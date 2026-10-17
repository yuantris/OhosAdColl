import { IAd } from '../impl/IAd';
import { AdConfig } from '../../model/AdConfig';
import { LogManager } from '../logger/LogManager';
import { CachedAdEntry } from './CachedAdEntry';

export class AdCache<T extends IAd<ESObject>> {
  private static readonly TAG = 'AdCache';
  private cacheMap: Map<string, Array<CachedAdEntry<T>>> = new Map();
  private cleanTimer: number | null = null;
  static readonly MAX_CACHE_COUNT = 5;
  static readonly CACHE_CLEAN_INTERVAL = 30000;

  addAd(ad: T): boolean {
    const adConfig = ad.getAdConfig();
    if (!adConfig) {
      LogManager.error(AdCache.TAG, 'addAd: adConfig is null');
      return false;
    }
    LogManager.warn(AdCache.TAG, 'addAd: adConfig is added');

    const adId = adConfig.getAdId();
    if (!this.cacheMap.has(adId)) {
      this.cacheMap.set(adId, []);
    }

    const entries = this.cacheMap.get(adId)!;
    entries.push(new CachedAdEntry(ad));

    if (entries.length > AdCache.MAX_CACHE_COUNT) {
      const removedEntry = entries.shift();
      if (removedEntry) {
        removedEntry.ad.destroy();
      }
    }

    LogManager.info(AdCache.TAG, `addAd: ${adId}, current cache size: ${entries.length}`);
    return true;
  }

  getValidAd(config: AdConfig): T | undefined {
    const adId = config.getAdId();
    const entries = this.cacheMap.get(adId);

    if (!entries || entries.length === 0) {
      return undefined;
    }

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.isValid) {
        // 取出即消费：从缓存移除，避免同一原生 ad 被多处持有 / destroy 后仍命中
        entries.splice(i, 1);
        if (entries.length === 0) {
          this.cacheMap.delete(adId);
        }
        return entry.ad;
      }
    }

    return undefined;
  }

  removeAd(ad: T): void {
    this.cacheMap.forEach((entries, adId) => {
      const remaining = entries.filter((entry) => entry.ad !== ad);
      if (remaining.length === 0) {
        this.cacheMap.delete(adId);
      } else if (remaining.length !== entries.length) {
        this.cacheMap.set(adId, remaining);
      }
    });
  }

  markDisplayExpired(ad: T): void {
    this.cacheMap.forEach((entries) => {
      entries.forEach((entry) => {
        if (entry.ad === ad) {
          entry.isDisplayExpired = true;
        }
      });
    });
  }

  clearExpiredAds(): void {
    let totalCleared = 0;

    this.cacheMap.forEach((entries, adId) => {
      const validEntries: CachedAdEntry<T>[] = [];

      entries.forEach((entry) => {
        if (entry.isCacheExpired) {
          entry.ad.destroy();
          totalCleared++;
        } else {
          validEntries.push(entry);
        }
      });

      if (validEntries.length > 0) {
        this.cacheMap.set(adId, validEntries);
      } else {
        this.cacheMap.delete(adId);
      }
    });

    if (totalCleared > 0) {
      LogManager.info(AdCache.TAG, `clearExpiredAds: cleared ${totalCleared} ads`);
    }
  }

  startAutoClean(): void {
    if (this.cleanTimer !== null) {
      clearInterval(this.cleanTimer);
    }
    this.cleanTimer = setInterval(() => {
      this.clearExpiredAds();
    }, AdCache.CACHE_CLEAN_INTERVAL);
  }

  stopAutoClean(): void {
    if (this.cleanTimer !== null) {
      clearInterval(this.cleanTimer);
      this.cleanTimer = null;
    }
  }

  clearCache(adId: string): void {
    const entries = this.cacheMap.get(adId);
    if (entries) {
      entries.forEach((entry) => entry.ad.destroy());
      this.cacheMap.delete(adId);
      LogManager.info(AdCache.TAG, `clearCache: ${adId}`);
    }
  }

  clearAllCache(): void {
    this.cacheMap.forEach((entries) => {
      entries.forEach((entry) => entry.ad.destroy());
    });
    this.cacheMap.clear();
    LogManager.info(AdCache.TAG, 'clearAllCache: cleared all ads');
  }

  getCacheSize(): number {
    let size = 0;
    this.cacheMap.forEach((entries) => {
      size += entries.length;
    });
    return size;
  }
}
