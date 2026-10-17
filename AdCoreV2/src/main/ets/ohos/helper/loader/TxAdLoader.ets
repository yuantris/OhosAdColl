import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTError,
  GDTInteractionListener,
  GDTInterstitialAd,
  GDTRewardAd,
  GDTSplashAd,
  GDTVideoStateListener
} from '@gdt/gdt-union-sdk';
import { Ohos } from '@zycore/common';
import { OnAdListener } from '../../interface/OnAdListener';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { ErrCode } from '../const/ErrCode';
import { AdSwitchManager } from '../core/AdSwitchManager';
import { LogManager } from '../logger/LogManager';
import {
  AdLoaders,
  AdLoadOptions,
  AdLoadResult,
  InterstitialAdLoader,
  RewardVideoAdLoader,
  SplashAdLoader,
  AD_LOAD_TIMEOUT_MS
} from './AdLoaderTypes';

const TAG = 'TxAdLoader';

class TxSplashAdLoader implements SplashAdLoader {
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

      let splashAd: GDTSplashAd | undefined;

      const interactionListener: GDTInteractionListener = {
        onAdExposure: () => {
          LogManager.info(TAG, 'Splash - onAdExposure');
          listener?.onAdShow?.();
        },
        onAdClick: () => {
          LogManager.info(TAG, 'Splash - onAdClick');
          listener?.onClick?.();
        },
        onAdClose: () => {
          LogManager.info(TAG, 'Splash - onAdClose');
          setTimeout(() => {
            listener?.onAdClose?.();
            splashAd = undefined;
          });
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `Splash[${adId}] - interaction error, code=${err.code}, msg=${err.message}`, err);
        }
      };

      const adLoadListener: GDTAdLoadListener<GDTSplashAd> = {
        onAdLoad: (ad: GDTSplashAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'Splash - onAdLoad');
          splashAd = ad;
          splashAd?.setInteractionListener(interactionListener);
          listener?.onAdRender?.();
          if (deferShow) {
            done(AdLoadResult.success(undefined, ad));
          } else {
            splashAd?.show(Ohos.getWindowStage());
            done(AdLoadResult.success(undefined, ad));
          }
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `Splash[${adId}] - load error, code=${err.code}, msg=${err.message}`);
          splashAd = undefined;
          done(AdLoadResult.failure(err.code, err.message));
        }
      };

      const config: GDTAdLoadConfig = { posId: adId };
      GDTAdSDK.getAdLoader().loadSplashAd(config, adLoadListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'Splash - show');
    (nativeHandle as GDTSplashAd).show(Ohos.getWindowStage());
  }
}

class TxInterstitialAdLoader implements InterstitialAdLoader {
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

      let interstitialAd: GDTInterstitialAd | undefined;

      const interactionListener: GDTInteractionListener = {
        onAdExposure: () => {
          LogManager.info(TAG, 'Interstitial - onAdExposure');
          listener?.onAdShow?.();
        },
        onAdClick: () => {
          LogManager.info(TAG, 'Interstitial - onAdClick');
          listener?.onClick?.();
        },
        onAdClose: () => {
          LogManager.info(TAG, 'Interstitial - onAdClose');
          listener?.onAdClose?.();
          interstitialAd = undefined;
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `Interstitial[${adId}] - interaction error, code=${err.code}, msg=${err.message}`);
        }
      };

      const videoStateListener: GDTVideoStateListener = {
        onVideoReady: () => LogManager.info(TAG, 'onVideoReady'),
        onVideoStart: () => LogManager.info(TAG, 'onVideoStart'),
        onVideoPause: () => LogManager.info(TAG, 'onVideoPause'),
        onVideoResume: () => LogManager.info(TAG, 'onVideoResume'),
        onVideoComplete: () => LogManager.info(TAG, 'onVideoComplete'),
        onVideoError: (err: GDTError) => LogManager.error(TAG, `onVideoError: code=${err.code}, msg=${err.message}`)
      };

      const adLoadListener: GDTAdLoadListener<GDTInterstitialAd> = {
        onAdLoad: (ad: GDTInterstitialAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'Interstitial - onAdLoad');
          interstitialAd = ad;
          interstitialAd.setInteractionListener(interactionListener);
          interstitialAd.setVideoStateListener(videoStateListener);
          interstitialAd.setVideoOptions({ autoPlayMuted: true });
          listener?.onAdRender?.();
          if (deferShow) {
            done(AdLoadResult.success(undefined, ad));
          } else {
            interstitialAd.show(Ohos.getWindowStage());
            done(AdLoadResult.success());
          }
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `Interstitial[${adId}] - load error, code=${err.code}, msg=${err.message}`);
          interstitialAd = undefined;
          done(AdLoadResult.failure(err.code, err.message));
        }
      };

      const config: GDTAdLoadConfig = { posId: adId };
      GDTAdSDK.getAdLoader().loadInterstitialAd(config, adLoadListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'Interstitial - show');
    (nativeHandle as GDTInterstitialAd).show(Ohos.getWindowStage());
  }
}

