import { init } from '@umeng/analytics';
import { AD } from '../config/AD';
import ADUtil from '../util/ADUtil';
import AdCacheHelper, { OnAdObtainCallback } from './AdCacheHelper';
import AdConfig, { AdType, PageType } from './ADConfig';
import { ADControl } from './ADControl';
import { csjHelper, initCsjSdk } from './CsjHelper';
import { IAd } from './impl/IAd';
import { OnVideoRewardListener } from './interface/OnVideoRewardListener';
import { PageInfo } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { HwInfoAd, HwLscrAd, HwVideoAd } from './HwAdHelper';
import { common } from '@kit.AbilityKit';
import { advertising } from '@kit.AdsKit';
import { initTxSdk, TxScreenAd, TxSplashAd, TxVideoAd } from './TxHelper';
import { RouteEventBus } from '../application/UnifiedRouteEvent';
import { RequestApplication } from '../application/RequestApplication';
import { BusinessError } from '@kit.BasicServicesKit';
import { requestOAIDTrackingConsentPermissions, verifyConfigAD } from '../../../../../Index';
import { NetConfig, NetUtil, requestAdOff, zyOff } from '@zycore/network';
import { StartHelper } from '../config/StartHelper';
import { Log, Ohos } from '@zycore/common';
import { getSdkParams, getV4It } from '../config/ADConfigBuilder';
import { ErrCode } from '../config/ErrCode';

const TAG = 'ADHelper';

export class ADHelper {
  private constructor() {
  }

  private static instance = new ADHelper();

  public static getInstance(): ADHelper {
    return ADHelper.instance;
  }

  private static isInit: boolean = false;
  private static isRevocationAuthorization = false
  // 广告配置
  private mADConfig: AdConfig | null = null;

  static init(successCallback: () => void) {
    if (ADHelper.isInit && ADHelper.isRevocationAuthorization) {
      // 撤消隐私授权
      ADHelper.isRevocationAuthorization = false
      successCallback()
      return
    }
    if (ADHelper.isInit) {
      Log.debug("SDK已经初始化过了~")
      return;
    }
    ADHelper.isInit = true;
    Log.debug("开始初始化")

    // 获取OAID
    requestOAIDTrackingConsentPermissions(Ohos.getContext())

    try {
      NetConfig.init({
        appId: AD.APPID,
        v: AD.VID,
        sid: AD.SID,
        it: getV4It(),
        sv: NetUtil.parseSV(getSdkParams())
      })
      Log.debug("网络初始化成功")

    } catch (err) {
      Log.error(`网络初始化错误：${err}`)
    }

    requestAdOff().then((off: zyOff | null) => {
      if (off) {
        AD.zyOff = off;

        if (AD.enableV4AD) {
          try {
            verifyConfigAD(off)
          } catch (e) {
            Log.error(`广告校验异常：${e}`);
          }
        }

        let ss = off.ss.split(',');

        ADUtil.logE("config", `广告展示：${ADHelper.getADModeV2(off)}`);
        ADUtil.logE("config", `下一个广告展示：${ADHelper.getNextAdPlatform()}`);
        // 广告开
        AD.isAdOpen = ADHelper.getADMode(off) != AD.OFF_CLOSE;
        AD.isHw = (ADHelper.getADMode(off) == AD.OFF_HW);
        AD.isTx = (ADHelper.getADMode(off) == AD.OFF_TX);
        AD.isCsj = (ADHelper.getADMode(off) == AD.OFF_CSJ);

        ADUtil.logD("config", `ss：${JSON.stringify(ss)}`);
        ADUtil.logD("config", `广告是否展示：${ADHelper.getADMode(off)}`);
        ADHelper.initSDK(Ohos.getContext(), successCallback);
      } else {
        successCallback()
      }

    }).catch(() => {
      successCallback()
    })


  }

  // 撤消隐私授权
  static revocationAuthorization() {
    if (!ADHelper.isRevocationAuthorization) {
      ADHelper.isRevocationAuthorization = true
    }
  }

