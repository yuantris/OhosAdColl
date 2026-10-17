import { rcp } from '@kit.RemoteCommunicationKit';
import { ZyResponseType, ZyTimeout, ZyRetry, ZyBusinessCodeHandler, ZyValidateStatus } from './ZyHttpConfig';
import { ZyCancelToken } from './ZyCancelToken';

/** 请求 ID 自增序列(日志与并发区分, 格式 #0001) */
let REQUEST_SEQ: number = 0;

/**
 * 生成递增请求 ID(#0001 格式, 并发请求可区分)
 * @returns 请求 ID
 */
export function nextRequestId(): string {
  REQUEST_SEQ += 1;
  const seq: string = REQUEST_SEQ.toString();
  return `#${seq.padStart(4, '0')}`;
}

/**
 * 内部请求对象(洋葱模型中间件的可变操作目标)
 * 由 ZyRequestBuilder 构建; 与 ZyHttpConfig 的差异在于:
 * - url 已完成 baseURL/path/query 拼接, 中间件可直接改写
 * - headers 为 Map(可变), 便于中间件注入
 * - 携带执行期状态: requestId / resolvedStatus / resolvedDurationMs(日志中间件回填)
 */
export class ZyHttpRequestInternal {
  /** 请求 ID(#0001 格式) */
  readonly requestId: string;
  /** HTTP 方法(官方 HttpMethod 字面量) */
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD';
  /** 完整 URL(已拼接 baseURL 与 query) */
  url: string;
  /** 请求头(可变; 中间件可注入) */
  headers: Map<string, string>;
  /** 请求体(官方 RequestContent: string | ArrayBuffer | Object | Form | MultipartForm 等) */
  content?: rcp.RequestContent;
  /** 响应体解析类型 */
  responseType: ZyResponseType;
  /** 超时(请求级覆盖实例级; undefined 时用实例级) */
  timeout?: ZyTimeout;
  /** 重试策略(请求级覆盖实例级; undefined 时用实例级) */
  retry?: ZyRetry;
  /** 业务码校验(请求级覆盖实例级) */
  businessCodeHandler?: ZyBusinessCodeHandler;
  /** 状态码校验(请求级覆盖实例级; 默认 2xx 通过) */
  validateStatus?: ZyValidateStatus;
  /** 取消令牌 */
  cancelToken?: ZyCancelToken;
  /** 取消标签(批量取消 ZyHttp.cancelTag) */
  tag?: string;
  /** 是否采集时间信息(collectTimeInfo) */
  collectTimeInfo: boolean;
  /** 本次请求跳过的中间件名列表(按 name 匹配, 如 ['sign', 'log']) */
  skipNames: string[];
  /** 请求级自定义数据(中间件可读写, 如 tokenSpec/cacheSeconds) */
  custom?: Record<string, ESObject>;
  /** 执行期回填: 最终 HTTP 状态码 */
  resolvedStatus?: number;
  /** 执行期回填: 请求总耗时(ms) */
  resolvedDurationMs?: number;

  constructor(method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD', url: string) {
    this.requestId = nextRequestId();
    this.method = method;
    this.url = url;
    this.headers = new Map<string, string>();
    this.responseType = 'json';
    this.collectTimeInfo = false;
    this.skipNames = new Array<string>();
  }
}
