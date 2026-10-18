import { AdError, AdErrorCode, AdFormat, AdHandle, AdHandleLifecycleListener } from '../core/AdCoreTypes';

/** Common lifecycle bridge that keeps vendor objects private to the adapter module. */
export class AdVendorHandle implements AdHandle {
  readonly id: string;
  readonly adapterId: string;
  readonly format: AdFormat;
  private readonly showAction: () => Promise<void>;
  private readonly releaseAction: () => void;
  private listener: AdHandleLifecycleListener | undefined;
  private shown: boolean = false;
  private destroyed: boolean = false;

  constructor(
    id: string,
    adapterId: string,
    format: AdFormat,
    showAction: () => Promise<void>,
    releaseAction: () => void = () => {}
  ) {
    this.id = id;
    this.adapterId = adapterId;
    this.format = format;
    this.showAction = showAction;
    this.releaseAction = releaseAction;
  }

  setLifecycleListener(listener: AdHandleLifecycleListener): void {
    this.listener = listener;
  }

  async show(): Promise<void> {
    if (this.destroyed || this.shown) {
      throw new AdError(AdErrorCode.InvalidState, 'This vendor ad handle is no longer showable.', this.adapterId);
    }
    this.shown = true;
    try {
      await this.showAction();
    } catch (error) {
      const adError = new AdError(
        AdErrorCode.ShowFailed,
        error instanceof Error ? error.message : 'Vendor SDK failed to show the ad.',
        this.adapterId
      );
      this.listener?.onFailed(adError);
      throw adError;
    }
  }

  notifyCompleted(): void {
    if (!this.destroyed) {
      this.listener?.onCompleted();
    }
  }

  notifyFailed(code: number, message: string): void {
    if (!this.destroyed) {
      this.listener?.onFailed(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.adapterId));
    }
  }

  destroy(): void {
    if (this.destroyed) { return; }
    this.destroyed = true;
    try { this.releaseAction(); } catch (_) {
      // Cleanup errors must not mask the ad outcome.
    }
    this.listener = undefined;
  }
}
