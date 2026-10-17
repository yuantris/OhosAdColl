import {
  AdSlotBuilder,
  CSJAdCreator,
  CSJSplashAd,
  CSJAdSdk,
  CSJSplashAdInteractionListener,
  CSJSplashAdLoadListener,
  CSJSplashAdCloseType,
  CSJSplashAdLoadParam,
  MediationAdInfo
} from '@csj/openadsdk'
import { UIUtil } from '../tools/UIUtil'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'
import { window } from '@kit.ArkUI'
import { DemoConstants } from '../../entryability/DemoConstants'

import('./SplashAdShowPage')

@Builder
function bottomViewBuilder() {
  Text('Bottom View')
    .backgroundColor(Color.Yellow)
    .width(UIUtil.getScreenWidthVp())
    .height(UIUtil.getScreenHeightVp() - adHeight)
}


@Builder
function closeBtnBuilder(closeBlock: () => Promise<void>) {
  Text('close')
    .textAlign(TextAlign.Center)
    .backgroundColor(Color.Yellow)
    .width(60)
    .height(60)
    .borderRadius(30)
    .margin({ top: 50, right: 40 })
    .onClick((event) => {
      closeBlock().then(() => {
        console.log("开屏自定义按钮广告关闭成功")
      }).catch((err: Error) => {
        console.log("开屏自定义按钮广告关闭失败：" + err.message)
      })
    })
}

let globalBuilder: WrappedBuilder<[]> = wrapBuilder(bottomViewBuilder)
let globalCloseBtnBuilder: WrappedBuilder<[closeBlock: () => Promise<void>]> = wrapBuilder(closeBtnBuilder)

let screenWidth: number = UIUtil.getScreenWidthVp()
let screenHeight: number = UIUtil.getScreenHeightVp()

let adWidth: number = Math.round(screenWidth)
let adHeight: number = Math.round(screenHeight)

@Entry
@Component
export struct SplashAdDemoPage {
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private splashAd: CSJSplashAd | undefined
  context = getContext(this)
  @State adLoadSuccess: Boolean = false
  @State errorMsg: string | undefined = undefined;
  @State startLoad: boolean = false;
  private mLoadListener: CSJSplashAdLoadListener = {
    onAdLoaded: (splashAd: CSJSplashAd) => {
      console.log("开屏回调 - onAdLoaded")
      this.splashAd = splashAd;
      this.adLoadSuccess = true;
      this.startLoad = false;
    },

    onError: (code: number, message: string) => {
      this.errorMsg = "onError code: " + code + "message: " + message;
      console.log(`开屏回调 - onError code: ${code} message: ${message}`)
    },

    onRenderSuccess: (splashAd: CSJSplashAd) => {
      this.splashAd = splashAd;
      this.adLoadSuccess = true;
      this.startLoad = false;
      console.log("开屏回调 - onRenderSuccess")
    },
    onRenderFail: (code: number, message: string) => {
      console.log("开屏回调 - onRenderFail")
    }
  }
  @State widthLabelText: string = "宽：" + adWidth
  @State heightLabelText: string = "高：" + adHeight
  private useCustomCloseBtn: boolean = false
  private loadTimeout: number = 3000
  private mWindow: window.Window | undefined = undefined

