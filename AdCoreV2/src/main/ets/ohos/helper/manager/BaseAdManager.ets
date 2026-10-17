import { IAd } from '../impl/IAd';
import { AdConfig } from '../../model/AdConfig';
import { IAdPlatform } from '../impl/IAdPlatform';
import { AdCache } from '../cache/AdCache';
import { ADHelper } from '../core/ADHelper';
import { LogManager } from '../logger/LogManager';

export abstract class BaseAdManager<T extends IAd<ESObject>> {
  /**
   * 日志标签
   */
  protected static readonly TAG: string = 'BaseAdManager';
  
  /**
   * 广告平台
   */
  protected platform: IAdPlatform;
  
  /**
   * 广告缓存
   */
  protected cache: AdCache<T>;
  
  /**
   * 构造函数
   */
  constructor(platform: IAdPlatform) {
    this.platform = platform;
    this.cache = new AdCache<T>();
    this.cache.startAutoClean();
  }
  
  /**
   * 加载广告
   */
  public abstract loadAd(config: AdConfig, retryCount?: number): Promise<T>;
  
  /**
   * 处理广告加载失败，返回null让上层ADHelper处理平台切换
   */
  protected async onLoadFail(config: AdConfig, error: Error, retryCount: number = 0): Promise<T | null> {
    // 直接返回null，由上层ADHelper处理平台切换和重试
    return null;
  }
  
  /**
   * 展示广告
   */
  public abstract showAd(ad: T, callback?: (success: boolean) => void): void;
  
  /**
   * 从缓存获取有效广告
   */
  protected async getFromCache(config: AdConfig): Promise<T | undefined> {
    return this.cache.getValidAd(config);
  }
  
  /**
   * 添加广告到缓存
   */
  protected async addToCache(ad: T): Promise<void> {
    await this.cache.addAd(ad);
  }
  
  /**
   * 清理过期广告
   */
  protected async clearExpiredAds(): Promise<void> {
    await this.cache.clearExpiredAds();
  }

  /**
   * 释放缓存并停止自动清理（平台切换重建 Manager 时调用）
   */
  dispose(): void {
    this.cache.stopAutoClean();
    this.cache.clearAllCache();
  }
}
