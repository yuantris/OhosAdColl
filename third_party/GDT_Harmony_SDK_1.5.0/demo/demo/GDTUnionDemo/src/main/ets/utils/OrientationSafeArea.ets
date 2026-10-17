import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DemoConstants } from '../constants/DemoConstants';
import { LogUtil } from './LogUtil';

/**
 * 横竖屏方向与安全区 insets 追踪器。
 *
 * 通过 windowSizeChange 事件感知旋转，横屏时从 getWindowAvoidArea 读取左右安全区宽度
 * （状态栏 + 刘海/挖孔），取两者最大值作为左右 padding。
 * 供 AdaptiveLayout（分栏布局）和列表页（仅需安全区 padding）共用。
 *
 * 使用方式：在组件 aboutToAppear 调用 init()，aboutToDisappear 调用 dispose()。
 */
@ObservedV2
export class OrientationSafeArea {
  @Trace public isLandscape: boolean = false;
  @Trace public leftInset: number = 0;
  @Trace public rightInset: number = 0;

  private hostWindow: window.Window | undefined = undefined;

  private readonly onWindowSizeChange = (size: window.Size): void => {
    this.isLandscape = size.width > size.height;
    this.updateInsets();
  };

  /**
   * 注册 windowSizeChange 监听并初始化当前方向与安全区。
   * 必须在组件 aboutToAppear 中调用。
   */
  public init(): void {
    try {
      const win = DemoConstants.windowStage.getMainWindowSync();
      this.hostWindow = win;
      const rect = win.getWindowProperties().windowRect;
      this.isLandscape = rect.width > rect.height;
      this.updateInsets();
      win.on('windowSizeChange', this.onWindowSizeChange);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogUtil.error(`OrientationSafeArea init: ${msg}`);
    }
  }

  /**
   * 移除监听。必须在组件 aboutToDisappear 中调用。
   */
  public dispose(): void {
    this.hostWindow?.off('windowSizeChange', this.onWindowSizeChange);
    this.hostWindow = undefined;
  }

  private updateInsets(): void {
    try {
      if (!this.hostWindow) {
        return;
      }
      const density = display.getDefaultDisplaySync().densityPixels;
      if (!density || density <= 0) {
        return;
      }
      if (!this.isLandscape) {
        this.leftInset = 0;
        this.rightInset = 0;
        return;
      }
      // 横屏时取 TYPE_SYSTEM（状态栏/导航栏）和 TYPE_CUTOUT（刘海/挖孔）的最大值
      const systemArea = this.hostWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea = this.hostWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const leftPx = Math.max(systemArea.leftRect.width, cutoutArea.leftRect.width);
      const rightPx = Math.max(systemArea.rightRect.width, cutoutArea.rightRect.width);
      this.leftInset = leftPx / density;
      this.rightInset = rightPx / density;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogUtil.error(`OrientationSafeArea updateInsets: ${msg}`);
    }
  }
}
