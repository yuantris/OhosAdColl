import { BusinessError } from '@kit.BasicServicesKit';
import { getRcpErrorMessage, isCancelRcpCode, isNonRetryableRcpCode, ERR_CELLULAR_UNAVAILABLE } from './RcpErrorCodes';

/**
 * 错误类别(六类)
 * - CANCEL:    请求被取消(调用方 abort / 官方取消类错误码 1007900992 等)
 * - NETWORK:   网络层失败(域名解析/连接/超时/SSL/蜂窝不可用等)
 * - HTTP:      HTTP 状态码校验未通过(validateStatus 或官方 validateResponse)
 * - PARSE:     响应体解析失败(toJSON/toString 异常等)
 * - BUSINESS:  业务码校验未通过(HTTP 成功但业务 code 非成功)
 * - UNKNOWN:   未归类的异常
 */
export type ZyNetErrorKind = 'cancel' | 'network' | 'http' | 'parse' | 'business' | 'unknown';

/**
 * 故障扩展字段(来源: 官方《故障日志关键字段说明》文档)
 * RCP 失败时通过 err.data 携带, 用于精准定位故障阶段(定位思路见官方 FAQ: RCP响应结果解析及常见问题定位思路)
 */
export interface ZyNetErrorFields {
  /** httpPhase: HTTP 失败所处的阶段 */
  httpPhase?: string;
  /** dnsDur: DNS 解析耗时(ms) */
  dnsDur?: number;
  /** tcpDur: TCP 连接耗时(ms) */
  tcpDur?: number;
  /** tlsDur: TLS 握手耗时(ms) */
  tlsDur?: number;
  /** sndDur: 发送耗时(ms) */
  sndDur?: number;
  /** rcvDur: 接收耗时(ms) */
  rcvDur?: number;
  /** totDur: 总耗时(ms) */
  totDur?: number;
  /** redDur: 重定向耗时(ms) */
  redDur?: number;
  /** osErr: 系统错误码 */
  osErr?: number;
  /** proxyType: 代理类型 */
  proxyType?: string;
  /** proxyCode: 代理错误码 */
  proxyCode?: number;
  /** proxyErr: 代理错误信息 */
  proxyErr?: string;
  /** dnsStatus: DNS 解析状态 */
  dnsStatus?: number;
  /** srcAddr/srcPort: 本端地址/端口 */
  srcAddr?: string;
  srcPort?: number;
  /** dstAddr/dstPort: 对端地址/端口 */
  dstAddr?: string;
  dstPort?: number;
  /** peer: 对端信息 */
  peer?: string;
  /** sslConnE: SSL 连接错误信息 */
  sslConnE?: string;
  /** sslErr: SSL 错误信息 */
  sslErr?: string;
}

/**
 * ZyNet 统一错误
 * 兼容 Error, 直接 throw 给调用方; kind/code/statusCode 供程序化分支处理
 */
export class ZyHttpError extends Error {
  /** 错误类别 */
  kind: ZyNetErrorKind;
  /** 底层系统错误码(RCP BusinessError.code 透传, 如蜂窝不可用 1007900986) */
  code?: number;
  /** HTTP 状态码(kind='http' 时有值) */
  statusCode?: number;
  /** 原始错误对象(BusinessError / rcp.Response 等, 便于深度排查) */
  cause?: ESObject;
  /** 故障扩展字段(官方 error-field, httpPhase/耗时/OS错误/代理/DNS/SSL等) */
  errorFields?: ZyNetErrorFields;
  /** 是否应该重试(由错误码分类推导: 取消/环境/配置类为 false) */
  retryable: boolean;

  constructor(kind: ZyNetErrorKind, message: string, retryable: boolean = false,
    statusCode?: number, code?: number, cause?: ESObject, errorFields?: ZyNetErrorFields) {
    super(message);
    this.name = 'ZyHttpError';
    this.kind = kind;
    this.retryable = retryable;
    if (statusCode !== undefined) {
      this.statusCode = statusCode;
    }
    if (code !== undefined) {
      this.code = code;
    }
    if (cause !== undefined) {
      this.cause = cause;
    }
    if (errorFields !== undefined) {
      this.errorFields = errorFields;
    }
  }

  /**
   * 判断是否为设备网络环境类错误(蜂窝不可用/存储IO/内存不足等)
   * 业务侧可据此提示用户检查设备网络, 而非继续等待
   */
  isEnvironmentError(): boolean {
    return this.kind === 'network' && this.code !== undefined && isNonRetryableRcpCode(this.code);
  }

