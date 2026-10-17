import display from '@ohos.display'

export class UIUtil {
  static getScreenWidthPx() {
    let screen = display.getDefaultDisplaySync()
    return screen.width
  }

  /**
   * 获得屏幕高度，包含了挖孔区域
   * @returns
   */
  static getScreenHeightPx() : number {
    let screen = display.getDefaultDisplaySync()
    return screen.height
  }

  static getScreenWidthVp(): number {
    return UIUtil.getScreenWidthPx() / UIUtil.getDensityPixels()
  }

  static getScreenHeightVp() : number {
    return UIUtil.getScreenHeightPx() / UIUtil.getDensityPixels()
  }

  static getScreenStatusBarHeightVp(): number {
    return 38.3
  }

  static getDensityPixels() {
    let screen = display.getDefaultDisplaySync()
    return screen.densityPixels
  }
}