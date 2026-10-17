import { rcp } from '@kit.RemoteCommunicationKit';
import { ZyTimeMetrics, computeTimeMetrics } from '../util/ZyTranslate';

/**
 * ZyNet 统一响应(泛型)
 * data 为按 responseType 解析后的业务数据:
 * - 'json' → ESObject(对象/数组)
 * - 'text' → string
 * - 'arraybuffer' → ArrayBuffer
 * 通过 get<T> 的泛型参数声明业务结构, 运行时为类型断言(擦除), 不做结构校验
 */
export class ZyHttpResponse<T> {
  /** HTTP 状态码 */
  readonly status: number;
  /** 响应头(官方 ResponseHeaders: Record<string, string | string[]>) */
  readonly headers: Record<string, string | string[]>;
  /** 最终生效 URL(重定向后; 官方 effectiveUrl, 转字符串) */
  readonly url: string;
  /** 解析后的业务数据 */
  readonly data: T;
  /** 请求耗时派生指标(collectTimeInfo 开启时存在) */
  readonly time?: ZyTimeMetrics;
  /** 官方原始响应(需要 cookies/debugInfo/raw 等深度能力时透出; 中间件降级构建的响应无原始响应) */
  readonly raw?: rcp.Response;
  /** 是否为中间件降级构建的兜底响应(onResponseError 链吞错后 respond 生成) */
  readonly recovered: boolean;

  /**
   * @param raw 官方原始响应(降级构建时为 undefined)
   * @param data 已解析的业务数据(由 ZyHttp 按 responseType 解析)
   * @param recoveredMode 内部标记: 降级响应构建模式(仅 ZyHttpResponse.recovered 使用)
   */
  constructor(raw: rcp.Response | undefined, data: T, recoveredMode: boolean = false) {
    this.raw = raw;
    this.recovered = recoveredMode;
    this.status = recoveredMode ? 0 : (raw !== undefined ? raw.statusCode : 0);
    this.headers = recoveredMode ? {} : (raw !== undefined ? (raw.headers as Record<string, string | string[]>) : {});
    this.url = (!recoveredMode && raw !== undefined && raw.effectiveUrl !== undefined)
      ? raw.effectiveUrl.toString() : '';
    this.data = data;
    if (!recoveredMode && raw !== undefined && raw.timeInfo !== undefined) {
      this.time = computeTimeMetrics(raw.timeInfo);
    }
  }

  /**
   * 构建中间件降级兜底响应(无原始 rcp.Response, status=0 标识)
   * 供 onResponseError 链吞错时返回兜底数据, 实现降级不中断业务
   * @param data 兜底数据
   */
  static recovered<T>(data: T): ZyHttpResponse<T> {
    return new ZyHttpResponse<T>(undefined, data, true);
  }

  /**
   * 读取响应头(多值头返回首个值)
   * @param name 头名称(不区分大小写场景由调用方保证一致)
   * @returns 头值; 不存在返回 undefined
   */
  header(name: string): string | undefined {
    const value: string | string[] | undefined = this.headers[name];
    if (value === undefined) {
      return undefined;
    }
    return Array.isArray(value) ? value[0] : value;
  }

  /**
   * 响应体转对象(官方 Response.toJSON; 降级响应返回 data)
   */
  toJSON(): ESObject {
    const raw = this.raw;
    if (raw === undefined) {
      return this.data as ESObject;
    }
    return raw.toJSON();
  }

  /**
   * 响应体转字符串(官方 Response.toString, null 兜底为空串)
   */
  toString(): string {
    const raw = this.raw;
    if (raw === undefined) {
      return '';
    }
    const text: string | null = raw.toString();
    return text ?? '';
  }
}
