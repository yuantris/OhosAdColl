import { AdDebugFloatPanel } from '../components/debug/AdDebugFloatPanel';

/**
 * 调试悬浮窗宿主页面（AdDebugFloatController.loadContentByName 加载）
 */
@Entry({
  routeName: 'AdDebugFloatPage'
})
@Component
struct AdDebugFloatPage {
  build() {
    Column() {
      AdDebugFloatPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
