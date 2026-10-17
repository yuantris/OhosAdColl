import {
  ZyCancelToken,
  ZyHttp,
  ZyHttpError,
  ZyHttpResponse,
  ZyMiddlewareContext,
  zyLog,
  ZyNetLogger,
  ZySecurityConfig
} from '@creative/net';
import { DEFAULT_BASE_URL } from './APIs';
import { rcp } from '@kit.RemoteCommunicationKit';
import { NetBasic } from './NetBasic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { ContextHolder } from '../../application/ContextHolder';
import {
  AnyObject,
  Call,
  HttpDownloadResponse,
  HttpRequestConfig,
  HttpResponse,
  InterceptorContext,
  MultipartFileSpec,
  NetInterceptor,
  RetryConfig,
  TransferRangeSpec
} from './OhosRcpTypes';
import { ZySignMiddleware } from './SignInterceptor';
import { ZyCacheMiddleware } from './ZyCacheMiddleware';
import { cloneRequestConfig } from './Common';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';

// 转导出库层开关与类型：intercept 调试日志 / 网络日志总开关 / 日志脱敏 / 安全配置(证书锁定)，业务侧可经 adCoreV2 直接调用
export { setInterceptLogEnabled, setNetLogEnabled, setNetLogMask } from '@creative/net';
export type { ZySecurityConfig } from '@creative/net';
export type { Call, NetInterceptor, InterceptorContext, RetryConfig, MultipartFileSpec,
  HttpResponse, HttpDownloadResponse, HttpError, HttpRequestConfig, AnyObject } from './OhosRcpTypes';
export type { ZyHttpError } from '@creative/net';


/** 请求超时时间（毫秒）：等待服务端响应的最大时长，与缓存时间无关 */
const config: HttpRequestConfig = {
  baseURL: DEFAULT_BASE_URL,
  timeout: 5000
}

/**
 * Call 句柄实现类：显式 class 包装 promise 与 abort 回调，
 * 供 execute() 构造 Call 返回值（规避接口对象字面量的 ArkTS 限制）
 */
class CallHandle<T> implements Call<T> {
  /** 请求 Promise（resolve 完整 HttpResponse） */
  promise: Promise<T>
  /** 取消请求 */
  abort: () => void

  /**
   * @param promise 请求 Promise
   * @param abortFn 取消回调
   */
  constructor(promise: Promise<T>, abortFn: () => void) {
    this.promise = promise
    this.abort = abortFn
  }
}

/**
 * 链式构建器可接受的查询参数值类型
 */
type ParamValue = string | number | boolean | null | undefined

/**
 * 缓存时长单位枚举：Builder.cache(duration, unit) 重载使用，换算基准为秒
 */
export enum CacheUnit {
  /** 秒 */
  SECOND = 1,
  /** 分 */
  MINUTE = 60,
  /** 时 */
  HOUR = 3600,
  /** 天 */
  DAY = 86400,
  /** 月（按 30 天计） */
  MONTH = 86400 * 30,
  /** 年（按 365 天计） */
  YEAR = 86400 * 365
}

/**
 * 通用业务响应 DTO（泛型版），与既有非泛型 ResultDto 并存
 *
 * 对齐服务端通用返回结构 { code, message, data }：
 * 链式 Builder 的 get/post/put/delete 内部以 ResultDTO<T> 接收响应体，
 * 自动解包后直接返回其中的 data，因此 .post<QuestionResp>() 的
 * QuestionResp 就是 data 的类型。
 * 该类随 Index.ets 的 export * from OhosRcp 一并对外导出。
 *
 * @template T 业务数据类型（即 data 字段的类型）
 */
export class ResultDTO<T> {
  /** 业务码：number 或 string（兼容服务端不同接口返回类型） */
  code: number | string
  /** 业务消息；Resource 类型支持鸿蒙资源字符串 */
  message: string
  /** 业务数据；调用方通过泛型 T 约束具体类型 */
  data: T | null | undefined

  /**
   * 构造函数，初始化默认值
   */
  constructor() {
    this.code = 0
    this.message = ''
    this.data = undefined
  }
}

/**
 * 业务 code 统一处理器：每个 ResultDTO 结构的响应解包前回调
 * 返回 true 放行（正常 resolve data）；返回 false 拦截（reject HttpError kind='business'），
 * 可用于登录失效全局跳转、黑名单 code 统一弹窗等场景
 */
type BusinessCodeHandler = (code: number | string, body: ESObject) => boolean

/**
 * Mock 模拟规则：match 命中时请求不再发出，直接返回 respond() 的本地数据（测试不依赖后端）
 */
interface MockRule {
  /** 匹配函数：url 为请求地址（相对路径或完整 URL），method 为大写 HTTP 方法 */
  match: (url: string, method: string) => boolean
  /** 返回模拟数据（resolve 给调用方的值） */
  respond: () => ESObject
}

/**
 * runBusiness 单入口可选项
 */
interface RunBusinessOptions {
  /** 缓存时长（秒）：>=0 显式生效；缺省时 GET 用 defaultCacheTime，非 GET 不缓存 */
  cacheSeconds?: number
  /** 是否显式走缓存通道（WithCache 方法传 true）：缺省时长时回落 defaultCacheTime，与旧版 WithCache 语义一致 */
  useCache?: boolean
  /** data 兜底值：响应体缺失或 data 字段缺失（null/undefined）时以该值顶替（仅影响本次返回，不写缓存） */
  fallback?: ESObject
}

// ==================== BSCStorage（白山云 S3 兼容对象存储，AWS Signature V2） ====================

/** BSC 错误码：参数非法（bucket/key/凭证等） */
export const BSC_ERR_PARAM = -3000;
/** BSC 错误码：MD5 计算失败 */
export const BSC_ERR_MD5 = -3001;
/** BSC 错误码：签名计算失败 */
export const BSC_ERR_SIGN = -3002;
/** BSC 错误码：key 编码失败 */
export const BSC_ERR_ENCODE = -3003;
/** BSC 错误码：网络请求失败（含非 2xx 响应，statusCode 携带 HTTP 状态码） */
export const BSC_ERR_NETWORK = -3004;

/** BSCStorage 默认存储域名（对齐 Java sEndpoint 默认值 ss.bscstorage.com） */
export const BSC_DEFAULT_HOST = 'ss.bscstorage.com';

/** BSC canned ACL：私有读写（仅 owner） */
export const BSC_CANNED_ACL_PRIVATE: BscCannedAcl = 'private';
/** BSC canned ACL：公共读 */
export const BSC_CANNED_ACL_PUBLIC_READ: BscCannedAcl = 'public-read';
/** BSC canned ACL：公共读写 */
export const BSC_CANNED_ACL_PUBLIC_READ_WRITE: BscCannedAcl = 'public-read-write';
/** BSC canned ACL：认证用户读写 */
export const BSC_CANNED_ACL_AUTHENTICATED_READ: BscCannedAcl = 'authenticated-read';

/** BSC canned ACL 类型（对齐 Java CANNED_ACL_* 四种） */
export type BscCannedAcl = 'private' | 'public-read' | 'public-read-write' | 'authenticated-read';

/**
 * BSC 异常：code 为 BSC_ERR_* 错误码，statusCode 为 HTTP 状态码（本地失败时 undefined）
 */
export class BscException extends Error {
  /** BSC 错误码（BSC_ERR_*） */
  code: number;
  /** HTTP 状态码（请求已发出时存在） */
  statusCode?: number;

