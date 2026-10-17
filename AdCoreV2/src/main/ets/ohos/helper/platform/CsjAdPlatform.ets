import {
  AdSlotBuilder,
  CSJAdSdk,
  CSJConstant,
  CSJNativeExpressAd,
  NativeExpressAdListener,
  SDKConfig,
  SDKConfigBuilder
} from '@csj/openadsdk';
import { BusinessError } from '@kit.BasicServicesKit';
import { BannerRenderPlan, IAdPlatform } from '../impl/IAdPlatform';
import { NativeAdEntity } from '../impl/NativeAdEntity';
import { NativeAdMaterial } from '../../model/NativeAdMaterial';
import { AdConfig } from '../../model/AdConfig';
import { IAd } from '../impl/IAd';
import { LogManager } from '../logger/LogManager';
import { PlatformConfig } from '../../model/PlatformConfig';
import { IndependentAd } from '../impl/IndependentAd';
import { OnAdListener } from '../../interface/OnAdListener';
import { Ohos } from '@zycore/common';
import { PlatformType } from '../../model/PlatformType';
import { NodeController } from '@kit.ArkUI';
import { ArrayList } from '@kit.ArkTS';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { CSJController } from './csj/CSJController';
import { CsjAdLoaders } from '../loader/CsjAdLoader';
import { AdLoadOptions, AdLoadResult } from '../loader/AdLoaderTypes';
import { ErrCode } from '../const/ErrCode';
import { AdError } from '../error/AdError';

export class CsjAdPlatform implements IAdPlatform {
  /**
   * 获取平台类型
   */
  getPlatformType(): PlatformType {
    return PlatformType.CSJ;
  }

  /**
   * SDK是否已经初始化完成
   */
  private isSdkInitialized: boolean = false;
  /**
   * 初始化完成的Promise
   */
  private initPromise: Promise<void> | null = null;

  /**
   * 初始化广告平台
   */
  init(config: PlatformConfig): void {
    LogManager.info('CsjAdPlatform', `CSJ init: ${config.getAppId()}`);
    // 创建SDKConfig对象
    let adConfigBuilder = new SDKConfigBuilder()
    let csjConfig: SDKConfig = adConfigBuilder
      .appId(config.getAppId())
      .allowShowNotify(true)
      .customController(new CSJController())
      .debug(config.isDebug())
      .build()
    // 初始化SDK
    CSJAdSdk.init(Ohos.getContext(), csjConfig) //context类型必须为UIAbility，否则可能存在展示异常场景

    // 启动SDK并保存Promise
    this.initPromise = CSJAdSdk.start().then(result => {
      // 判断SDK是否已经ready
      let isReady = CSJAdSdk.isSdkReady()
      this.isSdkInitialized = isReady;
      LogManager.info("CsjAdPlatform", `穿山甲isReady[${isReady}], 初始化：code: ${result.code} msg: ${result.msg}`);
    }).catch((error: BusinessError) => {
      LogManager.error("CsjAdPlatform", `穿山甲初始化失败: ${error instanceof Error ? error.message : String(error)}`);
      this.isSdkInitialized = false;
    });
  }

  /**
   * 创建开屏广告
   */
  createSplashAd(config: AdConfig): IndependentAd {
    return new CsjIndependentAd('splash', config);
  }

  /**
   * 创建激励视频广告
   */
  createVideoAd(config: AdConfig): IndependentAd {
    return new CsjIndependentAd('video', config);
  }

  /**
   * 创建插屏广告
   */
  createInterstitialAd(config: AdConfig): IndependentAd {
    return new CsjIndependentAd('interstitial', config);
  }

