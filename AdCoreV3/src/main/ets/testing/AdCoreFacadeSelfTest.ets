import { AdCore } from '../core/AdCore';
import { AdCoreConfig } from '../core/AdCoreConfig';
import { AdErrorCode, AdFormat, AdRequest } from '../core/AdCoreTypes';
import { FakeAdAdapter } from './FakeAdAdapter';

function assertCondition(condition: boolean, message: string): void {
  if (!condition) { throw new Error('AdCoreV3 facade test failed: ' + message); }
}

/** Focused checks for SDK initialization, adapter registration, and request isolation. */
export async function runAdCoreFacadeSelfTests(): Promise<string[]> {
  const passed: string[] = [];
  const core = new AdCore();
  const adapter = new FakeAdAdapter('facade-fake', [AdFormat.Interstitial]);
  core.registerAdapter(adapter);
  core.initialize(new AdCoreConfig(1000, true));
  core.initialize(new AdCoreConfig(1, false));
  assertCondition(core.config.defaultTimeoutMs === 1000, 'repeated initialize should preserve first configuration');
  passed.push('idempotent initialization');

  let duplicateRejected = false;
  try {
    const other = new AdCore();
    other.registerAdapter(new FakeAdAdapter('same', [AdFormat.Interstitial]));
    other.registerAdapter(new FakeAdAdapter('same', [AdFormat.Rewarded]));
  } catch (_) { duplicateRejected = true; }
  assertCondition(duplicateRejected, 'duplicate adapter IDs should be rejected');
  passed.push('adapter registry validation');

  const result = await core.load(new AdRequest('facade-load', AdFormat.Interstitial, 'placement'));
  assertCondition(result.success && result.handle !== null, 'facade should delegate to orchestrator');
  passed.push('facade load and default timeout');

  const uninitialized = new AdCore();
  const failed = await uninitialized.load(new AdRequest('not-initialized', AdFormat.Interstitial, 'placement'));
  assertCondition(!failed.success && failed.error !== null && failed.error.code === AdErrorCode.InvalidState,
    'load before initialize should fail with invalid state');
  passed.push('initialization guard');
  return passed;
}
