import { AdErrorCode, ErrorCodeUtils } from './AdErrorCode';


/**
 * 广告系统自定义异常类
 * 封装广告相关的异常信息，包含错误码、错误消息和额外数据
 */
export class AdException extends Error {
  /**
   * 错误码
   */
  public readonly code: AdErrorCode;

  /**
   * 错误消息
   */
  public readonly message: string;

  /**
   * 额外数据（可选）
   */
  public readonly data?: any;

  /**
   * 时间戳
   */
  public readonly timestamp: number;

  /**
   * 构造函数
   * @param code 错误码
   * @param message 错误消息（可选，如果未提供将使用错误码的默认消息）
   * @param data 额外数据（可选）
   */
  constructor(code: AdErrorCode, message?: string, data?: any) {
    super(message);
    this.code = code;
    this.message = message || this.getDefaultMessage(code);
    this.data = data;
    this.timestamp = Date.now();
    this.name = 'AdException';
  }

  /**
   * 获取默认的错误消息
   * @param code 错误码
   * @returns 默认错误消息
   */
  private getDefaultMessage(code: AdErrorCode): string {
    return ErrorCodeUtils.getErrorMessage(code);
  }

  /**
   * 创建网络异常
   * @param message 错误消息
   * @param data 额外数据
   * @returns AdException实例
   */
  static networkError(message?: string, data?: any): AdException {
    return new AdException(AdErrorCode.NETWORK_ERROR, message, data);
  }

  /**
   * 创建数据解析异常
   * @param message 错误消息
   * @param data 额外数据
   * @returns AdException实例
   */
  static parseError(message?: string, data?: any): AdException {
    return new AdException(AdErrorCode.PARSE_JSON_ERROR, message, data);
  }

  /**
   * 创建业务异常
   * @param message 错误消息
   * @param data 额外数据
   * @returns AdException实例
   */
  static businessError(message?: string, data?: any): AdException {
    return new AdException(AdErrorCode.BUSINESS_INVALID_AD_DATA, message, data);
  }

  /**
   * 创建参数异常
   * @param message 错误消息
   * @param data 额外数据
   * @returns AdException实例
   */
  static paramError(message?: string, data?: any): AdException {
    return new AdException(AdErrorCode.PARAM_INVALID, message, data);
  }

  /**
   * 创建系统异常
   * @param message 错误消息
   * @param data 额外数据
   * @returns AdException实例
   */
  static systemError(message?: string, data?: any): AdException {
    return new AdException(AdErrorCode.SYSTEM_UNKNOWN_ERROR, message, data);
  }

  /**
   * 转换为字符串表示
   * @returns 字符串表示
   */
  toString(): string {
    return `AdException {
  code: ${this.code},
  message: "${this.message}",
  name: "${this.name}",
  timestamp: ${this.timestamp},
  data: ${this.data ? JSON.stringify(this.data) : 'undefined'}
}`;
  }

  /**
   * 转换为JSON对象
   * @returns JSON对象
   */
  toJSON(): object {
    return {
      code: this.code,
      message: this.message,
      name: this.name,
      timestamp: this.timestamp,
      data: this.data,
      stack: this.stack
    };
  }
}