import { LogManager } from '../logger/LogManager';
import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

const TAG = 'LifecycleManager';

export type WindowStageActiveCallback = (ability: UIAbility, windowStage: window.WindowStage) => void;

export class LifecycleManager {
  private static instance: LifecycleManager | null = null;
  private windowStageActiveCallbacks: Map<string, WindowStageActiveCallback> = new Map();

  private constructor() {}

  public static getInstance(): LifecycleManager {
    if (!LifecycleManager.instance) {
      LifecycleManager.instance = new LifecycleManager();
    }
    return LifecycleManager.instance;
  }

  /**
   * 注册窗口活跃回调
   * @param uniqueId 组件唯一标识（如 `${adId}_${uniqueId}`）
   * @param callback 窗口活跃时的回调
   */
  public registerWindowStageActive(uniqueId: string, callback: WindowStageActiveCallback): void {
    if (this.windowStageActiveCallbacks.has(uniqueId)) {
      LogManager.warn(TAG, `Callback [${uniqueId}] already registered, skipping duplicate registration`);
      return;
    }
    this.windowStageActiveCallbacks.set(uniqueId, callback);
    LogManager.info(TAG, `Registered windowStageActive callback: ${uniqueId}`);
  }

  /**
   * 注销窗口活跃回调
   * @param uniqueId 组件唯一标识
   */
  public unregisterWindowStageActive(uniqueId: string): void {
    this.windowStageActiveCallbacks.delete(uniqueId);
    LogManager.info(TAG, `Unregistered windowStageActive callback: ${uniqueId}`);
  }

  /**
   * 分发窗口活跃事件到所有已注册的回调
   * 由 RequestApplication.onWindowStageActive 调用
   */
  public dispatchWindowStageActive(ability: UIAbility, windowStage: window.WindowStage): void {
    LogManager.debug(TAG, `Dispatching windowStageActive to ${this.windowStageActiveCallbacks.size} listeners`);
    for (const [id, callback] of this.windowStageActiveCallbacks) {
      try {
        callback(ability, windowStage);
      } catch (e) {
        LogManager.error(TAG, `Error in windowStageActive callback [${id}]: ${e}`);
      }
    }
  }
}
