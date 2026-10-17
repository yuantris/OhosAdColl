import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTAdSDKStartResult,
  GDTAdSize,
  GDTError,
  GDTInteractionListener,
  GDTInterstitialAd,
  GDTMultiAdLoadListener,
  GDTNativeAd,
  GDTRewardAd,
  GDTSplashAd,
  GDTVideoStateListener
} from '@gdt/gdt-union-sdk';
import { AD, RequestApplication } from '../../../../../Index';
import { common } from '@kit.AbilityKit';
import { IAd } from './impl/IAd';
import { NodeController, promptAction } from '@kit.ArkUI';
import { UIUtil } from '../util/UIUtil';
import { EmitterUtils, Log } from '@zycore/common';
import { BusinessError } from '@kit.BasicServicesKit';
import { ErrCode } from '../config/ErrCode';

/**
 * 初始化穿山甲SDK
 * @param context
 * @param callback
 */
export async function initTxSdk(context: common.UIAbilityContext): Promise<GDTAdSDKStartResult> {
  GDTAdSDK.init(context, {
    appId: AD.TX_APP_ID,
  })
  // 调用init后尽快调用start,否则可能影响广告填充，造成收入下降
  return GDTAdSDK.start()
}

export class TxSplashAd {
  ad?: GDTSplashAd;
  callback?: (success: boolean) => void

  loadAd(callback: (success: boolean) => void) {
    this.callback = callback
    const adLoadListener: GDTAdLoadListener<GDTSplashAd> = {
      onAdLoad: (ad: GDTSplashAd): void => {
        Log.debug(`TxSplashAd----onAdLoad`)
        this.ad = ad;
        this.ad?.setInteractionListener(interactionListener);
        // this.ad?.setBackground(new CustomNodeController(wrapBuilder(BackgroundBuilder)));
        this.ad?.show(AD.windowStage)
      },
      onError: (err: GDTError): void => {
        Log.error(`TxSplashAd----广告加载失败${JSON.stringify(err)}`)
        this.callback && this.callback(false)
      }
    };
    const interactionListener: GDTInteractionListener = {
      onAdExposure: (): void => {
        Log.debug(`TxSplashAd----onAdExposure`)
      },
      onAdClick: (): void => {
        Log.debug(`TxSplashAd----onAdClick`)
      },
      onAdClose: (): void => {
        Log.debug(`TxSplashAd----onAdClose`)
        this.callback && this.callback(true)
      },
      onError: (err: GDTError): void => {
        Log.error(`TxSplashAd----广告出现错误: ${err.code}, ${err.message}`)
      }
    };
    const config: GDTAdLoadConfig = {
      posId: AD.TX_SPLASH_DEFAULT_POS_ID,
    };
    GDTAdSDK.getAdLoader().loadSplashAd(config, adLoadListener);
  }
}

export class TxScreenAd {
  ad?: GDTInterstitialAd;
  callback?: (success: boolean) => void
  adLoadListener: GDTAdLoadListener<GDTInterstitialAd> = {
    onAdLoad: (ad: GDTInterstitialAd): void => {
      Log.info(`onAdLoad`);
      this.ad = ad;
      this.ad.setInteractionListener(this.interactionListener);
      this.ad.setVideoStateListener(this.videoStateListener);
      this.ad.setVideoOptions({ autoPlayMuted: true });
      this.ad.show(AD.windowStage);
      this.callback?.(true)
    },
    onError: (err: GDTError): void => {
      Log.error(`onError: ${err.code}, ${err.message}`)
      this.callback?.(false)
    }
  };
  interactionListener: GDTInteractionListener = {
    onAdExposure: (): void => {
      Log.info(`onAdExposure`);
    },
    onAdClick: (): void => {
      Log.info(`onAdClick`);
    },
    onAdClose: (): void => {
      Log.info(`onAdClose`);
    },
    onError: (err: GDTError): void => {
      if (AD.enableADToast && AD.isDEBUG()) {
        promptAction.showToast({
          message: `广告出现错误: ${err.code}, ${err.message}`
        })
      }

      Log.error(`onError: ${err.code}, ${err.message}`);
    },
  };
  videoStateListener: GDTVideoStateListener = {
    onVideoReady: (): void => {
      Log.info(`onVideoReady`);
    },
    onVideoStart: (): void => {
      Log.info(`onVideoStart`);
    },
    onVideoPause: (): void => {
      Log.info(`onVideoPause`);
    },
    onVideoResume: (): void => {
      Log.info(`onVideoResume`);
    },
    onVideoComplete: (): void => {
      Log.info(`onVideoComplete`);
    },
    onVideoError: (err: GDTError): void => {
      Log.error(`onVideoError: ${err.code}, ${err.message}`);
    }
  };

