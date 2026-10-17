import { rcp } from '@kit.RemoteCommunicationKit';
import { ZyResponseType, ZyTimeout, ZyRetry, ZyBusinessCodeHandler, ZyValidateStatus } from './ZyHttpConfig';
import { ZyCancelToken } from './ZyCancelToken';
import { ZyHttpRequestInternal } from './ZyHttpRequestInternal';
import { ZyHttp } from './ZyHttp';
import { ZyHttpResponse } from './ZyHttpResponse';
import { ZyHttpError } from '../error/ZyHttpError';

/**
 * 请求构建器(OkHttp Builder 风格链式 API)
 * 由 ZyHttp.newBuilder() 创建, 继承实例级默认配置; 每个方法返回 this 支持链式调用
 *
 * 使用示例:
 *   const resp = await http.newBuilder()
 *     .path('/v1/user').query('id', '1')
 *     .header('X-Trace', 'abc')
 *     .jsonBody({ page: 1 })
 *     .timeout(6000, 10000).retry(3, 500)
 *     .businessCode((body: ESObject): boolean => body?.code === 0)
 *     .cancelToken(token)
 *     .get<UserDTO>();
 *   resp.data  // UserDTO
 */
export class ZyRequestBuilder {
  private http: ZyHttp;
  private httpMethod: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD';
  /** 路径或完整 URL(相对路径走 baseURL; 'http(s)://' 开头视为绝对 URL) */
  private pathOrUrl: string = '/';
  /** query 参数(有序) */
  private queries: Map<string, string> = new Map<string, string>();
  /** 请求头(请求级增量) */
  private headers: Map<string, string> = new Map<string, string>();
  private content?: rcp.RequestContent;
  private _responseType?: ZyResponseType;
  private _timeout?: ZyTimeout;
  private _retry?: ZyRetry;
  private businessCodeHandler?: ZyBusinessCodeHandler;
  private _validateStatus?: ZyValidateStatus;
  private _cancelToken?: ZyCancelToken;
  private _tag?: string;
  private _skipNames: string[] = new Array<string>();
  private collectTimeInfo?: boolean;
  private _custom?: Record<string, ESObject>;

  /**
   * @param http 所属 ZyHttp 实例(执行与配置解析)
   * @param method HTTP 方法
   */
  constructor(http: ZyHttp, method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD') {
    this.http = http;
    this.httpMethod = method;
  }

  /**
   * 覆盖请求方法(默认由 newBuilder 创建时的 method 决定;
   * 供上层引擎按 cfg.method 动态指定, 支持 rcp 全量 HttpMethod: GET/POST/PUT/DELETE/HEAD/PATCH/OPTIONS...)
   * @param m HTTP 方法(大写)
   */
  method(m: string): ZyRequestBuilder {
    this.httpMethod = m as 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD';
    return this;
  }

  /**
   * 设置请求路径(相对路径拼接 baseURL; 传 'https://...' 完整 URL 则绕过 baseURL)
   * @param path 路径或完整 URL
   */
  path(path: string): ZyRequestBuilder {
    this.pathOrUrl = path;
    return this;
  }

  /**
   * 追加 query 参数(可多次调用; 值将 URL 编码)
   * @param name 参数名
   * @param value 参数值
   */
  query(name: string, value: string): ZyRequestBuilder {
    this.queries.set(name, value);
    return this;
  }

  /**
   * 设置请求头(同名覆盖; 实例默认头由 DefaultHeaderMiddleware 注入且不被覆盖)
   * @param name 头名称
   * @param value 头值
   */
  header(name: string, value: string): ZyRequestBuilder {
    this.headers.set(name, value);
    return this;
  }

  /**
   * 设置请求体(JSON 对象, 底层序列化; Content-Type 由 rcp 按 bodyType 自动处理)
   * @param body 业务对象
   */
  jsonBody(body: ESObject): ZyRequestBuilder {
    this.content = body;
    return this;
  }

  /**
   * 设置请求体(字符串: json 文本/form-urlencoded 均由调用方组装)
   * @param body 字符串体
   */
  textBody(body: string): ZyRequestBuilder {
    this.content = body;
    return this;
  }

  /**
   * 设置请求体(二进制: ArrayBuffer)
   * @param body 二进制体
   */
  binaryBody(body: ArrayBuffer): ZyRequestBuilder {
    this.content = body;
    return this;
  }

  /**
   * 设置请求体(官方 rcp.Form 表单)
   * @param form 官方表单对象(new rcp.Form(fields))
   */
  formBody(form: rcp.Form): ZyRequestBuilder {
    this.content = form;
    return this;
  }

  /**
   * 设置请求体(官方 rcp.MultipartForm 多部件表单)
   * @param form 官方多部件对象(new rcp.MultipartForm(fields))
   */
  multipartBody(form: rcp.MultipartForm): ZyRequestBuilder {
    this.content = form;
    return this;
  }

  /**
   * 设置响应体解析类型(默认继承实例配置, 实例默认 'json')
   * @param type 解析类型
   */
  responseType(type: ZyResponseType): ZyRequestBuilder {
    this._responseType = type;
    return this;
  }