  constructor(code: number, message: string, statusCode?: number) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

/**
 * BSC 超时单位（BscPutOptions.timeout 换算基准）
 */
export enum BscTimeUnit {
  /** 毫秒 */
  MILLISECOND = 1,
  /** 秒 */
  SECOND = 1000,
  /** 分 */
  MINUTE = 60000
}

/**
 * BSC HEAD 结果：exists 标识对象是否存在，存在时携带元信息
 */
export interface BscHeadResult {
  /** 对象是否存在（404 → false） */
  exists: boolean;
  /** 对象字节数（Content-Length） */
  contentLength?: number;
  /** 对象 ETag */
  eTag?: string;
  /** 对象最后修改时间（GMT 字符串） */
  lastModified?: string;
}

/**
 * BSC PUT/APPEND 可选项
 */
export interface BscPutOptions {
  /**
   * 附加请求头：x-amz-* 头会按字母序参与 V2 签名（如 x-amz-meta-* 自定义元数据），
   * 非 x-amz-* 头仅随请求发送不参与签名
   */
  extraHeaders?: Record<string, string>;
  /** 超时时长（默认毫秒，配合 timeUnit 换算；缺省不启用软超时） */
  timeout?: number;
  /** 超时单位（默认毫秒） */
  timeUnit?: BscTimeUnit;
}

/**
 * BSC bucket 名校验与规范化（对齐 Java handleBucketName）：
 * 3-63 位，仅小写字母/数字/连字符，不以连字符开头或结尾
 * @param bucket 原始 bucket 名
 * @returns 规范化后的 bucket 名（非法抛 BscException(BSC_ERR_PARAM)）
 */
function bscHandleBucketName(bucket: string): string {
  if (!bucket || bucket.length < 3 || bucket.length > 63) {
    throw new BscException(BSC_ERR_PARAM, `bucket 长度须为 3-63: "${bucket}"`);
  }
  for (let i = 0; i < bucket.length; i++) {
    const ch = bucket.charAt(i);
    const isLower = ch >= 'a' && ch <= 'z';
    const isDigit = ch >= '0' && ch <= '9';
    if (!isLower && !isDigit && ch !== '-') {
      throw new BscException(BSC_ERR_PARAM, `bucket 含非法字符 "${ch}": "${bucket}"`);
    }
  }
  if (bucket.startsWith('-') || bucket.endsWith('-')) {
    throw new BscException(BSC_ERR_PARAM, `bucket 不以连字符开头/结尾: "${bucket}"`);
  }
  return bucket;
}

/**
 * BSC key 路径编码（对齐 Java encodeKeyPath，RFC3986 严格集）：
 * 逐字符检查，未编码字符仅 A-Z a-z 0-9 - _ . ~ /，其余按 UTF-8 字节输出 %XX 大写十六进制
 * @param key 原始 key
 * @returns 编码后的 key（含非法字符抛 BscException(BSC_ERR_ENCODE)）
 */
function bscEncodeKeyPath(key: string): string {
  if (key === undefined || key === null) {
    throw new BscException(BSC_ERR_ENCODE, 'key 不能为空');
  }
  const allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~/';
  const encoder = new util.TextEncoder();
  let out = '';
  for (let i = 0; i < key.length; i++) {
    const ch = key.charAt(i);
    if (allowed.indexOf(ch) >= 0) {
      out += ch;
    } else {
      const bytes = encoder.encodeInto(ch);
      for (let j = 0; j < bytes.length; j++) {
        const hex = bytes[j].toString(16);
        out += '%' + (hex.length < 2 ? '0' + hex : hex).toUpperCase();
      }
    }
  }
  return out;
}

/**
 * BSC GMT 日期（HTTP Date 头格式）：EEE, dd MMM yyyy HH:mm:ss GMT（对齐 Java SimpleDateFormat US 区域）
 * @param date 时间
 * @returns GMT 格式字符串
 */
function bscGmtDate(date: Date): string {
  const days: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const pad2 = (n: number): string => (n < 10 ? '0' + n : '' + n);
  return `${days[date.getUTCDay()]}, ${pad2(date.getUTCDate())} ${months[date.getUTCMonth()]} ` +
    `${date.getUTCFullYear()} ${pad2(date.getUTCHours())}:${pad2(date.getUTCMinutes())}:${pad2(date.getUTCSeconds())} GMT`;
}

/**
 * BSC 响应头大小写不敏感取值
 * @param headers 响应头
 * @param name 头名
 * @returns 头值（多值取第一个；不存在返回 undefined）
 */
function bscRespHeader(headers: Record<string, string | string[]>, name: string): string | undefined {
  const keys: string[] = Object.keys(headers);
  for (const k of keys) {
    if (k.toLowerCase() === name.toLowerCase()) {
      const v = headers[k];
      if (Array.isArray(v)) {
        return v.length > 0 ? v[0] : undefined;
      }
      return v as string;
    }
  }
  return undefined;
}

/**
 * BSC HMAC-SHA1 摘要转 Base64（AWS V2 签名核心）
 * @param key 签名密钥（SecretKey）
 * @param data 待签名字符串（stringToSign）
 * @returns Base64 签名（失败抛 BscException(BSC_ERR_SIGN)）
 */
function bscHmacSha1Base64(key: string, data: string): string {
  try {
    const generator = cryptoFramework.createSymKeyGenerator('HMAC');
    const keyBlob: cryptoFramework.DataBlob = { data: new util.TextEncoder().encodeInto(key) };
    const symKey = generator.convertKeySync(keyBlob);
    const mac = cryptoFramework.createMac('SHA1');
    mac.initSync(symKey);
    mac.updateSync({ data: new util.TextEncoder().encodeInto(data) });
    const macResult = mac.doFinalSync();
    return new util.Base64Helper().encodeToStringSync(macResult.data);
  } catch (e) {
    throw new BscException(BSC_ERR_SIGN, `HMAC-SHA1 签名失败: ${(e as Error).message}`);
  }
}

/**
 * BSC 字节数组 MD5 转 Base64（Content-MD5 头用）
 * @param data 字节数组
 * @returns Base64 MD5（失败抛 BscException(BSC_ERR_MD5)）
 */
function bscMd5Base64FromBytes(data: Uint8Array): string {
  try {
    const md = cryptoFramework.createMd('MD5');
    md.updateSync({ data: data });
    const digest = md.digestSync();
    return new util.Base64Helper().encodeToStringSync(digest.data);
  } catch (e) {
    throw new BscException(BSC_ERR_MD5, `MD5 计算失败: ${(e as Error).message}`);
  }
}

/**
 * BSC 文件 MD5 转 Base64（64KB 分块读取，规避单次 DataBlob 长度上限）
 * @param filePath 本地文件路径
 * @returns Base64 MD5（失败抛 BscException(BSC_ERR_MD5)）
 */
async function bscMd5Base64FromFile(filePath: string): Promise<string> {
  const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(file.fd);
    const md = cryptoFramework.createMd('MD5');
    const buf = new ArrayBuffer(65536);
    let readTotal = 0;
    while (readTotal < stat.size) {
      const toRead = Math.min(65536, stat.size - readTotal);
      const n = fs.readSync(file.fd, buf, { offset: readTotal, length: toRead });
      if (n <= 0) {
        break;
      }
      md.updateSync({ data: new Uint8Array(buf.slice(0, n)) });
      readTotal += n;
    }
    const digest = md.digestSync();
    return new util.Base64Helper().encodeToStringSync(digest.data);
  } catch (e) {
    if (e instanceof BscException) {
      throw e;
    }
    throw new BscException(BSC_ERR_MD5, `文件 MD5 计算失败: ${(e as Error).message}`);
  } finally {
    fs.closeSync(file);
  }
}

/**
 * BSC 超时选项换算毫秒（缺省返回 undefined 表示不启用软超时）
 */
function bscToMillis(options?: BscPutOptions): number | undefined {
  if (!options || options.timeout === undefined) {
    return undefined;
  }
  const unit = options.timeUnit !== undefined ? options.timeUnit : BscTimeUnit.MILLISECOND;
  return options.timeout * unit;
}

/**
 * 链式请求构建器（建造者模式）
 *
 * 用法示例（泛型 T 即服务端 ResultDTO 包装结构中的 data 类型）：
 * const data = await zyClient.with()
 *   .urlPath(INFO_PATH)
 *   .setToken(INFO_TOKEN)
 *   .addParams(query)
 *   .addParams('tags', '1')
 *   .cache(30 * 24 * 60 * 60)
 *   .post<QuestionResp>()   // 直接得到 data: QuestionResp（无数据时为 null）
 */
class RequestBuilder {
  /** 宿主客户端：复用全局拦截器、签名与缓存逻辑 */
  private client: HttpClient
  /** 逐步填充的请求配置 */
  private config: HttpRequestConfig
  /** 缓存时长（秒）；-1 表示未显式设置，走 zyClient 默认缓存策略 */
  private cacheSeconds: number
  /** 解包后 data 缺失时的兜底值；undefined 表示未设置（保持返回 null） */
  private fallbackValue: ESObject
  /** 是否显式指定了单次 baseURL（baseUrl() 调用后置 true） */
  private explicitBaseURL: boolean
  /** baseURL 是否来自 preset（preset 显式带 baseURL 时保留，不清空） */
  private baseFromPreset: boolean

  /**
   * 构造函数
   * @param client 宿主 HttpClient 实例
   */
  constructor(client: HttpClient) {
    this.client = client
    this.config = {}
    this.cacheSeconds = -1
    this.fallbackValue = undefined
    this.explicitBaseURL = false
    this.baseFromPreset = false
  }

  /**
   * 应用基础配置模板（预设或自定义），仅由 HttpClient.with() 内部调用
   * @param base 基础配置模板
   * @param fromPreset 是否来自 registerPreset 预设（preset 显式带 baseURL 时保留）
   * @returns 当前构建器（支持链式）
   */
  applyBase(base: HttpRequestConfig, fromPreset: boolean = false): RequestBuilder {
    // 浅层结构克隆：header/params/custom/data/skip 与 preset 脱钩，
    // 避免后续 addHeader/addParams 原地修改污染共享的预设对象
    const cloned = cloneRequestConfig(base)
    this.config = cloned
    if (fromPreset && cloned.baseURL) {
      this.baseFromPreset = true
    }
    return this
  }

  /**
   * 设置请求路径（相对 baseURL 的路径或完整 URL）
   * @param path 请求路径
   * @returns 当前构建器（支持链式）
   */
  urlPath(path: string): RequestBuilder {
    this.config.url = path
    return this
  }

  /**
   * 单次覆盖请求基地址（仅本次请求生效，不影响全局配置）
   * 不调用时跟随全局 baseUrl（NetBasic.baseUrl / updateBaseUrl 切换后的最新值）
   * @param url 本次请求的基地址
   * @returns 当前构建器（支持链式）
   */
  baseUrl(url: string): RequestBuilder {
    this.config.baseURL = url
    this.explicitBaseURL = true
    return this
  }

  /**
   * 设置请求超时时间（毫秒）
   * @param ms 超时毫秒数
   * @returns 当前构建器（支持链式）
   */
  timeout(ms: number): RequestBuilder {
    this.config.timeout = ms
    return this
  }

  /**
   * 设置业务 token 规格（等价旧版 addParam('token', token)）
   * 规格存入 custom.tokenSpec（不再占用 params.token）：签名插件读取该规格计算 md5
   * 签名后写入 params.token；raw()/skip('sign') 时签名插件不执行，业务值完整保留
   * @param token token 规格字符串（如 'rtype_sid_aid_vid'）
   * @returns 当前构建器（支持链式）
   */
  setToken(token: string): RequestBuilder {
    if (!this.config.custom) {
      this.config.custom = {}
    }
    this.config.custom['tokenSpec'] = token
    return this
  }

