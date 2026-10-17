import {
  AdSlotBuilder,
  CSJAdCreator,
  CSJAdSdk,
  CSJRewardAd,
  CSJSplashAd,
  CSJSplashAdCloseType,
  CSJSplashAdInteractionListener,
  CSJSplashAdLoadListener,
  CSJSplashAdLoadParam,
  FullAdLoadListener,
  RewardAdLoadListener,
} from '@csj/openadsdk'
import { display } from '@kit.ArkUI'
import { Ohos } from '@zycore/common'
import { RequestApplication } from '../../application/RequestApplication';
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

const TAG = 'CsjAdLoader';

class CsjSplashAdLoader implements SplashAdLoader {
  private readonly adCreator: CSJAdCreator = CSJAdSdk.getAdCreator();

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

      let splashAdRef: CSJSplashAd | undefined;

      const interactionListener: CSJSplashAdInteractionListener = {
        onDidShow: () => {
          LogManager.info(TAG, 'Splash - onDidShow');
          listener?.onAdShow?.();
        },
        onDidClose: (closeType: CSJSplashAdCloseType) => {
          LogManager.info(TAG, `Splash - onDidClose: ${JSON.stringify(closeType)}`);
          listener?.onAdClose?.();
          listener?.onAdDestroy?.();
          splashAdRef = undefined;
        },
        onDidClick: () => {
          LogManager.info(TAG, 'Splash - onDidClick');
          listener?.onClick?.();
        },
        onVideoDidPlayFinish: () => {
          LogManager.info(TAG, 'Splash - onVideoDidPlayFinish');
        },
        onVideoDidPlayFail: () => {
          LogManager.info(TAG, 'Splash - onVideoDidPlayFail');
        }
      };

      const loadListener: CSJSplashAdLoadListener = {
        onAdLoaded: (splashAd: CSJSplashAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'Splash - onAdLoaded');
          splashAdRef = splashAd;
          try {
            splashAd.setInteractionListener(interactionListener);
            if (deferShow) {
              done(AdLoadResult.success(undefined, splashAd));
            } else {
              splashAd.showSplashAd(Ohos.getWindowStage());
              done(AdLoadResult.success(undefined, splashAd));
            }
          } catch (error) {
            LogManager.error(TAG, `Splash[${adId}] - show error`, error);
            splashAdRef = undefined;
            done(AdLoadResult.failure(ErrCode.AD_LOAD_FAILED, String(error)));
          }
        },
        onError: (code: number, message: string) => {
          LogManager.error(TAG, `Splash[${adId}] - onError: ${code}, ${message}`);
          splashAdRef = undefined;
          done(AdLoadResult.failure(code, message));
        },
        onRenderSuccess: (splashAd: CSJSplashAd) => {
          LogManager.info(TAG, 'Splash - onRenderSuccess');
          listener?.onAdRender?.();
        },
        onRenderFail: (code: number, message: string) => {
          LogManager.error(TAG, `Splash[${adId}] - onRenderFail: ${code}, ${message}`);
          splashAdRef = undefined;
          done(AdLoadResult.failure(code, message));
        }
      };

      const screen = display.getDefaultDisplaySync();
      const screenWidth = screen.width / screen.densityPixels;
      const screenHeight = screen.height / screen.densityPixels;

      const adSlot = new AdSlotBuilder()
        .setCodeId(adId)
        .setAcceptSize(screenWidth, screenHeight)
        .build();

      const param = new CSJSplashAdLoadParam(adSlot, loadListener, RequestApplication.uiContext);
      this.adCreator.loadSplashAd(param);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'Splash - show');
    (nativeHandle as CSJSplashAd).showSplashAd(Ohos.getWindowStage());
  }
}

class CsjInterstitialAdLoader implements InterstitialAdLoader {
  private readonly adCreator: CSJAdCreator = CSJAdSdk.getAdCreator();

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

      let fullAdRef: Object | undefined;

      const loadListener: FullAdLoadListener = {
        onAdLoaded: (fullAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, 'Interstitial - onAdLoaded');
          fullAdRef = fullAd;
          fullAd.setInteractionListener({
            onShow: () => {
              LogManager.info(TAG, 'Interstitial - onShow');
              listener?.onAdShow?.();
            },
            onSkip: () => {
              LogManager.info(TAG, 'Interstitial - onSkip');
              listener?.onAdClose?.();
              listener?.onAdDestroy?.();
              fullAdRef = undefined;
            },
            onClick: () => {
              LogManager.info(TAG, 'Interstitial - onClick');
              listener?.onClick?.();
            },
            onComplete: () => {
              LogManager.info(TAG, 'Interstitial - onComplete');
            },
            onClose: () => {
              LogManager.info(TAG, 'Interstitial - onClose');
              listener?.onAdClose?.();
              listener?.onAdDestroy?.();
              fullAdRef = undefined;
            }
          });
          if (deferShow) {
            done(AdLoadResult.success(undefined, fullAd));
          } else {
            fullAd.showFullAd(Ohos.getWindowStage());
            done(AdLoadResult.success(undefined, fullAd));
          }
        },
        onAdCached: () => {
          LogManager.info(TAG, 'Interstitial - onAdCached');
        },
        onError: (code: number, message: string) => {
          LogManager.error(TAG, `Interstitial[${adId}] - onError: ${code}, ${message}`);
          fullAdRef = undefined;
          done(AdLoadResult.failure(code, message));
        }
      };

      const adSlot = new AdSlotBuilder()
        .setCodeId(adId)
        .build();

      this.adCreator.loadFullAd(adSlot, loadListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'Interstitial - show');
    (nativeHandle as ESObject).showFullAd(Ohos.getWindowStage());
  }
}