  build() {
    Column() {
      Row() {
        Text(this.widthLabelText)
        Slider({ value: screenWidth, min: 0, max: screenWidth })
          .width(200)
          .onChange((value, mode) => {
            adWidth = Math.round(value)
            this.widthLabelText = "宽：" + adWidth
          })
      }

      Row() {
        Text(this.heightLabelText)
        Slider({ value: screenHeight, min: 0, max: screenHeight })
          .width(200)
          .onChange((value, mode) => {
            adHeight = Math.round(value)
            this.heightLabelText = "高：" + adHeight
          })
      }

      Row() {
        Text("超时(ms)：")
        TextInput({ placeholder: `${this.loadTimeout}` })
          .width(200)
          .type(InputType.Number)
          .onChange((value) => {
            this.loadTimeout = Number.parseInt(value)
            console.log(`songcaili ${this.loadTimeout}}`)
          })
      }

      Row() {
        Text("自定义关闭按钮")
        Toggle({ type: ToggleType.Switch, isOn: false })
          .onChange((isOn: boolean) => {
            this.useCustomCloseBtn = isOn
          })
          .margin({ left: 10 })
      }
      .margin({ top: 20 })
      .height(50)

      Column() {
        Button("加载开屏广告")
          .margin({ top: 20 })
          .onClick(() => {
            this.errorMsg = undefined;
            this.adLoadSuccess = false;
            this.startLoad = true;
            let adSlot = new AdSlotBuilder()
              .setCodeId("103055163")
              .setAcceptSize(adWidth,
                adHeight)
              .build()
            let param = new CSJSplashAdLoadParam(adSlot, this.mLoadListener, this.getUIContext(), this.loadTimeout)
            PrintBiddingTokenUtils.printBiddingToken(adSlot, this.mAdCreator);
            this.mAdCreator.loadSplashAd(param)
          })

        if (this.startLoad || this.adLoadSuccess) {
          Text((this.adLoadSuccess ? "开屏广告加载完成，可点击展示" : "加载中...")).margin({ top: 20 })
            .visibility(this.errorMsg != undefined ? Visibility.None : Visibility.Visible)
        }
        if (this.errorMsg != undefined) {
          Text(this.errorMsg).fontColor(Color.Red).margin({ top: 20 });
        }
      }.justifyContent(FlexAlign.Start)


      Button("展示: 直接show")
        .margin({ top: 20 })
        .onClick(() => {
          if (this.splashAd != undefined) {
            // 方式一：直接showSplashAd
            this.splashAd.setInteractionListener(this.mSplashAdInteractionListener)
            if (adHeight < screenHeight) {
              this.splashAd?.showSplashAd(DemoConstants.windowStage, globalBuilder,
                this.useCustomCloseBtn ? globalCloseBtnBuilder : undefined)
            } else {
              this.splashAd?.showSplashAd(DemoConstants.windowStage, undefined,
                this.useCustomCloseBtn ? globalCloseBtnBuilder : undefined)
            }
          }
        })

      Button("展示：使用getAdComponent")
        .margin({ top: 20 })
        .onClick(() => {
          if (this.splashAd != undefined) {
            this.splashAd.setInteractionListener(this.mSplashAdInteractionListener)
            // 方式二：使用getAdComponent
            DemoConstants.windowStage.createSubWindow("GMSplashAdWindow", (err, window) => {
              if (!window) {
                return
              }
              this.mWindow = window
              let localStorage = new LocalStorage()
              localStorage.setOrCreate('GMSplashAd', this.splashAd)
              localStorage.setOrCreate('GMSplashSubWindow', window)
              localStorage.setOrCreate('GMSplashCustomCloseBtn', this.useCustomCloseBtn)
              window.loadContentByName('GMSplashAdShowPage', localStorage)
              window.showWindow()
            })
          }
        })

    }
    .width('100%')
    .padding({
      top: 10,
      left: 20,
      right: 20,
      bottom: 10
    })
  }

  // CSJSplashAdInteractionListener
  private mSplashAdInteractionListener: CSJSplashAdInteractionListener = {
    onDidShow: () => {
      console.log("开屏回调 - onDidShow")
      // 聚合show信息获取
      let info: object | undefined = this.splashAd?.getMediationAdInfo()
      if (info instanceof MediationAdInfo) {
        let showcpm = info.getShowEcpm()
        if (showcpm) {
          console.log("GMMediation_showcpm", "adnName:"+showcpm.getAdnName())
          console.log("GMMediation_showcpm", "ritType:"+showcpm.getRitType())
          console.log("GMMediation_showcpm", "adnRitId:"+showcpm.getAdnRitId())
          console.log("GMMediation_showcpm", "ecpm:"+showcpm.getEcpm())
        }
      }
    },

    onDidClose: (closeType: CSJSplashAdCloseType) => {
      console.log(`开屏回调 - onDidClose 关闭原因：${closeType.value}`)
      this.splashAd = undefined
      // 方式二：需自行移除广告
      this.mWindow?.destroyWindow()
    },

    onDidClick: () => {
      console.log("开屏回调 - onDidClick")
    },

    onVideoDidPlayFinish: () => {
      console.log("开屏回调 - onVideoDidPlayFinish")
    },

    onVideoDidPlayFail: () => {
      console.log("开屏回调 - onVideoDidPlayFail")
    }
  }
}