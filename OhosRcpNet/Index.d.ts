import { rcp } from '@kit.RemoteCommunicationKit';

export type AnyObject = Record<string | number | symbol, any>;
export type HttpPromise<T> = Promise<HttpResponse<T>>;
export type ApiPromise<T> = Promise<ApiResponse<T>>;
export interface RequestTask {
  abort: () => void;
  offHeadersReceived: () => void;
  onHeadersReceived: () => void;
}
export type Tasks = RequestTask;

/**
 * multipart 文件字段描述（配合 multipartFields 或 upload() 使用）
 * path 与 content 二选一：path 为本地文件路径；content 直接给定文件内容
 */
export interface MultipartFileSpec {
  /** multipart 中的字段名（服务端按此名取文件） */
  name: string;
  /** 本地文件路径（与 content 二选一） */
  path?: string;
  /** 直接给定的文件内容（与 path 二选一） */
  content?: string | ArrayBuffer;
  /** 上传后服务端看到的文件名；缺省取 path 的最后一段 */
  remoteFileName?: string;
  /** 文件 MIME 类型（如 image/png） */
  contentType?: string;
}

/**
 * 重试配置：指数退避（delayMs * 2^attempt，封顶 maxDelayMs）
 * 默认仅对网络错误（kind='network'）与 5xx HTTP 错误重试，cancel/parse 永不重试
 */
export interface RetryConfig {
  /** 重试次数（不含首次请求） */
  count: number;
  /** 首次重试延迟（毫秒，默认 500） */
  delayMs?: number;
  /** 单次重试延迟上限（毫秒，默认 8000） */
  maxDelayMs?: number;
  /** 触发重试的错误类别（默认 network + http(5xx)） */
  retryOn?: ('network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown')[];
  /** 重试前钩子：在 sleep(delayMs) 前调用；不重走插件链（重试复用首次已签名的同一 rcp.Request） */
  onRetry?: (attempt: number, error: HttpError, delayMs: number) => void;
}

