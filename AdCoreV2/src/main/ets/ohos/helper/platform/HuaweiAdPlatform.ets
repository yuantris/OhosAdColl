import { BannerRenderPlan, IAdPlatform } from '../impl/IAdPlatform';
import { AdConfig } from '../../model/AdConfig';
import { IAd, SystemAdProps } from '../impl/IAd';
import { RenderMode } from '../../model/RenderMode';
import { AdLoadOptions, AdLoadResult } from '../loader/AdLoaderTypes';
import { LogManager } from '../logger/LogManager';
import { PlatformConfig } from '../../model/PlatformConfig';
import { IndependentAd } from '../impl/IndependentAd';
import { OnAdListener } from '../../interface/OnAdListener';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { OAIDStore } from '../core/OAIDStore';
import { Ohos } from '@zycore/common';
import { advertising } from '@kit.AdsKit';
import { HuaweiSplashAdParams } from '../../interface/HuaweiSplashAdParams';
import { NodeController } from '@kit.ArkUI';
import { PlatformType } from '../../model/PlatformType';
import { HwAdLoaders } from '../loader/HwAdLoader';
import { ErrCode } from '../const/ErrCode';
import { AdError } from '../error/AdError';

export class HuaweiAdPlatform implements IAdPlatform {
  /**
   * 获取平台类型
   */
  getPlatformType(): PlatformType {
    return PlatformType.HUAWEI;
  }

  /**
   * 初始化广告平台
   */
  init(config: PlatformConfig): void {
    // TODO: 实现华为SDK初始化逻辑
    LogManager.info('HuaweiAdPlatform', `HUAWEI init success`);
  }

  /**
   * 创建开屏广告
   */
  createSplashAd(config: AdConfig): IndependentAd {
    return new HuaweiIndependentAd('splash', config);
  }

  /**
   * 创建激励视频广告
   */
  createVideoAd(config: AdConfig): IndependentAd {
    return new HuaweiIndependentAd('video', config);
  }

  /**
   * 创建插屏广告
   */
  createInterstitialAd(config: AdConfig): IndependentAd {
    return new HuaweiIndependentAd('interstitial', config);
  }

  /**
   * 加载信息流广告
   */
  planBanner(config: AdConfig, realAdId: string, width: number, height: number): BannerRenderPlan | null {
    return {
      platformType: PlatformType.HUAWEI,
      adId: realAdId,
      hwAdType: 8,
      hwAdWidth: width,
      hwAdHeight: height
    };
  }

  /**
   * 华为 AdsKit 当前不支持原生自渲染
   */
  async loadNativeAd(config: AdConfig): Promise<IAd<ESObject>> {
    throw new AdError(ErrCode.AD_NOT_SUPPORTED, 'Huawei AdsKit does not support self-render native ad');
  }

  async loadFeedAd(config: AdConfig): Promise<IAd<ESObject>> {
    // 创建华为信息流广告实例
    const huaweiFeedAd = new HuaweiFeedAd(config.getAdId());

    try {
      // 调用广告实例的load方法加载广告
      await huaweiFeedAd.load();
      LogManager.warn('HuaweiAdPlatform',
        `【信息流加载成功】平台=华为, 槽位=${config.getAdSlot()}, 真实ID=${config.getAdId()}`);
      return huaweiFeedAd;
    } catch (error) {
      LogManager.error('HuaweiAdPlatform',
        `${config.getAdId()} loadFeedAd error: ${error instanceof Error ? error.message : String(error)}`);
      throw error instanceof Error ? error : new Error(String(error));
    }
  }
}

/**
 * 华为独立型广告实现
 */
class HuaweiIndependentAd implements IndependentAd {
  private adType: string;
  private config: AdConfig;
  private adListener: OnAdListener | undefined;
  private videoRewardListener: OnVideoRewardListener | undefined;
  private loaded: boolean = false;
  private showed: boolean = false;
  // 华为开屏广告特有参数
  private huaweiAds: Array<advertising.Advertisement> = [];
  private huaweiDisplayOptions: advertising.AdDisplayOptions | undefined;

  constructor(adType: string, config: AdConfig) {
    this.adType = adType;
    this.config = config;
  }

