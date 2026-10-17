import { AbilityLifecycleCallback, AbilityStage, UIAbility } from '@kit.AbilityKit';
import { uiObserver, window } from '@kit.ArkUI';
import { AD } from '../config/AD';
import { ADControl } from '../helper/ADControl';
import { InternalPlugin, preInit } from '@umeng/analytics';
import { PrefUtil } from '../util/PrefUtil';
import { pref } from '../ability/AppAbility';
import { getPageInfo, lifecycleCallbackTest, subscribeToRouteChanges } from './UnifiedRouteEvent';
import ADUtil from '../util/ADUtil';
import { warmStart } from '../helper/ADHelper';
import { Log, Ohos, StrUtils } from '@zycore/common';
import { AppConfig } from '../config/AppConfig';
import { configAD } from '../config/ADConfigBuilder';
import { TestLog } from '../test/TestLogEnvironment';

export abstract class RequestApplication extends AbilityStage {
  public static uiContext: UIContext
  public static appConfig: AppConfig
  private lifecycleId: number = 0

  onCreate(): void {
    let applicationContext = this.context.getApplicationContext()
    this.lifecycleId = applicationContext.on('abilityLifecycle', abilityLifecycleCallback)
    RequestApplication.appConfig = this.getAppConfig()
    configAD(JSON.parse(ADUtil.readInfoJsonFromRawFile(this.context))[0])
    // 友盟预初始化
    preInit({
      context: this.context.getApplicationContext(),
      plugins: [new InternalPlugin()]
    })
    Log.init()
    PrefUtil.init(pref, this.context)
    // 清除所有广告缓存
    PrefUtil.clear(pref)

    if (StrUtils.isBlank(RequestApplication.appConfig.mainPage)) {
      throw new Error('-----请在getAppConfig回调中设置setMainPage-----')
    }

    if (StrUtils.isBlank(RequestApplication.appConfig.guidePage)) {
      throw new Error('-----请在getAppConfig回调中设置setGuidePage-----')
    }

    this.preInitFinish()
  }

  onDestroy(): void {
    this.context.getApplicationContext()
      .off('abilityLifecycle', this.lifecycleId)
  }

  abstract getAppConfig(): AppConfig

  abstract preInitFinish(): void
}

export const sNavInfo = "NavDestination_AD_"

export const sHwSplash = "Hw_Splash_AD"

let isRegisterLifecycleCallback = false

// 页面生命周期回调
function lifecycleCallback(windowStage: window.WindowStage) {
  lifecycleCallbackTest(windowStage)
  subscribeToRouteChanges((event) => {
    let info = getPageInfo()
    ADUtil.logE('ADControl', `info: ${info.routerPageInfo?.name}\n${info.navDestinationInfo?.name}`)
    switch (event.eventType) {
      case 'switch':
        ADUtil.logE('ADControl', `switch__`)
        break
      case 'show':
        ADControl.onPageShow(info)
        break
      case 'hide':
        ADControl.onPageHide(info)
        break
      case 'appear':
        ADUtil.logE('ADControl', `appear__`)
        break
      case 'disappear':
        ADControl.onPageDestroy(info)
        break
    }
  })

}

// App热启动时间戳标记
export let mPreStamp: number

//设置热启动广告等待时间(毫秒),默认1分钟,
const adShowWaitingTime = 60000
// 声明ability生命周期回调，需配置所有回调后才可以在applicationContext注册
let abilityLifecycleCallback: AbilityLifecycleCallback = {
  onAbilityCreate(ability) {
    Log.fatal('onAbilityCreate');
    TestLog.updateMode(ability)
  },
  onWindowStageCreate(ability, windowStage) {
    Ohos.init(ability.context)
    AD.windowStage = windowStage
    AD.VID = Ohos.getVersionCode().toString()
    Log.fatal('onWindowStageCreate');
  },
  onWindowStageActive(ability, windowStage) {
    if (!RequestApplication.uiContext) {
      windowStage.getMainWindow().then((mainWindow) => {
        RequestApplication.uiContext = mainWindow.getUIContext();
        if (!isRegisterLifecycleCallback) {
          lifecycleCallback(windowStage);
          isRegisterLifecycleCallback = true
        }
      })
    }

    Log.fatal('onWindowStageActive');
  },
  onWindowStageInactive(ability, windowStage) {
    Log.fatal('onWindowStageInactive');
  },
  onWindowStageDestroy(ability, windowStage) {
    if (RequestApplication.uiContext) {
      uiObserver.off('routerPageUpdate', RequestApplication.uiContext);
      uiObserver.off('navDestinationUpdate');
    }
    Log.fatal('onWindowStageDestroy');
  },
  onAbilityDestroy(ability) {
    Log.fatal('onAbilityDestroy');
  },
  onAbilityForeground(ability) {
    Log.fatal('onAbilityForeground');
    let mCurStamp = Date.now()
    if (mPreStamp <= 0) {
      mPreStamp = mCurStamp
    }
    let sub = mCurStamp - mPreStamp
    if (sub > adShowWaitingTime) {
      warmStart()
    }
  },
  onAbilityBackground(ability) {
    Log.fatal('onAbilityBackground');
    mPreStamp = Date.now()
  },
  onAbilityContinue(ability) {
    Log.fatal('onAbilityContinue');
  },
  onNewWant(ability) {
    Log.fatal('onNewWant');
  },
  onWillNewWant(ability) {
    Log.fatal('onWillNewWant');
  },
  onAbilityWillCreate(ability) {
    Log.fatal('onAbilityWillCreate');
  },
  onWindowStageWillCreate(ability, windowStage) {
    Log.fatal('onWindowStageWillCreate');
  },
  onWindowStageWillDestroy(ability, windowStage) {
    Log.fatal('onWindowStageWillDestroy');
  },
  onAbilityWillDestroy(ability) {
    Log.fatal('onAbilityWillDestroy');
  },
  onAbilityWillForeground(ability) {
    Log.fatal('onAbilityWillForeground');
  },
  onAbilityWillBackground(ability) {
    Log.fatal('onAbilityWillBackground');
  },
  onAbilityWillContinue(ability: UIAbility) {
    Log.fatal('onAbilityWillContinue');
  },
  onWindowStageWillRestore(ability: UIAbility, windowStage: window.WindowStage) {
    Log.fatal('onWindowStageWillRestore');
  },
  onWindowStageRestore(ability: UIAbility, windowStage: window.WindowStage) {
    Log.fatal('onWindowStageRestore');
  },
  onAbilityWillSaveState(ability: UIAbility) {
    Log.fatal('onAbilityWillSaveState');
  },
  onAbilitySaveState(ability: UIAbility) {
    Log.fatal('onAbilitySaveState');
  }
}