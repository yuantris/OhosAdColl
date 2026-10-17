import { AdComponent, advertising } from '@kit.AdsKit'
import { HwSplashAd } from '../helper/HwAdHelper'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RequestApplication } from '../application/RequestApplication'
import { AD, ADHelper } from '../../../../../Index'
import { csjHelper } from '../helper/CsjHelper'
import { logD, logE } from '../util/ADUtil'
import { TxSplashAd } from '../helper/TxHelper'

@Component
export struct HwAdSplash {
  @State ads: Array<advertising.Advertisement> = []
  @State displayOptions: advertising.AdDisplayOptions | undefined = undefined
  onAdCloseCallback?: () => void

  aboutToAppear(): void {
    const currentMode = ADHelper.getADModeV2(AD.zyOff);
    if (currentMode == AD.OFF_HW) {
      logD('HwAdSplash 开始加载')
      let hwads = new HwSplashAd(AD.HW_SPLASH_ID)
      hwads.loadAd(getContext(),
        (ads: Array<advertising.Advertisement>, adDisplayOptions: advertising.AdDisplayOptions) => {
          logD(`HwAdSplash request finished ads size: ${ads.length}`)
          this.ads = ads
          this.displayOptions = adDisplayOptions

          if (this.ads.length <= 0 && this.onAdCloseCallback) {
            this.onAdCloseCallback();
          }
        }, () => {
          logE("华为广告加载失败---开始切换")
          let nextAd = ADHelper.getNextAdPlatform()
          if (nextAd == AD.OFF_HW) {
            // 直接关闭开屏广告
            if (this.onAdCloseCallback) {
              this.onAdCloseCallback();
            }
          } else {
            switch (nextAd) {
              case AD.OFF_CSJ:
                csjHelper.loadSplashAd(this.getUIContext(), AD.CSJ_SPLASH_ID, (ad, error) => {
                  if (this.onAdCloseCallback) {
                    this.onAdCloseCallback();
                  }
                })
                break
              case AD.OFF_TX:
                new TxSplashAd()
                  .loadAd(() => {
                    if (this.onAdCloseCallback) {
                      this.onAdCloseCallback();
                    }
                  })
                break
            }
          }
        })
    } else {
      if (this.onAdCloseCallback) {
        this.onAdCloseCallback();
      }
    }

  }

  build() {
    Column() {
      if (this.ads.length > 0) {
        ForEach(this.ads, (ad: advertising.Advertisement, index: number) => {
          ListItem() {
            AdComponent({
              ads: [ad], displayOptions: this.displayOptions,
              interactionListener: {
                onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
                  hilog.info(0x0000, 'testTag', `HwAdSplash onStatusChanged status: ${status}`);
                  hilog.info(0x0000, 'testTag',
                    `HwAdSplash onStatusChanged shown: ${ad.shown} click: ${ad.clicked} data: ${data}`);
                  switch (status) {
                    case 'onAdOpen':
                      hilog.info(0x0000, 'testTag', '%{public}s', 'Status is onAdOpen');
                      break
                    case 'onAdClick':
                      hilog.info(0x0000, 'testTag', '%{public}s', 'Status is onAdClick');
                      break;
                    case 'onAdClose':
                      hilog.info(0x0000, 'testTag', '%{public}s', 'Status is onAdClose');
                      if (this.onAdCloseCallback) {
                        this.onAdCloseCallback();
                      }
                      break;
                  }
                }
              }
            })
          }.width('100%')
          .height('100%')
        })
      }
    }.width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    // .backgroundImage(RequestApplication.appConfig.launcherBgRes)
    // .backgroundImageSize(ImageSize.FILL)
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 0 })
    PageTransitionExit({ type: RouteType.None, duration: 0 })
  }
}