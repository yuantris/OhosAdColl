import { ButtonItem } from '../components/ButtonItem';
import { PosIdSelector } from '../components/PosIdSelector';
import { AdConstants } from '@gdt/gdt-union-demo/ets/constants/AdConstants';
import { NativeAdParam } from '../model/NativeAdParam';
import { AdPageParam } from '../model/AdPageParam';
import { OrientationHelper } from '../utils/OrientationHelper';
import { AdaptiveLayout } from '../components/AdaptiveLayout';


@Builder
export function PageBuilder() {
  NativeAdEntryPage()
}

/** 合法子页路由白名单 —— 防止外部传入未在 router_map.json 注册的路由名导致跳转异常 */
const VALID_SUB_PAGES: ReadonlySet<string> = new Set<string>([
  'NativeAdSimplePage',
  'NativeAdListPage',
]);
const DEFAULT_SUB_PAGE = 'NativeAdSimplePage';

@ComponentV2
struct NativeAdEntryPage {
  pathStack: NavPathStack = new NavPathStack();
  loadAndShow: boolean = false;
  @Local posId: string = AdConstants.NATIVE_DEFAULT_POS_ID;
  @Local autoPlayMuted: boolean = false;
  private readonly posIdArr: Array<[string, string]> = AdConstants.NATIVE_POS_ID_LIST;
  @Local adInterval: number = 5;

  @Builder
  videoOptionsConfig() {
    Row() {
      Checkbox()
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .onChange((value: boolean) => {
          this.autoPlayMuted = value;
        })
      Text('静音播放')
    }.width('100%')
  }

  getParam(): NativeAdParam {
    return {
      posId: this.posId,
      adInterval: this.adInterval,
      autoPlayMuted: this.autoPlayMuted,
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
        this.pathStack.pushPath({ name: 'NativeAdSimplePage', param: this.getParam() },
          { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
      })
    Blank(10)
    ButtonItem({ title: '消息流示例' })
      .onClick(() => {
        this.pathStack.pushPath({ name: 'NativeAdListPage', param: this.getParam() },
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
    .title('原生广告（腾讯营销联盟渲染）')
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
