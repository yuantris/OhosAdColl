import { PlatformType } from '../../model/PlatformType';
import { AdConstants } from '../const/AdConstants';
import { RetryContext, RetryAction, RetryActionType, IRetryStrategy } from './RetryStrategy';
import { ErrCode } from '../const/ErrCode';

export class PlatformRetryStrategy implements IRetryStrategy {
  private readonly platform: PlatformType;
  private readonly retryRules: Map<number, number> = new Map();
  private readonly degradeCodes: Set<number> = new Set();
  private readonly failCodes: Set<number> = new Set();
  private readonly defaultMaxRetry: number = AdConstants.DEFAULT_MAX_RETRY;

  constructor(platform: PlatformType) {
    this.platform = platform;
    this.initDefaultRules();
  }

  private initDefaultRules(): void {
    this.initFailCodes();
    switch (this.platform) {
      case PlatformType.CSJ:
        this.initCsjRules();
        break;
      case PlatformType.TENCENT:
        this.initTencentRules();
        break;
      case PlatformType.HUAWEI:
        this.initHuaweiRules();
        break;
    }
  }

  private initFailCodes(): void {
    this.failCodes.add(ErrCode.NO_FULL_VIDEO);
    // 平台不支持该广告类型：直接降级到下一平台，不重试
    this.degradeCodes.add(ErrCode.AD_NOT_SUPPORTED);
  }

  private initCsjRules(): void {
    [-2, -3, -4, -5, -6, 0, 1, 2, 3, 23, -10, -11, -12,
      601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 612
    ].forEach(code => this.retryRules.set(code, this.defaultMaxRetry));

    [40001, 40004, 40005, 40006, 40007, 40008, 40009, 40013, 40016, 40018, 40019,
      40020, 40021, 40022, 40024, 40026, 40029, 40034, 40042, 50001, 60007,
      98764, 98765, -8, -7, 101, 102, 103, 107, 108, 109, 113, 117, 118, 123,
      127, 128, 141, 611, 20001, 20002, 20003, 20004, 20005, 20006
    ].forEach(code => this.degradeCodes.add(code));
  }

  private initTencentRules(): void {
    [5004, 40001, 40002].forEach(code => this.degradeCodes.add(code));
  }

  private initHuaweiRules(): void {
    [21800003, 21800004].forEach(code => this.degradeCodes.add(code));
  }


  determineAction(context: RetryContext): RetryAction {
    if (context.platform !== this.platform) {
      return this.defaultAction(context);
    }

    if (this.failCodes.has(context.errorCode)) {
      return RetryAction.fail();
    }

    if (this.retryRules.has(context.errorCode)) {
      return this.handleRetry(context);
    }

    if (this.degradeCodes.has(context.errorCode)) {
      return RetryAction.degrade();
    }

    return this.defaultAction(context);
  }

  private handleRetry(context: RetryContext): RetryAction {
    const maxRetry = this.retryRules.get(context.errorCode) ?? this.defaultMaxRetry;
    return RetryAction.retry(maxRetry);
  }

  private defaultAction(context: RetryContext): RetryAction {
    if (context.retryCount >= context.maxRetryCount) {
      return RetryAction.degrade();
    }
    return RetryAction.retry(context.maxRetryCount);
  }
}
