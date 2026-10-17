import { LogManager } from '../logger/LogManager';

export class AdIdStore {
  private static _APPID = ''
  private static _SID = ''
  private static _VID = ''

  private static _CSJ_APPID = '5477447'
  private static _CSJ_SPLASH_ID = '888906709'
  private static _CSJ_SCREEN_ID = '955806169'
  private static _CSJ_VIDEO_ID = '955804646'
  private static _CSJ_INFO_ID = '955804505'
  private static _CSJ_INFO_LEFT_ID = ''
  private static _CSJ_INFO_NATIVE_ID = ''

  private static _HW_APP_ID = ''
  private static _HW_SPLASH_ID = ''
  private static _HW_SCREEN_ID = ''
  private static _HW_VIDEO_ID = ''
  private static _HW_INFO_ID = ''
  private static _HW_INFO_LEFT_ID = ''
  private static _HW_INFO_NATIVE_ID = ''
  private static _HW_BANNER_ID = ''

  /** 证书锁定公钥 SHA256 BASE64（可多 pin 轮换）；空数组表示不启用 */
  private static _CERT_PINS: string[] = []

  private static _TX_APP_ID = '';
  private static _TX_REWARD_DEFAULT_POS_ID = '';
  private static _TX_REWARD_POS_ID_LIST: Array<[string, string]> = [
    ['5171580898607362', '激励广告'],
    ['2103516330525939', '激励广告（S2S）']
  ];
  private static _TX_SPLASH_DEFAULT_POS_ID = '';
  private static _TX_SPLASH_POS_ID_LIST: Array<[string, string]> = [
    ['2113519330120408', '开屏广告'],
    ['5193211370826641', '开屏广告（S2S）']
  ];
  private static _TX_INTERSTITIAL_DEFAULT_POS_ID = '';
  private static _TX_INTERSTITIAL_POS_ID_LIST: Array<[string, string]> = [
    ['3183311380526666', '插屏广告'],
    ['9133310340928744', '插屏广告（S2S）']
  ];
  private static _TX_BANNER_DEFAULT_POS_ID = '';
  private static _TX_BANNER_POS_ID_LIST: Array<[string, string]> = [
    ['5125743518781002', 'Banner'],
    ['6175741579510293', 'Banner（S2S）'],
  ];
  private static _TX_NATIVE_DEFAULT_POS_ID = '';
  private static _TX_NATIVE_POS_ID_LIST: Array<[string, string]> = [
    ['3115146508872689', '信息流'],
    ['3115548559014318', '信息流（S2S）'],
  ];
  private static _TX_MANUAL_DEFAULT_POS_ID = '';
  private static _TX_MANUAL_POS_ID_LIST: Array<[string, string]> = [
    ['1185848508872314', '信息流'],
    ['7105949579611688', '信息流（S2S）'],
  ];
  private static _TX_MANUAL_DEFAULT_LEFT_POS_ID = '';
  private static _TX_MANUAL_LEFT_POS_ID_LIST: Array<[string, string]> = [
    ['1185848508872314', '信息流小图'],
    ['7105949579611688', '信息流小图（S2S）'],
  ];

  static get APPID(): string { return AdIdStore._APPID }
  static set APPID(value: string) { AdIdStore._APPID = value }
  static get SID(): string { return AdIdStore._SID }
  static set SID(value: string) { AdIdStore._SID = value }
  static get VID(): string { return AdIdStore._VID }
  static set VID(value: string) { AdIdStore._VID = value }

