/** SDK-wide immutable configuration. Per-request values belong in AdRequest. */
export class AdCoreConfig {
  readonly defaultTimeoutMs: number;
  readonly debug: boolean;

  constructor(defaultTimeoutMs: number = 10000, debug: boolean = false) {
    this.defaultTimeoutMs = defaultTimeoutMs;
    this.debug = debug;
  }
}
