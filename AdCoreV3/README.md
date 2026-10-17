# AdCoreV3

AdCoreV3 is a clean redesign of the HarmonyOS advertising SDK. It is developed independently from AdCore and AdCoreV2; V2 compatibility is not a design constraint.

## Design goals

- Request-scoped state: every load/show flow owns an independent session. No process-wide mutable current-ad state or global request queue.
- Explicit lifecycle: a session moves through a validated state machine; late and duplicate vendor callbacks cannot revive a terminal session.
- Orchestration owns policy: waterfall order, timeout, cancellation, fallback, telemetry, and retry policy live above vendor adapters.
- Adapters own vendor details: an adapter translates one vendor SDK's API and callbacks into the stable V3 contract. It does not run the waterfall.
- Format-specific public APIs: splash, interstitial, rewarded, banner, and native ads expose only operations meaningful to that format.
- Clear resource ownership: each loaded handle has one owner and an explicit destroy/release path.
- Testable core: core orchestration depends on interfaces and can be tested with fake adapters without initializing a vendor SDK.
- HarmonyOS-native integration: platform context, UI-thread dispatch, lifecycle observation, and UI hosting are isolated behind platform services.

## Proposed layers

1. **Public API** — SDK initialization, immutable configuration, format-specific entry points.
2. **Orchestrator** — request sessions, waterfall, deadlines, fallback, and cancellation.
3. **Core contracts** — request/result/error models, adapter capability declarations, handles, and lifecycle state.
4. **Vendor adapters** — CSJ, GDT, Huawei, and future providers; no vendor types leak into public APIs.
5. **Platform services** — context, main-thread dispatch, app foreground/background, clock, logging.
6. **UI components** — splash/banner/native host components that bind to handles without owning waterfall policy.

## Lifecycle invariants

- Created → Loading → Ready → Showing → Completed is a valid happy path; formats that do not require an explicit show step may use a documented alternative.
- Failed, Cancelled, and Destroyed are terminal.
- show() is rejected unless the handle is ready and the format supports showing.
- A timeout/cancellation wins once; late callbacks are ignored.
- A vendor handle is destroyed at most once.
- Every public request resolves exactly once with a typed result or typed failure.

## Initial directory plan

- AdCoreV3/Index.ets — public exports
- AdCoreV3/src/main/ets/api/ — public format-specific API
- AdCoreV3/src/main/ets/core/ — session, state machine, result/error, adapter contracts
- AdCoreV3/src/main/ets/orchestration/ — waterfall and timeout/cancellation
- AdCoreV3/src/main/ets/adapters/ — vendor-specific adapters
- AdCoreV3/src/main/ets/platform/ — HarmonyOS runtime services
- AdCoreV3/src/main/ets/formats/ — splash, interstitial, rewarded, banner, native
- AdCoreV3/src/main/ets/telemetry/ — structured lifecycle events and diagnostics
- AdCoreV3/src/main/ets/testing/ — fake adapters and test fixtures

## Implementation milestones

1. **Core foundation** — models, lifecycle state machine, adapter contract, request session, fake-adapter tests.
2. **Orchestration** — serial waterfall, per-request timeout/cancellation, deterministic fallback, exactly-once completion.
3. **Vendor integration** — add providers behind adapters, one provider at a time.
4. **Ad formats** — rewarded/interstitial first, then splash and component-hosted formats.
5. **Production hardening** — cache ownership/TTL, privacy gates, diagnostics, lifecycle cleanup, integration documentation.

## Non-goals for the first milestone

- No V2 API compatibility layer.
- No parallel bidding before serial waterfall and cancellation semantics are stable.
- No vendor-specific types in the public API.
- No global queue that serializes unrelated requests.
- No automatic reward granting solely from a client-side completion callback; reward verification remains an application/server policy.

## Engineering rule

Each milestone must be independently reviewable. Vendor integration should begin only after the core contracts and fake-adapter tests define the expected behavior.
