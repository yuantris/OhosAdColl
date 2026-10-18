import { UIAbilityContext } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AdRequest } from '../core/AdCoreTypes';

/**
 * Host objects required by HarmonyOS ad SDKs.
 * The host application supplies these after obtaining its UIAbility and window.
 */
export class AdProviderRuntime {
  readonly context: UIAbilityContext;
  readonly uiContext: UIContext;
  readonly windowStage: window.WindowStage;
  readonly oaid: string;

  constructor(context: UIAbilityContext, uiContext: UIContext, windowStage: window.WindowStage, oaid: string = '') {
    this.context = context;
    this.uiContext = uiContext;
    this.windowStage = windowStage;
    this.oaid = oaid;
  }
}

/** App/vendor configuration is explicit; no sample placement IDs are embedded in V3. */
export function resolvePlacementId(request: AdRequest, providerId: string): string {
  const providerPlacement = request.extras.get('placement.' + providerId);
  return providerPlacement !== undefined && providerPlacement.length > 0 ? providerPlacement : request.placementId;
}

export class AdProviderConfig {
  readonly appId: string;
  readonly debug: boolean;

  constructor(appId: string, debug: boolean = false) {
    this.appId = appId;
    this.debug = debug;
  }
}
