import {
  AdSlotBuilder,
  CSJAdCreator,
  CSJAdSdk,
  CSJConstant,
  CSJFeedAd,
  CSJFeedAdListener,
  CSJNativeAd,
  CSJNativeExpressAd,
  CSJRewardAd,
  CSJSplashAd,
  CSJSplashAdCloseType,
  CSJSplashAdInteractionListener,
  CSJSplashAdLoadListener,
  CSJSplashAdLoadParam,
  FullAdLoadListener,
  NativeExpressAdListener,
  RewardAdLoadListener,
  SDKConfig,
  SDKConfigBuilder,
  StartResult
} from '@csj/openadsdk'
import { ArrayList } from '@kit.ArkTS'
import { PrefUtil } from '../util/PrefUtil'
import { AD } from '../config/AD'
import { BusinessError } from '@kit.BasicServicesKit'
import { NodeController, promptAction, uiObserver } from '@kit.ArkUI'
import { pageUpdate, pref, warmUpdate } from '../ability/AppAbility'

import { IAd } from './impl/IAd'
import ADUtil from '../util/ADUtil'

import '../components/SplashRequestPage'
import '../components/SplashShowPage'
import { OnVideoRewardListener } from './interface/OnVideoRewardListener'
import { RequestApplication } from '../application/RequestApplication'
import { DisplayUtils, EmitterUtils, Log } from '@zycore/common'
import { common, UIAbility } from '@kit.AbilityKit'
import { UIUtil } from '../util/UIUtil'
import { ErrCode } from '../config/ErrCode'

/*-----------------------------*/
// 应用ID 5624533   开屏  890219535    插屏广告961582024  Rewarded video 961582030    信息流大图首页：961582062   信息流大图其他页面：961582105
// let csjAppId = '5624533'
// let splashAdId = '890219535'
// let fullAdId = '961582024'
// let feedAdId = '961582105'
// let rewardAdId = '961582030'

// 测试账号(Android)
let csjAppId = '5339532'
let splashAdId = '887954953'
let fullAdId = '953997284'
let feedAdId = '952726904'
let rewardAdId = '949955401'

// 穿山甲测试账号
// let csjAppId = '5477447'
// let splashAdId = '888906709'
// let fullAdId = '955806169'
// let feedAdId = '955804505'
// let rewardAdId = '955804646'

/*-----------------------------*/

let screenWidth: number = UIUtil.getScreenWidthVp()
let screenHeight: number = UIUtil.getScreenHeightVp()
let adWidth: number = Math.round(screenWidth)
let adHeight: number = Math.round(screenHeight)

/**
 * 初始化穿山甲SDK
 * @param context
 * @param callback
 */
export async function initCsjSdk(context: common.UIAbilityContext): Promise<StartResult> {
  // 创建SDKConfig对象
  let adConfigBuilder = new SDKConfigBuilder()
  let config: SDKConfig = adConfigBuilder
    .appId(AD.CSJ_APPID)
    .appName('Cooking')
    .allowShowNotify(true)
    .debug(AD.isDEBUG())
    .build()
  // 初始化SDK
  CSJAdSdk.init(context, config) //context类型必须为UIAbility，否则可能存在展示异常场景
  // 启动SDK
  let result = CSJAdSdk.start()
  return result
}

/**
 * 广告监听帮助类
 */
class AdObserver {
  on(callback: (isTabHandoff?: boolean) => void) {

    // 应用热启动页面广告刷新通知
    EmitterUtils.onSubscribe<uiObserver.RouterPageInfo>(warmUpdate, () => {
      callback(false)
    })

    EmitterUtils.onSubscribe<uiObserver.RouterPageInfo>(pageUpdate, (info) => {
      if (info.state === uiObserver.RouterPageState.ON_PAGE_HIDE && info.name.startsWith('csj://')) {
        callback(false)
      }
    })

  }

  off() {
    EmitterUtils.unSubscribe(pageUpdate)
  }
}


// 广告类型
enum AdType {
  Splash,
  Screen,
  Info,
  InfoNative,
  Video
}

// 通用广告加载接口
interface AdLoader<T> {
  loadAd(adId: string, callback?: (ad: T | null, error?: BusinessError) => void, context?: Context | UIContext): void;
}