  /**
   * 追加/批量合并查询参数：
   * - 传入 (key, value) 时追加单个参数
   * - 传入对象（含 interface 实例）时逐键复制批量合并，
   *   调用侧无需对象展开运算符，规避 ArkTS 限制
   * @param keyOrParams 参数名或参数对象（如 QuestionQuery 实例）
   * @param value 参数值（仅 key 形式时传入）
   * @returns 当前构建器（支持链式）
   */
  addParams(keyOrParams: ESObject, value?: ParamValue): RequestBuilder {
    if (!this.config.params) {
      this.config.params = {}
    }
    if (typeof keyOrParams === 'string') {
      this.config.params[keyOrParams] = value as ParamValue
    } else {
      // 逐键复制合并（替代受限的 Object.assign）
      const srcParams: Record<string, ESObject> = keyOrParams as Record<string, ESObject>
      const ks: string[] = Object.keys(srcParams)
      for (const k of ks) {
        this.config.params[k] = srcParams[k] as ParamValue
      }
    }
    return this
  }

  /**
   * 追加单个请求头
   * @param key 请求头字段名
   * @param value 请求头值
   * @returns 当前构建器（支持链式）
   */
  addHeader(key: string, value: string): RequestBuilder {
    if (!this.config.header) {
      this.config.header = {}
    }
    this.config.header[key] = value
    return this
  }

  /**
   * 批量合并请求头
   * @param headers 请求头对象
   * @returns 当前构建器（支持链式）
   */
  addHeaders(headers: object): RequestBuilder {
    if (!this.config.header) {
      this.config.header = {}
    }
    // 逐键复制合并（替代受限的 Object.assign）
    const srcHeaders: Record<string, string> = headers as Record<string, string>
    const hks: string[] = Object.keys(srcHeaders)
    for (const hk of hks) {
      this.config.header[hk] = srcHeaders[hk]
    }
    return this
  }

  /**
   * 设置请求体（POST/PUT/DELETE 均可用）
   * @param data 请求体对象
   * @returns 当前构建器（支持链式）
   */
  body(data: AnyObject): RequestBuilder {
    this.config.data = data
    return this
  }

  /**
   * 设置缓存时长（秒）；未调用时走 zyClient 默认缓存策略
   * @param seconds 缓存秒数（缓存层统一秒语义）
   * @returns 当前构建器（支持链式）
   */
  cache(seconds: number): RequestBuilder;
  /**
   * 设置缓存时长（数值 + 单位重载）：内部换算为秒，如 .cache(30, CacheUnit.DAY) 缓存 30 天
   * @param duration 时长数值
   * @param unit 时间单位枚举（秒/分/时/天/月/年）
   * @returns 当前构建器（支持链式）
   */
  cache(duration: number, unit: CacheUnit): RequestBuilder;
  cache(duration: number, unit?: CacheUnit): RequestBuilder {
    this.cacheSeconds = unit === undefined ? duration : duration * unit
    return this
  }

  /**
   * 设置兜底默认值：响应解包后 data 缺失（null/undefined）时返回该值，调用端无需判空。
   * 用于后端不标准场景——如本应报错却返回 {"code":0,"message":"empty"}（HTTP 200、code 0、无 data），
   * SDK 层兜底成有效对象/默认实例，调用端拿到恒可用的数据
   * @param value 兜底值（与 post<T>() 的 T 同构；调用后 post() 不再返回 null）
   * @returns 当前构建器（支持链式）
   */
  default(value: ESObject): RequestBuilder {
    this.fallbackValue = value
    return this
  }

  /**
   * 纯净请求开关：跳过全部插件注入（签名/公共参数/公共头）与缓存、不做 ResultDTO 解包，
   * 发一个"原汁原味"的 HTTP 请求（请求体/头/参数完全由调用方掌控）
   * @returns 当前构建器（支持链式）
   */
  raw(): RequestBuilder {
    this.config.raw = true
    return this
  }

  /**
   * 跳过指定名称的插件（保留其余默认注入），如 .skip('sign') 跳过签名但保留其他注入
   * @param names 插件名列表（如 'sign'）
   * @returns 当前构建器（支持链式）
   */
  skip(...names: string[]): RequestBuilder {
    this.config.skip = [...(this.config.skip || []), ...names]
    return this
  }

  /**
   * 请求标签：配合 zyClient.cancelTag(tag) 批量取消同标签的进行中请求（页面销毁联动）
   * @param tag 标签名
   * @returns 当前构建器（支持链式）
   */
  tag(tag: string): RequestBuilder {
    this.config.tag = tag
    return this
  }

  /**
   * 重试配置（指数退避；仅网络类错误默认可重试，HTTP 状态码错误(含 5xx)/cancel/parse 不重试。
   * 未配置时：GET/HEAD 默认重试 3 次，POST/PUT/DELETE 等非幂等方法不重试，避免重复提交）
   * @param retry 重试次数（number）或完整 RetryConfig
   * @returns 当前构建器（支持链式）
   */
  retry(retry: number | RetryConfig): RequestBuilder {
    this.config.retry = retry
    return this
  }

  /**
   * 连接超时（毫秒）；未设置时单段 timeout 生效
   * @param ms 连接超时毫秒数
   * @returns 当前构建器（支持链式）
   */
  connectTimeout(ms: number): RequestBuilder {
    this.config.connectTimeout = ms
    return this
  }

  /**
   * 传输超时（毫秒）；未设置时单段 timeout 生效
   * @param ms 传输超时毫秒数
   * @returns 当前构建器（支持链式）
   */
  transferTimeout(ms: number): RequestBuilder {
    this.config.transferTimeout = ms
    return this
  }

  /**
   * 显式表达完整 URL（与 urlPath 等价；绝对 URL 不会拼接 baseURL）
   * @param url 完整请求地址
   * @returns 当前构建器（支持链式）
   */
  fullUrl(url: string): RequestBuilder {
    return this.urlPath(url)
  }

  /**
   * 只进查询串的参数（与 addParams 等价，语义化为 query-only）
   * @param keyOrParams 参数名或参数对象
   * @param value 参数值（仅 key 形式时传入）
   * @returns 当前构建器（支持链式）
   */
  setQuery(keyOrParams: string | object, value?: ParamValue): RequestBuilder {
    return this.addParams(keyOrParams, value)
  }

  /**
   * JSON 请求体（等价 body()，语义化为 JSON body）
   * @param data 请求体对象
   * @returns 当前构建器（支持链式）
   */
  bodyJson(data: AnyObject): RequestBuilder {
    return this.body(data)
  }

  /**
   * urlencoded 表单请求体：对象序列化为 a=1&b=2 并自动设置 content-type
   * @param form 表单字段对象
   * @returns 当前构建器（支持链式）
   */
  bodyForm(form: AnyObject): RequestBuilder {
    const qs = Object.keys(form)
      .map((k: string) => `${encodeURIComponent(k)}=${encodeURIComponent(String(form[k]))}`)
      .join('&')
    this.config.data = qs as ESObject as AnyObject
    return this.addHeader('content-type', 'application/x-www-form-urlencoded')
  }

  /**
   * 原始请求体（string/ArrayBuffer 原样发送），建议显式指定 contentType
   * @param raw 原始内容
   * @param contentType 内容类型（如 text/plain、application/octet-stream）
   * @returns 当前构建器（支持链式）
   */
  bodyRaw(raw: string | ArrayBuffer, contentType?: string): RequestBuilder {
    this.config.rawBody = raw
    if (contentType) {
      return this.addHeader('content-type', contentType)
    }
    return this
  }

  /**
   * multipart 请求体：文本字段 + 文件列表（文件支持本地路径或内存内容）
   * @param fields 文本字段对象
   * @param files 文件字段列表
   * @returns 当前构建器（支持链式）
   */
  bodyMultipart(fields: AnyObject, files: MultipartFileSpec[]): RequestBuilder {
    this.config.multipartFields = fields
    this.config.multipartFiles = files
    return this
  }

  /**
   * 上传进度回调
   * @param cb 回调（transferredSize 已传字节 / totalSize 总字节）
   * @returns 当前构建器（支持链式）
   */
  onUploadProgress(cb: (transferredSize: number, totalSize: number) => void): RequestBuilder {
    this.config.onUploadProgress = cb
    return this
  }

  /**
   * 下载进度回调
   * @param cb 回调（transferredSize 已收字节 / totalSize 总字节）
   * @returns 当前构建器（支持链式）
   */
  onDownloadProgress(cb: (transferredSize: number, totalSize: number) => void): RequestBuilder {
    this.config.onDownloadProgress = cb
    return this
  }

  /**
   * 断点续传范围（从 from 字节到 to 字节；配合 downloadTo 使用）
   * @param from 起始字节（含）
   * @param to 结束字节（含）
   * @returns 当前构建器（支持链式）
   */
  transferRange(from?: number, to?: number): RequestBuilder {
    const range: TransferRangeSpec = {}
    if (from !== undefined) {
      range.from = from
    }
    if (to !== undefined) {
      range.to = to
    }
    this.config.transferRange = range
    return this
  }

  /**
   * 任意 HTTP method 直发（HEAD/OPTIONS/PATCH 等），走与 get/post 一致的解包语义
   * @param method HTTP 方法（自动转大写）
   * @returns 业务数据 Promise
   */
  request<T = ESObject>(method: string): Promise<T> {
    return this.send<T>(method.toUpperCase())
  }

  /**
   * 发起请求并返回调用句柄：promise resolve 完整 HttpResponse（不做 ResultDTO 解包）；
   * call.abort() 取消请求（reject HttpError kind='cancel'）；不走缓存
   * @param method HTTP 方法（默认 GET）
   * @returns Call 句柄
   */
  execute<T = ESObject>(method: string = 'GET'): Call<HttpResponse<T>> {
    const cfg = this.build(method.toUpperCase())
    return this.client.execute<T>(cfg)
  }