class TxRewardVideoAdLoader implements RewardVideoAdLoader {
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

      let isComplete = false;
      let rewardAd: GDTRewardAd | undefined;

      const interactionListener: GDTInteractionListener = {
        onAdExposure: () => {
          LogManager.info(TAG, 'RewardVideo - onAdExposure');
          listener?.onVideoShow?.();
          clearTimeout(timer);
        },
        onAdClick: () => {
          LogManager.info(TAG, 'RewardVideo - onAdClick');
          listener?.onVideoClick?.();
        },
        onAdClose: () => {
          LogManager.info(TAG, 'RewardVideo - onAdClose');
          rewardAd = undefined;
          this.handleVideoClose(isComplete, listener, () => {});
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `RewardVideo[${adId}] - interaction error, code=${err.code}, msg=${err.message}`);
          rewardAd = undefined;
          if (!deferShow) {
            done(AdLoadResult.failure(err.code, err.message));
          }
        },
        onReward: (map: Map<string, string>) => {
          LogManager.info(TAG, `onReward: ${JSON.stringify(map)}`);
          isComplete = true;
        }
      };

      const videoStateListener: GDTVideoStateListener = {
        onVideoReady: () => LogManager.info(TAG, 'GDTVideoReady'),
        onVideoStart: () => LogManager.info(TAG, 'GDTVideoStart'),
        onVideoPause: () => LogManager.info(TAG, 'GDTVideoPause'),
        onVideoResume: () => LogManager.info(TAG, 'GDTVideoResume'),
        onVideoComplete: () => LogManager.info(TAG, 'GDTVideoComplete'),
        onVideoError: (err: GDTError) => LogManager.error(TAG, `GDTVideoError: code=${err.code}, msg=${err.message}`)
      };

      const adLoadListener: GDTAdLoadListener<GDTRewardAd> = {
        onAdLoad: (ad: GDTRewardAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'RewardVideo - onAdLoad');
          rewardAd = ad;
          rewardAd.setInteractionListener(interactionListener);
          rewardAd.setVideoStateListener(videoStateListener);
          rewardAd.setVideoOptions({ autoPlayMuted: true });
          if (deferShow) {
            done(AdLoadResult.success(undefined, ad));
          } else {
            rewardAd.show(Ohos.getWindowStage());
            done(AdLoadResult.success(undefined, ad));
          }
        },
        onError: (err: GDTError) => {
          LogManager.error(TAG, `RewardVideo[${adId}] - load error, code=${err.code}, msg=${err.message}`);
          rewardAd = undefined;
          done(AdLoadResult.failure(err.code, err.message));
        }
      };

      const config: GDTAdLoadConfig = { posId: adId };
      GDTAdSDK.getAdLoader().loadRewardAd(config, adLoadListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'RewardVideo - show');
    (nativeHandle as GDTRewardAd).show(Ohos.getWindowStage());
  }

  private handleVideoClose(
    isComplete: boolean,
    listener: OnVideoRewardListener | undefined,
    done: (result: AdLoadResult) => void
  ): void {
    if (isComplete) {
      listener?.onVideoComplete?.();
      done(AdLoadResult.success());
    } else if (AdSwitchManager.isADJumpCheck()) {
      listener?.onVideoError?.(ErrCode.NO_FULL_VIDEO, 'incomplete reward video');
      done(AdLoadResult.failure(ErrCode.NO_FULL_VIDEO, 'incomplete reward video'));
    } else {
      listener?.onVideoComplete?.();
      done(AdLoadResult.success());
    }
  }
}

export class TxAdLoaders implements AdLoaders {
  readonly splash: SplashAdLoader = new TxSplashAdLoader();
  readonly interstitial: InterstitialAdLoader = new TxInterstitialAdLoader();
  readonly rewardVideo: RewardVideoAdLoader = new TxRewardVideoAdLoader();
  private static instance: TxAdLoaders | null = null;

  static getInstance(): TxAdLoaders {
    if (!TxAdLoaders.instance) {
      TxAdLoaders.instance = new TxAdLoaders();
    }
    return TxAdLoaders.instance;
  }
}