// 实现 AdLoader 接口的通用广告加载器
class AdLoaderImpl<T> implements AdLoader<T> {
  loadAd(adId: string, callback?: (ad: T | null, error?: BusinessError) => void, context?: Context | UIContext) {
    // TODO: 添加实际的广告加载逻辑
    if (callback) {
      callback(null, {
        code: -1,
        message: 'Not implemented'
      } as BusinessError)
    }
  }
}

// 不同广告类型的具体加载器
class CsjSplashAdLoader implements AdLoader<CsjSplashAd> {
  loadAd(adId: string, callback: (ad: CsjSplashAd | null, error?: BusinessError) => void, context: UIContext) {
    const splashAd = new CsjSplashAd();
    splashAd.loadAd(context, (e) => callback(splashAd, e));
  }
}

class CsjScreenAdLoader implements AdLoader<CsjScreenAd> {
  loadAd(adId: string, callback: (ad: CsjScreenAd | null, error?: BusinessError) => void, context: UIContext) {
    const screenAd = new CsjScreenAd()
    screenAd.loadAd((err) => {
      if (err) {
        callback(null, err)
      } else {
        callback(screenAd, undefined)
      }
    });
  }
}

class CsjInfoAdLoader implements AdLoader<CSJNativeExpressAd> {
  loadAd(adId: string, callback: (ad: CSJNativeExpressAd | null, error?: BusinessError) => void, context: UIContext) {
    const infoAd = new CsjInfoAd(adId)
    infoAd.loadAd(context, (ad: CSJNativeExpressAd) => callback(ad, undefined));
  }
}

class CsjInfoNativeAdLoader implements AdLoader<Array<CSJFeedAd>> {
  loadAd(adId: string, callback: (ad: Array<CSJFeedAd> | null, error?: BusinessError) => void, context: UIContext) {
    const infoAd = new CsjInfoNativeAd(adId)
    infoAd.loadAd(context, (ad: Array<CSJFeedAd> | null) => callback(ad, undefined));
  }
}

class CsjVideoAdLoader implements AdLoader<CsjVideoAd> {
  loadAd(adId: string, callback: (ad: CsjVideoAd | null, error?: BusinessError) => void) {
    const screenAd = new CsjVideoAd(adId)
    screenAd.loadAd({
      onVideoSuccess() {
        callback(null, undefined)
      },
      onVideoFailed(code, msg) {
        callback(null, {
          code: code,
          message: msg
        } as BusinessError)
      }
    })
  }
}

// 根据不同的广告类型返回具体加载器
function createAdLoader<T>(adType: AdType): AdLoader<T> {
  switch (adType) {
    case AdType.Splash:
      return new CsjSplashAdLoader() as AdLoader<T>
    case AdType.Screen:
      return new CsjScreenAdLoader() as AdLoader<T>
    case AdType.Info:
      return new CsjInfoAdLoader() as AdLoader<T>
    case AdType.Video:
      return new CsjVideoAdLoader() as AdLoader<T>
    case AdType.InfoNative:
      return new CsjInfoNativeAdLoader() as AdLoader<T>
    default:
      return new AdLoaderImpl<T>()
  }
}

export class CsjHelper {
  private loadAd<T>(
    adFactory: () => AdLoader<T>,
    adId: string,
    callback?: (ad: T | null, error?: BusinessError) => void,
    context?: Context | UIContext
  ) {
    PrefUtil.get(adId, true, pref).then(condition => {
      if (condition) {
        // 未点击不感兴趣的AdId正常加载
        const adLoader = adFactory()
        Log.info(`[uiObserver][uiContext] got info ${adId}: 正在加载`)
        adLoader.loadAd(adId, callback, context)
      }
    }).catch((e: BusinessError) => {
      Log.error('[uiObserver][uiContext] got info ${adId}: ' + e.message)
    })
  }

  loadSplashAd(context: UIContext, adId: string, callback: (ad: CsjSplashAd | null, error?: BusinessError) => void) {
    this.loadAd(() => createAdLoader<CsjSplashAd>(AdType.Splash), adId, callback, context);
  }

  loadScreenAd(adId: string, callback?: (ad: CsjScreenAd | null, error?: BusinessError) => void) {
    this.loadAd(() => createAdLoader<CsjScreenAd>(AdType.Screen), adId, callback);
  }