  /**
   * 下载到指定目录（folder 语义）；支持 .transferRange() 断点续传与 onDownloadProgress 进度
   * @param filePath 下载目标路径
   * @returns 下载响应（含 tempFilePath）
   */
  downloadTo(filePath: string): Promise<HttpDownloadResponse> {
    const cfg = this.build('GET')
    cfg.filePath = filePath
    return this.client.download(cfg.url as string, cfg)
  }

  /**
   * 上传文件（multipart）：filePath 本地路径，fileKey 为服务端取文件的字段名（默认 'file'）；
   * 表单文本字段经 addParams/formData 注入，进度回调经 onUploadProgress
   * @param filePath 本地文件路径
   * @param fileKey 文件字段名（默认 'file'）
   * @returns 业务数据 Promise（服务端响应体）
   */
  upload<T = ESObject>(filePath: string, fileKey: string = 'file'): Promise<T> {
    const cfg = this.build('POST')
    cfg.filePath = filePath
    cfg.name = fileKey
    // 与 get/post 一致的解包语义：以 ResultDTO<T> 接收响应体，返回其中的 data
    return this.client.uploadBusiness<ResultDTO<T>>(cfg.url as string, cfg)
      .then((res: ResultDTO<T>): T => (res?.data ?? null) as T)
  }

  /**
   * 统一发送入口（收敛至 client.runBusiness 单通道）：
   * raw → requestRaw 直发（跳过缓存与 ResultDTO 解包）；
   * 其余一律 runBusiness：Mock → 缓存 → 去重 → 发请求 → unwrapBusiness → 写缓存，
   * 任意 method（GET/POST/PUT/DELETE/PATCH/HEAD...）与缓存/兜底语义完全一致
   * @param method HTTP 方法
   * @returns 业务数据 Promise
   */
  private send<T = ESObject>(method: string): Promise<T> {
    const cfg = this.build(method)
    // 纯净请求：跳过缓存与 ResultDTO 解包，直接返回响应体
    if (cfg.raw) {
      return this.client.requestRaw<T>(cfg)
    }
    // 解包 ResultDTO 取 data；缺失时用 default() 设置的兜底值顶替（未设置则为 null）
    const fb: ESObject = this.fallbackValue
    const unwrap = (res: ResultDTO<T>): T => ((res?.data ?? null) as T) ?? (fb as T)
    const explicitCache = this.cacheSeconds >= 0
    return this.client.runBusiness<ResultDTO<T>>(cfg, {
      cacheSeconds: explicitCache ? this.cacheSeconds : undefined,
      fallback: fb
    }).then(unwrap)
  }

  /**
   * 校验并生成最终请求配置（追加 HTTP method）
   * @param method HTTP 方法
   * @returns 最终请求配置
   */
  private build(method: string): HttpRequestConfig {
    if (!this.config.url) {
      throw new Error('RequestBuilder: url 未设置，请先调用 urlPath()')
    }
    const finalConfig = cloneRequestConfig(this.config)
    if (!this.explicitBaseURL && !this.baseFromPreset) {
      // 仅全局模板来源且未显式覆盖时清除 baseURL 快照，
      // 交由引擎实时填充全局最新 baseUrl；preset 显式带 baseURL 时保留
      finalConfig.baseURL = undefined
    }
    finalConfig.method = method
    return finalConfig
  }

  /**
   * 发起 GET 请求（内部以 ResultDTO<T> 接收并自动解包返回 data；raw 时返回原始响应体）
   * data 缺失时运行时为 null，调用侧请使用可选链（如 res?.xxx）兜底
   * @returns 业务数据 Promise
   */
  get<T = ESObject>(): Promise<T> {
    return this.send<T>('GET')
  }

  /**
   * 发起 POST 请求（内部以 ResultDTO<T> 接收并自动解包返回 data；raw 时返回原始响应体）
   * data 缺失时运行时为 null，调用侧请使用可选链（如 res?.xxx）兜底
   * @returns 业务数据 Promise
   */
  post<T = ESObject>(): Promise<T> {
    return this.send<T>('POST')
  }

  /**
   * 发起 PUT 请求（内部以 ResultDTO<T> 接收并自动解包返回 data；raw 时返回原始响应体）
   * data 缺失时运行时为 null，调用侧请使用可选链（如 res?.xxx）兜底
   * @returns 业务数据 Promise
   */
  put<T = ESObject>(): Promise<T> {
    return this.send<T>('PUT')
  }

  /**
   * 发起 DELETE 请求（内部以 ResultDTO<T> 接收并自动解包返回 data；raw 时返回原始响应体）
   * data 缺失时运行时为 null，调用侧请使用可选链（如 res?.xxx）兜底
   * @returns 业务数据 Promise
   */
  delete<T = ESObject>(): Promise<T> {
    return this.send<T>('DELETE')
  }

  /**
   * 发起 GET 请求并将业务 data 序列化为 JSON 字符串返回
   * 说明：TS 泛型运行时擦除，post<T>/get<T> 内部无法感知 T 的声明，
   * 因此"要字符串"必须显式调用本方法，以消除"类型是 string、运行时是对象"的歧义
   * @returns data 的 JSON 字符串 Promise（data 缺失时为 'null'）
   */
  getText(): Promise<string> {
    return this.get<ESObject>().then((data: ESObject) => JSON.stringify(data))
  }

  /**
   * 发起 POST 请求并将业务 data 序列化为 JSON 字符串返回
   * 说明：TS 泛型运行时擦除，post<T>/get<T> 内部无法感知 T 的声明，
   * 因此"要字符串"必须显式调用本方法，以消除"类型是 string、运行时是对象"的歧义
   * @returns data 的 JSON 字符串 Promise（data 缺失时为 'null'）
   */
  postText(): Promise<string> {
    return this.post<ESObject>().then((data: ESObject) => JSON.stringify(data))
  }
}

/**
 * 网络请求客户端（对外主入口）：引擎为 2.0 ZyHttp，对外方法签名与 1.x 完全一致
 * 提供：链式构建器(with)、缓存(内存+磁盘LRU)、并发去重、Mock、业务码拦截、
 * 插件链(use)、签名插件(sign)、上传下载、取消(tag)、安全配置(setSecurityConfig 证书锁定/防中间人)、原生逃生舱(requestNative)
 */
class HttpClient {
  /** 请求预设配置表（实例级，各 HttpClient 独立持有） */
  private presets: Map<string, HttpRequestConfig> = new Map<string, HttpRequestConfig>()
  /** GET 并发去重：同 key 的进行中请求 Promise（并发只发一次，全部调用方共享同一结果） */
  private inFlight: Map<string, Promise<ESObject>> = new Map();
  /** 业务 code 统一处理器（解包 ResultDTO 前回调；null 表示未启用） */
  private businessCodeHandler: BusinessCodeHandler | null = null;
  /** Mock 规则列表（setMockEnabled(true) 后生效） */
  private mocks: MockRule[] = [];
  /** Mock 总开关（默认关闭） */
  private mockEnabled: boolean = false;
  /** 全局请求配置（baseURL/timeout，setConfig 更新） */
  public config: HttpRequestConfig;
  /** 2.0 引擎实例（不发库层日志，日志框由 ZyNetLogger 承担） */
  private engine: ZyHttp;
  /** 签名中间件实例（baseURL 动态读取，updateBaseUrl 即刻生效） */
  private signMw: ZySignMiddleware;
  /** 缓存中间件实例（L1 内存 + L2 磁盘，洋葱模型） */
  private cacheMw: ZyCacheMiddleware;
  /** BSCStorage AccessKey（setBscCredential 初始化） */
  private bscAk: string = '';
  /** BSCStorage SecretKey（setBscCredential 初始化） */
  private bscSk: string = '';
  /** BSCStorage 存储域名（默认白山云 ss.bscstorage.com，setBscCredential 可覆盖） */
  private bscHost: string = BSC_DEFAULT_HOST;

  constructor(config: HttpRequestConfig) {
    this.config = cloneRequestConfig(config)
    this.signMw = new ZySignMiddleware(() => this.config.baseURL ?? '')
    this.cacheMw = new ZyCacheMiddleware()
    this.engine = ZyHttp.create({
      baseURL: config.baseURL,
      logging: false,
      middlewares: [this.signMw, this.cacheMw]
    })
  }

