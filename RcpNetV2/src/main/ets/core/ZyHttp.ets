import { rcp } from '@kit.RemoteCommunicationKit';
import { ZyHttpConfig, ZyResponseType, ZyTimeout, ZyRetry,
  ZyBusinessCodeHandler, ZyValidateStatus } from './ZyHttpConfig';
import { ZyCancelToken } from './ZyCancelToken';
import { ZyHttpRequestInternal } from './ZyHttpRequestInternal';
import { ZyRequestBuilder } from './ZyRequestBuilder';
import { ZyHttpResponse } from './ZyHttpResponse';
import { ZyMiddleware, ZyMiddlewareContext, LoggingMiddleware, DefaultHeaderMiddleware }
from '../middleware/ZyMiddleware';
import { ZyHttpError, toZyHttpError } from '../error/ZyHttpError';
import { translateDnsConfig, translateSecurityConfig } from '../util/ZyTranslate';
import { ZyHttpCache } from '../cache/ZyHttpCache';

/** 重试默认值(arkts 禁 utility types, 显式声明) */
interface ZyRetryDefaults {
  maxRetries: number;
  initialIntervalMs: number;
  maxIntervalMs: number;
}

/** 默认重试: 3 次, 500ms 起步, 8s 封顶 */
const DEFAULT_RETRY: ZyRetryDefaults = {
  maxRetries: 3,
  initialIntervalMs: 500,
  maxIntervalMs: 8000
};

/** 中间件链执行结果(onResponse 改写 / onResponseError 吞错降级的载体) */
interface ZyChainResult {
  /** onResponse 链: 响应数据是否被 respond 改写 */
  changed: boolean;
  /** 链上最终数据(响应数据或降级兜底数据) */
  data?: ESObject;
  /** onResponseError 链: 吞错降级数据(respond 调用后非空) */
  recoveredData?: ESObject;
  /** onResponseError 链: 转换后错误(未吞错时) */
  error?: ZyHttpError;
}

/**
 * ZyHttp 实例(2.0 核心, 一个实例 = 一个底层 rcp.Session)
 * - 实例化配置: ZyHttp.create(config), 会话级能力(DNS/安全/缓存/维测)挂在实例上
 * - 请求: newBuilder() 链式构建, 泛型直接返回解析后数据 resp.data
 * - 中间件: 洋葱模型(onRequest 顺序 / onResponse·onResponseError 逆序)
 * - 重试: 指数退避(仅网络类可重试错误; 取消/环境/配置类不重试; 未显式配置时仅幂等方法 GET/HEAD 默认重试, 非幂等方法不重试)
 * - 取消: ZyCancelToken 句柄式 + tag 批量 + cancelAll
 * - 生命周期: close() 释放底层会话
 */
export class ZyHttp {
  private config: ZyHttpConfig;
  private middlewares: ZyMiddleware[] = new Array<ZyMiddleware>();
  /** 正在进行中的请求(tag → 请求列表), 供 cancelTag */
  private inflight: Map<string, Array<ZyCancelToken>> = new Map<string, Array<ZyCancelToken>>();
  /** 全部进行中请求的取消令牌(含无 tag; 引用计数防同 token 多请求提前摘除), 供 cancelAll */
  private allTokens: Map<ZyCancelToken, number> = new Map<ZyCancelToken, number>();
  /** 底层会话(懒创建) */
  private session?: rcp.Session;
  /** 会话是否已关闭 */
  private closed: boolean = false;

  private constructor(config: ZyHttpConfig) {
    this.config = config;
    // 默认头注入中间件(实例级默认头, 请求级同名不覆盖)
    if (config.headers !== undefined && config.headers.size > 0) {
      this.middlewares.push(new DefaultHeaderMiddleware(config.headers));
    }
    // 外部自定义中间件(顺序保持)
    if (config.middlewares !== undefined) {
      for (const mw of config.middlewares) {
        this.middlewares.push(mw);
      }
    }
    // 结构化日志中间件(放最外层: onRequest 最先 / onResponse 最后; 出口注入宿主日志系统)
    if (config.logging === true) {
      this.middlewares.push(new LoggingMiddleware('ZyHttp', config.logger));
    }
  }

