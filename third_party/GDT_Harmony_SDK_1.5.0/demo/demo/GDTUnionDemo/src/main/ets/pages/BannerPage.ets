import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTBannerAd,
  GDTError,
  GDTRenderListener,
  GDTInteractionListener,
  GDTVideoStateListener,
  GDTAdSize,
} from '@gdt/gdt-union-sdk';
import { LogUtil } from '../utils/LogUtil';
import { BiddingUtil } from '../utils/BiddingUtil';
import { LoadAndShowCard } from '../components/LoadAndShowCard';
import { ToastUtil } from '../utils/ToastUtil';
import { PosIdSelector } from '../components/PosIdSelector';
import { AdConstants } from '@gdt/gdt-union-demo/ets/constants/AdConstants';
import { JSON } from '@kit.ArkTS';
import { ChangeOrientationView } from '../components/ChangeOrientationView';
import { DemoConstants } from '../constants/DemoConstants';
import { DisplayUtil } from '../utils/DisplayUtil';
import { BannerAdSizeView } from '../components/BannerAdSizeView';
import { AdPageParam } from '../model/AdPageParam';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';

@Builder
export function PageBuilder() {
  BannerPage()
}

@ComponentV2
struct BannerPage {
  private pathStack: NavPathStack = new NavPathStack();
  private loadAndShow: boolean = false;
  private readonly posIdArr: Array<[string, string]> = AdConstants.BANNER_POS_ID_LIST;
  private ad: GDTBannerAd | null = null;
  private token: string = ''; // s2s token
  private isRenderSuccess: boolean = false;
  @Local adWidth: number = 360;
  @Local adHeight: number = 96;
  // 实际展示区域宽度（横屏为右侧分栏宽），由 AdaptiveLayout onAreaChange 回传
  @Local contentWidth: number = DisplayUtil.getWidthDp();
  @Local refresh: number = 30;
  @Local posId: string = AdConstants.BANNER_DEFAULT_POS_ID;
  @Local autoPlayMuted: boolean = true;
  @Local isShow: boolean = false;
  adLoadListener: GDTAdLoadListener<GDTBannerAd> = {
    onAdLoad: (ad: GDTBannerAd): void => {
      LogUtil.info(`onAdLoad`);
      ToastUtil.showToast('广告加载成功');
      ad.setRefresh(this.refresh);
      ad.setInteractionListener(this.interactionListener);
      ad.setVideoStateListener(this.videoStateListener);
      ad.setVideoOptions({ autoPlayMuted: this.autoPlayMuted });
      ad.setRenderListener(this.renderListener);
      ad.render(DemoConstants.windowStage, this.getUIContext());
      BiddingUtil.handleAdLoadSuccess(ad);
      this.ad = ad;
    },
    onError: (err: GDTError): void => {
      ToastUtil.showToast(`广告加载失败${JSON.stringify(err)}`);
      BiddingUtil.handleAdLoadError(this.posId);
    }
  };

  renderListener: GDTRenderListener = {
    onRenderSuccess: (): void => {
      this.isRenderSuccess = true;
      if (this.loadAndShow) {
        this.isShow = true;
      }
      LogUtil.info(`onRenderSuccess`);
    },
    onRenderFail: (): void => {
      LogUtil.info(`广告渲染失败，请重试`);
      ToastUtil.showToast('广告渲染失败，请重试');
    }
  };

  interactionListener: GDTInteractionListener = {
    onAdExposure: (): void => {
      LogUtil.info(`onAdExposure`);
    },
    onAdClick: (): void => {
      LogUtil.info(`onAdClick`);
    },
    onAdClose: (): void => {
      LogUtil.info(`onAdClose`);
      this.isShow = false;
      // 关闭广告时，销毁广告实例
      this.ad?.destroy();
    },
    onError: (err: GDTError): void => {
      ToastUtil.showToast(`广告出现错误: ${err.code}, ${err.message}`);
      LogUtil.error(`onError: ${err.code}, ${err.message}`);
    },
  };
  videoStateListener: GDTVideoStateListener = {
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
  };

  loadAd(loadAndShow: boolean = false): void {
    // 如果已经存在广告实例，再次手动加载广告时，需要先释放广告实例
    this.isShow = false;
    this.ad?.destroy();
    this.loadAndShow = loadAndShow;
    const config: GDTAdLoadConfig = {
      posId: this.posId,
      adSize: new GDTAdSize(this.adWidth, this.adHeight)
    };
    // 每次广告请求后，都清空token
    if (this.token) {
      config.token = this.token;
      this.token = '';
    }
    GDTAdSDK.getAdLoader().loadBannerAd(config, this.adLoadListener);
  }

  checkAdValid(): void {
    if (!this.ad) {
      ToastUtil.showToast('请先加载广告');
      return;
    }
    ToastUtil.showToast(`广告${this.ad?.isValid() ? '有效' : '无效'}`);
  }

  showAd(): void {
    if (!this.ad) {
      ToastUtil.showToast('请先加载广告');
      return;
    }
    if (!this.isRenderSuccess) {
      ToastUtil.showToast('广告渲染失败，请重启加载广告');
      return;
    }
    this.isShow = true;
  }

  @Builder
  adSlideRefresh() {
    Flex({ alignItems: ItemAlign.Center }) {
      Text('轮播时长:').flexShrink(0).margin({ right: 20 })
      TextInput({ placeholder: '轮播时长: 单位秒(s)', text: `${this.refresh}` })
        .fontSize(20)
        .showUnderline(true)
        .onChange((value: string) => {
          const refresh = Number.parseInt(value);
          if (Number.isNaN(refresh)) {
            return;
          }
          this.refresh = refresh;
        })
    }
  }

  @Builder
  settingsContent() {
    PosIdSelector({
      posId: this.posId!!,
      posIdArr: this.posIdArr,
    })
    BannerAdSizeView({
      adWidth: this.adWidth!!,
      adHeight: this.adHeight!!,
      contentWidth: this.contentWidth,
    })
    Blank(10)
    this.adSlideRefresh();
    Blank(10)
    ChangeOrientationView()
  }

  @Builder
  actionsContent() {
    LoadAndShowCard({
      posId: this.posId,
      onLoadAdClick: () => {
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
        this.loadAd(true);
      }
    })
  }

  @Builder
  contentContent() {
    if (this.isShow && this.ad) {
      NodeContainer(this.ad.getAdComponent())
        .width(this.ad.getAcceptWidth())
        .height(this.ad.getAcceptHeight())
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
    .title('Banner广告')
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    }).onReady(async (context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as AdPageParam | undefined;
      if (param?.autoLoadAndShow) {
        await OrientationHelper.applyOrientation(param.orientation);
        this.loadAd(true);
      }
    })
  }

  aboutToDisappear(): void {
    // 页面卸载时，销毁广告实例；
    this.ad?.destroy();
    OrientationHelper.restoreAutoRotation();
  }
}