  static get CSJ_APPID(): string { return AdIdStore._CSJ_APPID }
  static set CSJ_APPID(value: string) { AdIdStore._CSJ_APPID = value }
  static get CSJ_SPLASH_ID(): string { return AdIdStore._CSJ_SPLASH_ID }
  static set CSJ_SPLASH_ID(value: string) { AdIdStore._CSJ_SPLASH_ID = value }
  static get CSJ_SCREEN_ID(): string { return AdIdStore._CSJ_SCREEN_ID }
  static set CSJ_SCREEN_ID(value: string) { AdIdStore._CSJ_SCREEN_ID = value }
  static get CSJ_VIDEO_ID(): string { return AdIdStore._CSJ_VIDEO_ID }
  static set CSJ_VIDEO_ID(value: string) { AdIdStore._CSJ_VIDEO_ID = value }
  static get CSJ_INFO_ID(): string { return AdIdStore._CSJ_INFO_ID }
  static set CSJ_INFO_ID(value: string) { AdIdStore._CSJ_INFO_ID = value }
  static get CSJ_INFO_LEFT_ID(): string { return AdIdStore._CSJ_INFO_LEFT_ID }
  static set CSJ_INFO_LEFT_ID(value: string) { AdIdStore._CSJ_INFO_LEFT_ID = value }
  static get CSJ_INFO_NATIVE_ID(): string { return AdIdStore._CSJ_INFO_NATIVE_ID }
  static set CSJ_INFO_NATIVE_ID(value: string) { AdIdStore._CSJ_INFO_NATIVE_ID = value }

  static get HW_APP_ID(): string { return AdIdStore._HW_APP_ID }
  static set HW_APP_ID(value: string) { AdIdStore._HW_APP_ID = value }
  static get CERT_PINS(): string[] { return [...AdIdStore._CERT_PINS] }
  static set CERT_PINS(value: string[]) { AdIdStore._CERT_PINS = value }
  static get HW_SPLASH_ID(): string { return AdIdStore._HW_SPLASH_ID }
  static set HW_SPLASH_ID(value: string) { AdIdStore._HW_SPLASH_ID = value }
  static get HW_SCREEN_ID(): string { return AdIdStore._HW_SCREEN_ID }
  static set HW_SCREEN_ID(value: string) { AdIdStore._HW_SCREEN_ID = value }
  static get HW_VIDEO_ID(): string { return AdIdStore._HW_VIDEO_ID }
  static set HW_VIDEO_ID(value: string) { AdIdStore._HW_VIDEO_ID = value }
  static get HW_INFO_ID(): string { return AdIdStore._HW_INFO_ID }
  static set HW_INFO_ID(value: string) { AdIdStore._HW_INFO_ID = value }
  static get HW_INFO_LEFT_ID(): string { return AdIdStore._HW_INFO_LEFT_ID }
  static set HW_INFO_LEFT_ID(value: string) { AdIdStore._HW_INFO_LEFT_ID = value }
  static get HW_INFO_NATIVE_ID(): string { return AdIdStore._HW_INFO_NATIVE_ID }
  static set HW_INFO_NATIVE_ID(value: string) { AdIdStore._HW_INFO_NATIVE_ID = value }
  static get HW_BANNER_ID(): string { return AdIdStore._HW_BANNER_ID }
  static set HW_BANNER_ID(value: string) { AdIdStore._HW_BANNER_ID = value }

