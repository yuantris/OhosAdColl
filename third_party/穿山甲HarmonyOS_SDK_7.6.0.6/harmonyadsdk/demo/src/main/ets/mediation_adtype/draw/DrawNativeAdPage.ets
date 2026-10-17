import {
  AdSlot,
  AdSlotBuilder,
  CSJAdCreator,
  CSJDrawAd,
  CSJArrayList,
  CSJDrawAdListener,
  CSJNativeAd,
  CSJConstant,
  CSJAdSdk,
  MediationAdInfo
} from '@csj/openadsdk';
import { ArrayList, util } from '@kit.ArkTS';
import { UIUtil } from '../tools/UIUtil';
import { PrintBiddingTokenUtils } from '../test/PrintBiddintTokenUtils';
import { router } from '@kit.ArkUI';

/**
 * Created by Wuzejian on 2024/2/5
 * Usage:  draw 原生广告渲染案例
 */
@Entry
@Component
export struct DrawNativeAdPage {
  @State private listArray: Array<CSJDrawAd> = new Array();
  private mWidth: number = UIUtil.getScreenWidthVp();
  private mHeight: number = UIUtil.getScreenHeightVp();

  aboutToAppear(): void {
    let params: Object = router.getParams()
    this.loadDrawAd();
  }

  /**
   * 加载draw广告
   */
  private loadDrawAd() {
    let adCreator = CSJAdSdk.getAdCreator()
    let adSlot: AdSlot = new AdSlotBuilder().setCodeId("103056847")
      .setAcceptSize(Math.floor(UIUtil.getScreenWidthVp()), Math.floor(UIUtil.getScreenHeightVp()))
      .setAdCount(1)
      .build()
    adCreator.loadDrawAd(adSlot, this.loadListener)
  }

