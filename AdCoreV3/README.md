# AdCoreV3

AdCoreV3 is a clean redesign of the HarmonyOS advertising SDK. It is independent from AdCore/AdCoreV2; V2 compatibility is not a design constraint.

## Current status: real full-screen adapters, alpha.2

Implemented:
- Public format, request, error, result, and handle contracts.
- Request-scoped lifecycle state machine and serial waterfall.
- Request deadline, cancellation, late-result cleanup, and SDK default timeout.
- SDK-owned AdManagedHandle lifecycle wrapper.
- Real full-screen adapters based on V2-verified HarmonyOS SDK calls:
  - CsjAdAdapter: splash, interstitial, rewarded video.
  - TencentAdAdapter: splash, interstitial, rewarded video.
  - HuaweiAdAdapter: interstitial and rewarded video.
- Explicit runtime injection for UIAbility context, UIContext, and WindowStage.
- Vendor SDK dependencies declared in this HAR module.

Not yet implemented:
- Huawei splash and UI-rendered banner/native/feed formats. Huawei splash and feed in V2 depend on host-rendered ArkUI components; V3 needs a separate render-host contract rather than pretending they are ordinary full-screen handles.
- Automatic OAID/privacy-consent integration; the host must gate initialization/load on its consent flow.
- Local HarmonyOS compilation and device validation.

## Provider setup

The host app obtains its UIAbilityContext, UIContext, and window.WindowStage, then injects them into AdProviderRuntime. Supply the app ID for CSJ/Tencent from the host's own configuration; do not rely on V2 sample IDs.

```ts
import {
  AdCore, AdCoreConfig, AdFormat, AdRequest,
  AdProviderConfig, AdProviderRuntime,
  CsjAdAdapter, TencentAdAdapter, HuaweiAdAdapter
} from '@zysdk/ad-core-v3';

const runtime = new AdProviderRuntime(abilityContext, uiContext, windowStage);
const core = new AdCore();
core.registerAdapter(new CsjAdAdapter(runtime, new AdProviderConfig(csjAppId, debug)));
core.registerAdapter(new TencentAdAdapter(runtime, new AdProviderConfig(tencentAppId, debug)));
core.registerAdapter(new HuaweiAdAdapter(runtime));
core.initialize(new AdCoreConfig(10000, debug));

const result = await core.load(new AdRequest(
  'home-interstitial-' + Date.now(),
  AdFormat.Interstitial,
  configuredPlacementId
));
if (result.success && result.handle !== null) {
  await result.handle.show();
}
```

Register adapters before initialize(). The placementId passed to AdRequest is the real placement ID for each provider, so do not put multiple providers with different placement IDs in the same waterfall until a placement mapping strategy is configured. The current serial waterfall passes the same request placement ID to each adapter.

## Format coverage

| Provider | Splash | Interstitial | Rewarded | Banner / feed / native |
|---|---|---|---|---|
| CSJ | Implemented | Implemented | Implemented | Render-host integration pending |
| Tencent GDT | Implemented | Implemented | Implemented | Render-host integration pending |
| Huawei AdsKit | Host-render contract pending | Implemented | Implemented | Render-host integration pending |

Rewarded completion is forwarded only when the vendor signals completion/reward. The app should still apply its own reward policy and server-side verification where appropriate.

## Lifecycle and ownership

- The orchestrator owns timeout, cancellation, fallback, and waterfall policy.
- Adapters translate vendor callbacks and never run the waterfall.
- AdManagedHandle enforces one show and idempotent destruction.
- Vendor SDK objects do not appear in the public API.

## Validation status

The implementation was authored through GitHub. It has not been compiled in DevEco Studio or verified on a HarmonyOS device yet. API-signature issues, especially SDK-version-specific listener declarations, must be confirmed by the project's HarmonyOS toolchain.
