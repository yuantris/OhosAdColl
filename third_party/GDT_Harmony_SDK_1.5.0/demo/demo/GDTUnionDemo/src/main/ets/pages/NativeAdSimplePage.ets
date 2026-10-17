import { GDTAdLoadConfig, GDTAdSDK, GDTAdSize, GDTError, GDTNativeAd } from '@gdt/gdt-union-sdk';
import { ChangeOrientationView } from '../components/ChangeOrientationView';
import { LoadAndShowCard } from '../components/LoadAndShowCard';
import { NativeAdParam } from '../model/NativeAdParam';
import { NodeController } from '@kit.ArkUI';
import { DemoConstants } from '../constants/DemoConstants';
import { ToastUtil } from '../utils/ToastUtil';
import { LogUtil } from '../utils/LogUtil';
import { BiddingUtil } from '../utils/BiddingUtil';
import { AdSizeView } from '../components/AdSizeView';
import { DisplayUtil } from '../utils/DisplayUtil';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';

@Builder
export function PageBuilder() {
  NativeAdSimplePage()
}

@ComponentV2
struct NativeAdSimplePage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  @Local param?: NativeAdParam = undefined;
  @Local posId?: string = undefined;
  token?: string = ''; // s2s token
  @Local adWidth: number = 360;
  @Local adHeight: number = GDTAdSize.AUTO_HEIGHT;
  // 实际展示区域宽度（横屏为右侧分栏宽），由 AdaptiveLayout onAreaChange 回传
  @Local contentWidth: number = DisplayUtil.getWidthDp();
  ad?: GDTNativeAd;
  @Local adComponent?: NodeController = undefined;

  loadAd(): void {
    if (!this.posId) {
      return;
    }
    if (this.ad) {
      this.clearAd();
    }
    const posId = this.posId;
    const config: GDTAdLoadConfig = {
      posId,
      adSize: new GDTAdSize(this.adWidth, this.adHeight)
    };
    // 每次广告请求后，都清空token
    if (this.token) {
      config.token = this.token;
      this.token = '';
    }
    GDTAdSDK.getAdLoader().loadNativeAd(config, {
      onAdLoad: (ads: Array<GDTNativeAd>): void => {
        LogUtil.info(`onAdLoad`);
        ToastUtil.showToast('广告加载成功');
        this.ad = ads[0];
        this.ad.setVideoOptions({ autoPlayMuted: this.param?.autoPlayMuted ?? true });
        this.bindListener(this.ad);
        // 调用 render 方法前需要 setRenderListener，render success 后可以展示
        this.ad.render(DemoConstants.windowStage, this.getUIContext());
        BiddingUtil.handleAdLoadSuccess(this.ad);
      },
      onError: (err: GDTError): void => {
        ToastUtil.showToast(`广告加载失败${JSON.stringify(err)}`);
        BiddingUtil.handleAdLoadError(posId);
      }
    });
  }

  private bindListener(ad: GDTNativeAd): void {
    ad.setRenderListener({
      onRenderSuccess: (): void => {
        if (this.loadAndShow) {
          this.showAd();
        }
      },
      onRenderFail: (err: GDTError): void => {
        ToastUtil.showToast(`广告渲染失败${JSON.stringify(err)}`);
      }
    });
    ad.setInteractionListener({
      onAdExposure: (): void => {
        LogUtil.info(`onAdExposure`);
      },
      onAdClick: (): void => {
        LogUtil.info(`onAdClick`);
      },
      onAdClose: (): void => {
        LogUtil.info(`onAdClose`);
        this.clearAd();
      },
      onError: (err: GDTError): void => {
        ToastUtil.showToast(`广告出现错误: ${err.code}, ${err.message}`);
        LogUtil.error(`onError: ${err.code}, ${err.message}`);
      }
    });
    ad.setVideoStateListener({
      onVideoReady: (): void => {
        LogUtil.info(`onVideoReady`);
      },
      onVideoStart: (): void => {
        LogUtil.info(`onVideoStart`);
      },
      onVideoPause: (): void => {
        LogUtil.info(`onVideoPause`);
      },
      onVideoResume: (): void => {
        LogUtil.info(`onVideoResume`);
      },
      onVideoComplete: (): void => {
        LogUtil.info(`onVideoComplete`);
      },
      onVideoError: (err: GDTError): void => {
        LogUtil.error(`onVideoError: ${err.code}, ${err.message}`);
      }
    });
  }

  checkAdValid(): void {
    if (!this.ad) {
      ToastUtil.showToast('请先加载广告');
      return;
    }
    ToastUtil.showToast(`广告${this.ad?.isValid() ? '有效' : '无效'}`);
  }

  showAd(): void {
    this.adComponent = this.ad?.getAdComponent();
  }

  clearAd(): void {
    this.adComponent = undefined;
    this.ad?.destroy();
    this.ad = undefined;
  }

  @Builder
  settingsContent() {
    Text(`广告位：${this.posId}`)
    Blank(10)
    AdSizeView({
      adWidth: this.adWidth!!,
      adHeight: this.adHeight!!,
      contentWidth: this.contentWidth,
    })
    Blank(10)
    ChangeOrientationView()
  }

  @Builder
  actionsContent() {
    LoadAndShowCard({
      posId: this.posId,
      onLoadAdClick: () => {
        this.loadAndShow = false;
        this.loadAd();
      },
      onAdValidClick: () => {
        this.checkAdValid();
      },
      onShowAdClick: () => {
        this.showAd();
      },
      onGetS2STokenClick: (token: string) => {
        this.token = token;
      },
      onLoadAndShowAdClick: () => {
        this.loadAndShow = true;
        this.loadAd();
      }
    })
  }

  @Builder
  contentContent() {
    if (this.adComponent) {
      NodeContainer(this.adComponent)
    }
  }

  build() {
    NavDestination() {
      AdaptiveLayout({
        settingsBuilder: (): void => { this.settingsContent(); },
        actionsBuilder: (): void => { this.actionsContent(); },
        contentBuilder: (): void => { this.contentContent(); },
        onAreaWidthChange: (width: number): void => {
          this.contentWidth = width;
        },
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    }).onReady(async (context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.param = context.pathInfo.param as NativeAdParam;
      this.posId = this.param.posId;
      if (this.param.autoLoadAndShow) {
        await OrientationHelper.applyOrientation(this.param.orientation);
        this.loadAndShow = true;
        this.loadAd();
      }
    })
    .onWillDisappear(() => {
      // 及时清理资源
      this.clearAd();
    })
  }

  aboutToDisappear(): void {
    OrientationHelper.restoreAutoRotation();
  }
}
