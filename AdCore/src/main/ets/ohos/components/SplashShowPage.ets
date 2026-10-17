import { RequestApplication } from '../application/RequestApplication'
import { ADControl } from '../helper/ADControl'
import { HwAdSplash } from '../../../../../Index'
import { SplashAdManager } from '../helper/ADHelper'
import { Log, Preferences } from '@zycore/common'
import { window } from '@kit.ArkUI'
import { StartHelper } from '../config/StartHelper'

let first = true

@Entry({
  routeName: 'SplashShowPage',
  storage: LocalStorage.getShared()
})
@Component
struct SplashShowPage {
  @State isHwAdShow: boolean = false
  @LocalStorageLink('window') _window: window.Window | undefined = undefined

  aboutToAppear(): void {
    Log.info(`进入热启动页面`)
    SplashAdManager.getInstance().showSplashAd((isHw) => {
      if (isHw) {
        this.isHwAdShow = true
      } else {
        this.returnPage()
      }
    })
  }

  aboutToDisappear(): void {
    ADControl.warmLscrShow()
  }

  returnPage() {

    if (this._window) {
      this._window.destroyWindow()
      // let test = AppStorage.get<boolean>("zy_onSplashAdFlush") ?? true
      if (first) {
        first = false
        if (this.isHwAdShow) {
          setTimeout(() => {
            StartHelper.checkSplashEvent()
          })
        }
      } else {

        // 除首次外开启热启动刷新
        ADControl.onSplashAdFlush()
      }
    }
  }

  build() {
    Column() {
      if (this.isHwAdShow) {
        HwAdSplash({
          onAdCloseCallback: () => {
            this.returnPage()
          }
        })
      }
    }.width('100%')
    .height('100%')
    // .backgroundImage(RequestApplication.appConfig.launcherBgRes)
    // .backgroundImageSize(ImageSize.FILL)

  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 0 })
    PageTransitionExit({ type: RouteType.None, duration: 0 })
  }
}