  async load(): Promise<void> {
    // 广告生命周期关键节点统一 warn 级（黄色高亮）+【】突出格式
    LogManager.warn('HuaweiAdPlatform',
      `【广告加载】平台=华为, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);

    const loaders = HwAdLoaders.getInstance();
    const adId = this.config.getAdId();

    let result: AdLoadResult;

    switch (this.adType) {
      case 'splash':
        result = await loaders.splash.load(adId, this.adListener);
        if (result.success && result.data) {
          this.huaweiAds = result.data.ads as Array<advertising.Advertisement>;
          this.huaweiDisplayOptions = result.data.adDisplayOptions as advertising.AdDisplayOptions;
        }
        break;
      case 'video':
        result = await loaders.rewardVideo.load(adId, this.videoRewardListener);
        break;
      case 'interstitial':
        result = await loaders.interstitial.load(adId, this.adListener);
        break;
      default:
        result = AdLoadResult.failure(ErrCode.AD_LOAD_FAILED, `Unknown ad type: ${this.adType}`);
    }

    this.loaded = result.success;
    if (!result.success) {
      const code = result.errorCode ?? ErrCode.AD_LOAD_FAILED;
      const message = result.errorMessage ?? 'Unknown error';
      // 补齐槽位名与真实广告ID，便于错误定位
      LogManager.error('HuaweiAdPlatform',
        `[${this.adType}] 加载失败: 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}, code=${code}, message=${message}`);
      throw new AdError(code, message);
    }
  }

  show(): void {
    LogManager.warn('HuaweiAdPlatform',
      `【广告展示】平台=华为, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
    if (this.isValid()) {
      this.showed = true;
      // 触发广告展示事件
      if (this.adListener && this.adListener.onAdShow) {
        this.adListener.onAdShow();
      }
    }
  }

