import { router } from '@kit.ArkUI';
import {
  AdSwitchManager,
  ADHelper,
  IndependentAd,
  OnAdListener,
  RequestApplication,
  SDKCore,
  SplashAdComponent
} from '@zysdk/ad-core-hm';
import App from '../app/App';

@Entry
@Component
struct Splash {
  @State ad: IndependentAd | undefined = undefined;
  // 广告监听器
  private adListener: OnAdListener = {
    onAdClose: () => {
      // 广告关闭，跳转到主页面
      this.gotoMainPage()
    },
    onAdShowError: (code: number, msg: string) => {
      console.debug('AdCoreLog', `开屏加载异常： code: ${code}, msg: ${msg}`)
      // 只有在所有平台都失败时才跳转到首页
      // 平台切换时不会触发此回调
      this.gotoMainPage()
    },
    onAdPlatformSwitchStart: (currentPlatform: number, nextPlatform: number) => {
      console.log('AdCoreLog', `${currentPlatform}平台开屏加载异常，准备切换：${nextPlatform}`)
    },
    onAdPlatformSwitchSuccess: (previousPlatform: number, currentPlatform: number) => {
      console.log('AdCoreLog', `平台切换成功，从${previousPlatform}切换到${currentPlatform}`)
    }
  };

  async aboutToAppear() {
    // AD.enableV4AD = false
    await ADHelper.getInstance().init()
    // RequestApplication.clearAllData()
    const result = await ADHelper.getInstance().loadSplashAd(this.adListener);
    this.ad = result.ad ?? undefined;
  }

  private gotoMainPage() {
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Column() {
      SplashAdComponent({
        ad: this.ad,
        adListener: this.adListener
      })
    }.backgroundImage($r('app.media.app_start'))
    .backgroundImageSize(ImageSize.FILL)
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 0 })
    PageTransitionExit({ type: RouteType.None, duration: 0 })
  }
}