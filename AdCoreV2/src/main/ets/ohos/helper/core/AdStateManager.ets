import { LogManager } from '../logger/LogManager';
import { AdType } from '../../model/AdType';
import { OnAdListener } from '../../interface/OnAdListener';
import { IAd } from '../impl/IAd';
import { ExclusiveNotification } from '../../utils/ExclusiveNotification';
import { AdUIDataGlobal } from '../../storage/AdUIDataGlobal';

export enum AdSlotStatus {
  QUEUED = 'queued',
  ACTIVE = 'active',
  EXPIRED = 'expired',
  DESTROYED = 'destroyed'
}

export interface AdSlotState {
  adId: string;
  adType: AdType;
  pageId: string;
  adInstance?: IAd<ESObject>;
  status: AdSlotStatus;
  listener?: OnAdListener;
  createTime: number;
  lastActiveTime: number;
}

export class AdStateManager {
  private static readonly TAG = 'AdStateManager';
  private static instance: AdStateManager | null = null;
  private adSlotStates: Map<string, AdSlotState> = new Map();
  public static readonly EVENT_AD_REFRESH = 'zyAdWarmRefresh';

  private constructor() {
  }

  public static getInstance(): AdStateManager {
    if (!AdStateManager.instance) {
      AdStateManager.instance = new AdStateManager();
    }
    return AdStateManager.instance;
  }

  public registerAdSlot(adId: string, adType: AdType, pageId: string): void {
    const key = `${adId}_${pageId}`;
    if (!this.adSlotStates.has(key)) {
      const state: AdSlotState = {
        adId,
        adType,
        pageId,
        status: AdSlotStatus.QUEUED,
        createTime: Date.now(),
        lastActiveTime: Date.now()
      };
      this.adSlotStates.set(key, state);
      LogManager.info(AdStateManager.TAG, `Registered ad slot: ${key}, adType: ${adType}`);
      AdUIDataGlobal.adSlotUpdated = Date.now();
    }
  }

  public updateAdSlot(adId: string, pageId: string, adInstance?: IAd<ESObject>, listener?: OnAdListener): void {
    const key = `${adId}_${pageId}`;
    const state = this.adSlotStates.get(key);
    if (state) {
      state.adInstance = adInstance;
      state.listener = listener;
      state.status = AdSlotStatus.ACTIVE;
      state.lastActiveTime = Date.now();
      LogManager.info(AdStateManager.TAG, `Updated ad slot: ${key}`);
    }
  }

  public unregisterAdSlot(adId: string, pageId: string): void {
    const key = `${adId}_${pageId}`;
    const state = this.adSlotStates.get(key);
    if (state) {
      state.status = AdSlotStatus.DESTROYED;
      state.lastActiveTime = Date.now();
      LogManager.info(AdStateManager.TAG, `Destroy ad slot: ${key}`);
    }
  }

  public markAdSlotExpired(adId: string, pageId: string): void {
    const key = `${adId}_${pageId}`;
    const state = this.adSlotStates.get(key);
    if (state) {
      state.status = AdSlotStatus.EXPIRED;
      LogManager.info(AdStateManager.TAG, `Marked ad slot as expired: ${key}`);
    }
  }

  public markAdSlotActive(adId: string, pageId: string): void {
    const key = `${adId}_${pageId}`;
    const state = this.adSlotStates.get(key);
    if (state) {
      state.status = AdSlotStatus.ACTIVE;
      LogManager.info(AdStateManager.TAG, `Marked ad slot as active: ${key}`);
    }
  }

  public getActiveAdSlots(): AdSlotState[] {
    const activeSlots: AdSlotState[] = [];
    for (const state of this.adSlotStates.values()) {
      if (state.status === AdSlotStatus.ACTIVE) {
        activeSlots.push(state);
      }
    }
    return activeSlots;
  }

  public getAllAdSlots(): AdSlotState[] {
    const allSlots: AdSlotState[] = [];
    for (const state of this.adSlotStates.values()) {
      allSlots.push(state);
    }
    return allSlots;
  }

  public refreshAds(): void {
    LogManager.info(AdStateManager.TAG, 'Refreshing all active ads...');

    ExclusiveNotification.getInstance<number>(AdStateManager.EVENT_AD_REFRESH).emit(Date.now())
    AdUIDataGlobal.adRefreshTimestamp = Date.now();
    AdUIDataGlobal.adEasySlotUpdated = Date.now();

    for (const state of this.adSlotStates.values()) {
      if (state.status === AdSlotStatus.ACTIVE) {
        LogManager.info(AdStateManager.TAG, `Refreshing ad slot: ${state.adId}_${state.pageId}`);
      }
    }
  }

  public getAdSlotState(adId: string, pageId: string): AdSlotState | undefined {
    const key = `${adId}_${pageId}`;
    return this.adSlotStates.get(key);
  }
}
