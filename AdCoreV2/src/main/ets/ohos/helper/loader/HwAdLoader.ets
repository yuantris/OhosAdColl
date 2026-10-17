import { advertising } from '@kit.AdsKit'
import { promptAction } from '@kit.ArkUI'
import { Ohos } from '@zycore/common'
import { RewardAdStatusHandler } from '../platform/huawei/RewardAdStatusHandler'
import { InterstitialAdStatusHandler } from '../platform/huawei/InterstitialAdStatusHandler'
import { AdLoaders, AdLoadOptions, AdLoadResult, InterstitialAdLoader, RewardVideoAdLoader, SplashAdLoader, AD_LOAD_TIMEOUT_MS } from './AdLoaderTypes'
import { ErrCode } from '../const/ErrCode'
import { OnAdListener } from '../../interface/OnAdListener'
import { OAIDStore } from '../core/OAIDStore'
import { AdSwitchManager } from '../core/AdSwitchManager'
import { LogManager } from '../logger/LogManager'
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener'


const TAG = 'HwAdLoader';

interface HwSplashAdHandle {
  ads: Array<advertising.Advertisement>;
  adDisplayOptions: advertising.AdDisplayOptions;
}

interface HwInterstitialAdHandle {
  ads: Array<advertising.Advertisement>;
  displayOptions: advertising.AdDisplayOptions;
}

class HwSplashAdLoader implements SplashAdLoader {
  async load(adId: string, listener?: OnAdListener, options?: AdLoadOptions): Promise<AdLoadResult> {
    return new Promise((resolve) => {
      const deferShow = options?.deferShow === true;
      const timeoutMs = options?.loadTimeout ?? AD_LOAD_TIMEOUT_MS;
      let settled = false;
      const done = (result: AdLoadResult) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timer);
        resolve(result);
      };

      const timer = setTimeout(() => {
        LogManager.error(TAG, `Splash[${adId}] - load timeout after ${timeoutMs}ms`);
        done(AdLoadResult.failure(ErrCode.AD_TIMEOUT, 'Splash ad load timeout'));
      }, timeoutMs);

      const adDisplayOptions: advertising.AdDisplayOptions = { mute: true };

      const adOptions: advertising.AdOptions = {
        allowMobileTraffic: 0,
        tagForChildProtection: -1,
        tagForUnderAgeOfPromise: -1,
        adContentClassification: 'A'
      };

      const splashAdReqParams: advertising.AdRequestParams = {
        adId: adId,
        adType: 1,
        adCount: 1,
        oaid: OAIDStore.OAID
      };

      const adLoaderListener: advertising.AdLoadListener = {
        onAdLoadFailure: (errorCode: number, errorMsg: string) => {
          LogManager.error(TAG, `Splash - ${adId} load failed: ${errorCode}, ${errorMsg}`);
          done(AdLoadResult.failure(errorCode, errorMsg));
        },
        onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
          LogManager.info(TAG, `Splash - load success, adType: ${ads[0].adType}`);
          if (canIUse("SystemCapability.Advertising.Ads") && ads.length > 0 && ads[0].adType === 1) {
            listener?.onAdRender?.();
            const data: HwSplashAdHandle = { ads, adDisplayOptions };
            if (deferShow) {
              done(AdLoadResult.success(data, data));
            } else {
              done(AdLoadResult.success(data));
            }
          } else {
            const error = `Error adType: ${ads[0].adType}`;
            LogManager.error(TAG, error);
            done(AdLoadResult.failure(ErrCode.AD_RENDER_FAILED, error));
          }
        }
      };

      const load = new advertising.AdLoader(Ohos.getContext());
      load.loadAd(splashAdReqParams, adOptions, adLoaderListener);
    });
  }
}

class HwInterstitialAdLoader implements InterstitialAdLoader {
  async load(adId: string, listener?: OnAdListener, options?: AdLoadOptions): Promise<AdLoadResult> {
    return new Promise((resolve) => {
      const deferShow = options?.deferShow === true;
      const timeoutMs = options?.loadTimeout ?? AD_LOAD_TIMEOUT_MS;
      let settled = false;
      const done = (result: AdLoadResult) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timer);
        resolve(result);
      };

      const timer = setTimeout(() => {
        LogManager.error(TAG, `Interstitial[${adId}] - load timeout after ${timeoutMs}ms`);
        done(AdLoadResult.failure(ErrCode.AD_TIMEOUT, 'Interstitial ad load timeout'));
      }, timeoutMs);

      const adRequestParam: advertising.AdRequestParams = {
        adType: 12,
        adId: adId,
        oaid: OAIDStore.OAID
      };

      const displayOptions: advertising.AdDisplayOptions = {
        mute: true,
        colorMode: 1
      };

      const adOption: advertising.AdOptions = {
        nonPersonalizedAd: 0,
        allowMobileTraffic: 0,
        tagForChildProtection: -1,
        tagForUnderAgeOfPromise: -1,
        adContentClassification: 'A'
      };

      const adLoaderListener: advertising.AdLoadListener = {
        onAdLoadFailure: (errorCode: number, errorMsg: string) => {
          LogManager.error(TAG, `Interstitial - ${adId} load failed: ${errorCode}, ${errorMsg}`);
          done(AdLoadResult.failure(errorCode, errorMsg));
        },
        onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
          LogManager.info(TAG, 'Interstitial - load success');
          const statusHandler = new InterstitialAdStatusHandler();
          statusHandler.setAdListener(listener);
          statusHandler.registerPPSReceiver();
          const handle: HwInterstitialAdHandle = { ads, displayOptions };
          if (deferShow) {
            done(AdLoadResult.success(undefined, handle));
          } else {
            advertising.showAd(ads[0], displayOptions, Ohos.getContext());
            done(AdLoadResult.success());
          }
        }
      };

