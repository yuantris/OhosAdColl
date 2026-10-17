import {
  AdSlot,
  AdSlotBuilder,
  CSJAdSdk,
  CSJArrayList,
  CSJConstant,
  CSJFeedAd,
  CSJFeedAdListener,
  CSJImage,
  CSJNativeAd,
  FilterWord
} from '@csj/openadsdk';
import { ArrayList, util } from '@kit.ArkTS';
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils';
import { router } from '@kit.ArkUI';
import { customDislikeComponent } from '../customdislike/CustomDislikeComponent';

/**
 * Created by Wuzejian on 2024/2/5
 * Usage:  feed 原生广告渲染案例
 */
@Entry
@Component
export struct FeedNativeAdPage {
  @State private listArray: Array<string | CSJFeedAd> = new Array();
  @State private error: string = "";
  @State private dislikeStatus: boolean = false;
  private mBiddingAdm = '' //服务端Bidding才需要设置
  private isNeedDislikeDialog = true;
  @State private loadMore: boolean = false

  /**
   * 页面启动加载广告
   */
  aboutToAppear(): void {
    let params: Object = router.getParams()
    if (typeof params == 'string') {
      this.mBiddingAdm = params
    }
    this.loadFeedAd();
  }

  /**
   * 加载feed广告
   */
  loadFeedAd(): void {
    let adCreator = CSJAdSdk.getAdCreator()
    let adSlot: AdSlot = new AdSlotBuilder().setCodeId("955804860")
      .setAcceptSize(350, 200)
      .setAdCount(3)
      .setBidAdm(this.mBiddingAdm)
      .setSupportRenderControl(true)
      .build();
    PrintBiddingTokenUtils.printBiddingToken(adSlot, adCreator);
    adCreator.loadFeedAd(adSlot, this.feedAdListener)
  }

  /**
   * 广告加载监听器
   */
  private feedAdListener: CSJFeedAdListener = {
    onError: (code: number, message: string) => {
      console.log("FeedNativeAdPage==code=" + code + ",message-" + message);
      this.error = "error code = " + code + ",message-" + message;
    },
    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */
    onFeedAdLoad: (ads: ArrayList<CSJFeedAd>) => {
      console.log("FeedNativeAdPage==onFeedAdLoad......success");
      if (ads && ads.length > 0) {
        ads.forEach((ad: CSJFeedAd, idx: number) => {
          //【注意】
          //如果打开了支持模板样式开关 supportRenderControl()：
          //则需要给广告对象设置ExpressRenderListener监听，
          //然后调用广告对象的render()方法开始渲染，在渲染成功的回调中再更新广告数据
          ad.setExpressRenderListener({
            onRenderSuccess: (width: number, height: number, isExpress: boolean) => {
              let size: number = this.listArray.length;
              for (let i = size; i < size + 3; i++) {
                this.listArray.push(i.toString())
              }
              this.listArray.push(ad)
              size = this.listArray.length;
              console.log("FeedNativeAdPage==onRenderSuccess......ad=imageMode:" + ad.getImageMode());
              for (let i = size; i < size + 6; i++) {
                this.listArray.push((i + 3).toString())
              }
              this.loadMore = false
            }
          });
          this.setAdInteractionListener(ad);
          this.setVideoListener(ad);
          this.setDislikeCallback(ad);
          //渲染广告
          ad.render(this.getUIContext())
        })
      }
    }
  }

