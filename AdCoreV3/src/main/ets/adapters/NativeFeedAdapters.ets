import { NodeController } from '@kit.ArkUI';
import { ArrayList } from '@kit.ArkTS';
import {
  AdSlotBuilder,
  CSJAdSdk,
  CSJNativeExpressAd,
  NativeExpressAdListener,
  SDKConfig,
  SDKConfigBuilder
} from '@csj/openadsdk';
import {
  GDTAdLoadConfig,
  GDTAdSDK,
  GDTAdSize,
  GDTError,
  GDTMultiAdLoadListener,
  GDTNativeAd
} from '@gdt/gdt-union-sdk';
import { AdError, AdErrorCode, AdFormat } from '../core/AdCoreTypes';
import { AdNativeMaterial, AdRenderMode, AdViewAdapter, AdViewHandle, AdViewLifecycleListener, AdViewLoadRequest } from '../core/AdViewTypes';
import { AdProviderConfig, AdProviderRuntime, resolvePlacementId } from './AdProviderRuntime';
import { AdProviderSdkRegistry } from './AdProviderSdkRegistry';
import { CsjPrivacyController } from './CsjPrivacyController';
import { AdPrivacyGate } from '../core/AdPrivacyGate';

class NativeFeedViewHandle implements AdViewHandle {
  readonly providerId: string;
  readonly format: AdFormat = AdFormat.Native;
  readonly mode: AdRenderMode = AdRenderMode.ProviderView;
  readonly material: AdNativeMaterial | null = null;
  readonly nodeController: NodeController | null;
  private readonly renderAd: () => void;
  private readonly releaseAd: () => void;
  private listener: AdViewLifecycleListener | null = null;
  private mounted: boolean = false;
  private destroyed: boolean = false;

  constructor(
    providerId: string,
    nodeController: NodeController,
    renderAd: () => void,
    releaseAd: () => void
  ) {
    this.providerId = providerId;
    this.nodeController = nodeController;
    this.renderAd = renderAd;
    this.releaseAd = releaseAd;
  }

  setLifecycleListener(listener: AdViewLifecycleListener): void {
    this.listener = listener;
  }

  mount(): Promise<void> {
    if (this.destroyed) {
      return Promise.reject(new AdError(AdErrorCode.InvalidState, 'Cannot mount a destroyed feed ad.', this.providerId));
    }
    if (this.mounted) {
      return Promise.resolve();
    }
    this.mounted = true;
    try {
      this.renderAd();
      return Promise.resolve();
    } catch (error) {
      this.mounted = false;
      const message = error instanceof Error ? error.message : String(error);
      this.listener?.onFailed('RENDER_FAILED', message);
      return Promise.reject(new AdError(AdErrorCode.ShowFailed, message, this.providerId));
    }
  }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    this.mounted = false;
    this.listener = null;
    this.releaseAd();
  }

  notifyLoaded(): void { this.listener?.onLoaded(); }
  notifyShown(): void { this.listener?.onShown(); }
  notifyClicked(): void { this.listener?.onClicked(); }
  notifyClosed(): void { this.listener?.onClosed(); }
  notifyFailed(code: string, message: string): void { this.listener?.onFailed(code, message); }
}

/** Native-express feed adapter for 穿山甲（Pangle）. */
export class PangleFeedViewAdapter implements AdViewAdapter {
  readonly id: string = 'pangle';
  private readonly runtime: AdProviderRuntime;
  private readonly config: AdProviderConfig;
  private initPromise: Promise<void> | null = null;

  constructor(runtime: AdProviderRuntime, config: AdProviderConfig) {
    this.runtime = runtime;
    this.config = config;
  }

