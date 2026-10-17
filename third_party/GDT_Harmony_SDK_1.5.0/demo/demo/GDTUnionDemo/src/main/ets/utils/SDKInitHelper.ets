import { common } from '@kit.AbilityKit';
import { GDTAdSDK, GDTAdSDKConfig, GDTAdSDKStartResult } from '@gdt/gdt-union-sdk';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from './LogUtil';
import { ToastUtil } from './ToastUtil';

/**
 * SDK 初始化辅助类，统一管理 GDTAdSDK 的 init 和 start 流程
 */
export class SDKInitHelper {
  private static readonly TAG = 'SDKInitHelper';

  private constructor() {
  }

  /**
   * 初始化 SDK（不采集用户信息）
   * @param context UIAbilityContext
   * @param appId 应用ID
   */
  public static initSDK(context: common.UIAbilityContext, appId: string): void {
    const config: GDTAdSDKConfig = {
      appId: appId
    };
    LogUtil.info(`${SDKInitHelper.TAG} SDK Version: ${GDTAdSDK.getSDKVersion()}`);
    GDTAdSDK.init(context, config);
    LogUtil.info(`${SDKInitHelper.TAG} SDK init 完成, appId: ${config.appId}`);
  }

  /**
   * 启动 SDK，启动后可执行全部功能
   * 应在 init 之后调用
   * @returns Promise<GDTAdSDKStartResult>
   */
  public static startSDK(): Promise<void> {
    return GDTAdSDK.start()
      .then((result: GDTAdSDKStartResult) => {
        LogUtil.info(`${SDKInitHelper.TAG} SDK 启动成功`);
        ToastUtil.showToast('SDK 初始化成功');
      })
      .catch((err: BusinessError) => {
        LogUtil.error(`${SDKInitHelper.TAG} SDK 启动失败：${err.code} ${err.message}`);
        ToastUtil.showToast(`SDK 初始化失败：${err.message}`);
      });
  }
}
