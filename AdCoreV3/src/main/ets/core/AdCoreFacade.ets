import { AdCore } from './AdCore';
import { AdCoreConfig } from './AdCoreConfig';
import { AdError, AdErrorCode, AdLoadResult, AdRequest } from './AdCoreTypes';
import { AdPrivacyGate, AdPrivacyState } from './AdPrivacyGate';
import { AdViewAdapter, AdViewHandle, AdViewLoadRequest } from './AdViewTypes';
import { AdProviderConfig, AdProviderRuntime } from '../adapters/AdProviderRuntime';
import { PangleAdAdapter } from '../adapters/PangleAdAdapter';
import { GdtAdAdapter } from '../adapters/GdtAdAdapter';
import { HuaweiAdAdapter } from '../adapters/HuaweiAdAdapter';
import { PangleFeedViewAdapter, GdtFeedViewAdapter } from '../adapters/NativeFeedAdapters';

/** Single host-facing entry point. Constructor wiring does not initialize vendor SDKs. */
export class AdCoreFacade {
  readonly core: AdCore;
  private readonly coreConfig: AdCoreConfig;
  private readonly viewAdapters: Map<string, AdViewAdapter> = new Map<string, AdViewAdapter>();
  private initialized: boolean = false;

  constructor(runtime: AdProviderRuntime, pangleConfig: AdProviderConfig, gdtConfig: AdProviderConfig,
    coreConfig: AdCoreConfig = new AdCoreConfig()) {
    this.core = new AdCore();
    this.coreConfig = coreConfig;
    this.core.registerAdapter(new PangleAdAdapter(runtime, pangleConfig));
    this.core.registerAdapter(new GdtAdAdapter(runtime, gdtConfig));
    this.core.registerAdapter(new HuaweiAdAdapter(runtime));
    this.viewAdapters.set('pangle', new PangleFeedViewAdapter(runtime, pangleConfig));
    this.viewAdapters.set('gdt', new GdtFeedViewAdapter(runtime, gdtConfig));
  }

  /** Call with true only after the user's affirmative action in the privacy UI. */
  initialize(consentGranted: boolean): void {
    AdPrivacyGate.setConsent(consentGranted);
    if (!consentGranted) {
      this.initialized = false;
      throw new AdError(AdErrorCode.InvalidState, 'Cannot initialize AdCoreFacade before privacy consent.', 'facade');
    }
    if (this.initialized) { return; }
    this.core.initialize(this.coreConfig);
    this.initialized = true;
  }

  /** Blocks new requests after consent withdrawal; SDKs already loaded may not support unloading. */
  revokeConsent(): void {
    AdPrivacyGate.setConsent(false);
    this.initialized = false;
  }

  get privacyState(): AdPrivacyState { return AdPrivacyGate.state; }

  async load(request: AdRequest): Promise<AdLoadResult> {
    if (!this.initialized || AdPrivacyGate.state !== AdPrivacyState.Granted) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidState,
        'Initialize the facade after explicit privacy consent before requesting ads.', 'facade'));
    }
    return this.core.load(request);
  }

  async loadView(providerId: string, request: AdViewLoadRequest): Promise<AdViewHandle> {
    AdPrivacyGate.requireConsent(providerId);
    if (!this.initialized) {
      throw new AdError(AdErrorCode.InvalidState,
        'Initialize the facade after explicit privacy consent before requesting ads.', 'facade');
    }
    const adapter = this.viewAdapters.get(providerId);
    if (adapter === undefined) {
      throw new AdError(AdErrorCode.NoAdapter, 'No view adapter registered for provider: ' + providerId, providerId);
    }
    return adapter.loadView(request);
  }
}