class CsjRewardVideoAdLoader implements RewardVideoAdLoader {
  private readonly adCreator: CSJAdCreator = CSJAdSdk.getAdCreator();

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
      let rewardAdRef: CSJRewardAd | undefined;

      const loadListener: RewardAdLoadListener = {
        onAdLoaded: (rewardAd: CSJRewardAd) => {
          if (settled) {
            return;
          }
          LogManager.info(TAG, `RewardVideo - onAdLoaded`);
          rewardAdRef = rewardAd;

          rewardAd.setInteractionListener({
            onShow: () => {
              LogManager.info(TAG, `RewardVideo - onShow`);
              listener?.onVideoShow?.();
              clearTimeout(timer);
            },
            onSkip: () => {
              LogManager.info(TAG, `RewardVideo - onSkip`);
            },
            onClick: () => {
              LogManager.info(TAG, `RewardVideo - onClick`);
              listener?.onVideoClick?.();
            },
            onClose: () => {
              LogManager.info(TAG, `RewardVideo - onClose`);
              rewardAdRef = undefined;
              if (deferShow) {
                this.handleVideoClose(isComplete, listener, () => {});
              } else {
                this.handleVideoClose(isComplete, listener, done);
              }
            },
            onComplete: () => {
              LogManager.info(TAG, `RewardVideo - onComplete`);
              isComplete = true;
            },
            onRewardArrived: (isVerify, rewardType, extraInfo) => {
              LogManager.info(TAG, `RewardVideo - onRewardArrived: ${isVerify}, ${rewardType}, ${extraInfo}`);
              isComplete = true;
            }
          });

          rewardAd.setPlayAgainListener({
            onShow: (count: number) => LogManager.info(TAG, `RewardVideo - Again ${count} onShow`),
            onSkip: (count: number) => LogManager.info(TAG, `RewardVideo - Again ${count} onSkip`),
            onClick: (count: number) => LogManager.info(TAG, `RewardVideo - Again ${count} onClick`),
            onComplete: (count: number) => LogManager.info(TAG, `RewardVideo - Again ${count} onComplete`),
            onRewardArrived: (count, isVerify, rewardType, extraInfo) => {
              LogManager.info(TAG, `RewardVideo - Again ${count} onRewardArrived`);
            },
            getPlayAgainCondition: (nextCount: number) => {
              LogManager.info(TAG, `RewardVideo - getPlayAgainCondition ${nextCount}`);
              let obj = new Object({
                "allow": nextCount <= 2,
                "name": "coin",
                "amount": nextCount
              })
              return Promise.resolve(obj);
            }
          });

          if (deferShow) {
            done(AdLoadResult.success(undefined, rewardAd));
          } else {
            rewardAd.showRewardAd(Ohos.getWindowStage());
            done(AdLoadResult.success(undefined, rewardAd));
          }
        },
        onAdCached: () => {
          LogManager.info(TAG, `RewardVideo - onAdCached`);
        },
        onError: (code: number, message: string) => {
          LogManager.error(TAG, `RewardVideo[${adId}] - onError: ${code}, ${message}`);
          rewardAdRef = undefined;
          done(AdLoadResult.failure(code, message));
        }
      };

      const adSlot = new AdSlotBuilder()
        .setCodeId(adId)
        .setRewardAmount(1)
        .build();

      this.adCreator.loadRewardAd(adSlot, loadListener);
    });
  }

  show(nativeHandle: Object): void {
    LogManager.info(TAG, 'RewardVideo - show');
    (nativeHandle as CSJRewardAd).showRewardAd(Ohos.getWindowStage());
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

export class CsjAdLoaders implements AdLoaders {
  readonly splash: SplashAdLoader = new CsjSplashAdLoader();
  readonly interstitial: InterstitialAdLoader = new CsjInterstitialAdLoader();
  readonly rewardVideo: RewardVideoAdLoader = new CsjRewardVideoAdLoader();
  private static instance: CsjAdLoaders | null = null;

  static getInstance(): CsjAdLoaders {
    if (!CsjAdLoaders.instance) {
      CsjAdLoaders.instance = new CsjAdLoaders();
    }
    return CsjAdLoaders.instance;
  }
}
