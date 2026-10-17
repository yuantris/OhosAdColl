import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { buildFullPath, buildURL } from './src/main/js/buildurl';
import { zyLog, ZyNetLogger } from './logger';

// 统一日志实现收敛至 logger.ts（zyLog / 日志域与标签常量 / ZyNetLogger 请求日志框 / 全局开关与脱敏）
export { zyLog, ZY_LOG_DOMAIN, ZY_LOG_TAG, ZyNetLogger, setNetLogEnabled, setNetLogMask } from './logger';

/** intercept 调试日志开关：默认关闭，开启后 intercept 内日志才会输出 */
let interceptLogEnabled: boolean = false;

/**
 * 开启/关闭 RequestInterceptor.intercept 的调试日志输出
 * @param enabled true 开启 / false 关闭（默认关闭）
 */
export function setInterceptLogEnabled(enabled: boolean): void {
  interceptLogEnabled = enabled;
}

import {
  AnyObject,
  Call,
  HttpDownloadResponse,
  HttpPromise,
  HttpRequestConfig,
  HttpResponse,
  HttpUploadResponse,
  InterceptorContext,
  MultipartFileSpec,
  NetInterceptor,
  RequestTask,
  RetryConfig
} from './Index';

/**
 * 统一错误模型：所有请求失败都以此结构 reject，业务侧 catch 收到的永远是 HttpError
 * kind: network 网络异常 / http HTTP状态码错误 / parse 解析失败 / cancel 已取消 / business 业务码拦截 / unknown 未知
 */
export class HttpError extends Error {
  kind: 'network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown';
  statusCode?: number;
  cause?: ESObject;
  config?: ESObject;

  constructor(kind: 'network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown', message: string, statusCode?: number, cause?: ESObject, config?: ESObject) {
    super(message);
    this.name = 'HttpError';
    this.kind = kind;
    this.statusCode = statusCode;
    this.cause = cause;
    this.config = config;
  }
}

/**
 * 判断某请求配置是否跳过指定插件（raw 视为跳过全部插件）
 * @param config 请求配置
 * @param pluginName 插件名
 * @returns true 表示该插件对本请求不生效
 */
export function isSkipped(config: HttpRequestConfig | undefined, pluginName: string): boolean {
  if (!config) {
    return false;
  }
  if (config.raw) {
    return true;
  }
  return !!(config.skip && config.skip.indexOf(pluginName) >= 0);
}

/**
 * 判断某请求配置是否为纯净请求（raw=true）
 * @param config 请求配置
 * @returns true 表示纯净请求
 */
export function isRaw(config: HttpRequestConfig | undefined): boolean {
  return !!config && !!config.raw;
}

// ==================== 插件链执行器 ====================

/**
 * 依次执行插件链的 onRequest（前一个的返回值作为下一个的输入）
 * 单个插件异常仅打印 error 日志，不中断请求
 * @param plugins 插件列表
 * @param config 当前配置
 * @param ctx 拦截器上下文（携带本次请求日志框）
 * @returns 插件链处理后的最终配置
 */
async function applyRequestPlugins(plugins: NetInterceptor[], config: HttpRequestConfig, ctx: InterceptorContext): Promise<HttpRequestConfig> {
  let cfg = config;
  for (const plugin of plugins) {
    if (!plugin.onRequest) {
      continue;
    }
    // 以"当前配置"实时判断 skip：插件可以在链路上动态追加 skip 使后续插件失效
    if (isSkipped(cfg, plugin.name)) {
      continue;
    }
    try {
      const out = await plugin.onRequest(cfg, ctx);
      if (out) {
        cfg = out;
      }
    } catch (e) {
      zyLog(hilog.error, `[ZYNet] 插件 ${plugin.name}.onRequest 执行异常（已跳过该插件）: ${e}`);
    }
  }
  return cfg;
}

/**
 * 依次执行插件链的 onResponse（响应返回后、resolve 前调用）
 * 单个插件异常仅打印 error 日志，不中断响应
 * @param plugins 插件列表
 * @param response 响应对象
 * @param ctx 拦截器上下文
 * @returns 插件链处理后的最终响应
 */
