import { AdCoreFacade } from '../core/AdCoreFacade';
import { AdFormat, AdRequest } from '../core/AdCoreTypes';
import { AdRenderMode, AdViewHandle, AdViewLifecycleListener } from '../core/AdViewTypes';

/**
 * Drop-in provider-rendered native feed slot.
 * The app initializes AdCoreFacade after affirmative privacy consent; this component
 * loads, mounts and releases the selected provider's feed ad with its UI lifecycle.
 */
@ComponentV2
export struct AdFeed {
  @Require @Param facade: AdCoreFacade;
  @Require @Param providerId: string;
  @Require @Param placementId: string;
  @Param width: Length = '100%';
  @Param height: Length = 'auto';
  @Param widthVp: number = 360;
  @Param heightVp: number = 0;
  @Param timeoutMs: number = 15000;
  @Param backgroundColor: ResourceColor = Color.Transparent;
  @Param radius: Length = 0;
  @Param lifecycleListener: AdViewLifecycleListener | undefined = undefined;
  @Param onLoadError: ((message: string) => void) | undefined = undefined;

  @Local private handle: AdViewHandle | null = null;
  @Local private loading: boolean = false;
  private disposed: boolean = false;
  private requestSequence: number = 0;

  aboutToAppear(): void {
    this.disposed = false;
    this.loadAd();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.requestSequence++;
    this.loading = false;
    const current = this.handle;
    this.handle = null;
    current?.destroy();
  }

  /** Explicitly request a fresh ad, for example after the parent refreshes its feed. */
  public async reload(): Promise<void> {
    await this.loadAd();
  }

  private async loadAd(): Promise<void> {
    if (this.loading || this.disposed) {
      return;
    }
    this.loading = true;
    const previous = this.handle;
    this.handle = null;
    previous?.destroy();

    const sequence = ++this.requestSequence;
    const request = new AdRequest(
      'feed-' + this.providerId + '-' + Date.now() + '-' + String(sequence),
      AdFormat.Native,
      this.placementId,
      this.timeoutMs
    );

    try {
      const loaded = await this.facade.loadView(this.providerId, {
        request: request,
        providerId: this.providerId,
        mode: AdRenderMode.ProviderView,
        size: { widthVp: this.widthVp, heightVp: this.heightVp }
      });
      if (this.disposed || sequence !== this.requestSequence) {
        loaded.destroy();
        return;
      }
      if (this.lifecycleListener !== undefined) {
        loaded.setLifecycleListener(this.lifecycleListener);
      }
      this.handle = loaded;
      await loaded.mount();
    } catch (error) {
      if (!this.disposed && sequence === this.requestSequence) {
        const message = error instanceof Error ? error.message : String(error);
        this.onLoadError?.(message);
      }
    } finally {
      if (sequence === this.requestSequence) {
        this.loading = false;
      }
    }
  }

  build(): void {
    Column() {
      if (this.handle !== null && this.handle.nodeController !== null) {
        NodeContainer(this.handle.nodeController)
          .width('100%')
          .backgroundColor(this.backgroundColor)
          .borderRadius(this.radius);
      }
    }
    .width(this.width)
    .height(this.handle !== null ? this.height : 0)
    .backgroundColor(this.backgroundColor)
    .borderRadius(this.radius)
    .clip(true)
  }
}