  loadInfoAd(context: UIContext, adId: string,
    callback: (ad: CSJNativeExpressAd | null, error?: BusinessError) => void) {
    this.loadAd(() => createAdLoader<CSJNativeExpressAd>(AdType.Info), adId, callback, context);
  }

  loadInfoNativeAd(context: UIContext, adId: string,
    callback: (ad: Array<CSJFeedAd> | null, error?: BusinessError) => void) {
    this.loadAd(() => createAdLoader<Array<CSJFeedAd>>(AdType.InfoNative), adId, callback, context);
  }

  loadVideoAd(adId: string, callback: (ad: CsjVideoAd | null, error?: BusinessError) => void) {
    this.loadAd(() => createAdLoader<CsjVideoAd>(AdType.Video), adId, callback);
  }


  // registerAdListener(adId: string, context: UIContext, callback: (ad: CSJNativeExpressAd | null) => void): void {
  //   const AD_IDS: ESObject = {
  //     HOME_AD: '961582062',
  //     FEED_AD: '961582105'
  //   }
  //   adObserver.on((isTabHandoff) => {
  //     Log.debug('[uiObserver][uiContext] got info ' + adId + ': ' + (isTabHandoff ? '切换到其他页面' : '返回首页'));
  //     if (isTabHandoff) {
  //       // 首页切换
  //       if (adId === AD_IDS.HOME_AD) {
  //         csjHelper.loadInfoAd(context, adId, (ad) => {
  //           Log.warn('[uiObserver][uiContext] got info ' + adId + ': ' + '重新加载广告')
  //           callback(ad)
  //         })
  //       }
  //     } else {
  //       // 信息流跳转重新展示
  //       if (adId === AD_IDS.HOME_AD) {
  //         csjHelper.loadInfoAd(context, adId, (ad) => {
  //           callback(ad)
  //         })
  //       } else if (adId === AD_IDS.FEED_AD) {
  //         csjHelper.loadInfoAd(context, adId, (ad) => {
  //           callback(ad)
  //         })
  //       }
  //     }
  //   })
  // }
  //
  //
  // unRegisterAdListener() {
  //   adObserver.off()
  // }
}

/**
 * 加载开屏广告
 */
class CsjSplashAd {
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()

