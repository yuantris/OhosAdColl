import { AdConfig } from '../../model/AdConfig';
import { IAd } from './IAd';
import { PlatformConfig } from '../../model/PlatformConfig';
import { IndependentAd } from './IndependentAd';
import { PlatformType } from '../../model/PlatformType';

/**
 * 横幅渲染计划：横幅经 AutoAdComponent 等组件自请求自渲染，
 * 平台层只负责解析真实广告位与组件参数，不做 load/show 分离
 */
export interface BannerRenderPlan {
  readonly platformType: PlatformType;
  readonly adId: string;
  /** 仅华为 AutoAdComponent 可用 */
  readonly hwAdType?: number;
  readonly hwAdWidth?: number;
  readonly hwAdHeight?: number;
}

export interface IAdPlatform {
  /**
   * 初始化广告平台
   */
  init(config: PlatformConfig): void;

  /**
   * 获取平台类型
   */
  getPlatformType(): PlatformType;

  /**
   * 创建开屏广告
   */
  createSplashAd(config: AdConfig): IndependentAd;

  /**
   * 创建激励视频广告
   */
  createVideoAd(config: AdConfig): IndependentAd;

  /**
   * 创建插屏广告
   */
  createInterstitialAd(config: AdConfig): IndependentAd;

  /**
   * 加载信息流广告
   */
  loadFeedAd(config: AdConfig): Promise<IAd<ESObject>>;

  /**
   * 解析横幅渲染计划（含真实广告位）；不支持横幅时返回 null
   */
  planBanner(config: AdConfig, realAdId: string, width: number, height: number): BannerRenderPlan | null;

  /**
   * 加载原生自渲染广告（SELF_RENDER 模式）；不支持时抛错触发降级
   * 华为 AdsKit 当前无自渲染能力，会抛 NotSupported
   */
  loadNativeAd(config: AdConfig): Promise<IAd<ESObject>>;
}