  private ensureInitialized(): Promise<void> {
    if (this.initPromise !== null) { return this.initPromise; }
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle appId must be configured.', this.id));
    }
    this.initPromise = AdProviderSdkRegistry.ensure(this.id, this.config.appId + ':' + String(this.config.debug), (): Promise<void> => {
      const sdkConfig: SDKConfig = new SDKConfigBuilder().appId(this.config.appId).allowShowNotify(true)
        .customController(new CsjPrivacyController()).debug(this.config.debug).build();
      CSJAdSdk.init(this.runtime.context, sdkConfig);
      return CSJAdSdk.start().then((): void => {
        AdPrivacyGate.requireConsent(this.id);
        if (!CSJAdSdk.isSdkReady()) { throw new AdError(AdErrorCode.LoadFailed, 'Pangle SDK did not become ready.', this.id); }
      });
    }).catch((error: Error) => {
      this.initPromise = null;
      throw new AdError(AdErrorCode.LoadFailed, 'Pangle SDK initialization failed: ' + String(error), this.id);
    });
    return this.initPromise;
  }

  loadView(request: AdViewLoadRequest): Promise<AdViewHandle> {
    try { AdPrivacyGate.requireConsent(this.id); } catch (error) { return Promise.reject(error); }
    if (request.request.format !== AdFormat.Native) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle feed adapter requires AdFormat.Native.', this.id));
    }
    const placementId = resolvePlacementId(request.request, this.id);
    if (placementId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle placement ID is empty.', this.id));
    }
    return this.ensureInitialized().then(() => {
      AdPrivacyGate.requireConsent(this.id);
      return new Promise<AdViewHandle>((resolve, reject) => {
      let settled = false;
      const timeoutMs = request.request.timeoutMs > 0 ? request.request.timeoutMs : 15000;
      const timeoutId = setTimeout((): void => {
        if (settled) { return; }
        settled = true;
        reject(new AdError(AdErrorCode.Timeout, 'Pangle feed request timed out.', this.id));
      }, timeoutMs);
      const slot = new AdSlotBuilder()
        .setCodeId(placementId)
        .setAcceptSize(Math.max(1, request.size.widthVp), Math.max(0, request.size.heightVp))
        .setAdCount(1)
        .build();
      const listener: NativeExpressAdListener = {
        onError: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          clearTimeout(timeoutId);
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        },
        onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>): void => {
          if (settled || AdPrivacyGate.state !== 'granted') {
            for (let i = 0; i < ads.length; i++) { ads[i].destroy(); }
            if (!settled) {
              settled = true;
              clearTimeout(timeoutId);
              reject(new AdError(AdErrorCode.InvalidState, 'Privacy consent was withdrawn while loading Pangle feed.', this.id));
            }
            return;
          }
          if (ads.length === 0) {
            settled = true;
            clearTimeout(timeoutId);
            reject(new AdError(AdErrorCode.LoadFailed, 'Pangle returned an empty feed list.', this.id));
            return;
          }
          settled = true;
          clearTimeout(timeoutId);
          const ad = ads[0];
          const node = ad.getAdComponent();
          if (node === undefined || node === null) {
            ad.destroy();
            reject(new AdError(AdErrorCode.LoadFailed, 'Pangle feed returned no ArkUI node.', this.id));
            return;
          }
          const handle = new NativeFeedViewHandle(this.id, node, (): void => {
            ad.render(this.runtime.uiContext);
          }, (): void => {
            ad.destroy();
          });
          ad.setExpressInteractionListener({
            onAdClicked: (): void => { handle.notifyClicked(); },
            onAdShow: (): void => { handle.notifyShown(); },
            onRenderFail: (code: number, message: string): void => { handle.notifyFailed(String(code), message); },
            onRenderSuccess: (): void => { handle.notifyLoaded(); }
          });
          resolve(handle);
        }
      };
      try {
        CSJAdSdk.getAdCreator().loadExpressFeedAd(slot, listener);
      } catch (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timeoutId);
          reject(new AdError(AdErrorCode.Internal,
            'Pangle feed request could not be started: ' + (error instanceof Error ? error.message : String(error)),
            this.id));
        }
      }
      });
    });
  }
}

/** Native feed adapter for 优量汇（GDT）. */
export class GdtFeedViewAdapter implements AdViewAdapter {
  readonly id: string = 'gdt';
  private readonly runtime: AdProviderRuntime;
  private readonly config: AdProviderConfig;
  private initPromise: Promise<void> | null = null;

  constructor(runtime: AdProviderRuntime, config: AdProviderConfig) {
    this.runtime = runtime;
    this.config = config;
  }

