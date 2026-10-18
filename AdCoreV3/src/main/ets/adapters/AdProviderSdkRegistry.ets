import { AdPrivacyGate } from '../core/AdPrivacyGate';

/**
 * Coordinates one SDK startup across full-screen and view adapters.
 * A provider may only be initialized once per app/configuration in a process.
 */
export class AdProviderSdkRegistry {
  private static readonly entries: Map<string, { configKey: string; promise: Promise<void> }> =
    new Map<string, { configKey: string; promise: Promise<void> }>();

  static ensure(providerId: string, configKey: string, initialize: () => Promise<void>): Promise<void> {
    try { AdPrivacyGate.requireConsent(providerId); } catch (error) { return Promise.reject(error); }
    const existing = AdProviderSdkRegistry.entries.get(providerId);
    if (existing !== undefined) {
      if (existing.configKey !== configKey) {
        return Promise.reject(new Error('SDK ' + providerId + ' was already configured with a different app configuration.'));
      }
      return existing.promise.then((): void => {
        AdPrivacyGate.requireConsent(providerId);
      });
    }

    const promise = initialize().catch((error: Error) => {
      const current = AdProviderSdkRegistry.entries.get(providerId);
      if (current !== undefined && current.configKey === configKey) {
        AdProviderSdkRegistry.entries.delete(providerId);
      }
      throw error;
    });
    AdProviderSdkRegistry.entries.set(providerId, { configKey: configKey, promise: promise });
    return promise.then((): void => {
      AdPrivacyGate.requireConsent(providerId);
    });
  }
}