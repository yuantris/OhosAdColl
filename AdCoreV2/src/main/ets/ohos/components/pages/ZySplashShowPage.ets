import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI'
import { ADHelper } from '../../helper/core/ADHelper'
import { IndependentAd } from '../../helper/impl/IndependentAd'
import { OnAdListener } from '../../interface/OnAdListener'
import { SplashAdComponent } from '../SplashAdComponent'
import { HotStartManager } from '../../helper/core/HotStartManager'
import { LogManager } from '../../helper/logger/LogManager'

@Entry({
  routeName: 'ZySplashShowPage',
  storage: LocalStorage.getShared()
})
@Component
struct SplashShowPage {
  @State ad: IndependentAd | undefined = undefined;
  @LocalStorageLink('window') _window: window.Window | undefined = undefined
  // 广告监听器
  private adListener: OnAdListener = {
    onAdClose: () => {
      this.finishSplashAd()
    },
    onAdShowError: (code: number, msg: string) => {
      this.finishSplashAd()
    }
  };

  async aboutToAppear() {
    LogManager.info(`SplashShowPage`, `进入热启动页面`)

    try {
      // 加载广告并获取实例
      const result = await ADHelper.getInstance().loadSplashAd(this.adListener);
      this.ad = result.ad ?? undefined;
    } catch (error) {
      LogManager.error(`SplashShowPage`, `加载开屏广告失败: ${error}`)
    }
  }

  aboutToDisappear(): void {
    HotStartManager.warmStartDetector()
    HotStartManager.onSplashAdFlush()
  }

  finishSplashAd() {
    if (this._window) {
      this._window.destroyWindow().catch((error: BusinessError) => {
        LogManager.error(`SplashShowPage`, `destroyWindow失败: ${error}`)
      })
    }
  }

  build() {
    Column() {
      SplashAdComponent({
        ad: this.ad,
        adListener: this.adListener
      })
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