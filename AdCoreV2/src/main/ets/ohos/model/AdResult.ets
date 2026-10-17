import { PlatformType } from './PlatformType';
import { AdAttemptRecord, AdAttemptResult } from './AdAttemptRecord';
import { AdDiagnosticInfo } from './AdDiagnosticInfo';

export class AdResult<T> {
  readonly ad: T | null;
  readonly attemptRecords: AdAttemptRecord[];
  readonly successPlatform: PlatformType | null;
  readonly totalDuration: number;
  readonly diagnosticInfo: AdDiagnosticInfo | null;

  constructor(ad: T | null, attemptRecords: AdAttemptRecord[],
    successPlatform: PlatformType | null, totalDuration: number, diagnosticInfo: AdDiagnosticInfo | null = null) {
    this.ad = ad;
    this.attemptRecords = attemptRecords;
    this.successPlatform = successPlatform;
    this.totalDuration = totalDuration;
    this.diagnosticInfo = diagnosticInfo;
  }

  get isSuccess(): boolean {
    return this.ad !== null;
  }

  toDiagnosticInfo(adSlot: string): AdDiagnosticInfo {
    if (this.diagnosticInfo) {
      return this.diagnosticInfo;
    }
    const platformPriority: PlatformType[] = this.attemptRecords.map((record) => record.platformType);
    const finalResult = this.isSuccess ? 'SUCCESS' : 'FAILED';
    return new AdDiagnosticInfo(adSlot, platformPriority, this.attemptRecords, finalResult);
  }
}