  loadAd(context: UIContext, callback: (err?: BusinessError) => void) {
    // 初始化 CSJSplashAdInteractionListener
    const mSplashAdInteractionListener: CSJSplashAdInteractionListener = {
      onDidShow: () => {
        Log.info("开屏 - onDidShow")
      },

      onDidClose: (closeType: CSJSplashAdCloseType) => {
        Log.info(`开屏 - onDidClose 关闭原因：${JSON.stringify(closeType)}`)
        // AD.splashAdWindow?.destroyWindow(() => callback())
        setTimeout(() => {
          callback()
        }, 100)
      },

      onDidClick: () => {
        Log.info("开屏 - onDidClick")
      },

      onVideoDidPlayFinish: () => {
        Log.info("开屏 - onVideoDidPlayFinish")
      },

      onVideoDidPlayFail: () => {
        Log.info("开屏 - onVideoDidPlayFail")
      }
    }

    // 初始化 CSJSplashAdLoadListener
    const mLoadListener: CSJSplashAdLoadListener = {
      onAdLoaded: (splashAd: CSJSplashAd) => {
        Log.info("开屏 - onAdLoaded")
        try {
          splashAd.setInteractionListener(mSplashAdInteractionListener)
          splashAd.showSplashAd(AD.windowStage)
          // AD.windowStage.createSubWindow("splashAdWindow", (err, window) => {
          //   if (!window) {
          //     return
          //   }
          //   AD.splashAdWindow = window
          //   let localStorage = new LocalStorage()
          //   localStorage.setOrCreate('splashAd', splashAd)
          //   localStorage.setOrCreate('splashAdWindow', window)
          //   window.loadContentByName("SplashRequestPage", localStorage)
          //   window.showWindow()
          // })

        } catch (error) {
          Log.info(`开屏 - onAdLoaded 错误: ${error.message}`)
        }
      },

      onError: (code: number, message: string) => {
        Log.error(`开屏 - onError code: ${code} message: ${message}`)
        // ToastUtil.showShort(`开屏 - onError code: ${code} message: ${message}`)
        callback({
          code: code,
          message: message
        } as BusinessError)
      },

      onRenderSuccess: (splashAd: CSJSplashAd) => {
        Log.info("开屏 - onRenderSuccess")
      },

      onRenderFail: (code: number, message: string) => {
        Log.info("开屏 - onRenderFail")
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder()
      .setCodeId(AD.CSJ_SPLASH_ID)
      .setAcceptSize(adWidth, adHeight)
      .build()

    // 创建 CSJSplashAdLoadParam 并加载广告
    let param = new CSJSplashAdLoadParam(adSlot, mLoadListener, context)
    try {
      this.mAdCreator.loadSplashAd(param)
    } catch (error) {
      callback()
      Log.info(`开屏 - loadSplashAd 错误: ${error.message}`)
    }
  }
}

/**
 * 加载插屏广告
 */
class CsjScreenAd {
  /*插屏广告*/
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()

  loadAd(callback: (err?: BusinessError) => void) {
    // 初始化 FullAdLoadListener
    const mLoadListener: FullAdLoadListener = {
      onAdLoaded: (fullAd) => {
        Log.info(`插屏 - onAdLoaded`)
        callback()
        fullAd.setInteractionListener({
          onShow: () => {
            Log.info(`插屏 - onShow`)
          },
          onSkip: () => {
            Log.info(`插屏 - onSkip`)
          },
          onClick: () => {
            Log.info(`插屏 - onClick`)
          },
          onComplete: () => {
            Log.info(`插屏 - onComplete`)
          },
          onClose: () => {
            Log.info(`插屏 - onClose`)
          }
        })
        fullAd.showFullAd(AD.windowStage)
      },
      onAdCached: () => {
        Log.info(`插屏 - onAdCached`)
      },
      onError: (code: number, message: string) => {
        // ToastUtil.showToast(`广告加载出错了 \n code:${code}, message:${message}`)
        Log.error(`插屏 - onError code: ${code} message: ${message}`)
        callback({
          code: code,
          message: message
        } as BusinessError)
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder()
      .setCodeId(AD.CSJ_SCREEN_ID)
      .build()

    // 加载广告
    this.mAdCreator.loadFullAd(adSlot, mLoadListener)
  }
}

/**
 * 加载信息流广告
 */
class CsjInfoAd {
  private mAdId: string
  /*信息流广告*/
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()

  constructor(adId: string) {
    this.mAdId = adId
  }

  private setDislikeCallback(ad: CSJNativeExpressAd, adId?: string) {
    ad.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        Log.info(`信息流 - dislike......show`);
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        Log.warn(`[uiObserver][uiContext] got info ${adId}: false`)
        PrefUtil.put(adId, false, pref)
        ad.destroy()
        Log.info(`信息流 - dislike......onSelected: position=${position}, value:${value}, enforce=${enforceRemove}`);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        Log.info(`信息流 - dislike......onCancel`);
      }

    })
  }

  /**
   * 设置视频监听
   * @param ad
   */
  private setVideoListener(ad: CSJNativeExpressAd) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
      ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
      ad.setVideoAdListener({
        onVideoLoad: () => {
          Log.info(`信息流 - onVideoLoad......`);
        },
        /**
         * 视频广告加载失败（原生MediaPlayer内部提供的错误类型）
         * @param errorCode 错误类型：
         *
         */
        onVideoError: (errorCode: number, errorMsg: string) => {
          Log.error(`信息流 - onVideoError......errorCode=${errorCode}, errorMsg=${errorMsg}`);
        },

        /**
         * 视频广告播放
         *
         * @param ad
         */
        onVideoAdStartPlay: () => {
          Log.info(`信息流 - onVideoAdStartPlay......`);
        },

        /**
         * 视频广告暂停
         *
         * @param ad
         */
        onVideoAdPaused: () => {
          Log.info(`信息流 - onVideoAdPaused......`);
        },

        /**
         * 视频广告续播
         *
         * @param ad
         */
        onVideoAdContinuePlay: () => {
          Log.info(`信息流 - onVideoAdContinuePlay......`);
        },

        /**
         * 视频播放进度
         *
         * @param current
         * @param duration
         */
        onProgressUpdate: (current: number, duration: number) => {
          //Log.info(`信息流 - onProgressUpdate......current=${current}, duration=${duration}`);
        },

        /**
         * 视频广告播放完成
         *
         * @param ad
         */
        onVideoAdComplete: () => {
          Log.info(`信息流 - onVideoAdComplete......`);
        },

        /**
         * 点击重播(Draw)
         */
        onClickReplay: () => {

        }
      })
    }
  }

  loadAd(context: UIContext, callback: (ad: CSJNativeExpressAd) => void) {
    // 创建广告加载监听
    const expressLoadAdListener: NativeExpressAdListener = {
      /**
       * 加载失败的
       *
       * @param code
       * @param message
       */
      onError: (code: number, message: string) => {
        Log.error(`加载信息流${this.mAdId} 广告失败，code=${code}，message=${message}`);
      },

      /**
       * 广告加载成功的，接入方可以在这个中进行渲染
       *
       * @param ads 返回的广告列表
       */
      onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
        Log.info(`信息流 - onNativeExpressAdLoad......success`);
        if (ads && ads.length > 0) {
          ads.forEach((ad: CSJNativeExpressAd, idx: number) => {
            ad.setExpressInteractionListener({
              /**
               * 广告的点击
               * @param type 广告的交互类型
               */
              onAdClicked: (type: number) => {
                Log.info(`信息流 - onAdClicked......`);
              },

              /**
               * 广告的展示 每个广告仅一次
               * @param type 广告的交互类型
               */
              onAdShow: (type: number) => {
                Log.info(`信息流 - onAdShow......`);
              },

              /**
               * 模板渲染失败
               */
              onRenderFail: (code: number, msg: string) => {
                Log.info(`信息流 ${this.mAdId} - onRenderFail...code=${code}, msg=${msg}`);
              },

              /**
               * 模板渲染成功
               * @param width  返回view的宽 单位 vp
               * @param height 返回view的高 单位 vp
               */
              onRenderSuccess: (width: number, height: number) => {
                Log.info(`信息流 - onRenderSuccess......width=${width},height=${height}`);
                // 广告渲染成功后立即返回
                callback(ad);
              }
            });
            // 设置监听
            this.setVideoListener(ad);
            // 设置dislike
            this.setDislikeCallback(ad, this.mAdId);
            // 渲染广告
            ad.render(context);
          })
        }
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder()
      .setCodeId(this.mAdId)
      .setAcceptSize(adWidth, 0)
      .setAdCount(1)
      .build()

    // 加载广告
    this.mAdCreator.loadExpressFeedAd(adSlot, expressLoadAdListener)
  }
}

