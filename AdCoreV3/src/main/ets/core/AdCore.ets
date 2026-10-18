import { AdAdapter } from './AdAdapter';
import { AdCoreConfig } from './AdCoreConfig';
import { AdError, AdErrorCode, AdLoadResult, AdRequest } from './AdCoreTypes';
import { AdRequestSession } from './AdRequestSession';
import { AdOrchestrator } from '../orchestration/AdOrchestrator';

/** Shared configuration/adapter registry; mutable state remains isolated per request. */
export class AdCore {
  private configValue: AdCoreConfig = new AdCoreConfig();
  private initialized: boolean = false;
  private adapters: AdAdapter[] = [];
  private inFlight: Map<string, AdRequestSession> = new Map<string, AdRequestSession>();
  private orchestrator: AdOrchestrator = new AdOrchestrator();

  get config(): AdCoreConfig { return this.configValue; }
  get isInitialized(): boolean { return this.initialized; }

  initialize(config: AdCoreConfig = new AdCoreConfig()): void {
    if (this.initialized) { return; }
    if (config.defaultTimeoutMs <= 0) {
      throw new AdError(AdErrorCode.InvalidRequest, 'Default timeout must be greater than zero.');
    }
    this.configValue = new AdCoreConfig(config.defaultTimeoutMs, config.debug);
    this.initialized = true;
  }

  registerAdapter(adapter: AdAdapter): void {
    if (this.initialized) {
      throw new AdError(AdErrorCode.InvalidState, 'Register adapters before initialize() in alpha.3.');
    }
    if (adapter.id.length === 0) {
      throw new AdError(AdErrorCode.InvalidRequest, 'Adapter id cannot be empty.');
    }
    if (this.adapters.some((registered: AdAdapter) => registered.id === adapter.id)) {
      throw new AdError(AdErrorCode.InvalidRequest, 'Duplicate adapter id: ' + adapter.id);
    }
    this.adapters.push(adapter);
  }

  async load(request: AdRequest): Promise<AdLoadResult> {
    if (!this.initialized) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidState, 'Call initialize() before loading ads.'));
    }
    if (request.requestId.length === 0 || request.placementId.length === 0) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidRequest, 'Request id and placement id cannot be empty.'));
    }
    if (this.inFlight.has(request.requestId)) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidRequest, 'This request id is already in flight.'));
    }

    const effectiveRequest = request.timeoutMs > 0
      ? request
      : new AdRequest(request.requestId, request.format, request.placementId, this.configValue.defaultTimeoutMs, request.extras);
    const session = new AdRequestSession(effectiveRequest.requestId);
    this.inFlight.set(effectiveRequest.requestId, session);
    try {
      return await this.orchestrator.load(effectiveRequest, this.adapters, session);
    } finally {
      this.inFlight.delete(effectiveRequest.requestId);
    }
  }

  cancel(requestId: string): boolean {
    const session = this.inFlight.get(requestId);
    if (session === undefined) { return false; }
    return session.cancel();
  }
}
