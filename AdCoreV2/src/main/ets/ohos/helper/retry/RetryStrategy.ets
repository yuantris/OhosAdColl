import { PlatformType } from "../../model/PlatformType";
import { AdConstants } from "../const/AdConstants";

export enum RetryActionType {
  RETRY = 'RETRY',
  DEGRADE = 'DEGRADE',
  FAIL = 'FAIL'
}

export interface RetryAction {
  readonly type: RetryActionType;
  readonly maxRetry?: number;
}

export namespace RetryAction {
  export function retry(maxRetry: number = AdConstants.DEFAULT_MAX_RETRY): RetryAction {
    return { type: RetryActionType.RETRY, maxRetry };
  }

  export function degrade(): RetryAction {
    return { type: RetryActionType.DEGRADE };
  }

  export function fail(): RetryAction {
    return { type: RetryActionType.FAIL };
  }
}

export interface RetryContext {
  readonly platform: PlatformType;
  readonly errorCode: number;
  readonly errorMessage: string;
  readonly retryCount: number;
  readonly maxRetryCount: number;
  readonly adSlot: string;
}

export interface IRetryStrategy {
  determineAction(context: RetryContext): RetryAction;
}