export interface HttpRequestConfig<T = Tasks> {
  /** 请求基地址 */
  baseURL?: string;
  /** 请求服务器接口地址 */
  url?: string;
  /** 请求查询参数，自动拼接为查询字符串 */
  params?: AnyObject;
  /** 请求体参数（对象由 RCP 序列化为 JSON；字符串原样发送，可配合 header 的 content-type） */
  data?: AnyObject;
  /** 文件对应的 key（upload() 使用，与 filePath 配套） */
  name?: string;
  /** HTTP 请求中其他额外的 form data（upload() 时合并进 multipart 文本字段） */
  formData?: AnyObject;
  /** 要上传文件资源的路径（upload() 使用）；download() 时作为下载目标路径 */
  filePath?: string;
  /** 请求头信息 */
  header?: AnyObject;
  /** 请求方式 */
  method?: "GET" | "POST" | "PUT" | "DELETE" | "CONNECT" | "HEAD" | "OPTIONS" | "TRACE" | "UPLOAD" | "DOWNLOAD" | (string & NonNullable<unknown>);
  /** 设置响应的数据类型，支付宝小程序不支持 */
  responseType?: "text" | "arraybuffer";
  /** 自定义参数（tokenSpec 等库内部通道也存放于此） */
  custom?: AnyObject;
  /** 超时时间（毫秒）：未细分时同时作为连接与传输超时 */
  timeout?: number;
  /** 连接超时（毫秒），缺省取 timeout */
  connectTimeout?: number;
  /** 传输超时（毫秒），缺省取 timeout */
  transferTimeout?: number;
  /** 重试配置：number 等价 { count }；缺省不重试 */
  retry?: number | RetryConfig;
  /** 请求标签：可调用 cancelTag(tag) 批量取消同标签的进行中请求 */
  tag?: string;
  /** 纯净请求开关：true 时跳过全部插件注入（签名/公共头等），业务完全掌控请求内容 */
  raw?: boolean;
  /** 跳过指定名称的插件（配合 NetInterceptor.name），如 ['sign'] */
  skip?: string[];
  /** DNS解析时优先使用ipv4 @deprecated RCP dns 透传已可通过 dns 配置实现 */
  firstIpv4?: boolean;
  /** 验证 ssl 证书；false 时映射 RCP remoteValidation='skip' */
  sslVerify?: boolean;
  /** TLS 配置（RCP 透传：'system' | 加密套件数组 | TlsV1xOption，如 { tlsVersion: 'TlsV1.2' }）；sslVerify=false 时自动 remoteValidation='skip' */
  tlsOptions?: rcp.SecurityConfiguration['tlsOptions'];
  /** 代理配置（rcp.ProxyConfiguration 透传：'system' | 'no-proxy' | WebProxy） */
  proxy?: rcp.ProxyConfiguration;
  /** DNS 配置（rcp.DnsConfiguration 透传，HTTPDNS 场景） */
  dns?: rcp.DnsConfiguration;
  /** 跨域请求时是否携带凭证（cookies） @deprecated 本阶段不接 Cookie 管理，请使用 Session automaticCookieManagement */
  withCredentials?: boolean;
  /** 返回当前请求的task, options。请勿在此处修改options。 @deprecated async 模型无同步 task 回调语义 */
  getTask?: (task: T, options: HttpRequestConfig<T>) => void;
  /**  全局自定义验证器 */
  validateStatus?: (statusCode: number) => boolean | void;
  /** multipart 文本字段（配合 multipartFiles 或 upload()） */
  multipartFields?: AnyObject;
  /** multipart 文件字段列表 */
  multipartFiles?: MultipartFileSpec[];
  /** 原始请求体（string/ArrayBuffer 原样发送，配合 header 的 content-type；优先级高于 data） */
  rawBody?: string | ArrayBuffer;
  /** 传输范围（断点续传 Range），透传 rcp.Request.transferRange */
  transferRange?: rcp.TransferRange | rcp.TransferRange[];
  /** 上传进度回调：transferredSize 已传字节 / totalSize 总字节 */
  onUploadProgress?: (transferredSize: number, totalSize: number) => void;
  /** 下载进度回调：transferredSize 已收字节 / totalSize 总字节 */
  onDownloadProgress?: (transferredSize: number, totalSize: number) => void;
}

export interface ApiResponse<T = any> {
  code: number
  data?: T;
  message: string
}
export interface HttpResponse<T = any> {
  config?: HttpRequestConfig;
  statusCode: number;
  data: T;
  errMsg: string;
  cookies: Array<string>;
  header: AnyObject;
}
export interface HttpUploadResponse<T = any> {
  config: HttpRequestConfig;
  statusCode: number;
  data: T;
  errMsg: string;
}
export interface HttpDownloadResponse extends HttpResponse {
  tempFilePath: string;
}

/**
 * 统一错误模型：所有请求失败（网络异常/HTTP 状态码错误/解析失败/取消/业务码拦截/未知）都以此结构 reject，
 * 业务侧 catch 收到的永远是 HttpError，不再混杂 BusinessError 或原始 Response
 */
export declare class HttpError extends Error {
  /** 错误类别：network 网络异常 / http HTTP状态码错误 / parse 解析失败 / cancel 已取消 / business 业务码拦截 / unknown 未知 */
  kind: 'network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown';
  /** HTTP 状态码（kind='http' 时有值） */
  statusCode?: number;
  /** 原始错误对象（BusinessError / Response 等，便于深度排查） */
  cause?: ESObject;
  /** 发起请求时的配置快照（便于上报与重试） */
  config?: ESObject;
  constructor(kind: 'network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown', message: string, statusCode?: number, cause?: ESObject, config?: ESObject);
}

/**
 * 拦截器上下文：随插件钩子传递，提供本次请求的日志框句柄
 */
export interface InterceptorContext {
  /** 本次请求日志框；插件可 step() 写入框内信息（并发时自动携带 #ID 前缀） */
  logger: ZyNetLogger | null;
}

/**
 * 库级拦截器插件（可插拔、支持异步）：
 * - onRequest 按注册顺序依次执行，前一个的返回值作为下一个的输入
 * - onResponse / onError 在响应返回 / 失败 reject 前依次执行
 * - 插件内部异常不会中断请求（仅打印 error 日志）
 * - 通过 config.skip 或 config.raw 可按请求粒度跳过指定插件
 */
