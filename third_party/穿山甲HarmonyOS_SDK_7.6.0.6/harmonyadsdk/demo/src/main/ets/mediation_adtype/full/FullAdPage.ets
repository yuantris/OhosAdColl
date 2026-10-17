import { AdSlot, AdSlotBuilder,
  CSJAdCreator,
  CSJAdSdk,
  CSJFullAd,
  MediationAdInfo,
  FullAdLoadListener } from '@csj/openadsdk'
import { ToastUtil } from '../../util/ToastUtil'
import { DemoConstants } from '../../entryability/DemoConstants'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'

@Entry
@Component
export struct FullAdPage {
  @State private mLoadState: string = "未加载"
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private mAd: CSJFullAd | undefined
  private mLoadListener: FullAdLoadListener = {
    onAdLoaded: (fullAd) => {
      this.mLoadState = "Loaded"
      this.mAd = fullAd
      console.log("FullAdLoadListener", "Callback --> onAdLoaded")
      fullAd.setInteractionListener({
        onShow: () => {
          let info =  this.mAd?.getMediationAdInfo()
          if (info instanceof MediationAdInfo) {
            let showcpm = info.getShowEcpm()
            if (showcpm) {
              console.log("GMMediation_showcpm", "adnName:" + showcpm.getAdnName())
              console.log("GMMediation_showcpm", "ritType:" + showcpm.getRitType())
              console.log("GMMediation_showcpm", "adnRitId:" + showcpm.getAdnRitId())
              console.log("GMMediation_showcpm", "ecpm:" + showcpm.getEcpm())
            }
          }
          ToastUtil.showToast("onShow")
          console.log("FullAdInteractionListener", "Callback --> onShow")
          this.mAd = undefined
        },
        onSkip: () => {
          ToastUtil.showToast("onSkip")
          console.log("FullAdInteractionListener", "Callback --> onSkip")
        },
        onClick: () => {
          ToastUtil.showToast("onClick")
          console.log("FullAdInteractionListener", "Callback --> onClick")
        },
        onComplete: () => {
          ToastUtil.showToast("onComplete")
          console.log("FullAdInteractionListener", "Callback --> onComplete")
        },
        onClose: () => {
          ToastUtil.showToast("onClose")
          console.log("FullAdInteractionListener", "Callback --> onClose")
        }
      })
    },
    onAdCached: () => {
      this.mLoadState = "Cached"
      console.log("FullAdLoadListener", "Callback --> onAdCached")
    },
    onError: (code: number, message: string) => {
      ToastUtil.showToast(`广告加载出错了 \n code:${code}, message:${message}`)
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
      ToastUtil.showToast("请先加载广告")
      return
    }
    this.mAd?.showFullAd(DemoConstants.windowStage)
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
              .setCodeId("103054600")
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
              .setCodeId("103056847")
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
              .setCodeId("103086407")
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
              .setCodeId("103086313")
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