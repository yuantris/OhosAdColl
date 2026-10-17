import {
  GDTAdLoadConfig,
  GDTAdLoadListener,
  GDTAdSDK,
  GDTError,
  GDTInteractionListener,
  GDTSplashAd,
} from '@gdt/gdt-union-sdk';
import { LogUtil } from '../utils/LogUtil';
import { BiddingUtil } from '../utils/BiddingUtil';
import { LoadAndShowCard } from '../components/LoadAndShowCard';
import { ToastUtil } from '../utils/ToastUtil';
import { PosIdSelector } from '../components/PosIdSelector';
import { AdConstants } from '@gdt/gdt-union-demo/ets/constants/AdConstants';
import { JSON } from '@kit.ArkTS';
import { ChangeOrientationView } from '../components/ChangeOrientationView';
import { CustomNodeController } from '../components/CustomNodeController';
import { DemoConstants } from '../constants/DemoConstants';
import { BusinessError } from '@kit.BasicServicesKit';
import { AdPageParam } from '../model/AdPageParam';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';


@Builder
export function PageBuilder() {
  SplashPage()
}

@Builder
export function BackgroundBuilder(param: Object) {
  Stack() {
    Image($r('app.media.gdt_splash_holder')).width('100%').height('100%')
    Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Start }) {
      Image($r('app.media.gdt_splash_text')).height(120).margin({ top: 200 })
    }.width('100%').height('100%')
  }.width('100%').height('100%')
}

@Builder
export function BottomViewBuilder(param: Object) {
  Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
    Image($r('app.media.gdt_logo')).height(28)
  }
  .width('100%')
  .height('15%') // 竖屏下高度必须小于等于20%，否则会被裁剪
}

@ComponentV2
struct SplashPage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  uiContext: UIContext = this.getUIContext();
  @Local posId: string = AdConstants.SPLASH_DEFAULT_POS_ID;
  @Local fullscreen: boolean = true;
  @Local closeOnClick: boolean = false;
  @Local navigateOnClose: boolean = false;
  @Local useNavigation: boolean = true;
  @Local timeoutMillis?: number = undefined;
  private readonly posIdArr: Array<[string, string]> = AdConstants.SPLASH_POS_ID_LIST;
  ad?: GDTSplashAd;
  token?: string = ''; // s2s token
  adLoadListener: GDTAdLoadListener<GDTSplashAd> = {
    onAdLoad: (ad: GDTSplashAd): void => {
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
      this.navigateToNextPage();
    },
    onError: (err: GDTError): void => {
      ToastUtil.showToast(`广告出现错误: ${err.code}, ${err.message}`);
      LogUtil.error(`onError: ${err.code}, ${err.message}`);
    }
  };

  navigateToNextPage(): void {
    if (!this.navigateOnClose) {
      LogUtil.info('未勾选跳转新页面，不做跳转');
      return;
    }
    if (this.useNavigation) {
      // Navigation 方案：通过 NavPathStack 跳转到 NavDestination 页面
      this.pathStack.pushPath(
        { name: 'SplashNavNextPage' },
        { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON }
      );
      LogUtil.info('通过 Navigation 跳转到 SplashNavNextPage');
    } else {
      // Router 方案：通过主窗口的 UIContext 获取 Router，避免子窗口销毁导致的上下文问题
      this.uiContext.getRouter().pushUrl({
        url: 'pages/SplashRouterNextPage'
      }).then(() => {
        LogUtil.info('通过 Router 跳转到 SplashRouterNextPage 成功');
      }).catch((err: BusinessError) => {
        LogUtil.error(`通过 Router 跳转到 SplashRouterNextPage 失败: ${err.code}, ${err.message}`);
      });
    }
  }

  loadAd(loadAndShow: boolean = false): void {
    this.loadAndShow = loadAndShow;
    const config: GDTAdLoadConfig = {
      posId: this.posId,
      timeoutMillis: this.timeoutMillis
    };
    // 每次广告请求后，都清空token
    if (this.token) {
      config.token = this.token;
      this.token = '';
    }
    GDTAdSDK.getAdLoader().loadSplashAd(config, this.adLoadListener);
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
    this.ad.setCloseOnClick(this.closeOnClick);
    this.ad.setBackground(new CustomNodeController(wrapBuilder(BackgroundBuilder)));
    if (this.fullscreen) {
      this.ad.show(DemoConstants.windowStage);
    } else {
      const bottom = new CustomNodeController(wrapBuilder(BottomViewBuilder));
      this.ad.show(DemoConstants.windowStage, bottom);
    }
  }

  @Builder
  fullscreenConfig() {
    Row() {
      Checkbox()
        .select(true)
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .onChange((value: boolean) => {
          this.fullscreen = value;
        })
      Text('全屏展示')
    }.width('100%')
  }

  @Builder
  closeOnClickConfig() {
    Row() {
      Checkbox()
        .select(this.closeOnClick)
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .onChange((value: boolean) => {
          this.closeOnClick = value;
        })
      Text('点击广告后关闭开屏')
    }.width('100%')
  }

  @Builder
  navigateConfig() {
    Column() {
      Row() {
        Checkbox()
          .select(this.navigateOnClose)
          .shape(CheckBoxShape.ROUNDED_SQUARE)
          .onChange((value: boolean) => {
            this.navigateOnClose = value;
          })
        Text('广告关闭后跳转新页面')
      }.width('100%')

      if (this.navigateOnClose) {
        Row() {
          Checkbox()
            .select(!this.useNavigation)
            .shape(CheckBoxShape.ROUNDED_SQUARE)
            .onChange((value: boolean) => {
              this.useNavigation = !value;
            })
          Text('使用 Router（默认 Navigation）')
        }
        .width('100%')
        .padding({ left: 20 })
      }
    }
  }

  @Builder
  timeoutBuilder() {
    Column() {
      Text('超时时间（单位ms，默认5000ms)').width('100%').fontSize(12).fontColor(Color.Gray)
      TextInput()
        .type(InputType.Number)
        .onChange((value) => {
          this.timeoutMillis = Number(value);
        })
    }.width('100%')
  }

  @Builder
  settingsContent() {
    PosIdSelector({
      posId: this.posId!!,
      posIdArr: this.posIdArr,
    })
    this.fullscreenConfig();
    Blank(10)
    this.closeOnClickConfig();
    Blank(10)
    this.navigateConfig();
    Blank(10)
    this.timeoutBuilder();
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
    .title('开屏广告')
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
