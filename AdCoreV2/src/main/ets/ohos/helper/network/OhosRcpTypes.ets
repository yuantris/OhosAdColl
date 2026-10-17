/**
 * OhosRcp 对外类型层（引擎已切换 2.0，类型签名与 1.x 保持一致）
 */

// ZyNetLogger/ZyCancelToken/ZyHttpError 仅为类型引用（运行时从 @creative/net 导入）
import { ZyNetLogger, ZyCancelToken, ZyHttpError } from '@creative/net';

/** 任意对象类型 */
export type AnyObject = Record<string, ESObject>;

/** 业务 code 类型（兼容 number/string） */
export type BusinessCode = number | string;

/**
 * 断点续传范围规格（1.x 语义：from 到 to 字节区间）
 */
export interface TransferRangeSpec {
  /** 起始字节（含） */
  from?: number;
  /** 结束字节（含） */
  to?: number;
}

/**
 * 请求配置（1.x HttpRequestConfig 语义，字段全集保留）
 */
export interface HttpRequestConfig {
  /** 请求路径（相对 baseURL 的路径或完整 URL） */
  url?: string;
  /** HTTP 方法（大写） */
  method?: string;
  /** 请求基地址（未设置时实时读取全局 baseUrl） */
  baseURL?: string;
  /** 总超时（毫秒，作为传输超时兜底） */
  timeout?: number;
  /** 连接超时（毫秒） */
  connectTimeout?: number;
  /** 传输超时（毫秒） */
  transferTimeout?: number;
  /** 查询参数 */
  params?: Record<string, string | number | boolean | null | undefined>;
  /** 请求头 */
  header?: Record<string, string>;
  /** 请求体（对象/字符串/二进制） */
  data?: ESObject;
  /** 原始请求体（string/ArrayBuffer 原样发送） */
  rawBody?: string | ArrayBuffer;
  /** multipart 文本字段 */
  multipartFields?: Record<string, ESObject>;
  /** multipart 文件列表 */
  multipartFiles?: MultipartFileSpec[];
  /** 下载目标路径（downloadTo） */
  filePath?: string;
  /** 上传文件字段名（默认 'file'） */
  name?: string;
  /** 响应体解析类型 */
  responseType?: 'json' | 'text' | 'arraybuffer';
  /** 断点续传范围（字节） */
  transferRange?: TransferRangeSpec;
  /** 上传进度回调 */
  onUploadProgress?: (transferredSize: number, totalSize: number) => void;
  /** 下载进度回调 */
  onDownloadProgress?: (transferredSize: number, totalSize: number) => void;
  /** 取消标签（配合 cancelTag 批量取消） */
  tag?: string;
  /** 取消令牌（execute() abort 透传引擎；builder.cancelToken 生效） */
  cancelToken?: ZyCancelToken;
  /** 重试次数或完整配置 */
  retry?: number | RetryConfig;
  /** 纯净请求：跳过全部插件注入/缓存/解包 */
  raw?: boolean;
  /** 跳过指定插件名列表 */
  skip?: string[];
  /** 透传扩展字段（如 tokenSpec） */
  custom?: Record<string, ESObject>;
}

/**
 * 重试配置（1.x 语义：指数退避）
 */
export interface RetryConfig {
  /** 重试次数 */
  count?: number;
  /** 首次重试间隔（毫秒） */
  interval?: number;
  /** 重试间隔上限（毫秒） */
  maxInterval?: number;
  /** 自定义重试判定：返回 true 才重试 */
  retryOn?: (err: ZyHttpError) => boolean;
}

/**
 * HTTP 响应（1.x 语义）
 */
export interface HttpResponse<T = ESObject> {
  /** HTTP 状态码 */
  statusCode: number;
  /** 响应体（已按 responseType 解析） */
  data: T;
  /** 响应头 */
  headers: Record<string, string | string[]>;
  /** 下载落盘路径（downloadTo 场景） */
  tempFilePath?: string;
}

/** 下载响应（含落盘路径） */
export type HttpDownloadResponse = HttpResponse<ESObject>;

/** @deprecated 上传响应暂无独立用途，请直接使用 HttpResponse<T> */
export type HttpUploadResponse = HttpResponse<ESObject>;

/**
 * 统一错误类型（兼容别名，底层已统一为 ZyHttpError）
 * ZyHttpError 新增字段：retryable / statusCode / errorFields
 * 业务体通过 cause 字段传递（原 data 参数映射到 cause）
 */
export type HttpError = ZyHttpError;

/**
 * 调用句柄：promise + abort（1.x Call 语义）
 */
export interface Call<T> {
  /** 请求 Promise（resolve 完整 HttpResponse） */
  promise: Promise<T>;
  /** 取消请求（reject HttpError kind='cancel'） */
  abort(): void;
}

/**
 * @deprecated 已迁移至 ZyMiddleware 洋葱模型，NetInterceptor 不再参与请求管线。
 * 保留类型以兼容存量代码，新代码请使用 @creative/net 的 ZyMiddleware
 */
export interface InterceptorContext {
  /** 当前请求日志框（ZyNetLogger） */
  logger?: ZyNetLogger | null;
}

/**
 * @deprecated 已迁移至 ZyMiddleware 洋葱模型，NetInterceptor 不再参与请求管线。
 * 保留类型以兼容存量代码，新代码请使用 @creative/net 的 ZyMiddleware
 */
export interface NetInterceptor {
  /** 插件名（skip(name) 与 isSkipped 按此匹配） */
  name: string;
  /** 请求钩子：同步执行，返回新 config（或原地修改后返回） */
  onRequest?: (config: HttpRequestConfig, ctx: InterceptorContext) => HttpRequestConfig;
  /** 响应钩子（保留扩展位） */
  onResponse?: (response: HttpResponse, ctx: InterceptorContext) => HttpResponse;
  /** 错误钩子（保留扩展位） */
  onError?: (err: ZyHttpError, ctx: InterceptorContext) => void;
}

/**
 * multipart 文件规格（1.x 语义）
 */
export interface MultipartFileSpec {
  /** 文件字段名（默认 'file'） */
  name?: string;
  /** 本地文件路径 */
  filePath: string;
  /** 文件名（服务端收到的文件名，缺省取路径末段） */
  fileName?: string;
  /** MIME 类型 */
  mimeType?: string;
}