  loadAd(callback: (success: boolean) => void) {
    this.callback = callback
    const config: GDTAdLoadConfig = {
      posId: AD.TX_INTERSTITIAL_DEFAULT_POS_ID
    };
    GDTAdSDK.getAdLoader().loadInterstitialAd(config, this.adLoadListener);
  }
}

export class TxVideoAd {
  private isComplete: boolean = false
  ad?: GDTRewardAd;
  callback?: (err?: BusinessError) => void
  adLoadListener: GDTAdLoadListener<GDTRewardAd> = {
    onAdLoad: (ad: GDTRewardAd): void => {
      Log.info(`onAdLoad`);
      this.ad = ad;
      this.ad.setInteractionListener(this.interactionListener);
      this.ad.setVideoStateListener(this.videoStateListener);
      this.ad.setVideoOptions({ autoPlayMuted: true });
      this.ad.show(AD.windowStage);
    },
    onError: (err: GDTError): void => {
      Log.error(`GDTRewardAd onError: ${err.code}, ${err.message}`)
      this.callback && this.callback({
        code: err.code,
        message: err.message
      } as BusinessError)
    }
  };
  interactionListener: GDTInteractionListener = {
    onAdExposure: (): void => {
      Log.info(`onAdExposure`);
    },
    onAdClick: (): void => {
      Log.info(`onAdClick`);
    },
    onAdClose: (): void => {
      Log.info(`onAdClose`);
      if (this.isComplete) {
        this.callback && this.callback()
      } else {
        if (AD.isADJumpCheck()) {
          this.callback && this.callback({
            code: ErrCode.NO_FULL_VIDEO,
            message: '未完整观看激励视频'
          } as BusinessError)
        } else {
          this.callback && this.callback()
        }
      }
    },
    onError: (err: GDTError): void => {
      Log.error(`onError: ${err.code}, ${err.message}`);
      this.callback && this.callback({
        code: err.code,
        message: err.message
      } as BusinessError)
    },
    onReward: (map: Map<string, string>): void => {
      Log.info(`onReward: ${JSON.stringify(map)}`);
      if (!this.isComplete) {
        this.isComplete = true;
      }
    },
  };
  videoStateListener: GDTVideoStateListener = {
    onVideoReady: (): void => {
      Log.info(`onVideoReady`);
    },
    onVideoStart: (): void => {
      Log.info(`onVideoStart`);
    },
    onVideoPause: (): void => {
      Log.info(`onVideoPause`);
    },
    onVideoResume: (): void => {
      Log.info(`onVideoResume`);
    },
    onVideoComplete: (): void => {
      Log.info(`onVideoComplete`);
    },
    onVideoError: (err: GDTError): void => {
      Log.error(`onVideoError: ${err.code}, ${err.message}`);
    }
  };

  loadAd(callback: (err?: BusinessError) => void) {
    this.callback = callback
    const config: GDTAdLoadConfig = {
      posId: AD.TX_REWARD_DEFAULT_POS_ID
    };
    // 每次广告请求后，都清空token
    GDTAdSDK.getAdLoader().loadRewardAd(config, this.adLoadListener);
  }
}

export class TxInfoAd {
  ad?: GDTNativeAd;
  adViewCallback?: (adView: NodeController | undefined) => void
  adLoadListener: GDTMultiAdLoadListener<GDTNativeAd> = {
    onAdLoad: (ads: Array<GDTNativeAd>): void => {
      Log.info(`onAdLoad`);
      this.ad = ads[0];
      this.ad.setVideoOptions({ autoPlayMuted: true });
      this.bindListener(this.ad);
      // 调用 render 方法前需要 setRenderListener，render success 后可以展示
      this.ad.render(AD.windowStage, RequestApplication.uiContext);
    },
    onError: (err: GDTError): void => {
      this.adViewCallback?.(undefined)
      if (AD.enableADToast && AD.isDEBUG()) {
        promptAction.showToast({
          message: `广告加载失败${JSON.stringify(err)}`
        })
      }
    }
  }

