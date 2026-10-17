import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Ohos, Preferences } from '@zycore/common';
import { LogManager } from '../logger/LogManager';
import '../../pages/AdDebugFloatPage.ets';

const TAG = 'AdDebugFloatController';
const WINDOW_NAME = 'AdDebugFloatWindow';
const PAGE_NAME = 'AdDebugFloatPage';
const PREF_KEY_X = 'ad_debug_float_x';
const PREF_KEY_Y = 'ad_debug_float_y';

/**
 * 调试悬浮窗控制器（小米游戏工具箱式）
 * 仅 debug 构建可用：createSubWindow + startMoving 拖拽 + 折叠/展开
 */
export class AdDebugFloatController {
  private static instance: AdDebugFloatController | null = null;
  private subWindow: window.Window | null = null;
  private visible: boolean = false;

  static getInstance(): AdDebugFloatController {
    if (!AdDebugFloatController.instance) {
      AdDebugFloatController.instance = new AdDebugFloatController();
    }
    return AdDebugFloatController.instance;
  }

  isAvailable(): boolean {
    return Ohos.debug();
  }

  isVisible(): boolean {
    return this.visible;
  }

  /**
   * 显示调试悬浮球（默认球形态，点击展开面板）
   * @param width 窗口宽(vp)，默认 48（球）
   * @param height 窗口高(vp)，默认 48
   */
  async show(width: number = 48, height: number = 48): Promise<void> {
    if (!this.isAvailable()) {
      LogManager.warn(TAG, 'Debug float window only available in debug build');
      return;
    }
    if (this.visible && this.subWindow) {
      await this.subWindow.showWindow();
      return;
    }

    const windowStage = Ohos.getWindowStage();
    if (!windowStage) {
      LogManager.error(TAG, 'windowStage is null, cannot create debug float window');
      return;
    }

    try {
      const win: window.Window = await windowStage.createSubWindow(WINDOW_NAME);
      this.subWindow = win;

      const uiContext = Ohos.getUIContext();
      const w: number = uiContext ? uiContext.vp2px(width) : width;
      const h: number = uiContext ? uiContext.vp2px(height) : height;

      await win.resize(w, h);
      // 官方建议：不设 setFollowParentWindowLayoutEnabled，否则 moveWindowTo/resize 失效
      // 恢复上次拖拽位置（无记录时默认右边缘中部）
      const savedX = Preferences.getSync(PREF_KEY_X, -1) as number;
      const savedY = Preferences.getSync(PREF_KEY_Y, -1) as number;
      const posX = savedX >= 0 ? savedX : (uiContext ? uiContext.vp2px(16) : 16);
      const posY = savedY >= 0 ? savedY : (uiContext ? uiContext.vp2px(120) : 120);
      await win.moveWindowTo(posX, posY);
      // 官方模式：loadContentByName 加载已 import 的页面组件
      const storage: LocalStorage = new LocalStorage();
      await new Promise<void>((resolve, reject) => {
        win.loadContentByName(PAGE_NAME, storage, (err: BusinessError) => {
          if (err.code !== 0) {
            reject(new Error(`loadContentByName failed: ${err.code} ${err.message}`));
            return;
          }
          resolve();
        });
      });
      await win.setWindowBackgroundColor('#00000000');
      await win.setWindowTouchable(true);
      await win.showWindow();

      this.visible = true;
      LogManager.info(TAG, `Debug float window shown at (${posX},${posY}), ${width}x${height}`);
    } catch (e) {
      LogManager.error(TAG, `show debug float window failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  /** 隐藏悬浮窗 */
  async hide(): Promise<void> {
    if (this.subWindow && this.visible) {
      try {
        // 子窗口无 hide()，用 destroyWindow 或 moveWindowTo 屏幕外
        await this.subWindow.destroyWindow();
      } catch (e) {
        LogManager.warn(TAG, `hide failed: ${e instanceof Error ? e.message : String(e)}`);
      }
      this.subWindow = null;
      this.visible = false;
    }
  }

  /** 销毁悬浮窗 */
  async destroy(): Promise<void> {
    await this.hide();
  }

  /** 切换显示/隐藏 */
  async toggle(width?: number, height?: number): Promise<void> {
    if (this.visible) {
      await this.hide();
    } else {
      await this.show(width, height);
    }
  }

  /** 获取悬浮窗实例（供 UI 层调用 startMoving） */
  getWindow(): window.Window | null {
    return this.subWindow;
  }

  /**
   * 保存当前悬浮球位置（拖拽结束后调用，下次启动恢复）
   */
  async savePosition(): Promise<void> {
    if (!this.subWindow) {
      return;
    }
    try {
      // window.getProperties 获取窗口位置（API 12+）
      const props = await this.subWindow.getWindowProperties();
      const area = props.windowRect;
      Preferences.putSync(PREF_KEY_X, area.left);
      Preferences.putSync(PREF_KEY_Y, area.top);
      LogManager.info(TAG, `Position saved: (${area.left},${area.top})`);
    } catch (e) {
      // getWindowProperties 不可用时静默忽略
      LogManager.warn(TAG, `savePosition failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  /** 展开面板（L1/L2） */
  async expand(width: number = 200, height: number = 80): Promise<void> {
    if (!this.subWindow) {
      return;
    }
    const uiContext = Ohos.getUIContext();
    const w: number = uiContext ? uiContext.vp2px(width) : width;
    const h: number = uiContext ? uiContext.vp2px(height) : height;
    await this.subWindow.resize(w, h);
  }

  /**
   * 展开「图标列 + 面板」合并形态（小米游戏工具箱式）
   * 以球位置为锚点：
   * - 球在左半屏：窗口左边缘不变，向右展开，图标列在左、面板在右
   * - 球在右半屏：窗口右边缘不变，向左展开，面板在左、图标列在右（镜像）
   * 垂直方向做屏幕 clamp，避免面板超出屏幕
   * @param width 合并形态总宽(vp)
   * @param height 合并形态总高(vp)
   * @returns 是否镜像（true=图标列在右侧）
   */
  async expandDock(width: number = 336, height: number = 430): Promise<boolean> {
    if (!this.subWindow) {
      return false;
    }
    try {
      const rect = this.subWindow.getWindowProperties().windowRect;
      const uiContext = Ohos.getUIContext();
      const screenW = uiContext ? uiContext.vp2px(360) : 360;
      const screenH = uiContext ? uiContext.vp2px(800) : 800;
      const w = uiContext ? uiContext.vp2px(width) : width;
      const h = uiContext ? uiContext.vp2px(height) : height;
      const isRight = rect.left + rect.width / 2 > screenW / 2;

      await this.subWindow.resize(w, h);
      let x = isRight ? rect.left + rect.width - w : rect.left;
      let y = rect.top;
      // 屏幕 clamp
      x = Math.max(0, Math.min(x, Math.max(0, screenW - w)));
      y = Math.max(0, Math.min(y, Math.max(0, screenH - h)));
      await this.subWindow.moveWindowTo(x, y);
      return isRight;
    } catch (e) {
      LogManager.warn(TAG, `expandDock failed: ${e instanceof Error ? e.message : String(e)}`);
      return false;
    }
  }

  /**
   * 收起为悬浮球：缩放回球大小，并把球移回图标列所在位置（保持展开前视觉锚点不跳变）
   * @param mirrored expandDock 返回值（图标列是否在右侧）
   * @param ballOffsetX 图标列左缘相对于窗口左缘的偏移(vp)，非镜像传 0
   */
  async collapseToBall(mirrored: boolean = false, ballOffsetX: number = 0): Promise<void> {
    if (!this.subWindow) {
      return;
    }
    try {
      const uiContext = Ohos.getUIContext();
      const w: number = uiContext ? uiContext.vp2px(48) : 48;
      const h: number = uiContext ? uiContext.vp2px(48) : 48;
      const offset: number = uiContext ? uiContext.vp2px(ballOffsetX) : ballOffsetX;
      const rect = this.subWindow.getWindowProperties().windowRect;
      await this.subWindow.resize(w, h);
      // 图标列在右（镜像）时，球应回到窗口右缘，抵消 resize 以左上为基准的偏移
      if (mirrored) {
        await this.subWindow.moveWindowTo(rect.left + offset, rect.top);
      }
    } catch (e) {
      LogManager.warn(TAG, `collapseToBall failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  /** 折叠为悬浮球（保持左上角，仅缩放） */
  async collapse(): Promise<void> {
    if (!this.subWindow) {
      return;
    }
    const uiContext = Ohos.getUIContext();
    const w: number = uiContext ? uiContext.vp2px(48) : 48;
    const h: number = uiContext ? uiContext.vp2px(48) : 48;
    await this.subWindow.resize(w, h);
  }
}