  private ensureInitialized(): Promise<void> {
    if (this.initPromise !== null) { return this.initPromise; }
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT appId must be configured.', this.id));
    }
    this.initPromise = AdProviderSdkRegistry.ensure(this.id, this.config.appId, (): Promise<void> => {
      GDTAdSDK.init(this.runtime.context, { appId: this.config.appId });
      return GDTAdSDK.start().then((): void => {
        AdPrivacyGate.requireConsent(this.id);
      });
    }).catch((error: Error) => {
      this.initPromise = null;
      throw new AdError(AdErrorCode.LoadFailed, 'GDT SDK initialization failed: ' + String(error), this.id);
    });
    return this.initPromise;
  }

  loadView(request: AdViewLoadRequest): Promise<AdViewHandle> {
    try { AdPrivacyGate.requireConsent(this.id); } catch (error) { return Promise.reject(error); }
    if (request.request.format !== AdFormat.Native) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT feed adapter requires AdFormat.Native.', this.id));
    }
    const placementId = resolvePlacementId(request.request, this.id);
    if (placementId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'GDT placement ID is empty.', this.id));
    }
    return this.ensureInitialized().then(() => {
      AdPrivacyGate.requireConsent(this.id);
      return new Promise<AdViewHandle>((resolve, reject) => {
      let settled = false;
      const timeoutMs = request.request.timeoutMs > 0 ? request.request.timeoutMs : 15000;
      const timeoutId = setTimeout((): void => {
        if (settled) { return; }
        settled = true;
        reject(new AdError(AdErrorCode.Timeout, 'GDT feed request timed out.', this.id));
      }, timeoutMs);
      const config: GDTAdLoadConfig = {
        posId: placementId,
        adSize: new GDTAdSize(GDTAdSize.FULL_WIDTH, GDTAdSize.AUTO_HEIGHT)
      };
      const listener: GDTMultiAdLoadListener<GDTNativeAd> = {
        onAdLoad: (ads: Array<GDTNativeAd>): void => {
          if (settled || AdPrivacyGate.state !== 'granted') {
            ads.forEach((ad: GDTNativeAd) => ad.destroy());
            if (!settled) {
              settled = true;
              clearTimeout(timeoutId);
              reject(new AdError(AdErrorCode.InvalidState, 'Privacy consent was withdrawn while loading GDT feed.', this.id));
            }
            return;
          }
          if (ads.length === 0) {
            settled = true;
            clearTimeout(timeoutId);
            reject(new AdError(AdErrorCode.LoadFailed, 'GDT returned an empty feed list.', this.id));
            return;
          }
          settled = true;
          clearTimeout(timeoutId);
          const ad = ads[0];
          const node = ad.getAdComponent();
          if (node === undefined || node === null) {
            ad.destroy();
            reject(new AdError(AdErrorCode.LoadFailed, 'GDT feed returned no ArkUI node.', this.id));
            return;
          }
          const handle = new NativeFeedViewHandle(this.id, node, (): void => {
            ad.setVideoOptions({ autoPlayMuted: true });
            ad.render(this.runtime.windowStage, this.runtime.uiContext);
          }, (): void => {
            ad.destroy();
          });
          ad.setInteractionListener({
            onAdExposure: (): void => { handle.notifyShown(); },
            onAdClick: (): void => { handle.notifyClicked(); },
            onAdClose: (): void => { handle.notifyClosed(); },
            onError: (error: GDTError): void => { handle.notifyFailed(String(error.code), error.message); }
          });
          ad.setRenderListener({
            onRenderSuccess: (): void => { handle.notifyLoaded(); },
            onRenderFail: (error: GDTError): void => { handle.notifyFailed(String(error.code), error.message); }
          });
          resolve(handle);
        },
        onError: (error: GDTError): void => {
          if (settled) { return; }
          settled = true;
          clearTimeout(timeoutId);
          reject(new AdError(AdErrorCode.LoadFailed, '[' + error.code + '] ' + error.message, this.id));
        }
      };
      try {
        GDTAdSDK.getAdLoader().loadNativeAd(config, listener);
      } catch (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timeoutId);
          reject(new AdError(AdErrorCode.Internal,
            'GDT feed request could not be started: ' + (error instanceof Error ? error.message : String(error)),
            this.id));
        }
      }
      });
    });
  }
}