export class CsjInfoAds extends IAd<CSJNativeExpressAd> {
  public static TIMEOUT = 3600000

  constructor(ad: CSJNativeExpressAd) {
    super(ad)
  }

  public timeout(): number {
    return CsjInfoAds.TIMEOUT
  }

  public view(): NodeController | undefined {
    return this.mAd.getAdComponent()
  }

  protected bind(): void {
    this.bindAdListener()
  }

  public render(): void {
    this.bindDislikeCallback()
    this.mAd.render(RequestApplication.uiContext)
    ADUtil.logD('TAG', "信息流广告渲染成功")
  }

  public destroy(): void {
    this.mAd.destroy()
    this.onDestroy()
  }

  private bindAdListener() {
    this.mAd.setExpressInteractionListener({
      /**
       * 广告的点击
       * @param type 广告的交互类型
       */
      onAdClicked: (type: number) => {
        this.onClick()
      },

      /**
       * 广告的展示 每个广告仅一次
       * @param type 广告的交互类型
       */
      onAdShow: (type: number) => {
        this.onShow()
      },

      /**
       * 模板渲染失败
       */
      onRenderFail: (code: number, msg: string) => {
        this.onFail(code, msg)
      },

      /**
       * 模板渲染成功
       * @param width  返回view的宽 单位 vp
       * @param height 返回view的高 单位 vp
       */
      onRenderSuccess: (width: number, height: number) => {
        this.onRender()
      }
    });
  }

  private bindDislikeCallback() {
    this.mAd.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        Log.info(`信息流 - dislike......show`);
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        this.onClose()
        this.mAd.destroy()
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        Log.info(`信息流 - dislike......onCancel`);
      }

    })
  }
}

/**
 * 信息流原生广告
 */
