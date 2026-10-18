import { AdError, AdErrorCode, AdFormat, AdHandle, AdHandleLifecycleListener, AdSessionState } from './AdCoreTypes';

/** SDK-owned lifecycle wrapper around a vendor handle. */
export class AdManagedHandle implements AdHandle {
  readonly id: string;
  readonly adapterId: string;
  readonly format: AdFormat;
  private delegate: AdHandle;
  private currentState: AdSessionState = AdSessionState.Ready;
  private terminalError: AdError | null = null;
  private destroyed: boolean = false;

  constructor(delegate: AdHandle) {
    this.delegate = delegate;
    this.id = delegate.id;
    this.adapterId = delegate.adapterId;
    this.format = delegate.format;
    const listener: AdHandleLifecycleListener = {
      onCompleted: (): void => { this.complete(); },
      onFailed: (error: AdError): void => { this.fail(error); }
    };
    if (delegate.setLifecycleListener !== undefined) {
      delegate.setLifecycleListener(listener);
    }
  }

  get state(): AdSessionState { return this.currentState; }
  get error(): AdError | null { return this.terminalError; }

  async show(): Promise<void> {
    if (this.currentState !== AdSessionState.Ready) {
      throw new AdError(AdErrorCode.InvalidState, 'An ad can only be shown once after it is ready.', this.adapterId);
    }
    this.currentState = AdSessionState.Showing;
    try {
      await this.delegate.show();
    } catch (error) {
      this.currentState = AdSessionState.Failed;
      this.terminalError = new AdError(
        AdErrorCode.ShowFailed,
        error instanceof Error ? error.message : 'The ad failed to start showing.',
        this.adapterId
      );
      this.destroyDelegate();
      throw this.terminalError;
    }
  }

  complete(): boolean {
    if (this.currentState !== AdSessionState.Showing) { return false; }
    this.currentState = AdSessionState.Completed;
    return true;
  }

  fail(error: AdError): boolean {
    if (this.currentState !== AdSessionState.Showing && this.currentState !== AdSessionState.Ready) {
      return false;
    }
    this.currentState = AdSessionState.Failed;
    this.terminalError = error;
    this.destroyDelegate();
    return true;
  }

  destroy(): void {
    if (this.currentState === AdSessionState.Destroyed) { return; }
    this.currentState = AdSessionState.Destroyed;
    this.destroyDelegate();
  }

  private destroyDelegate(): void {
    if (this.destroyed) { return; }
    this.destroyed = true;
    try { this.delegate.destroy(); } catch (_) {
      // Vendor cleanup must not replace the original lifecycle outcome.
    }
  }
}
