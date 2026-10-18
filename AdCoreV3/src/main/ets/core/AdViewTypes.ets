import { NodeController } from '@kit.ArkUI';
import { AdFormat, AdRequest } from '../core/AdCoreTypes';

/**
 * Render modes supported by the V3 host contract.
 * Banner is provider-rendered; Native is host-rendered using returned material.
 */
export enum AdRenderMode {
  ProviderView = 'provider_view',
  SelfRender = 'self_render'
}

export interface AdNativeMaterial {
  readonly title: string;
  readonly description: string;
  readonly iconUrl: string;
  readonly imageUrls: string[];
  readonly videoUrl: string;
  readonly adLogoUrl: string;
  readonly callToAction: string;
  readonly pattern: string;
}

export interface AdViewSize {
  readonly widthVp: number;
  readonly heightVp: number;
}

export interface AdViewLoadRequest {
  readonly request: AdRequest;
  readonly providerId: string;
  readonly mode: AdRenderMode;
  readonly size: AdViewSize;
}

export interface AdViewLifecycleListener {
  onLoaded(): void;
  onShown(): void;
  onClicked(): void;
  onClosed(): void;
  onFailed(code: string, message: string): void;
}

/**
 * Channel-specific view handle. It deliberately does not extend AdHandle:
 * a banner/feed view is mounted in the host UI and is not a modal full-screen ad.
 */
export interface AdViewHandle {
  readonly providerId: string;
  readonly format: AdFormat;
  readonly mode: AdRenderMode;
  readonly material: AdNativeMaterial | null;
  /** SDK-owned ArkUI node used by NodeContainer for provider-rendered feed ads. */
  readonly nodeController: NodeController | null;
  setLifecycleListener(listener: AdViewLifecycleListener): void;
  /** Called by the host when its UI node is mounted and ready to display the ad. */
  mount(): Promise<void>;
  /** Detaches listeners and releases the underlying vendor ad exactly once. */
  destroy(): void;
}

/**
 * The host owns the ArkUI component tree. Adapters return a view handle; they
 * must not reach into a page's component state or install global UI.
 */
export interface AdViewAdapter {
  readonly id: string;
  loadView(request: AdViewLoadRequest): Promise<AdViewHandle>;
}
