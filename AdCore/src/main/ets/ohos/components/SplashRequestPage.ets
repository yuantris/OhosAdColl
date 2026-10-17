import { CSJSplashAd } from '@csj/openadsdk';
import { NodeController, window } from '@kit.ArkUI';
import { Log } from '@zycore/common';

@Entry({
  routeName: "SplashRequestPage",
  storage: LocalStorage.getShared()
})
@Component
struct SplashRequestPage {
  @LocalStorageLink('splashAd') splashAd: CSJSplashAd | undefined = undefined
  @LocalStorageLink('splashAdWindow') _window: window.Window | undefined = undefined
  @LocalStorageProp('splashCustomCloseBtn') splashCustomCloseBtn: boolean = false
  @State splashAdComponent: NodeController | undefined = undefined

  aboutToAppear(): void {
    Log.debug('进入SplashRequestPage页面')
    this.splashAdComponent = this.splashAd?.getAdComponent(this.splashCustomCloseBtn, this._window)
  }

  aboutToDisappear(): void {
    Log.debug('退出SplashRequestPage页面')
  }

  onPageShow(): void {
    this._window?.setWindowKeepScreenOn(true)
  }

  onPageHide(): void {
    this._window?.setWindowLayoutFullScreen(false)
  }

  build() {
    Stack() {
      if (this.splashAdComponent) {
        NodeContainer(this.splashAdComponent)
      }
    }
    .alignContent(Alignment.TopStart)
    .backgroundColor(Color.White)
  }

}