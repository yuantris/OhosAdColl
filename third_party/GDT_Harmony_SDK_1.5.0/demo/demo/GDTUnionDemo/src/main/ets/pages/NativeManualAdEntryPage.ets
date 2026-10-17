import { ButtonItem } from '../components/ButtonItem';
import { PosIdSelector } from '../components/PosIdSelector';
import { AdConstants } from '@gdt/gdt-union-demo/ets/constants/AdConstants';
import { NativeAdParam } from '../model/NativeAdParam';
import { AdPageParam } from '../model/AdPageParam';
import { GDTAutoPlayPolicy } from '@gdt/gdt-union-sdk';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';

@Builder
export function PageBuilder() {
  NativeManualAdEntryPage()
}

/** 合法子页路由白名单 —— 防止外部传入未在 router_map.json 注册的路由名导致跳转异常 */
const VALID_SUB_PAGES: ReadonlySet<string> = new Set<string>([
  'NativeManualAdSimplePage',
  'NativeManualAdListPage',
]);
const DEFAULT_SUB_PAGE = 'NativeManualAdSimplePage';

@ComponentV2
struct NativeManualAdEntryPage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  @Local posId: string = AdConstants.MANUAL_DEFAULT_POS_ID;
  @Local autoPlayPolicy: GDTAutoPlayPolicy = GDTAutoPlayPolicy.ALWAYS;
  @Local autoPlayMuted: boolean = true;
  @Local showCoverImg: boolean = true;
  @Local showProgressBar: boolean = true;
  private readonly posIdArr: Array<[string, string]> = AdConstants.MANUAL_POS_ID_LIST;
  @Local adInterval: number = 5;

  @Builder
  videoOptionsConfig() {
    Column() {
      Row() {
        Checkbox()
          .select(this.autoPlayMuted)
          .shape(CheckBoxShape.ROUNDED_SQUARE)
          .onChange((value: boolean) => {
            this.autoPlayMuted = value;
          })
        Text('静音播放')
      }.width('100%').margin({ bottom: 6 })

      Row() {
        Checkbox()
          .select(this.showCoverImg)
          .shape(CheckBoxShape.ROUNDED_SQUARE)
          .onChange((value: boolean) => {
            this.showCoverImg = value;
          })
        Text('显示封面图')
      }.width('100%').margin({ bottom: 6 })

      Row() {
        Checkbox()
          .select(this.showProgressBar)
          .shape(CheckBoxShape.ROUNDED_SQUARE)
          .onChange((value: boolean) => {
            this.showProgressBar = value;
          })
        Text('显示进度条')
      }.width('100%').margin({ bottom: 6 })

      Row() {
        Text('视频播放条件')
        Select([{ value: '仅WiFi自动播放' }, { value: '始终自动播放' }, { value: '从不自动播放' }])
          .selected(1)
          .value('始终自动播放')
          .onSelect((index: number, value: string) => {
            this.autoPlayPolicy = index;
          })
          .backgroundColor(Color.White)
      }.width('100%').margin({ bottom: 6 })
    }
  }

  getParam(): NativeAdParam {
    return {
      posId: this.posId,
      adInterval: this.adInterval,
      autoPlayMuted: this.autoPlayMuted,
      autoPlayPolicy: this.autoPlayPolicy,
      showCoverImg: this.showCoverImg,
      showProgressBar: this.showProgressBar,
    };
  }

  @Builder
  settingsContent() {
    PosIdSelector({
      posId: this.posId!!,
      posIdArr: this.posIdArr,
    })
    Blank(10)
    Row() {
      Text('消息流（间隔n个插入广告）：')
      TextInput({ text: '5' })
        .fontSize(20)
        .showUnderline(true)
        .width(120)
        .onChange((value: string) => {
          this.adInterval = Number.parseInt(value);
        })
    }.width('100%')

    Blank(10)
    this.videoOptionsConfig();
  }

  @Builder
  actionsContent() {
    Blank(10)
    ButtonItem({ title: '简单示例' })
      .onClick(() => {
        this.pathStack.pushPath({ name: 'NativeManualAdSimplePage', param: this.getParam() },
          { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
      })
    Blank(10)
    ButtonItem({ title: '消息流示例' })
      .onClick(() => {
        this.pathStack.pushPath({ name: 'NativeManualAdListPage', param: this.getParam() },
          { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
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
    .title('原生广告（开发者自渲染）')
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    }).onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as AdPageParam | undefined;
      if (param?.autoLoadAndShow) {
        const nativeParam = this.getParam();
        nativeParam.autoLoadAndShow = true;
        nativeParam.orientation = param.orientation;
        // 子页路由由 SDK 算好，未传 / 非白名单时兜底简单示例
        const subPage = (param.subPage && VALID_SUB_PAGES.has(param.subPage)) ?
          param.subPage : DEFAULT_SUB_PAGE;
        this.pathStack.pushPath(
          { name: subPage, param: nativeParam },
          { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON },
        );
      }
    })
  }

  aboutToDisappear(): void {
    OrientationHelper.restoreAutoRotation();
  }
}
