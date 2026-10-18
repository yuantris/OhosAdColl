import { AdAdapter } from '../core/AdAdapter';
import { AdError, AdErrorCode, AdFormat, AdHandle, AdRequest } from '../core/AdCoreTypes';

/** Deterministic fixture for integration tests and manual playgrounds. */
export class FakeAdHandle implements AdHandle {
  readonly id: string;
  readonly adapterId: string;
  readonly format: AdFormat;
  private destroyed: boolean = false;
  private shown: boolean = false;
  destroyCount: number = 0;

  constructor(id: string, adapterId: string, format: AdFormat) {
    this.id = id;
    this.adapterId = adapterId;
    this.format = format;
  }

  get isDestroyed(): boolean { return this.destroyed; }
  get isShown(): boolean { return this.shown; }

  async show(): Promise<void> {
    if (this.destroyed) { throw new Error('Cannot show a destroyed ad handle.'); }
    if (this.shown) { throw new Error('This ad handle has already been shown.'); }
    this.shown = true;
  }

  destroy(): void {
    if (this.destroyed) { return; }
    this.destroyed = true;
    this.destroyCount++;
  }
}

export class FakeAdAdapter implements AdAdapter {
  readonly id: string;
  readonly supportedFormats: AdFormat[];
  delayMs: number = 0;
  shouldFail: boolean = false;
  loadCount: number = 0;
  lastHandle: FakeAdHandle | null = null;

  constructor(id: string, formats: AdFormat[]) {
    this.id = id;
    this.supportedFormats = formats.slice();
  }

  async load(request: AdRequest): Promise<AdHandle> {
    this.loadCount++;
    if (this.delayMs > 0) {
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), this.delayMs);
      });
    }
    if (this.shouldFail) {
      throw new AdError(AdErrorCode.LoadFailed, 'Fake adapter configured to fail.', this.id);
    }
    const handle = new FakeAdHandle(request.requestId + ':' + this.id, this.id, request.format);
    this.lastHandle = handle;
    return handle;
  }
}
