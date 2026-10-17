import {
  GDTAdLoadConfig,
  GDTAdSDK,
  GDTAdSize,
  GDTError,
  GDTMultiAdLoadListener,
  GDTNativeAd
} from '@gdt/gdt-union-sdk';
import { BusinessError } from '@kit.BasicServicesKit';
import { BannerRenderPlan, IAdPlatform } from '../impl/IAdPlatform';
import { AdConfig } from '../../model/AdConfig';
import { IAd } from '../impl/IAd';
import { NativeAdEntity } from '../impl/NativeAdEntity';
import { NativeAdMaterial } from '../../model/NativeAdMaterial';
import { LogManager } from '../logger/LogManager';
import { PlatformConfig } from '../../model/PlatformConfig';
import { IndependentAd } from '../impl/IndependentAd';
import { OnAdListener } from '../../interface/OnAdListener';
import { PlatformType } from '../../model/PlatformType';
import { Ohos } from '@zycore/common';
import { AdSwitchManager } from '../core/AdSwitchManager';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { display, NodeController, promptAction } from '@kit.ArkUI';
import { TxAdLoaders } from '../loader/TxAdLoader';
import { AdLoadOptions, AdLoadResult } from '../loader/AdLoaderTypes';
import { ErrCode } from '../const/ErrCode';
import { AdError } from '../error/AdError';

export class TencentAdPlatform implements IAdPlatform {
  /**
   * 获取平台类型
   */
  getPlatformType(): PlatformType {
    return PlatformType.TENCENT;
  }

  /**
   * SDK是否已经初始化完成
   */
  private static _isSdkInitialized: boolean = false;

  static get isSdkInitialized(): boolean {
    return TencentAdPlatform._isSdkInitialized;
  }

  static set isSdkInitialized(value: boolean) {
    TencentAdPlatform._isSdkInitialized = value;
  }
  /**
   * 初始化完成的Promise
   */
  private initPromise: Promise<void> | null = null;

  /**
   * 初始化广告平台
   */
  init(config: PlatformConfig): void {
    LogManager.info('TencentAdPlatform', `Tencent init: ${config.getAppId()}`);
    GDTAdSDK.init(Ohos.getContext(), {
      appId: config.getAppId(),
    })
    // 调用init后尽快调用start,否则可能影响广告填充，造成收入下降
    // 启动SDK并保存Promise
    this.initPromise = GDTAdSDK.start().then(result => {
      // 判断SDK是否已经ready
      TencentAdPlatform._isSdkInitialized = true;
      LogManager.info("TencentAdPlatform", `腾讯isReady[${true}], 初始化：code: ${result.code} msg: ${result.msg}`);
    }).catch((error: BusinessError) => {
      LogManager.error("TencentAdPlatform",
        `腾讯初始化失败: ${error instanceof Error ? error.message : String(error)}`);
      TencentAdPlatform._isSdkInitialized = false;
    });
  }

  /**
   * 创建开屏广告
   */
  createSplashAd(config: AdConfig): IndependentAd {
    return new TencentIndependentAd('splash', config);
  }

  /**
   * 创建激励视频广告
   */
  createVideoAd(config: AdConfig): IndependentAd {
    return new TencentIndependentAd('video', config);
  }

  /**
   * 创建插屏广告
   */
  createInterstitialAd(config: AdConfig): IndependentAd {
    return new TencentIndependentAd('interstitial', config);
  }

  /**
   * 加载信息流广告
   */
  async loadFeedAd(config: AdConfig): Promise<IAd<ESObject>> {
    return new Promise((resolve, reject) => {
      const adLoadListener: GDTMultiAdLoadListener<GDTNativeAd> = {
        onAdLoad: (ads: Array<GDTNativeAd>): void => {
          LogManager.warn('TencentAdPlatform',
            `【信息流加载成功】平台=腾讯, 槽位=${config.getAdSlot()}, 真实ID=${config.getAdId()}, 数量=${ads.length}`);
          if (ads && ads.length > 0) {
            // 取第一个广告实例创建TencentFeedAd对象
            const txFeedAd = new TencentFeedAd(ads[0]);
            resolve(txFeedAd);
          } else {
            reject(new AdError(ErrCode.AD_LOAD_FAILED, "No ads returned from server"));
          }
        },
        onError: (err: GDTError): void => {
          LogManager.error("TencentAdPlatform",
            `加载信息流${config.getAdId()}广告失败，code=${err.code}，message=${err.message}`);
          reject(new AdError(err.code, err.message));
        }
      }

      const gdtConfig: GDTAdLoadConfig = {
        posId: config.getAdId(),
        adSize: new GDTAdSize(GDTAdSize.FULL_WIDTH, GDTAdSize.AUTO_HEIGHT)
      };
      GDTAdSDK.getAdLoader().loadNativeAd(gdtConfig, adLoadListener)
    });
  }

  /**
   * 解析横幅渲染计划（优量汇暂不支持横幅）
   */
  planBanner(config: AdConfig, realAdId: string, width: number, height: number): BannerRenderPlan | null {
    return null;
  }