  /**
   * 创建 ZyHttp 实例
   * @param config 实例配置(baseURL/headers/timeout/retry/middlewares/dns/security/tracing/cache/logging)
   * @returns ZyHttp 实例
   */
  static create(config: ZyHttpConfig = {}): ZyHttp {
    return new ZyHttp(config);
  }

  /**
   * 创建请求构建器(继承实例默认配置)
   * @returns 构建器
   */
  newBuilder(): ZyRequestBuilder {
    return new ZyRequestBuilder(this, 'GET');
  }

  /**
   * 注册中间件(运行期追加, 等价 1.x addInterceptor; 顺序排在已注册中间件之后)
   * @param mw 中间件
   */
  use(mw: ZyMiddleware): void {
    this.middlewares.push(mw);
  }

  /**
   * 按名称移除中间件
   * @param name 中间件名(ZyMiddleware.name)
   */
  removeMiddleware(name: string): void {
    for (let i = this.middlewares.length - 1; i >= 0; i--) {
      if (this.middlewares[i].name === name) {
        this.middlewares.splice(i, 1);
      }
    }
  }

  /**
   * 动态更新 baseURL（updateBaseUrl 后即刻对所有后续请求生效）
   * @param url 新的 baseURL
   */
  setBaseURL(url: string): void {
    this.config.baseURL = url;
  }

  /**
   * 快捷 GET(等价 newBuilder().path(url).get<T>())
   * @param url 相对路径或完整 URL
   */
  get<T>(url: string): Promise<ZyHttpResponse<T>> {
    return this.newBuilder().path(url).get<T>();
  }

  /**
   * 快捷 POST(json 对象体)
   * @param url 相对路径或完整 URL
   * @param body 业务对象
   */
  post<T>(url: string, body: ESObject): Promise<ZyHttpResponse<T>> {
    return this.newBuilder().path(url).jsonBody(body).post<T>();
  }

  /**
   * 快捷 PUT(json 对象体)
   */
  put<T>(url: string, body: ESObject): Promise<ZyHttpResponse<T>> {
    return this.newBuilder().path(url).jsonBody(body).put<T>();
  }

  /**
   * 快捷 DELETE
   */
  delete<T>(url: string): Promise<ZyHttpResponse<T>> {
    return this.newBuilder().path(url).delete<T>();
  }

  /**
   * 组装内部请求(由 ZyRequestBuilder.build 调用; 完成默认值合并与 URL 拼接)
   */
  buildRequest(method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD', pathOrUrl: string,
    queries: Map<string, string>, headers: Map<string, string>, content?: rcp.RequestContent,
    responseType?: ZyResponseType, timeout?: ZyTimeout, retry?: ZyRetry,
    businessCodeHandler?: ZyBusinessCodeHandler, validateStatus?: ZyValidateStatus,
    cancelToken?: ZyCancelToken, tag?: string, collectTimeInfo?: boolean): ZyHttpRequestInternal {
    // 实例级默认 params 合并(公共参数注入点; 请求级 query 同名优先)
    const mergedQueries: Map<string, string> = new Map<string, string>();
    if (this.config.params !== undefined) {
      this.config.params.forEach((v: string, k: string) => {
        mergedQueries.set(k, v);
      });
    }
    queries.forEach((v: string, k: string) => {
      mergedQueries.set(k, v);
    });
    const url: string = this.resolveUrl(pathOrUrl, mergedQueries);
    const req = new ZyHttpRequestInternal(method, url);
    req.headers = headers;
    req.content = content;
    req.responseType = responseType ?? this.config.responseType ?? 'json';
    req.timeout = timeout ?? this.config.timeout;
    req.retry = retry ?? this.config.retry;
    req.businessCodeHandler = businessCodeHandler;
    req.validateStatus = validateStatus;
    req.cancelToken = cancelToken;
    req.tag = tag;
    req.collectTimeInfo = collectTimeInfo ?? false;
    return req;
  }

