import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import window from '@ohos.window';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrefUtil } from '../util/PrefUtil';
import { Log } from '@zycore/common';

// 每次启动缓存key
export const pref = 'ZY_AD_CORE'

// 点击刷新标记
export const pageUpdate = 'zy_page_update_event_listener'

// 热启动更新标记
export const warmUpdate = 'zy_warm_update_event_listener'

export abstract class AppAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    PrefUtil.init(pref, this.context)
    // 清除所有广告缓存
    PrefUtil.clear(pref)
  }

  onDestroy() {
    Log.info("[Demo] AppAbility onDestroy");
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Log.error('AppAbility onWindowStageCreate')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');


  }

  onWindowStageDestroy(): void {

  }

  abstract onWindowInit(): void

  abstract getSplashPage(): string

  abstract getSplashImg(): Resource
}

