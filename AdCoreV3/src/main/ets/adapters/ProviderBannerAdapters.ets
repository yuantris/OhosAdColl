import { NodeController } from '@kit.ArkUI';
import { AdSlotBuilder, CSJAdSdk, CSJNativeExpressAd, NativeExpressAdListener, SDKConfig, SDKConfigBuilder } from '@csj/openadsdk';
import { ArrayList } from '@kit.ArkTS';
import { GDTAdLoadConfig, GDTAdLoadListener, GDTAdSDK, GDTAdSize, GDTBannerAd, GDTError } from '@gdt/gdt-union-sdk';
import { AdError, AdErrorCode, AdFormat } from '../core/AdCoreTypes';
import { AdRenderMode, AdViewAdapter, AdViewHandle, AdViewLifecycleListener, AdViewLoadRequest } from '../core/AdViewTypes';
import { AdProviderConfig, AdProviderRuntime, resolvePlacementId } from './AdProviderRuntime';
import { AdProviderSdkRegistry } from './AdProviderSdkRegistry';
import { CsjPrivacyController } from './CsjPrivacyController';
import { AdPrivacyGate } from '../core/AdPrivacyGate';

class BannerHandle implements AdViewHandle {
  readonly providerId: string;
  readonly format: AdFormat = AdFormat.Banner;
  readonly mode: AdRenderMode = AdRenderMode.ProviderView;
  readonly material = null;
  readonly nodeController: NodeController;
  private readonly render: () => void;
  private readonly release: () => void;
  private listener: AdViewLifecycleListener | null = null;
  private mounted = false;
  private destroyed = false;

  constructor(providerId: string, node: NodeController, render: () => void, release: () => void) {
    this.providerId = providerId;
    this.nodeController = node;
    this.render = render;
    this.release = release;
  }
  setLifecycleListener(listener: AdViewLifecycleListener): void { this.listener = listener; }
  mount(): Promise<void> {
    if (this.destroyed) {
      return Promise.reject(new AdError(AdErrorCode.InvalidState, 'Cannot mount a destroyed Banner.', this.providerId));
    }
    if (this.mounted) { return Promise.resolve(); }
    this.mounted = true;
    try {
      this.render();
      return Promise.resolve();
    } catch (error) {
      this.mounted = false;
      const message = error instanceof Error ? error.message : String(error);
      this.listener?.onFailed('RENDER_FAILED', message);
      return Promise.reject(new AdError(AdErrorCode.ShowFailed, message, this.providerId));
    }
  }
  destroy(): void {
    if (this.destroyed) { return; }
    this.destroyed = true;
    this.mounted = false;
    this.listener = null;
    this.release();
  }
  loaded(): void { this.listener?.onLoaded(); }
  shown(): void { this.listener?.onShown(); }
  clicked(): void { this.listener?.onClicked(); }
  closed(): void { this.listener?.onClosed(); }
  failed(code: string, message: string): void { this.listener?.onFailed(code, message); }
}

export class PangleBannerViewAdapter implements AdViewAdapter {
  readonly id = 'pangle';
  private readonly runtime: AdProviderRuntime;
  private readonly config: AdProviderConfig;
  constructor(runtime: AdProviderRuntime, config: AdProviderConfig) {
    this.runtime = runtime;
    this.config = config;
  }
  private ensureInitialized(): Promise<void> {
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle appId must be configured.', this.id));
    }
    return AdProviderSdkRegistry.ensure(this.id, this.config.appId + ':' + String(this.config.debug), (): Promise<void> => {
      const sdkConfig: SDKConfig = new SDKConfigBuilder().appId(this.config.appId).allowShowNotify(true)
        .customController(new CsjPrivacyController()).debug(this.config.debug).build();
      CSJAdSdk.init(this.runtime.context, sdkConfig);
      return CSJAdSdk.start().then((): void => {
        AdPrivacyGate.requireConsent(this.id);
        if (!CSJAdSdk.isSdkReady()) {
          throw new AdError(AdErrorCode.LoadFailed, 'Pangle SDK did not become ready.', this.id);
        }
      });
    });
  }
  loadView(request: AdViewLoadRequest): Promise<AdViewHandle> {
    try { AdPrivacyGate.requireConsent(this.id); } catch (error) { return Promise.reject(error); }
    if (request.request.format !== AdFormat.Banner) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle Banner adapter requires AdFormat.Banner.', this.id));
    }
    const placementId = resolvePlacementId(request.request, this.id);
    if (placementId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle Banner placement ID is empty.', this.id));
    }
    return this.ensureInitialized().then(() => new Promise<AdViewHandle>((resolve, reject) => {
      let settled = false;
      const timeout = setTimeout((): void => {
        if (settled) { return; }
        settled = true;
        reject(new AdError(AdErrorCode.Timeout, 'Pangle Banner request timed out.', this.id));
      }, request.request.timeoutMs > 0 ? request.request.timeoutMs : 15000);
      const slot = new AdSlotBuilder().setCodeId(placementId)
        .setAcceptSize(Math.max(1, request.size.widthVp), Math.max(1, request.size.heightVp))
        .setAdCount(1).build();
      const listener: NativeExpressAdListener = {
        onError: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          clearTimeout(timeout);
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        },
        onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>): void => {
          if (settled || AdPrivacyGate.state !== 'granted') {
            for (let i = 0; i < ads.length; i++) { ads[i].destroy(); }
            if (!settled) {
              settled = true;
              clearTimeout(timeout);
              reject(new AdError(AdErrorCode.InvalidState, 'Privacy consent was withdrawn during Pangle Banner load.', this.id));
            }
            return;
          }
          if (ads.length === 0) {
            settled = true;
            clearTimeout(timeout);
            reject(new AdError(AdErrorCode.LoadFailed, 'Pangle returned no Banner ad.', this.id));
            return;
          }
          settled = true;
          clearTimeout(timeout);
          const ad = ads[0];
          const node = ad.getAdComponent();
          if (node === null || node === undefined) {
            ad.destroy();
            reject(new AdError(AdErrorCode.LoadFailed, 'Pangle Banner returned no ArkUI node.', this.id));
            return;
          }
          const handle = new BannerHandle(this.id, node, (): void => {
            ad.setSlideIntervalTime(30000);
            ad.render(this.runtime.uiContext);
          }, (): void => { ad.destroy(); });
          ad.setExpressInteractionListener({
            onAdClicked: (): void => { handle.clicked(); },
            onAdShow: (): void => { handle.shown(); },
            onRenderSuccess: (): void => { handle.loaded(); },
            onRenderFail: (code: number, message: string): void => { handle.failed(String(code), message); }
          });
          resolve(handle);
        }
      };
      try {
        CSJAdSdk.getAdCreator().loadBannerAd(slot, listener);
      } catch (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timeout);
          reject(new AdError(AdErrorCode.Internal, 'Could not start Pangle Banner request: ' +
            (error instanceof Error ? error.message : String(error)), this.id));
        }
      }
    }));
  }
}