async function applyResponsePlugins(plugins: NetInterceptor[], response: HttpResponse, ctx: InterceptorContext): Promise<HttpResponse> {
  let resp = response;
  for (const plugin of plugins) {
    if (!plugin.onResponse || isSkipped(resp.config, plugin.name)) {
      continue;
    }
    try {
      const out = await plugin.onResponse(resp, ctx);
      if (out) {
        resp = out;
      }
    } catch (e) {
      zyLog(hilog.error, `[ZYNet] 插件 ${plugin.name}.onResponse 执行异常（已跳过该插件）: ${e}`);
    }
  }
  return resp;
}

/**
 * 依次执行插件链的 onError（reject 前调用，允许插件替换/包装最终错误）
 * 单个插件异常时保留原错误继续
 * @param plugins 插件列表
 * @param error 当前错误
 * @param ctx 拦截器上下文
 * @returns 最终 reject 的错误
 */
async function applyErrorPlugins(plugins: NetInterceptor[], error: HttpError, ctx: InterceptorContext): Promise<HttpError> {
  let err = error;
  for (const plugin of plugins) {
    if (!plugin.onError || isSkipped(err.config as HttpRequestConfig, plugin.name)) {
      continue;
    }
    try {
      const out = await plugin.onError(err, ctx);
      if (out) {
        err = out;
      }
    } catch (e) {
      zyLog(hilog.error, `[ZYNet] 插件 ${plugin.name}.onError 执行异常（保留原错误）: ${e}`);
    }
  }
  return err;
}

// ==================== 重试辅助 ====================

/**
 * 规整重试配置：number 等价 { count }；未配置时不重试
 * @param retry 调用方传入的重试配置
 * @returns 完整重试配置（含默认延迟参数）
 */
function normalizeRetry(retry?: number | RetryConfig): RetryConfig {
  if (retry === undefined || retry === null) {
    return { count: 0 };
  }
  if (typeof retry === 'number') {
    return { count: Math.max(0, Math.floor(retry)) };
  }
  return { delayMs: 500, maxDelayMs: 8000, ...retry, count: Math.max(0, Math.floor(retry.count)) };
}

/**
 * 判断某错误是否应重试：cancel/parse 永不重试；
 * 未显式配置 retryOn 时默认重试 网络错误 + HTTP 5xx
 * @param retry 重试配置
 * @param err 当前错误
 * @returns true 表示可重试
 */
function shouldRetry(retry: RetryConfig, err: HttpError): boolean {
  if (err.kind === 'cancel' || err.kind === 'parse') {
    return false;
  }
  if (retry.retryOn && retry.retryOn.length > 0) {
    return retry.retryOn.indexOf(err.kind) >= 0;
  }
  if (err.kind === 'network') {
    return true;
  }
  if (err.kind === 'http' && (err.statusCode ?? 0) >= 500) {
    return true;
  }
  return false;
}

/**
 * 计算第 attempt 次重试的退避延迟（指数退避，封顶 maxDelayMs）
 * @param retry 重试配置
 * @param attempt 已重试次数（从 0 计）
 * @returns 延迟毫秒数
 */
function backoffDelay(retry: RetryConfig, attempt: number): number {
  const base = retry.delayMs ?? 500;
  const cap = retry.maxDelayMs ?? 8000;
  return Math.min(base * Math.pow(2, attempt), cap);
}

/**
 * 等待指定毫秒
 * @param ms 延迟毫秒数
 */
function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * 将任意异常标准化为 HttpError
 * @param err 原始异常
 * @param config 请求配置快照
 * @param cancelled 是否因调用方 abort 而失败
 * @returns 标准化错误
 */
function toHttpError(err: ESObject, config: HttpRequestConfig, cancelled: boolean): HttpError {
  if (err instanceof HttpError) {
    return err;
  }
  if (cancelled) {
    return new HttpError('cancel', '请求已取消', undefined, err, config);
  }
  const be = err as BusinessError;
  return new HttpError('network', be?.message || `网络请求失败(code=${be?.code})`, undefined, err, config);
}

