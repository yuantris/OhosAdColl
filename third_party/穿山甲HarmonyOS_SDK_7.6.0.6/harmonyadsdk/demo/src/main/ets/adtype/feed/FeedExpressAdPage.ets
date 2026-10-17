/**
 * Created by Wuzejian on 2024/2/17
 * Usage:  feed 模板广告案例
 */
import {
  AdSlot,
  AdSlotBuilder,
  CSJAdCreator,
  CSJNativeExpressAd,
  NativeExpressAdListener,
  CSJConstant,
  CSJAdSdk
} from '@csj/openadsdk';
import { ArrayList } from '@kit.ArkTS';
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils';
import { router } from '@kit.ArkUI';

@Entry
@Component
export struct FeedExpressAdPage {
  @State private listArray: Array<string | CSJNativeExpressAd> = new Array();
  @State private errorMsg: string | undefined = undefined;
  @State private dislikeStatus: boolean = false;
  private mBiddingAdm = '' //服务端Bidding才需要设置
  @State private loadMore: boolean = false

  /**
   * 界面展示时，加载
   */
  aboutToAppear(): void {
    let params: Object = router.getParams()
    if (typeof params == 'string') {
      this.mBiddingAdm = params
    }
    //加载feed广告
    this.loadExpressFeedAd();
  }

  /**
   * 加载广告
   */
  loadExpressFeedAd(): void {
    let adCreator = CSJAdSdk.getAdCreator()
    let adSlot: AdSlot =
      new AdSlotBuilder().setCodeId("955804505").setBidAdm(this.mBiddingAdm).setAcceptSize(390, 0).build()
    PrintBiddingTokenUtils.printBiddingToken(adSlot, adCreator);
    adCreator.loadExpressFeedAd(adSlot, this.expressLoadAdListener)
  }

  /**
   * 创建广告加载回调监听
   */
  private expressLoadAdListener: NativeExpressAdListener = {
    /**
     * 加载失败的回调
     *
     * @param code
     * @param message
     */
    onError: (code: number, message: string) => {
      console.error("加载expressFeed 广告失败，code=" + code + "，message=" + message);
      this.errorMsg = "加载expressFeed 广告失败，code=" + code + "，message=" + message;
    },

    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */

    onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
      console.log("FeedExpressAdPage==onNativeExpressAdLoad......success");
      if (ads && ads.length > 0) {
        ads.forEach((ad: CSJNativeExpressAd, idx: number) => {
          ad.setExpressInteractionListener({
            /**
             *广告的点击回调
             * @param type 广告的交互类型
             */
            onAdClicked: (type: number) => {
              console.log("FeedExpressAdPage==onAdClicked......");
            },

            /**
             * 广告的展示回调 每个广告仅回调一次
             * @param type 广告的交互类型
             */
            onAdShow: (type: number) => {
              console.log("FeedExpressAdPage==onAdShow......");
            },

            /**
             * 模板渲染失败
             */
            onRenderFail: (code: number, msg: string) => {
              console.log("FeedExpressAdPage==onRenderFail...code=" + code + ",msg=" + msg);
              this.errorMsg = "onRenderFail...code=" + code + ",msg=" + msg;
            },

            /**
             * 模板渲染成功
             * @param width  返回view的宽 单位 vp
             * @param height 返回view的高 单位 vp
             */
            onRenderSuccess: (width: number, height: number) => {
              let size: number = this.listArray.length;
              for (let i = size; i < size + 2; i++) {
                this.listArray.push(i.toString())
              }
              console.log("FeedExpressAdPage==onRenderSuccess......width=" + width + ",height=" + height);
              this.listArray.push(ad)
              size = this.listArray.length;
              for (let i = size; i < size + 10; i++) {
                this.listArray.push((i + 3).toString())
              }
              this.loadMore = false
            }
          })
          //设置监听回调
          this.setVideoListener(ad);
          //设置dislike
          this.setDislikeCallback(ad);
          //渲染广告
          ad.render(this.getUIContext())
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
        console.log("FeedExpressAdPage==dislike......show");
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        this.dislikeStatus = enforceRemove;
        console.log("FeedExpressAdPage==dislike......onSelected:position=" + position + ",value:" + value +
          ",enforce=" + enforceRemove);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        console.log("FeedExpressAdPage==dislike......onCancel");
      }

    })
  }

  /**
   * 设置视频监听
   * @param ad
   */
  private setVideoListener(ad: CSJNativeExpressAd) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
      ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
      ad.setVideoAdListener({
        onVideoLoad: () => {
          console.log("FeedExpressAdPage==onVideoLoad......");
        },
        /**
         * 视频广告加载失败（原生MediaPlayer内部提供的错误类型）
         * @param errorCode 错误类型：
         *
         */
        onVideoError: (errorCode: number, errorMsg: string) => {
          console.log("FeedExpressAdPage==onVideoError......errorCode=" + errorCode + ",errorMsg=" + errorMsg);
        },

        /**
         * 视频广告播放回调
         *
         * @param ad
         */
        onVideoAdStartPlay: () => {
          console.log("FeedExpressAdPage==onVideoAdStartPlay......");
        },

        /**
         * 视频广告暂停回调
         *
         * @param ad
         */
        onVideoAdPaused: () => {
          console.log("FeedExpressAdPage==onVideoAdPaused......");
        },

        /**
         * 视频广告续播
         *
         * @param ad
         */
        onVideoAdContinuePlay: () => {
          console.log("FeedExpressAdPage==onVideoAdContinuePlay......");
        },

        /**
         * 视频播放进度
         *
         * @param current
         * @param duration
         */
        onProgressUpdate: (current: number, duration: number) => {
          // console.log("FeedExpressAdPage==onProgressUpdate......current=" + current + ",duration=" + duration);
        },

        /**
         * 视频广告播放完成回调
         *
         * @param ad
         */
        onVideoAdComplete: () => {
          console.log("FeedExpressAdPage==onVideoAdComplete......");
        },

        /**
         * 点击重播(Draw)
         */
        onClickReplay: () => {

        }
      })
    }
  }

  /**
   * 构建广告UI
   */
  build() {
    Row() {
      if (this.errorMsg) {
        Text(this.errorMsg).fontSize(18).fontColor(Color.Red).margin(10);
      }
      List() {
        ForEach(this.listArray, (item: string | CSJNativeExpressAd) => {
          ListItem() {
            if (typeof item === 'string') {
              this.BuildCommonItem(item)
            } else if (item && !this.dislikeStatus) {
              NodeContainer(item.getAdComponent()).width("100%")
            }
          }
          .align(Alignment.Center)
          .backgroundColor((typeof item === 'string') ? Color.Orange : Color.White)
          .width('100%')
          .onDisAppear(() => {
            if (typeof item != 'string') {
              item.destroy(); //释放资源
            }
          })
        }, (item: string | CSJNativeExpressAd, index: number) => {
          return item.toString() + "_" + index
        })

        if (this.loadMore) {
          ListItem() {
            Text("正在加载...").height(60)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
          }.width("100%")
        }
      }.divider({ strokeWidth: 1, color: Color.Gray })
      .scrollBar(BarState.Off)
      .align(Alignment.Center)
      .onReachEnd(() => {
        this.loadMore = true;
        console.log("FeedExpressAdPage:onReachEnd=>到底了-->加载更多数据")
        this.loadExpressFeedAd();
      })

    }

  }

  /**
   * 非广告Item
   * @param text
   */
  @Builder
  BuildCommonItem(text: string) {
    Row() {
      Text(text)
        .height(100)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 30, bottom: 30 })
    }
  }
}