  private resolveFullUrl(cfg: HttpRequestConfig): string {
    const path = cfg.url as string
    let full: string
    if (path.startsWith('http://') || path.startsWith('https://')) {
      full = path
    } else {
      const base = cfg.baseURL || this.config.baseURL || ''
      const p = path.startsWith('/') ? path : `/${path}`
      full = `${base}${p}`
    }
    if (cfg.params && typeof cfg.params === 'object') {
      const pairs: string[] = []
      const params = cfg.params as Record<string, ESObject>
      Object.keys(params).forEach((k: string) => {
        const v: ESObject = params[k]
        if (v !== undefined && v !== null) {
          pairs.push(`${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
        }
      })
      if (pairs.length > 0) {
        full = `${full}${full.includes('?') ? '&' : '?'}${pairs.join('&')}`
      }
    }
    return full
  }

  /**
   * 构建请求体内容（1.x resolveContent 语义）：
   * multipart 优先 → rawBody → data（对象/字符串/二进制原样交引擎序列化）
   */
  private resolveContent(cfg: HttpRequestConfig): rcp.RequestContent | undefined {
    if (cfg.multipartFiles && cfg.multipartFiles.length > 0) {
      const fields: Record<string, rcp.MultipartFormFieldValue> = {}
      const textFields = cfg.multipartFields || {}
      Object.keys(textFields).forEach((k: string) => {
        fields[k] = String((textFields as Record<string, ESObject>)[k])
      })
      for (const spec of cfg.multipartFiles) {
        const fileField: rcp.FormFieldFileValue = {
          contentOrPath: spec.filePath,
          remoteFileName: spec.fileName,
          contentType: spec.mimeType
        };
        fields[spec.name || 'file'] = fileField;
      }
      return new rcp.MultipartForm(fields)
    }
    if (cfg.rawBody !== undefined) {
      return cfg.rawBody as rcp.RequestContent
    }
    return cfg.data as rcp.RequestContent
  }

  /**
   * 解析原生响应体：JSON 尝试解析为对象，失败时原样返回文本
   * @param raw 官方原始响应
   * @returns 解析后的响应体
   */
  private parseBody(raw: rcp.Response): ESObject {
    const text: string | null = raw.toString();
    if (text === null || text === undefined) {
      return undefined;
    }
    try {
      return JSON.parse(text) as ESObject;
    } catch (e) {
      return text as ESObject;
    }
  }

  /**
   * 核心请求引擎（替代 1.x 基类 request）：插件链 → 日志框 → 2.0 引擎 fetch → 收尾
   * 下载（filePath）与断点续传（transferRange）场景走原生 rcp.Request（官方 destination/
   * transferRange 为 Request 级能力），其余走 2.0 引擎构建器
   * @param cfg 请求配置（method/url 必填）
   * @returns HttpResponse Promise
   */
  private async doRequest(cfg: HttpRequestConfig): Promise<HttpResponse<ESObject>> {
    const method = (cfg.method || 'GET').toUpperCase()
    const logger = new ZyNetLogger(method, cfg.url as string)
    logger.begin({ baseURL: cfg.baseURL || this.config.baseURL, header: cfg.header,
      params: cfg.params, data: cfg.data })
    if (!cfg.raw && !NetBasic.isConfigured()) {
      zyLog(hilog.warn, `[NET] NetBasic 未配置完整(SID/SV/IT)，签名可能不完整: url=${cfg.url ?? ''}`);
    }
    const customData: Record<string, ESObject> = {}
    if (cfg.custom !== undefined) {
      const customKeys: string[] = Object.keys(cfg.custom)
      for (const ck of customKeys) {
        customData[ck] = cfg.custom[ck]
      }
    }
    if (cfg.params !== undefined) {
      customData['params'] = cfg.params as ESObject
    }
    if (cfg.data !== undefined) {
      customData['data'] = cfg.data as ESObject
    }
    const skipNames: string[] = []
    if (cfg.raw || (cfg.skip && cfg.skip.includes('sign'))) {
      skipNames.push('sign')
    }
    const pathOrUrl = cfg.url as string
    const isAbsolute = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')
    const explicitBase = cfg.baseURL !== undefined
    let requestPath: string
    let paramsViaQuery: boolean
    if (explicitBase || isAbsolute) {
      requestPath = this.resolveFullUrl(cfg)
      paramsViaQuery = false
    } else {
      requestPath = pathOrUrl
      paramsViaQuery = true
    }
    const builder = this.engine.newBuilder().method(method).path(requestPath)
    if (paramsViaQuery && cfg.params && typeof cfg.params === 'object') {
      const params = cfg.params as Record<string, ESObject>
      Object.keys(params).forEach((k: string) => {
        const v: ESObject = params[k]
        if (v !== undefined && v !== null) {
          builder.query(k, String(v))
        }
      })
    }
    if (skipNames.length > 0) {
      builder.skip(skipNames)
    }
    builder.custom(customData)
    if (cfg.header && typeof cfg.header === 'object') {
      const headers = cfg.header as Record<string, string>
      Object.keys(headers).forEach((k: string) => {
        builder.header(k, String(headers[k]))
      })
    }
    const content = this.resolveContent(cfg)
    if (content !== undefined) {
      if (typeof content === 'string') {
        builder.textBody(content)
      } else if (content instanceof ArrayBuffer) {
        builder.binaryBody(content)
      } else if (content instanceof rcp.MultipartForm) {
        builder.multipartBody(content)
      } else if (content instanceof rcp.Form) {
        builder.formBody(content)
      } else {
        builder.jsonBody(content as ESObject)
      }
    }
    if (cfg.responseType === 'arraybuffer') {
      builder.responseType('arraybuffer')
    } else if (cfg.responseType === 'text') {
      builder.responseType('text')
    }
    const connectMs = cfg.connectTimeout ?? undefined
    const transferMs = cfg.transferTimeout ?? cfg.timeout ?? undefined
    if (connectMs !== undefined || transferMs !== undefined) {
      builder.timeout(connectMs, transferMs)
    }
    if (cfg.retry !== undefined) {
      if (typeof cfg.retry === 'number') {
        builder.retry(cfg.retry)
      } else {
        builder.retry(cfg.retry.count ?? 0, cfg.retry.interval ?? 500,
          cfg.retry.maxInterval ?? 8000)
        if (cfg.retry.retryOn) {
          builder.retryOn(cfg.retry.retryOn)
        }
      }
    }
    if (cfg.tag) {
      builder.tag(cfg.tag)
    }
    if (cfg.cancelToken !== undefined) {
      builder.cancelToken(cfg.cancelToken)
    }
    const needNative: boolean = cfg.filePath !== undefined || cfg.transferRange !== undefined
    const fetchTask: Promise<ZyHttpResponse<ESObject>> = (async (): Promise<ZyHttpResponse<ESObject>> => {
      if (needNative) {
        const req = builder.build()
        logger.step('fullUrl', req.url)
        if (!skipNames.includes('sign')) {
          const signCtx: ZyMiddlewareContext = {
            request: req,
            respond: (_data: ESObject): void => {},
            custom: customData
          }
          await this.signMw.onRequest(signCtx)
        }
        const requestHeaders: rcp.RequestHeaders = {}
        req.headers.forEach((v: string, k: string) => {
          requestHeaders[k] = v
        })
        let range: rcp.TransferRange[] | undefined = undefined
        if (cfg.transferRange) {
          const r: TransferRangeSpec = cfg.transferRange
          const one: rcp.TransferRange = { from: r.from, to: r.to }
          range = [one]
        }
        const rawReq = new rcp.Request(req.url, method, requestHeaders, content, undefined, range, undefined)
        if (cfg.filePath !== undefined) {
          const dest: rcp.DownloadToFile = { kind: 'folder', path: cfg.filePath } as rcp.DownloadToFile
          rawReq.destination = dest
        }
        const nativeSession = this.engine.getNativeSession()
        const cancelAction = (): void => {
          try {
            nativeSession.cancel(rawReq)
          } catch (e) {
          }
        }
        if (cfg.cancelToken !== undefined) {
          if (cfg.cancelToken.isCancelled()) {
            throw ZyCancelToken.cancelledError();
          }
          cfg.cancelToken.register(cancelAction)
          this.engine.trackInflight(cfg.cancelToken)
        }
        try {
          if (cfg.cancelToken !== undefined && cfg.cancelToken.isCancelled()) {
            throw ZyCancelToken.cancelledError();
          }
          const raw: rcp.Response = await nativeSession.fetch(rawReq)
          return new ZyHttpResponse<ESObject>(raw, this.parseBody(raw))
        } finally {
          if (cfg.cancelToken !== undefined) {
            cfg.cancelToken.unregister(cancelAction)
            this.engine.untrackInflight(cfg.cancelToken)
          }
        }
      }
      const builtReq = builder.build()
      logger.step('fullUrl', builtReq.url)
      return this.engine.execute<ESObject>(builtReq)
    })()
    return fetchTask.then((resp: ZyHttpResponse<ESObject>): HttpResponse<ESObject> => {
      // HTTP 响应码写入框内(与 1.x 一致, 在 succeed 收尾前输出, 如 200)
      logger.step('statusCode', `${resp.status}`)
      logger.succeed(resp.data)
      const result: HttpResponse<ESObject> = {
        statusCode: resp.status,
        data: resp.data,
        headers: resp.headers,
        tempFilePath: cfg.filePath
      }
      return result
    }).catch((err: ESObject): HttpResponse<ESObject> => {
      // 失败时 HTTP 状态码以 error 级别写入框内(如 405); 失败原因随 reason 行输出
      const httpErr: ZyHttpError | undefined = err instanceof ZyHttpError ? err : undefined
      if (httpErr !== undefined && httpErr.statusCode !== undefined) {
        logger.step('statusCode', `${httpErr.statusCode}`, 'error')
      }
      const reason: string = err instanceof Error ? err.message : String(err)
      logger.failed(err, reason)
      throw err as Error
    })
  }

  /**
   * 注册业务 code 统一处理器（全局生效）：
   * 每个含 { code, message, data } 结构的响应解包前回调，返回 false 时该请求 reject
   * HttpError(kind='business')，用于登录失效等全局统一处理
   * @param handler 处理器；传 null 取消
   * @returns 当前实例（支持链式）
   */
  public setBusinessCodeHandler(handler: BusinessCodeHandler | null): HttpClient {
    this.businessCodeHandler = handler;
    return this;
  }

  /**
   * 开启/关闭 Mock（全局生效）
   * @param on true 开启 / false 关闭（默认）
   * @returns 当前实例（支持链式）
   */
  public setMockEnabled(on: boolean): HttpClient {
    this.mockEnabled = on;
    return this;
  }

  /**
   * 注册 Mock 规则（配合 setMockEnabled(true) 使用）
   * @param rule 匹配 + 响应规则
   * @returns 当前实例（支持链式）
   */
  public registerMock(rule: MockRule): HttpClient {
    this.mocks.push(rule);
    return this;
  }

  /** 清空全部 Mock 规则 */
  public clearMocks(): HttpClient {
    this.mocks = [];
    return this;
  }

  /**
   * Mock 拦截检查：开启 Mock 且命中规则时返回本地模拟数据（不发真实请求）
   * @param url 请求地址
   * @param method HTTP 方法
   * @returns 命中时的模拟数据；未命中返回 undefined
   */
  private checkMock(url: string, method: string): ESObject {
    if (!this.mockEnabled || this.mocks.length === 0) {
      return undefined;
    }
    for (const rule of this.mocks) {
      if (rule.match(url, method)) {
        zyLog(hilog.warn, `[MOCK] 命中模拟规则，返回本地数据: [${method}] ${url}`);
        return rule.respond();
      }
    }
    return undefined;
  }

  /**
   * 统一解包响应体：返回其中的业务体（HttpResponse.data，即 ResultDTO 整包）；
   * 若注册了业务 code 处理器且响应为 { code, ... } 结构，解包前回调校验，
   * 返回 false 时抛出 HttpError(kind='business') 中断解包链
   * @param response 引擎层 HttpResponse
   * @returns 业务体
   */
  private unwrapBusiness<T = ESObject>(response: ESObject): T {
    const body: ESObject = (response?.data ?? response) as ESObject;
    if (this.businessCodeHandler && body && typeof body === 'object' && body['code'] !== undefined) {
      const pass = this.businessCodeHandler(body['code'] as number | string, body);
      if (!pass) {
        throw new ZyHttpError('business', `业务码拦截: code=${body['code']}`, false, undefined, undefined, body);
      }
    }
    return body as T;
  }

  /**
   * 动态设置默认缓存时间
   * @param cacheTime 缓存时间（秒）
   */
  public setDefaultCacheTime(cacheTime: number): HttpClient {
    this.cacheMw.setDefaultCacheTime(cacheTime)
    return this
  }

  public getDefaultCacheTime(): number {
    return this.cacheMw.getDefaultCacheTime()
  }

  /**
   * 注册或覆盖请求预设，供 with(预设名) 复用
   * @param name 预设名称
   * @param preset 预设配置模板
   * @returns 当前实例（支持链式）
   */
  public registerPreset(name: string, preset: HttpRequestConfig): HttpClient {
    this.presets.set(name, preset)
    return this
  }

  /**
   * 创建链式请求构建器（建造者模式入口）
   * @param preset 预设名称（如 'default'）或自定义基础配置；缺省时使用全局默认配置
   * @returns 链式请求构建器
   */
  public with(preset?: string | HttpRequestConfig): RequestBuilder {
    const builder = new RequestBuilder(this)
    let base: HttpRequestConfig
    let fromPreset = false
    if (typeof preset === 'string') {
      const found = this.presets.get(preset)
      if (!found) {
        throw new Error(`HttpClient.with: 未找到名为 ${preset} 的请求预设，请先调用 registerPreset()`)
      }
      base = found
      fromPreset = true
    } else if (preset) {
      base = preset
      fromPreset = true
    } else {
      base = config
    }
    return builder.applyBase(base, fromPreset)
  }

  public clearMemoryCache(): HttpClient {
    this.cacheMw.clearMemoryCache()
    return this
  }

  public clearCache(): HttpClient {
    this.cacheMw.clearCache()
    return this
  }

  /**
   * 纯净请求通道：不走缓存、不做 ResultDTO 解包，直接返回响应体（Builder.raw() 使用）
   * @param cfg 最终请求配置
   * @returns 响应体 Promise
   */
  requestRaw<T = ESObject>(cfg: HttpRequestConfig): Promise<T> {
    return this.doRequest(cfg).then((response: ESObject) => {
      return (response?.data ?? response) as T;
    });
  }

  /**
   * data 兜底：业务体缺失或 data 字段缺失（null/undefined）时以 fallback 顶替。
   * 仅构造返回值副本，不改写入缓存的原始业务体（缓存永远存原始数据，兜底按调用方各自生效）
   * @param body 业务体（ResultDTO 整包），可为 null（Mock 空数据等）
   * @param fallback 兜底值；undefined 表示未设置（原样返回）
   * @returns 兜底后的业务体
   */
  private applyFallback<T>(body: ESObject, fallback?: ESObject): T {
    if (fallback === undefined) {
      return body as T;
    }
    if (body === null || body === undefined || typeof body !== 'object') {
      const wrapped: Record<string, ESObject> = {};
      wrapped.data = fallback;
      return wrapped as ESObject as T;
    }
    if (body.data === null || body.data === undefined) {
      // 逐键复制业务体（替代受限的 Object.assign），再以 fallback 顶替 data
      const bodyRec: Record<string, ESObject> = body as Record<string, ESObject>;
      const copy: Record<string, ESObject> = {};
      const bks: string[] = Object.keys(bodyRec);
      for (const bk of bks) {
        copy[bk] = bodyRec[bk];
      }
      copy.data = fallback;
      return copy as ESObject as T;
    }
    return body as T;
  }

  /**
   * 统一业务请求单入口：Mock → raw → 缓存读取 → 并发去重 → 发请求 → unwrapBusiness → 写缓存。
   * 传统 get/post/put/delete(WithCache) 与 Builder.send 均收敛到此，保证行为一致
   * @param cfg 最终请求配置（method/url 必填；raw=true 时纯净直发，不缓存不解包不兜底）
   * @param opts cacheSeconds 缓存秒数（>=0 显式生效；缺省时 GET 默认缓存、非 GET 不缓存）；
   *             fallback data 缺失时的兜底值（仅影响本次返回，不写缓存）
   * @returns 业务体 Promise（ResultDTO 整包，fallback 已在 data 缺失时填入）
   */
  runBusiness<T = ESObject>(cfg: HttpRequestConfig, opts?: RunBusinessOptions): Promise<T> {
    const method = (cfg.method || 'GET').toUpperCase();
    const fallback: ESObject = opts?.fallback;
    // 1. Mock 拦截
    const mocked: ESObject = this.checkMock(cfg.url as string, method);
    if (mocked !== undefined) {
      return Promise.resolve(this.applyFallback<T>(this.unwrapBusiness<ESObject>(mocked), fallback));
    }
    // 2. 纯净请求
    if (cfg.raw) {
      return this.requestRaw<T>(cfg);
    }
    // 3. 缓存时长决议
    let resolved: number | undefined = undefined;
    if (opts?.useCache === true) {
      resolved = opts.cacheSeconds !== undefined && opts.cacheSeconds >= 0
        ? opts.cacheSeconds
        : this.cacheMw.getDefaultCacheTime();
    } else if (opts?.cacheSeconds !== undefined && opts.cacheSeconds >= 0) {
      resolved = opts.cacheSeconds;
    } else if (opts?.cacheSeconds === undefined && method === 'GET') {
      resolved = this.cacheMw.getDefaultCacheTime();
    }
    // 注入 cacheSeconds 到 custom（引擎层缓存中间件读取）
    if (resolved !== undefined) {
      if (!cfg.custom) {
        cfg.custom = {}
      }
      cfg.custom['cacheSeconds'] = resolved
    }
    // 4. 并发去重：同 url+method+custom 进行中请求共享同一结果
    const dedupKey: string = `${method}\u0001${cfg.url}\u0001${JSON.stringify(cfg.custom)}`
    const pending: Promise<ESObject> | undefined = this.inFlight.get(dedupKey);
    if (pending) {
      zyLog(hilog.info, `[CACHE] 并发去重命中(进行中): [${method}] ${cfg.url}`);
      return pending.then((businessData: ESObject) => this.applyFallback<T>(businessData, fallback));
    }
    // 5. 发请求 → 业务解包（缓存由引擎中间件处理）
    const p: Promise<ESObject> = this.doRequest(cfg).then((response: ESObject): ESObject => {
      return this.unwrapBusiness<ESObject>(response);
    }).finally(() => {
      this.inFlight.delete(dedupKey);
    });
    this.inFlight.set(dedupKey, p as Promise<ESObject>);
    return p.then((businessData: ESObject) => this.applyFallback<T>(businessData, fallback));
  }

  /**
   * 任意 method 业务通道（PATCH/HEAD/OPTIONS 等）：按 cfg.method 原样直发。
   * 已收敛为 runBusiness 薄封装：Mock/raw/缓存/去重/解包逻辑与 get/post 完全一致
   * @param cfg 最终请求配置（method 必须已填充）
   * @param cacheSeconds 缓存时长（秒）；undefined 按默认策略（GET 默认缓存，非 GET 不缓存）
   * @returns 业务体 Promise（ResultDTO 整包，由调用方 Builder 再解 data）
   */
  requestBusiness<T = ESObject>(cfg: HttpRequestConfig, cacheSeconds?: number): Promise<T> {
    return this.runBusiness<T>(cfg, { cacheSeconds: cacheSeconds });
  }

  /**
   * 文件上传业务通道（multipart）：支持 Mock 拦截与业务 code 校验，
   * 内部走引擎上传并解包返回响应体（RequestBuilder.upload 使用）
   * @param url 上传地址
   * @param cfg 上传配置（filePath/name 由构建器写入）
   * @returns 响应体 Promise
   */
  uploadBusiness<T = ESObject>(url: string, cfg?: HttpRequestConfig): Promise<T> {
    const finalCfg = cloneRequestConfig(cfg);
    finalCfg.url = url;
    finalCfg.method = 'POST';
    const mocked: ESObject = this.checkMock(url, 'POST');
    if (mocked !== undefined) {
      return Promise.resolve(this.unwrapBusiness<T>(mocked));
    }
    return this.doRequest(finalCfg).then((response: ESObject) => {
      return this.unwrapBusiness<T>(response);
    });
  }

  /**
   * 发起请求并返回调用句柄：promise resolve 完整 HttpResponse（不做解包）；call.abort() 取消
   * @param cfg 请求配置
   * @returns Call 句柄
   */
  execute<T = ESObject>(cfg: HttpRequestConfig): Call<HttpResponse<T>> {
    const token = new ZyCancelToken();
    // 透传 cancelToken：abort → 引擎 session.cancel(request)，非仅置标志
    const runCfg = cloneRequestConfig(cfg);
    runCfg.cancelToken = token;
    const promise = (async (): Promise<HttpResponse<T>> => {
      const resp: HttpResponse<ESObject> = await this.doRequest(runCfg);
      if (token.isCancelled()) {
        throw ZyCancelToken.cancelledError();
      }
      return resp as ESObject as HttpResponse<T>;
    })() as Promise<HttpResponse<T>>;
    promise.catch((ignore: ESObject) => {
      // Call 句柄的 promise 若调用方未 await，错误不被吞掉（返回给调用方后由其处理）
    });
    const call = new CallHandle<HttpResponse<T>>(promise, (): void => {
      token.cancel();
    });
    return call;
  }

  /**
   * 文件下载（folder 语义）：经引擎 fetch + 官方 configuration.destination 落盘
   * 支持断点续传（config.transferRange）
   * @param url 下载地址
   * @param cfg 下载配置
   * @returns 下载响应（含 tempFilePath）
   */
  download(url: string, cfg?: HttpRequestConfig): Promise<HttpDownloadResponse> {
    const finalCfg = cloneRequestConfig(cfg);
    finalCfg.url = url;
    finalCfg.method = finalCfg.method || 'GET';
    return this.doRequest(finalCfg) as Promise<HttpDownloadResponse>;
  }

  /**
   * 获取底层原生 rcp.Session 实例（逃生舱）：
   * 会话与引擎共享（连接复用），供上层单次使用未封装的原生 RCP 能力
   * @returns 共享的 rcp.Session 实例
   */
  public getSession(): rcp.Session {
    return this.engine.getNativeSession();
  }

  /**
   * 单次原生 RCP 调用（逃生舱）：将共享 rcp.Session 抛给回调，回调返回的 Promise 原样透传
   * @param handler 接收 rcp.Session 的回调
   * @returns 回调返回值原样透传
   */
  public requestNative<T>(handler: (session: rcp.Session) => Promise<T>): Promise<T> {
    return handler(this.engine.getNativeSession());
  }

  /**
   * 按标签批量取消进行中请求
   * @param tag 标签名
   */
  public cancelTag(tag: string): void {
    this.engine.cancelTag(tag);
  }

  /**
   * 取消全部进行中请求
   */
  public cancelAll(): void {
    this.engine.cancelAll();
  }

  /**
   * 配置会话级安全策略（证书校验/TLS 版本/证书锁定，防中间人）：
   * 安全配置为 rcp.Session 级能力，仅能在引擎实例化时传入，
   * 内部通过"重建引擎实例"使其生效（与库内缓存策略构造期配置先例一致）；
   * 旧实例 close() 会释放底层会话并取消其进行中请求，建议仅在 SDK 初始化阶段调用
   * @param security 安全配置（remoteValidation: 'system' 证书校验 / 'skip' 跳过(仅开发测试)；
   *                 tlsVersion: 'TlsV1.0'~'TlsV1.3'；certificatePinning: 证书公钥 SHA256 哈希锁定）
   * @returns 当前实例（支持链式）
   */
  public setSecurityConfig(security: ZySecurityConfig): HttpClient {
    const oldEngine = this.engine;
    this.engine = ZyHttp.create({ logging: false, security: security });
    oldEngine.close();
    return this;
  }

  // ==================== BSCStorage（白山云 S3 兼容对象存储） ====================

  /**
   * 初始化 BSCStorage 凭证（对齐 Java KHelper.init；必填参数经本门面方法传入）：
   * 后续 bscHeadObject/bscPutObject/bscPutObjectBytes/bscAppendObject 均使用该凭证签名
   * @param ak AccessKey
   * @param sk SecretKey
   * @param host 存储域名（如 ss.bscstorage.com；缺省用 BSC_DEFAULT_HOST）
   * @returns 当前实例（支持链式）
   */
  public setBscCredential(ak: string, sk: string, host?: string): HttpClient {
    this.bscAk = ak;
    this.bscSk = sk;
    this.bscHost = host !== undefined && host.length > 0 ? host : BSC_DEFAULT_HOST;
    return this;
  }

  /**
   * BSC 凭证校验（内部）：未初始化时抛参数异常
   */
  private bscCheckCredential(): void {
    if (!this.bscAk || !this.bscSk) {
      throw new BscException(BSC_ERR_PARAM, 'BSC 凭证未初始化，请先调用 setBscCredential(ak, sk)');
    }
  }

  /**
   * BSC 对象 URL 拼接（内部）：https://{bucket}.{host}/{encodedKey}
   */
  private bscObjectUrl(bucket: string, encodedKey: string): string {
    return `https://${bucket}.${this.bscHost}/${encodedKey}`;
  }

  /**
   * BSC 原生请求（内部）：走共享原生会话（绕过业务签名/缓存中间件，S3 签名头不能被污染），
   * timeoutMs 存在时启用软超时（超时主动 cancel 底层请求并 reject）
   */
  private bscFetch(url: string, method: string, headers: Record<string, string>,
    content?: rcp.RequestContent, timeoutMs?: number): Promise<rcp.Response> {
    const session = this.engine.getNativeSession();
    const req = new rcp.Request(url, method, headers, content, undefined, undefined, undefined);
    if (timeoutMs === undefined) {
      return session.fetch(req);
    }
    return new Promise<rcp.Response>((resolve, reject) => {
      let settled = false;
      const timer = setTimeout((): void => {
        if (!settled) {
          settled = true;
          try {
            session.cancel(req);
          } catch (ignore) {
          }
          reject(new BscException(BSC_ERR_NETWORK, `BSC 请求软超时(${timeoutMs}ms): ${method} ${url}`));
        }
      }, timeoutMs);
      session.fetch(req).then((resp: rcp.Response): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(resp);
        }
      }).catch((err: ESObject): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(new BscException(BSC_ERR_NETWORK, `BSC 请求失败: ${err instanceof Error ? err.message : String(err)}`));
        }
      });
    });
  }

  /**
   * BSC AWS V2 签名（内部）：
   * stringToSign = HTTP-Verb\nContent-MD5\nContent-Type\nDate\n[CanonicalizedAmzHeaders]{CanonicalizedResource}
   * x-amz-* 头按字母序参与签名，且同步写入 outHeaders（发出的头与签名头完全一致）
   * @param method 大写 HTTP 方法
   * @param md5Base64 Content-MD5（无则传 undefined）
   * @param contentType Content-Type（无则传 undefined）
   * @param date GMT 日期串
   * @param amzHeaders 参与签名的附加头（x-amz-* 及其他需签名头）
   * @param canonicalResource 规范化资源（/{bucket}/{encodedKey}）
   * @param outHeaders 实际发送的头（签名结果与 amz 头写入此处）
   * @returns Authorization 头值（AWS {ak}:{signature}）
   */
  private bscSign(method: string, md5Base64: string | undefined, contentType: string | undefined,
    date: string, amzHeaders: Record<string, string>, canonicalResource: string,
    outHeaders: Record<string, string>): string {
    const amzKeys: string[] = Object.keys(amzHeaders)
      .filter((k: string): boolean => k.toLowerCase().startsWith('x-amz-'))
      .sort();
    let amzPart = '';
    for (const k of amzKeys) {
      amzPart += `${k.toLowerCase()}:${amzHeaders[k]}\n`;
      outHeaders[k.toLowerCase()] = amzHeaders[k];
    }
    const stringToSign = `${method}\n${md5Base64 ?? ''}\n${contentType ?? ''}\n${date}\n${amzPart}${canonicalResource}`;
    const signature = bscHmacSha1Base64(this.bscSk, stringToSign);
    return `AWS ${this.bscAk}:${signature}`;
  }

  /**
   * BSC HEAD 原始请求（内部）：keyValid=false 时探测 bucket 根（key 不参与 URL 与签名）
   */
  private bscHeadRaw(bucket: string, key: string, keyValid: boolean): Promise<rcp.Response> {
    this.bscCheckCredential();
    const validBucket = bscHandleBucketName(bucket);
    const encodedKey = keyValid ? bscEncodeKeyPath(key) : '';
    const url = this.bscObjectUrl(validBucket, encodedKey);
    const date = bscGmtDate(new Date());
    const headers: Record<string, string> = {};
    headers['Date'] = date;
    headers['Authorization'] = this.bscSign('HEAD', undefined, undefined, date, {},
      `/${validBucket}/${encodedKey}`, headers);
    return this.bscFetch(url, 'HEAD', headers);
  }

  /**
   * BSC HEAD 对象：探测对象是否存在及元信息
   * 404 → exists:false；200 → exists:true + contentLength/eTag/lastModified；其余状态码抛异常
   * @param bucket bucket 名
   * @param key 对象 key
   * @returns HEAD 结果
   */
  public async bscHeadObject(bucket: string, key: string): Promise<BscHeadResult> {
    const resp = await this.bscHeadRaw(bucket, key, true);
    if (resp.statusCode === 404) {
      return { exists: false };
    }
    if (resp.statusCode === 200) {
      const headers = resp.headers as Record<string, string | string[]>;
      const lenStr = bscRespHeader(headers, 'Content-Length');
      const len = lenStr !== undefined ? parseInt(lenStr, 10) : NaN;
      return {
        exists: true,
        contentLength: isNaN(len) ? undefined : len,
        eTag: bscRespHeader(headers, 'ETag'),
        lastModified: bscRespHeader(headers, 'Last-Modified')
      };
    }
    throw new BscException(BSC_ERR_NETWORK, `HEAD 失败: HTTP ${resp.statusCode}`, resp.statusCode);
  }

  /**
   * BSC PUT 对象（文件版）：
   * - key 以 '/' 结尾时自动拼文件名（对齐 Java putObject 行为）
   * - 文件 MD5（64KB 分块计算）作为 Content-MD5 头并参与签名
   * - acl 经 x-amz-acl 头参与签名；options.extraHeaders 中 x-amz-* 按字母序参与签名
   * @param bucket bucket 名
   * @param key 对象 key（以 '/' 结尾自动拼文件名）
   * @param filePath 本地文件路径
   * @param acl canned ACL（缺省 private）
   * @param options 可选项（附加头/软超时）
   */
  public async bscPutObject(bucket: string, key: string, filePath: string,
    acl?: BscCannedAcl, options?: BscPutOptions): Promise<void> {
    this.bscCheckCredential();
    const validBucket = bscHandleBucketName(bucket);
    let finalKey = key;
    if (finalKey.endsWith('/')) {
      const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      finalKey = finalKey + fileName;
    }
    const encodedKey = bscEncodeKeyPath(finalKey);
    const md5Base64 = await bscMd5Base64FromFile(filePath);
    const date = bscGmtDate(new Date());
    const headers: Record<string, string> = {};
    headers['Date'] = date;
    headers['Content-MD5'] = md5Base64;
    const amz: Record<string, string> = {};
    amz['x-amz-acl'] = acl !== undefined ? acl : BSC_CANNED_ACL_PRIVATE;
    if (options && options.extraHeaders) {
      const ks: string[] = Object.keys(options.extraHeaders);
      for (const k of ks) {
        amz[k] = options.extraHeaders[k];
      }
    }
    headers['Authorization'] = this.bscSign('PUT', md5Base64, 'application/octet-stream', date, amz,
      `/${validBucket}/${encodedKey}`, headers);
    const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      const resp = await this.bscFetch(this.bscObjectUrl(validBucket, encodedKey), 'PUT', headers, buf,
        bscToMillis(options));
      if (resp.statusCode !== 200) {
        throw new BscException(BSC_ERR_NETWORK, `PUT 失败: HTTP ${resp.statusCode}`, resp.statusCode);
      }
    } finally {
      fs.closeSync(file);
    }
  }

