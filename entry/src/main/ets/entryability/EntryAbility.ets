import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import RdbManager from '../common/zyhttp/RdbManager';
import { Log } from '@zycore/common';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    // json.applicationId
    // json.hmads.csj.exts
    // json.hmads.csj.modules.find((item) => {
    //   item.moduleId == 'public'
    // })?.lscr

    uiObserver.on('routerPageUpdate', this.context, (info: uiObserver.RouterPageInfo) => {
      Log.warn(`uiObserver: ${info.name} ${info.state.toString()}`)
    })
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage)
    RdbManager.init(this.context)
    // Main window is created, set main page for this ability
    let windows = windowStage.getMainWindowSync()
    windows?.setWindowLayoutFullScreen(true)
    windowStage.loadContent('pages/Splash', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
    })
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
