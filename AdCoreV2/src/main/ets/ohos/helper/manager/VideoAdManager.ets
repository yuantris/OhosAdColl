import { BaseAdManager } from './BaseAdManager';
import { IAd } from '../impl/IAd';
import { AdConfig } from '../../model/AdConfig';
import { IAdPlatform } from '../impl/IAdPlatform';
import { IndependentAd } from '../impl/IndependentAd';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { ErrCode } from '../const/ErrCode';
import { LogManager } from '../logger/LogManager';

export class VideoAdManager extends BaseAdManager<IAd<ESObject>> {
  protected static readonly TAG = 'VideoAdManager';
  private currentAd: IndependentAd | null = null;
  private rewardListener: OnVideoRewardListener | undefined;

  constructor(platform: IAdPlatform) {
    super(platform);
  }

  public async loadAd(config: AdConfig, retryCount: number = 0): Promise<IAd<ESObject>> {
    throw new Error('VideoAdManager.loadAd is unsupported, use loadIndependentAd instead');
  }

  public async loadIndependentAd(config: AdConfig, rewardListener?: OnVideoRewardListener,
    retryCount: number = 0, autoShow: boolean = true): Promise<IndependentAd | null> {
    LogManager.info(VideoAdManager.TAG, `loadIndependentAd: ${config.getAdId()}, retryCount: ${retryCount}`);

    if (this.currentAd) {
      this.currentAd.destroy();
      this.currentAd = null;
      this.rewardListener = undefined;
    }

    this.currentAd = this.platform.createVideoAd(config);
    this.rewardListener = rewardListener;

    if (rewardListener) {
      this.currentAd.setVideoRewardListener?.(rewardListener);
    }

    await this.currentAd.load();

    if (!this.currentAd.isValid()) {
      LogManager.error(VideoAdManager.TAG, `loadIndependentAd[${config.getAdSlot()}|${config.getAdId()}]: ad is invalid after loading`);
      this.currentAd.destroy();
      this.currentAd = null;
      this.rewardListener = undefined;
      return null;
    }

    LogManager.warn(VideoAdManager.TAG,
      `【广告加载成功】类型=video, 槽位=${config.getAdSlot()}, 真实ID=${config.getAdId()}`);

    if (autoShow) {
      this.currentAd.show();
    }

    return this.currentAd;
  }

  public showAd(ad: IAd<ESObject>, callback?: (success: boolean) => void): void {
    LogManager.info(VideoAdManager.TAG, `showAd: ${ad.getLinkAdId()}`);

    try {
      ad.render();
      callback?.(true);
    } catch (error) {
      LogManager.error(VideoAdManager.TAG, `showAd: error = ${error}`);
      callback?.(false);
    }
  }

  public showIndependentAd(callback?: (success: boolean) => void): void {
    LogManager.info(VideoAdManager.TAG, `showIndependentAd`);

    try {
      if (!this.currentAd || !this.currentAd.isReady()) {
        LogManager.error(VideoAdManager.TAG, `showIndependentAd: ad is not ready`);
        callback?.(false);
        return;
      }

      this.currentAd.show();
      callback?.(true);
    } catch (error) {
      LogManager.error(VideoAdManager.TAG, `showIndependentAd: error = ${error}`);
      callback?.(false);
    }
  }

  public destroyAd(): void {
    if (this.currentAd) {
      this.currentAd.destroy();
      this.currentAd = null;
    }
    this.rewardListener = undefined;
  }

  public getCurrentAd(): IndependentAd | null {
    return this.currentAd;
  }

  dispose(): void {
    this.destroyAd();
    super.dispose();
  }
}