  /**
   * BSC PUT 对象（字节数组版）：语义同 bscPutObject，数据源为内存 ArrayBuffer
   * @param bucket bucket 名
   * @param key 对象 key
   * @param data 字节数据
   * @param acl canned ACL（缺省 private）
   * @param options 可选项（附加头/软超时）
   */
  public async bscPutObjectBytes(bucket: string, key: string, data: ArrayBuffer,
    acl?: BscCannedAcl, options?: BscPutOptions): Promise<void> {
    this.bscCheckCredential();
    const validBucket = bscHandleBucketName(bucket);
    const encodedKey = bscEncodeKeyPath(key);
    const md5Base64 = bscMd5Base64FromBytes(new Uint8Array(data));
    const date = bscGmtDate(new Date());
    const headers: Record<string, string> = {};
    headers['Date'] = date;
    headers['Content-MD5'] = md5Base64;
    const amz: Record<string, string> = {};
    amz['x-amz-acl'] = acl !== undefined ? acl : BSC_CANNED_ACL_PRIVATE;
    if (options && options.extraHeaders) {
      const ks: string[] = Object.keys(options.extraHeaders);
      for (const k of ks) {
        amz[k] = options.extraHeaders[k];
      }
    }
    headers['Authorization'] = this.bscSign('PUT', md5Base64, 'application/octet-stream', date, amz,
      `/${validBucket}/${encodedKey}`, headers);
    const resp = await this.bscFetch(this.bscObjectUrl(validBucket, encodedKey), 'PUT', headers, data,
      bscToMillis(options));
    if (resp.statusCode !== 200) {
      throw new BscException(BSC_ERR_NETWORK, `PUT 失败: HTTP ${resp.statusCode}`, resp.statusCode);
    }
  }

