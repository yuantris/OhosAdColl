import { AdError, AdErrorCode } from './AdCoreTypes';

export enum AdPrivacyState {
  Unknown = 'unknown',
  Denied = 'denied',
  Granted = 'granted'
}

/** Process-wide consent gate. Unknown/denied are both closed by default. */
export class AdPrivacyGate {
  private static currentState: AdPrivacyState = AdPrivacyState.Unknown;
  private static nextListenerId: number = 1;
  private static readonly listeners: Map<number, (state: AdPrivacyState) => void> =
    new Map<number, (state: AdPrivacyState) => void>();

  static get state(): AdPrivacyState { return AdPrivacyGate.currentState; }

  /** Subscribe UI-owned SDK components to consent changes. Returns an idempotent unsubscribe action. */
  static subscribe(listener: (state: AdPrivacyState) => void): () => void {
    const listenerId = AdPrivacyGate.nextListenerId;
    AdPrivacyGate.nextListenerId += 1;
    AdPrivacyGate.listeners.set(listenerId, listener);
    return (): void => {
      AdPrivacyGate.listeners.delete(listenerId);
    };
  }

  static setConsent(granted: boolean): void {
    const nextState = granted ? AdPrivacyState.Granted : AdPrivacyState.Denied;
    if (AdPrivacyGate.currentState === nextState) { return; }
    AdPrivacyGate.currentState = nextState;
    AdPrivacyGate.listeners.forEach((listener: (state: AdPrivacyState) => void) => {
      try { listener(nextState); } catch (_) {
        // A UI observer must not prevent other observers from receiving consent changes.
      }
    });
  }
  static requireConsent(providerId: string = ''): void {
    if (AdPrivacyGate.currentState !== AdPrivacyState.Granted) {
      throw new AdError(AdErrorCode.InvalidState,
        'Advertising SDK access is blocked until the user explicitly agrees to the privacy policy.', providerId);
    }
  }
}