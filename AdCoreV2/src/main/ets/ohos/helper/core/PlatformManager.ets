import { getPlatformName, PlatformType } from '../../model/PlatformType';
import { IAdPlatform } from '../impl/IAdPlatform';
import { AdPlatformFactory } from './AdPlatformFactory';
import { SplashAdManager } from '../manager/SplashAdManager';
import { VideoAdManager } from '../manager/VideoAdManager';
import { InterstitialAdManager } from '../manager/InterstitialAdManager';
import { FeedAdManager } from '../manager/FeedAdManager';
import { AdType } from '../../model/AdType';
import { AdSlotManager } from './AdSlotManager';
import { LogManager } from '../logger/LogManager';

export class PlatformManager {
  private static readonly TAG = 'PlatformManager';
  private availablePlatforms: Array<IAdPlatform> = [];
  private platformMap: Map<PlatformType, IAdPlatform> = new Map<PlatformType, IAdPlatform>();
  private currentPlatform: IAdPlatform | null = null;
  private platformAvailability: Map<PlatformType, Map<string, boolean>> = new Map<PlatformType, Map<string, boolean>>();
  private platformFailureCount: Map<PlatformType, Map<string, number>> = new Map<PlatformType, Map<string, number>>();
  private platformFailureTime: Map<PlatformType, Map<string, number>> = new Map<PlatformType, Map<string, number>>();
  static readonly FAILURE_THRESHOLD = 3;
  static readonly HEALTH_CHECK_INTERVAL = 60000;
  private splashAdManager: SplashAdManager | null = null;
  private videoAdManager: VideoAdManager | null = null;
  private interstitialAdManager: InterstitialAdManager | null = null;
  private feedAdManager: FeedAdManager | null = null;
  private adSlotManager: AdSlotManager = AdSlotManager.getInstance();

  init(platformConfigs: Map<PlatformType, ESObject>, availAd: PlatformType[]): void {
    this.availablePlatforms = [];
    this.platformMap.clear();
    this.platformAvailability.clear();
    this.platformFailureCount.clear();
    this.platformFailureTime.clear();

    Array.from(platformConfigs.keys())
      .filter((key: PlatformType) => availAd.includes(key))
      .forEach((type: PlatformType) => {
        const config: ESObject | undefined = platformConfigs.get(type)
        const platform = AdPlatformFactory.createPlatform(type);
        platform.init(config as ESObject);
        this.availablePlatforms.push(platform);
        this.platformMap.set(type, platform);
        this.platformAvailability.set(type, new Map<string, boolean>());
        this.platformFailureCount.set(type, new Map<string, number>());
        this.platformFailureTime.set(type, new Map<string, number>());
      });

    if (this.availablePlatforms.length > 0) {
      this.currentPlatform = this.availablePlatforms[0];
      this.initAdManagers();
    }
  }

  switchToPlatformByType(platformType: PlatformType): void {
    const platform = this.platformMap.get(platformType);
    if (platform) {
      this.currentPlatform = platform;
      this.initAdManagers();
      LogManager.info(PlatformManager.TAG, `switchToPlatformByType: switched to ${getPlatformName(platformType)}`);
    } else {
      LogManager.error(PlatformManager.TAG, `switchToPlatformByType: platform ${getPlatformName(platformType)} not found`);
    }
  }

  getAvailablePlatformTypes(): PlatformType[] {
    return this.availablePlatforms.map((platform: IAdPlatform) => platform.getPlatformType());
  }

  getAvailablePlatforms(): IAdPlatform[] {
    return this.availablePlatforms;
  }

  getCurrentPlatformType(): PlatformType | null {
    return this.currentPlatform?.getPlatformType() || null;
  }

  getCurrentPlatformName(): string {
    return getPlatformName(this.currentPlatform?.getPlatformType());
  }

  getRealAdId(adSlot: string, platformType: PlatformType): string | null {
    return this.adSlotManager.getRealAdId(adSlot, platformType);
  }

  isPlatformAvailable(platformType: PlatformType, adType: AdType, adSlot: string): boolean {
    const platformAvailabilityMap = this.platformAvailability.get(platformType);
    if (!platformAvailabilityMap) {
      LogManager.info(PlatformManager.TAG,
        `isPlatformAvailable: ${getPlatformName(platformType)} for ${adType}:${adSlot} -> true (no availability map)`);
      return true;
    }
    const availabilityKey = `${adType}:${adSlot}`;
    const isExplicitlyUnavailable = platformAvailabilityMap.get(availabilityKey) === false;
    if (isExplicitlyUnavailable) {
      const platformTimeMap = this.platformFailureTime.get(platformType);
      if (platformTimeMap) {
        const lastFailureTime = platformTimeMap.get(availabilityKey) || 0;
        const now = Date.now();
        const elapsed = now - lastFailureTime;
        if (elapsed >= PlatformManager.HEALTH_CHECK_INTERVAL) {
          platformAvailabilityMap.delete(availabilityKey);
          LogManager.info(PlatformManager.TAG,
            `Platform ${getPlatformName(platformType)} auto recovered for ${adType}:${adSlot}`);
          return true;
        }
        LogManager.info(PlatformManager.TAG,
          `isPlatformAvailable: ${getPlatformName(platformType)} for ${adType}:${adSlot} -> false (熔断中, elapsed=${elapsed}ms)`);
      }
      return false;
    }
    LogManager.info(PlatformManager.TAG,
      `isPlatformAvailable: ${getPlatformName(platformType)} for ${adType}:${adSlot} -> true`);
    return true;
  }

