import { rcp } from '@kit.RemoteCommunicationKit';
import { ZyDnsConfig, ZySecurityConfig } from '../util/ZyTranslate';
import { ZyHttpCache } from '../cache/ZyHttpCache';
import { ZyMiddleware } from '../middleware/ZyMiddleware';
import { ZyHttpError } from '../error/ZyHttpError';

/**
 * 响应体解析类型
 * - 'json':       响应体 JSON.parse 为对象(默认)
 * - 'text':       响应体转字符串
 * - 'arraybuffer': 响应体保持原始 ArrayBuffer
 */
export type ZyResponseType = 'json' | 'text' | 'arraybuffer';

/**
 * 超时配置(官方 rcp.Timeout 三元组, 单位 ms)
 * - connectMs:    建连超时(含 DNS/TCP/TLS)
 * - transferMs:   传输超时(请求发出到响应完成)
 * - inactivityMs: 无活动超时(连接空闲无数据的最长等待)
 */
export interface ZyTimeout {
  connectMs?: number;
  transferMs?: number;
  inactivityMs?: number;
}

/**
 * 重试配置(指数退避)
 * - maxRetries: 最大重试次数(不含首次请求)
 * - initialIntervalMs: 首次重试间隔(ms)
 * - maxIntervalMs: 重试间隔上限(ms, 指数退避封顶)
 * - retryOn: 自定义重试判定(默认: 网络类可重试错误才重试, 取消/环境/配置类不重试)
 */
export interface ZyRetry {
  maxRetries?: number;
  initialIntervalMs?: number;
  maxIntervalMs?: number;
  retryOn?: (error: ZyHttpError) => boolean;
}

/**
 * 业务码校验器签名
 * @param data 已解析的响应体对象
 * @returns true 表示业务成功; false 将抛出 ZyHttpError(kind='business')
 */
export type ZyBusinessCodeHandler = (data: ESObject) => boolean;

/**
 * HTTP 状态码校验器签名
 * @param status HTTP 状态码
 * @returns true 表示通过; false 将抛出 ZyHttpError(kind='http')
 */
export type ZyValidateStatus = (status: number) => boolean;

/**
 * 日志出口签名(注入宿主日志系统, 如 hilog/LogManager; 不注入时走 console)
 * @param level 日志级别
 * @param msg 日志内容(含 #0001 请求 ID)
 */
export type ZyHttpLogger = (level: 'debug' | 'info' | 'warn' | 'error', msg: string) => void;

/**
 * ZyHttp 实例配置(实例级默认值, 请求级可通过 builder 覆盖)
 * 一个 ZyHttp 实例对应一个底层 rcp.Session(懒创建, close() 释放);
 * 多组会话级配置(DNS/安全/缓存等)请创建多个 ZyHttp 实例
 */
export interface ZyHttpConfig {
  /** URL 基地址(官方 baseAddress: builder.path() 的相对路径将自动拼接在基地址前) */
  baseURL?: string;
  /** 实例级默认请求头(与请求级 builder.header() 合并, 同名以请求级优先) */
  headers?: Map<string, string>;
  /** 实例级默认 query 参数(公共参数如 token/version 注入点; 与请求级 builder.query() 合并, 同名以请求级优先) */
  params?: Map<string, string>;
  /** 默认超时(官方 Timeout 三元组) */
  timeout?: ZyTimeout;
  /** 默认重试策略(指数退避) */
  retry?: ZyRetry;
  /** 默认响应体解析类型(默认 'json') */
  responseType?: ZyResponseType;
  /** 中间件(洋葱模型, 详见 ZyMiddleware) */
  middlewares?: ZyMiddleware[];
  /** 结构化日志开关(开启后注册内置日志中间件, 输出请求/响应/耗时摘要) */
  logging?: boolean;
  /** 日志出口(注入宿主日志系统; 不注入时内置日志走 console) */
  logger?: ZyHttpLogger;
  /** DNS 定制(会话级) */
  dns?: ZyDnsConfig;
  /** 安全配置(会话级: 证书校验/TLS 版本/证书锁定) */
  security?: ZySecurityConfig;
  /** 性能维测(会话级: verbose 日志/时间信息采集/事件回调) */
  tracing?: rcp.TracingConfiguration;
  /** HTTP 缓存(官方 ResponseCache 封装, 遵循 RFC 9111, API 20+) */
  cache?: ZyHttpCache;
}

// 防止 rcp.TracingConfiguration 在类型检查时的孤立引用告警(显式依赖 rcp 类型)
export type ZyTracingConfig = rcp.TracingConfiguration;
