import { Log, Preferences } from "@zycore/common";

const SHOW_GUIDE_KEY = "ZY_ShowGuideKey";
const SHOW_DIALOG_KEY = "ZY_ShowDialogKey";

export class Launcher {
  /**
   * 同步检查隐私对话框显示状态
   * @param callback 回调函数，返回是否显示对话框
   */
  static checkPrivateDialog(callback: (showDialog: boolean) => void) {
    try {
      const show = Preferences.getBooleanSync(SHOW_DIALOG_KEY, true);
      callback(show);
    } catch (error) {
      Log.error("checkPrivateDialog error:", error);
      callback(true); // 默认显示
    }
  }

  /**
   * 异步检查隐私对话框显示状态
   * @returns Promise 返回是否显示对话框
   */
  static async checkPrivateDialogAsync(): Promise<boolean> {
    try {
      return await Preferences.getBoolean(SHOW_DIALOG_KEY, true);
    } catch (error) {
      Log.error("checkPrivateDialogAsync error:", error);
      return true; // 默认显示
    }
  }

  /**
   * 同步检查引导页显示状态
   * @param callback 回调函数，返回是否显示引导页
   */
  static checkGuide(callback: (showGuide: boolean) => void) {
    try {
      const show = Preferences.getBooleanSync(SHOW_GUIDE_KEY, true);
      callback(show);
    } catch (error) {
      Log.error("checkGuide error:", error);
      callback(true); // 默认显示
    }
  }

  /**
   * 异步检查引导页显示状态
   * @returns Promise 返回是否显示引导页
   */
  static async checkGuideAsync(): Promise<boolean> {
    try {
      return await Preferences.getBoolean(SHOW_GUIDE_KEY, true);
    } catch (error) {
      Log.error("checkGuideAsync error:", error);
      return true; // 默认显示
    }
  }

  static async authorizationPrivacyPolicy(): Promise<void> {
    try {
      return await Preferences.put(SHOW_DIALOG_KEY, false);
    } catch (error) {
      Log.error("authorizationPrivacyPolicy error:", error);
    }
  }

  static async finishGuideBrowsing(): Promise<void> {
    try {
      return await Preferences.put(SHOW_GUIDE_KEY, false);
    } catch (error) {
      Log.error("finishGuideBrowsing error:", error);
    }
  }

}