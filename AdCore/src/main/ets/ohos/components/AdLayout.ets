import { ADHelper } from '../helper/ADHelper'
import { IAd } from '../helper/impl/IAd'
import ADUtil, { logD, logE } from '../util/ADUtil'
import { NodeController, PageInfo, uiObserver } from '@kit.ArkUI'
import { AdType } from '../helper/ADConfig'
import { AdComponent, advertising } from '@kit.AdsKit'
import { CSJArrayList, CSJConstant, CSJFeedAd, CSJImage, FilterWord } from '@csj/openadsdk'
import { ArrayList, util } from '@kit.ArkTS'
import { customDislikeComponent } from './CustomDislikeComponent'
import { csjHelper, CsjInfoNativeAd } from '../helper/CsjHelper'
import { AD } from '../config/AD'
import { PrefUtil } from '../util/PrefUtil'
import { pref } from '../ability/AppAbility'
import { TxInfoAd, TxInfoAds } from '../helper/TxHelper'
import { EmitterUtils } from '@zycore/common'

const TAG = 'ADLayout'

// 订阅广告刷新
export const subscribe = 'NodeAd_Reception_'

@Component
export struct AdLayout {
  @Prop adId: string
  @Prop adName: string
  @Prop adType: AdType
  @State infoAd: NodeController | undefined = undefined
  @State listArray: Array<CSJFeedAd> = [];
  @State ads: Array<advertising.Advertisement> = [{
    adType: -1
  } as advertising.Advertisement]
  @State options: advertising.AdDisplayOptions | undefined = undefined
  @State flushed: boolean = false
  @State load: boolean = true
  @State currentAdProvider: Provider = Provider.Csj
  bgColor: ResourceColor = '' // 背景颜色
  adWidth: Length = 312 // 广告宽度（暂时只有华为生效）
  // 管理外部移除
  // @Link isRemove: boolean
  @State switchAttempts: number = 0 // 新增切换次数计数器
  private pageInfo: PageInfo = {}

  aboutToAppear(): void {
    this.switchAttempts = 0; // 重置计数器
    this.pageInfo = this.getUIContext().getPageInfoByUniqueId(this.getUniqueId())
    ADUtil.logD(TAG, `当前广告信息：${this.adName}--${this.adId}`)
    // ADUtil.logE(TAG, `event info is ${JSON.stringify(this.getUIContext().getPageInfoByUniqueId(this.getUniqueId()))}`)
    // ADUtil.logE(TAG, `ads size: ${this.ads.length}`)
    // ADUtil.logE(TAG, `ads options: ${JSON.stringify(this.options)}`)
    // 订阅广告刷新
    this.onADSubscribe()
    // 页面监听
    this.onPageChangeListener()
    // 开始加载广告
    this.loadAd()
  }

  aboutToDisappear(): void {
    this.switchAttempts = 0; // 重置计数器
    EmitterUtils.unSubscribe(subscribe + this.adId)
    //uiObserver.off('navDestinationUpdate');
  }

  // 加载广告
  loadAd() {
    this.currentAdProvider = this.getAdProviders()
    PrefUtil.get(this.getAdSpCacheKey(), true, pref).then((value) => {
      if (value) {
        this.load = true
      } else {
        this.disAppearAdContainer()
      }

      // 确认加载广告
      if (this.load) {
        this.flushedAdV2()
      }

    })
  }

