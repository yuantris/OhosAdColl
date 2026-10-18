/** Public ad format identifiers. Keep vendor-specific identifiers out of this enum. */
export enum AdFormat {
  Splash = 'splash',
  Interstitial = 'interstitial',
  Rewarded = 'rewarded',
  Banner = 'banner',
  Native = 'native'
}

export enum AdSessionState {
  Created = 'created',
  Loading = 'loading',
  Ready = 'ready',
  Showing = 'showing',
  Completed = 'completed',
  Failed = 'failed',
  Cancelled = 'cancelled',
  Destroyed = 'destroyed'
}

export enum AdErrorCode {
  InvalidRequest = 'invalid_request',
  NoAdapter = 'no_adapter',
  LoadFailed = 'load_failed',
  Timeout = 'timeout',
  Cancelled = 'cancelled',
  InvalidState = 'invalid_state',
  ShowFailed = 'show_failed',
  Internal = 'internal'
}

export class AdError extends Error {
  readonly code: AdErrorCode;
  readonly adapterId: string;

  constructor(code: AdErrorCode, message: string, adapterId: string = '') {
    super(message);
    this.name = 'AdError';
    this.code = code;
    this.adapterId = adapterId;
  }
}

/** A snapshot of one logical ad request. Extras are copied on construction. */
export class AdRequest {
  readonly requestId: string;
  readonly format: AdFormat;
  readonly placementId: string;
  readonly timeoutMs: number;
  readonly extras: Map<string, string>;

  constructor(
    requestId: string,
    format: AdFormat,
    placementId: string,
    timeoutMs: number = 0,
    extras: Map<string, string> = new Map<string, string>()
  ) {
    this.requestId = requestId;
    this.format = format;
    this.placementId = placementId;
    this.timeoutMs = timeoutMs;
    this.extras = new Map<string, string>(extras);
  }
}

export interface AdHandleLifecycleListener {
  onCompleted(): void;
  onFailed(error: AdError): void;
}

export interface AdHandle {
  readonly id: string;
  readonly adapterId: string;
  readonly format: AdFormat;
  show(): Promise<void>;
  destroy(): void;
  setLifecycleListener?(listener: AdHandleLifecycleListener): void;
}

export class AdLoadResult {
  readonly success: boolean;
  readonly handle: AdHandle | null;
  readonly error: AdError | null;

  private constructor(success: boolean, handle: AdHandle | null, error: AdError | null) {
    this.success = success;
    this.handle = handle;
    this.error = error;
  }

  static loaded(handle: AdHandle): AdLoadResult {
    return new AdLoadResult(true, handle, null);
  }

  static failed(error: AdError): AdLoadResult {
    return new AdLoadResult(false, null, error);
  }
}
