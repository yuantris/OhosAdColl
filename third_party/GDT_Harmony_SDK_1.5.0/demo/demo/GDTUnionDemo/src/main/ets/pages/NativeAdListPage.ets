import { GDTAdLoadConfig, GDTAdSDK, GDTError, GDTNativeAd } from '@gdt/gdt-union-sdk';
import { DemoConstants } from '../constants/DemoConstants';
import { NativeAdParam } from '../model/NativeAdParam';
import { IDataSourcePrefetching, IPrefetcher } from '@kit.ArkUI';
import { SimplePrefetcher } from '../utils/SimplePrefetcher';
import { AbstractDataSourcePrefetching } from '../utils/AbstractDataSourcePrefetching';
import { LogUtil } from '../utils/LogUtil';
import { ToastUtil } from '../utils/ToastUtil';
import { BiddingUtil } from '../utils/BiddingUtil';
import { OrientationHelper } from '../utils/OrientationHelper';
import { ChangeOrientationView } from '../components/ChangeOrientationView';


@Builder
export function PageBuilder() {
  NativeAdListPage()
}

const prefetchSize = 5;
let normalDataCount = 0;

class SimpleDataSource extends AbstractDataSourcePrefetching<string | GDTNativeAd> {
  private readonly uiContext: UIContext;
  private readonly param: NativeAdParam;
  private loading: boolean = false;

  public constructor(uiContext: UIContext, param: NativeAdParam) {
    super();
    this.uiContext = uiContext;
    this.param = param;
  }

  private loadAd(): void {
    if (!this.param || this.loading) {
      return;
    }
    this.loading = true;
    const config: GDTAdLoadConfig = {
      posId: this.param.posId,
      count: 5
    };
    GDTAdSDK.getAdLoader().loadNativeAd(config, {
      onAdLoad: (ads: Array<GDTNativeAd>): void => {
        LogUtil.info(`onAdLoad，共${ads.length}条广告`);
        ToastUtil.showToast('广告加载成功');
        for (const ad of ads) {
          ad.setVideoOptions({ autoPlayMuted: this.param.autoPlayMuted ?? true });
          this.bindListener(ad);
          // 调用 render 方法前需要 setRenderListener，render success 后可以展示
          ad.render(DemoConstants.windowStage, this.uiContext);
          BiddingUtil.handleAdLoadSuccess(ad);
        }
        this.loading = false;
      },
      onError: (err: GDTError): void => {
        ToastUtil.showToast(`广告加载失败${JSON.stringify(err)}`);
        this.loading = false;
        BiddingUtil.handleAdLoadError(this.param.posId);
      }
    });
  }

  private bindListener(ad: GDTNativeAd): void {
    ad.setRenderListener({
      onRenderSuccess: (): void => {
        this.pushData(ad);
        for (let index = 0; index < this.param.adInterval; index++) {
          this.pushData(`No.${normalDataCount++} Normal Data`);
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
        this.removeData(ad);
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

  public prefetch(index: number): void | Promise<void> {
    if (index >= this.totalCount()) {
      this.loadAd();
    }
  }
}


@ComponentV2
struct NativeAdListPage {
  private pathStack: NavPathStack = new NavPathStack();
  private dataSource?: IDataSourcePrefetching;
  private prefetcher?: IPrefetcher;

  build() {
    NavDestination() {
      List() {
        ListItem() {
          Row() {
            ChangeOrientationView()
              .width('40%')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }

        LazyForEach(this.dataSource, (item: string | GDTNativeAd) => {
          ListItem() {
            // 信息流条目（占位/广告/分隔）统一最大宽度 400dp，横屏受限居中
            Row() {
              Column() {
                if (typeof item === 'string') {
                  Text(item)
                    .height(100)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 20, bottom: 20 })
                  Divider().height(1)
                } else if (item) {
                  NodeContainer(item.getAdComponent()).width('100%')
                  Divider().height(1)
                }
              }
              .width('100%')
              .constraintSize({ maxWidth: 400 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .cachedCount(10)
      .onScrollIndex((start: number, end: number) => {
        this.prefetcher?.visibleAreaChanged(start, end);
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    }).onReady(async (context: NavDestinationContext) => {
      normalDataCount = 0;
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as NativeAdParam;
      this.dataSource = new SimpleDataSource(this.getUIContext(), param);
      this.prefetcher = new SimplePrefetcher(this.dataSource, prefetchSize);
      if (param.autoLoadAndShow) {
        // 信息流广告由 SimpleDataSource.prefetch 在列表滚动时自动触发加载，无需显式 loadAd
        await OrientationHelper.applyOrientation(param.orientation);
      }
    })
  }

  aboutToDisappear(): void {
    OrientationHelper.restoreAutoRotation();
  }
}
