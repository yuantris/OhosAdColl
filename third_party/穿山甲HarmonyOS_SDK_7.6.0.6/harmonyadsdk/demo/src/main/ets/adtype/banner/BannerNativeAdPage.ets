import {
  AdSlotBuilder,
  CSJAdCreator,
  CSJAdSdk,
  CSJArrayList,
  CSJConstant,
  CSJImage,
  CSJNativeAd,
  CSJNativeAdListener,
  FilterWord
} from '@csj/openadsdk'
import { ArrayList, util } from '@kit.ArkTS'
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils'
import { customDislikeComponent } from '../customdislike/CustomDislikeComponent'

/**
 * Created by Wuzejian on 2024/2/5
 * Usage:  banner 原生广告渲染案例
 */
@Entry
@Component
export struct BannerNativeAdPage {
  @State private status: string = "未加载"
  @State private isShowAd: boolean = false
  private declare mAd: CSJNativeAd;
  private mWidth: number = 300;
  private mHeight: number = 250;
  private isNeedDislikeDialog: boolean = false;
  private mBiddingAdm = '' //服务端bidding才需要设置
  private stateUpdate: (status: string) => void = (status: string) => {
    this.status = status;
  }

  /**
   * 加载Banner广告
   */
  loadBannerAd() {
    let adCreator = CSJAdSdk.getAdCreator()
    let adSlot = new AdSlotBuilder()
      .setCodeId("956393125")
      .setAcceptSize(300, 250)
      .setSupportRenderControl(true)//支持模板渲染
      .setAdCount(1)
      .setBidAdm(this.mBiddingAdm)
      .build()
    PrintBiddingTokenUtils.printBiddingToken(adSlot, adCreator);
    adCreator.loadNativeAd(adSlot, this.mLoadListener)
    this.stateUpdate("广告加载中")

    this.mWidth = adSlot.getAcceptWidth();
    this.mHeight = adSlot.getAcceptHeight();
  }

  private mLoadListener: CSJNativeAdListener = {
    /**
     * 加载失败的回调
     *
     * @param code
     * @param message
     */
    onError: (code: number, message: string) => {
      console.error("加载广告失败，code=" + code + "，message=" + message);
      this.stateUpdate("加载广告失败，code=" + code + "，message=" + message)
    },

    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */
    onNativeAdLoad: (ads: ArrayList<CSJNativeAd>) => {
      console.log("BannerExpressAdPage==onNativeAdLoad......success.....");
      if (ads && !ads.isEmpty()) {
        let ad: CSJNativeAd = ads[0];
        //[支持模板样式]:需要支持模板广告和原生广告样式的切换，需要调用supportRenderControl
        ad.setExpressRenderListener({
          onRenderSuccess: (width: number, height: number, isExpress: boolean) => {
            this.mAd = ad;
            this.stateUpdate("广告加载完成待展示");
          }
        })
        //设置广告交互监听
        this.setAdInteractionListener(ad);
        //设置dislike
        this.setDislikeCallback(ad);
        //渲染广告
        ad.render(this.getUIContext())
      }
    }
  }

  /**
   * 设置广告交互监听
   * @param ad
   */
  setAdInteractionListener(ad: CSJNativeAd) {
    ad?.setAdInteractionListener( {
      /**
       * 普通点击事件
       * @param ad
       */
      onAdClicked: (ad: CSJNativeAd) => {
        console.log("BannerNativeAdPage==onAdClicked......");
      },

      /**
       * 创意点击事件
       * @param ad
       */
      onAdCreativeClick: (ad: CSJNativeAd) => {
        console.log("BannerNativeAdPage==onAdCreativeClick......");
      },

      /**
       * show展示回调
       * @param ad
       */
      onAdShow: (ad: CSJNativeAd) => {
        console.log("BannerNativeAdPage==onAdShow......");
      }
    })
  }

  private setDislikeCallback(ad: CSJNativeAd) {
    ad.setDislikeCallback({
      /**
       * dislike show
       */
      onShow: () => {
        console.log("BannerNativeAdPage==dislike......show");
      },

      /**
       * @param position 选择的位置
       * @param value 选择的内容
       * @param enforceRemove 是否强制关闭广告
       */
      onSelected: (position: number, value: string, enforceRemove: boolean) => {
        this.isShowAd = !enforceRemove;
        console.log("BannerNativeAdPage==dislike......onSelected:position=" + position + ",value:" + value +
          ",enforce=" + enforceRemove);
      },

      /**
       * 点击取消
       */
      onCancel: () => {
        console.log("BannerNativeAdPage==dislike......onCancel");
      }

    })
  }

  aboutToDisappear() {
    if (this.mAd) {
      this.mAd.destroy() //释放资源
    }
  }

  build() {
    Column() {
      Row() {
        Text("adm：")
        TextInput({ placeholder: "adm" })
          .width("80%")
          .onChange((value) => {
            this.mBiddingAdm = value
            console.log(`csjAdm onChanage ${value}`)
          })
      }.margin({ top: 20 })

      Button("加载Banner广告")
        .onClick(() => {
          this.loadBannerAd()
        }).margin(8)
      Button("展示Banner广告")
        .onClick(() => {
          this.showBannerAd()
        }).margin(8)
      Text(`当前广告加载状态：${this.status}`)
        .fontColor(Color.Blue).margin(8)

      if (this.isShowAd) {
        if (this.mAd.isExpressAd()) {
          NodeContainer(this.mAd.getAdComponent())
        } else {
          this.BuildBannerAdUI(this.mAd)
        }
      }
    }.width('100%')
    .height('100%')
  }