  /**
   * URL 解析: 绝对 URL 直接用; 相对路径拼 baseURL; 追加 query(含编码)
   */
  private resolveUrl(pathOrUrl: string, queries: Map<string, string>): string {
    let url: string;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      url = pathOrUrl;
    } else {
      const base: string = this.config.baseURL ?? '';
      const path: string = pathOrUrl.startsWith('/') ? pathOrUrl : `/${pathOrUrl}`;
      url = `${base}${path}`;
    }
    if (queries.size > 0) {
      const pairs: string[] = [];
      queries.forEach((v: string, k: string) => {
        pairs.push(`${encodeURIComponent(k)}=${encodeURIComponent(v)}`);
      });
      url = `${url}${url.includes('?') ? '&' : '?'}${pairs.join('&')}`;
    }
    return url;
  }

  /**
   * 执行请求(核心编排: 中间件洋葱 → rcp 请求 → 校验/解析 → 重试 → 取消 → 降级)
   * @param req 内部请求
   * @returns 统一响应(data: T)
   */
  async execute<T>(req: ZyHttpRequestInternal): Promise<ZyHttpResponse<T>> {
    if (this.closed) {
      throw new ZyHttpError('unknown', 'ZyHttp 实例已关闭, 请重新 create', false);
    }
    // 1) onRequest 链(注册顺序; skip 过滤)
    const actives: ZyMiddleware[] = this.activeMiddlewares(req);
    for (const mw of actives) {
      if (mw.onRequest !== undefined) {
        const ctx: ZyMiddlewareContext = {
          request: req,
          respond: (data: ESObject): void => {
            // onRequest 阶段无响应可替换, 预留扩展(当前为空实现)
          },
          custom: req.custom
        };
        await mw.onRequest(ctx);
      }
    }
    // 取消令牌已失效: 快速失败
    if (req.cancelToken !== undefined && req.cancelToken.isCancelled()) {
      throw ZyCancelToken.cancelledError();
    }
    // 无令牌请求补建: 保证 cancelAll 可覆盖(不依赖 tag)
    if (req.cancelToken === undefined) {
      req.cancelToken = new ZyCancelToken();
    }
    // 2) 重试循环
    // 未显式配置重试时: 仅幂等方法(GET/HEAD)使用默认重试; POST/PUT/DELETE 等非幂等方法不默认重试,
    // 避免网络类错误重试时请求可能已达服务端造成重复提交; 显式配置 retry 时以调用方配置为准
    const defaults: ZyRetryDefaults = DEFAULT_RETRY;
    const idempotent: boolean = req.method === 'GET' || req.method === 'HEAD';
    const maxRetries: number = req.retry !== undefined
      ? (req.retry.maxRetries ?? defaults.maxRetries)
      : (idempotent ? defaults.maxRetries : 0);
    const initialInterval: number = req.retry?.initialIntervalMs ?? defaults.initialIntervalMs;
    const maxInterval: number = req.retry?.maxIntervalMs ?? defaults.maxIntervalMs;
    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const startedAt: number = Date.now();
      try {
        let resp: ZyHttpResponse<T> = await this.executeOnce<T>(req, startedAt);
        // 3) onResponse 链(逆序洋葱; respond 可改写响应数据)
        const rewritten: ZyChainResult = await this.fireResponseChain(req, resp.data as ESObject);
        if (rewritten.changed) {
          // 保留原始响应元信息(status/headers/raw)重建响应
          if (resp.raw !== undefined) {
            resp = new ZyHttpResponse<T>(resp.raw, rewritten.data as T);
          } else {
            resp = ZyHttpResponse.recovered<T>(rewritten.data as T);
          }
        }
        return resp;
      } catch (err) {
        let error: ZyHttpError = toZyHttpError(err);
        // 4) onResponseError 链(逆序; respond 吞错降级, 抛错则转换错误)
        const handled: ZyChainResult = await this.fireErrorChain(req, error);
        if (handled.recoveredData !== undefined) {
          // 中间件吞错降级: 返回兜底响应(recovered=true, status=0)
          return ZyHttpResponse.recovered<T>(handled.recoveredData as T);
        }
        if (handled.error !== undefined) {
          error = handled.error;
        }
        // 5) 重试判定(默认: 网络类且 retryable 才重试)
        const shouldRetry: boolean = attempt < maxRetries && this.judgeRetry(req, error);
        if (!shouldRetry) {
          throw error;
        }
        // 指数退避: initial * 2^attempt, 封顶 maxInterval
        const backoff: number = Math.min(initialInterval * Math.pow(2, attempt), maxInterval);
        await this.sleep(backoff);
        attempt += 1;
      }
    }
  }

  /**
   * 过滤本次请求生效的中间件(按 req.skipNames 剔除)
   */
  private activeMiddlewares(req: ZyHttpRequestInternal): ZyMiddleware[] {
    if (req.skipNames.length === 0) {
      return this.middlewares;
    }
    const actives: ZyMiddleware[] = new Array<ZyMiddleware>();
    for (const mw of this.middlewares) {
      if (!req.skipNames.includes(mw.name)) {
        actives.push(mw);
      }
    }
    return actives;
  }

  /**
   * 单次请求执行(rcp 调用 + 状态码/业务码校验 + 响应解析)
   */
  private async executeOnce<T>(req: ZyHttpRequestInternal, startedAt: number): Promise<ZyHttpResponse<T>> {
    const session: rcp.Session = this.ensureSession();
    // 请求级 rcp.Configuration(超时/时间采集)
    const reqConfig: rcp.Configuration = {};
    const timeout: ZyTimeout | undefined = req.timeout;
    if (timeout !== undefined) {
      const transfer: rcp.TransferConfiguration = {};
      const t: rcp.Timeout = {
        connectMs: timeout.connectMs,
        transferMs: timeout.transferMs,
        inactivityMs: timeout.inactivityMs
      };
      transfer.timeout = t;
      reqConfig.transfer = transfer;
    }
    if (req.collectTimeInfo) {
      const tracing: rcp.TracingConfiguration = { collectTimeInfo: true };
      reqConfig.tracing = tracing;
    }
    // 头转换 Map → 官方 RequestHeaders(Record)
    const requestHeaders: rcp.RequestHeaders = {};
    req.headers.forEach((v: string, k: string) => {
      requestHeaders[k] = v;
    });
    const request: rcp.Request =
      new rcp.Request(req.url, req.method, requestHeaders, req.content, undefined, undefined, reqConfig);
    // 取消注册(session.cancel(request) 按 Request 实例取消)
    const cancelAction: () => void = (): void => {
      session.cancel(request);
    };
    if (req.cancelToken !== undefined) {
      req.cancelToken.register(cancelAction);
      // 注册前已取消: 立即失败，避免已 cancel 仍发出 fetch
      if (req.cancelToken.isCancelled()) {
        req.cancelToken.unregister(cancelAction);
        throw ZyCancelToken.cancelledError();
      }
    }
    // tag 索引(供 cancelTag); 令牌全局登记(供 cancelAll, 含无 tag)
    if (req.cancelToken !== undefined) {
      this.trackAll(req.cancelToken);
    }
    if (req.tag !== undefined && req.cancelToken !== undefined) {
      this.trackTag(req.tag, req.cancelToken);
    }
    try {
      const raw: rcp.Response = await session.fetch(request);
      req.resolvedStatus = raw.statusCode;
      req.resolvedDurationMs = Date.now() - startedAt;
      // 状态码校验(默认 2xx)
      const validator: ZyValidateStatus = req.validateStatus ?? ((s: number): boolean => s >= 200 && s < 300);
      if (!validator(raw.statusCode)) {
        throw new ZyHttpError('http', `HTTP 状态码校验失败: ${raw.statusCode}`, false,
          raw.statusCode, undefined, raw);
      }
      // 响应解析
      const data: ESObject = this.parseBody(raw, req.responseType);
      // 业务码校验
      if (req.businessCodeHandler !== undefined && !req.businessCodeHandler(data)) {
        throw new ZyHttpError('business', '业务码校验未通过', false, raw.statusCode, undefined, data);
      }
      return new ZyHttpResponse<T>(raw, data as T);
    } finally {
      if (req.cancelToken !== undefined) {
        req.cancelToken.unregister(cancelAction);
        this.untrackAll(req.cancelToken);
      }
      if (req.tag !== undefined) {
        this.untrackTag(req.tag, req.cancelToken);
      }
    }
  }

  /**
   * onResponse 链(逆序洋葱; ctx.respond 改写响应数据并短路)
   * @returns 链执行结果: changed=true 时 data 为改写后数据
   */
  private async fireResponseChain(req: ZyHttpRequestInternal, data: ESObject): Promise<ZyChainResult> {
    const result: ZyChainResult = { changed: false, data: data };
    const reversed: ZyMiddleware[] = this.activeMiddlewares(req).slice().reverse();
    for (const mw of reversed) {
      if (result.changed) {
        break; // 已被 respond 改写, 短路
      }
      if (mw.onResponse !== undefined) {
        const ctx: ZyMiddlewareContext = {
          request: req,
          response: result.data,
          respond: (d: ESObject): void => {
            result.changed = true;
            result.data = d;
          },
          custom: req.custom
        };
        try {
          await mw.onResponse(ctx);
        } catch (err) {
          // 中间件抛错: 标准化后转入错误链(洋葱语义, 响应阶段错误可被 onResponseError 观测)
          throw toZyHttpError(err);
        }
      }
    }
    return result;
  }

  /**
   * onResponseError 链(逆序; ctx.respond 吞错降级, 重抛则转换错误)
   * @returns 链执行结果: recoveredData 非空表示吞错降级; error 为转换后错误
   */
  private async fireErrorChain(req: ZyHttpRequestInternal, error: ZyHttpError): Promise<ZyChainResult> {
    const result: ZyChainResult = { changed: false, error: error };
    const reversed: ZyMiddleware[] = this.activeMiddlewares(req).slice().reverse();
    for (const mw of reversed) {
      if (result.recoveredData !== undefined) {
        break; // 已吞错降级, 短路
      }
      if (mw.onResponseError !== undefined) {
        try {
          const ctx: ZyMiddlewareContext = {
            request: req,
            error: result.error,
            respond: (d: ESObject): void => {
              result.recoveredData = d;
            },
            custom: req.custom
          };
          await mw.onResponseError(ctx);
        } catch (err) {
          result.error = toZyHttpError(err);
        }
      }
    }
    return result;
  }

  /**
   * 重试判定: 请求级 retryOn > 实例级 retryOn > 默认(网络类且 retryable)
   */
  private judgeRetry(req: ZyHttpRequestInternal, error: ZyHttpError): boolean {
    const custom: ((e: ZyHttpError) => boolean) | undefined = req.retry?.retryOn;
    if (custom !== undefined) {
      return custom(error);
    }
    const instanceCustom: ((e: ZyHttpError) => boolean) | undefined = this.config.retry?.retryOn;
    if (instanceCustom !== undefined) {
      return instanceCustom(error);
    }
    return error.kind === 'network' && error.retryable;
  }

  /**
   * 按 responseType 解析响应体
   * - json: toString → JSON.parse(失败抛 kind='parse')
   * - text: toString
   * - arraybuffer: 官方 body(已是 ArrayBuffer)
   */
  private parseBody(raw: rcp.Response, type: ZyResponseType): ESObject {
    if (type === 'arraybuffer') {
      return raw.body;
    }
    const text: string = raw.toString() ?? '';
    if (type === 'text') {
      return text;
    }
    // json
    if (text.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(text);
    } catch (err) {
      throw new ZyHttpError('parse', `响应体 JSON 解析失败: ${text.substring(0, 100)}`, false,
        raw.statusCode, undefined, err);
    }
  }

  /**
   * 懒创建底层会话(实例级配置: baseURL/安全/DNS/维测/缓存)
   * 官方约束: API18 起单子线程最多 1024 个 session, close() 释放
   */
  private ensureSession(): rcp.Session {
    if (this.session !== undefined) {
      return this.session;
    }
    const sessionConfig: rcp.SessionConfiguration = {};
    if (this.config.baseURL !== undefined) {
      sessionConfig.baseAddress = this.config.baseURL;
    }
    const requestConfig: rcp.Configuration = {};
    if (this.config.timeout !== undefined) {
      const transfer: rcp.TransferConfiguration = {};
      const t: rcp.Timeout = {
        connectMs: this.config.timeout.connectMs,
        transferMs: this.config.timeout.transferMs,
        inactivityMs: this.config.timeout.inactivityMs
      };
      transfer.timeout = t;
      requestConfig.transfer = transfer;
    }
    if (this.config.security !== undefined) {
      requestConfig.security = translateSecurityConfig(this.config.security);
    }
    if (this.config.dns !== undefined) {
      requestConfig.dns = translateDnsConfig(this.config.dns);
    }
    if (this.config.tracing !== undefined) {
      requestConfig.tracing = this.config.tracing;
    }
    sessionConfig.requestConfiguration = requestConfig;
    // HTTP 缓存挂载(官方 Configuration.cache, 运行时 API 20+ 才有实例;
    // ZyHttpCache 构造期已按 deviceInfo.sdkApiVersion 门控, 低版本 getCache()=undefined 自动跳过)
    const cache: ZyHttpCache | undefined = this.config.cache;
    if (cache !== undefined) {
      const rawCache: rcp.ResponseCache | undefined = cache.getCache();
      if (rawCache !== undefined) {
        requestConfig.cache = rawCache;
      }
    }
    this.session = rcp.createSession(sessionConfig);
    return this.session;
  }

  /**
   * 登记进行中请求到全局令牌表(cancelAll 用; 引用计数防同 token 多请求)
   */
  private trackAll(token: ZyCancelToken): void {
    const count: number = this.allTokens.get(token) ?? 0;
    this.allTokens.set(token, count + 1);
  }

  /**
   * 注销全局令牌登记(计数归零才移除)
   */
  private untrackAll(token: ZyCancelToken): void {
    const count: number = (this.allTokens.get(token) ?? 0) - 1;
    if (count <= 0) {
      this.allTokens.delete(token);
    } else {
      this.allTokens.set(token, count);
    }
  }

  /**
   * 登记进行中请求(tag → tokens)
   */
  private trackTag(tag: string, token: ZyCancelToken): void {
    let list: Array<ZyCancelToken> | undefined = this.inflight.get(tag);
    if (list === undefined) {
      list = new Array<ZyCancelToken>();
      this.inflight.set(tag, list);
    }
    list.push(token);
  }

  /**
   * 外部原生路径登记取消令牌(供 cancelAll; 如 download 直连 session.fetch)
   * @param token 取消令牌
   */
  trackInflight(token: ZyCancelToken): void {
    this.trackAll(token);
  }

  /**
   * 外部原生路径注销取消令牌
   * @param token 取消令牌
   */
  untrackInflight(token: ZyCancelToken): void {
    this.untrackAll(token);
  }

  /**
   * 注销进行中请求
   */
  private untrackTag(tag: string, token: ZyCancelToken | undefined): void {
    if (token === undefined) {
      return;
    }
    const list: Array<ZyCancelToken> | undefined = this.inflight.get(tag);
    if (list === undefined) {
      return;
    }
    const index: number = list.indexOf(token);
    if (index >= 0) {
      list.splice(index, 1);
    }
    if (list.length === 0) {
      this.inflight.delete(tag);
    }
  }

  /**
   * 按标签批量取消进行中请求
   * @param tag 标签名
   */
  cancelTag(tag: string): void {
    const list: Array<ZyCancelToken> | undefined = this.inflight.get(tag);
    if (list === undefined) {
      return;
    }
    const snapshot: Array<ZyCancelToken> = list.slice();
    for (const token of snapshot) {
      token.cancel();
    }
  }

  /**
   * 取消全部进行中请求(含无 tag; 遍历全局令牌表, 不再只走 tag 桶)
   */
  cancelAll(): void {
    const tokens: ZyCancelToken[] = Array.from(this.allTokens.keys());
    for (const token of tokens) {
      token.cancel();
    }
    // tag 桶兜底(极端情况下 allTokens 未覆盖的残留)
    const tags: string[] = Array.from(this.inflight.keys());
    for (const tag of tags) {
      this.cancelTag(tag);
    }
  }

  /**
   * 休眠(重试退避用)
   */
  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  /**
   * 获取底层原生 rcp.Session（逃生舱）：
   * 供上层单次使用未封装的原生能力（downloadToFile/uploadFromFile/
   * configuration.destination/fetchForSendable 等），原生调用不经过中间件链
   * @returns 共享的 rcp.Session 实例
   */
  getNativeSession(): rcp.Session {
    return this.ensureSession();
  }

  /**
   * 关闭实例并释放底层会话(close 后不可再发请求)
   */
  close(): void {
    this.closed = true;
    this.cancelAll();
    const session = this.session;
    if (session !== undefined) {
      try {
        session.close();
      } catch (err) {
        // 忽略重复关闭异常
      }
      this.session = undefined;
    }
  }
}