  /**
   * 加载原生自渲染广告（GDT Manual 模式）
   */
  async loadNativeAd(config: AdConfig): Promise<IAd<ESObject>> {
    return new Promise((resolve, reject) => {
      const adLoadListener: GDTMultiAdLoadListener<GDTNativeAd> = {
        onAdLoad: (ads: Array<GDTNativeAd>): void => {
          if (ads && ads.length > 0) {
            const nativeAd = ads[0];
            const material = this.extractMaterial(nativeAd);
            const entity = new NativeAdEntity(nativeAd, material);
            entity.setAdConfig(config);
            resolve(entity);
          } else {
            reject(new AdError(ErrCode.AD_LOAD_FAILED, 'GDT native ad: no ads'));
          }
        },
        onError: (err: GDTError): void => {
          reject(new AdError(err.code, err.message));
        }
      };
      const gdtConfig: GDTAdLoadConfig = {
        posId: config.getAdId(),
        adSize: new GDTAdSize(GDTAdSize.FULL_WIDTH, GDTAdSize.AUTO_HEIGHT)
      };
      GDTAdSDK.getAdLoader().loadNativeAd(gdtConfig, adLoadListener);
    });
  }

  /** 从 GDT 原生广告提取自渲染素材 */
  private extractMaterial(ad: GDTNativeAd): NativeAdMaterial {
    const gdt = ad as object as GDTNativeMaterialSource;
    return {
      title: typeof gdt.getTitle === 'function' ? gdt.getTitle() : '',
      desc: typeof gdt.getDesc === 'function' ? gdt.getDesc() : '',
      iconUrl: typeof gdt.getIconUrl === 'function' ? gdt.getIconUrl() : '',
      imageUrls: typeof gdt.getImgUrl === 'function' && gdt.getImgUrl() ? [gdt.getImgUrl()] : [],
      videoUrl: typeof gdt.getVideoUrl === 'function' ? gdt.getVideoUrl() : '',
      pattern: typeof gdt.getAdPattern === 'function' ? gdt.getAdPattern() : 'single',
      adLogoUrl: typeof gdt.getAdLogoUrl === 'function' ? gdt.getAdLogoUrl() : '',
      actionText: typeof gdt.getButtonText === 'function' ? gdt.getButtonText() : ''
    };
  }
}

/** GDT 原生广告素材字段（按需调用，字段缺失时兜底空串） */
interface GDTNativeMaterialSource {
  getTitle?: () => string;
  getDesc?: () => string;
  getIconUrl?: () => string;
  getImgUrl?: () => string;
  getVideoUrl?: () => string;
  getAdPattern?: () => string;
  getAdLogoUrl?: () => string;
  getButtonText?: () => string;
}

/**
 * 腾讯独立型广告实现
 */
class TencentIndependentAd implements IndependentAd {
  private adType: string;
  private config: AdConfig;
  private adListener: OnAdListener | undefined;
  private videoRewardListener: OnVideoRewardListener | undefined;
  private loaded: boolean = false;
  private showed: boolean = false;
  private nativeHandle: Object | undefined;

  constructor(adType: string, config: AdConfig) {
    this.adType = adType;
    this.config = config;
  }

  async load(): Promise<void> {
    LogManager.warn('TencentAdPlatform',
      `【广告加载】平台=腾讯, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);

    if (this.adType === 'splash') {
      await this.waitForSdkReady();
    }

    const loaders = TxAdLoaders.getInstance();
    const adId = this.config.getAdId();
    const options: AdLoadOptions = { deferShow: true, loadTimeout: this.config.getTimeout() };

    let result: AdLoadResult;

    switch (this.adType) {
      case 'splash':
        result = await loaders.splash.load(adId, this.adListener, options);
        break;
      case 'video':
        result = await loaders.rewardVideo.load(adId, this.videoRewardListener, options);
        break;
      case 'interstitial':
        result = await loaders.interstitial.load(adId, this.adListener, options);
        break;
      default:
        result = AdLoadResult.failure(ErrCode.AD_LOAD_FAILED, `Unknown ad type: ${this.adType}`);
    }

    this.loaded = result.success;
    if (result.success) {
      this.nativeHandle = result.nativeHandle;
    } else {
      const code = result.errorCode ?? ErrCode.AD_LOAD_FAILED;
      const message = result.errorMessage ?? 'Unknown error';
      LogManager.error('TencentAdPlatform',
        `[${this.adType}] 加载失败: 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}, code=${code}, message=${message}`);
      throw new AdError(code, message);
    }
  }

  /**
   * 等待SDK准备就绪
   */
  private async waitForSdkReady(): Promise<void> {
    const MAX_WAIT_TIME = 5000; // 最大等待时间5秒
    const INTERVAL = 100; // 检查间隔100毫秒
    let waitTime = 0;

    while (!TencentAdPlatform.isSdkInitialized && waitTime < MAX_WAIT_TIME) {
      await new Promise<void>(resolve => setTimeout(resolve, INTERVAL));
      waitTime += INTERVAL;
      LogManager.info('TencentAdPlatform', `Waiting for TX SDK ready, elapsed: ${waitTime}ms`);
    }

    if (!TencentAdPlatform.isSdkInitialized) {
      LogManager.warn('TencentAdPlatform', `TX SDK not ready after ${MAX_WAIT_TIME}ms, proceeding anyway`);
    }
  }

  show(): void {
    LogManager.warn('TencentAdPlatform',
      `【广告展示】平台=腾讯, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
    if (!this.isValid() || !this.nativeHandle) {
      LogManager.error('TencentAdPlatform', `show: ad not ready, type=${this.adType}`);
      return;
    }
    this.showed = true;
    const loaders = TxAdLoaders.getInstance();
    switch (this.adType) {
      case 'splash':
        loaders.splash.show?.(this.nativeHandle);
        break;
      case 'video':
        loaders.rewardVideo.show?.(this.nativeHandle);
        break;
      case 'interstitial':
        loaders.interstitial.show?.(this.nativeHandle);
        break;
    }
    if (this.adListener && this.adListener.onAdShow) {
      this.adListener.onAdShow();
    }
  }

