import { PromptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from './LogUtil';

export class ToastUtil {
  private static promptAction?: PromptAction;

  /**
   * 初始化 ToastUtil，在 onWindowStageCreate 中调用
   */
  public static init(uiContext: UIContext): void {
    ToastUtil.promptAction = uiContext.getPromptAction();
  }

  public static showToast(message: string | Resource, duration?: number): void {
    try {
      ToastUtil.promptAction?.showToast({
        message: message,
        duration: duration ? duration : 3000
      });
    } catch (error) {
      const message = (error as BusinessError).message;
      const code = (error as BusinessError).code;
      LogUtil.error(`showToast error: ${code}, ${message}`);
    }
  }
}