  /**
   * 广告加载监听
   */
  private loadListener: CSJDrawAdListener = {
    /**
     * 加载失败的回调
     *
     * @param code
     * @param message
     */
    onError: (code: number, message: string) => {
      console.log("DrawNativeAdPage==code=" + code + ",message-" + message);
    },

    /**
     * 广告加载成功的回调，接入方可以在这个回调中进行渲染
     *
     * @param ads 返回的广告列表
     */
    onDrawAdLoad: (ads: ArrayList<CSJDrawAd>) => {
      console.log("DrawNativeAdPage==onDrawAdLoad......success");

      if (ads && ads.length > 0) {
        ads.forEach((ad: CSJDrawAd, idx: number) => {

          let info =  ad.getMediationAdInfo()
          if (info instanceof MediationAdInfo) {
            let showcpm = info.getShowEcpm()
            if (showcpm) {
              console.log("GMMediation_showcpm", "adnName:"+showcpm.getAdnName())
              console.log("GMMediation_showcpm", "ritType:"+showcpm.getRitType())
              console.log("GMMediation_showcpm", "adnRitId:"+showcpm.getAdnRitId())
              console.log("GMMediation_showcpm", "ecpm:"+showcpm.getEcpm())
            }
          }

          this.setAdInteractionListener(ad);//设置交互回调
          this.setVideoListener(ad); //视频相关回调
          //设置点击视频是否暂停； true：暂停
          ad.setCanInterruptVideoPlay(true);

          //【注意】
          //如果配置了模板自渲染混出
          //则需要给广告对象设置ExpressRenderListener监听，
          //然后调用广告对象的render()方法开始渲染，在渲染成功的回调中再更新广告数据
          ad.setExpressRenderListener({
            onRenderSuccess: (width: number, height: number, isExpress: boolean) => {
              this.listArray.push(ad);
            }
          });
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
  setAdInteractionListener(ad: CSJDrawAd) {
    ad?.setAdInteractionListener( {
      onAdClicked: (ad: CSJNativeAd) => {
        console.log("DrawNativeAdPage==onAdClicked......");
      },

      /**
       * 创意点击事件
       * @param ad
       */
      onAdCreativeClick: (ad: CSJNativeAd) => {
        console.log("DrawNativeAdPage==onAdCreativeClick......");
      },

      /**
       * show展示回调
       * @param ad
       */
      onAdShow: (ad: CSJNativeAd) => {
        console.log("DrawNativeAdPage==onAdShow......");
      }
    })
  }

  setVideoListener(ad:CSJDrawAd){
    ad.setDrawVideoListener({
      /**
       * 点击重播按钮
       */
      onClickReplay: () => {
        console.log("DrawNativeAdPage==onClickReplay......");
      }, /**
       * 视频广告加载成功
       *
       * @param ad
       */
      onVideoLoad: () => {
        console.log("DrawNativeAdPage==onVideoLoad......");
      },
      /**
       * 视频广告加载失败（原生MediaPlayer内部提供的错误类型）
       * @param errorCode 错误类型：
       *
       */
      onVideoError: (errorCode: number, errorMsg: string) => {
        console.log("DrawNativeAdPage==onVideoError......errorCode=" + errorCode + ",errorMsg=" + errorMsg);
      },

      /**
       * 视频广告播放回调
       *
       * @param ad
       */
      onVideoAdStartPlay: () => {
        console.log("DrawNativeAdPage==onVideoAdStartPlay......");
      },

      /**
       * 视频广告暂停回调
       *
       * @param ad
       */
      onVideoAdPaused: () => {
        console.log("DrawNativeAdPage==onVideoAdPaused......");
      },

      /**
       * 视频广告续播
       *
       * @param ad
       */
      onVideoAdContinuePlay: () => {
        console.log("DrawNativeAdPage==onVideoAdContinuePlay......");
      },

      /**
       * 视频播放进度
       *
       * @param current
       * @param duration
       */
      onProgressUpdate: (current: number, duration: number) => {
        // console.log("DrawNativeAdPage==onProgressUpdate......current=" + current + ",duration=" + duration);
      },

      /**
       * 视频广告播放完成回调
       *
       * @param ad
       */
      onVideoAdComplete: () => {
        console.log("DrawNativeAdPage==onVideoAdComplete......");
      }
    })
  }

  build() {
    Column() {
      ForEach(this.listArray, (ad: CSJDrawAd) => {
        ListItem() {
          if (ad.isExpressAd()) {
            NodeContainer(ad.getAdComponent())
          } else {
            this.buildAdLayout(ad)
          }
        }.onDisAppear(() => {
          if (ad) {
            ad.destroy(); //释放资源
          }
        })
      }, (item: CSJDrawAd, index: number) => {
        return item.toString() + "_" + index
      })

    }

  }

  /**
   * Draw自渲染广告
   * @param ad
   */
  @Builder
  private buildAdLayout(ad: CSJDrawAd, clickViewIds: CSJArrayList<string> = new CSJArrayList(),
    creativeViewIds: CSJArrayList<string> = new CSJArrayList(), rootComponentId: string = util.generateRandomUUID()) {
    Stack({ alignContent: Alignment.BottomStart }) {
      NodeContainer(ad.getAdComponent()).width(this.mWidth)
        .height(this.mHeight).hitTestBehavior(HitTestMode.None);

      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.End }) { // 子组件在容器主轴上行布局
        if (typeof ad.getAdLogo() === "string") {
          Text(ad.getAdLogo())
            .fontSize(6)
            .height(18)
            .width(25)
            .fontColor(Color.White)
            .backgroundColor("#40ffffff")
            .align(Alignment.Center)
            .padding({ left: 2 })
            .onClick((event: ClickEvent) => {
              ad.onAdClick(CSJConstant.TYPE_CLICK_LOGO, event);
            })
        } else {
          Image(ad.getAdLogo())
            .height(15)
            .width(25)
            .objectFit(ImageFit.Auto)
            .onClick((event: ClickEvent) => {
              ad.onAdClick(CSJConstant.TYPE_CLICK_LOGO, event);
            })
        }

      }.width(this.mWidth)
      .height(15)

      Row() {
        //广告主Icon
        Image(ad.getIcon()?.getImageUrl())
          .height(35)
          .width(35)
          .borderRadius(5)
          .margin({ right: 10, left: 10 })
          .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费

        //描述内容
        Text(ad.getDescription())
          .fontSize(11)
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .width("48%")
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费


        //创意按钮
        Button(ad.getButtonText(), { type: ButtonType.Normal })
          .fontSize(10)
          .borderRadius(5)
          .width("20%")
          .height(28)
          .padding(0)
          .margin({ top: 20, bottom: 20, left: 10, right: 10 })
          .id(creativeViewIds.addAdId(util.generateRandomUUID()))//设置组件Id，需要全局保证唯一性，涉及计费

      }
      .height("10%")
      .width("70%")
      .backgroundColor("#95ffffff")
      .borderRadius(5)
      .margin({ bottom: 35, left: 25 })
      .justifyContent(FlexAlign.Center)
      .id(rootComponentId)//设置广告组件rootId
      .onAppear(()=>{
        //注册计费事件
        ad.registerViewForInteraction(rootComponentId,this.getUIContext(), clickViewIds, creativeViewIds)
      });

    }
  }
}