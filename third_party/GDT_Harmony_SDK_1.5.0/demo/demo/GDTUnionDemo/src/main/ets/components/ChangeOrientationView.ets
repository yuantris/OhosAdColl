import { ButtonItem } from './ButtonItem';
import { window } from '@kit.ArkUI';
import { DemoConstants } from '../constants/DemoConstants';
import { LogUtil } from '../utils/LogUtil';

/**
 * 横竖屏切换按钮，文案随当前方向显示"切换为横屏/切换为竖屏"。
 *
 * 用 windowClass.on('windowSizeChange') 而非 display.on('change') 感知旋转：
 * 后者触发时 Display.orientation 可能仍是旋转前的旧值（鸿蒙已知时序问题）。
 */
@ComponentV2
export struct ChangeOrientationView {
  @Local title: string = this.getTitle();
  // 回调须对象传递（非匿名函数），否则 off 时无法按引用精确移除，会造成监听残留
  private hostWindow: window.Window | undefined = undefined;
  private readonly onWindowSizeChange = (size: window.Size): void => {
    this.title = size.width > size.height ? '切换为竖屏' : '切换为横屏';
  };

  aboutToAppear(): void {
    try {
      const win = DemoConstants.windowStage.getMainWindowSync();
      this.hostWindow = win;
      win.on('windowSizeChange', this.onWindowSizeChange);
    } catch (err) {
      LogUtil.error(`ChangeOrientationView register windowSizeChange failed: ${(err as Error).message}`);
    }
  }

  aboutToDisappear(): void {
    this.hostWindow?.off('windowSizeChange', this.onWindowSizeChange);
  }

  getTitle(): string {
    try {
      const rect = DemoConstants.windowStage.getMainWindowSync().getWindowProperties().windowRect;
      return rect.width > rect.height ? '切换为竖屏' : '切换为横屏';
    } catch (err) {
      LogUtil.error(`ChangeOrientationView getTitle failed: ${(err as Error).message}`);
      return '切换为横屏';
    }
  }

  changeOrientation(): void {
    try {
      const rect = DemoConstants.windowStage.getMainWindowSync().getWindowProperties().windowRect;
      const target = rect.width > rect.height ? window.Orientation.PORTRAIT : window.Orientation.LANDSCAPE;
      DemoConstants.windowStage.getMainWindowSync().setPreferredOrientation(target);
    } catch (err) {
      LogUtil.error(`ChangeOrientationView changeOrientation failed: ${(err as Error).message}`);
    }
  }

  build() {
    ButtonItem({ title: this.title })
      .onClick(() => {
        this.changeOrientation();
      })
  }
}