  /**
   * 初始化SDK
   * @param context 上下文
   * @param initCallback 初始化回调
   */
  private static initSDK(context: common.UIAbilityContext, initCallback: () => void) {
    // 友盟初始化
    init();
    // 初始化各个平台
    const platformInitializers = new Map<number, (context: Context) => Promise<void>>([
      [AD.OFF_CSJ, (context: Context): Promise<void> => {
        return initCsjSdk(context as common.UIAbilityContext).then((result) => {
          ADUtil.logE("config", `穿山甲初始化：code: ${result.code} msg: ${result.msg}`);
          // 穿山甲初始化：0 success
        });
      }],
      [AD.OFF_TX, (context: Context): Promise<void> => {
        return initTxSdk(context as common.UIAbilityContext).then((result) => {
          ADUtil.logE("config", `腾讯初始化：code: ${result.code} msg: ${result.msg}`);
          // 腾讯初始化：0 success
        });
      }],
      [AD.OFF_HW, (context: Context): Promise<void> => {
        // 华为初始化（空Promise）
        return Promise.resolve();
      }],
    ]);

    const platforms = ADHelper.getAvailableAdPlatforms(AD.zyOff);
    const promises = platforms.map(platform => {
      const initializer = platformInitializers.get(platform);
      if (initializer) {
        return initializer(context);
      }
      return Promise.resolve();
    });

    Promise.all(promises).then(() => {
      // 所有并行初始化完成后，展示开屏
      SplashAdManager.getInstance().showSplashAd((isHw) => {
        if (isHw) {
          StartHelper.pushSplashAdPage()
        } else {
          initCallback()
        }
      });
    });
  }

  /**
   * 广告模式
   * @param off - zyOff配置对象
   * @returns 广告模式(0:关闭,1:穿山甲,2:腾讯,3:华为)
   */
  static getADMode(off: zyOff): number {
    if (AD.forceEnableAdChannel > 0) {
      if (AD.forceEnableAdChannel == AD.OFF_CSJ) {
        return AD.OFF_CSJ
      }
      if (AD.forceEnableAdChannel == AD.OFF_TX) {
        return AD.OFF_TX
      }
      if (AD.forceEnableAdChannel == AD.OFF_HW) {
        return AD.OFF_HW
      }
    }

    const ss: string[] = off.ss.split(',');
    const c: number = off.c;
    const h: number = off.h;
    const t: number = off.t;

    const modeMap: Map<string, number> = new Map([
      ['1', c === 1 ? AD.OFF_CSJ : AD.OFF_CLOSE],
      ['2', t === 1 ? AD.OFF_TX : AD.OFF_CLOSE],
      ['4', h === 1 ? AD.OFF_HW : AD.OFF_CLOSE],
    ]);

    for (let i = 0; i < ss.length; i++) {
      const currentMode = modeMap.get(ss[i]);
      if (currentMode && currentMode !== 0) {
        return currentMode;
      }
    }

    return AD.OFF_CLOSE;
  }

  /**
   * 获取当前可用的广告平台
   * @param off - zyOff配置对象
   * @returns 可用的广告平台数组，按优先级排序
   */
  static getAvailableAdPlatforms(off: zyOff): number[] {
    if (!off || !off.ss) {
      return [];
    }

    const ss: string[] = Array.from(new Set(off.ss.split(',').filter(p => p.trim() !== '')));
    const availablePlatforms: number[] = [];

    // 检查每个广告平台是否启用
    for (const platform of ss) {
      switch (platform) {
        case '1': // 穿山甲
          if (off.c === 1) {
            availablePlatforms.push(AD.OFF_CSJ);
          }
          break;
        case '2': // 腾讯
          if (off.t === 1) {
            availablePlatforms.push(AD.OFF_TX);
          }
          break;
        case '4': // 华为
          if (off.h === 1) {
            availablePlatforms.push(AD.OFF_HW);
          }
          break;
        default:
          Log.warn(`Unknown ad platform type: ${platform}`);
          break;
      }
    }

    if (AD.forceEnableAdChannel > 0) {
      if (AD.forceEnableAdChannel == AD.OFF_CSJ) {
        return [AD.OFF_CSJ]
      }
      if (AD.forceEnableAdChannel == AD.OFF_TX) {
        return [AD.OFF_TX]
      }
      if (AD.forceEnableAdChannel == AD.OFF_HW) {
        return [AD.OFF_HW]
      }
    }
    return availablePlatforms;
  }

