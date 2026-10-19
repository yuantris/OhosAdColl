import { AdCoreFacade } from '../core/AdCoreFacade';
import { AdError, AdFormat, AdRequest } from '../core/AdCoreTypes';
import { AdRenderMode, AdViewHandle, AdViewLifecycleListener } from '../core/AdViewTypes';
import { HuaweiBannerAd } from './HuaweiBannerAd';

/**
 * Public drop-in Banner component for Pangle, GDT and Huawei AdsKit.
 * Pass the provider-specific placement ID and an initialized AdCoreFacade.
 */
@ComponentV2
export struct AdBanner {
  @Require @Param facade: AdCoreFacade;
  @Require @Param providerId: string;
  @Require @Param placementId: string;
  @Param width: Length = '100%';
  @Param height: Length = 'auto';
  @Param widthVp: number = 360;
  @Param heightVp: number = 57;
  @Param timeoutMs: number = 15000;
  @Param refreshTime: number = 0;
  @Param oaid: string = '';
  @Param radius: Length = 0;
  @Param backgroundColor: ResourceColor = Color.Transparent;
  @Param lifecycleListener: AdViewLifecycleListener | undefined = undefined;
  @Param onLoadError: ((message: string) => void) | undefined = undefined;

  @Local private handle: AdViewHandle | null = null;
  @Local private loading = false;
  private disposed = false;
  private sequence = 0;

  aboutToAppear(): void {
    this.disposed = false;
    if (this.providerId !== 'huawei') {
      this.loadAd();
    }
  }
  aboutToDisappear(): void {
    this.disposed = true;
    this.sequence++;
    this.loading = false;
    const current = this.handle;
    this.handle = null;
    current?.destroy();
  }
  public async reload(): Promise<void> {
    if (this.providerId === 'huawei') {
      return;
    }
    await this.loadAd();
  }
  private async loadAd(): Promise<void> {
    if (this.loading || this.disposed || this.providerId === 'huawei') {
      return;
    }
    if (this.providerId !== 'pangle' && this.providerId !== 'gdt') {
      this.onLoadError?.('Unsupported Banner provider: ' + this.providerId);
      return;
    }
    this.loading = true;
    const previous = this.handle;
    this.handle = null;
    previous?.destroy();
    const currentSequence = ++this.sequence;
    const request = new AdRequest(
      'banner-' + this.providerId + '-' + Date.now() + '-' + String(currentSequence),
      AdFormat.Banner,
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
      if (this.disposed || currentSequence !== this.sequence) {
        loaded.destroy();
        return;
      }
      if (this.lifecycleListener !== undefined) {
        loaded.setLifecycleListener(this.lifecycleListener);
      }
      this.handle = loaded;
      await loaded.mount();
    } catch (error) {
      if (!this.disposed && currentSequence === this.sequence) {
        this.onLoadError?.(error instanceof Error ? error.message : String(error));
      }
    } finally {
      if (currentSequence === this.sequence) {
        this.loading = false;
      }
    }
  }

  build(): void {
    Column() {
      if (this.providerId === 'huawei') {
        HuaweiBannerAd({
          adId: this.placementId,
          oaid: this.oaid,
          bannerHeight: this.heightVp === 144 ? 144 : 57,
          refreshTime: this.refreshTime,
          width: this.width,
          radius: this.radius,
          backgroundColor: this.backgroundColor,
          lifecycleListener: this.lifecycleListener
        })
      } else if (this.handle !== null && this.handle.nodeController !== null) {
        NodeContainer(this.handle.nodeController)
          .width('100%')
          .backgroundColor(this.backgroundColor)
          .borderRadius(this.radius);
      }
    }
    .width(this.width)
    .height(this.providerId === 'huawei' ? this.height : (this.handle !== null ? this.height : 0))
    .backgroundColor(this.backgroundColor)
    .borderRadius(this.radius)
    .clip(true)
  }
}
