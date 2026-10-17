import ExpressCheck from '../view/ExpressCheck'
import { expCompany } from '../entity/ExpBeans'
import { router } from '@kit.ArkUI'
import SetPage from './SetPage'

import { hilog } from '@kit.PerformanceAnalysisKit'
import { AESCodec, Dialog, Log, Ohos } from '@zycore/common'
import { ADHelper, AdConfig, AdType, IAd } from '@zysdk/ad-core-hm'

const TAB_INDEX_EXPRESS = 0
const TAB_INDEX_BAR_CODE = 1
let startTime = -1; // 用于记录上一次点击返回键的时间


@Entry
@Component
struct Index {
  @State currentIndex: number = TAB_INDEX_EXPRESS
  private tabsController: TabsController = new TabsController()
  @State company: expCompany | null = null

  aboutToAppear(): void {
    // let adLoader = new zyAdvertising.ZYAdLoader(getContext())
    // adLoader.loadAd({
    //   adId: 'test1234splash',
    //   adType: 1
    // }, {}, adLoadListener)
    // AdManager.requestAd({ adId: 'test1234splash' })
    // HttpClient.getInstance()
    //   .get<string>("https://zyapp.ss.bscstorage.com/android/sdk/ads/test1234splash")
    //   .then((result) => {
    //     Log.warn(`result: ${result}`)
    //   })
    //   .catch((err: Error) => {
    //     Log.warn(`请求失败:${err.message}`);
    //   })

    ADHelper.getInstance().loadInterstitialAd()

    // ADHelper.getInstance().showScreenAD()
    let value = AESCodec.decrypt('zy', '1r0FdTCs4JWii1eKoPB-0g==')
    let params = AESCodec.decrypt('0830d6eab9-100', 'tTSu130--GT5VVQ1qEGBPplHtw2p73LI6RbWnzXyfEs=')

    let aaa = AESCodec.decrypt("931659ae", "nNqJylsHXnRU4qU25q1SYu1jXRht2jnR9XEc1YVlzR4EMPpBwO2mCYdMY69j9omT")
    Dialog.showToast(aaa)

    Log.debug('AESCodec_', value)
    Log.debug("AESCodec_", aaa)
    Log.debug("AESCodec_", params)
    Dialog.showToast(aaa)

    // let sid_from = 'dfd90a6462-500'
    // let m_header = DeviceUtil.getBrand()
    // let s1_header = sid_from
    // let p1_header = "com.cooking.listzyhm"
    // let o_header = MD5.digestSync(DeviceUtil.getDeviceId())
    // let t1_header = Date.now()
    //
    // zyRcp.setBaseURL(APIs.BASE_Url)
    //   .enableLogInterceptor()
    //   .setLoadingContent('加载中...')
    //   .addCommonHeaders({
    //     "m": m_header,
    //     "s1": s1_header,
    //     "p1": p1_header,
    //     "o": o_header,
    //     "t1": String(t1_header)
    //   })
    //   .enableLottie()
    //   .addOhosCodeEvent({
    //     listener: (code: number) => {
    //       Log.debug("----code监听事件-----", code + "")
    //     }
    //   })
    //   .addCryptoEvent({
    //     requestEncoder: (request: rcp.RequestContext): rcp.RequestContext => {
    //       if (request.request.content) {
    //         Log.debug('-----------------加密操作--------------', request.request.content as string)
    //       }
    //       return request;
    //     },
    //     responseDecoder: (response: rcp.Response): rcp.Response => {
    //       if (response) {
    //         Log.debug('-----------------解密操作--------------', JSON.stringify(response.toJSON()))
    //       }
    //       return response;
    //     }
    //   })
    //   .setUploadEvent({
    //     onUploadProgress: (progress) => {
    //       Log.debug("---------测试上传进度----------", progress + "%")
    //     }
    //   })
    //   .setDownLoadEvent({
    //     onDownloadProgress: (progress) => {
    //       Log.debug("---------测试下载进度----------", progress + "%")
    //     }
    //   })
    //   .create()
    //   .builder();
    // getCompanys()
  }

  onPageShow(): void {
    let data = router.getParams()
    if (data != null) {
      this.company = data as expCompany
    }

    hilog.debug(0x0001, 'Index', 'onPageShow')
  }

  onBackPress(): boolean | void {
    let currentTime = new Date().getTime(); // 获取当前时间
    let flag = currentTime - startTime; // 计算两次点击的时间间隔
    if (flag < 2000) { // 如果时间间隔小于2000毫秒，则认为是双击返回
      Ohos.exit()
    } else {
      Dialog.showToast('再按一次退出')
      startTime = currentTime; // 更新上一次点击返回键的时间
      Log.info('onBackPress', `currentTime:${currentTime}`)
    }
    return true; // 表示已经处理了onBackPress事件，不需要再执行默认的返回操作

  }

  /**
   * TabBar 样式
   * @param title
   * @param index
   * @param selectImg
   * @param normalImg
   */
  @Builder
  TabBuilder(index: number, selectImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === index ? selectImg : normalImg)
        .width('50vp')
        .height('50vp')
        .objectFit(ImageFit.Contain)
    }
    .justifyContent(FlexAlign.Center)
    .height('56vp')
    .width('100%')
    .onClick(() => {
      this.currentIndex = index;
      this.tabsController.changeIndex(this.currentIndex);
    })
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentIndex,
      controller: this.tabsController
    }) {
      TabContent() {
        ExpressCheck({ company: this.company })
      }
      .tabBar(this.TabBuilder(TAB_INDEX_EXPRESS, $r('app.media.express_check_b_s'),
        $r('app.media.express_check_b_d')))

      TabContent() {
        SetPage()
      }
      .backgroundColor('#f5f5f5')
      .tabBar(this.TabBuilder(TAB_INDEX_BAR_CODE, $r('app.media.my_b_s'),
        $r('app.media.my_b_d')))
    }
    .width('100%')
    .backgroundImage($r('app.media.img_btm_bg'))
    .barHeight('56vp')
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentIndex = index
    })
    .padding({ bottom: px2vp(Ohos.getNavigationIndicatorHeight()) })
  }
}