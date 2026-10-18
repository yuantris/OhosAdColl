import { advertising, AutoAdComponent } from '@kit.AdsKit';
import { AdViewLifecycleListener } from '../core/AdViewTypes';
import { AdPrivacyGate } from '../core/AdPrivacyGate';

const HW_BANNER_AD_TYPE = 8;
const HW_BANNER_WIDTH = 360;
const MIN_REFRESH_TIME = 30000;
const MAX_REFRESH_TIME = 120000;

/**
 * Huawei AdsKit banner slot.
 *
 * Unlike native feed views, a banner is a provider-owned ArkUI component:
 * mounting this component starts its request, AdsKit owns display/refresh,
 * and removing it from the tree releases the provider view. Do not pass a
 * banner through the full-screen AdHandle lifecycle.
 */
@ComponentV2
export struct HuaweiBannerAd {
  @Require @Param adId: string;
  @Param oaid: string = '';
  @Param bannerHeight: number = 57;
  @Param refreshTime: number = 0;
  @Param width: Length = '100%';
  @Param radius: Length = 0;
  @Param backgroundColor: ResourceColor = Color.Transparent;
  @Param lifecycleListener: AdViewLifecycleListener | undefined = undefined;

  @Local private shouldMount: boolean = false;
  @Local private closed: boolean = false;
  @Local private requestParams: advertising.AdRequestParams = {
    adId: '',
    adType: HW_BANNER_AD_TYPE,
    adWidth: HW_BANNER_WIDTH,
    adHeight: 57
  };
  @Local private displayOptions: advertising.AdDisplayOptions = {};
  private readonly adOptions: advertising.AdOptions = {};

  aboutToAppear(): void {
    this.loadBanner();
  }

  aboutToDisappear(): void {
    // Unmounting AutoAdComponent releases the SDK-owned view/listeners.
    this.shouldMount = false;
  }

  /**
   * Explicit reload entry point. Call again after a close/failure if desired.
   * Banner loading is deliberately local to this component, not the waterfall.
   */
  public loadBanner(): void {
    try { AdPrivacyGate.requireConsent('huawei'); } catch (error) {
      this.shouldMount = false;
      this.lifecycleListener?.onFailed('PRIVACY_CONSENT_REQUIRED', 'User consent is required before initializing Huawei AdsKit.');
      return;
    }
    if (this.adId.length === 0) {
      this.lifecycleListener?.onFailed('INVALID_PLACEMENT', 'Huawei banner adId is empty.');
      return;
    }
    const safeHeight = this.bannerHeight === 144 ? 144 : 57;
    this.requestParams = {
      adId: this.adId,
      adType: HW_BANNER_AD_TYPE,
      adWidth: HW_BANNER_WIDTH,
      adHeight: safeHeight,
      oaid: this.oaid
    };

    const refresh = this.clampRefreshTime(this.refreshTime);
    this.displayOptions = refresh > 0 ? { refreshTime: refresh } : {};
    this.closed = false;
    this.shouldMount = true;
  }

  private clampRefreshTime(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return 0;
    }
    return Math.min(Math.max(Math.floor(value), MIN_REFRESH_TIME), MAX_REFRESH_TIME);
  }

  private handleStatusChanged(status: string, data: string): void {
    switch (status) {
      case 'onAdLoad':
        this.lifecycleListener?.onLoaded();
        break;
      case 'onAdOpen':
        this.lifecycleListener?.onShown();
        break;
      case 'onAdClick':
        this.lifecycleListener?.onClicked();
        break;
      case 'onAdClose':
        this.closed = true;
        this.shouldMount = false;
        this.lifecycleListener?.onClosed();
        break;
      case 'onAdFail':
        this.closed = true;
        this.shouldMount = false;
        this.lifecycleListener?.onFailed('PROVIDER_LOAD_FAILED', data || 'Huawei AdsKit banner failed.');
        break;
      default:
        break;
    }
  }

  build(): void {
    Column() {
      if (this.shouldMount && !this.closed) {
        AutoAdComponent({
          adParam: this.requestParams,
          adOptions: this.adOptions,
          displayOptions: this.displayOptions,
          interactionListener: {
            onStatusChanged: (status: string, ad: advertising.Advertisement, data: string): void => {
              this.handleStatusChanged(status, data);
            }
          }
        })
        .width('100%')
        .aspectRatio(HW_BANNER_WIDTH / (this.bannerHeight === 144 ? 144 : 57))
      }
    }
    .width(this.width)
    .backgroundColor(this.backgroundColor)
    .borderRadius(this.radius)
    .clip(true)
  }
}
