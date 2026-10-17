/**
 * Created by Wuzejian on 2023/12/13
 * Usage: Toast 弹窗工具类
 */
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import { DemoConstants } from '../entryability/DemoConstants';


export class ToastUtil {
  /**
   * Toast 弹窗
   * @param message
   * @param duration 默认值3000ms
   */
  public static showToast(message: string | Resource): void; /* 第一个签名 */

  /**
   * Toast 弹窗
   * @param message
   * @param duration 默认值1500ms，取值区间：1500ms-10000ms。若小于1500ms则取默认值，若大于10000ms则取上限值10000ms。
   */
  public static showToast(message: string | Resource, duration: number): void; /* 第二个签名 */

  public static showToast(message: string | Resource, duration?: number): void { /* 实现签名 */
    try {
      promptAction.showToast({
        message: message,
        duration: duration ? duration : 3000
      });
    } catch (error) {
      let message = (error as BusinessError).message
      let code = (error as BusinessError).code
      console.error(`showToast args error code is ${code}, message is ${message}`);
    }
  }

  public static showToastOnMainWindow(message: string | Resource, duration?: number): void { /* 实现签名 */
    DemoConstants.windowStage.getMainWindowSync().getUIContext().getPromptAction()
    try {
      DemoConstants.windowStage.getMainWindowSync().getUIContext().getPromptAction().showToast({
        message: message,
        duration: duration ? duration : 3000
      });
    } catch (error) {
      let message = (error as BusinessError).message
      let code = (error as BusinessError).code
      console.error(`showToast args error code is ${code}, message is ${message}`);
    }
  }
}