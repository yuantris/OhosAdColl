import { AdError, AdErrorCode } from './AdCoreTypes';

export enum AdPrivacyState {
  Unknown = 'unknown',
  Denied = 'denied',
  Granted = 'granted'
}

/** Process-wide consent gate. Unknown/denied are both closed by default. */
export class AdPrivacyGate {
  private static currentState: AdPrivacyState = AdPrivacyState.Unknown;
  static get state(): AdPrivacyState { return AdPrivacyGate.currentState; }
  static setConsent(granted: boolean): void {
    AdPrivacyGate.currentState = granted ? AdPrivacyState.Granted : AdPrivacyState.Denied;
  }
  static requireConsent(providerId: string = ''): void {
    if (AdPrivacyGate.currentState !== AdPrivacyState.Granted) {
      throw new AdError(AdErrorCode.InvalidState,
        'Advertising SDK access is blocked until the user explicitly agrees to the privacy policy.', providerId);
    }
  }
}