  /**
   * 获取当前广告模式
   * @param off - zyOff配置对象
   * @returns 广告模式(0:关闭,1:穿山甲,2:腾讯,3/4:华为)
   */
  static getADModeV2(off: zyOff): number {
    const availablePlatforms = ADHelper.getAvailableAdPlatforms(off);
    return availablePlatforms.length > 0 ? availablePlatforms[0] : 0;
  }

  /**
   * 获取下一个可用的广告平台
   * @param off - zyOff配置对象
   * @returns 下一个可用的广告平台(0:无可用平台,1:穿山甲,2:腾讯,3/4:华为)
   */
  static getNextAdPlatform(): number {
    const off = AD.zyOff;
    const availablePlatforms = ADHelper.getAvailableAdPlatforms(off);
    ADUtil.logE("config", `所有可用广告平台：${JSON.stringify(availablePlatforms)}`);
    if (availablePlatforms.length <= 1) {
      return ADHelper.getADModeV2(off);
    }

    // 获取当前平台
    const currentMode = ADHelper.getADModeV2(off);
    ADUtil.logE("config", `当前广告平台：${currentMode}`);
    const index = availablePlatforms.indexOf(currentMode);

    // 计算下一个平台的索引
    if (index >= 0) {
      const nextIndex = (index + 1) % availablePlatforms.length;
      ADUtil.logE("config", `下一个广告平台：${availablePlatforms[nextIndex]}`);
      return availablePlatforms[nextIndex];
    }

    return availablePlatforms[0];
  }


  /**
   * 信息流广告
   * @param page
   * @param adId
   */
  public showInfoAD(page: PageInfo, adId: string, adType: AdType = AdType.INFO,
    callback?: (ad: IAd<ESObject>) => void) {
    let adConfig = this.mADConfig;
    if (adConfig === null) {
      adConfig = AdConfig.createBuilder().build();
    }
    adConfig.setADId((adType == AdType.LINFO) ? AD.CSJ_INFO_LEFT_ID : adId)
      .setAdType(adType)
      .setPageType(PageType.NORMAL);


    RouteEventBus.pageInfoCache.add(page);
    ADUtil.logE('zyAdCore_', `[${adConfig.getLinkADId()}] showInfoAd on.`, true);
    if (!ADControl.isAdShowNext(page, adConfig)) {
      ADUtil.logD(TAG, `[${adConfig.getLinkADId()}] showInfoAd off.`, true);
      return;
    }
    // 请求广告
    AdCacheHelper.getInstance().obtainAd(adConfig, page, new adObtainCallback(page, adConfig, callback));
  }

  public getAdInfoAdvertisement(unique: string, id: string, callback: (ads: Array<advertising.Advertisement>,
    adDisplayOptions: advertising.AdDisplayOptions) => void) {
    let ad = new HwInfoAd(unique, id);
    ad.loadAd(Ohos.getContext(), callback);
  }

  public showVideoAD(adId: string, callback: OnVideoRewardListener) {
    VideoAdManager.getInstance().showVideoAd(adId, callback)
  }

  public showScreenAD() {
    LscrAdManager.getInstance().showLscrAd("")
  }
}

// 开屏广告管理
export class SplashAdManager {
  private static instance: SplashAdManager | null = null;

  private constructor() {
  }

  public static getInstance(): SplashAdManager {
    if (!SplashAdManager.instance) {
      SplashAdManager.instance = new SplashAdManager();
    }
    return SplashAdManager.instance;
  }

