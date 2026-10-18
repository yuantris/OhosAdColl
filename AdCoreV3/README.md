# AdCoreV3

AdCoreV3 is a clean redesign of the HarmonyOS advertising SDK. It is developed independently from AdCore and AdCoreV2; V2 compatibility is not a design constraint.

## Current status: Core lifecycle, alpha.2

Implemented:
- Public format, request, error, result, and handle contracts.
- Request-scoped lifecycle state machine.
- Vendor adapter interface with format capability declarations.
- Serial waterfall orchestrator with a shared request deadline.
- Late-handle cleanup when a timed-out or cancelled adapter eventually returns.
- SDK-owned managed handle enforcing one show, lifecycle callback forwarding, and idempotent destruction.
- `runAdCoreSelfTests()` covering waterfall fallback, managed handle lifecycle, timeout, cancellation, and late cleanup.
- Fake adapter/handle fixtures for deterministic integration testing.

Not yet implemented:
- Vendor SDK adapters, and local execution of the self-tests.
- Format-specific UI components and public format facades.
- Cache, telemetry pipeline, and integration tests.
- Local HarmonyOS compilation; this commit was authored through GitHub and needs verification in DevEco Studio.

## Adapter lifecycle contract

Adapters return a raw vendor-backed handle. If it implements `setLifecycleListener`, the managed wrapper subscribes and receives completion/failure events. Vendor close/failure callbacks should forward to that listener; vendor types remain inside the adapter.

## Design goals

- Every load/show flow owns an independent request session.
- Terminal states cannot return to active states.
- Orchestration owns timeout, cancellation, fallback, and waterfall policy.
- Adapters translate vendor APIs and callbacks; they do not run the waterfall.
- Vendor types never leak into the public API.
- Every loaded handle has one owner and an explicit destroy/release path.

## Initial layout

- `Index.ets` — public exports
- `src/main/ets/core/` — request models, adapter contract, lifecycle state machine
- `src/main/ets/orchestration/` — waterfall and timeout/cancellation
- `src/main/ets/adapters/` — vendor-specific adapters (next milestone)
- `src/main/ets/platform/` — HarmonyOS runtime services (next milestone)
- `src/main/ets/formats/` — splash, interstitial, rewarded, banner, native (next milestone)
- `src/main/ets/telemetry/` — lifecycle events and diagnostics (next milestone)
- `src/main/ets/testing/` — fake adapters and fixtures

## Lifecycle

The request session models Created, Loading, Ready, Showing, Completed, Failed, Cancelled, and Destroyed. `AdManagedHandle` now owns the per-ad lifecycle after loading.

## Milestones

1. Core contracts, lifecycle state machine, request session, and serial waterfall.
2. Fake adapter and tests for timeout, cancellation, duplicate/late callbacks, and cleanup.
3. Vendor integrations, one adapter at a time.
4. Format-specific APIs and UI host components.
5. Cache ownership/TTL, privacy gates, telemetry, diagnostics, and integration docs.

## Non-goals for the first milestone

- No V2 compatibility layer.
- No parallel bidding until serial waterfall and cancellation semantics are stable.
- No vendor-specific types in public API.
- No global queue that serializes unrelated requests.
- No client-only guarantee of reward fulfillment; reward verification remains an application/server policy.
