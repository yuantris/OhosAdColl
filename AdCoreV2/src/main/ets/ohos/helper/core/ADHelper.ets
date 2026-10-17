import { PlatformType, getPlatformName } from '../../model/PlatformType';
import { AdConfig } from '../../model/AdConfig';
import { IAd } from '../impl/IAd';
import { IndependentAd } from '../impl/IndependentAd';
import { PlatformConfig } from '../../model/PlatformConfig';
import { LogManager } from '../logger/LogManager';
import { OnAdListener } from '../../interface/OnAdListener';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { AdType } from '../../model/AdType';
import { AdIdStore } from './AdIdStore';
import { AdSwitchManager } from './AdSwitchManager';
import { SDKCore } from '../../application/SDKCore';
import { AdModeManager } from './AdModeManager';
import { ErrCode } from '../const/ErrCode';
import { requestOAID } from '../../utils/OAIDUtil';
import { PlatformManager } from './PlatformManager';
import { BannerRenderPlan } from '../impl/IAdPlatform';
import zyClient from '../network/OhosRcp';
import { DegradationStrategy } from './DegradationStrategy';
import { HealthChecker } from './HealthChecker';
import { AdResult } from '../../model/AdResult';
import { GlobalAdLoadLogStore } from './GlobalAdLoadLogStore';
import { VIPRepo } from '../../storage/VIPData';
import { init, onEventObject } from '@umeng/analytics';
import { Ohos } from '@zycore/common';
import { AdDebugFloatController } from './AdDebugFloatController';
import { TestLog } from '../../test/TestLogEnvironment';

export class ADHelper {
  private static readonly TAG = 'ADHelper';
  private static instance: ADHelper | null = null;
  private platformManager: PlatformManager = new PlatformManager();
  private degradationStrategy: DegradationStrategy = new DegradationStrategy(this.platformManager);
  private healthChecker: HealthChecker = new HealthChecker(this.platformManager);
  public isInitialized: boolean = false;

  private constructor() {
  }

  public static getInstance(): ADHelper {
    if (!ADHelper.instance) {
      ADHelper.instance = new ADHelper();
    }
    return ADHelper.instance;
  }

  public async init(): Promise<void> {
    if (this.isInitialized) {
      LogManager.info(ADHelper.TAG, 'SDK already initialized, skipping');
      return;
    }
    LogManager.warn(ADHelper.TAG, '【ZY】SDK 开始初始化');

    init();
    requestOAID(Ohos.getContext())

    try {
      if (AdSwitchManager.enableEasyConfig) {
        await SDKCore.requestEasyOFF();
      } else {
        await SDKCore.requestOFF();
      }
      await TestLog.checkUpdateAllSlotToTestAdId()
      let availAd: PlatformType[] = AdModeManager.getAvailableAdPlatforms(SDKCore.OFF)
      // 枚举数组禁止直接插值(toString输出裸数字, 空数组输出空白), 转为可读平台名并显式输出数量
      const availAdNames: string = availAd.length > 0
        ? availAd.map((p: PlatformType): string => getPlatformName(p)).join(', ')
        : '无(平台开关未开或全部被熔断)';
      // 可用平台是初始化的核心决策结果, 用 warn(黄色)突出
      LogManager.warn(ADHelper.TAG, `可用平台[${availAd.length}]: ${availAdNames}`)

      const platformConfigs = new Map<PlatformType, PlatformConfig>();
      platformConfigs.set(PlatformType.CSJ, PlatformConfig.builder()
        .setAppId(AdIdStore.CSJ_APPID)
        .setDebug(Ohos.debug())
        .build());
      platformConfigs.set(PlatformType.TENCENT, PlatformConfig.builder()
        .setAppId(AdIdStore.TX_APP_ID)
        .setDebug(Ohos.debug())
        .build());
      platformConfigs.set(PlatformType.HUAWEI, PlatformConfig.builder()
        .setAppId(AdIdStore.HW_APP_ID)
        .setDebug(Ohos.debug())
        .build());

      this.platformManager.init(platformConfigs as Map<PlatformType, ESObject>, availAd);
      this.healthChecker.start();

      this.isInitialized = true;
      LogManager.warn(ADHelper.TAG, 'SDK initialized successfully');

      // debug 环境自动弹出调试悬浮球
      if (Ohos.debug()) {
        AdDebugFloatController.getInstance().show();
      }

      // 预热信息流缓存（供组件命中即时展示）
      this.preloadCommonFeedAds();
    } catch (e) {
      LogManager.error(ADHelper.TAG, '请求广告开关出错', e)
    }
  }

