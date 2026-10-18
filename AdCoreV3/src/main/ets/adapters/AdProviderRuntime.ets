import { UIAbilityContext } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

/**
 * Host objects required by HarmonyOS ad SDKs.
 * The host application supplies these after obtaining its UIAbility and window.
 */
export class AdProviderRuntime {
  readonly context: UIAbilityContext;
  readonly uiContext: UIContext;
  readonly windowStage: window.WindowStage;

  constructor(context: UIAbilityContext, uiContext: UIContext, windowStage: window.WindowStage) {
    this.context = context;
    this.uiContext = uiContext;
    this.windowStage = windowStage;
  }
}

/** App/vendor configuration is explicit; no sample placement IDs are embedded in V3. */
export class AdProviderConfig {
  readonly appId: string;
  readonly debug: boolean;

  constructor(appId: string, debug: boolean = false) {
    this.appId = appId;
    this.debug = debug;
  }
}