// ==================== 请求内容构建 ====================

/**
 * 从配置构建 RCP 请求体内容：
 * 1. multipartFiles（或 upload() 的 name+filePath）→ rcp.MultipartForm（文本字段 + 文件）
 * 2. rawBody → 原样发送（string/ArrayBuffer，content-type 由调用方在 header 指定）
 * 3. data → 对象由 RCP 序列化为 JSON；字符串原样发送（bodyForm 的 urlencoded 场景）
 * @param cfg 请求配置
 * @returns RCP 请求体；GET 等无体请求返回 undefined
 */
function buildRequestContent(cfg: HttpRequestConfig): rcp.RequestContent | undefined {
  // 收集文件字段：显式 multipartFiles + upload() 的 name/filePath 组合
  const files: MultipartFileSpec[] = cfg.multipartFiles ? cfg.multipartFiles.slice() : [];
  if (cfg.name && cfg.filePath) {
    files.push({ name: cfg.name, path: cfg.filePath });
  }
  if (files.length > 0) {
    const fields: Record<string, rcp.MultipartFormFieldValue> = {};
    // 文本字段：upload() 的 formData + bodyMultipart 的 multipartFields
    if (cfg.formData) {
      Object.keys(cfg.formData).forEach((k: string) => {
        fields[k] = String(cfg.formData![k]) as rcp.FormFieldValue;
      });
    }
    if (cfg.multipartFields) {
      Object.keys(cfg.multipartFields).forEach((k: string) => {
        fields[k] = cfg.multipartFields![k] as rcp.FormFieldValue;
      });
    }
    // 文件字段：path（本地路径）或 content（内存内容）二选一
    files.forEach((f: MultipartFileSpec) => {
      const fileValue: rcp.FormFieldFileValue = {
        contentOrPath: (f.path !== undefined ? f.path : { content: f.content as string | ArrayBuffer })
      };
      const baseName = f.remoteFileName || (f.path ? f.path.split(/[\\/]/).pop() : undefined);
      if (baseName) {
        fileValue.remoteFileName = baseName;
      }
      if (f.contentType) {
        fileValue.contentType = f.contentType as rcp.ContentType;
      }
      fields[f.name] = fileValue;
    });
    return new rcp.MultipartForm(fields);
  }
  if (cfg.rawBody !== undefined) {
    return cfg.rawBody;
  }
  return cfg.data;
}

// 定义RequestInterceptor拦截器（兼容保留：同步 onFulfilled 钩子在插件链之前执行）
export class RequestInterceptor implements rcp.Interceptor {
  public onFulfilled?: (config?: HttpRequestConfig) => HttpRequestConfig;
  public onRejected?: (error: any) => any;

  constructor(onFulfilled?: (config: HttpRequestConfig) => HttpRequestConfig, onRejected?: (error: any) => any) {
    this.onFulfilled = onFulfilled;
    this.onRejected = onRejected;
  }

