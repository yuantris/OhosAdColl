import { IAd } from '../impl/IAd';

export class CachedAdEntry<T extends IAd<ESObject>> {
  readonly ad: T;
  readonly cachedTime: number;
  isDisplayExpired: boolean = false;
  static readonly CACHE_TTL = 60000;

  constructor(ad: T) {
    this.ad = ad;
    this.cachedTime = Date.now();
  }

  get isCacheExpired(): boolean {
    return this.cachedTime + CachedAdEntry.CACHE_TTL < Date.now();
  }

  get isValid(): boolean {
    return !this.isDisplayExpired && !this.isCacheExpired;
  }
}