export class GdtBannerViewAdapter implements AdViewAdapter {
  readonly id = 'gdt';
  private readonly runtime: AdProviderRuntime;
  private readonly config: AdProviderConfig;
  constructor(runtime: AdProviderRuntime, config: AdProviderConfig) {
    this.runtime = runtime;
    this.config = config;
  }
  private ensureInitialized(): Promise<void> {
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT appId must be configured.', this.id));
    }
    return AdProviderSdkRegistry.ensure(this.id, this.config.appId, (): Promise<void> => {
      GDTAdSDK.init(this.runtime.context, { appId: this.config.appId });
      return GDTAdSDK.start().then((): void => { AdPrivacyGate.requireConsent(this.id); });
    });
  }
  loadView(request: AdViewLoadRequest): Promise<AdViewHandle> {
    try { AdPrivacyGate.requireConsent(this.id); } catch (error) { return Promise.reject(error); }
    if (request.request.format !== AdFormat.Banner) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT Banner adapter requires AdFormat.Banner.', this.id));
    }
    const placementId = resolvePlacementId(request.request, this.id);
    if (placementId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT Banner placement ID is empty.', this.id));
    }
    return this.ensureInitialized().then(() => new Promise<AdViewHandle>((resolve, reject) => {
      let settled = false;
      const timeout = setTimeout((): void => {
        if (settled) { return; }
        settled = true;
        reject(new AdError(AdErrorCode.Timeout, 'GDT Banner request timed out.', this.id));
      }, request.request.timeoutMs > 0 ? request.request.timeoutMs : 15000);
      const config: GDTAdLoadConfig = {
        posId: placementId,
        adSize: new GDTAdSize(Math.max(1, request.size.widthVp), Math.max(1, request.size.heightVp))
      };
      const listener: GDTAdLoadListener<GDTBannerAd> = {
        onAdLoad: (ad: GDTBannerAd): void => {
          if (settled || AdPrivacyGate.state !== 'granted') {
            ad.destroy();
            if (!settled) {
              settled = true;
              clearTimeout(timeout);
              reject(new AdError(AdErrorCode.InvalidState, 'Privacy consent was withdrawn during GDT Banner load.', this.id));
            }
            return;
          }
          settled = true;
          clearTimeout(timeout);
          const node = ad.getAdComponent();
          if (node === null || node === undefined) {
            ad.destroy();
            reject(new AdError(AdErrorCode.LoadFailed, 'GDT Banner returned no ArkUI node.', this.id));
            return;
          }
          const handle = new BannerHandle(this.id, node, (): void => {
            ad.setRefresh(30);
            ad.setRenderListener({
              onRenderSuccess: (): void => { handle.loaded(); },
              onRenderFail: (): void => { handle.failed('RENDER_FAILED', 'GDT Banner render failed.'); }
            });
            ad.setInteractionListener({
              onAdExposure: (): void => { handle.shown(); },
              onAdClick: (): void => { handle.clicked(); },
              onAdClose: (): void => { handle.closed(); },
              onError: (error: GDTError): void => { handle.failed(String(error.code), error.message); }
            });
            ad.render(this.runtime.windowStage, this.runtime.uiContext);
          }, (): void => { ad.destroy(); });
          resolve(handle);
        },
        onError: (error: GDTError): void => {
          if (settled) { return; }
          settled = true;
          clearTimeout(timeout);
          reject(new AdError(AdErrorCode.LoadFailed, '[' + error.code + '] ' + error.message, this.id));
        }
      };
      try {
        GDTAdSDK.getAdLoader().loadBannerAd(config, listener);
      } catch (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timeout);
          reject(new AdError(AdErrorCode.Internal, 'Could not start GDT Banner request: ' +
            (error instanceof Error ? error.message : String(error)), this.id));
        }
      }
    }));
  }
}