  /**
   * 预热常用信息流槽位到缓存；组件后续 loadFeedAd 可命中缓存即时展示
   */
  public async preloadCommonFeedAds(): Promise<void> {
    const slots: string[] = ['info', 'info_left'];
    for (const slot of slots) {
      try {
        const config = AdConfig.builder()
          .setAdId(slot)
          .setAdType(AdType.FEED)
          .setPlatformPriority(this.platformManager.getAvailablePlatformTypes())
          .build();
        await this.preloadFeedAd(slot, config);
      } catch (e) {
        LogManager.warn(ADHelper.TAG, `preloadCommonFeedAds[${slot}] skipped: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }

  /**
   * 解析横幅渲染计划（含真实广告位 + 平台组件参数）
   */
  public resolveBannerPlan(config: AdConfig, realAdId: string, width: number, height: number): BannerRenderPlan | null {
    const currentType = this.platformManager.getCurrentPlatformType();
    const platforms = this.platformManager.getAvailablePlatforms();
    const ordered = currentType
      ? [...platforms.filter(p => p.getPlatformType() === currentType), ...platforms.filter(p => p.getPlatformType() !== currentType)]
      : platforms;
    for (const p of ordered) {
      const plan = p.planBanner(config, realAdId, width, height);
      if (plan) {
        return plan;
      }
    }
    return null;
  }

  /**
   * 启用证书锁定（防中间人）
   * @param pins 公钥 SHA256 BASE64 数组（支持多 pin 轮换）；为空则使用 AdIdStore.CERT_PINS
   * @param remoteValidation 'system' 系统校验（默认）| 'skip' 跳过（仅测试）
   * 注意：pin 失效会导致全部请求失败，务必配置至少一个备用 pin 或用 'system' 回退
   */
  public enableCertificatePinning(pins?: string[], remoteValidation: 'system' | 'skip' = 'system'): void {
    const effectivePins = pins && pins.length > 0 ? pins : AdIdStore.CERT_PINS;
    if (effectivePins.length === 0) {
      LogManager.warn(ADHelper.TAG, 'enableCertificatePinning: no pins provided, skip');
      return;
    }
    // 官方 rcp.CertificatePinning: kind='public-key', hashAlgorithm='SHA-256'
    // 多 pin：当前 RCP 版本单次仅支持一个 pin，取第一个；备用 pin 待 API 支持后轮换
    zyClient.setSecurityConfig({
      remoteValidation: remoteValidation,
      certificatePinning: {
        kind: 'public-key',
        publicKeyHash: effectivePins[0],
        hashAlgorithm: 'SHA-256'
      }
    });
    LogManager.warn(ADHelper.TAG,
      `Certificate pinning enabled, pins=${effectivePins.length}, remoteValidation=${remoteValidation}`);
  }

  public async loadSplashAd(listener?: OnAdListener, autoShow: boolean = true): Promise<AdResult<IndependentAd>> {
    if (!this.platformManager.getSplashAdManager()) {
      const errorMsg = `${ADHelper.TAG}.loadSplashAd: splashAdManager is not initialized`;
      listener?.onAdShowError?.(ErrCode.AD_CLOSE, errorMsg);
      return new AdResult<IndependentAd>(null, [], null, 0);
    }

    let config: AdConfig = AdConfig.builder()
      .setAdId("splash")
      .setAdType(AdType.SPLASH)
      .setPlatformPriority(this.platformManager.getAvailablePlatformTypes())
      .build()

    return this.degradationStrategy.executeWithDegradation(config, async (config, retryCount) => {
      const ad = await this.platformManager.getSplashAdManager()!.loadIndependentAd(config, listener, retryCount, autoShow);
      if (!ad) {
        throw new Error(`Failed to load splash ad`);
      }
      return ad;
    }, listener).then((result: AdResult<IndependentAd>) => {
      this.reportLog(AdType.SPLASH, 'splash', result);
      return result;
    });
  }

  /**
   * 展示已加载的开屏广告（loadSplashAd(..., autoShow=false) 后调用）
   */
  public showSplashAd(): void {
    this.platformManager.getSplashAdManager()?.showIndependentAd();
  }

  public async loadVideoAd(adId: string, rewardListener?: OnVideoRewardListener, autoShow: boolean = true): Promise<AdResult<IndependentAd>> {
    if (VIPRepo.instance.props.vip) {
      LogManager.info(ADHelper.TAG, 'VIP user, skip reward video');
      const emptyResult = new AdResult<IndependentAd>(null, [], null, 0);
      this.reportLog(AdType.VIDEO, adId, emptyResult);
      return emptyResult;
    }

    if (!this.platformManager.getVideoAdManager()) {
      const errorMsg = `${ADHelper.TAG}.loadVideoAd: videoAdManager is not initialized`;
      rewardListener?.onVideoError?.(ErrCode.AD_CLOSE, 'ad switch closed');
      return new AdResult<IndependentAd>(null, [], null, 0);
    }

    let config = AdConfig.builder()
      .setAdId(adId)
      .setAdType(AdType.VIDEO)
      .setPlatformPriority(this.platformManager.getAvailablePlatformTypes())
      .build()

    const silentListener: OnVideoRewardListener | undefined = rewardListener ? {
      onVideoShow: () => rewardListener.onVideoShow?.(),
      onVideoClick: () => rewardListener.onVideoClick?.(),
      onVideoComplete: () => rewardListener.onVideoComplete?.(),
      onVideoError: (code: number, msg: string) => {
        if (code === ErrCode.NO_FULL_VIDEO) {
          rewardListener.onVideoError?.(code, msg);
        }
      },
    } : undefined;

    const result = await this.degradationStrategy.executeWithDegradation(config, async (config, retryCount) => {
      const ad = await this.platformManager.getVideoAdManager()!.loadIndependentAd(config, silentListener, retryCount, autoShow);
      if (!ad) {
        throw new Error(`Failed to load video ad`);
      }
      return ad;
    });

    if (!result.isSuccess && !result.ad) {
      const lastRecord = result.attemptRecords[result.attemptRecords.length - 1];
      rewardListener?.onVideoError?.(lastRecord?.errorCode || ErrCode.AD_LOAD_FAILED, lastRecord?.errorMessage || 'All platforms failed');
    }

    this.reportLog(AdType.VIDEO, adId, result);
    return result;
  }

  /**
   * 展示已加载的激励视频（loadVideoAd(..., autoShow=false) 后调用）
   */
  public showVideoAd(): void {
    this.platformManager.getVideoAdManager()?.showIndependentAd();
  }

  public async loadInterstitialAd(adId?: string, listener?: OnAdListener, autoShow: boolean = true): Promise<AdResult<IndependentAd>> {
    if (VIPRepo.instance.props.vip) {
      LogManager.info(ADHelper.TAG, 'VIP user, skip interstitial');
      const emptyResult = new AdResult<IndependentAd>(null, [], null, 0);
      this.reportLog(AdType.INTERSTITIAL, adId ?? 'lscr', emptyResult);
      return emptyResult;
    }

    if (!this.platformManager.getInterstitialAdManager()) {
      const errorMsg = `${ADHelper.TAG}.loadInterstitialAd: interstitialAdManager is not initialized`;
      listener?.onAdShowError?.(ErrCode.AD_CLOSE, errorMsg);
      return new AdResult<IndependentAd>(null, [], null, 0);
    }

    let config = AdConfig.builder()
      .setAdId((adId === undefined) ? 'lscr' : adId)
      .setAdType(AdType.INTERSTITIAL)
      .setPlatformPriority(this.platformManager.getAvailablePlatformTypes())
      .build();

    return this.degradationStrategy.executeWithDegradation(config, async (config, retryCount) => {
      const ad = await this.platformManager.getInterstitialAdManager()!.loadIndependentAd(config, listener, retryCount, autoShow);
      if (!ad) {
        throw new Error(`Failed to load interstitial ad`);
      }
      return ad;
    }, listener).then((result: AdResult<IndependentAd>) => {
      this.reportLog(AdType.INTERSTITIAL, config.getAdSlot(), result);
      return result;
    });
  }

  /**
   * 展示已加载的插屏（loadInterstitialAd(..., autoShow=false) 后调用）
   */
  public showInterstitialAd(): void {
    this.platformManager.getInterstitialAdManager()?.showIndependentAd();
  }

  public async loadFeedAd(config: AdConfig): Promise<AdResult<IAd<ESObject>>> {
    if (!this.platformManager.getFeedAdManager()) {
      const errorMsg = `${ADHelper.TAG}.loadFeedAd: feedAdManager is not initialized`;
      LogManager.error(ADHelper.TAG, errorMsg);
      return new AdResult<IAd<ESObject>>(null, [], null, 0);
    }

    return this.degradationStrategy.executeWithDegradation(config, async (config, retryCount) => {
      return await this.platformManager.getFeedAdManager()!.loadAd(config, retryCount);
    }).then((result: AdResult<IAd<ESObject>>) => {
      this.reportLog(AdType.FEED, config.getAdSlot(), result);
      return result;
    });
  }

  /**
   * 加载原生自渲染广告（走统一降级栈）
   * 不支持自渲染的平台（如华为）抛 NotSupported，降级到下一平台
   */
  public async loadNativeAd(config: AdConfig): Promise<AdResult<IAd<ESObject>>> {
    return this.degradationStrategy.executeWithDegradation(config, async (cfg, retryCount) => {
      const currentType = this.platformManager.getCurrentPlatformType();
      const platform = this.platformManager.getAvailablePlatforms().find(
        (p) => p.getPlatformType() === currentType
      );
      if (!platform) {
        throw new Error('No available platform for native ad');
      }
      return await platform.loadNativeAd(cfg);
    }).then((result: AdResult<IAd<ESObject>>) => {
      this.reportLog(AdType.NATIVE, config.getAdSlot(), result);
      return result;
    });
  }

  public async preloadFeedAd(adId: string, config: AdConfig): Promise<void> {
    const feedManager = this.platformManager.getFeedAdManager();
    if (!feedManager) {
      return;
    }
    await feedManager.preloadAd(config);
  }

  public destroySplashAd(): void {
    this.platformManager.getSplashAdManager()?.destroyAd();
  }

  public destroyVideoAd(): void {
    this.platformManager.getVideoAdManager()?.destroyAd();
  }

  public destroyInterstitialAd(): void {
    this.platformManager.getInterstitialAdManager()?.destroyAd();
  }

  public getAvailablePlatformTypes(): PlatformType[] {
    return this.platformManager.getAvailablePlatformTypes();
  }

  public getCurrentPlatformType(): PlatformType | null {
    return this.platformManager.getCurrentPlatformType();
  }

  public getCurrentPlatformName(): string {
    return this.platformManager.getCurrentPlatformName();
  }

  public switchToPlatformByType(platformType: PlatformType): void {
    this.platformManager.switchToPlatformByType(platformType);
  }

  private reportLog<T>(adType: AdType, adSlot: string, result: AdResult<T>): void {
    const diagnosticText = result.toDiagnosticInfo(adSlot).toDisplayString();
    GlobalAdLoadLogStore.getInstance().addLog(
      adType, adSlot, result.attemptRecords,
      result.totalDuration, result.isSuccess,
      this.platformManager.getAvailablePlatformTypes(),
      diagnosticText
    );
    // 埋点：加载失败上报（填充率/收益归因）
    if (!result.isSuccess && result.attemptRecords.length > 0) {
      const last = result.attemptRecords[result.attemptRecords.length - 1];
      try {
        onEventObject('ad_load_fail', {
          adType: adType as number,
          adSlot: adSlot,
          platform: last.platformType as number,
          errorCode: last.errorCode,
          attempts: result.attemptRecords.length
        });
      } catch (e) {
        // 埋点失败不影响主流程
      }
    }
  }
}