  /**
   * 展示开屏广告
   * @param context - 上下文对象
   * @param callback - 广告展示完成回调
   */
  public showSplashAd(callback: (isHw: boolean) => void): void {
    if (!AD.isAdOpen) {
      Log.info('SplashAdManager: Ads are disabled');
      callback(false);
      return;
    }

    const currentMode = ADHelper.getADModeV2(AD.zyOff);
    Log.info(`SplashAdManager: Current ad mode is ${currentMode}`);

    switch (currentMode) {
      case AD.OFF_CSJ: // 穿山甲
        this.handlePlatformAd(AD.OFF_CSJ, callback);
        break;
      case AD.OFF_TX: // 腾讯
        this.handlePlatformAd(AD.OFF_TX, callback);
        break;
      case AD.OFF_HW: // 华为
        Log.info('SplashAdManager: Using Huawei ads');
        callback(true);
        break;
      default:
        Log.info('SplashAdManager: No valid ad platform found');
        callback(false);
    }
  }

  private handlePlatformAd(platform: number, callback: (isHw: boolean) => void): void {
    Log.info(`SplashAdManager: Handling platform ${platform} ad`);

    if (platform === AD.OFF_CSJ || platform === AD.OFF_TX) {
      this.handleAdChange(platform, (success) => {
        if (success) {
          Log.info(`SplashAdManager: Platform ${platform} ad loaded successfully`);
          callback(false);
        } else {
          Log.warn(`SplashAdManager: Failed to load platform ${platform} ad`);
          this.handleAdFallback(platform, callback);
        }
      });
    }
  }

  private handleAdFallback(currentPlatform: number, callback: (isHw: boolean) => void): void {
    const nextPlatform = ADHelper.getNextAdPlatform();
    Log.info(`SplashAdManager: Trying fallback to platform ${nextPlatform}`);

    if (nextPlatform === currentPlatform) {
      Log.warn('SplashAdManager: No alternative platform available');
      callback(false);
    } else if (nextPlatform === AD.OFF_HW) {
      Log.info('SplashAdManager: Falling back to Huawei ads');
      callback(true);
    } else {
      this.handleAdChange(nextPlatform, (success) => {
        Log.info(`SplashAdManager: Fallback to platform ${nextPlatform} ${success ? 'succeeded' : 'failed'}`);
        callback(false);
      });
    }
  }

  private handleAdChange(ad: number, callback: (success: boolean) => void): void {
    switch (ad) {
      case AD.OFF_CSJ: // 穿山甲
        csjHelper.loadSplashAd(RequestApplication.uiContext, AD.CSJ_SPLASH_ID, (ad, error) => {
          if (error) {
            callback(false);
            Log.error('Failed to load splash ad:', error.message);
          } else {
            Log.info('Splash ad loaded successfully');
            callback(true);
          }
        });
        break;
      case AD.OFF_TX: // 腾讯
        let ad = new TxSplashAd();
        ad.loadAd((success: boolean) => {
          if (success) {
            callback(true);
          } else {
            callback(false);
          }
        });
        break;
      case AD.OFF_HW: // 华为
      default:
        callback(true);
    }
  }
}

// 激励视频广告管理
class VideoAdManager {
  private static instance: VideoAdManager | null = null;
  private adRecord: Map<string, Map<string, number>> = new Map

  private constructor() {
  }

  public static getInstance(): VideoAdManager {
    if (!VideoAdManager.instance) {
      VideoAdManager.instance = new VideoAdManager();
    }
    return VideoAdManager.instance;
  }

