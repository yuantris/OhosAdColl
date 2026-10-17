import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DemoConstants } from '../constants/DemoConstants';
import { LogUtil } from '../utils/LogUtil';
import { onAbilityCreate, onAbilityDestroy, onAbilityNewWant } from '@gdt/gdt-union-demo/ets/utils/AbilityHooks';
import { getAppId, onLoadContent } from '@gdt/gdt-union-demo/ets/utils/AdUtils';
import { SDKInitHelper } from '../utils/SDKInitHelper';
import { ToastUtil } from '../utils/ToastUtil';

export default class DemoAbility extends UIAbility {
  public onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    LogUtil.info('Ability onCreate');
    onAbilityCreate(want);
  }

  public onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    LogUtil.info('Ability onNewWant');
    onAbilityNewWant(want);
  }

  public onDestroy(): void {
    LogUtil.info('Ability onDestroy');
    onAbilityDestroy();
  }

  public onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    LogUtil.info('Ability onWindowStageCreate');
    DemoConstants.windowStage = windowStage;
    DemoConstants.uiAbilityContext = this.context;

    SDKInitHelper.initSDK(this.context, getAppId());

    windowStage.getMainWindow()
      .then((win) => {
        // 为方便调试，屏幕常亮
        win.setWindowKeepScreenOn(true);
        // 屏幕方向根据传感器自动切换
        win.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
      });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        LogUtil.error(`Failed to load the content. Cause: ${JSON.stringify(err) ?? ''}`);
        return;
      }
      // 初始化 ToastUtil，getUIContext 必须在 loadContent 之后调用
      const uiContext = windowStage.getMainWindowSync().getUIContext();
      ToastUtil.init(uiContext);

      onLoadContent();
      LogUtil.info('Succeeded in loading the content.');
    });
  }

  public onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    LogUtil.info('Ability onWindowStageDestroy');
  }

  public onForeground(): void {
    // Ability has brought to foreground
    LogUtil.info('Ability onForeground');
  }

  public onBackground(): void {
    // Ability has back to background
    LogUtil.info('Ability onBackground');
  }
}
