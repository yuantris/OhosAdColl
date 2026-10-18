import { AdError, AdErrorCode, AdSessionState } from './AdCoreTypes';

/** State owner for one request. Terminal states cannot transition back to an active state. */
export class AdRequestSession {
  readonly requestId: string;
  private currentState: AdSessionState = AdSessionState.Created;
  private terminalError: AdError | null = null;
  private settled: boolean = false;
  private cancelHandlers: Array<() => void> = [];

  constructor(requestId: string) {
    this.requestId = requestId;
  }

  get state(): AdSessionState { return this.currentState; }
  get error(): AdError | null { return this.terminalError; }

  get isTerminal(): boolean {
    return this.currentState === AdSessionState.Completed ||
      this.currentState === AdSessionState.Failed ||
      this.currentState === AdSessionState.Cancelled ||
      this.currentState === AdSessionState.Destroyed;
  }

  transition(next: AdSessionState): boolean {
    if (this.isTerminal || this.currentState === next || !this.canTransition(this.currentState, next)) {
      return false;
    }
    this.currentState = next;
    if (next === AdSessionState.Completed || next === AdSessionState.Failed ||
      next === AdSessionState.Cancelled || next === AdSessionState.Destroyed) {
      this.settled = true;
      if (next !== AdSessionState.Cancelled) { this.cancelHandlers = []; }
    }
    return true;
  }

  fail(error: AdError): boolean {
    if (!this.transition(AdSessionState.Failed)) { return false; }
    this.terminalError = error;
    return true;
  }

  cancel(): boolean {
    const handlers = this.cancelHandlers.slice();
    if (!this.transition(AdSessionState.Cancelled)) { return false; }
    this.terminalError = new AdError(AdErrorCode.Cancelled, 'The ad request was cancelled.');
    this.cancelHandlers = [];
    handlers.forEach((handler: () => void) => {
      try { handler(); } catch (_) {
        // Cancellation must continue even if a cleanup callback fails.
      }
    });
    return true;
  }

  onCancel(handler: () => void): void {
    if (this.currentState === AdSessionState.Cancelled) {
      handler();
      return;
    }
    if (!this.isTerminal) { this.cancelHandlers.push(handler); }
  }

  markSettled(): boolean {
    if (this.settled) { return false; }
    this.settled = true;
    return true;
  }

  private canTransition(from: AdSessionState, to: AdSessionState): boolean {
    if (from === AdSessionState.Created) {
      return to === AdSessionState.Loading || to === AdSessionState.Cancelled ||
        to === AdSessionState.Failed || to === AdSessionState.Destroyed;
    }
    if (from === AdSessionState.Loading) {
      return to === AdSessionState.Ready || to === AdSessionState.Failed ||
        to === AdSessionState.Cancelled || to === AdSessionState.Destroyed;
    }
    if (from === AdSessionState.Ready) {
      return to === AdSessionState.Showing || to === AdSessionState.Completed ||
        to === AdSessionState.Cancelled || to === AdSessionState.Destroyed ||
        to === AdSessionState.Failed;
    }
    if (from === AdSessionState.Showing) {
      return to === AdSessionState.Completed || to === AdSessionState.Failed ||
        to === AdSessionState.Cancelled || to === AdSessionState.Destroyed;
    }
    return false;
  }
}
