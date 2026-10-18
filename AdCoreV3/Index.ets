/** AdCoreV3 public entry point. Vendor SDK types are intentionally not exported. */
export { AdError, AdErrorCode, AdFormat, AdHandle, AdHandleLifecycleListener, AdLoadResult, AdRequest, AdSessionState } from './src/main/ets/core/AdCoreTypes';
export { AdCoreConfig } from './src/main/ets/core/AdCoreConfig';
export { AdCore } from './src/main/ets/core/AdCore';
export { AdAdapter, adapterSupports } from './src/main/ets/core/AdAdapter';
export { AdRequestSession } from './src/main/ets/core/AdRequestSession';
export { AdManagedHandle } from './src/main/ets/core/AdManagedHandle';
export { AdOrchestrator } from './src/main/ets/orchestration/AdOrchestrator';
export { FakeAdAdapter, FakeAdHandle } from './src/main/ets/testing/FakeAdAdapter';
export { runAdCoreSelfTests } from './src/main/ets/testing/AdCoreSelfTest';
export { runAdCoreFacadeSelfTests } from './src/main/ets/testing/AdCoreFacadeSelfTest';
