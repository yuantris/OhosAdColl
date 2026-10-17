import { common, Context } from '@kit.AbilityKit'
import { UIContext } from '@kit.ArkUI'

/**
 * 全局 Context 持有器（.ts 文件，供网络库等非 ArkUI 模块获取应用上下文）
 *
 * 持久化缓存（cacheDir 文件存储）依赖应用 Context：
 * 需在应用初始化阶段（如 AbilityStage.onCreate / EntryAbility.onWindowStageCreate）
 * 调用 setNetContext(this.context) 注入；未注入时网络库自动降级为纯内存缓存。
 */
export class ContextHolder {
  /** 应用上下文（由业务初始化时注入） */
  private static context: string = 'zy_sdk_context'
  private static uiContext: string = 'zy_sdk_uiContext'

  /**
   * 注入应用上下文（幂等，重复调用以后一次为准）
   * @param ctx 应用级或 Ability 级 Context
   */
  public static setContext(ctx: Context): void {
    AppStorage.setOrCreate(this.context, ctx)
  }

  /**
   * 注入UI上下文（幂等，重复调用以后一次为准）
   * @param ctx UIContext
   */
  public static setUIContext(ctx: UIContext): void {
    AppStorage.setOrCreate(this.uiContext, ctx)
  }

  /**
   * 获取已注入的应用上下文
   * @returns Context；未注入时返回 undefined，调用方需自行降级处理
   */
  public static getContext(): Context | undefined {
    return AppStorage.get<Context>(this.context)
  }

  /**
   * 获取已注入的应用上下文
   * @returns common.UIAbilityContext；未注入时返回 undefined，调用方需自行降级处理
   */
  public static getUIAbilityContext(): common.UIAbilityContext | undefined {
    return AppStorage.get<common.UIAbilityContext>(this.context)
  }

  /**
   * 获取UI上下文
   * @returns UIContext；未注入时返回 undefined，调用方需自行降级处理
   */
  public static getUIContext(): UIContext | undefined {
    return AppStorage.get<UIContext>(this.uiContext)
  }
}
