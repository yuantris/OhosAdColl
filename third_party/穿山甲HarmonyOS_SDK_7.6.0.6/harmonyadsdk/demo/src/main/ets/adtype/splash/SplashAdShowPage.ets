import { CSJSplashAd, CSJSplashAdInteractionListener, CSJSplashAdCloseType } from '@csj/openadsdk';
import { NodeController, window } from '@kit.ArkUI';

@Entry({
  routeName: "SplashAdShowPage",
  storage: LocalStorage.getShared()
})
@Component
export struct SplashAdShowPage {
  @LocalStorageLink('splashAd') splashAd: CSJSplashAd | undefined = undefined
  @LocalStorageLink('splashAdWindow') _window: window.Window | undefined = undefined
  @LocalStorageProp('splashCustomCloseBtn') splashCustomCloseBtn: boolean = false

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