  // 自定义请求处理逻辑
  async intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response> {
    try {
      // 添加调试日志，查看 context.request 的完整结构
      if (interceptLogEnabled) zyLog(hilog.debug, `intercept 方法 - context.request: ${JSON.stringify(context.request)}`);
      if (interceptLogEnabled) zyLog(hilog.debug, `intercept 方法 - context.request 属性: ${JSON.stringify(Object.keys(context.request))}`);

      if (this.onFulfilled) {
        let requestData: any;
        if ('body' in context.request) {
          requestData = context.request.body;
          if (interceptLogEnabled) zyLog(hilog.debug, `使用 request.body 获取数据: ${JSON.stringify(requestData)}`);
        } else if ('data' in context.request) {
          requestData = context.request.data;
          if (interceptLogEnabled) zyLog(hilog.debug, `使用 request.data 获取数据: ${JSON.stringify(requestData)}`);
        } else if ('payload' in context.request) {
          requestData = context.request.payload;
          if (interceptLogEnabled) zyLog(hilog.debug, `使用 request.payload 获取数据: ${JSON.stringify(requestData)}`);
        } else {
          if (interceptLogEnabled) zyLog(hilog.debug, `未找到数据属性，context.request: ${JSON.stringify(context.request)}`);
        }

        let conf: HttpRequestConfig = {
          method: context.request.method,
          header: context.request.headers,
          // 将 URL 类型转换为 string 类型
          url: typeof context.request.url === 'string' ? context.request.url : context.request.url.toString(),
          data: requestData
        };

        if (interceptLogEnabled) zyLog(hilog.debug, `创建的 conf 对象: ${JSON.stringify(conf)}`);

        // 调用拦截器并获取修改后的配置
        const modifiedConfig = this.onFulfilled(conf);

        if (interceptLogEnabled) zyLog(hilog.debug, `拦截器返回的 modifiedConfig: ${JSON.stringify(modifiedConfig)}`);

        // 使用修改后的配置更新 request
        if (modifiedConfig) {
          context.request.method = modifiedConfig.method || context.request.method;
          context.request.headers = modifiedConfig.header || context.request.headers;

          if ('body' in context.request) {
            context.request.body = modifiedConfig.data || context.request.body;
          } else if ('data' in context.request) {
            context.request.data = modifiedConfig.data || context.request.data;
          } else if ('payload' in context.request) {
            context.request.payload = modifiedConfig.data || context.request.payload;
          }
        }
      }
    } catch (error) {
      if (interceptLogEnabled) zyLog(hilog.error, `intercept 方法出错: ${error}`);
      if (this.onRejected) {
        const result = this.onRejected(error);
        if (result !== undefined) {
          return result;
        }
      }
      throw error;
    }
    return next.handle(context);
  }
}

// 定义ResponseInterceptor拦截器（兼容保留）
export class ResponseInterceptor implements rcp.Interceptor {
  public onFulfilled?: (response?: HttpResponse) => HttpResponse;
  public onRejected?: (error: any) => any;

  constructor(onFulfilled?: (response: HttpResponse) => HttpResponse, onRejected?: (error: any) => any) {
    this.onFulfilled = onFulfilled;
    this.onRejected = onRejected;
  }

  // 自定义响应处理逻辑
  async intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response> {
    const response = await next.handle(context);
    try {
      if (this.onFulfilled) {
        let resp: HttpResponse = {
          data: response.toJSON(),
          statusCode: response.statusCode,
          errMsg: response.reasonPhrase,
          cookies: response.cookies?.map(cookie => `${cookie.name}=${cookie.value}`),
          header: response.headers
        }
        this.onFulfilled(resp);
      }
    } catch (error) {
      if (this.onRejected) {
        const result = this.onRejected(error);
        if (result !== undefined) {
          return result;
        }
      }
      throw error;
    }
    return response;
  }
}

export abstract class HttpRequestAbstract {
  session: rcp.Session;
  config: HttpRequestConfig;
  requestInterceptor: RequestInterceptor;
  responseInterceptor: ResponseInterceptor;
  /** 库级插件链（use() 注册，按注册顺序执行） */
  private plugins: NetInterceptor[] = [];
  /** 进行中的请求索引：request -> tag（cancelTag/cancelAll/abort 联动用；实例级，避免多实例互串） */
  private activeTags: Map<rcp.Request, string | undefined> = new Map<rcp.Request, string | undefined>();
  /** 已被调用方 abort 的请求集合：fetch reject 时据此判定 kind='cancel'（实例级） */
  private abortedRequests: Set<rcp.Request> = new Set<rcp.Request>();

  constructor(public conf: HttpRequestConfig) {
    this.config = {
      ...conf,
      validateStatus: conf.validateStatus || ((status) => {
        return status >= 200 && status < 300;
      })
    };
    this.requestInterceptor = new RequestInterceptor();
    this.responseInterceptor = new ResponseInterceptor();

    const timeoutMs = conf.timeout || 5000;
    const sessionConfig: rcp.SessionConfiguration = {
      baseAddress: conf.baseURL,
      headers: conf.header !== undefined ? conf.header : { 'accept': 'application/json' },
      interceptors: [
        this.requestInterceptor,
        this.responseInterceptor
      ],
      requestConfiguration: {
        transfer: {
          timeout: {
            connectMs: timeoutMs,
            transferMs: timeoutMs
          }
        },
        security: {
          tlsOptions: {
            tlsVersion: 'TlsV1.2'
          }
        }
      }
    }
    this.session = rcp.createSession(sessionConfig);
  }