  public loadAd(id: string, adViewCallback: (adView: NodeController | undefined) => void) {
    this.adViewCallback = adViewCallback
    const config: GDTAdLoadConfig = {
      posId: id,
      adSize: new GDTAdSize(UIUtil.getScreenWidthVp(), GDTAdSize.AUTO_HEIGHT)
    };
    GDTAdSDK.getAdLoader().loadNativeAd(config, this.adLoadListener)
  }

  private bindListener(ad: GDTNativeAd) {
    ad.setRenderListener({
      onRenderSuccess: (): void => {
        this.adViewCallback?.(ad.getAdComponent())
        Log.debug(`onRenderSuccess`)
      },
      onRenderFail: (err: GDTError): void => {
        this.adViewCallback?.(undefined)
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败${JSON.stringify(err)}`
          })
        }
      }
    });
    ad.setInteractionListener({
      onAdExposure: (): void => {
        Log.info(`onAdExposure`);
      },
      onAdClick: (): void => {
        Log.info(`onAdClick`);
      },
      onAdClose: (): void => {
        Log.info(`onAdClose`);
        EmitterUtils.post<string>(TxInfoAds.CLOSE, "1")
        this.ad?.destroy();
      },
      onError: (err: GDTError): void => {
        Log.error(`onError: ${err.code}, ${err.message}`);
      }
    });
    ad.setVideoStateListener({
      onVideoReady: (): void => {
        Log.info(`onVideoReady`);
      },
      onVideoStart: (): void => {
        Log.info(`onVideoStart`);
      },
      onVideoPause: (): void => {
        Log.info(`onVideoPause`);
      },
      onVideoResume: (): void => {
        Log.info(`onVideoResume`);
      },
      onVideoComplete: (): void => {
        Log.info(`onVideoComplete`);
      },
      onVideoError: (err: GDTError): void => {
        Log.error(`onVideoError: ${err.code}, ${err.message}`);
      }
    });
  }
}

export class TxInfoAds extends IAd<GDTNativeAd> {
  public static TIMEOUT = 3600000
  public static CLOSE = "TxInfoAds_Close"

  public timeout(): number {
    return TxInfoAds.TIMEOUT
  }

  public view(): NodeController | undefined {
    return this.mAd.getAdComponent()
  }

  protected bind(): void {
    this.bindAdListener()
  }

  public render(): void {
    this.mAd.setVideoOptions({ autoPlayMuted: true });
    this.bindRenderListener()
    this.mAd.render(AD.windowStage, RequestApplication.uiContext)
  }

  public destroy(): void {
    this.mAd.destroy()
    this.onDestroy()
  }

  private bindAdListener() {
    this.mAd.setInteractionListener({
      onAdExposure: (): void => {
        Log.info(`onAdExposure`);
      },
      onAdClick: (): void => {
        Log.info(`onAdClick`);
      },
      onAdClose: (): void => {
        Log.info(`onAdClose`);
        EmitterUtils.post<string>(TxInfoAds.CLOSE, "1")
        this.onClose()
        this.mAd.destroy()
      },
      onError: (err: GDTError): void => {
        Log.error(`onError: ${err.code}, ${err.message}`);
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告出现错误: ${err.code}, ${err.message}`
          })
        }
      }
    });

    this.mAd.setVideoStateListener({
      onVideoReady: (): void => {
        Log.info(`onVideoReady`);
      },
      onVideoStart: (): void => {
        Log.info(`onVideoStart`);
      },
      onVideoPause: (): void => {
        Log.info(`onVideoPause`);
      },
      onVideoResume: (): void => {
        Log.info(`onVideoResume`);
      },
      onVideoComplete: (): void => {
        Log.info(`onVideoComplete`);
      },
      onVideoError: (err: GDTError): void => {
        Log.error(`onVideoError: ${err.code}, ${err.message}`);
      }
    });
  }

  private bindRenderListener() {
    this.mAd.setRenderListener({
      onRenderSuccess: (): void => {
        // if (this.loadAndShow) {
        //   this.showAd();
        // }
      },
      onRenderFail: (err: GDTError): void => {
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败${JSON.stringify(err)}`
          })
        }
      }
    });
  }
}