  // 刷新请求广告
  flushedAdV2() {
    PrefUtil.get(this.getAdSpCacheKey(), true, pref).then((value) => {
      if (value) {
        switch (this.currentAdProvider) {
          case Provider.Csj:
            if (this.adType == AdType.NATIVE) {
              logD(`穿山甲原生广告加载--->页面回调--->${this.adId}`)
              csjHelper.loadInfoNativeAd(this.getUIContext(), this.adId, (listArray: Array<CSJFeedAd> | null) => {
                this.clearAd()
                if (listArray) {
                  ADUtil.logD(TAG, '广告加载--->页面回调--->触发原生刷新')
                  this.listArray = listArray
                } else {
                  // 切换或重试
                  if (this.switchAttempts >= ADHelper.getAvailableAdPlatforms(AD.zyOff).length) {
                    logE('所有广告平台尝试失败')
                    this.disAppearAdContainer();
                    return;
                  }
                  this.changeAdPlatform();
                }
              })
            } else {
              ADUtil.logD(TAG, '穿山甲信息流广告加载--->页面回调--->')
              let info = this.getUIContext().getPageInfoByUniqueId(this.getUniqueId())
              ADHelper.getInstance()
                .showInfoAD(info, this.adId, this.adType,
                  (ad: IAd<ESObject>) => {
                    this.clearAd()
                    ADUtil.logD(TAG, '广告加载--->页面回调--->触发刷新')
                    let adView = ad.view()
                    this.infoAd = adView
                    if (adView == undefined) {
                      // 切换或重试
                      if (this.switchAttempts >= ADHelper.getAvailableAdPlatforms(AD.zyOff).length) {
                        logE('所有广告平台尝试失败')
                        this.disAppearAdContainer();
                        return;
                      }
                      this.changeAdPlatform();
                    }
                  })
            }
            break
          case Provider.Tx:
            let txInfoAd = new TxInfoAd()
            logD(`腾讯广告加载--->页面回调--->${this.adId}`)
            ADUtil.logD(TAG, '腾讯广告加载--->页面回调--->')
            txInfoAd.loadAd(this.isInfoLeftAd() ? AD.TX_MANUAL_DEFAULT_POS_ID : AD.TX_NATIVE_DEFAULT_POS_ID,
              (adView: NodeController | undefined) => {
                this.clearAd()
                this.infoAd = adView
                ADUtil.logD(TAG, '腾讯广告加载--->页面回调--->触发原生刷新')
                if (adView == undefined) {
                  // 切换或重试
                  if (this.switchAttempts >= ADHelper.getAvailableAdPlatforms(AD.zyOff).length) {
                    logE('所有广告平台尝试失败')
                    this.disAppearAdContainer();
                    return;
                  }
                  this.changeAdPlatform();
                }
              })
            break
          case Provider.Huawei:
            logD(`华为广告加载--->页面回调--->${this.adId}`)
            ADHelper.getInstance()
              .getAdInfoAdvertisement(this.adName, this.isInfoLeftAd() ? AD.HW_INFO_LEFT_ID : AD.HW_INFO_ID,
                (ads, adDisplayOptions) => {
                  this.clearAd()
                  this.flushed = false
                  this.ads = ads
                  this.options = adDisplayOptions
                  logD(`华为广告加载--->页面回调完成，正在配置--->`)
                  if (ads.length == 0) {
                    // 切换或重试
                    logD(`华为广告加载--->页面回调完成，正在配置--->广告为空--->`)
                    if (this.switchAttempts >= ADHelper.getAvailableAdPlatforms(AD.zyOff).length) {
                      logE('所有广告平台尝试失败')
                      this.disAppearAdContainer();
                      return;
                    }
                    this.changeAdPlatform();
                  }
                })
            break
        }
      }
    })

  }

  // 重试或切换广告平台
  changeAdPlatform() {
    ADUtil.logD(TAG, '重试或切换广告平台')
    logD('重试或切换广告平台')
    let availableAdPlatforms = ADHelper.getAvailableAdPlatforms(AD.zyOff);

    if (this.switchAttempts >= availableAdPlatforms.length) {
      ADUtil.logE(TAG, '广告切换次数已达上限');
      logD('所有广告均请求失败')
      this.switchAttempts = 0;
      this.disAppearAdContainer();
      return;
    }

    let next = ADHelper.getNextAdPlatform();
    if (this.currentAdProvider.valueOf() != next) {
      this.currentAdProvider = Provider.fromNumber(next);
      this.switchAttempts++;
      logD(`切换广告平台，当前尝试次数：${this.switchAttempts}`)
      ADUtil.logD(TAG, `切换广告平台，当前尝试次数：${this.switchAttempts}`);
      this.flushedAdV2();
    } else {
      logE('---广告请求失败---')
      // this.isRemove = true
    }
  }

