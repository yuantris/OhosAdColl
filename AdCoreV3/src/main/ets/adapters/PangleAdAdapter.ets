import {
  AdSlotBuilder, CSJAdSdk, CSJRewardAd, CSJSplashAd, CSJSplashAdLoadListener,
  CSJSplashAdLoadParam, FullAdLoadListener, RewardAdLoadListener, SDKConfig, SDKConfigBuilder
} from '@csj/openadsdk';
import { display } from '@kit.ArkUI';
import { AdAdapter } from '../core/AdAdapter';
import { AdError, AdErrorCode, AdFormat, AdHandle, AdRequest } from '../core/AdCoreTypes';
import { AdProviderConfig, AdProviderRuntime, resolvePlacementId } from './AdProviderRuntime';
import { AdVendorHandle } from './AdVendorHandle';
import { CsjPrivacyController } from './CsjPrivacyController';
import { AdProviderSdkRegistry } from './AdProviderSdkRegistry';
import { AdPrivacyGate } from '../core/AdPrivacyGate';

export class PangleAdAdapter implements AdAdapter {
  readonly id: string = 'pangle';
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
    AdPrivacyGate.requireConsent(this.id);
    if (request.format === AdFormat.Splash) { return this.loadSplash(request); }
    if (request.format === AdFormat.Interstitial) { return this.loadInterstitial(request); }
    if (request.format === AdFormat.Rewarded) { return this.loadRewarded(request); }
    throw new AdError(AdErrorCode.InvalidRequest, 'Pangle does not support format: ' + request.format, this.id);
  }

  private ensureInitialized(): Promise<void> {
    if (this.initPromise !== null) { return this.initPromise; }
    if (this.config.appId.length === 0) {
      return Promise.reject(new AdError(AdErrorCode.InvalidRequest, 'Pangle appId must be configured.', this.id));
    }
    this.initPromise = AdProviderSdkRegistry.ensure(this.id, this.config.appId + ':' + String(this.config.debug), (): Promise<void> => {
      const sdkConfig: SDKConfig = new SDKConfigBuilder()
        .appId(this.config.appId).allowShowNotify(true)
        .customController(new CsjPrivacyController()).debug(this.config.debug).build();
      CSJAdSdk.init(this.runtime.context, sdkConfig);
      return CSJAdSdk.start().then((): void => {
        if (!CSJAdSdk.isSdkReady()) { throw new AdError(AdErrorCode.LoadFailed, 'Pangle SDK did not become ready.', this.id); }
      });
    }).catch((error: Error) => {
      this.initPromise = null;
      throw new AdError(AdErrorCode.LoadFailed, 'Pangle SDK initialization failed: ' +
        (error instanceof Error ? error.message : String(error)), this.id);
    });
    return this.initPromise;
  }

  private loadSplash(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const screen = display.getDefaultDisplaySync();
      const screenWidth = screen.width / screen.densityPixels;
      const screenHeight = screen.height / screen.densityPixels;
      const slot = new AdSlotBuilder()
        .setCodeId(resolvePlacementId(request, this.id))
        .setAcceptSize(screenWidth, screenHeight)
        .build();
      const listener: CSJSplashAdLoadListener = {
        onAdLoaded: (ad: CSJSplashAd): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.showSplashAd(this.runtime.windowStage);
          });
          ad.setInteractionListener({
            onDidShow: (): void => {},
            onDidClose: (): void => { handle.notifyCompleted(); },
            onDidClick: (): void => {},
            onVideoDidPlayFinish: (): void => {},
            onVideoDidPlayFail: (): void => {}
          });
          resolve(handle);
        },
        onError: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        },
        onRenderSuccess: (): void => {},
        onRenderFail: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        }
      };
      CSJAdSdk.getAdCreator().loadSplashAd(new CSJSplashAdLoadParam(slot, listener, this.runtime.uiContext));
    });
  }

  private loadInterstitial(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const listener: FullAdLoadListener = {
        onAdLoaded: (ad): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.showFullAd(this.runtime.windowStage);
          });
          ad.setInteractionListener({
            onShow: (): void => {},
            onSkip: (): void => { handle.notifyCompleted(); },
            onClick: (): void => {},
            onComplete: (): void => {},
            onClose: (): void => { handle.notifyCompleted(); }
          });
          resolve(handle);
        },
        onAdCached: (): void => {},
        onError: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        }
      };
      CSJAdSdk.getAdCreator().loadFullAd(new AdSlotBuilder().setCodeId(resolvePlacementId(request, this.id)).build(), listener);
    });
  }

  private loadRewarded(request: AdRequest): Promise<AdHandle> {
    return new Promise((resolve, reject) => {
      let settled = false;
      const listener: RewardAdLoadListener = {
        onAdLoaded: (ad: CSJRewardAd): void => {
          if (settled) { return; }
          settled = true;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            ad.showRewardAd(this.runtime.windowStage);
          });
          let rewarded = false;
          ad.setInteractionListener({
            onShow: (): void => {},
            onSkip: (): void => {},
            onClick: (): void => {},
            onClose: (): void => {
              if (rewarded) { handle.notifyCompleted(); }
              else { handle.notifyFailed(-1, 'Rewarded video closed before reward completion.'); }
            },
            onComplete: (): void => { rewarded = true; },
            onRewardArrived: (): void => { rewarded = true; }
          });
          resolve(handle);
        },
        onAdCached: (): void => {},
        onError: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        }
      };
      CSJAdSdk.getAdCreator().loadRewardAd(
        new AdSlotBuilder().setCodeId(resolvePlacementId(request, this.id)).setRewardAmount(1).build(), listener);
    });
  }
}
