import { AdFormat, AdRequest, AdHandle } from './AdCoreTypes';

/** Vendor adapter contract. An adapter loads one provider; it never owns waterfall policy. */
export interface AdAdapter {
  readonly id: string;
  readonly supportedFormats: AdFormat[];
  load(request: AdRequest): Promise<AdHandle>;
}

export function adapterSupports(adapter: AdAdapter, format: AdFormat): boolean {
  return adapter.supportedFormats.indexOf(format) >= 0;
}