  onADSubscribe() {
    // 穿山甲信息流刷新订阅
    EmitterUtils.onSubscribe<number>(subscribe + this.adId, (config) => {
      ADUtil.logD(TAG, '广告加载--->订阅回调--->触发刷新')
      this.listArray = []
      this.flushedAdV2()

    })
    // 穿山甲原生广告点击关闭
    EmitterUtils.onSubscribe<string>(CsjInfoNativeAd.csj_native_ad, (ads) => {
      logD(`穿山甲原生广告点击关闭--->准备移除广告`)
      // 原生广告点击关闭 移除
      this.disAppearAdContainer()
      // this.isRemove = true

      // 存储此广告位移除，避免再次加载
      PrefUtil.put(this.getAdSpCacheKey(), false, pref)
    })

    // 腾讯广告点击关闭
    EmitterUtils.onSubscribe<string>(TxInfoAds.CLOSE, (ads) => {
      // 腾讯点击关闭 移除
      this.infoAd = undefined
      // this.isRemove = true

      this.disAppearAdContainer()

      // 存储此广告位移除，避免再次加载
      PrefUtil.put(this.getAdSpCacheKey(), false, pref)
    })
  }

  onPageChangeListener() {
    //todo 穿山甲页面监听
    uiObserver.on('routerPageUpdate', this.getUIContext(), (info: uiObserver.RouterPageInfo) => {
      logD(`Router--回调-->${info.name}-${info.state}`)
      if (this.pageInfo.routerPageInfo?.name == info.name && info.name.startsWith('csj://')) {
        switch (info.state) {
          case uiObserver.RouterPageState.ON_PAGE_SHOW: // 只判断页面展示
            logD(`Router--当前-->${info.name}`)
            logD(`Router--存储页面-->${this.pageInfo.routerPageInfo?.name}`)
            // 存储的页面和当前页面相同，则刷新广告
            if (true) { // 广告统一控制，待填写
              this.clearAd()
              this.flushedAdV2()
            }
            break
        }
      }

    })

    //todo 腾讯页面监听
    uiObserver.on('navDestinationUpdate', (info) => {
      logD(`Nav--回调-->${info.name}-${info.navigationId}-${info.state}`)
      // 相同页面
      if (info.state == uiObserver.NavDestinationState.ON_SHOWN) { // 只判断页面展示
        logD(`Nav--当前-->${info.name}`)
        logD(`Nav--当前uniqueId-->${info.uniqueId}`)
        logD(`Nav--存储页面-->${this.pageInfo.navDestinationInfo?.name}`)
        logD(`Nav--存储uniqueId-->${this.pageInfo.navDestinationInfo?.uniqueId}`)

        if (this.pageInfo.navDestinationInfo?.uniqueId == info.uniqueId) {
          if (true) { // 广告统一控制，待填写
            this.clearAd()
            this.flushedAdV2()
          }
        }
      }

      // 腾讯广告在Router项目触发广告刷新
      if (info.name.toString().startsWith('GDTAd') && info.state == uiObserver.NavDestinationState.ON_DISAPPEAR) {
        if (true) { // 广告统一控制，待填写
          this.clearAd()
          this.flushedAdV2()
        }
      }

    });
  }

