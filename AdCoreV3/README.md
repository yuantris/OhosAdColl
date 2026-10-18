# AdCoreV3

AdCoreV3 is a clean redesign of the HarmonyOS advertising SDK. It is independent from AdCore/AdCoreV2; V2 compatibility is not a design constraint.

## Current status: real full-screen adapters, alpha.2

Implemented:
- Public format, request, error, result, and handle contracts.
- Request-scoped lifecycle state machine and serial waterfall.
- Request deadline, cancellation, late-result cleanup, and SDK default timeout.
- SDK-owned AdManagedHandle lifecycle wrapper.
- Real full-screen adapters based on V2-verified HarmonyOS SDK calls:
  - `PangleAdAdapter`: splash, interstitial, rewarded video. Pangle (穿山甲) is the product name; `@csj/openadsdk` is the SDK package name.
  - `GdtAdAdapter`: splash, interstitial, rewarded video. GDT/优量汇 is the ad platform name; Tencent is the parent company.
  - HuaweiAdAdapter: interstitial and rewarded video.
- Explicit runtime injection for UIAbility context, UIContext, and WindowStage.
- Vendor SDK dependencies declared in this HAR module.

Added in this step:
- A separate `AdViewAdapter` / `AdViewHandle` contract for Banner and Native/Feed rendering. It is intentionally distinct from full-screen `AdHandle` because these ads live inside the host ArkUI tree.
- `AdViewHost`, a single ArkUI component for provider-rendered Banner, provider-rendered Feed, and host self-rendered native material.
- `HuaweiBannerAd`, a concrete AdsKit banner component using ad type 8, supported 360×57 / 360×144 sizes, optional 30–120 second refresh, OAID injection, and normalized lifecycle callbacks.
- Explicit lifecycle split: Banner appearance/disappearance is delegated to the provider component (it owns load/refresh/close); Feed mounts its loaded handle and releases it when the host slot disappears; SelfRender lays out returned material and releases an optional host-owned handle on detach.

Not yet implemented:
- Concrete `PangleFeedViewAdapter` and `GdtFeedViewAdapter` load native feed ads and expose their SDK `NodeController` to `AdViewHost`; Huawei banner now has a provider-owned `HuaweiBannerAd` component. The V2 implementation confirms Huawei Banner is a provider-rendered AdsKit component, while Pangle and GDT feed ads use native-express/native-ad objects; their SDK-owned render and destruction paths are kept separate.
- Huawei splash and UI-rendered banner/native/feed formats. Huawei splash and feed in V2 depend on host-rendered ArkUI components; V3 needs a separate render-host contract rather than pretending they are ordinary full-screen handles.
- `AdCoreFacade` is the host-facing entry point. SDK initialization and ad requests are blocked by default until the host confirms explicit privacy consent. Pangle/GDT feed and Huawei banner paths are guarded too.
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
    // Example: HuaweiBannerAd({ adId: huaweiBannerId, oaid })
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

The host is a rendering/lifecycle boundary. Pangle/GDT feed adapters return provider-owned `NodeController` instances, and `AdViewHost` mounts them with `NodeContainer`. Feed adapters require the same `AdProviderConfig` as their full-screen adapter; a shared registry coalesces startup and rejects conflicting app configuration. Local HarmonyOS compilation and device validation are still required.

## Provider setup

The host app obtains its UIAbilityContext, UIContext, and window.WindowStage, then injects them into AdProviderRuntime. Supply the app ID for Pangle/GDT from the host's own configuration; do not rely on V2 sample IDs.

```ts
import {
  AdCore, AdCoreConfig, AdFormat, AdRequest,
  AdProviderConfig, AdProviderRuntime,
  PangleAdAdapter, GdtAdAdapter, HuaweiAdAdapter,
  PangleFeedViewAdapter, GdtFeedViewAdapter
} from '@zysdk/ad-core-v3';

const runtime = new AdProviderRuntime(abilityContext, uiContext, windowStage);
const core = new AdCore();
core.registerAdapter(new PangleAdAdapter(runtime, new AdProviderConfig(pangleAppId, debug)));
core.registerAdapter(new GdtAdAdapter(runtime, new AdProviderConfig(gdtAppId, debug)));
// View adapters share the same SDK initialization registry and app configuration.
const pangleViewAdapter = new PangleFeedViewAdapter(runtime, new AdProviderConfig(pangleAppId, debug));
const gdtViewAdapter = new GdtFeedViewAdapter(runtime, new AdProviderConfig(gdtAppId, debug));
core.registerAdapter(new HuaweiAdAdapter(runtime));
core.initialize(new AdCoreConfig(10000, debug));

const providerSlots = new Map<string, string>([
  ['placement.pangle', pangleSlotId],
  ['placement.gdt', gdtPosId],
  ['placement.huawei', huaweiAdId]
]);
const result = await core.load(new AdRequest(
  'home-interstitial-' + Date.now(), AdFormat.Interstitial, 'home-interstitial', 0, providerSlots
));
if (result.success && result.handle !== null) {
  await result.handle.show();
}
```

Register adapters before initialize(). For a multi-provider waterfall, use the logical placementId plus provider-specific IDs in extras. The adapters resolve `placement.pangle`, `placement.gdt`, and `placement.huawei` independently; when a key is absent, they fall back to placementId. Example: `new Map<string, string>([['placement.pangle', pangleSlotId], ['placement.gdt', gdtPosId], ['placement.huawei', huaweiAdId]])`.

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


## Mandatory privacy consent

Use `AdCoreFacade` as the host-facing entry point. Constructing it only wires adapters; it does not initialize vendor SDKs. After displaying the privacy policy and receiving the user's explicit agreement, call `initialize(true)`. Never pass true before that user action. Declining or withdrawing consent must block ad requests.

```ts
const facade = new AdCoreFacade(
  runtime,
  new AdProviderConfig(pangleAppId, debug),
  new AdProviderConfig(gdtAppId, debug)
);

// Only in the affirmative branch of the actual consent UI:
facade.initialize(true);
const result = await facade.load(request);

// On decline/withdrawal:
facade.revokeConsent();
```

The process-wide gate starts at `Unknown`. The SDK registry rejects initialization unless consent is `Granted`; Huawei full-screen and Banner paths are guarded separately. Revocation blocks future requests, but third-party SDKs already initialized in-process may not be unloadable, so detach active ad views and follow each provider's privacy APIs.
