import display from '@ohos.display';
import { promptAction } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';

export default class Util {
  /**
   * 吐司提示
   * @param name 提示内容
   */
  public static toast(name: string, duration: number = 2000): void {
    promptAction.showToast({
      message: name,
      duration: duration
    })
  }

  /**
   * 去掉浮点的小数
   */
  public static float2Int(value?: number): number {
    if (value === undefined || value === null) {
      return 0
    }

    if (value < 0) {
      return Math.ceil(value);
    }
    return Math.floor(value);
  }

  /**
   * 屏幕高度(像素比屏幕密度)
   * @returns
   */
  public static screenHeight(): number {
    let defaultDisplay = display.getDefaultDisplaySync()
    let height = defaultDisplay.height / defaultDisplay.scaledDensity

    if (isNaN(height)) {
      return 0
    }
    return Util.float2Int(height)
  }

  /**
   * 屏幕宽度(像素比屏幕密度)
   * @returns
   */
  public static screenWeight(): number {
    let defaultDisplay = display.getDefaultDisplaySync()
    let width = defaultDisplay.width / defaultDisplay.scaledDensity

    if (isNaN(width)) {
      return 0
    }
    return Util.float2Int(width)
  }

  /**
   * 空字符串检查
   * @param value 检查的值
   * @returns true 为空
   */
  public static isEmpty(value?: string): boolean {
    if (value === undefined || value === null || value === '' || value.length <= 0) {
      return true
    }
    return false
  }

  /**
   * 是否应该异形屏适配
   * @returns
   */
  public static isSpecialShapedScreen(): boolean {
    let manager = getContext().resourceManager;
    let type = manager.getDeviceCapabilitySync().deviceType;
    if (type === resourceManager.DeviceType.DEVICE_TYPE_PHONE) {
      return display.isFoldable()
    } else {
      return true
    }
  }
}