import { display } from '@kit.ArkUI';

export class DisplayUtil {
  private constructor() {
  }


  /**
   * 获取当前默认的display对象。
   * @returns
   */
  public static getDefaultDisplaySync(): display.Display {
    return display.getDefaultDisplaySync();
  }


  /**
   * 获取设备的屏幕宽度，单位为px。
   */
  public static getWidth(): display.FoldStatus {
    return DisplayUtil.getDefaultDisplaySync().width;
  }

  /**
   * 获取设备的屏幕宽度，单位为dp。
   */
  public static getWidthDp(): number {
    return DisplayUtil.px2dp(DisplayUtil.getWidth());
  }

  /**
   * 获取设备的屏幕高度，单位为px。
   */
  public static getHeight(): display.FoldStatus {
    return DisplayUtil.getDefaultDisplaySync().height;
  }

  /**
   * 获取设备的屏幕高度，单位为dp。
   */
  public static getHeightDp(): number {
    return DisplayUtil.px2dp(DisplayUtil.getHeight());
  }

  /**
   * 获取屏幕密度
   */
  public static getDensityDPI(): number {
    return DisplayUtil.getDefaultDisplaySync().densityDPI;
  }

  private static px2dp(px: number): number {
    const densityPixels = DisplayUtil.getDefaultDisplaySync().densityPixels;
    if (densityPixels === 0) {
      return px;
    }
    return Math.floor(px / densityPixels);
  }
}
