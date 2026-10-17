import { AdSlot, AdSlotBuilder, CSJAdCreator, CSJAdSdk, CSJFullAd, FullAdLoadListener } from '@csj/openadsdk'
import { ToastUtil } from '../../util/ToastUtil'
import { DemoConstants } from '../../entryability/DemoConstants'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'

@Entry
@Component
export struct FullAdPage {
  @State private mLoadState: string = "未加载"
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private mAd: CSJFullAd | undefined
  private mBiddingAdm = '' //服务端Bidding才需要设置
  private mLoadListener: FullAdLoadListener = {
    onAdLoaded: (fullAd) => {
      this.mLoadState = "Loaded"
      this.mAd = fullAd
      console.log("FullAdLoadListener", "Callback --> onAdLoaded")
      fullAd.setInteractionListener({
        onShow: () => {
          ToastUtil.showToastOnMainWindow("onShow")
          console.log("FullAdInteractionListener", "Callback --> onShow")
        },
        onSkip: () => {
          ToastUtil.showToastOnMainWindow("onSkip")
          console.log("FullAdInteractionListener", "Callback --> onSkip")
        },
        onClick: () => {
          ToastUtil.showToastOnMainWindow("onClick")
          console.log("FullAdInteractionListener", "Callback --> onClick")
        },
        onComplete: () => {
          ToastUtil.showToastOnMainWindow("onComplete")
          console.log("FullAdInteractionListener", "Callback --> onComplete")
        },
        onClose: () => {
          ToastUtil.showToastOnMainWindow("onClose")
          console.log("FullAdInteractionListener", "Callback --> onClose")
        }
      })
    },
    onAdCached: () => {
      this.mLoadState = "Cached"
      console.log("FullAdLoadListener", "Callback --> onAdCached")
    },
    onError: (code: number, message: string) => {
      ToastUtil.showToastOnMainWindow(`广告加载出错了 \n code:${code}, message:${message}`)
      this.mLoadState = "加载失败"
      console.log("FullAdLoadListener", "Callback --> onError")
    }
  }

  loadAd(adSlot: AdSlot) {
    this.mLoadState = "加载中"
    PrintBiddingTokenUtils.printBiddingToken(adSlot, this.mAdCreator);
    this.mAdCreator.loadFullAd(adSlot, this.mLoadListener)
  }

  showAd() {
    if (!this.mAd) {
      ToastUtil.showToastOnMainWindow("请先加载广告")
      return
    }
    this.mAd?.showFullAd(DemoConstants.windowStage)
    this.mAd = undefined
    this.mLoadState = "已展示"
  }

  build() {
    Column() {
      Text("新插屏广告演示")
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({
          top: 20,
          bottom: 20
        })
      Row() {
        Text("adm：")
        TextInput({ placeholder: "广告的adm" })
          .width("80%")
          .onChange((value) => {
            this.mBiddingAdm = value
            console.log(`csjAdm onChanage ${value}`)
          })
      }.margin({ top: 20 })
      Text("插屏广告")
        .fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
        .margin({
          top: 10
        })
      Row() {
        Button("竖版-模板-半屏")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("955804644")
              .setBidAdm(this.mBiddingAdm)
              .build()
            this.loadAd(adSlot)
          })
      }.margin({
        top: 10
      })
      Row() {
        Button("横版-模板-半屏")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("955804640")
              .setBidAdm(this.mBiddingAdm)
              .build()
            this.loadAd(adSlot)
          })
      }.margin({
        top: 10
      })
      Text("全屏广告")
        .fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
        .margin({
          top: 10
        })
      Row() {
        Button("竖版-模板-全屏")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("955806169")
              .setBidAdm(this.mBiddingAdm)
              .build()
            this.loadAd(adSlot)
          })
      }.margin({
        top: 10
      })
      Row() {
        Button("横版-模板-全屏")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("955804616")
              .setBidAdm(this.mBiddingAdm)
              .build()
            this.loadAd(adSlot)
          })
      }.margin({
        top: 10
      })
      Text(`广告加载状态：${this.mLoadState}`)
        .fontWeight(FontWeight.Bold)
        .fontSize(20)
        .margin(20)
      Button("广告展示")
        .width('100%')
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          this.showAd()
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
}