import { AdSlot, AdSlotBuilder,
  AdSlotType,
  CSJAdCreator,
  CSJAdSdk,
  CSJRewardAd,
  MediationAdInfo,
  RewardAdLoadListener,
  RewardAdPlayAgainListener } from '@csj/openadsdk'
import { ToastUtil } from '../../util/ToastUtil'
import { DemoConstants } from '../../entryability/DemoConstants'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'
import { List } from '@kit.ArkTS'

@Entry
@Component
export struct RewardAdPage {
  @State private mLoadState: string = "未加载"
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()
  private mAd: CSJRewardAd | undefined
  private mLoadListener: RewardAdLoadListener = {
    onAdLoaded: (rewardAd: CSJRewardAd) => {
      this.mLoadState = "Loaded"
      this.mAd = rewardAd
      console.log("RewardAdLoadListener", "Callback --> onAdLoaded")
      rewardAd.setInteractionListener({
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
          console.log("RewardAdInteractionListener", "Callback --> onShow")
          this.mAd = undefined
        },
        onSkip: () => {
          ToastUtil.showToast("onSkip")
          console.log("RewardAdInteractionListener", "Callback --> onSkip")
        },
        onClick: () => {
          ToastUtil.showToast("onClick")
          console.log("RewardAdInteractionListener", "Callback --> onClick")
        },
        onClose: () => {
          ToastUtil.showToast("onClose")
          console.log("RewardAdInteractionListener", "Callback --> onClose")
        },
        onComplete: () => {
          ToastUtil.showToast("onComplete")
          console.log("RewardAdInteractionListener", "Callback --> onComplete")
        },
        onRewardArrived: (isVerify, rewardType, extraInfo) => {
          ToastUtil.showToast("onRewardArrived")
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
          ToastUtil.showToast("onRewardArrived")
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
      ToastUtil.showToast(`广告加载出错了 code:${code}, message:${message}`)
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
      ToastUtil.showToast("请先加载广告")
      return
    }
    this.mAd?.showRewardAd(DemoConstants.windowStage)
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
        Button("加载激励视频")
          .backgroundColor(Color.Orange)
          .onClick(() => {
            let adSlot = new AdSlotBuilder()
              .setCodeId("102922441")
              .setRewardName("金币")
              .setRewardAmount(1)
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