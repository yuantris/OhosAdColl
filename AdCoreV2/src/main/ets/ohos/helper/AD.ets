import { AdIdStore } from "./core/AdIdStore"
import { AdSwitchManager } from "./core/AdSwitchManager"

export class AD {
  static get APPID(): string {
    return AdIdStore.APPID
  }

  static get SID(): string {
    return AdIdStore.SID
  }

  static get VID(): string {
    return AdIdStore.VID
  }

  static set AD_VJUMP(value: number) {
    AdSwitchManager.AD_VJUMP = value
  }

  static get isAdOpen(): boolean {
    return AdSwitchManager.isAdOpen
  }

  static get VJUMP(): number {
    return AdSwitchManager.AD_VJUMP
  }

  static isADJumpCheck(): boolean {
    return AdSwitchManager.isADJumpCheck()
  }

  static printAD(): void {
    AdIdStore.printAD()
  }
}