  public showVideoAd(adId: string, callback: OnVideoRewardListener) {
    if (!AD.isAdOpen) {
      Log.info('SplashAdManager: Ads are disabled');
      callback.onVideoFailed(-1, "SplashAdManager: Ads are disabled")
      return;
    }
    let currentMode = ADHelper.getADModeV2(AD.zyOff)

    switch (currentMode) {
      case AD.OFF_CSJ:
        this.handlePlatformAd(AD.OFF_CSJ, adId, (err) => {
          if (!err) {
            callback.onVideoSuccess()
          } else {
            callback.onVideoFailed(err?.code ?? -1, err?.message ?? '失败')
          }
        });
        break
      case AD.OFF_TX:
        this.handlePlatformAd(AD.OFF_TX, adId, (err) => {
          if (!err) {
            callback.onVideoSuccess()
          } else {
            callback.onVideoFailed(err?.code ?? -1, err?.message ?? '失败')
          }
        })
        break
      case AD.OFF_HW:
        this.handlePlatformAd(AD.OFF_HW, adId, (err) => {
          if (!err) {
            callback.onVideoSuccess()
          } else {
            callback.onVideoFailed(err?.code ?? -1, err?.message ?? '失败')
          }
        })
        break
    }

  }

  private handlePlatformAd(platform: number, adId: string,
    callback: (err?: BusinessError) => void): void {
    Log.info(`VideoAdManager: Handling platform ${platform} ad`);
    this.handleAdChange(platform, adId, (err) => {
      if (!err) {
        Log.info(`VideoAdManager: Platform ${platform} ad loaded successfully`);
        callback();
      } else {
        this.handleAdFallback(platform, adId, err, callback);
      }
    });
  }

  private handleAdChange(ad: number, adId: string, callback: (err?: BusinessError) => void): void {
    switch (ad) {
      case AD.OFF_CSJ: // 穿山甲
        csjHelper.loadVideoAd(adId, (ad, e) => {
          if (e) {
            callback(e);
          } else {
            callback();
          }
        });
        break;
      case AD.OFF_TX: // 腾讯
        let ad = new TxVideoAd();
        ad.loadAd((err?: BusinessError) => {
          if (!err) {
            callback();
          } else {
            callback({
              code: err?.code,
              message: err?.message
            } as BusinessError);
          }
        });
        break;
      case AD.OFF_HW: // 华为
        new HwVideoAd(AD.HW_VIDEO_ID)
          .loadAd(Ohos.getContext(), callback);
        break
      default:
        callback();
    }
  }

  private handleAdFallback(currentPlatform: number, adId: string, error: BusinessError,
    callback: (err?: BusinessError) => void): void {
    const nextPlatform = ADHelper.getNextAdPlatform();
    Log.info(`VideoAdManager: Trying fallback to platform ${nextPlatform}`);

    if (nextPlatform === currentPlatform) {
      Log.warn('VideoAdManager: No alternative platform available');
      // 判断是否为成功
      this.handleAdFallToSuccess(currentPlatform, error, callback)
    } else {
      if (error.code == ErrCode.NO_FULL_VIDEO) {
        // 当为未完整观看时不走重试逻辑
        this.handleAdFallToSuccess(currentPlatform, error, callback)
      } else {
        // 重试
        this.handleAdChange(nextPlatform, adId, (success) => {
          Log.info(`VideoAdManager: Fallback to platform ${nextPlatform} ${success ? 'succeeded' : 'failed'}`);
          if (success) {
            callback();
          } else {
            this.handleAdFallback(nextPlatform, adId, error, callback);
          }
        });
      }

    }
  }

  private handleAdFallToSuccess(currentPlatform: number, error: BusinessError,
    callback: (err?: BusinessError) => void) {
    if (currentPlatform == AD.OFF_HW) {
      if (error.code == 21800003) { // 服务器无素材
        callback()
      } else {
        callback(error)
      }
    } else if (currentPlatform == AD.OFF_CSJ) {
      if (error.code == 20001) { // 服务器无素材
        callback()
      } else {
        callback(error)
      }
    } else {
      callback({
        code: -100,
        message: '出现错误'
      } as BusinessError)
    }
  }
}

// 插屏广告管理
class LscrAdManager {
  private static instance: LscrAdManager | null = null;

  private constructor() {
  }

  public static getInstance(): LscrAdManager {
    if (!LscrAdManager.instance) {
      LscrAdManager.instance = new LscrAdManager();
    }
    return LscrAdManager.instance;
  }

