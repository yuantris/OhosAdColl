import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DemoConstants } from '../constants/DemoConstants';
import { LogUtil } from './LogUtil';

/**
 * 广告页横竖屏旋转辅助工具
 *
 * 预览/调试场景下根据 AdPageParam.orientation 自动旋转窗口方向，
 * 离开广告页时恢复自动旋转，避免整个 Demo App 卡在横屏。
 *
 * orientation 取值约定：1=竖屏(portrait)，2=横屏(landscape)
 */
export class OrientationHelper {
  /**
   * 根据方向参数旋转窗口，返回 Promise 以便调用方 await 旋转完成后再执行后续操作。
   *
   * 禁止在 aboutToDisappear 中 await 调用：async/await 会令组件被 Promise 闭包持有，
   * 阻止垃圾回收。生命周期销毁场景改用 restoreAutoRotation()。
   *
   * @param orientation 屏幕方向（1=竖屏，2=横屏）；未传或非 2 均视为竖屏
   * @returns 旋转完成（或失败）后 resolve
   */
  public static async applyOrientation(orientation?: number): Promise<void> {
    try {
      const target = orientation === 2 ?
        window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT;
      const promise = DemoConstants.windowStage.getMainWindowSync().setPreferredOrientation(target);
      if (promise) {
        await promise.catch((err: BusinessError) => {
          LogUtil.error(`OrientationHelper.applyOrientation failed: ${err.message}`);
        });
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogUtil.error(`OrientationHelper.applyOrientation failed: ${msg}`);
    }
  }

  /**
   * 恢复自动旋转方向（广告页离开时调用）。
   *
   * 与 DemoAbility 初始策略一致，回到 home 后支持横竖旋转。
   *
   * fire-and-forget：aboutToDisappear 中禁止使用 async/await（会阻止组件垃圾回收），
   * 故不 await，旋转在后台异步完成。失败仅记录日志，不影响页面销毁流程；调用方无需感知结果。
   */
  public static restoreAutoRotation(): void {
    try {
      const promise = DemoConstants.windowStage.getMainWindowSync()
        .setPreferredOrientation(window.Orientation.AUTO_ROTATION);
      if (promise) {
        promise.catch((err: BusinessError) => {
          LogUtil.error(`OrientationHelper.restoreAutoRotation failed: ${err.message}`);
        });
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogUtil.error(`OrientationHelper.restoreAutoRotation failed: ${msg}`);
    }
  }
}
