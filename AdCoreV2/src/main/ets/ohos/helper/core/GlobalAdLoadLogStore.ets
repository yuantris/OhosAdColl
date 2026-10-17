import { AdType } from '../../model/AdType';
import { PlatformType } from '../../model/PlatformType';
import { AdAttemptRecord } from '../../model/AdAttemptRecord';

export class GlobalAdLogEntry {
  readonly adType: AdType;
  readonly adSlot: string;
  readonly attemptRecords: AdAttemptRecord[];
  readonly totalDuration: number;
  readonly isSuccess: boolean;
  readonly timestamp: number;
  readonly availablePlatforms: PlatformType[];
  /** waterfall 轨迹可读串，供 debug 组件展示 */
  readonly diagnosticText: string;

  constructor(adType: AdType, adSlot: string, attemptRecords: AdAttemptRecord[],
    totalDuration: number, isSuccess: boolean, availablePlatforms: PlatformType[],
    diagnosticText: string = '') {
    this.adType = adType;
    this.adSlot = adSlot;
    this.attemptRecords = attemptRecords;
    this.totalDuration = totalDuration;
    this.isSuccess = isSuccess;
    this.timestamp = Date.now();
    this.availablePlatforms = availablePlatforms;
    this.diagnosticText = diagnosticText;
  }
}

export class GlobalAdLoadLogStore {
  private static instance: GlobalAdLoadLogStore | null = null;
  private logs: GlobalAdLogEntry[] = [];
  private readonly MAX_LOGS = 50;

  private constructor() {
  }

  static getInstance(): GlobalAdLoadLogStore {
    if (!GlobalAdLoadLogStore.instance) {
      GlobalAdLoadLogStore.instance = new GlobalAdLoadLogStore();
    }
    return GlobalAdLoadLogStore.instance;
  }

  addLog(adType: AdType, adSlot: string, attemptRecords: AdAttemptRecord[],
    totalDuration: number, isSuccess: boolean, availablePlatforms: PlatformType[],
    diagnosticText: string = ''): void {
    const entry = new GlobalAdLogEntry(adType, adSlot, attemptRecords, totalDuration, isSuccess, availablePlatforms, diagnosticText);
    this.logs.unshift(entry);
    if (this.logs.length > this.MAX_LOGS) {
      this.logs.pop();
    }
  }

  getLogs(): GlobalAdLogEntry[] {
    return this.logs;
  }

  getLogsByType(adType: AdType): GlobalAdLogEntry[] {
    return this.logs.filter((log: GlobalAdLogEntry) => log.adType === adType);
  }

  clearLogs(): void {
    this.logs = [];
  }
}