export interface NetInterceptor {
  /** 插件名：skip(['name']) 按此名称跳过 */
  name: string;
  /** 请求拦截：返回修改后的配置（支持异步） */
  onRequest?: (config: HttpRequestConfig, ctx: InterceptorContext) => HttpRequestConfig | Promise<HttpRequestConfig>;
  /** 响应拦截：返回处理后的响应（支持异步） */
  onResponse?: (response: HttpResponse, ctx: InterceptorContext) => HttpResponse | Promise<HttpResponse>;
  /** 错误拦截：可替换/包装最终 reject 的 HttpError（支持异步） */
  onError?: (error: HttpError, ctx: InterceptorContext) => HttpError | Promise<HttpError>;
}

/**
 * 请求调用句柄（execute() 返回）：
 * promise 为请求结果；abort() 取消进行中的请求（reject HttpError kind='cancel'）
 */
export interface Call<T = ESObject> {
  /** 请求结果 Promise */
  promise: Promise<T>;
  /** 取消本次请求 */
  abort: () => void;
}

export declare class RequestInterceptor implements rcp.Interceptor {
  onFulfilled?: (config?: HttpRequestConfig) => HttpRequestConfig;
  onRejected?: (error: any) => any;
  constructor(onFulfilled?: (config: HttpRequestConfig) => HttpRequestConfig, onRejected?: (error: any) => any);
  intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response>;
}
export declare class ResponseInterceptor implements rcp.Interceptor {
  onFulfilled?: (response?: HttpResponse) => HttpResponse;
  onRejected?: (error: any) => any;
  constructor(onFulfilled?: (response: HttpResponse) => HttpResponse, onRejected?: (error: any) => any);
  intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response>;
}
/**
 * 开启/关闭 RequestInterceptor.intercept 的调试日志输出
 * @param enabled true 开启 / false 关闭（默认关闭）
 */
export declare function setInterceptLogEnabled(enabled: boolean): void;
/**
 * 开启/关闭网络日志全局开关（覆盖请求日志框与 [CACHE] 等库内日志）
 * @param enabled true 开启（默认）/ false 关闭（error 级日志仍输出）
 */
export declare function setNetLogEnabled(enabled: boolean): void;
/**
 * 配置日志脱敏（全局生效）
 * @param on true 开启脱敏 / false 关闭（默认）
 * @param keys 参与脱敏的字段名集合；不传时沿用默认集合
 */
export declare function setNetLogMask(on: boolean, keys?: string[]): void;
/**
 * 判断某请求配置是否跳过指定插件（raw 视为跳过全部）
 * @param config 请求配置
 * @param pluginName 插件名
 */
export declare function isSkipped(config: HttpRequestConfig | undefined, pluginName: string): boolean;
/**
 * 判断某请求配置是否为纯净请求（raw=true）
 * @param config 请求配置
 */
export declare function isRaw(config: HttpRequestConfig | undefined): boolean;
/**
 * 统一日志输出：以明文（%{public}s）经 hilog 打印（domain=0x5A59，tag='ZYNetLog'）
 * @param level hilog 级别方法（hilog.debug/info/warn/error）
 * @param msg 已拼接好的日志内容
 */
export declare function zyLog(level: (domain: number, tag: string, format: string, ...args: ESObject[]) => void, msg: string): void;
/** 日志级别名：日志行级别以枚举传递，输出时显式映射到 hilog 对应方法 */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/**
 * 网络请求日志框：为每次请求生成唯一自增 ID（如 #000A），
 * 并发多个请求时通过 ID 在控制台区分各自的请求/响应/耗时日志
 */
