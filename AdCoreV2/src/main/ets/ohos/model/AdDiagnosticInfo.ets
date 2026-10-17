import { PlatformType } from './PlatformType';
import { AdAttemptRecord, AdAttemptResult } from './AdAttemptRecord';

export class AdDiagnosticInfo {
  readonly adSlot: string;
  readonly platformPriority: PlatformType[];
  readonly attemptHistory: AdAttemptRecord[];
  readonly finalResult: string;

  constructor(adSlot: string, platformPriority: PlatformType[],
    attemptHistory: AdAttemptRecord[], finalResult: string) {
    this.adSlot = adSlot;
    this.platformPriority = platformPriority;
    this.attemptHistory = attemptHistory;
    this.finalResult = finalResult;
  }

  toDisplayString(): string {
    const parts: string[] = [];
    this.attemptHistory.forEach((record) => {
      const platformName = this.getPlatformName(record.platformType);
      if (record.result === AdAttemptResult.SKIPPED) {
        parts.push(`${platformName}: 跳过(不可用)`);
      } else if (record.result === AdAttemptResult.FAILED) {
        parts.push(`${platformName}: 第${record.attemptIndex}次失败(错误码${record.errorCode})`);
      } else {
        parts.push(`${platformName}: 成功`);
      }
    });
    return parts.join(' → ');
  }

  private getPlatformName(platformType: PlatformType): string {
    switch (platformType) {
      case PlatformType.CSJ:
        return 'CSJ';
      case PlatformType.TENCENT:
        return 'TX';
      case PlatformType.HUAWEI:
        return 'HW';
      default:
        return 'UNKNOWN';
    }
  }
}