export class CsjInfoNativeAd {
  private mAdId: string
  /*信息流广告*/
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private listArray: Array<CSJFeedAd> = new Array()
  public static csj_native_ad = "csj_info_native_ad"

  constructor(adId: string) {
    this.mAdId = adId
  }

  private setDislikeCallback(ad: CSJFeedAd, adId?: string) {

    ad.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        console.log("FeedNativeAdPage==dislike......show");
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        PrefUtil.put(adId, false, pref)
        EmitterUtils.post(CsjInfoNativeAd.csj_native_ad, adId)
        console.log("FeedNativeAdPage==dislike......onSelected:position=" + position + ",value:" + value + ",enforce=" +
          enforceRemove);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        console.log("FeedNativeAdPage==dislike......onCancel");
      }

    })
  }

  /**
   * 设置视频监听
   * @param ad
   */
  private setVideoListener(ad: CSJFeedAd) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
      ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
      ad.setVideoAdListener({
        onVideoLoad: () => {
          console.log("FeedNativeAdPage==onVideoLoad......");
        },
        /**
         * 视频广告加载失败
         * @param errorCode 错误类型：
         *
         */
        onVideoError: (errorCode: number, errorMsg: string) => {
          console.log("FeedNativeAdPage==onVideoError......errorCode=" + errorCode + ",errorMsg=" + errorMsg);
        },

        /**
         * 视频广告播放回调
         *
         * @param ad
         */
        onVideoAdStartPlay: () => {
          console.log("FeedNativeAdPage==onVideoAdStartPlay......");
        },

        /**
         * 视频广告暂停回调
         *
         * @param ad
         */
        onVideoAdPaused: () => {
          console.log("FeedNativeAdPage==onVideoAdPaused......");
        },

        /**
         * 视频广告续播
         *
         * @param ad
         */
        onVideoAdContinuePlay: () => {
          console.log("FeedNativeAdPage==onVideoAdContinuePlay......");
        },

        /**
         * 视频播放进度
         *
         * @param current
         * @param duration
         */
        onProgressUpdate: (current: number, duration: number) => {
          // console.log("FeedNativeAdPage==onProgressUpdate......current=" + current + ",duration=" + duration);
        },

        /**
         * 视频广告播放完成回调
         *
         * @param ad
         */
        onVideoAdComplete: () => {
          console.log("FeedNativeAdPage==onVideoAdComplete......");
        }
      })
    }
  }

  private setAdInteractionListener(ad: CSJFeedAd) {
    ad?.setAdInteractionListener({
      onAdClicked: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdClicked......");
      },

      /**
       * 创意点击事件
       * @param ad
       */
      onAdCreativeClick: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdCreativeClick......");
      },

      /**
       * show展示回调
       * @param ad
       */
      onAdShow: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdShow......");
      }
    })
  }

  loadAd(context: UIContext, callback: (ad: Array<CSJFeedAd> | null) => void) {
    /**
     * 广告加载监听器
     */
    const feedAdListener: CSJFeedAdListener = {
      onError: (code: number, message: string) => {
        console.log("FeedNativeAdPage==code=" + code + ",message-" + message);
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败: ${code} ${message}`
          })
        }
      },
      /**
       * 广告加载成功的回调，接入方可以在这个回调中进行渲染
       *
       * @param ads 返回的广告列表
       */
      onFeedAdLoad: (ads: ArrayList<CSJFeedAd>) => {
        console.log("FeedNativeAdPage==onFeedAdLoad......success");
        if (ads && ads.length > 0) {
          ads.forEach((ad: CSJFeedAd, idx: number) => {
            //【注意】
            //如果打开了支持模板样式开关 supportRenderControl()：
            //则需要给广告对象设置ExpressRenderListener监听，
            //然后调用广告对象的render()方法开始渲染，在渲染成功的回调中再更新广告数据
            ad.setExpressRenderListener({
              onRenderSuccess: (width: number, height: number, isExpress: boolean) => {
                console.log("FeedNativeAdPage==onRenderSuccess......ad=title:" + ad.getTitle());
                console.log("FeedNativeAdPage==onRenderSuccess......ad=description:" + ad.getDescription());
                console.log("FeedNativeAdPage==onRenderSuccess......ad=adLogo:" + ad.getAdLogo());
                this.listArray.push(ad)
                console.log("FeedNativeAdPage==onRenderSuccess......ad=imageMode:" + ad.getImageMode());
                callback(this.listArray)
              }
            });
            this.setAdInteractionListener(ad);
            this.setVideoListener(ad);
            this.setDislikeCallback(ad);
            //渲染广告
            ad.render(context)
          })
        }
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder().setCodeId(this.mAdId)
      .setAcceptSize(350, 200)
      .setAdCount(1)
      .setSupportRenderControl(true)
      .build();

    // 加载广告
    this.mAdCreator.loadFeedAd(adSlot, feedAdListener)
  }
}

/**
 * 加载激励视频广告
 */
class CsjVideoAd {
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private mAdId: string
  private isComplete: boolean = false

  constructor(adId: string) {
    this.mAdId = adId
  }

  loadAd(callback: OnVideoRewardListener) {
    // 初始化 RewardAdLoadListener
    const mLoadListener: RewardAdLoadListener = {
      onAdLoaded: (rewardAd: CSJRewardAd) => {
        Log.info(`激励视频 - onAdLoaded`)
        rewardAd.setInteractionListener({
          onShow: () => {
            // ToastUtil.showToast("onShow")
            Log.info(`激励视频 - onShow`)
          },
          onSkip: () => {
            Log.info(`激励视频 - onSkip`)
          },
          onClick: () => {
            Log.info(`激励视频 - onClick`)
          },
          onClose: () => {
            Log.info(`激励视频 - onClose`)
            if (this.isComplete) {
              callback.onVideoSuccess()
            } else {
              if (AD.isADJumpCheck()) {
                callback.onVideoFailed(
                  ErrCode.NO_FULL_VIDEO,
                  '未完整观看激励视频'
                )
              } else {
                callback.onVideoSuccess()
              }
            }

          },
          onComplete: () => {
            Log.info(`激励视频 - onComplete`)
            if (!this.isComplete) {
              this.isComplete = true;
            }
          },
          onRewardArrived: (isVerify, rewardType, extraInfo) => {
            // ToastUtil.showToast("onRewardArrived")
            Log.info(`激励视频 - onRewardArrived ${isVerify} ; ${rewardType} ; ${extraInfo}`)
            if (!this.isComplete) {
              this.isComplete = true;
            }
          }
        })
        rewardAd.setPlayAgainListener({
          onShow: (againCount) => {
            Log.info(`激励视频 - AgainCount ${againCount} onShow`)
          },
          onSkip: (againCount) => {
            Log.info(`激励视频 - AgainCount ${againCount} onSkip`)
          },
          onClick: (againCount) => {
            Log.info(`激励视频 - AgainCount ${againCount} onClick`)
          },
          onComplete: (againCount) => {
            Log.info(`激励视频 - AgainCount ${againCount} onComplete`)
          },
          onRewardArrived: (againCount, isVerify, rewardType, extraInfo) => {
            // ToastUtil.showToast("onRewardArrived")
            Log.info(`激励视频 - AgainCount ${againCount} onRewardArrived verify: ${isVerify} ; type: ${rewardType} ; extra: ${extraInfo}`)
          },
          getPlayAgainCondition: (nextCount) => {
            Log.info(`激励视频 - getPlayAgainCondition ${nextCount}`)
            return new Promise((resolve, reject) => {
              // 进行网络请求等
              let obj = new Object({
                "allow": nextCount <= 2,
                "name": "金币",
                "amount": nextCount
              })
              resolve(obj)
            })
          }
        })

        // 显示广告
        rewardAd.showRewardAd(AD.windowStage)
      },
      onAdCached: () => {
        Log.info(`激励视频 - onAdCached`)
      },
      onError: (code: number, message: string) => {
        // ToastUtil.showToast(`广告加载出错了 code:${code}, message:${message}`)
        Log.error(`激励视频 - onError code:${code}, message:${message}`)
        callback.onVideoFailed(code, message)
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder()
      .setCodeId(this.mAdId)//.setAdLoadType(adLoadType)
      //.setMediaExtra(mediaExtra)
      .setRewardAmount(1)
      .build()

    // 加载广告
    this.mAdCreator.loadRewardAd(adSlot, mLoadListener)

  }
}

const adObserver: AdObserver = new AdObserver()

export const csjHelper: CsjHelper = new CsjHelper()