  destroy(): void {
    LogManager.warn('HuaweiAdPlatform',
      `【广告销毁】平台=华为, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
    this.loaded = false;
    this.showed = false;
    this.huaweiAds = [];
    this.huaweiDisplayOptions = undefined;
    // 触发广告销毁事件
    if (this.adListener && this.adListener.onAdDestroy) {
      this.adListener.onAdDestroy();
    }
  }

  isValid(): boolean {
    return this.loaded && !this.showed;
  }

  isReady(): boolean {
    return this.loaded && !this.showed;
  }

  setAdListener(listener: OnAdListener): void {
    this.adListener = listener;
  }

  setVideoRewardListener(listener: OnVideoRewardListener | undefined): void {
    this.videoRewardListener = listener;
  }

  /**
   * 获取华为开屏广告所需参数
   * 仅对华为开屏广告有效
   */
  getHuaweiAdParams(): HuaweiSplashAdParams {
    return {
      ads: this.huaweiAds,
      displayOptions: this.huaweiDisplayOptions!,
    };
  }
}

/**
 * 华为信息流广告实现
 */
export class HuaweiFeedAd extends IAd<advertising.Advertisement> {
  private adId: string;
  private displayOptions: advertising.AdDisplayOptions | undefined;
  private adOptions: advertising.AdOptions;
  private uniqueId: string = '';
  private adRequestParams: advertising.AdRequestParams;

  public getRenderMode(): RenderMode {
    return RenderMode.SYSTEM_COMPONENT;
  }

  public getSystemProps(): SystemAdProps | undefined {
    const emptyOptions: advertising.AdDisplayOptions = {};
    const opts: object = this.displayOptions ?? emptyOptions;
    return { ads: [this.ad as object], displayOptions: opts };
  }

  public handleAdStatus(status: string): void {
    switch (status) {
      case 'onAdOpen':
        this.onShow();
        break;
      case 'onAdClick':
        this.onClick();
        break;
      case 'onAdClose':
        this.onClose();
        break;
      case 'onAdFail':
        this.onFail(ErrCode.AD_RENDER_FAILED, 'Huawei feed ad render failed');
        break;
      default:
        break;
    }
  }

  /**
   * 构造函数
   * @param adId 广告位ID
   */
  constructor(adId: string) {
    // 初始化为undefined，广告加载后会赋值
    super(undefined as ESObject);
    this.adId = adId;
    this.uniqueId = `feed_ad_${Date.now()}`;

    // 广告配置选项
    this.adOptions = {
      // 是否允许流量下载 0不允许 1允许，不设置以广告主设置为准
      allowMobileTraffic: 0,
      // 是否希望根据 COPPA 的规定将您的内容视为面向儿童的内容: -1默认值，不确定 0不希望 1希望
      tagForChildProtection: -1,
      // 是否希望按适合未达到法定承诺年龄的欧洲经济区 (EEA) 用户的方式处理该广告请求： -1默认值，不确定 0不希望 1希望
      tagForUnderAgeOfPromise: -1,
      // 设置广告内容分级上限: W: 3+,所有受众 PI: 7+,家长指导 J:12+,青少年 A: 16+/18+，成人受众
      adContentClassification: 'A'
    };

    // 广告请求参数
    this.adRequestParams = {
      // 广告位ID
      adId: this.adId,
      // 广告类型：3表示原生广告
      adType: 3,
      // 广告数量
      adCount: 1,
      // 原生广告自定义扩展参数。等所有广告素材下载完后再回调
      enableDirectReturnVideoAd: true,
      // 开放匿名设备标识符
      oaid: OAIDStore.OAID
    };

    // 广告展示参数
    this.displayOptions = {
      // 是否静音，默认不静音
      mute: true,
      colorMode: 1
    };
  }

  /**
   * 获取广告超时时间
   */
  timeout(): number {
    return 30000; // 30秒超时
  }

  /**
   * 获取广告视图控制器
   */
  view(): NodeController | undefined {
    // 华为信息流广告使用AdComponent组件展示，不需要NodeController
    return undefined;
  }

  /**
   * 绑定广告事件
   */
  protected bind(): void {
    // 绑定华为广告事件
    if (this.ad) {
      LogManager.info('HuaweiFeedAd', '绑定广告事件');

      // TODO: 实现华为广告事件监听
      // 可以添加广告点击、展示、关闭等事件监听
    }
  }

  /**
   * 渲染广告
   */
  public render(): void {
    // 华为信息流广告由AdComponent组件渲染，这里不需要额外处理
    LogManager.info('HuaweiFeedAd', '渲染广告');
  }

  /**
   * 销毁广告
   */
  public destroy(): void {
    // 销毁华为广告资源
    LogManager.info('HuaweiFeedAd', '销毁广告');
    this.displayOptions = undefined;
  }

  /**
   * 加载广告
   */
  public load(): Promise<void> {
    return new Promise((resolve, reject) => {
      LogManager.info('HuaweiFeedAd', `加载广告: ${this.adId}`);

      // 广告请求回调监听
      const adLoaderListener: advertising.AdLoadListener = {
        // 广告请求失败回调
        onAdLoadFailure: (errorCode: number, errorMsg: string) => {
          reject(new AdError(errorCode, errorMsg));
        },
        // 广告请求成功回调
        onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
          LogManager.info('HuaweiFeedAd', '广告加载成功');
          if (ads && ads.length > 0) {
            // 保存广告对象
            this.ad = ads[0];
            resolve();
          } else {
            reject(new AdError(ErrCode.AD_LOAD_FAILED, '华为信息流广告加载失败：无可用广告'));
          }
        }
      };
      // 创建AdLoader广告对象
      const load: advertising.AdLoader = new advertising.AdLoader(Ohos.getContext());
      // 调用广告请求接口
      load.loadAd(this.adRequestParams, this.adOptions, adLoaderListener);
    });
  }

  /**
   * 获取华为广告展示选项
   */
  public getDisplayOptions(): advertising.AdDisplayOptions | undefined {
    return this.displayOptions;
  }

  /**
   * 获取广告配置选项
   */
  public getAdOptions(): advertising.AdOptions {
    return this.adOptions;
  }

  /**
   * 获取广告唯一标识
   */
  public getUniqueId(): string {
    return this.uniqueId;
  }

  /**
   * 获取广告位ID
   */
  public getAdId(): string {
    return this.adId;
  }
}