  /**
   * 设置广告交互监听
   * @param ad
   */
  setAdInteractionListener(ad: CSJFeedAd) {
    ad?.setAdInteractionListener({
      onAdClicked: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdClicked......");
      },

      /**
       * 创意点击事件
       * @param ad
       */
      onAdCreativeClick: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdCreativeClick......");
      },

      /**
       * show展示回调
       * @param ad
       */
      onAdShow: (ad: CSJNativeAd) => {
        console.log("FeedNativeAdPage==onAdShow......");
      }
    })
  }

  private setDislikeCallback(ad: CSJFeedAd) {

    ad.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        console.log("FeedNativeAdPage==dislike......show");
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        this.dislikeStatus = enforceRemove;
        console.log("FeedNativeAdPage==dislike......onSelected:position=" + position + ",value:" + value + ",enforce=" +
          enforceRemove);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        console.log("FeedNativeAdPage==dislike......onCancel");
      }

    })
  }

  /**
   * 设置视频监听
   * @param ad
   */
  private setVideoListener(ad: CSJFeedAd) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
      ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
      ad.setVideoAdListener({
        onVideoLoad: () => {
          console.log("FeedNativeAdPage==onVideoLoad......");
        },
        /**
         * 视频广告加载失败
         * @param errorCode 错误类型：
         *
         */
        onVideoError: (errorCode: number, errorMsg: string) => {
          console.log("FeedNativeAdPage==onVideoError......errorCode=" + errorCode + ",errorMsg=" + errorMsg);
        },

        /**
         * 视频广告播放回调
         *
         * @param ad
         */
        onVideoAdStartPlay: () => {
          console.log("FeedNativeAdPage==onVideoAdStartPlay......");
        },

        /**
         * 视频广告暂停回调
         *
         * @param ad
         */
        onVideoAdPaused: () => {
          console.log("FeedNativeAdPage==onVideoAdPaused......");
        },

        /**
         * 视频广告续播
         *
         * @param ad
         */
        onVideoAdContinuePlay: () => {
          console.log("FeedNativeAdPage==onVideoAdContinuePlay......");
        },

        /**
         * 视频播放进度
         *
         * @param current
         * @param duration
         */
        onProgressUpdate: (current: number, duration: number) => {
          // console.log("FeedNativeAdPage==onProgressUpdate......current=" + current + ",duration=" + duration);
        },

        /**
         * 视频广告播放完成回调
         *
         * @param ad
         */
        onVideoAdComplete: () => {
          console.log("FeedNativeAdPage==onVideoAdComplete......");
        }
      })
    }
  }

  /**
   * UI布局构建
   */
  build() {
    Row() {
      if (this.error != "") {
        Text(this.error).fontSize(12).fontColor(Color.Red).margin(5)
      }
      List() {
        ForEach(this.listArray, (item: string | CSJFeedAd) => {
          ListItem() {
            if (typeof item === 'string') {
              this.BuildCommonItem(item)
            } else
              if (!this.dislikeStatus) {
                if (item.isExpressAd()) {
                  NodeContainer(item.getAdComponent())
                } else {
                  this.buildAdLayout(item);
                }
              }
          }
          .align(Alignment.Center)
          .width('100%')
          .height(285)
          .onDisAppear(() => {
            if (typeof item != 'string') {
              item.destroy(); //释放资源
            }
          })
        }, (item: string | CSJFeedAd, index: number) => {
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
      }
      .onReachEnd(() => {
        //底部加载更多
        this.loadMore=true;
        this.loadFeedAd();
      })
      .divider({ strokeWidth: 1, color: Color.Gray }).scrollBar(BarState.Off)
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
        .width('100%')
        .key("key")
        .textAlign(TextAlign.Center)
        .padding({ top: 30, bottom: 30 })

    }
  }

  /**
   * Feed自渲染广告
   * @param ad
   */
  @Builder
  private buildAdLayout(ad: CSJFeedAd, clickViewIds: CSJArrayList<string> = new CSJArrayList(),
    creativeViewIds: CSJArrayList<string> = new CSJArrayList(), rootComponentId: string = util.generateRandomUUID()) {
    Column() {
      Row() {
        Row() {
          //广告主Icon
          Image(ad.getIcon()?.getImageUrl())
            .height(32)
            .width(32)
            .borderRadius(5)
            .margin({ right: 5 })
            .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费

          //描述内容
          Text(ad.getDescription())
            .fontSize(12)
            .textAlign(TextAlign.Start)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
        }
        .height(35)
        .width("85%")
        .justifyContent(FlexAlign.Start);

        Row() {
          //dislike 按钮
          Image($r("app.media.tt_dislike")).onClick(() => {
            if (this.isNeedDislikeDialog) { //是否需要走定义Dislike弹窗
              //定义WrappedBuilder
              let customDislikeBuilder: WrappedBuilder<[fwList: Array<FilterWord>,
                onSelected: (filterPosition: number, filterName: string) => void,
                onOtherSuggestComment: (suggestionValue: string) => void,
                onUserSuggestDialogCancel: (commentValue: string) => void]> = wrapBuilder(customDislikeComponent);
              ad.getDislikeDialog()?.setCustomDislikeComponent(customDislikeBuilder)
            }
            ad.getDislikeDialog()?.showDislikeDialog(this)
          })
            .height(16)
            .width(16)
            .borderRadius(8)
        }.height(35)
        .width("10%")
        .justifyContent(FlexAlign.End);
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .height(35)
      .width("100%")
      .padding({ left: 10, right: 10, bottom: 4 })

      //视频|图片区域
      Stack({ alignContent: Alignment.BottomStart }) {
        if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
          ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
          NodeContainer(ad.getAdComponent())
        } else if (ad.getImageList()) {
          this.buildImageLayout(ad, creativeViewIds)
        }

        Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.End }) { // 子组件在容器主轴上行布局
          if (typeof ad.getAdLogo() === "string") {
            Text(ad.getAdLogo())
              .fontSize(6)
              .height(18)
              .width(30)
              .fontColor(Color.White)
              .backgroundColor("#40ffffff")
              .align(Alignment.Center)
              .padding({ left: 2 })
          } else {
            Image(ad.getAdLogo()).height(20).width(30).objectFit(ImageFit.Auto).onClick((event: ClickEvent) => {
              ad.onAdClick(CSJConstant.TYPE_CLICK_LOGO, event);
            })
          }
        }.width("100%")
        .height(20)

      }.height(200)

      Row() {
        //标题
        Text(ad.getTitle())
          .fontSize(12)
          .textAlign(TextAlign.Center)
          .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
        //创意按钮
        Button(ad.getButtonText(), { type: ButtonType.Normal })
          .fontSize(12)
          .borderRadius(5)
          .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .height(35)
      .width("100%")
      .padding({
        top: 5,
        bottom: 5,
        left: 10,
        right: 10
      })
    }
    .backgroundColor("#08000000")
    .id(rootComponentId) //设置广告容器组件rootId
    .onAppear(() => {
      //注册计费事件
      ad.registerViewForInteraction(rootComponentId, this.getUIContext(), clickViewIds, creativeViewIds)
    })
  }

  /**
   * 图片类型广告布局
   * @param ad
   */
  @Builder
  buildImageLayout(ad: CSJFeedAd, creativeViewIds: CSJArrayList<string>) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_LARGE_IMG) { //大图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_SMALL_IMG) { //小图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VERTICAL_IMG) { //垂直大图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_GROUP_IMG) { //组图
      Row({ space: 10 }) {
        ForEach((ad.getImageList() ?? new ArrayList<CSJImage>()).convertToArray(), (image: CSJImage) => {
          Image(image.getImageUrl())
            .objectFit(ImageFit.Cover)
            .width(((100 / (ad.getImageList()?.length ?? 0) - 1) + "%"))
            .height("100%")
            .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费;
        })
      }.justifyContent(FlexAlign.SpaceBetween).width("100%").alignItems(VerticalAlign.Center).height("100%")
    }
  }

  private getImageUrl(ad: CSJFeedAd): string {
    let imageList = ad.getImageList();
    if (imageList && imageList.length > 0) {
      return imageList[0].getImageUrl()
    }
    return ""
  }
}