  build() {
    Column() {
      if (this.infoAd !== undefined && this.currentAdProvider == Provider.Csj) {
        NodeContainer(this.infoAd)
          .width('100%')
          .backgroundColor(Color.White)
      } else if (this.infoAd !== undefined && this.currentAdProvider == Provider.Tx) {
        NodeContainer(this.infoAd)
          .width('100%')
          .backgroundColor(Color.White)
      } else if (this.listArray.length > 0 && this.currentAdProvider == Provider.Csj) {
        ForEach(this.listArray, (item: CSJFeedAd) => {
          ListItem() {
            this.buildAdLayout(item);
          }
          .align(Alignment.Center)
          .width('100%')
          .height(285)
          .onDisAppear(() => {
            if (typeof item != 'string') {
              item.destroy(); //释放资源
            }
          })
        }, (item: CSJFeedAd, index: number) => {
          return item.toString() + "_" + index
        })
      } else if (this.currentAdProvider == Provider.Huawei) {
        ForEach(this.ads, (item: advertising.Advertisement) => {
          Column() {
            AdComponent({
              ads: [item],
              displayOptions: this.options,
              interactionListener: {
                onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
                  switch (status) {
                    case 'onAdOpen':
                      break;
                    case 'onAdClick':
                      // this.ads = []
                      // this.flushed = true
                      // this.flushedAdV2()
                      break;
                    case 'onAdClose':
                      // this.isRemove = true
                      PrefUtil.putSync(this.getAdSpCacheKey(), false, pref)
                      PrefUtil.get(this.getAdSpCacheKey(), true, pref).then((value) => {
                        if (value) {
                          this.load = true
                        } else {
                          this.load = false
                        }
                        this.flushed = true
                      })
                      break;
                  }
                }
              }
            }).width(this.adWidth)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        })
      }
    }
    .width('100%')
    .backgroundColor((this.bgColor != '') ? this.bgColor : Color.Transparent)
    .visibility((!this.load && this.flushed) ? Visibility.None : Visibility.Visible)
  }

  // 获取广告平台
  getAdProviders() {
    let adMode = ADHelper.getADModeV2(AD.zyOff)
    switch (adMode) {
      case AD.OFF_CSJ:
        return Provider.Csj
      case AD.OFF_TX:
        return Provider.Tx
      case AD.OFF_HW:
        return Provider.Huawei
      default:
        return Provider.Csj
    }
  }

  getAdSpCacheKey() {
    return `${this.adName}_${this.adId}`
  }

  clearAd() {
    this.listArray = []
    this.ads = []
    this.infoAd = undefined
  }

  isInfoLeftAd(): boolean {
    return this.adType == AdType.LINFO
  }

  disAppearAdContainer() {
    // 隐藏广告
    this.load = false
    this.flushed = true
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
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Clip })
            .id(clickViewIds.addAdId(util.generateRandomUUID())) //设置组件Id，需要全局保证唯一性，涉及计费
        }
        .height(35)
        .width("85%")
        .justifyContent(FlexAlign.Start);

        Row() {
          //dislike 按钮
          Image($r("app.media.tt_dislike")).onClick(() => {
            if (true) { //是否需要走定义Dislike弹窗
              //定义WrappedBuilder
              let customDislikeBuilder: WrappedBuilder<[fwList: Array<FilterWord>,
                onSelected: (filterPosition: number, filterName: string) => void,
                onOtherSuggestComment: (suggestionValue: string) => void,
                onUserSuggestDialogCancel: (commentValue: string) => void]> = wrapBuilder(customDislikeComponent);
              ad.getDislikeDialog()?.setCustomDislikeComponent(customDislikeBuilder)
            }
            ad.getDislikeDialog()?.showDislikeDialog(this)
            // ToastUtil.showToast('原生广告点击--->dislike')
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
              .visibility(Visibility.Hidden)
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

export enum Provider {
  Csj = 1,
  Tx = 2,
  Huawei = 4,
}

export namespace Provider {
  export function fromNumber(value: number): Provider {
    switch (value) {
      case AD.OFF_CSJ:
        return Provider.Csj;
      case AD.OFF_TX:
        return Provider.Tx;
      case AD.OFF_HW:
        return Provider.Huawei;
      default:
        return Provider.Csj; // 默认返回华为
    }
  }
}