  static get TX_APP_ID(): string { return AdIdStore._TX_APP_ID }
  static set TX_APP_ID(value: string) { AdIdStore._TX_APP_ID = value }
  static get TX_REWARD_DEFAULT_POS_ID(): string { return AdIdStore._TX_REWARD_DEFAULT_POS_ID }
  static set TX_REWARD_DEFAULT_POS_ID(value: string) { AdIdStore._TX_REWARD_DEFAULT_POS_ID = value }
  static get TX_REWARD_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_REWARD_POS_ID_LIST] }
  static get TX_SPLASH_DEFAULT_POS_ID(): string { return AdIdStore._TX_SPLASH_DEFAULT_POS_ID }
  static set TX_SPLASH_DEFAULT_POS_ID(value: string) { AdIdStore._TX_SPLASH_DEFAULT_POS_ID = value }
  static get TX_SPLASH_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_SPLASH_POS_ID_LIST] }
  static get TX_INTERSTITIAL_DEFAULT_POS_ID(): string { return AdIdStore._TX_INTERSTITIAL_DEFAULT_POS_ID }
  static set TX_INTERSTITIAL_DEFAULT_POS_ID(value: string) { AdIdStore._TX_INTERSTITIAL_DEFAULT_POS_ID = value }
  static get TX_INTERSTITIAL_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_INTERSTITIAL_POS_ID_LIST] }
  static get TX_BANNER_DEFAULT_POS_ID(): string { return AdIdStore._TX_BANNER_DEFAULT_POS_ID }
  static set TX_BANNER_DEFAULT_POS_ID(value: string) { AdIdStore._TX_BANNER_DEFAULT_POS_ID = value }
  static get TX_BANNER_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_BANNER_POS_ID_LIST] }
  static get TX_NATIVE_DEFAULT_POS_ID(): string { return AdIdStore._TX_NATIVE_DEFAULT_POS_ID }
  static set TX_NATIVE_DEFAULT_POS_ID(value: string) { AdIdStore._TX_NATIVE_DEFAULT_POS_ID = value }
  static get TX_NATIVE_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_NATIVE_POS_ID_LIST] }
  static get TX_MANUAL_DEFAULT_POS_ID(): string { return AdIdStore._TX_MANUAL_DEFAULT_POS_ID }
  static set TX_MANUAL_DEFAULT_POS_ID(value: string) { AdIdStore._TX_MANUAL_DEFAULT_POS_ID = value }
  static get TX_MANUAL_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_MANUAL_POS_ID_LIST] }
  static get TX_MANUAL_DEFAULT_LEFT_POS_ID(): string { return AdIdStore._TX_MANUAL_DEFAULT_LEFT_POS_ID }
  static set TX_MANUAL_DEFAULT_LEFT_POS_ID(value: string) { AdIdStore._TX_MANUAL_DEFAULT_LEFT_POS_ID = value }
  static get TX_MANUAL_LEFT_POS_ID_LIST(): Array<[string, string]> { return [...AdIdStore._TX_MANUAL_LEFT_POS_ID_LIST] }

  static printAD(): void {
    let ads = `[
    CSJ_APPID: ${AdIdStore.CSJ_APPID}
    CSJ_SPLASH_ID: ${AdIdStore.CSJ_SPLASH_ID}
    CSJ_SCREEN_ID: ${AdIdStore.CSJ_SCREEN_ID}
    CSJ_VIDEO_ID: ${AdIdStore.CSJ_VIDEO_ID}
    CSJ_INFO_ID: ${AdIdStore.CSJ_INFO_ID}
    CSJ_INFO_LEFT_ID: ${AdIdStore.CSJ_INFO_LEFT_ID}
    CSJ_INFO_NATIVE_ID: ${AdIdStore.CSJ_INFO_NATIVE_ID}
    TX_APP_ID: ${AdIdStore.TX_APP_ID}
    TX_SPLASH_ID: ${AdIdStore.TX_SPLASH_DEFAULT_POS_ID}
    TX_VIDEO_ID: ${AdIdStore.TX_REWARD_DEFAULT_POS_ID}
    TX_SCREEN_ID: ${AdIdStore.TX_INTERSTITIAL_DEFAULT_POS_ID}
    TX_INFO_ID: ${AdIdStore.TX_NATIVE_DEFAULT_POS_ID}
    TX_INFO_LEFT_ID: ${AdIdStore.TX_MANUAL_DEFAULT_POS_ID}
    HW_SPLASH_ID: ${AdIdStore.HW_SPLASH_ID}
    HW_SCREEN_ID: ${AdIdStore.HW_SCREEN_ID}
    HW_VIDEO_ID: ${AdIdStore.HW_VIDEO_ID}
    HW_INFO_ID: ${AdIdStore.HW_INFO_ID}
    HW_INFO_LEFT_ID: ${AdIdStore.HW_INFO_LEFT_ID}
    HW_BANNER_ID: ${AdIdStore.HW_BANNER_ID}
]`
    LogManager.error('printAD', ads)
  }
}