  isReady(): boolean {
    return this.loaded && !this.showed && this.nativeHandle !== undefined;
  }

  destroy(): void {
    LogManager.warn('TencentAdPlatform',
      `【广告销毁】平台=腾讯, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
    this.loaded = false;
    this.showed = false;
    this.nativeHandle = undefined;
    if (this.adListener && this.adListener.onAdDestroy) {
      this.adListener.onAdDestroy();
    }
  }

  isValid(): boolean {
    return this.loaded && !this.showed;
  }

  setAdListener(listener: OnAdListener): void {
    this.adListener = listener;
  }

  setVideoRewardListener(listener: OnVideoRewardListener): void {
    this.videoRewardListener = listener;
  }
}

/**
 * 腾讯信息流广告实现
 */
class TencentFeedAd extends IAd<GDTNativeAd> {
  /**
   * 构造函数
   * @param ad GDTNativeAd
   */
  constructor(ad: GDTNativeAd) {
    super(ad);
    // 设置视频监听
    this.setVideoListener(ad);
  }

  public timeout(): number {
    return 30000; // 30秒超时
  }

  public view(): NodeController | undefined {
    return this.ad.getAdComponent()
  }

  protected bind(): void {
    this.bindRenderListener()
    this.ad.setInteractionListener({
      onAdExposure: (): void => {
        LogManager.info('TencentFeedAd', '信息流 - onAdExposure......');
        super.onShow()
      },
      onAdClick: (): void => {
        LogManager.info('TencentFeedAd', '信息流 - onAdClick......');
        super.onClick()
      },
      onAdClose: (): void => {
        LogManager.info('TencentFeedAd', '信息流 - onAdClose......');
        super.onClose()
      },
      onError: (err: GDTError): void => {
        super.onFail(err.code, err.message)
        if (AdSwitchManager.enableADToast && Ohos.debug()) {
          promptAction.showToast({
            message: `腾讯广告出现错误: ${err.code}, ${err.message}`
          })
        }
      }
    });
  }

  public render(): void {
    LogManager.info('TencentFeedAd', '信息流 - render......');
    // 调用 render 方法前需要 setRenderListener，render success 后可以展示
    try {
      this.ad.setVideoOptions({ autoPlayMuted: true });
      this.ad.render(Ohos.getWindowStage(), Ohos.getUIContext());
    } catch (error) {
      LogManager.error('TencentFeedAd', `信息流渲染失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  public destroy(): void {
    LogManager.info('TencentFeedAd', '信息流 - destroy......');
    this.ad.destroy()
  }

  private setVideoListener(ad: GDTNativeAd): void {
    ad.setVideoStateListener({
      onVideoReady: (): void => {
        LogManager.info("TencentFeedAd", `信息流 - onVideoReady......`);
      },
      onVideoStart: (): void => {
        LogManager.info("TencentFeedAd", `信息流 - onVideoStart......`);
      },
      onVideoPause: (): void => {
        LogManager.info("TencentFeedAd", `信息流 - onVideoPause......`);
      },
      onVideoResume: (): void => {
        LogManager.info("TencentFeedAd", `信息流 - onVideoResume......`);
      },
      onVideoComplete: (): void => {
        LogManager.info("TencentFeedAd", `信息流 - onVideoComplete......`);
      },
      onVideoError: (err: GDTError): void => {
        LogManager.error("TencentFeedAd", `信息流 - onVideoError......`, err);
      }
    });
  }

  private bindRenderListener() {
    this.ad.setRenderListener({
      onRenderSuccess: (): void => {
        super.onRender()
      },
      onRenderFail: (err: GDTError): void => {
        if (AdSwitchManager.enableADToast && Ohos.debug()) {
          promptAction.showToast({
            message: `广告渲染失败${JSON.stringify(err)}`
          })
        }
      }
    });
  }
}