  /**
   * BSC 追加写对象（白山云 S3 扩展）：
   * 1. HEAD 定位现有对象，取 Content-Length 作为追加位置；404 视为新文件从 0 追加
   * 2. PUT 携带 x-amz-meta-s2-append-position 头（参与签名）
   * 3. 409（位置冲突）自动重试：重新 HEAD 定位再追加（默认最多 3 次）
   * @param bucket bucket 名
   * @param key 对象 key
   * @param data 追加的字节数据
   * @param acl canned ACL（缺省 private）
   * @param options 可选项（附加头/软超时）
   * @param maxRetry 409 冲突最大重试次数（默认 3）
   */
  public async bscAppendObject(bucket: string, key: string, data: ArrayBuffer,
    acl?: BscCannedAcl, options?: BscPutOptions, maxRetry?: number): Promise<void> {
    this.bscCheckCredential();
    const validBucket = bscHandleBucketName(bucket);
    const encodedKey = bscEncodeKeyPath(key);
    const retry = maxRetry !== undefined ? maxRetry : 3;
    const md5Base64 = bscMd5Base64FromBytes(new Uint8Array(data));
    for (let attempt = 0; attempt <= retry; attempt++) {
      // 1. HEAD 定位追加位置（404 → 新文件从 0 开始）
      let position = 0;
      const head = await this.bscHeadObject(validBucket, key);
      if (head.exists && head.contentLength !== undefined) {
        position = head.contentLength;
      }
      // 2. PUT 追加（x-amz-meta-s2-append-position 参与签名）
      const date = bscGmtDate(new Date());
      const headers: Record<string, string> = {};
      headers['Date'] = date;
      headers['Content-MD5'] = md5Base64;
      const amz: Record<string, string> = {};
      amz['x-amz-acl'] = acl !== undefined ? acl : BSC_CANNED_ACL_PRIVATE;
      amz['x-amz-meta-s2-append-position'] = String(position);
      if (options && options.extraHeaders) {
        const ks: string[] = Object.keys(options.extraHeaders);
        for (const k of ks) {
          amz[k] = options.extraHeaders[k];
        }
      }
      headers['Authorization'] = this.bscSign('PUT', md5Base64, 'application/octet-stream', date, amz,
        `/${validBucket}/${encodedKey}`, headers);
      const resp = await this.bscFetch(this.bscObjectUrl(validBucket, encodedKey), 'PUT', headers, data,
        bscToMillis(options));
      if (resp.statusCode === 200) {
        return;
      }
      if (resp.statusCode === 409 && attempt < retry) {
        continue;
      }
      throw new BscException(BSC_ERR_NETWORK,
        `追加写失败: HTTP ${resp.statusCode}${resp.statusCode === 409 ? `(重试 ${retry} 次后仍冲突)` : ''}`,
        resp.statusCode);
    }
  }

