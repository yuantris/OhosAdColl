import { advertising } from '@kit.AdsKit'
import { common } from '@kit.AbilityKit'
import { InterstitialAdStatusHandler } from './handler/InterstitialAdStatusHandler'
import { RewardAdStatusHandler } from './handler/RewardAdStatusHandler'
import { AD } from '../config/AD'
import { promptAction } from '@kit.ArkUI'
import { Log } from '@zycore/common'
import { BusinessError } from '@kit.BasicServicesKit'


export class HwSplashAd {
  private adDisplayOptions: advertising.AdDisplayOptions;
  private adOptions: advertising.AdOptions;
  private splashAdReqParams: advertising.AdRequestParams;

  constructor(id: string) {
    // 广告展示参数
    this.adDisplayOptions = {
      // 是否静音，默认不静音
      mute: true
    }

    // 广告配置
    this.adOptions = {
      // 是否允许流量下载0：不允许，1：允许，不设置以广告主设置为准
      allowMobileTraffic: 0,
      // 是否希望根据 COPPA 的规定将您的内容视为面向儿童的内容: -1默认值，不确定 0不希望 1希望
      tagForChildProtection: -1,
      // 是否希望按适合未达到法定承诺年龄的欧洲经济区 (EEA) 用户的方式处理该广告请求： -1默认值，不确定 0不希望 1希望
      tagForUnderAgeOfPromise: -1,
      // 设置广告内容分级上限: W: 3+,所有受众 PI: 7+,家长指导 J:12+,青少年 A: 16+/18+，成人受众
      adContentClassification: 'A'
    }

    // 开屏图片广告请求参数
    this.splashAdReqParams = {
      // 'testq6zq98hecj'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
      adId: id,
      adType: 1,
      adCount: 1,
      oaid: AD.OAID
    }
  }

  loadAd(context: common.Context, routePage: (ads: Array<advertising.Advertisement>,
    adDisplayOptions: advertising.AdDisplayOptions) => void, error: () => void) {
    // 广告请求回调监听
    const adLoaderListener: advertising.AdLoadListener = {
      // 广告请求失败回调
      onAdLoadFailure: (errorCode: number, errorMsg: string) => {
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败: ${errorCode} ${errorMsg}}`
          })
        }
        Log.error(`Failed to request HwSplashAd ad. errorCode is: ${errorCode}, errorMsg is: ${errorMsg}`)
        error()
      },
      // 广告请求成功回调
      onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
        Log.info('Succeeded in requesting HwSplashAd!')
        // 保存请求到的广告内容用于展示
        Log.info(`adType is : ${ads[0].adType}`)
        if (canIUse("SystemCapability.Advertising.Ads")) {
          if (ads[0].adType === 1) {
            // 调用开屏广告展示页面
            routePage(ads, this.adDisplayOptions);
          } else {
            Log.error('Error adType')
          }
        }
      }
    };

    // 创建AdLoader广告对象
    const load: advertising.AdLoader = new advertising.AdLoader(context);
    // 调用广告请求接口
    Log.info('Request SplashAd!')
    load.loadAd(this.splashAdReqParams, this.adOptions, adLoaderListener);
  }
}

export class HwInfoAd {
  private adDisplayOptions: advertising.AdDisplayOptions;
  private adOptions: advertising.AdOptions;
  private nativeVideoAdReqParams: advertising.AdRequestParams;
  private uniqueId = ''

  constructor(uniqueId: string, adId: string) {
    this.uniqueId = uniqueId
    // 广告展示参数
    this.adDisplayOptions = {
      // 是否静音，默认不静音
      mute: true,
      colorMode: 1
    }

    // 原生广告配置
    this.adOptions = {
      // 是否允许流量下载 0不允许 1允许，不设置以广告主设置为准
      allowMobileTraffic: 0,
      // 是否希望根据 COPPA 的规定将您的内容视为面向儿童的内容: -1默认值，不确定 0不希望 1希望
      tagForChildProtection: -1,
      // 是否希望按适合未达到法定承诺年龄的欧洲经济区 (EEA) 用户的方式处理该广告请求： -1默认值，不确定 0不希望 1希望
      tagForUnderAgeOfPromise: -1,
      // 设置广告内容分级上限: W: 3+,所有受众 PI: 7+,家长指导 J:12+,青少年 A: 16+/18+，成人受众
      adContentClassification: 'A'
    };

    // 原生广告请求参数
    this.nativeVideoAdReqParams = {
      // 'testu7m3hc4gvm'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
      adId: adId,
      adType: 3,
      adCount: 1,
      // 原生广告自定义扩展参数。等所有广告素材下载完后再回调
      enableDirectReturnVideoAd: true,
      oaid: AD.OAID
    }
  }

  loadAd(context: common.Context, routePage: (ads: Array<advertising.Advertisement>,
    adDisplayOptions: advertising.AdDisplayOptions) => void) {
    // 广告请求回调监听
    const adLoaderListener: advertising.AdLoadListener = {
      // 广告请求失败回调
      onAdLoadFailure: (errorCode: number, errorMsg: string) => {
        Log.error(`Failed to request InfoAd, message: ${errorMsg}, error code: ${errorCode}`)
        routePage([], this.adDisplayOptions);
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败: ${errorCode} ${errorMsg}}`
          })
        }

      },
      // 广告请求成功回调
      onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
        Log.info('Succeeded in requesting InfoAd')
        // 调用原生广告展示页面
        routePage(ads, this.adDisplayOptions);
      }
    };
    // 创建AdLoader广告对象
    const load: advertising.AdLoader = new advertising.AdLoader(context);
    // 调用广告请求接口
    load.loadAd(this.nativeVideoAdReqParams, this.adOptions, adLoaderListener);
  }
}

