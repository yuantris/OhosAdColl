import { BaseAdManager } from './BaseAdManager';
import { IAd } from '../impl/IAd';
import { AdConfig } from '../../model/AdConfig';
import { IAdPlatform } from '../impl/IAdPlatform';
import { LogManager } from '../logger/LogManager';
import { IndependentAd } from '../impl/IndependentAd';
import { OnAdListener } from '../../interface/OnAdListener';
import { ADHelper } from '../core/ADHelper';

export class InterstitialAdManager extends BaseAdManager<IAd<ESObject>> {
  /**
   * 日志标签
   */
  protected static readonly TAG = 'InterstitialAdManager';
  
  /**
   * 当前独立型插屏广告实例
   */
  private currentAd: IndependentAd | null = null;
  
  /**
   * 构造函数
   */
  constructor(platform: IAdPlatform) {
    super(platform);
  }
  
  /**
   * 加载插屏广告（兼容旧接口，已废弃：插屏请使用 loadIndependentAd）
   */
  public async loadAd(config: AdConfig, retryCount: number = 0): Promise<IAd<ESObject>> {
    throw new Error('InterstitialAdManager.loadAd is unsupported, use loadIndependentAd instead');
  }
  
  /**
   * 使用独立型广告加载插屏广告
   * @param autoShow 默认 true（兼容旧行为）；false 时仅加载，需显式 showIndependentAd
   */
  public async loadIndependentAd(config: AdConfig, listener?: OnAdListener, retryCount: number = 0,
    autoShow: boolean = true): Promise<IndependentAd | null> {
    if (this.currentAd) {
      this.currentAd.destroy();
      this.currentAd = null;
    }

    this.currentAd = this.platform.createInterstitialAd(config);

    if (listener) {
      this.currentAd.setAdListener?.(listener);
    }

    await this.currentAd.load();

    if (!this.currentAd.isValid()) {
      LogManager.error(InterstitialAdManager.TAG, `loadIndependentAd[${config.getAdSlot()}|${config.getAdId()}]: ad is invalid after loading`);
      this.currentAd.destroy();
      this.currentAd = null;
      return null;
    }

    if (autoShow) {
      this.currentAd.show();
    }

    return this.currentAd;
  }
  
  /**
   * 展示插屏广告（兼容旧接口）
   */
  public showAd(ad: IAd<ESObject>, callback?: (success: boolean) => void): void {
    LogManager.info(InterstitialAdManager.TAG, `showAd: ${ad.getLinkAdId()}`);
    
    try {
      // 调用广告实例的render方法展示广告
      ad.render();
      callback?.(true);
    } catch (error) {
      LogManager.error(InterstitialAdManager.TAG, `showAd: error = ${error}`);
      callback?.(false);
    }
  }
  
  /**
   * 展示独立型插屏广告
   */
  public showIndependentAd(callback?: (success: boolean) => void): void {
    LogManager.info(InterstitialAdManager.TAG, 'showIndependentAd');

    try {
      if (!this.currentAd || !this.currentAd.isReady()) {
        LogManager.error(InterstitialAdManager.TAG, 'showIndependentAd: ad is not ready');
        callback?.(false);
        return;
      }

      this.currentAd.show();
      callback?.(true);
    } catch (error) {
      LogManager.error(InterstitialAdManager.TAG, `showIndependentAd: error = ${error}`);
      callback?.(false);
    }
  }
  
  /**
   * 销毁当前插屏广告
   */
  public destroyAd(): void {
    if (this.currentAd) {
      this.currentAd.destroy();
      this.currentAd = null;
    }
  }
  
  /**
   * 获取当前插屏广告实例
   */
  public getCurrentAd(): IndependentAd | null {
    return this.currentAd;
  }

  dispose(): void {
    this.destroyAd();
    super.dispose();
  }
}