  recordPlatformFailure(platformType: PlatformType, adType: AdType, adSlot: string): void {
    let platformCountMap = this.platformFailureCount.get(platformType);
    if (!platformCountMap) {
      platformCountMap = new Map<string, number>();
      this.platformFailureCount.set(platformType, platformCountMap);
    }
    let platformTimeMap = this.platformFailureTime.get(platformType);
    if (!platformTimeMap) {
      platformTimeMap = new Map<string, number>();
      this.platformFailureTime.set(platformType, platformTimeMap);
    }
    const failureKey = `${adType}:${adSlot}`;
    const currentCount = platformCountMap.get(failureKey) || 0;
    const newCount = currentCount + 1;
    platformCountMap.set(failureKey, newCount);
    platformTimeMap.set(failureKey, Date.now());
    LogManager.info(PlatformManager.TAG,
      `recordPlatformFailure: ${getPlatformName(platformType)}, adType: ${adType}, adSlot: ${adSlot}, count: ${newCount}`);
    if (newCount >= PlatformManager.FAILURE_THRESHOLD) {
      this.setPlatformAvailability(platformType, adType, adSlot, false);
      LogManager.warn(PlatformManager.TAG,
        `Platform ${getPlatformName(platformType)} marked unavailable for ${adType}:${adSlot}`);
    }
  }

  setPlatformAvailability(platformType: PlatformType, adType: AdType, adSlot: string, available: boolean): void {
    let platformAvailabilityMap = this.platformAvailability.get(platformType);
    if (!platformAvailabilityMap) {
      platformAvailabilityMap = new Map<string, boolean>();
      this.platformAvailability.set(platformType, platformAvailabilityMap);
    }
    const availabilityKey = `${adType}:${adSlot}`;
    platformAvailabilityMap.set(availabilityKey, available);
    LogManager.info(PlatformManager.TAG,
      `setPlatformAvailability: ${platformType} for ${adType}:${adSlot} is ${available ? 'available' : 'unavailable'}`);
  }

  resetPlatformStatus(platformType: PlatformType, adType: AdType | null = null, adSlot: string | null = null): void {
    let platformCountMap = this.platformFailureCount.get(platformType);
    if (!platformCountMap) {
      platformCountMap = new Map<string, number>();
      this.platformFailureCount.set(platformType, platformCountMap);
    }
    let platformAvailabilityMap = this.platformAvailability.get(platformType);
    if (!platformAvailabilityMap) {
      platformAvailabilityMap = new Map<string, boolean>();
      this.platformAvailability.set(platformType, platformAvailabilityMap);
    }
    let platformTimeMap = this.platformFailureTime.get(platformType);
    if (!platformTimeMap) {
      platformTimeMap = new Map<string, number>();
      this.platformFailureTime.set(platformType, platformTimeMap);
    }
    if (adType === null || adSlot === null) {
      platformCountMap.clear();
      platformAvailabilityMap.clear();
      platformTimeMap.clear();
    } else {
      const resetKey = `${adType}:${adSlot}`;
      platformCountMap.delete(resetKey);
      platformAvailabilityMap.delete(resetKey);
      platformTimeMap.delete(resetKey);
    }
  }

  initAdManagers(): void {
    if (!this.currentPlatform) {
      LogManager.error(PlatformManager.TAG, 'initAdManagers: currentPlatform is null');
      return;
    }
    // 释放旧 Manager 的缓存与定时器，避免平台切换后僵尸缓存/定时器泄漏
    this.splashAdManager?.dispose();
    this.videoAdManager?.dispose();
    this.interstitialAdManager?.dispose();
    this.feedAdManager?.dispose();

    this.splashAdManager = new SplashAdManager(this.currentPlatform);
    this.videoAdManager = new VideoAdManager(this.currentPlatform);
    this.interstitialAdManager = new InterstitialAdManager(this.currentPlatform);
    this.feedAdManager = new FeedAdManager(this.currentPlatform);
  }

  getSplashAdManager(): SplashAdManager | null {
    return this.splashAdManager;
  }

  getVideoAdManager(): VideoAdManager | null {
    return this.videoAdManager;
  }

  getInterstitialAdManager(): InterstitialAdManager | null {
    return this.interstitialAdManager;
  }

  getFeedAdManager(): FeedAdManager | null {
    return this.feedAdManager;
  }

  getPlatformFailureTime(): Map<PlatformType, Map<string, number>> {
    return this.platformFailureTime;
  }
}