export class HwLscrAd {
  private adId: string = ''

  constructor(adId: string) {
    this.adRequestParam = {
      // 广告类型：插屏广告
      adType: 12,
      // 'testb4znbuh3n2'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
      adId: adId,
      // 开放匿名设备标识符
      oaid: AD.OAID
    };
  }

  private displayOptions: advertising.AdDisplayOptions = {
    // 插屏广告视频播放是否静音
    mute: true,
    colorMode: 1
  }
  private adRequestParam: advertising.AdRequestParams = {
    // 广告类型：插屏广告
    adType: 12,
    // 'testb4znbuh3n2'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
    adId: this.adId,
    // 开放匿名设备标识符
    oaid: AD.OAID
  };
  private adOption: advertising.AdOptions = {
    // 设置是否请求非个性化广告
    nonPersonalizedAd: 0,
    // 是否允许流量下载0：不允许，1：允许，不设置以广告主设置为准
    allowMobileTraffic: 0,
    // 是否希望根据 COPPA 的规定将您的内容视为面向儿童的内容: -1默认值，不确定 0不希望 1希望
    tagForChildProtection: -1,
    // 是否希望按适合未达到法定承诺年龄的欧洲经济区 (EEA) 用户的方式处理该广告请求： -1默认值，不确定 0不希望 1希望
    tagForUnderAgeOfPromise: -1,
    // 设置广告内容分级上限: W: 3+,所有受众 PI: 7+,家长指导 J:12+,青少年 A: 16+/18+，成人受众
    adContentClassification: 'A'
  };

  loadAd(context: common.UIAbilityContext, callback: (success: boolean) => void) {
    const adLoaderListener: advertising.AdLoadListener = {
      onAdLoadFailure: (errorCode: number, errorMsg: string) => {
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败: ${errorCode} ${errorMsg}}`
          })
        }
        Log.error(`Failed to request HwLscrAd, message: ${errorMsg}, error code: ${errorCode}`)
        callback(false)
      },
      onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
        Log.info('Succeeded in requesting HwLscrAd!')
        new InterstitialAdStatusHandler().registerPPSReceiver()
        advertising.showAd(ads[0], this.displayOptions, context)
        callback(true)
        //routePage(ads, this.displayOptions);
      },
    };
    // 创建AdLoader广告对象
    const load: advertising.AdLoader = new advertising.AdLoader(context);
    // 调用广告请求接口
    load.loadAd(this.adRequestParam, this.adOption, adLoaderListener);
  }
}

export class HwVideoAd {
  constructor(adId: string) {
    this.adRequestParam = {
      // 广告类型：激励广告
      adType: 7,
      // 'testx9dtjwj8hp'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
      adId: adId,
      // 开放匿名设备标识符
      oaid: AD.OAID
    };
  }

  private adRequestParam: advertising.AdRequestParams = {
    // 广告类型：激励广告
    adType: 7,
    // 'testx9dtjwj8hp'为测试专用的广告位ID，App正式发布时需要改为正式的广告位ID
    adId: '',
    // 开放匿名设备标识符
    oaid: AD.OAID
  };
  private adOption: advertising.AdOptions = {
    // 设置是否请求非个性化广告
    nonPersonalizedAd: 0,
    // 是否允许流量下载0：不允许，1：允许，不设置以广告主设置为准
    allowMobileTraffic: 0,
    // 是否希望根据 COPPA 的规定将您的内容视为面向儿童的内容: -1默认值，不确定 0不希望 1希望
    tagForChildProtection: -1,
    // 是否希望按适合未达到法定承诺年龄的欧洲经济区 (EEA) 用户的方式处理该广告请求： -1默认值，不确定 0不希望 1希望
    tagForUnderAgeOfPromise: -1,
    // 设置广告内容分级上限: W: 3+,所有受众 PI: 7+,家长指导 J:12+,青少年 A: 16+/18+，成人受众
    adContentClassification: 'A'
  };

  loadAd(context: common.UIAbilityContext, callback: (err?:BusinessError) => void) {
    const adLoaderListener: advertising.AdLoadListener = {
      onAdLoadFailure: (errorCode: number, errorMsg: string) => {
        if (AD.enableADToast && AD.isDEBUG()) {
          promptAction.showToast({
            message: `广告渲染失败: ${errorCode} ${errorMsg}}`
          })
        }
        callback({
          code: errorCode,
          message: errorMsg
        } as BusinessError)
        Log.error(`Failed to request HwVideoAd, message: ${errorMsg}, error code: ${errorCode}`)
      },
      onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
        Log.info(`Succeeded in requesting HwVideoAd`)
        new RewardAdStatusHandler().registerPPSReceiver(callback)
        advertising.showAd(ads[0], this.adOption, context);
      },
    };

    // 创建AdLoader广告对象
    const load: advertising.AdLoader = new advertising.AdLoader(context);
    // 调用广告请求接口
    load.loadAd(this.adRequestParam, this.adOption, adLoaderListener);
  }
}