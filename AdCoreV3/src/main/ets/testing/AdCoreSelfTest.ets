import { AdError, AdErrorCode, AdFormat, AdRequest, AdSessionState } from '../core/AdCoreTypes';
import { AdManagedHandle } from '../core/AdManagedHandle';
import { AdRequestSession } from '../core/AdRequestSession';
import { AdOrchestrator } from '../orchestration/AdOrchestrator';
import { FakeAdAdapter, FakeAdHandle } from './FakeAdAdapter';

function assertCondition(condition: boolean, message: string): void {
  if (!condition) { throw new Error('AdCoreV3 self-test failed: ' + message); }
}

/** Runs lightweight core checks without a vendor SDK or external test framework. */
export async function runAdCoreSelfTests(): Promise<string[]> {
  const passed: string[] = [];

  const first = new FakeAdAdapter('fake-fail', [AdFormat.Interstitial]);
  first.shouldFail = true;
  const second = new FakeAdAdapter('fake-success', [AdFormat.Interstitial]);
  const fallback = await new AdOrchestrator().load(
    new AdRequest('self-test-fallback', AdFormat.Interstitial, 'placement-test', 1000),
    [first, second]
  );
  assertCondition(fallback.success && fallback.handle !== null, 'waterfall should fall back to the second adapter');
  assertCondition(first.loadCount === 1 && second.loadCount === 1, 'adapters should be visited in order');
  passed.push('waterfall fallback');

  const raw = new FakeAdHandle('managed-test', 'fake', AdFormat.Interstitial);
  const managed = new AdManagedHandle(raw);
  await managed.show();
  let duplicateRejected = false;
  try { await managed.show(); } catch (_) { duplicateRejected = true; }
  assertCondition(duplicateRejected, 'duplicate show must be rejected');
  raw.emitCompleted();
  assertCondition(managed.state === AdSessionState.Completed, 'vendor completion must update managed state');
  assertCondition(!managed.complete(), 'duplicate completion must be ignored');
  managed.destroy();
  managed.destroy();
  assertCondition(raw.destroyCount === 1, 'underlying handle must be destroyed once');
  passed.push('managed handle lifecycle');

  const slow = new FakeAdAdapter('fake-slow', [AdFormat.Interstitial]);
  slow.delayMs = 60;
  const timed = await new AdOrchestrator().load(
    new AdRequest('self-test-timeout', AdFormat.Interstitial, 'placement-test', 10),
    [slow]
  );
  assertCondition(!timed.success && timed.error !== null, 'slow adapter should time out');
  assertCondition(timed.error.code === AdErrorCode.Timeout, 'timeout should use typed error');
  await new Promise<void>((resolve) => setTimeout(() => resolve(), 100));
  assertCondition(slow.lastHandle !== null && slow.lastHandle.destroyCount === 1, 'late result should be destroyed');
  passed.push('timeout and late-handle cleanup');

  const cancelAdapter = new FakeAdAdapter('fake-cancel', [AdFormat.Interstitial]);
  cancelAdapter.delayMs = 60;
  const request = new AdRequest('self-test-cancel', AdFormat.Interstitial, 'placement-test', 1000);
  const session = new AdRequestSession(request.requestId);
  const pending = new AdOrchestrator().load(request, [cancelAdapter], session);
  await new Promise<void>((resolve) => setTimeout(() => resolve(), 5));
  assertCondition(session.cancel(), 'active session should accept cancellation');
  const cancelled = await pending;
  assertCondition(!cancelled.success && session.state === AdSessionState.Cancelled, 'cancel should end request');
  await new Promise<void>((resolve) => setTimeout(() => resolve(), 100));
  assertCondition(cancelAdapter.lastHandle !== null && cancelAdapter.lastHandle.destroyCount === 1, 'cancelled late result should be destroyed');
  passed.push('cancellation and late-handle cleanup');

  return passed;
}
