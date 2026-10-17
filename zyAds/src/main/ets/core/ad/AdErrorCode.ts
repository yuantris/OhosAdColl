/**
 * 广告错误码枚举
 * 定义了广告系统中可能出现的各种错误码及其含义
 */
export enum AdErrorCode {
  // 成功状态码
  SUCCESS = 0,

  // 网络相关错误码 (1000-1999)
  NETWORK_ERROR = 1000,
  NETWORK_TIMEOUT = 1001,
  NETWORK_INVALID_RESPONSE = 1002,
  NETWORK_UNREACHABLE = 1003,

  // 数据解析错误码 (2000-2999)
  PARSE_JSON_ERROR = 2000,
  PARSE_DATA_FORMAT_ERROR = 2001,
  PARSE_MISSING_REQUIRED_FIELD = 2002,

  // 业务逻辑错误码 (3000-3999)
  BUSINESS_EMPTY_AD_LIST = 3000,
  BUSINESS_INVALID_AD_DATA = 3001,
  BUSINESS_AD_EXPIRED = 3002,
  BUSINESS_AD_NOT_FOUND = 3003,

  // 参数错误码 (4000-4999)
  PARAM_INVALID = 4000,
  PARAM_MISSING = 4001,
  PARAM_TYPE_ERROR = 4002,

  // 系统错误码 (5000-5999)
  SYSTEM_UNKNOWN_ERROR = 5000,
  SYSTEM_INTERNAL_ERROR = 5001,
  SYSTEM_MEMORY_ERROR = 5002,

  // 权限错误码 (6000-6999)
  PERMISSION_DENIED = 6000,
  PERMISSION_NOT_GRANTED = 6001
}

/**
 * 错误码工具类
 * 提供错误码相关的工具方法
 */
export class ErrorCodeUtils {
  /**
   * 获取错误码对应的描述信息
   * @param code 错误码
   * @returns 错误描述
   */
  static getErrorMessage(code: AdErrorCode): string {
    switch (code) {
      case AdErrorCode.SUCCESS:
        return "操作成功";
      case AdErrorCode.NETWORK_ERROR:
        return "网络错误";
      case AdErrorCode.NETWORK_TIMEOUT:
        return "网络超时";
      case AdErrorCode.NETWORK_INVALID_RESPONSE:
        return "服务器返回数据格式错误";
      case AdErrorCode.NETWORK_UNREACHABLE:
        return "网络不可达";
      case AdErrorCode.PARSE_JSON_ERROR:
        return "JSON解析失败";
      case AdErrorCode.PARSE_DATA_FORMAT_ERROR:
        return "数据格式错误";
      case AdErrorCode.PARSE_MISSING_REQUIRED_FIELD:
        return "缺少必需字段";
      case AdErrorCode.BUSINESS_EMPTY_AD_LIST:
        return "广告列表为空";
      case AdErrorCode.BUSINESS_INVALID_AD_DATA:
        return "广告数据无效";
      case AdErrorCode.BUSINESS_AD_EXPIRED:
        return "广告已过期";
      case AdErrorCode.BUSINESS_AD_NOT_FOUND:
        return "广告不存在";
      case AdErrorCode.PARAM_INVALID:
        return "参数无效";
      case AdErrorCode.PARAM_MISSING:
        return "缺少参数";
      case AdErrorCode.PARAM_TYPE_ERROR:
        return "参数类型错误";
      case AdErrorCode.SYSTEM_UNKNOWN_ERROR:
        return "未知系统错误";
      case AdErrorCode.SYSTEM_INTERNAL_ERROR:
        return "系统内部错误";
      case AdErrorCode.SYSTEM_MEMORY_ERROR:
        return "内存不足";
      case AdErrorCode.PERMISSION_DENIED:
        return "权限被拒绝";
      case AdErrorCode.PERMISSION_NOT_GRANTED:
        return "权限未授予";
      default:
        return "未知错误";
    }
  }

  /**
   * 判断错误码是否为网络错误
   * @param code 错误码
   * @returns 是否为网络错误
   */
  static isNetworkError(code: AdErrorCode): boolean {
    return code >= 1000 && code < 2000;
  }

  /**
   * 判断错误码是否为业务错误
   * @param code 错误码
   * @returns 是否为业务错误
   */
  static isBusinessError(code: AdErrorCode): boolean {
    return code >= 3000 && code < 4000;
  }

  /**
   * 判断错误码是否为系统错误
   * @param code 错误码
   * @returns 是否为系统错误
   */
  static isSystemError(code: AdErrorCode): boolean {
    return code >= 5000 && code < 6000;
  }
}