export declare class ZyNetLogger {
  constructor(method: string, url: string);
  /** 注册"当前请求"logger（仅限同步钩子窗口，如请求拦截器执行期间），钩子执行完毕后传 null 注销 */
  static setCurrent(logger: ZyNetLogger | null): void;
  /** 获取"当前请求"logger（同步钩子窗口内可取到；异步回调中返回 null） */
  static getCurrent(): ZyNetLogger | null;
  /** 开启/关闭 JSON 格式化输出（全局生效）：开启后 params/body/header/data 按 2 空格缩进逐行打印 */
  static setPretty(on: boolean): void;
  /** 打印请求开始框：框头 + baseURL/params/body/header 信息行 */
  begin(info?: ESObject): void;
  /** 框内补充一行信息（如 fullUrl、statusCode）；kind 为级别名，默认 'info' */
  step(key: string, value: string, kind?: LogLevel): void;
  /** 响应成功收尾：耗时分隔行 + data + END 框尾 */
  succeed(data: ESObject): void;
  /** 请求失败收尾：耗时分隔行 + 失败原因 + 错误对象 + END 框尾 */
  failed(err: ESObject, reason?: string): void;
}
export declare abstract class HttpRequestAbstract {
  conf: HttpRequestConfig;
  session: rcp.Session;
  config: HttpRequestConfig;
  requestInterceptor: RequestInterceptor;
  responseInterceptor: ResponseInterceptor;
  constructor(conf: HttpRequestConfig);
  /**
   * 注册库级拦截器插件（链式叠加，按注册顺序执行）
   * @param plugin 拦截器插件
   */
  use(plugin: NetInterceptor): this;
  /**
   * 发起请求并返回调用句柄：promise 为完整 HttpResponse（不做 ResultDTO 解包）；abort() 取消请求
   * @param config 请求配置（method/url 必须已填充）
   */
  execute<T = ESObject>(config: HttpRequestConfig): Call<HttpResponse<T>>;
  /**
   * 按 tag 批量取消进行中的请求（如页面销毁时联动取消）
   * @param tag 请求标签
   * @returns 本次实际取消的请求数
   */
  cancelTag(tag: string): number;
  /** 取消当前实例全部进行中的请求 */
  cancelAll(): void;
  /**
   * 获取底层原生 rcp.Session 实例（逃生舱）：供上层单次使用未封装的原生 RCP 能力
   * （如 downloadToStream/uploadFromStream/fetchForSendable 等）；
   * 会话与 zyClient 共享（连接复用，cancelTag 可取消经此发出的请求）
   */
  getSession(): rcp.Session;
  /**
   * 单次原生 RCP 调用（逃生舱）：将共享 rcp.Session 抛给回调，返回值原样透传，
   * 用于临时实现未封装的原生能力（流式传输、跨线程 Sendable 请求、自定义 Request 等）
   * @param handler 接收 rcp.Session 的回调
   */
  requestNative<T>(handler: (session: rcp.Session) => Promise<T>): Promise<T>;
  middleware<T = any>(config: HttpRequestConfig): HttpPromise<T>;
  request<T = any>(config: HttpRequestConfig): HttpPromise<T>;
  /**
   * @deprecated 传统方法已过时，请改用建造者模式：zyClient.with().urlPath(url).get<T>()
   */
  get<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): HttpPromise<T>;
  /**
   * @deprecated 传统方法已过时，请改用建造者模式：zyClient.with().urlPath(url).post<T>()
   */
  post<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): HttpPromise<T>;
  /**
   * @deprecated 传统方法已过时，请改用建造者模式：zyClient.with().urlPath(url).put<T>()
   */
  put<T = any>(url: string, data?: AnyObject, config?: HttpRequestConfig<RequestTask>): HttpPromise<T>;
  /**
   * @deprecated 传统方法已过时，请改用建造者模式：zyClient.with().urlPath(url).delete<T>()
   */
  delete<T = any>(url: string, data?: AnyObject, config?: HttpRequestConfig<RequestTask>): HttpPromise<T>;
  upload<T = any>(url: string, config?: HttpRequestConfig<RequestTask>): Promise<HttpUploadResponse>;
  download(url: string, config?: HttpRequestConfig<RequestTask>): Promise<HttpDownloadResponse>;
}
declare class HttpRequest extends HttpRequestAbstract {
  setConfig(f: (config: HttpRequestConfig) => HttpRequestConfig): void;
}
export default HttpRequest;
