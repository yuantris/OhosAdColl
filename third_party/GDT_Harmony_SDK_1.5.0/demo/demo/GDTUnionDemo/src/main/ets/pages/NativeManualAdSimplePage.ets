import { GDTAdLoadConfig, GDTAdSDK, GDTAutoPlayPolicy, GDTError, GDTManualAd } from '@gdt/gdt-union-sdk';
import { NativeAdParam } from '../model/NativeAdParam';
import { ManualAdVideoSize } from '../model/ManualAdVideoSize';
import { LogUtil } from '../utils/LogUtil';
import { ToastUtil } from '../utils/ToastUtil';
import { DemoConstants } from '../constants/DemoConstants';
import { BiddingUtil } from '../utils/BiddingUtil';
import { ChangeOrientationView } from '../components/ChangeOrientationView';
import { LoadAndShowCard } from '../components/LoadAndShowCard';
import { ManualAdItemView } from '../components/ManualAdItemView';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';

@Builder
export function PageBuilder() {
  NativeManualAdSimplePage()
}

@ComponentV2
struct NativeManualAdSimplePage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  @Local param?: NativeAdParam = undefined;
  @Local posId?: string = undefined;
  token?: string = ''; // s2s token
  ad?: GDTManualAd;
  @Local showingAd: boolean = false;
  // 视频区域尺寸：宽度百分比 + 高宽比（width:height）。仅正整数，非法回落默认值
  @Local videoWidthPercentInput: string = '100';
  @Local videoAspectWidthInput: string = '16';
  @Local videoAspectHeightInput: string = '9';
  @Local videoSize: ManualAdVideoSize = new ManualAdVideoSize();

  loadAd(): void {
    if (!this.posId) {
      return;
    }
    if (this.ad) {
      this.clearAd();
    }
    const posId = this.posId;
    const config: GDTAdLoadConfig = {
      posId
    };
    // 每次广告请求后，都清空token
    if (this.token) {
      config.token = this.token;
      this.token = '';
    }
    GDTAdSDK.getAdLoader().loadManualAd(config, {
      onAdLoad: (ads: Array<GDTManualAd>): void => {
        LogUtil.info(`onAdLoad`);
        ToastUtil.showToast('广告加载成功');
        this.ad = ads[0];
        if (this.param) {
          this.ad.setVideoOptions({
            autoPlayMuted: this.param.autoPlayMuted ?? true,
            autoPlayPolicy: this.param.autoPlayPolicy ?? GDTAutoPlayPolicy.ALWAYS,
            showCoverImg: this.param.showCoverImg ?? true,
            showProgressBar: this.param.showProgressBar ?? true,
          });
        }
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

  private bindListener(ad: GDTManualAd): void {
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
    this.showingAd = true;
  }

  clearAd(): void {
    this.showingAd = false;
    this.ad?.destroy();
    this.ad = undefined;
  }

  /** 解析正整数；非正整数 / 解析失败返回 undefined */
  private parsePositiveInt(input: string): number | undefined {
    if (!input) {
      return undefined;
    }
    if (!/^\d+$/.test(input)) {
      return undefined;
    }
    const v = Number.parseInt(input, 10);
    return v > 0 ? v : undefined;
  }

  /** 点击应用时刷新 videoSize；非法输入回落默认值。 */
  private applyVideoSize(): void {
    const widthPercent = this.parsePositiveInt(this.videoWidthPercentInput);
    const aw = this.parsePositiveInt(this.videoAspectWidthInput);
    const ah = this.parsePositiveInt(this.videoAspectHeightInput);
    this.videoSize.widthPercent = widthPercent !== undefined && widthPercent <= 100 ? widthPercent : 100;
    this.videoSize.aspectRatio = aw !== undefined && ah !== undefined ? aw / ah : 16 / 9;
  }

  @Builder
  settingsContent() {
    Text(`广告位：${this.posId}`)
    Blank(10)
    // 视频区域尺寸控制（仅自渲染视频生效，点击「应用」后生效）
    Column() {
      Row() {
        Text('宽度%').fontSize(14).width(56)
        TextInput({ text: this.videoWidthPercentInput, placeholder: '1~100' })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(36)
          .onChange((v: string) => {
            this.videoWidthPercentInput = v;
          })
      }
      .width('100%')
      Row() {
        Text('比例').fontSize(14).width(56)
        TextInput({ text: this.videoAspectWidthInput, placeholder: '宽' })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(36)
          .onChange((v: string) => {
            this.videoAspectWidthInput = v;
          })
        Text(' : ').fontSize(14).margin({ left: 6, right: 6 })
        TextInput({ text: this.videoAspectHeightInput, placeholder: '高' })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(36)
          .onChange((v: string) => {
            this.videoAspectHeightInput = v;
          })
        Button('应用')
          .height(36)
          .margin({ left: 8 })
          .onClick(() => {
            this.applyVideoSize();
          })
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
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
    if (this.showingAd && this.ad) {
      ManualAdItemView(this.ad, this.getUIContext(), this.param, this.videoSize);
    }
  }

  build() {
    NavDestination() {
      AdaptiveLayout({
        settingsBuilder: (): void => { this.settingsContent(); },
        actionsBuilder: (): void => { this.actionsContent(); },
        contentBuilder: (): void => { this.contentContent(); },
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