  /**
   * 更新全局配置（1.x setConfig 语义：回调返回新配置）
   * @param f 配置变换函数
   */
  public setConfig(f: (config: HttpRequestConfig) => HttpRequestConfig): void {
    const oldBaseURL = this.config.baseURL
    this.config = f(this.config);
    if (this.config.baseURL !== oldBaseURL && this.config.baseURL !== undefined) {
      this.engine.setBaseURL(this.config.baseURL)
    }
  }

}

// 自定义HttpClient创建zyClient
const zyClient = new HttpClient(config);

// 注册内置默认预设（与全局 config 一致），供 zyClient.with('default') 使用
zyClient.registerPreset('default', config)

// 注册 NetBasic.baseUrl 变更回调：解耦 NetBasic 与 HttpClient 的循环依赖
NetBasic.onBaseUrlChange = (newBaseUrl: string): void => {
  updateBaseUrl(newBaseUrl)
}
// 默认业务码处理器：1/'1'/0/'0'/200/'200' 视为成功（真机回归确认本服务端成功码为 1），其余 reject HttpError(kind='business')
// 宿主可经 zyClient.setBusinessCodeHandler(...) 覆盖，传 null 关闭
// zyClient.setBusinessCodeHandler((code: number | string, body: ESObject): boolean =>
//   code === 0 || code === '0' || code === 1 || code === '1' || code === 200 || code === '200')


/**
 * 注入应用 Context，启用磁盘持久化缓存（cacheDir/zy_http_cache）
 * 未注入时缓存自动降级为纯内存缓存（进程退出即失效）
 * 建议在 AbilityStage.onCreate 或 EntryAbility.onWindowStageCreate 中调用：
 * setNetContext(this.context)
 * @param ctx 应用级或 Ability 级 Context
 */
export const setNetContext = (ctx: common.Context): void => {
  ContextHolder.setContext(ctx)
}

/**
 * 动态更换BaseUrl
 * @param newBaseUrl 新的BaseUrl地址
 */
export const updateBaseUrl = (newBaseUrl: string) => {
  zyClient.setConfig((currentConfig: HttpRequestConfig) => {
    const newConfig = cloneRequestConfig(currentConfig);
    newConfig.baseURL = newBaseUrl;
    return newConfig;
  });
}

/**
 * 工厂函数：创建独立的 HttpClient 实例（拥有独立的预设、缓存、引擎）
 * 默认注册 'default' 预设；不自动注册 NetBasic.baseUrl 回调（需手动调用 updateBaseUrl 或自行绑定）
 * @param cfg 实例配置（缺省时使用模块默认 config）
 * @returns 新 HttpClient 实例
 */
export const createHttpClient = (cfg?: HttpRequestConfig): HttpClient => {
  const instance = new HttpClient(cfg ?? config)
  instance.registerPreset('default', cfg ?? config)
  return instance
}

export default zyClient
