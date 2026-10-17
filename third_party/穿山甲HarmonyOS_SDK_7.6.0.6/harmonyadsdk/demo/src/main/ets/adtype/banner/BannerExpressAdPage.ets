import { AdSlot, AdSlotBuilder, CSJAdCreator,
  CSJAdSdk,
  CSJNativeExpressAd, NativeExpressAdListener } from '@csj/openadsdk'
import { ArrayList } from '@kit.ArkTS'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils';

/**
 * Created by Wuzejian on 2024/2/5
 * Usage:  banner 模板广告渲染案例
 */
@Entry
@Component
export struct BannerExpressAdPage {
  private declare bannerAd: CSJNativeExpressAd;
  @State private status: string = "未加载"
  @State private isShowAd: boolean = false
  private declare mAdSlot: AdSlot;
  private mBiddingAdm = '' //服务端bidding才需要设置
  private expressLoadAdListener: NativeExpressAdListener = {
    /**
     * 加载失败的回调
     *
     * @param code
     * @param message
     */
    onError: (code: number, message: string) => {
      console.error("加载广告失败，code=" + code + "，message=" + message);
      this.status = "加载广告失败，code=" + code + "，message=" + message;
    },

    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */

    onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
      console.log("BannerExpressAdPage==onNativeExpressAdLoad......success");
      if (ads && ads.length > 0) {
        ads.forEach((ad: CSJNativeExpressAd, idx: number) => {
          ad.setExpressInteractionListener({
            /**
             *广告的点击回调
             * @param type 广告的交互类型
             */
            onAdClicked: (type: number) => {
              console.log("BannerExpressAdPage==onAdClicked......");
            },

            /**
             * 广告的展示回调 每个广告仅回调一次
             * @param type 广告的交互类型
             */
            onAdShow: (type: number) => {
              console.log("BannerExpressAdPage==onAdShow......");
            },

            /**
             * 模板渲染失败
             */
            onRenderFail: (code: number, msg: string) => {
              console.log("BannerExpressAdPage==onRenderFail...code=" + code + ",msg=" + msg);
            },

            /**
             * 模板渲染成功
             * @param width  返回view的宽 单位 vp
             * @param height 返回view的高 单位 vp
             */
            onRenderSuccess: (width: number, height: number) => {
              console.log("BannerExpressAdPage==onRenderSuccess......width=" + width + ",height=" + height);
              this.bannerAd = ad;
              this.status = "广告加载完成待展示";
            }
          })
          //渲染广告
          ad.setSlideIntervalTime(30 * 1000);//设置轮播时间长
          this.setDislikeCallback(ad); //设置dislike
          ad.render(this.getUIContext())
          this.status = "广告加载中...";
        });
      }
    }
  }

  private setDislikeCallback(ad: CSJNativeExpressAd) {
    ad.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        console.log("BannerExpressAdPage==dislike......show");
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        this.isShowAd = !enforceRemove;
        console.log("BannerExpressAdPage==dislike......onSelected:position=" + position + ",value:" + value + ",enforce=" + enforceRemove);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        console.log("BannerExpressAdPage==dislike......onCancel");
      }

    })
  }

  /**
   * 加载Banner广告
   */
  loadBannerAd(width: number, height: number, rit: string) {
    this.isShowAd = false;
    let adCreator = CSJAdSdk.getAdCreator()
    this.mAdSlot = new AdSlotBuilder()
      .setCodeId(rit)
      .setAcceptSize(width, height)
      .setAdCount(1)
      .setBidAdm(this.mBiddingAdm)
      .build()
    PrintBiddingTokenUtils.printBiddingToken(this.mAdSlot, adCreator);
    adCreator.loadBannerAd(this.mAdSlot, this.expressLoadAdListener)
    this.status = "广告加载中..."
  }

  /**
   * 展示Banner广告
   */
  showBannerAd() {
    if (!this.bannerAd) {
      return
    }
    this.isShowAd = true
    this.status = "已展示"
  }

  build() {
    Column() {
      Row() {
        Button("300 * 45")
          .onClick(() => {
            this.loadBannerAd(300, 45, "955804721")
          }).margin(8)
        Button("300 * 75")
          .onClick(() => {
            this.loadBannerAd(300, 75, "955804734")
          }).margin(8)
        Button("300 * 250")
          .onClick(() => {
            this.loadBannerAd(300, 250, "955804667")
          }).margin(8)
      }

      Row() {
        Text("adm：")
        TextInput({ placeholder: "adm" })
          .width("80%")
          .onChange((value) => {
            this.mBiddingAdm = value
            console.log(`csjAdm onChanage ${value}`)
          })
      }.margin({ top: 20 })

      Button("展示Banner广告")
        .onClick(() => {
          this.showBannerAd()
        }).margin(8)

      Text(`广告加载状态：${this.status}`)
        .fontColor(Color.Blue).margin(8)

      if (this.isShowAd) {
        NodeContainer(this.bannerAd.getAdComponent())
          .width(this.mAdSlot.getAcceptWidth())
          .height(this.mAdSlot.getAcceptHeight())
          .alignSelf(ItemAlign.Center)
          .align(Alignment.Center);
      }
    }.width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)

  }

  aboutToDisappear() {
    if (this.bannerAd) {
      this.bannerAd.destroy()
    }
  }
}