  /**
   * 注册库级拦截器插件（链式叠加，按注册顺序执行）
   * @param plugin 拦截器插件
   * @returns 当前实例（支持链式）
   */
  use(plugin: NetInterceptor): this {
    this.plugins.push(plugin);
    return this;
  }

  /**
   * 构建请求级 RCP Configuration：两段超时/进度回调/代理/DNS/TLS
   * 进度回调按 RCP 规范挂在 tracing.httpEventsHandler，对外参数顺序统一为 (transferredSize, totalSize)
   * 请求级配置优先于 Session 级，单次请求可独立覆盖
   * @param cfg 请求配置
   * @returns RCP 请求级配置
   */
  private buildRequestConfiguration(cfg: HttpRequestConfig): rcp.Configuration {
    // 超时细分：connect/transfer 缺省回落到 timeout，再回落 5000ms
    const timeoutMs = cfg.timeout || this.config.timeout || 5000;
    const connectMs = cfg.connectTimeout || timeoutMs;
    const transferMs = cfg.transferTimeout || timeoutMs;
    const transfer: rcp.TransferConfiguration = {
      timeout: { connectMs: connectMs, transferMs: transferMs }
    };
    const configuration: rcp.Configuration = { transfer: transfer };
    // 进度回调：RCP 挂点为 tracing.httpEventsHandler（原生参数顺序 totalSize 在前，桥接时换序）
    if (cfg.onUploadProgress || cfg.onDownloadProgress) {
      const events: rcp.HttpEventsHandler = {};
      if (cfg.onUploadProgress) {
        const cb = cfg.onUploadProgress;
        events.onUploadProgress = (totalSize: number, transferredSize: number, request?: rcp.Request): void => cb(transferredSize, totalSize);
      }
      if (cfg.onDownloadProgress) {
        const cb = cfg.onDownloadProgress;
        events.onDownloadProgress = (totalSize: number, transferredSize: number, request?: rcp.Request): void => cb(transferredSize, totalSize);
      }
      configuration.tracing = { httpEventsHandler: events };
    }
    if (cfg.proxy) {
      configuration.proxy = cfg.proxy;
    }
    if (cfg.dns) {
      configuration.dns = cfg.dns;
    }
    if (cfg.tlsOptions || cfg.sslVerify === false) {
      const security: rcp.SecurityConfiguration = {
        tlsOptions: cfg.tlsOptions || { tlsVersion: 'TlsV1.2' } as rcp.TlsV12Option
      };
      if (cfg.sslVerify === false) {
        security.remoteValidation = 'skip';
      }
      configuration.security = security;
    }
    return configuration;
  }