  /**
   * 加载信息流广告
   */
  async loadFeedAd(config: AdConfig): Promise<IAd<ESObject>> {
    return new Promise((resolve, reject) => {
      // 创建广告加载监听器
      const expressLoadAdListener: NativeExpressAdListener = {
        /**
         * 广告加载失败
         */
        onError: (code: number, message: string) => {
          LogManager.error("CsjAdPlatform", `加载信息流${config.getAdId()}广告失败，code=${code}，message=${message}`);
          reject(new AdError(code, message));
        },

        /**
         * 广告加载成功
         */
        onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
          LogManager.info("CsjAdPlatform", `信息流广告加载成功，数量：${ads.length}`);
          if (ads && ads.length > 0) {
            // 取第一个广告实例创建CsjFeedAd对象
            const csjFeedAd = new CsjFeedInfoAd(ads[0]);
            resolve(csjFeedAd);
          } else {
            reject(new AdError(ErrCode.AD_LOAD_FAILED, "No ads returned from server"));
          }
        }
      };

      // 创建AdSlotBuilder
      const adSlot = new AdSlotBuilder()
        .setCodeId(config.getAdId())
        .setAcceptSize(375, 0) // 设置广告宽度，高度自适应
        .setAdCount(1) // 一次加载1个广告
        .build();

      // 获取广告创建器并加载广告
      const adCreator = CSJAdSdk.getAdCreator();
      adCreator.loadExpressFeedAd(adSlot, expressLoadAdListener);
    });
  }

  /**
   * 解析横幅渲染计划（穿山甲暂不支持横幅）
   */
  planBanner(config: AdConfig, realAdId: string, width: number, height: number): BannerRenderPlan | null {
    return null;
  }

  /**
   * 加载原生自渲染广告（CSJ registerViewForInteraction 模式）
   */
  async loadNativeAd(config: AdConfig): Promise<IAd<ESObject>> {
    return new Promise((resolve, reject) => {
      const adSlot = new AdSlotBuilder()
        .setCodeId(config.getAdId())
        .setAdCount(1)
        .build();
      const adCreator = CSJAdSdk.getAdCreator();
      const loadListener = new CsjNativeAdLoadHandler(
        (nativeAd: object) => {
          const material = this.extractMaterial(nativeAd);
          const entity = new NativeAdEntity(nativeAd, material);
          entity.setAdConfig(config);
          resolve(entity);
        },
        (code: number, message: string) => {
          reject(new AdError(code, message));
        }
      );
      adCreator.loadNativeAd(adSlot, loadListener as ESObject);
    });
  }

  private extractMaterial(ad: object): NativeAdMaterial {
    const csj = ad as CSJNativeMaterialSource;
    const title: string = typeof csj.getTitle === 'function' ? csj.getTitle() : '';
    const desc: string = typeof csj.getDescription === 'function' ? csj.getDescription() : '';
    const iconUrl: string = typeof csj.getIcon === 'function' ? csj.getIcon() : '';
    const imageUrls: string[] = typeof csj.getImageList === 'function' ? csj.getImageList() : [];
    const videoUrl: string = typeof csj.getVideoUrl === 'function' ? csj.getVideoUrl() : '';
    const adLogoUrl: string = typeof csj.getAdLogo === 'function' ? csj.getAdLogo() : '';
    const actionText: string = typeof csj.getButtonText === 'function' ? csj.getButtonText() : '';
    return {
      title, desc, iconUrl, imageUrls, videoUrl,
      pattern: 'single', adLogoUrl, actionText
    };
  }
}

/** CSJ 原生广告素材字段（按需调用） */
interface CSJNativeMaterialSource {
  getTitle?: () => string;
  getDescription?: () => string;
  getIcon?: () => string;
  getImageList?: () => string[];
  getVideoUrl?: () => string;
  getAdLogo?: () => string;
  getButtonText?: () => string;
}

/** CSJ 原生广告加载监听处理器 */
class CsjNativeAdLoadHandler {
  private readonly loaded: (nativeAd: object) => void;
  private readonly failed: (code: number, message: string) => void;

  constructor(loaded: (nativeAd: object) => void, failed: (code: number, message: string) => void) {
    this.loaded = loaded;
    this.failed = failed;
  }

  onAdLoaded(nativeAd: object): void {
    this.loaded(nativeAd);
  }

  onError(code: number, message: string): void {
    this.failed(code, message);
  }
}

/**
 * 穿山甲独立型广告实现
 */
class CsjIndependentAd implements IndependentAd {
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
    LogManager.warn('CsjAdPlatform',
      `【广告加载】平台=穿山甲, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);

    if (this.adType === 'splash') {
      await this.waitForSdkReady();
    }

    const loaders = CsjAdLoaders.getInstance();
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
      LogManager.error('CsjAdPlatform',
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

    while (!CSJAdSdk.isSdkReady() && waitTime < MAX_WAIT_TIME) {
      await new Promise<void>(resolve => setTimeout(resolve, INTERVAL));
      waitTime += INTERVAL;
      LogManager.info('CsjAdPlatform', `Waiting for CSJ SDK ready, elapsed: ${waitTime}ms`);
    }

    if (!CSJAdSdk.isSdkReady()) {
      LogManager.warn('CsjAdPlatform', `CSJ SDK not ready after ${MAX_WAIT_TIME}ms, proceeding anyway`);
    }
  }

  show(): void {
    LogManager.warn('CsjAdPlatform',
      `【广告展示】平台=穿山甲, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
    if (!this.isValid() || !this.nativeHandle) {
      LogManager.error('CsjAdPlatform', `show: ad not ready, type=${this.adType}`);
      return;
    }
    this.showed = true;
    const loaders = CsjAdLoaders.getInstance();
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
    LogManager.warn('CsjAdPlatform',
      `【广告销毁】平台=穿山甲, 类型=${this.adType}, 槽位=${this.config.getAdSlot()}, 真实ID=${this.config.getAdId()}`);
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

  setVideoRewardListener(listener: OnVideoRewardListener | undefined): void {
    this.videoRewardListener = listener;
  }
}

/**
 * 穿山甲信息流广告实现
 */
class CsjFeedInfoAd extends IAd<CSJNativeExpressAd> {
  /**
   * 构造函数
   * @param ad CSJNativeExpressAd实例
   */
  constructor(ad: CSJNativeExpressAd) {
    super(ad);
    // 设置视频监听
    this.setVideoListener(ad);
  }

