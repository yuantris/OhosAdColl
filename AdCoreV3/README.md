# AdCoreV3

AdCoreV3 is a redesigned HarmonyOS advertising SDK, independent from AdCore/AdCoreV2.

## Public drop-in components

### AdFeed

AdFeed automatically loads and mounts a provider-owned native-feed view, and releases it when removed from the ArkUI tree. Supported provider IDs: `pangle`, `gdt`.

### AdBanner

AdBanner is the unified Banner component for `pangle`, `gdt`, and `huawei`. It dispatches Pangle/GDT to their SDK adapters and renders Huawei AdsKit through HuaweiBannerAd. The host app must provide a real placement ID for the selected provider.

```ts
AdBanner({
  facade: facade,
  providerId: 'pangle', // 'pangle', 'gdt', or 'huawei'
  placementId: bannerPlacementId,
  width: '100%',
  height: 57,
  widthVp: 360,
  heightVp: 57,
  refreshTime: 60000, // Huawei milliseconds; Pangle/GDT use provider SDK refresh behavior
  onLoadError: (message: string): void => {
    console.error('Banner load failed: ' + message);
  }
})
```

For Huawei, `heightVp` is normalized to the supported 57 or 144 vp and `oaid` is optional. Pangle/GDT dimensions are passed to their SDK Banner slots. `reload()` is available for Pangle/GDT component references; Huawei refresh is managed by AdsKit when configured.

### AdFeed example

```ts
AdFeed({
  facade: facade,
  providerId: 'gdt', // or 'pangle'
  placementId: feedPlacementId,
  width: '100%',
  height: 285,
  widthVp: 360,
  heightVp: 285,
  onLoadError: (message: string): void => {
    console.error('Feed load failed: ' + message);
  }
})
```

## Initialization and privacy

Create `AdProviderRuntime` from the host app's `UIAbilityContext`, `UIContext`, and `WindowStage`. Construct `AdCoreFacade` with the real Pangle/GDT app IDs. Call `facade.initialize(true)` only after affirmative user privacy consent. Call `facade.revokeConsent()` when consent is withdrawn. Constructing the facade does not initialize vendor SDKs.

## Format coverage

| Provider | Splash | Interstitial | Rewarded | Banner | Feed |
|---|---|---|---|---|---|
| Pangle | Implemented | Implemented | Implemented | Implemented | Implemented |
| GDT | Implemented | Implemented | Implemented | Implemented | Implemented |
| Huawei AdsKit | Pending | Implemented | Implemented | Implemented | Pending |

## Validation status

This branch has not been compiled in DevEco Studio or verified on a HarmonyOS device. Verify ArkTS type compatibility and the exact SDK callback signatures against the configured HarmonyOS SDK versions before release.