  public showLscrAd(adId: string) {
    if (!AD.isAdOpen) {
      Log.info('LscrAdManager: Ads are disabled');
      return;
    }
    let currentMode = ADHelper.getADModeV2(AD.zyOff)
    switch (currentMode) {
      case AD.OFF_CSJ:
        this.handlePlatformAd(AD.OFF_CSJ, (success: boolean) => {

        })
        break
      case AD.OFF_TX:
        this.handlePlatformAd(AD.OFF_TX, (success: boolean) => {

        })
        break
      case AD.OFF_HW:
        this.handlePlatformAd(AD.OFF_HW, (success: boolean) => {

        })
        break
    }
  }

  private handlePlatformAd(platform: number, callback: (succeed: boolean) => void): void {
    Log.info(`LscrAdManager: Handling platform ${platform} ad`);
    this.handleAdChange(platform, (success) => {
      if (success) {
        Log.info(`LscrAdManager: Platform ${platform} ad loaded successfully`);
        callback(false);
      } else {
        Log.warn(`LscrAdManager: Failed to load platform ${platform} ad`);
        this.handleAdFallback(platform, callback);
      }
    });

  }

  private handleAdFallback(currentPlatform: number, callback: (isHw: boolean) => void): void {
    const nextPlatform = ADHelper.getNextAdPlatform();
    Log.info(`LscrAdManager: Trying fallback to platform ${nextPlatform}`);

    if (nextPlatform === currentPlatform) {
      Log.warn('LscrAdManager: No alternative platform available');
      callback(false);
    } else if (nextPlatform === AD.OFF_HW) {
      Log.info('LscrAdManager: Falling back to Huawei ads');
      callback(true);
    } else {
      this.handleAdChange(nextPlatform, (success) => {
        Log.info(`LscrAdManager: Fallback to platform ${nextPlatform} ${success ? 'succeeded' : 'failed'}`);
        callback(false);
      });
    }
  }

  private handleAdChange(ad: number, callback: (success: boolean) => void): void {
    switch (ad) {
      case AD.OFF_CSJ: // 穿山甲
        csjHelper.loadScreenAd(AD.CSJ_SCREEN_ID, (ad, e) => {
          if (e) {
            callback(false);
          } else {
            callback(true);
          }
        });
        break;
      case AD.OFF_TX: // 腾讯
        let ad = new TxScreenAd();
        ad.loadAd(callback);
        break;
      case AD.OFF_HW: // 华为
        let lscr = new HwLscrAd(AD.HW_SCREEN_ID);
        lscr.loadAd(getContext(this) as common.UIAbilityContext, callback);
        break
      default:
        callback(true);
    }
  }
}

/**
 * 应用热启动
 */
export function warmStart() {
  Log.info('开始进入热启动页面')
  StartHelper.pushSplashAdPage()
    .catch((err: BusinessError) => {
      Log.debug(JSON.stringify(err))
    })
}

class adObtainCallback extends OnAdObtainCallback {
  private callback?: (ad: IAd<ESObject>) => void;
  private adConfig: AdConfig;
  private page: PageInfo;
  private mIAd: IAd<ESObject> | undefined;

  constructor(page: PageInfo, adConfig: AdConfig, callback?: (ad: IAd<ESObject>) => void) {
    super();
    this.page = page;
    this.adConfig = adConfig;
    this.callback = callback;
  }

  public onAdObtained(ad: IAd<ESObject>): void {
    ADUtil.logD(TAG, "startRequestAd obtainAd-onAdObtained ");
    this.mIAd = ad;
    // if (this.mIAd === undefined || !this.mIAd.bindAd(this.page, this.adConfig)) {
    //   //重新加载广告
    //   return
    // }
    if (this.mIAd) {
      this.mIAd.bindAd(this.page, this.adConfig);

      if (this.callback) {
        this.callback(ad);
      } else {
        //TODO 需要存储这个ad
      }
    }

  }

  public onAdFailed(code: number, err: string): void {
    ADUtil.logE(TAG, "startRequestAd obtainAd-onAdFailed " + code + " " + err);
  }
}