  /**
   * 设置超时(ms; 不传的维度沿用官方默认)
   * @param connectMs 建连超时
   * @param transferMs 传输超时
   * @param inactivityMs 无活动超时
   */
  timeout(connectMs?: number, transferMs?: number, inactivityMs?: number): ZyRequestBuilder {
    const t: ZyTimeout = {
      connectMs: connectMs,
      transferMs: transferMs,
      inactivityMs: inactivityMs
    };
    this._timeout = t;
    return this;
  }

  /**
   * 设置重试(指数退避)
   * @param maxRetries 最大重试次数
   * @param initialIntervalMs 首次重试间隔(ms)
   * @param maxIntervalMs 间隔上限(ms)
   */
  retry(maxRetries: number, initialIntervalMs: number = 500, maxIntervalMs: number = 8000): ZyRequestBuilder {
    const r: ZyRetry = {
      maxRetries: maxRetries,
      initialIntervalMs: initialIntervalMs,
      maxIntervalMs: maxIntervalMs
    };
    this._retry = r;
    return this;
  }

  /**
   * 自定义重试判定(覆盖默认: 仅网络类可重试错误重试)
   * @param retryOn 判定函数
   */
  retryOn(retryOn: (error: ZyHttpError) => boolean): ZyRequestBuilder {
    if (this._retry === undefined) {
      this._retry = { maxRetries: 3, initialIntervalMs: 500, maxIntervalMs: 8000 };
    }
    this._retry.retryOn = retryOn;
    return this;
  }

  /**
   * 设置业务码校验(false → ZyHttpError(kind='business'))
   * @param handler 校验器
   */
  businessCode(handler: ZyBusinessCodeHandler): ZyRequestBuilder {
    this.businessCodeHandler = handler;
    return this;
  }

  /**
   * 自定义 HTTP 状态码校验(默认 2xx 通过)
   * @param validator 校验器
   */
  validateStatus(validator: ZyValidateStatus): ZyRequestBuilder {
    this._validateStatus = validator;
    return this;
  }

  /**
   * 绑定取消令牌(调用 token.cancel() 取消本请求)
   * @param token 取消令牌
   */
  cancelToken(token: ZyCancelToken): ZyRequestBuilder {
    this._cancelToken = token;
    return this;
  }

  /**
   * 设置取消标签(供 ZyHttp.cancelTag(tag) 批量取消)
   * @param tag 标签名
   */
  tag(tag: string): ZyRequestBuilder {
    this._tag = tag;
    return this;
  }

  /**
   * 跳过指定中间件(按 name 匹配, 等价 1.x 的 skip 能力)
   * 内置中间件名: 'default-header'(默认头) / 'log'(日志) / 'sign'(签名, 若注册)
   * @param names 要跳过的中间件名列表
   */
  skip(names: string[]): ZyRequestBuilder {
    for (const name of names) {
      this._skipNames.push(name);
    }
    return this;
  }

  /**
   * 开启时间信息采集(响应 time 指标可用)
   */
  enableTimeInfo(): ZyRequestBuilder {
    this.collectTimeInfo = true;
    return this;
  }

  /**
    * 请求级自定义数据(中间件可通过 ZyMiddlewareContext.custom 读取)
    * @param data 自定义键值对
    */
  custom(data: Record<string, ESObject>): ZyRequestBuilder {
    this._custom = data;
    return this;
  }

  /**
    * 构建内部请求对象(高级用法: 直接交 ZyHttp.execute 执行或自定义执行器)
    * @returns 内部请求(url 已拼接 query)
    */
  build(): ZyHttpRequestInternal {
    const req: ZyHttpRequestInternal = this.http.buildRequest(this.httpMethod, this.pathOrUrl, this.queries,
      this.headers, this.content, this._responseType, this._timeout, this._retry, this.businessCodeHandler,
      this._validateStatus, this._cancelToken, this._tag, this.collectTimeInfo);
    req.skipNames = this._skipNames;
    req.custom = this._custom;
    return req;
  }

  /**
   * 发起 GET 请求
   * @returns 统一响应(data 为解析后业务数据)
   */
  async get<T>(): Promise<ZyHttpResponse<T>> {
    this.httpMethod = 'GET';
    return this.http.execute<T>(this.build());
  }

  /**
   * 发起 POST 请求
   * @returns 统一响应
   */
  async post<T>(): Promise<ZyHttpResponse<T>> {
    this.httpMethod = 'POST';
    return this.http.execute<T>(this.build());
  }

  /**
   * 发起 PUT 请求
   * @returns 统一响应
   */
  async put<T>(): Promise<ZyHttpResponse<T>> {
    this.httpMethod = 'PUT';
    return this.http.execute<T>(this.build());
  }

  /**
   * 发起 DELETE 请求
   * @returns 统一响应
   */
  async delete<T>(): Promise<ZyHttpResponse<T>> {
    this.httpMethod = 'DELETE';
    return this.http.execute<T>(this.build());
  }

  /**
   * 发起 HEAD 请求
   * @returns 统一响应(无响应体)
   */
  async head<T>(): Promise<ZyHttpResponse<T>> {
    this.httpMethod = 'HEAD';
    return this.http.execute<T>(this.build());
  }
}
