/**
 * 70xx 广告相关错误码
 * 77xx sdk配置错误码
 */
export class ErrCode {
  // 广告开关未开启
  public static AD_CLOSE: number = 7000
  // 广告加载失败
  public static AD_LOAD_FAILED: number = 7001
  // 广告超时
  public static AD_TIMEOUT: number = 7002
  // 没有完整观看视频
  public static NO_FULL_VIDEO: number = 7003
  // 广告类型不匹配/渲染失败
  public static AD_RENDER_FAILED: number = 7004
  // 平台不支持该广告类型（直接降级到下一平台，不重试）
  public static AD_NOT_SUPPORTED: number = 7005

  // 配置infojson异常
  public static CONFIG_INFO: number = 7701
}