  /**
   * 获取广告超时时长（毫秒）
   */
  public timeout(): number {
    return 30000; // 30秒超时
  }

  /**
   * 获取广告的View控制器
   */
  public view(): NodeController | undefined {
    return this.ad.getAdComponent();
  }

  /**
   * 绑定广告事件
   */
  protected bind(): void {
    // 设置广告交互监听器
    this.ad.setExpressInteractionListener({
      /**
       * 广告点击事件
       */
      onAdClicked: (type: number) => {
        LogManager.info('CsjFeedAd', `信息流 - onAdClicked......type=${type}`);
        // 调用父类的onClick方法
        super.onClick();
      },

      /**
       * 广告展示事件
       */
      onAdShow: (type: number) => {
        LogManager.info('CsjFeedAd', `信息流 - onAdShow......type=${type}`);
        // 调用父类的onShow方法
        super.onShow();
      },

      /**
       * 模板渲染失败
       */
      onRenderFail: (code: number, msg: string) => {
        LogManager.error('CsjFeedAd', `信息流 - onRenderFail...code=${code}, msg=${msg}`);
      },

      /**
       * 模板渲染成功
       */
      onRenderSuccess: (width: number, height: number) => {
        LogManager.info('CsjFeedAd', `信息流 - onRenderSuccess......width=${width},height=${height}`);
        // 调用父类的onRender方法
        super.onRender();
      }
    });

    // 设置dislike回调
    this.bindDislikeCallback();
  }

  /**
   * 渲染广告
   */
  public render(): void {
    LogManager.info('CsjFeedAd', '信息流 - render......');
    try {
      this.ad.render(Ohos.getUIContext());
    } catch (error) {
      LogManager.error('CsjFeedAd', `信息流渲染失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 销毁广告
   */
  public destroy(): void {
    LogManager.info('CsjFeedAd', '信息流 - destroy......');
    try {
      this.ad.destroy();
    } catch (error) {
      LogManager.error('CsjFeedAd', `信息流销毁失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 绑定dislike回调
   */
  private bindDislikeCallback(): void {
    this.ad.setDislikeCallback({
      /**
       * dislike面板展示
       */
      onShow: () => {
        LogManager.info('CsjFeedAd', `信息流 - dislike......show`);
      },

      /**
       * 用户选择dislike选项
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        LogManager.info('CsjFeedAd',
          `信息流 - dislike......onSelected position=${position}, value=${value}, enforceRemove=${enforceRemove}`);
        // 调用父类的onClose方法
        super.onClose();
      },

      /**
       * 点击取消dislike
       */
      onCancel: () => {
        LogManager.info('CsjFeedAd', `信息流 - dislike......onCancel`);
      }
    });
  }

  /**
   * 设置视频监听
   * @param ad CSJNativeExpressAd实例
   */
  private setVideoListener(ad: CSJNativeExpressAd): void {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
      ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
      ad.setVideoAdListener({
        /**
         * 视频加载成功
         */
        onVideoLoad: () => {
          LogManager.info("CsjFeedAd", `信息流 - onVideoLoad......`);
        },

        /**
         * 视频加载失败
         */
        onVideoError: (errorCode: number, errorMsg: string) => {
          LogManager.error("CsjFeedAd", `信息流 - onVideoError......errorCode=${errorCode}, errorMsg=${errorMsg}`);
        },

        /**
         * 视频开始播放
         */
        onVideoAdStartPlay: () => {
          LogManager.info("CsjFeedAd", `信息流 - onVideoAdStartPlay......`);
        },

        /**
         * 视频暂停
         */
        onVideoAdPaused: () => {
          LogManager.info("CsjFeedAd", `信息流 - onVideoAdPaused......`);
        },

        /**
         * 视频继续播放
         */
        onVideoAdContinuePlay: () => {
          LogManager.info("CsjFeedAd", `信息流 - onVideoAdContinuePlay......`);
        },

        /**
         * 视频播放进度
         */
        onProgressUpdate: (current: number, duration: number) => {
          // 可以在这里处理视频播放进度
        },

        /**
         * 视频播放完成
         */
        onVideoAdComplete: () => {
          LogManager.info("CsjFeedAd", `信息流 - onVideoAdComplete......`);
        },

        /**
         * 点击重播
         */
        onClickReplay: () => {
          LogManager.info("CsjFeedAd", `信息流 - onClickReplay......`);
        }
      });
    }
  }
}
