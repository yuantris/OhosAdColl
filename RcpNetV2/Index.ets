import { ZyMiddleware, DefaultHeaderMiddleware, LoggingMiddleware, SignMiddleware }
from './src/main/ets/middleware/ZyMiddleware';

/**
 * @creative/net 2.0.0 (RcpNetV2)
 * 基于 Remote Communication Kit 的现代底层网络请求库(完全破坏性重构, 与 1.x 无兼容关系)
 * 架构: ZyHttp 实例(单实例单Session) + Builder 链式 API + 泛型响应 ZyHttpResponse<T>
 *       + 洋葱中间件(可改写请求/响应/吞错降级) + 句柄式取消(ZyCancelToken)
 *       + 指数退避重试(官方错误码分类) + HTTP 缓存(RFC 9111, API 20+)
 *       + 时间维测(TimeInfo 派生) + URPC 高性能 RPC
 */

// ===== 核心引擎 =====
export { ZyHttp } from './src/main/ets/core/ZyHttp';
export { ZyRequestBuilder } from './src/main/ets/core/ZyRequestBuilder';
export { ZyHttpRequestInternal } from './src/main/ets/core/ZyHttpRequestInternal';
export { ZyHttpResponse } from './src/main/ets/core/ZyHttpResponse';
export { ZyCancelToken } from './src/main/ets/core/ZyCancelToken';
export { ZyHttpConfig, ZyResponseType, ZyTimeout, ZyRetry, ZyHttpLogger,
  ZyBusinessCodeHandler, ZyValidateStatus, ZyTracingConfig } from './src/main/ets/core/ZyHttpConfig';

// ===== 中间件(洋葱模型, 2.0 中拦截器的对应物) =====
export { ZyMiddleware, ZyMiddlewareContext, LoggingMiddleware,
  DefaultHeaderMiddleware, SignMiddleware } from './src/main/ets/middleware/ZyMiddleware';

// ===== 1.x 迁移别名(命名兼容层, 能力等价但签名基于洋葱上下文) =====
/**
 * @deprecated 2.0 命名为 ZyMiddleware(onRequest/onResponse/onResponseError 洋葱模型)
 */
export type ZyInterceptor = ZyMiddleware;
/**
 * @deprecated 2.0 命名为 DefaultHeaderMiddleware
 */
export type DefaultHeaderInterceptor = DefaultHeaderMiddleware;
/**
 * @deprecated 2.0 命名为 LoggingMiddleware
 */
export type LoggingInterceptor = LoggingMiddleware;
/**
 * @deprecated 2.0 命名为 SignMiddleware
 */
export type SignInterceptor = SignMiddleware;

// ===== 官方能力翻译层(DNS/安全/时间指标) =====
export { ZyTimeMetrics, computeTimeMetrics, ZyDnsConfig, ZyDnsServer, ZyStaticDnsRule,
  ZySecurityConfig, translateDnsConfig, translateSecurityConfig } from './src/main/ets/util/ZyTranslate';

// ===== 错误体系(六 kind + 官方 66 错误码) =====
export { ZyHttpError, ZyNetErrorKind, ZyNetErrorFields, toZyHttpError }
from './src/main/ets/error/ZyHttpError';
export { ERR_CELLULAR_UNAVAILABLE, getRcpErrorMessage, isCancelRcpCode,
  isEnvironmentRcpCode, isConfigRcpCode, isNonRetryableRcpCode }
from './src/main/ets/error/RcpErrorCodes';

// ===== HTTP 缓存(官方 ResponseCache 封装, 运行时 API 20+ 门控) =====
export { ZyHttpCache, ZyExpirationPolicy, ZyCacheState,
  HTTP_CACHE_MIN_API, isHttpCacheApiSupported } from './src/main/ets/cache/ZyHttpCache';

// ===== URPC 高性能 RPC =====
export { ZyUrpc, ZyUrpcConfig } from './src/main/ets/urpc/ZyUrpc';

// ===== 1.x 日志层兼容(原样移植自 OhosRcpNet logger.ts) =====
export { zyLog, ZY_LOG_DOMAIN, ZY_LOG_TAG, ZyNetLogger, LogLevel,
  setNetLogEnabled, setNetLogMask, setInterceptLogEnabled }
from './src/main/ets/compat/logger';
