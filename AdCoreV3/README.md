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

Added in this step:
- A separate `AdViewAdapter` / `AdViewHandle` contract for Banner and Native/Feed rendering. It is intentionally distinct from full-screen `AdHandle` because these ads live inside the host ArkUI tree.
- `AdViewHost`, a single ArkUI component for provider-rendered Banner, provider-rendered Feed, and host self-rendered native material.
- Explicit lifecycle split: Banner appearance/disappearance is delegated to the provider component (it owns load/refresh/close); Feed mounts its loaded handle and releases it when the host slot disappears; SelfRender lays out returned material and releases an optional host-owned handle on detach.

Not yet implemented:
- Concrete provider-view adapters that connect each vendor SDK's actual banner/feed objects to `AdViewHost`. The V2 implementation confirms Huawei Banner is a provider-rendered AdsKit component, while CSJ and Tencent feed ads use native-express/native-ad objects; those need different mount paths behind this contract.
- Huawei splash and UI-rendered banner/native/feed formats. Huawei splash and feed in V2 depend on host-rendered ArkUI components; V3 needs a separate render-host contract rather than pretending they are ordinary full-screen handles.
- Automatic OAID/privacy-consent integration; the host must gate initialization/load on its consent flow.
- Local HarmonyOS compilation and device validation.

## Unified ArkUI view host

`AdViewHost` is the single public host component. Use `kind: AdViewKind.Banner` for a provider component that owns its own loading/refresh lifecycle, `kind: AdViewKind.Feed` for a loaded provider feed view, and `kind: AdViewKind.SelfRender` for native material rendered by the host. Vendor-specific ArkUI content is supplied with the `providerContent` builder slot; no vendor SDK type leaks into the public API.

```ts
import { AdViewHost, AdViewKind, AdNativeMaterial } from '@zysdk/ad-core-v3';

// Host-rendered native material:
AdViewHost({
  kind: AdViewKind.SelfRender,
  material: nativeMaterial
})

// Provider-rendered Banner: the vendor component owns loading, refresh and close.
AdViewHost({
  kind: AdViewKind.Banner,
  onBannerAppear: () => bannerController.load(),
  onBannerDisappear: () => bannerController.dispose(),
  providerContent: (): void => {
    // Place the provider's ArkUI banner component here.
    // The provider component manages its own ad lifecycle.
  }
})

// Provider-rendered Feed: the host calls handle.mount() and handle.destroy().
AdViewHost({
  kind: AdViewKind.Feed,
  handle: feedViewHandle,
  providerContent: (): void => {
    // Place the provider's ArkUI feed node/component here.
  }
})
```

The host is a rendering/lifecycle boundary, not yet a concrete vendor bridge. Each provider adapter still needs to provide the correct SDK-specific banner/feed node or material before that format is production-ready.

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

const providerSlots = new Map<string, string>([
  ['placement.csj', csjSlotId],
  ['placement.tencent', tencentPosId],
  ['placement.huawei', huaweiAdId]
]);
const result = await core.load(new AdRequest(
  'home-interstitial-' + Date.now(), AdFormat.Interstitial, 'home-interstitial', 0, providerSlots
));
if (result.success && result.handle !== null) {
  await result.handle.show();
}
```

Register adapters before initialize(). For a multi-provider waterfall, use the logical placementId plus provider-specific IDs in extras. The adapters resolve `placement.csj`, `placement.tencent`, and `placement.huawei` independently; when a key is absent, they fall back to placementId. Example: `new Map<string, string>([['placement.csj', csjSlotId], ['placement.tencent', tencentPosId], ['placement.huawei', huaweiAdId]])`.

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
