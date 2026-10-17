import { BaseAdManager } from './BaseAdManager';
import { IAd } from '../impl/IAd';
import { AdConfig } from '../../model/AdConfig';
import { LogManager } from '../logger/LogManager';
import { IAdPlatform } from '../impl/IAdPlatform';

export class FeedAdManager extends BaseAdManager<IAd<ESObject>> {
  /**
   * 日志标签
   */
  protected static readonly TAG = 'FeedAdManager';

  /**
   * 构造函数
   */
  constructor(platform: IAdPlatform) {
    super(platform);
  }

  /**
   * 加载信息流广告
   */
  public async loadAd(config: AdConfig, retryCount: number = 0): Promise<IAd<ESObject>> {
    LogManager.info(FeedAdManager.TAG, `loadAd: ${config.getAdId()}, retryCount: ${retryCount}`);

    // 先从缓存获取（取出即消费）
    const cachedAd: IAd<ESObject> | undefined = await this.getFromCache(config);
    if (cachedAd) {
      LogManager.info(FeedAdManager.TAG, 'loadAd: from cache');
      return cachedAd;
    }

    try {
      // 从平台加载；组件路径即请求即展示，不回写缓存，避免与 View 双持有/僵尸条目
      const ad: IAd<ESObject> = await this.platform.loadFeedAd(config);
      ad.setAdConfig(config);
      ad.attach();
      return ad;
    } catch (error) {
      LogManager.error(FeedAdManager.TAG, `loadAd failed: ${error instanceof Error ? error.message : String(error)}`);

      // 调用父类的onLoadFail方法进行平台切换和重试
      const result: IAd<ESObject> | null = await this.onLoadFail(config, error instanceof Error ? error : new Error(String(error)), retryCount);
      if (result) {
        return result;
      }

      // 当前平台加载失败，抛出错误让上层ADHelper处理平台切换
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 预加载信息流广告进缓存（供后续 getFromCache 取出）
   */
  public async preloadAd(config: AdConfig): Promise<void> {
    try {
      const ad: IAd<ESObject> = await this.platform.loadFeedAd(config);
      ad.setAdConfig(config);
      ad.attach();
      await this.addToCache(ad);
    } catch (error) {
      LogManager.error(FeedAdManager.TAG, `preloadAd failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 展示信息流广告
   */
  public showAd(ad: IAd<ESObject>, callback?: (success: boolean) => void): void {
    LogManager.info(FeedAdManager.TAG, `showAd: ${ad.getLinkAdId()}`);

    try {
      ad.render();
      callback?.(true);
    } catch (error) {
      LogManager.error(FeedAdManager.TAG, `showAd: error = ${error}`);
      callback?.(false);
    }
  }
}
