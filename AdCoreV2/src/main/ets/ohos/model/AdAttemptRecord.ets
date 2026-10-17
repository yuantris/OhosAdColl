import { PlatformType } from './PlatformType';

export enum AdAttemptResult {
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  SKIPPED = 'SKIPPED'
}

export enum RetryType {
  NONE = 'NONE',
  SELF_RETRY = 'SELF_RETRY',
  CHANNEL_RETRY = 'CHANNEL_RETRY'
}

export class AdAttemptRecord {
  readonly platformType: PlatformType;
  readonly attemptIndex: number;
  readonly result: AdAttemptResult;
  readonly errorCode: number;
  readonly errorMessage: string;
  readonly duration: number;
  readonly adId: string;
  readonly retryType: RetryType;

  constructor(platformType: PlatformType, attemptIndex: number, result: AdAttemptResult,
    errorCode: number, errorMessage: string, duration: number, adId: string = '',
    retryType: RetryType = RetryType.NONE) {
    this.platformType = platformType;
    this.attemptIndex = attemptIndex;
    this.result = result;
    this.errorCode = errorCode;
    this.errorMessage = errorMessage;
    this.duration = duration;
    this.adId = adId;
    this.retryType = retryType;
  }
}