  /** 语义化判定: 网络层错误(替代 kind === 'network' 字符串比较) */
  isNetwork(): boolean {
    return this.kind === 'network';
  }

  /** 语义化判定: 请求被取消 */
  isCancel(): boolean {
    return this.kind === 'cancel';
  }

  /** 语义化判定: HTTP 状态码校验未通过 */
  isHttpError(): boolean {
    return this.kind === 'http';
  }

  /** 语义化判定: 业务码校验未通过 */
  isBusinessError(): boolean {
    return this.kind === 'business';
  }

  /** 语义化判定: 响应体解析失败 */
  isParseError(): boolean {
    return this.kind === 'parse';
  }
}

/**
 * 从任意异常构建 ZyHttpError(统一错误出口)
 * 分类规则:
 * 1. 已是 ZyHttpError → 原样返回
 * 2. 官方取消类错误码 → kind='cancel'
 * 3. 其余 RCP 错误码 → kind='network', message 用官方中文描述表(蜂窝不可用给出可操作指引), retryable 按分类推导
 * 4. 非 RCP 异常 → kind='unknown', 沿用系统 message
 * @param err 原始异常
 * @returns 标准化错误
 */
export function toZyHttpError(err: ESObject): ZyHttpError {
  if (err instanceof ZyHttpError) {
    return err;
  }
  const be = err as BusinessError;
  const code: number | undefined = be?.code;
  // 1) 官方取消类错误码 → cancel(重试无意义)
  if (code !== undefined && isCancelRcpCode(code)) {
    return new ZyHttpError('cancel', `请求已取消(code=${code})`, false, undefined, code, err,
      extractErrorFields(be?.data));
  }
  // 2) RCP 错误码 → network + 官方中文描述
  if (code !== undefined) {
    const officialDesc: string | undefined = getRcpErrorMessage(code);
    let message: string;
    if (officialDesc !== undefined) {
      message = code === ERR_CELLULAR_UNAVAILABLE
        ? `蜂窝网络不可用, 请检查飞行模式或SIM卡状态(code=${code})`
        : `${officialDesc}(code=${code})`;
    } else {
      message = be?.message || `网络请求失败(code=${code})`;
    }
    return new ZyHttpError('network', message, !isNonRetryableRcpCode(code), undefined, code, err,
      extractErrorFields(be?.data));
  }
  // 3) 非 RCP 异常
  const msg: string = err instanceof Error ? err.message : String(err);
  return new ZyHttpError('unknown', msg || '未知错误', false, undefined, undefined, err);
}

/**
 * 从 BusinessError.data 中提取官方故障扩展字段(error-field)
 * @param data BusinessError.data(rcp 失败时携带的故障信息对象)
 * @returns 可读的故障扩展字段; 无数据时返回 undefined
 */
function extractErrorFields(data: ESObject): ZyNetErrorFields | undefined {
  if (data === undefined || data === null) {
    return undefined;
  }
  const fields: ZyNetErrorFields = {};
  const src = data as Record<string, ESObject>;
  if (typeof src['httpPhase'] === 'string') {
    fields.httpPhase = src['httpPhase'] as string;
  }
  if (typeof src['osErr'] === 'number') {
    fields.osErr = src['osErr'] as number;
  }
  if (typeof src['dnsDur'] === 'number') {
    fields.dnsDur = src['dnsDur'] as number;
  }
  if (typeof src['tcpDur'] === 'number') {
    fields.tcpDur = src['tcpDur'] as number;
  }
  if (typeof src['tlsDur'] === 'number') {
    fields.tlsDur = src['tlsDur'] as number;
  }
  if (typeof src['sndDur'] === 'number') {
    fields.sndDur = src['sndDur'] as number;
  }
  if (typeof src['rcvDur'] === 'number') {
    fields.rcvDur = src['rcvDur'] as number;
  }
  if (typeof src['totDur'] === 'number') {
    fields.totDur = src['totDur'] as number;
  }
  if (typeof src['proxyType'] === 'string') {
    fields.proxyType = src['proxyType'] as string;
  }
  if (typeof src['srcAddr'] === 'string') {
    fields.srcAddr = src['srcAddr'] as string;
  }
  if (typeof src['dstAddr'] === 'string') {
    fields.dstAddr = src['dstAddr'] as string;
  }
  if (typeof src['sslErr'] === 'string') {
    fields.sslErr = src['sslErr'] as string;
  }
  const keys: string[] = Object.keys(fields);
  return keys.length > 0 ? fields : undefined;
}