  /**
   * 核心请求流程（async 直写，供 request/execute/upload/download 复用）：
   * 日志框 → 兼容同步拦截器 → 插件链 → URL 构建 → Request 创建（注册取消索引）
   * → 重试循环（指数退避）→ 状态校验 → JSON 解析 → 响应插件链 → resolve
   * 所有失败路径先收尾日志框再抛出统一 HttpError
   * @param config 请求配置
   * @param hooks 内部钩子：onRequestCreated 供 execute 拿到 rcp.Request 句柄；destination 为下载目标
   */
  private async doRequest<T = ESObject>(config: HttpRequestConfig, hooks?: {
    onRequestCreated?: (req: rcp.Request) => void;
    destination?: rcp.DownloadToFile;
  }): Promise<HttpResponse<T> | HttpDownloadResponse> {
    // 本次请求的日志框（并发请求通过唯一 ID 区分）
    const netLogger = new ZyNetLogger(config.method || 'GET', config.url || '');
    /** 实际发出的 rcp.Request（finally 清理取消索引用） */
    let req: rcp.Request | null = null;
    try {
      // 开启本次请求的日志框（打印原始请求信息；签名等同步钩子经 setCurrent 写入框内）
      netLogger.begin({
        baseURL: config.baseURL || this.config.baseURL,
        params: config.params,
        data: config.data,
        header: config.header
      });

      // 1. 兼容窗口：旧同步 requestInterceptor.onFulfilled（签名等历史逻辑仍在用）
      let processedConfig = config;
      if (this.requestInterceptor.onFulfilled) {
        ZyNetLogger.setCurrent(netLogger);
        try {
          processedConfig = this.requestInterceptor.onFulfilled(config) || config;
        } finally {
          ZyNetLogger.setCurrent(null);
        }
      }

      // 2. 插件链（异步、可组合；raw/skip 在链内实时判定）
      const ctx: InterceptorContext = { logger: netLogger };
      processedConfig = await applyRequestPlugins(this.plugins, processedConfig, ctx);

      // 3. 参数校验与 URL 构建（axios 语义：绝对 URL 直接用，不拼 baseURL）
      if (!processedConfig.url) {
        netLogger.failed({ url: processedConfig.url }, 'processedConfig.url 为空，无法构建 fullUrl');

        throw new HttpError('unknown', 'URL is required', undefined, undefined, config);
      }
      const fullPath = buildFullPath(processedConfig.baseURL || this.config.baseURL, processedConfig.url);
      const fullUrl = buildURL(fullPath, processedConfig.params);
      netLogger.step('fullUrl', fullUrl);
      // 签名后最终查询参数（含签名 token）
      netLogger.step('signedParams', JSON.stringify(processedConfig.params || {}));

      // 4. 构建 RCP Request（请求体内容 + 请求级配置 + 断点续传范围）
      const content = buildRequestContent(processedConfig);
      const requestConfiguration = this.buildRequestConfiguration(processedConfig);
      req = new rcp.Request(fullUrl, processedConfig.method, processedConfig.header, content,
        undefined, processedConfig.transferRange, requestConfiguration);
      // 下载目标：destination 是 Request 实例属性（不属于 Configuration），构造后赋值
      if (hooks?.destination) {
        req.destination = hooks.destination;
      }
      hooks?.onRequestCreated?.(req);
      this.activeTags.set(req, processedConfig.tag);

      // 5. 重试循环（指数退避；网络错误/5xx 默认可重试）
      const retry = normalizeRetry(processedConfig.retry);
      const validateStatus = processedConfig.validateStatus || this.config.validateStatus!;
      let attempt = 0;
      for (;;) {
        let response: rcp.Response;
        try {
          response = await this.session.fetch(req);
        } catch (e) {
          const httpErr = toHttpError(e, processedConfig, this.abortedRequests.has(req));
          if (httpErr.kind === 'cancel') {
            netLogger.failed({ kind: 'cancel' }, '请求已被调用方取消');
            throw await applyErrorPlugins(this.plugins, httpErr, ctx);
          }
          if (attempt < retry.count && shouldRetry(retry, httpErr)) {
            attempt++;
            const delay = backoffDelay(retry, attempt - 1);
            netLogger.step('retry', `${attempt}/${retry.count} · ${delay}ms 后重发 · ${httpErr.message}`, 'warn');
            retry.onRetry?.(attempt, httpErr, delay);
            await sleep(delay);
            continue;
          }
          netLogger.failed(httpErr.cause ?? httpErr.message, httpErr.kind === 'network' ? '网络请求失败' : '请求失败');
          throw await applyErrorPlugins(this.plugins, httpErr, ctx);
        }

        // 状态码校验
        if (validateStatus(response.statusCode)) {
          netLogger.step('statusCode', `${response.statusCode}`);
          // 文件下载：响应无 JSON body，直接收尾返回
          if (hooks?.destination) {
            const resp: HttpDownloadResponse = {
              config: processedConfig,
              data: null as ESObject as T,
              statusCode: response.statusCode,
              errMsg: response.reasonPhrase,
              tempFilePath: processedConfig.filePath,
              header: response.headers,
              cookies: response.cookies?.map(cookie => `${cookie.name}=${cookie.value}`)
            };
            netLogger.succeed({ downloadedTo: processedConfig.filePath, statusCode: response.statusCode });
            return resp;
          }
          netLogger.succeed(response);
          // 解析响应体（解析失败：框已由 succeed 收尾，仅追加框外错误行）
          let parsed: T;
          try {
            const responseType = processedConfig.responseType;
            if (responseType === 'arraybuffer') {
              // RCP 二进制体直接挂在 body 属性上（无 arrayBuffer() 方法）；
              // 无 body（204/HEAD 等）时与 toJSON 空体语义对齐返回 null，避免 undefined 流入下游
              parsed = (response.body ?? null) as T;
            } else if (responseType === 'text') {
              parsed = response.toString() as T;
            } else {
              parsed = response.toJSON() as T;
            }
          } catch (err) {
            zyLog(hilog.error, `ZyNet response parse error: ${err}`);
            throw await applyErrorPlugins(this.plugins,
              new HttpError('parse', `响应解析失败: ${err}`, response.statusCode, err, processedConfig), ctx);
          }
          const resp: HttpResponse<T> = {
            config: processedConfig,
            data: parsed,
            statusCode: response.statusCode,
            errMsg: response.reasonPhrase,
            cookies: response.cookies?.map(cookie => `${cookie.name}=${cookie.value}`),
            header: response.headers
          };
          // 响应插件链（resolve 前最后一步）
          const finalResp = await applyResponsePlugins(this.plugins, resp, ctx);
          return finalResp as HttpResponse<T>;
        }

        // HTTP 错误（5xx 默认可重试）
        const httpErr = new HttpError('http', response.reasonPhrase || `HTTP ${response.statusCode}`,
          response.statusCode, response, processedConfig);
        if (attempt < retry.count && shouldRetry(retry, httpErr)) {
          attempt++;
          const delay = backoffDelay(retry, attempt - 1);
          netLogger.step('retry', `HTTP ${response.statusCode} · ${attempt}/${retry.count} · ${delay}ms 后重发`, 'warn');
          retry.onRetry?.(attempt, httpErr, delay);
          await sleep(delay);
          continue;
        }
        netLogger.step('statusCode', `${response.statusCode}`, 'error');
        netLogger.failed({ statusCode: response.statusCode }, 'validateStatus 校验未通过');

        throw await applyErrorPlugins(this.plugins, httpErr, ctx);
      }
    } catch (err) {
      // 兜底标准化：各失败路径已收尾日志框，这里仅保证抛出的一定是 HttpError
      throw toHttpError(err, config, false);
    } finally {
      // 清理取消索引
      if (req) {
        this.activeTags.delete(req);
        this.abortedRequests.delete(req);
      }
    }
  }