      const load = new advertising.AdLoader(Ohos.getContext());
      load.loadAd(adRequestParam, adOption, adLoaderListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'Interstitial - show');
    const handle = nativeHandle as advertising.Advertisement;
    advertising.showAd(handle, { mute: true, colorMode: 1 }, Ohos.getContext());
  }
}

class HwRewardVideoAdLoader implements RewardVideoAdLoader {
  async load(adId: string, listener?: OnVideoRewardListener, options?: AdLoadOptions): Promise<AdLoadResult> {
    return new Promise((resolve) => {
      const deferShow = options?.deferShow === true;
      const timeoutMs = options?.loadTimeout ?? AD_LOAD_TIMEOUT_MS;
      let settled = false;
      const done = (result: AdLoadResult) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timer);
        resolve(result);
      };

      const timer = setTimeout(() => {
        LogManager.error(TAG, `RewardVideo[${adId}] - load timeout after ${timeoutMs}ms`);
        done(AdLoadResult.failure(ErrCode.AD_TIMEOUT, 'RewardVideo ad load timeout'));
      }, timeoutMs);

      const adRequestParam: advertising.AdRequestParams = {
        adType: 7,
        adId: adId,
        oaid: OAIDStore.OAID
      };

      const adOption: advertising.AdOptions = {
        nonPersonalizedAd: 0,
        allowMobileTraffic: 0,
        tagForChildProtection: -1,
        tagForUnderAgeOfPromise: -1,
        adContentClassification: 'A'
      };

      const adLoaderListener: advertising.AdLoadListener = {
        onAdLoadFailure: (errorCode: number, errorMsg: string) => {
          if (AdSwitchManager.enableADToast && Ohos.debug()) {
            promptAction.showToast({ message: `ad render failed: ${errorCode} ${errorMsg}` });
          }
          LogManager.error(TAG, `RewardVideo - ${adId} load failed: ${errorCode}, ${errorMsg}`);
          done(AdLoadResult.failure(errorCode, errorMsg));
        },
        onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'RewardVideo - load success');
          const showGuardListener: OnAdListener = {
            onAdShow: () => {
              clearTimeout(timer);
            }
          };
          if (deferShow) {
            new RewardAdStatusHandler().registerPPSReceiver(
              (err) => {
                if (err) {
                  LogManager.error(TAG, `RewardVideo PPS error: ${err.message}`);
                }
              },
              showGuardListener,
              listener
            );
            done(AdLoadResult.success(undefined, ads[0]));
          } else {
            new RewardAdStatusHandler().registerPPSReceiver(
              (err) => {
                if (err) {
                  LogManager.error(TAG, `RewardVideo PPS error: ${err.message}`);
                }
              },
              showGuardListener,
              listener
            );
            advertising.showAd(ads[0], adOption, Ohos.getContext());
            done(AdLoadResult.success(undefined, ads[0]));
          }
        }
      };

      const load = new advertising.AdLoader(Ohos.getContext());
      load.loadAd(adRequestParam, adOption, adLoaderListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'RewardVideo - show');
    advertising.showAd(nativeHandle as advertising.Advertisement,
      { nonPersonalizedAd: 0, allowMobileTraffic: 0, tagForChildProtection: -1, tagForUnderAgeOfPromise: -1, adContentClassification: 'A' },
      Ohos.getContext());
  }
}

export class HwAdLoaders implements AdLoaders {
  readonly splash: SplashAdLoader = new HwSplashAdLoader();
  readonly interstitial: InterstitialAdLoader = new HwInterstitialAdLoader();
  readonly rewardVideo: RewardVideoAdLoader = new HwRewardVideoAdLoader();

  private static instance: HwAdLoaders | null = null;

  static getInstance(): HwAdLoaders {
    if (!HwAdLoaders.instance) {
      HwAdLoaders.instance = new HwAdLoaders();
    }
    return HwAdLoaders.instance;
  }
}
