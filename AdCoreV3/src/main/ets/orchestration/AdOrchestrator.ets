import { AdAdapter, adapterSupports } from '../core/AdAdapter';
import { AdError, AdErrorCode, AdHandle, AdLoadResult, AdRequest, AdSessionState } from '../core/AdCoreTypes';
import { AdRequestSession } from '../core/AdRequestSession';

/** Serial waterfall. Every call has an independent session and one shared request deadline. */
export class AdOrchestrator {
  async load(request: AdRequest, adapters: AdAdapter[], session?: AdRequestSession): Promise<AdLoadResult> {
    const activeSession = session === undefined ? new AdRequestSession(request.requestId) : session;
    if (request.requestId.length === 0 || request.placementId.length === 0 || request.timeoutMs <= 0) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidRequest, 'Request id, placement id, and timeout must be valid.'));
    }
    if (activeSession.state !== AdSessionState.Created) {
      return AdLoadResult.failed(new AdError(AdErrorCode.InvalidState, 'A request session can only be loaded once.'));
    }
    const candidates = adapters.filter((adapter: AdAdapter) => adapterSupports(adapter, request.format));
    if (candidates.length === 0) {
      const error = new AdError(AdErrorCode.NoAdapter, 'No adapter supports this ad format.');
      activeSession.fail(error);
      return AdLoadResult.failed(error);
    }

    activeSession.transition(AdSessionState.Loading);
    const deadline = Date.now() + request.timeoutMs;
    const errors: AdError[] = [];

    for (let i = 0; i < candidates.length; i++) {
      if (activeSession.isTerminal) {
        return AdLoadResult.failed(activeSession.error === null
          ? new AdError(AdErrorCode.Cancelled, 'The request ended before an ad was loaded.')
          : activeSession.error);
      }
      const remaining = deadline - Date.now();
      if (remaining <= 0) { break; }

      const adapter = candidates[i];
      try {
        const handle = await this.loadWithTimeout(adapter, request, remaining, activeSession);
        if (activeSession.isTerminal) {
          this.safeDestroy(handle);
          return AdLoadResult.failed(activeSession.error === null
            ? new AdError(AdErrorCode.Cancelled, 'The request ended before loading completed.')
            : activeSession.error);
        }
        if (handle.format !== request.format) {
          this.safeDestroy(handle);
          errors.push(new AdError(AdErrorCode.LoadFailed, 'Adapter returned a handle with a mismatched format.', adapter.id));
          continue;
        }
        activeSession.transition(AdSessionState.Ready);
        return AdLoadResult.loaded(handle);
      } catch (error) {
        if (activeSession.isTerminal) {
          return AdLoadResult.failed(activeSession.error === null
            ? new AdError(AdErrorCode.Cancelled, 'The request ended.')
            : activeSession.error);
        }
        const code = error instanceof AdError ? error.code : AdErrorCode.LoadFailed;
        const message = error instanceof Error ? error.message : 'Adapter load failed.';
        errors.push(new AdError(code, message, adapter.id));
      }
    }

    const timedOut = Date.now() >= deadline;
    const finalError = timedOut
      ? new AdError(AdErrorCode.Timeout, 'The ad request timed out.')
      : errors.length > 0
        ? new AdError(AdErrorCode.LoadFailed, this.describeErrors(errors), errors[errors.length - 1].adapterId)
        : new AdError(AdErrorCode.LoadFailed, 'All adapters failed to load an ad.');
    activeSession.fail(finalError);
    return AdLoadResult.failed(finalError);
  }

  private loadWithTimeout(
    adapter: AdAdapter,
    request: AdRequest,
    timeoutMs: number,
    session: AdRequestSession
  ): Promise<AdHandle> {
    return new Promise<AdHandle>((resolve, reject) => {
      let settled = false;
      const timerId = setTimeout(() => {
        if (settled) { return; }
        settled = true;
        reject(new AdError(AdErrorCode.Timeout, 'Adapter load timed out.', adapter.id));
      }, timeoutMs);

      const finishResolve = (handle: AdHandle): void => {
        if (settled) {
          this.safeDestroy(handle);
          return;
        }
        settled = true;
        clearTimeout(timerId);
        resolve(handle);
      };
      const finishReject = (error: Error): void => {
        if (settled) { return; }
        settled = true;
        clearTimeout(timerId);
        reject(error);
      };

      session.onCancel(() => {
        finishReject(new AdError(AdErrorCode.Cancelled, 'The request was cancelled.', adapter.id));
      });
      adapter.load(request).then(finishResolve).catch((error: Error) => {
        finishReject(error);
      });
    });
  }

  private safeDestroy(handle: AdHandle): void {
    try { handle.destroy(); } catch (_) {
      // Cleanup is best-effort and must not hide the original request result.
    }
  }

  private describeErrors(errors: AdError[]): string {
    return errors.map((error: AdError) => error.adapterId + ': ' + error.message).join('; ');
  }
}
