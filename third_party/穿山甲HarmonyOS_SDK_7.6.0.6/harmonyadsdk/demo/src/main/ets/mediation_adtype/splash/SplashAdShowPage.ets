import { CSJSplashAd } from '@csj/openadsdk';
import { NodeController, window } from '@kit.ArkUI';

@Entry({
  routeName: "GMSplashAdShowPage",
  storage: LocalStorage.getShared()
})
@Component
export struct SplashAdShowPage {
  @LocalStorageLink('GMSplashAd') splashAd: CSJSplashAd | undefined = undefined
  @LocalStorageLink('GMSplashSubWindow') _window: window.Window | undefined = undefined
  @LocalStorageProp('GMSplashCustomCloseBtn') splashCustomCloseBtn: boolean = false
  @State splashAdComponent: NodeController | undefined = undefined

  aboutToAppear(): void {
    this.splashAdComponent = this.splashAd?.getAdComponent(this.splashCustomCloseBtn, this._window)
  }

  onPageShow(): void {
    this._window?.setWindowLayoutFullScreen(true)
  }

  onPageHide(): void {
    this._window?.setWindowLayoutFullScreen(false)
  }

  build() {
    Stack() {
      if (this.splashAdComponent) {
        NodeContainer(this.splashAdComponent)
      }
      if (this.splashCustomCloseBtn) {
        Text('close')
          .textAlign(TextAlign.Center)
          .backgroundColor(Color.Yellow)
          .width(60)
          .height(60)
          .borderRadius(30)
          .margin({ left: 50, top: 50 })
          .onClick((event) => {
            this.closeBtnClicked()
          })
      }
    }
    .alignContent(Alignment.TopStart)
  }

  closeBtnClicked() {
    this._window?.destroyWindow()
  }
}