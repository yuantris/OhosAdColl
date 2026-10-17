import {
  AdSlot,
  AdSlotBuilder,
  CSJAdCreator,
  CSJAdSdk,
  CSJDrawAd,
  CSJNativeExpressAd,
  NativeExpressAdListener
} from '@csj/openadsdk';
import { ArrayList } from '@kit.ArkTS';
import { UIUtil } from '../tools/UIUtil';
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils';
import { router } from '@kit.ArkUI';

/**
 * Created by Wuzejian on 2024/2/5
 * Usage:  draw 模板广告渲染案例
 */
@Entry
@Component
export struct DrawExpressAdPage {
  @State private listArray: Array<string | CSJNativeExpressAd> = new Array();
  @State loadSuccess: boolean = false;
  private mBiddingAdm: string = '' //服务端Bidding才需要设置
  private expressLoadAdListener: NativeExpressAdListener = {
    /**
     * 加载失败的回调
     *
     * @param code
     * @param message
     */
    onError: (code: number, message: string) => {
      console.error("加载DrawExpressAdPage 广告失败，code=" + code + "，message=" + message);
    },

    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */

    onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
      console.log("DrawExpressAdPage==onNativeExpressAdLoad......success");
      if (ads && ads.length > 0) {
        ads.forEach((ad: CSJNativeExpressAd, idx: number) => {
          ad.setExpressInteractionListener({
            /**
             *广告的点击回调
             * @param type 广告的交互类型
             */
            onAdClicked: (type: number) => {
              console.log("DrawExpressAdPage==onAdClicked......");
            },

            /**
             * 广告的展示回调 每个广告仅回调一次
             * @param type 广告的交互类型
             */
            onAdShow: (type: number) => {
              console.log("DrawExpressAdPage==onAdShow......");
            },

            /**
             * 模板渲染失败
             */
            onRenderFail: (code: number, msg: string) => {
              console.log("DrawExpressAdPage==onRenderFail...code=" + code + ",msg=" + msg);
            },

            /**
             * 模板渲染成功
             * @param width  返回view的宽 单位 vp
             * @param height 返回view的高 单位 vp
             */
            onRenderSuccess: (width: number, height: number) => {
              console.log("DrawExpressAdPage==onRenderSuccess......width=" + width + ",height=" + height);
              this.listArray.push(ad)
              // for (let i = 0; i < 10; i++) {
              //   this.listArray.push((i + 3).toString())
              // }
            }
          })

          ad.setVideoAdListener({
            /**
             * 视频广告加载成功
             */
            onVideoLoad: () => {
              console.log("DrawExpressAdPage==onVideoLoad...");
            },

            /**
             * 视频广告加载失败
             */
            onVideoError: (errorCode: number, msg: string) => {
              console.log("DrawExpressAdPage==onVideoError......errorCode=" + errorCode + ",msg=" + msg);
            },

            /**
             * 视频广告播放回调
             */
            onVideoAdStartPlay: () => {
              console.log("DrawExpressAdPage==onVideoAdStartPlay...");
            },

            /**
             * 视频广告暂停回调
             */
            onVideoAdPaused: () => {
              console.log("DrawExpressAdPage==onVideoAdPaused...");
            },

            /**
             * 视频广告续播
             */
            onVideoAdContinuePlay: () => {
              console.log("DrawExpressAdPage==onVideoAdContinuePlay...");
            },

            /**
             * 视频播放进度
             *
             * @param current
             * @param duration
             */
            onProgressUpdate: (current: number, duration: number) => {
              // console.log("DrawExpressAdPage==onProgressUpdate......current=" + current + ",duration=" + duration);
            },

            /**
             * 视频广告播放完成回调
             */
            onVideoAdComplete: () => {
              console.log("DrawExpressAdPage==onVideoAdComplete...");
            },

            /**
             * 点击重播
             */
            onClickReplay: () => {
              console.log("DrawExpressAdPage==onClickReplay...");
            },
          })

          ad.setCanInterruptVideoPlay(true)
          //渲染广告
          ad.render(this.getUIContext())
        });
      }
    }
  }

  aboutToAppear(): void {
    let params: Object = router.getParams()
    if (typeof params == 'string') {
      this.mBiddingAdm = params
    }
    //加载Draw广告
    this.loadDrawAd();
  }

  /**
   * 加载draw广告
   */
  private loadDrawAd() {
    let adCreator = CSJAdSdk.getAdCreator()
    let adSlot: AdSlot = new AdSlotBuilder().setCodeId("955804605")
      .setAcceptSize(Math.floor(UIUtil.getScreenWidthVp()), Math.floor(UIUtil.getScreenHeightVp()))
      .setBidAdm(this.mBiddingAdm)
      .build()
    PrintBiddingTokenUtils.printBiddingToken(adSlot, adCreator);
    adCreator.loadExpressDrawAd(adSlot, this.expressLoadAdListener)
  }

  build() {
    Column() {
      ForEach(this.listArray, (ad: CSJNativeExpressAd) => {
        ListItem() {
          Stack({ alignContent: Alignment.BottomStart }) {
            NodeContainer(ad.getAdComponent());
          }
        }
        .width("100%")
        .onDisAppear(() => {
          if (ad) {
            ad.destroy(); //释放资源
          }
        })

      }, (item: CSJDrawAd, index: number) => {
        return item.toString() + "_" + index
      })

    }
  }
}