  /**
   * 展示Banner广告
   */
  showBannerAd() {
    if (!this.mAd) {
      return
    }
    this.isShowAd = true
    this.status = "已展示"
  }

  /**
   * banner自渲染广告
   * @param ad
   */
  @Builder
  private BuildBannerAdUI(ad: CSJNativeAd, clickViewIds: CSJArrayList<string> = new CSJArrayList(),
    creativeViewIds: CSJArrayList<string> = new CSJArrayList(), rootComponentId: string = util.generateRandomUUID()) {
    Column() {
      Stack() {
        if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO ||
          ad.getImageMode() == CSJConstant.IMAGE_MODE_VIDEO_VERTICAL) {
          NodeContainer(ad.getAdComponent()).height(Math.floor(this.mHeight * 2 / 3))
            .width(this.mWidth)
            .margin(8)
        } else if (ad.getImageList()) {
          this.buildImageLayout(ad, creativeViewIds)
        }

        Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.End }) { // 子组件在容器主轴上行布局
          Image($r("app.media.tt_dislike"))
            .height(18)
            .width(18)
            .padding(3)
            .backgroundColor("#40ffffff")
            .borderRadius(9)
            .margin(5)
            .onClick((event: ClickEvent) => {
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
        }
        .width(this.mWidth)
        .height(Math.floor(this.mHeight * 2 / 3))
        .hitTestBehavior(HitTestMode.None)

        Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.End }) { // 子组件在容器主轴上行布局
          if (typeof ad.getAdLogo() === "string" && ad.getAdLogo() != "") {
            Text(ad.getAdLogo())
              .fontSize(6)
              .height(18)
              .width(25)
              .fontColor(Color.White)
              .backgroundColor("#40ffffff")
              .align(Alignment.Center)
              .padding({ left: 2 })
          } else {
            Image(ad.getAdLogo())
              .height(12)
              .width(20)
              .margin({ left: "93%" })
              .objectFit(ImageFit.Auto)
              .onClick((event: ClickEvent) => {
                ad.onAdClick(CSJConstant.TYPE_CLICK_LOGO, event);
              })
          }
        }
        .width(this.mWidth)
        .height(Math.floor(this.mHeight * 2 / 3))
        .hitTestBehavior(HitTestMode.None)

      }.height(Math.floor(this.mHeight * 2 / 3))
      .width(this.mWidth)

      Row() {
        Column() {
          //描述
          Text(ad.getDescription())
            .fontSize(11)
            .fontColor("#FF333333")
            .maxLines(1)
            .width("70%")
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费

          //标题
          Text(ad.getTitle())
            .fontSize(10)
            .fontColor("#50333333")
            .margin({ top: 6, bottom: 6 })
            .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费

        }.alignItems(HorizontalAlign.Start).margin({ left: 4, top: 6 })

        Button(ad.getButtonText())
          .height("50%")
          .width("20%")
          .padding({ left: 4, right: 4 })
          .fontSize(10)
          .borderRadius(3)
          .margin({ left: 6, right: 6 })
          .type(ButtonType.Normal)
          .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费

      }
      .width(this.mWidth)
      .height(Math.floor(this.mHeight * 1 / 4))
      .backgroundColor("#08000000")
      .justifyContent(FlexAlign.SpaceBetween)

    }.width(this.mWidth).height(this.mHeight).id(rootComponentId) //设置广告容器组件rootId
    .onAppear(() => {
      //注册计费事件
      ad.registerViewForInteraction(rootComponentId, this.getUIContext(), clickViewIds,
        creativeViewIds)
    })
  }

  /**
   * 图片类型广告布局
   * @param ad
   */
  @Builder
  buildImageLayout(ad: CSJNativeAd, creativeViewIds: CSJArrayList<string>) {
    if (ad.getImageMode() == CSJConstant.IMAGE_MODE_LARGE_IMG) { //大图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .imageStyle()
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_SMALL_IMG) { //小图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .imageStyle()
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_VERTICAL_IMG) { //垂直大图
      Image(this.getImageUrl(ad))
        .objectFit(ImageFit.Cover)
        .imageStyle()
        .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
    } else if (ad.getImageMode() == CSJConstant.IMAGE_MODE_GROUP_IMG) { //组图
      Row({ space: 10 }) {
        ForEach((ad.getImageList() ??new ArrayList<CSJImage>()).convertToArray(), (image: CSJImage) => {
          Image(image.getImageUrl())
            .objectFit(ImageFit.Cover)
            .width(((100 / (ad.getImageList()?.length ?? 0) - 1) + "%"))
            .height("100%")
            .id(creativeViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费;
        })
      }.justifyContent(FlexAlign.SpaceBetween).alignItems(VerticalAlign.Center).imageStyle()
    }
  }

  @Styles
  imageStyle(){
    .height(Math.floor(this.mHeight * 2 / 3))
    .width(this.mWidth)
    .margin(8)
  }

  private getImageUrl(ad: CSJNativeAd): string {
    let imageList = ad.getImageList();
    if (imageList && imageList.length > 0) {
      return imageList[0].getImageUrl()
    }
    return ""
  }

}