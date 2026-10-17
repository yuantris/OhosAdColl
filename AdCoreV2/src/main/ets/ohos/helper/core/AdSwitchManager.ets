import { Ohos } from "@zycore/common"

export class AdSwitchManager {
  private static _isCsj = false
  private static _isHw = false
  private static _isTx = false
  private static _isAdOpen = false
  private static _isForceAdOpen = false
  private static _AD_VJUMP: number = 0
  private static _enableDynamicAD: boolean = true
  private static _enableEasyConfig: boolean = false
  private static _enableADToast: boolean = false
  private static _enableAutoNetConfig: boolean = true
  // 动态广告模式下后端约定：华为平台info_left与ban合二为一，共用同一广告位ID
  // false时还原旧行为：ban与info_left各自使用独立配置
  private static _enableBanMerge: boolean = false

  static get isCsj(): boolean { return AdSwitchManager._isCsj }
  static get isHw(): boolean { return AdSwitchManager._isHw }
  static get isTx(): boolean { return AdSwitchManager._isTx }
  static get isAdOpen(): boolean { return AdSwitchManager._isAdOpen }
  static get VJUMP(): number { return AdSwitchManager._AD_VJUMP }
  static get enableDynamicAD(): boolean { return AdSwitchManager._enableDynamicAD }
  static get enableV4AD(): boolean { return AdSwitchManager._enableDynamicAD }
  static get enableEasyConfig(): boolean { return AdSwitchManager._enableEasyConfig }
  static get enableADToast(): boolean { return AdSwitchManager._enableADToast }
  static get enableAutoNetConfig(): boolean { return AdSwitchManager._enableAutoNetConfig }
  static get enableBanMerge(): boolean { return AdSwitchManager._enableBanMerge }

  static set AD_VJUMP(value: number) { AdSwitchManager._AD_VJUMP = value }
  static set enableDynamicAD(value: boolean) { AdSwitchManager._enableDynamicAD = value }
  static set enableV4AD(value: boolean) { AdSwitchManager._enableDynamicAD = value }
  static set enableEasyConfig(value: boolean) { AdSwitchManager._enableEasyConfig = value }
  static set enableADToast(value: boolean) { AdSwitchManager._enableADToast = value }
  static set enableAutoNetConfig(value: boolean) { AdSwitchManager._enableAutoNetConfig = value }
  static set enableBanMerge(value: boolean) { AdSwitchManager._enableBanMerge = value }
  static forceAdOpen() {
    if (Ohos.debug()) {
      AdSwitchManager._isForceAdOpen = true
    }
  }
  static setAdPlatformFlags(csj: boolean, hw: boolean, tx: boolean, adOpen: boolean): void {
    AdSwitchManager._isCsj = csj
    AdSwitchManager._isHw = hw
    AdSwitchManager._isTx = tx
    AdSwitchManager._isAdOpen = AdSwitchManager._isForceAdOpen ? true : adOpen;
  }

  static isADJumpCheck(): boolean {
    return AdSwitchManager._AD_VJUMP == 2 || AdSwitchManager._AD_VJUMP == 4
  }
}