  // Middleware method
  middleware<T = any>(config: HttpRequestConfig): HttpPromise<T> {
    return this.request(config);
  }

  /**
   * 发起请求并返回调用句柄：promise 为完整 HttpResponse（不做业务解包）；abort() 可取消请求
   * @param config 请求配置（method/url 必须已填充）
   * @returns Call 句柄
   */
  execute<T = ESObject>(config: HttpRequestConfig): Call<HttpResponse<T>> {
    let reqRef: rcp.Request | null = null;
    // 插件链执行期间 abort 的竞态兜底：请求对象尚未创建时先记账，创建回调里立即取消
    let abortedBeforeCreate = false;
    const promise = this.doRequest<T>(config, {
      onRequestCreated: (req: rcp.Request) => {
        reqRef = req;
        if (abortedBeforeCreate) {
          this.abortedRequests.add(req);
          this.session.cancel(req);
        }
      }
    }) as Promise<HttpResponse<T>>;
    return {
      promise: promise,
      abort: () => {
        if (reqRef) {
          this.abortedRequests.add(reqRef);
          this.session.cancel(reqRef);
        } else {
          abortedBeforeCreate = true;
        }
      }
    };
  }

  /**
   * 按 tag 批量取消进行中的请求（如页面销毁时联动取消）
   * @param tag 请求标签
   * @returns 本次实际取消的请求数
   */
  cancelTag(tag: string): number {
    const targets: rcp.Request[] = [];
    this.activeTags.forEach((t: string | undefined, req: rcp.Request) => {
      if (t === tag) {
        targets.push(req);
      }
    });
    if (targets.length > 0) {
      targets.forEach((req: rcp.Request) => this.abortedRequests.add(req));
      this.session.cancel(targets);
    }
    return targets.length;
  }

