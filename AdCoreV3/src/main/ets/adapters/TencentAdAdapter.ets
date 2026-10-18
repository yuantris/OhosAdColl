import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTError,
  GDTInteractionListener,
  GDTInterstitialAd,
  GDTRewardAd,
  GDTSplashAd
} from '@gdt/gdt-union-sdk';
import { BusinessError } from '@kit.BasicServicesKit';
import { AdAdapter } from '../core/AdAdapter';
import { AdError, AdErrorCode, AdFormat, AdHandle, AdRequest } from '../core/AdCoreTypes';
import { AdProviderConfig, AdProviderRuntime, resolvePlacementId } from './AdProviderRuntime';
import { AdVendorHandle } from './AdVendorHandle';

/** Tencent GDT adapter. Vendor callbacks are translated into V3 lifecycle events. */
export class TencentAdAdapter implements AdAdapter {
  readonly id: string = 'tencent';
  readonly supportedFormats: AdFormat[] = [AdFormat.Splash, AdFormat.Interstitial, AdFormat.Rewarded];
  private readonly runtime: AdProviderRuntime;
  private readonly config: AdProviderConfig;
  private initPromise: Promise<void> | null = null;

  constructor(runtime: AdProviderRuntime, config: AdProviderConfig) {
    this.runtime = runtime;
    this.config = config;
  }

  async load(request: AdRequest): Promise<AdHandle> {
    await this.ensureInitialized();
    if (request.format === AdFormat.Splash) { return this.loadSplash(request); }
    if (request.format === AdFormat.Interstitial) { return this.loadInterstitial(request); }
    if (request.format === AdFormat.Rewarded) { return this.loadRewarded(request); }
    throw new AdError(AdErrorCode.InvalidRequest, 'Tencent does not support format: ' + request.format, this.id);
  }

  private ensureInitialized(): Promise<void> {
    if (this.initPromise !== null) { return this.initPromise; }
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Tencent appId must be configured.', this.id));
    }
    GDTAdSDK.init(this.runtime.context, { appId: this.config.appId });
    this.initPromise = GDTAdSDK.start().then((): void => {}).catch((error: BusinessError) => {
      this.initPromise = null;
      throw new AdError(AdErrorCode.LoadFailed, 'Tencent SDK initialization failed: ' +
        (error instanceof Error ? error.message : String(error)), this.id);
    });
    return this.initPromise;
  }

  private loadSplash(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const listener: GDTAdLoadListener<GDTSplashAd> = {
        onAdLoad: (ad: GDTSplashAd): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.show(this.runtime.windowStage);
          });
          ad.setInteractionListener({
            onAdExposure: (): void => {},
            onAdClick: (): void => {},
            onAdClose: (): void => { handle.notifyCompleted(); },
            onError: (error: GDTError): void => { handle.notifyFailed(error.code, error.message); }
          });
          resolve(handle);
        },
        onError: (error: GDTError): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + error.code + '] ' + error.message, this.id));
        }
      };
      const config: GDTAdLoadConfig = { posId: resolvePlacementId(request, this.id) };
      GDTAdSDK.getAdLoader().loadSplashAd(config, listener);
    });
  }

  private loadInterstitial(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const listener: GDTAdLoadListener<GDTInterstitialAd> = {
        onAdLoad: (ad: GDTInterstitialAd): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.show(this.runtime.windowStage);
          });
          ad.setInteractionListener({
            onAdExposure: (): void => {},
            onAdClick: (): void => {},
            onAdClose: (): void => { handle.notifyCompleted(); },
            onError: (error: GDTError): void => { handle.notifyFailed(error.code, error.message); }
          });
          resolve(handle);
        },
        onError: (error: GDTError): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + error.code + '] ' + error.message, this.id));
        }
      };
      GDTAdSDK.getAdLoader().loadInterstitialAd({ posId: resolvePlacementId(request, this.id) }, listener);
    });
  }

  private loadRewarded(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const listener: GDTAdLoadListener<GDTRewardAd> = {
        onAdLoad: (ad: GDTRewardAd): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.show(this.runtime.windowStage);
          });
          let rewarded = false;
          const interactionListener: GDTInteractionListener = {
            onAdExposure: (): void => {},
            onAdClick: (): void => {},
            onAdClose: (): void => {
              if (rewarded) { handle.notifyCompleted(); }
              else { handle.notifyFailed(-1, 'Rewarded video closed before reward callback.'); }
            },
            onError: (error: GDTError): void => { handle.notifyFailed(error.code, error.message); },
            onReward: (): void => { rewarded = true; }
          };
          ad.setInteractionListener(interactionListener);
          resolve(handle);
        },
        onError: (error: GDTError): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + error.code + '] ' + error.message, this.id));
        }
      };
      GDTAdSDK.getAdLoader().loadRewardAd({ posId: resolvePlacementId(request, this.id) }, listener);
    });
  }
}
