import { window } from '@kit.ArkUI';
import { zyOff } from '@zycore/network';
import { AESCodec, Log, Ohos } from '@zycore/common';

export class AD {
  static APPID = ''
  static SID = ''
  static VID = ''
  /*广告ID*/
  static CSJ_APPID = ''
  static CSJ_SPLASH_ID = '' // 开屏广告ID
  static CSJ_SCREEN_ID = '' // 插屏广告ID
  static CSJ_VIDEO_ID = '' // 激励视频广告ID
  static CSJ_INFO_ID = '' // 信息流大图广告ID
  static CSJ_INFO_LEFT_ID = '' // 信息流大图广告ID
  static CSJ_INFO_NATIVE_ID = '' // 信息流大图原生广告ID

  static HW_SPLASH_ID = '' // 开屏广告ID
  static HW_SCREEN_ID = '' // 插屏广告ID
  static HW_VIDEO_ID = '' // 激励视频广告ID
  static HW_INFO_ID = '' // 信息流大图广告ID
  static HW_INFO_LEFT_ID = '' // 信息流大图广告ID
  static HW_INFO_NATIVE_ID = '' // 信息流大图原生广告ID

  //-------------------------------腾讯优量汇-----------------------------------
  public static TX_APP_ID = '';
  public static TX_REWARD_DEFAULT_POS_ID = '';
  public static readonly TX_REWARD_POS_ID_LIST: Array<[string, string]> = [
    ['5171580898607362', '激励广告'],
    ['2103516330525939', '激励广告（S2S）']
  ];
  public static TX_SPLASH_DEFAULT_POS_ID = '';
  public static readonly TX_SPLASH_POS_ID_LIST: Array<[string, string]> = [
    ['2113519330120408', '开屏广告'],
    ['5193211370826641', '开屏广告（S2S）']
  ];
  public static TX_INTERSTITIAL_DEFAULT_POS_ID = '';
  public static readonly TX_INTERSTITIAL_POS_ID_LIST: Array<[string, string]> = [
    ['3183311380526666', '插屏广告'],
    ['9133310340928744', '插屏广告（S2S）']
  ];
  public static readonly TX_BANNER_DEFAULT_POS_ID = '';
  public static readonly TX_BANNER_POS_ID_LIST: Array<[string, string]> = [
    ['5125743518781002', 'Banner'],
    ['6175741579510293', 'Banner（S2S）'],
  ];
  public static TX_NATIVE_DEFAULT_POS_ID = '';
  public static readonly TX_NATIVE_POS_ID_LIST: Array<[string, string]> = [
    ['3115146508872689', '信息流'],
    ['3115548559014318', '信息流（S2S）'],
  ];
  public static TX_MANUAL_DEFAULT_POS_ID = '';
  public static readonly TX_MANUAL_POS_ID_LIST: Array<[string, string]> = [
    ['1185848508872314', '信息流'],
    ['7105949579611688', '信息流（S2S）'],
  ];
  static isCsj = false // 首先是否是穿山甲广告
  static isHw = false // 首先是否是华为广告
  static isTx = false // 首先是否是腾讯广告
  static isAdOpen = false // 广告是否开启

  // 广告off
  static OFF_CLOSE = 0
  static OFF_CSJ = 1
  static OFF_TX = 2
  static OFF_HW = 4
  static windowStage: window.WindowStage
  static splashAdWindow: window.Window
  static zyOff: zyOff
  static OAID: string
  // 激励视频广告全部观看 0不配置 1/3配置 2/4配置并完整观看
  static AD_VJUMP: number = 2
  // 强制启用渠道
  static forceEnableAdChannel: number = -1
  // 启用线上V4更换广告ID
  static enableV4AD: boolean = true
  // AD吐司提示
  static enableADToast: boolean = false

  static isDEBUG(): boolean {
    return Ohos.debug()
  }

  static isADJumpCheck(): boolean {
    return AD.AD_VJUMP == 2 || AD.AD_VJUMP == 4;
  }

  static printAD() {
    let ads = `[
    CSJ_APPID: ${AD.CSJ_APPID}
    CSJ_SPLASH_ID: ${AD.CSJ_SPLASH_ID}
    CSJ_SCREEN_ID: ${AD.CSJ_SCREEN_ID}
    CSJ_VIDEO_ID: ${AD.CSJ_VIDEO_ID}
    CSJ_INFO_ID: ${AD.CSJ_INFO_ID}
    CSJ_INFO_LEFT_ID: ${AD.CSJ_INFO_LEFT_ID}
    CSJ_INFO_NATIVE_ID: ${AD.CSJ_INFO_NATIVE_ID}
    TX_APP_ID: ${AD.TX_APP_ID}
    TX_SPLASH_ID: ${AD.TX_SPLASH_DEFAULT_POS_ID}
    TX_VIDEO_ID: ${AD.TX_REWARD_DEFAULT_POS_ID}
    TX_SCREEN_ID: ${AD.TX_INTERSTITIAL_DEFAULT_POS_ID}
    TX_INFO_ID: ${AD.TX_NATIVE_DEFAULT_POS_ID}
    TX_INFO_LEFT_ID: ${AD.TX_MANUAL_DEFAULT_POS_ID}
    HW_SPLASH_ID: ${AD.HW_SPLASH_ID}
    HW_SCREEN_ID: ${AD.HW_SCREEN_ID}
    HW_VIDEO_ID: ${AD.HW_VIDEO_ID}
    HW_INFO_ID: ${AD.HW_INFO_ID}
    HW_INFO_LEFT_ID: ${AD.HW_INFO_LEFT_ID}
]`
    Log.error(ads)
  }

  static printV4AD() {
    try {
      Log.error(AESCodec.decrypt(AD.APPID, AD.zyOff.i))
    } catch (e) {
      Log.error(`printV4AD error: ${e}`)
    }
  }
}