  /** 取消当前实例全部进行中的请求 */
  cancelAll(): void {
    const targets: rcp.Request[] = [];
    this.activeTags.forEach((_t: string | undefined, req: rcp.Request) => {
      targets.push(req);
    });
    if (targets.length > 0) {
      targets.forEach((req: rcp.Request) => this.abortedRequests.add(req));
      this.session.cancel(targets);
    }
  }

  // 主请求方法
  request<T = any>(config: HttpRequestConfig<RequestTask>): HttpPromise<T> {
    return this.doRequest<T>(config as HttpRequestConfig) as Promise<HttpResponse<T>>;
  }

  // GET 请求
  get<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): HttpPromise<T> {
    return this.request({ ...config, url, method: 'GET' });
  }

  // POST 请求
  post<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): HttpPromise<T> {
    return this.request({
      ...config,
      url,
      method: 'POST'
    });
  }

  // PUT 请求
  put<T = any>(url: string, data?: AnyObject, config?: HttpRequestConfig<RequestTask>): HttpPromise<T> {
    return this.request({
      ...config,
      url,
      data,
      method: 'PUT'
    });
  }

  // DELETE 请求
  delete<T = any>(url: string, data?: AnyObject, config?: HttpRequestConfig<RequestTask>): HttpPromise<T> {
    return this.request({
      ...config,
      url,
      data,
      method: 'DELETE'
    });
  }

  /**
   * 上传（multipart）：config.name + config.filePath 组成文件字段，formData/multipartFields 为文本字段，
   * 进度回调经 config.onUploadProgress；内部统一走 doRequest（插件链/重试/取消/日志框全量可用）
   * @param url 上传接口地址
   * @param config 上传配置
   * @returns 上传响应
   */
  upload<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): Promise<HttpUploadResponse> {
    const cfg: HttpRequestConfig = { ...(config || {}), url: url, method: 'POST' } as HttpRequestConfig;
    return this.doRequest<T>(cfg).then((resp: HttpResponse<T> | HttpDownloadResponse) => {
      const r = resp as HttpResponse<T>;
      return {
        config: r.config as HttpRequestConfig,
        data: r.data,
        statusCode: r.statusCode,
        errMsg: r.errMsg
      };
    });
  }

  /**
   * 下载到文件：config.filePath 为目标路径（folder 语义），
   * 支持断点续传（config.transferRange）与进度回调（config.onDownloadProgress）；
   * 内部经 fetch + configuration.destination，统一错误模型与日志框
   * @param url 下载地址
   * @param config 下载配置
   * @returns 下载响应（含 tempFilePath）
   */
  download(url: string, config?: HttpRequestConfig<RequestTask>): Promise<HttpDownloadResponse> {
    const cfg: HttpRequestConfig = { ...(config || {}), url: url, method: config?.method || 'GET' } as HttpRequestConfig;
    const destination: rcp.DownloadToFile = {
      kind: 'folder',
      path: cfg.filePath
    } as rcp.DownloadToFile;
    return this.doRequest(cfg, { destination: destination }) as Promise<HttpDownloadResponse>;
  }
}

class HttpRequest extends HttpRequestAbstract {
  setConfig(f: (config: HttpRequestConfig) => HttpRequestConfig): void {
    this.config = f(this.config);
  }
}

// 导出类型
export type {
  AnyObject,
  ApiPromise,
  Call,
  HttpPromise,
  HttpRequestConfig,
  HttpResponse,
  HttpUploadResponse,
  HttpDownloadResponse,
  InterceptorContext,
  MultipartFileSpec,
  NetInterceptor,
  RequestTask,
  RetryConfig,
  ApiResponse
} from './Index';

export default HttpRequest;
