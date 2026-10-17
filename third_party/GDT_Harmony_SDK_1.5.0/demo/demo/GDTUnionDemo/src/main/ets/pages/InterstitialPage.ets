import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTError,
  GDTInteractionListener,
  GDTInterstitialAd,
  GDTVideoStateListener,
} from '@gdt/gdt-union-sdk';
import { DemoConstants } from '../constants/DemoConstants';
import { LogUtil } from '../utils/LogUtil';
import { BiddingUtil } from '../utils/BiddingUtil';
import { LoadAndShowCard } from '../components/LoadAndShowCard';
import { ToastUtil } from '../utils/ToastUtil';
import { PosIdSelector } from '../components/PosIdSelector';
import { AdConstants } from '@gdt/gdt-union-demo/ets/constants/AdConstants';
import { JSON } from '@kit.ArkTS';
import { ChangeOrientationView } from '../components/ChangeOrientationView';
import { AdPageParam } from '../model/AdPageParam';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';


@Builder
export function PageBuilder() {
  InterstitialPage()
}

@ComponentV2
struct InterstitialPage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  @Local posId: string = AdConstants.INTERSTITIAL_DEFAULT_POS_ID;
  @Local autoPlayMuted: boolean = true;
  private readonly posIdArr: Array<[string, string]> = AdConstants.INTERSTITIAL_POS_ID_LIST;
  ad?: GDTInterstitialAd;
  token?: string = ''; // s2s token
  adLoadListener: GDTAdLoadListener<GDTInterstitialAd> = {
    onAdLoad: (ad: GDTInterstitialAd): void => {
      LogUtil.info(`onAdLoad`);
      ToastUtil.showToast('广告加载成功');
      this.ad = ad;
      if (this.loadAndShow) {
        this.showAd();
      }
      BiddingUtil.handleAdLoadSuccess(this.ad);
    },
    onError: (err: GDTError): void => {
      ToastUtil.showToast(`广告加载失败${JSON.stringify(err)}`);
      BiddingUtil.handleAdLoadError(this.posId);
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
    this.loadAndShow = loadAndShow;
    const config: GDTAdLoadConfig = {
      posId: this.posId
    };
    // 每次广告请求后，都清空token
    if (this.token) {
      config.token = this.token;
      this.token = '';
    }
    GDTAdSDK.getAdLoader().loadInterstitialAd(config, this.adLoadListener);
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
    this.ad.setInteractionListener(this.interactionListener);
    this.ad.setVideoStateListener(this.videoStateListener);
    this.ad.setVideoOptions({ autoPlayMuted: this.autoPlayMuted });
    this.ad.show(DemoConstants.windowStage);
  }

  @Builder
  videoOptionsConfig() {
    Row() {
      Checkbox()
        .select(this.autoPlayMuted)
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .onChange((value: boolean) => {
          this.autoPlayMuted = value;
        })
      Text('静音播放')
    }.width('100%')
  }

  @Builder
  settingsContent() {
    PosIdSelector({
      posId: this.posId!!,
      posIdArr: this.posIdArr,
    })
    this.videoOptionsConfig();
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

  build() {
    NavDestination() {
      AdaptiveLayout({
        settingsBuilder: (): void => { this.settingsContent(); },
        actionsBuilder: (): void => { this.actionsContent(); },
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .title('插屏广告')
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
    OrientationHelper.restoreAutoRotation();
  }
}
