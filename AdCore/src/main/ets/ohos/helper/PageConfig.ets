import { PageInfo, uiObserver } from '@kit.ArkUI'

/**
 * 页面信息
 * 例如：开屏页
 * "name":"SplashRequestPage"
 * "path":"../../../../zyAdCore/src/main/ets/ohos/components/"
 */
export default class PageConfig implements PageInfo {
  routerPageInfo?: uiObserver.RouterPageInfo | undefined
  navDestinationInfo?: uiObserver.NavDestinationInfo | undefined

  constructor(routerPageInfo?: uiObserver.RouterPageInfo | undefined,
    navDestinationInfo?: uiObserver.NavDestinationInfo | undefined) {
    this.routerPageInfo = routerPageInfo
    this.navDestinationInfo = navDestinationInfo
  }
}