export class AdConst {
  public static readonly BASE_URL: string = "https://zyapp.ss.bscstorage.com/android/sdk/ads/";
}

// 广告类型
export enum ZYAdType {
  SPLASH = 1, // 开屏
  SCREEN = 2, // 插屏
  INFO = 3, // 信息流
  BANNER = 4, // Banner
  VIDEO = 5, // 激励视频
}