import { AdSlot, AdSlotBuilder, CSJAdCreator,
  CSJAdSdk,
  CSJRewardAd, RewardAdLoadListener,
  RewardAdPlayAgainListener } from '@csj/openadsdk'
import { ToastUtil } from '../../util/ToastUtil'
import { DemoConstants } from '../../entryability/DemoConstants'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'

@Entry
@Component
export struct RewardAdPage {
  @State private mLoadState: string = "未加载"
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private mAd: CSJRewardAd | undefined
  private mBiddingAdm = '' //服务端Bidding才需要设置
  private mLoadListener: RewardAdLoadListener = {
    onAdLoaded: (rewardAd: CSJRewardAd) => {
      this.mLoadState = "Loaded"
      this.mAd = rewardAd
      console.log("RewardAdLoadListener", "Callback --> onAdLoaded")
      rewardAd.setInteractionListener({
        onShow: () => {
          ToastUtil.showToastOnMainWindow("onShow")
          console.log("RewardAdInteractionListener", "Callback --> onShow")
        },
        onSkip: () => {
          ToastUtil.showToastOnMainWindow("onSkip")
          console.log("RewardAdInteractionListener", "Callback --> onSkip")
        },
        onClick: () => {
          ToastUtil.showToastOnMainWindow("onClick")
          console.log("RewardAdInteractionListener", "Callback --> onClick")
        },
        onClose: () => {
          ToastUtil.showToastOnMainWindow("onClose")
          console.log("RewardAdInteractionListener", "Callback --> onClose")
        },
        onComplete: () => {
          ToastUtil.showToastOnMainWindow("onComplete")
          console.log("RewardAdInteractionListener", "Callback --> onComplete")
        },
        onRewardArrived: (isVerify, rewardType, extraInfo) => {
          ToastUtil.showToastOnMainWindow("onRewardArrived")
          console.log("RewardAdInteractionListener", `Callback --> onRewardArrived ${isVerify} ; ${rewardType} ; ${extraInfo}`)
        }
      })
      rewardAd.setPlayAgainListener({
        onShow: (againCount) => {
          console.log("RewardAgainListener", `Callback --> AgainCount ${againCount} onShow`)
        },
        onSkip: (againCount) => {
          console.log("RewardAgainListener", `Callback --> AgainCount ${againCount} onSkip`)
        },
        onClick: (againCount) => {
          console.log("RewardAgainListener", `Callback --> AgainCount ${againCount} onClick`)
        },
        onComplete: (againCount) => {
          console.log("RewardAgainListener", `Callback --> AgainCount ${againCount} onComplete`)
        },
        onRewardArrived: (againCount, isVerify, rewardType, extraInfo) => {
          ToastUtil.showToastOnMainWindow("onRewardArrived")
          console.log("RewardAdInteractionListener", `Callback --> AgainCount ${againCount} onRewardArrived verify: ${isVerify} ; type: ${rewardType} ; extra: ${extraInfo}`)
        },
        getPlayAgainCondition: (nextCount) => {
          console.log("RewardAgainListener", `Callback --> getPlayAgainCondition ${nextCount}`)
          return new Promise((resolve, reject) => {
            // 进行网络请求等
            let obj = new Object({
              "allow": nextCount <= 2,
              "name": "金币",
              "amount": nextCount
            })
            resolve(obj)
          })
        }
      })
    },
    onAdCached: () => {
      this.mLoadState = "Cached"
      console.log("RewardAdLoadListener", "Callback --> onAdCached")
    },
    onError: (code: number, message: string) => {
      ToastUtil.showToastOnMainWindow(`广告加载出错了 code:${code}, message:${message}`)
      this.mLoadState = "加载失败"
      console.log("RewardAdLoadListener", `Callback --> onError code:${code}, message:${message}`)
    }
  }

  loadAd(adSlot: AdSlot) {
    PrintBiddingTokenUtils.printBiddingToken(adSlot, this.mAdCreator);
    this.mLoadState = "加载中"
    this.mAdCreator.loadRewardAd(adSlot, this.mLoadListener)
  }

  showAd() {
    if (!this.mAd) {
      ToastUtil.showToastOnMainWindow("请先加载广告")
      return
    }
    this.mAd?.showRewardAd(DemoConstants.windowStage)
    this.mAd = undefined
    this.mLoadState = "已展示"
  }

  build() {
    Column() {
      Text("激励广告演示")
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

      Row() {
        Button("竖版-模板激励")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("955804646")
              .setRewardName("金币")
              .setRewardAmount(1)
              .setBidAdm(this.mBiddingAdm)
              .build()
            this.loadAd(adSlot)
          })
      }.margin({
        top: 10
      })

      Row() {
        Button("横版-模板激励")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("956363865")
              .setRewardName("金币")
              .setRewardAmount(1)
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
    }.padding({
      left: 20,
      right: 20
    })
  }
}