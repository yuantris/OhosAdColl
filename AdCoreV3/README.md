# AdCoreV3

AdCoreV3 is a clean redesign of the HarmonyOS advertising SDK. It is independent from AdCore/AdCoreV2; V2 compatibility is not a design constraint.

## Current status: alpha.2

Implemented:
- Public format, request, error, result, and handle contracts.
- Request-scoped lifecycle state machine, serial waterfall, timeout/cancellation and late-result cleanup.
- Full-screen adapters for Pangle (穿山甲), GDT (优量汇), and Huawei AdsKit.
- Explicit runtime injection for UIAbility context, UIContext, and WindowStage.
- Separate view contracts for in-tree ads; these are intentionally not full-screen handles.
- PangleFeedViewAdapter and GdtFeedViewAdapter for SDK-owned native-feed views.
- Public AdFeed component: provide an initialized AdCoreFacade, providerId and placementId; it loads, mounts and destroys the feed ad with component lifecycle.
- Public HuaweiBannerAd component for Huawei AdsKit Banner (ad type 8), with supported 360×57 / 360×144 sizes, optional refresh, OAID injection and lifecycle callbacks.
- AdViewHost for advanced/manual composition and host-rendered native material.
- Privacy-consent gate for full-screen and feed requests, plus Huawei Banner.

## Public component coverage

The ready-to-use Feed component is AdFeed. The ready-to-use Banner component currently available is HuaweiBannerAd.

A provider-independent, drop-in AdBanner component that automatically dispatches to Pangle, GDT or Huawei is not implemented yet. Pangle/GDT Banner adapters and their provider-specific view lifecycle implementations still need to be added. AdViewHost is a low-level rendering host; it does not automatically choose a Banner provider or load an ad.

## Feed usage

Create AdProviderRuntime using the host app's UIAbilityContext, UIContext and WindowStage. Construct AdCoreFacade with the real Pangle and GDT app IDs. After the user explicitly accepts the privacy policy, call facade.initialize(true) once. Then use the component in an ArkUI build method:

    AdFeed({
      facade: facade,
      providerId: 'pangle', // or 'gdt'
      placementId: feedPlacementId,
      width: '100%',
      height: 285,
      widthVp: 360,
      heightVp: 285,
      onLoadError: (message: string): void => {
        console.error('Feed ad load failed: ' + message);
      }
    })

The providerId currently supports pangle and gdt for Feed. placementId is the provider's own placement ID. widthVp and heightVp are passed to the SDK as requested creative dimensions. AdFeed loads on appear, releases the view on disappear, and exposes reload() for an explicit refresh.

## Huawei Banner usage

    HuaweiBannerAd({
      adId: huaweiBannerAdId,
      oaid: oaid,
      bannerHeight: 57,
      refreshTime: 60000
    })

The host app must call AdCoreFacade.initialize(true) only after affirmative consent. Removing HuaweiBannerAd detaches the SDK-owned Banner view.

## Format coverage

| Provider | Splash | Interstitial | Rewarded | Banner | Feed |
|---|---|---|---|---|---|
| Pangle | Implemented | Implemented | Implemented | Pending | Implemented |
| GDT | Implemented | Implemented | Implemented | Pending | Implemented |
| Huawei AdsKit | Pending | Implemented | Implemented | Implemented | Pending |

## Validation status

Changes are authored through GitHub. This branch has not been compiled in DevEco Studio or verified on a HarmonyOS device. Confirm ArkTS type compatibility and SDK-version-specific callback signatures in the HarmonyOS toolchain before release.
