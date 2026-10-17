import { Any } from '@zycore/common';
import { zyClient,
  AdIdStore,
  AdSlotManager,
  AdSwitchManager,
  AppConfig,
  CacheUnit,
  NetBasic,
  PlatformType,
  RequestApplication,
  ResultDto,
  updateBaseUrl
} from '@zysdk/ad-core-hm';

export default class App extends RequestApplication {
  getAppConfig(): AppConfig {
    return AppConfig.create()
      .setLauncherBgRes($r('app.media.app_start'))
      .setAdShowWaitingTime(60000)
      .setSplashEventHandler((eventData, hasGuide) => {
        // 自定义处理逻辑
        if (hasGuide) {
          // 显示引导页
        } else {
          // 显示主页面
        }
      })
      .build()
  }

  public onCreate(): void {
    super.onCreate()
  }

  preInitBefore(): void {
    AdSwitchManager.enableEasyConfig = true
  }

  preInitFinish(): void {
    // AD.printAD()
    //
    // // ADHelper.revocationAuthorization()
    // AD.forceEnableAdChannel = AD.OFF_HW
    // // new TimeOutHandler()
    //
    // // AD.CSJ_SPLASH_ID = '103055163'
    //
    //
    // AD.HW_SPLASH_ID = 'testq6zq98hecj'
    // AD.HW_SCREEN_ID = 'testb4znbuh3n2'
    // AD.HW_VIDEO_ID = 'testx9dtjwj8hp'
    // AD.HW_INFO_ID = 'testu7m3hc4gvm'
    // AD.HW_INFO_LEFT_ID = 'testb65czjivt9'

    // 腾讯
    // 广告 ID 1212622554
    // 开屏ID:2284659488139986
    // 插屏  ID:5284157488847440
    // 激励视频ID:2224656498544987
    // 信息流小图 ID:9294451478852349
    // 大图ID:4254455418564051

    // 穿山甲测试账号
    // let csjAppId = '5477447'
    // let splashAdId = '888906709'
    // let fullAdId = '955806169'
    // let feedAdId = '955804505'
    // let rewardAdId = '955804646'

    // 穿山甲
    // 广告id 5769720
    // 开屏id 893734833
    // 插屏id 974048733
    // 激励视频id 974048742
    // 信息流小图 974048780
    // 大974048794

    // AD.setForceAdChannel(AD.OFF_TX)
    AdIdStore.CSJ_APPID = '5769720'
    AdIdStore.TX_APP_ID = '1212622554'


    AdSwitchManager.forceAdOpen()
    AdSwitchManager.enableBanMerge = true
    AdSlotManager.getInstance()
      .updateAdSlot("splash", PlatformType.HUAWEI, "testq6zq98hecj")
      // .updateAdSlot("splash", PlatformType.CSJ, "893734833")
      .updateAdSlot("splash", PlatformType.TENCENT, "2284659488139986")
      .updateAdSlot("info", PlatformType.HUAWEI, "testu7m3hc4gvm")
      // .updateAdSlot("info", PlatformType.CSJ, "974048794")
      .updateAdSlot("info", PlatformType.TENCENT, "4254455418564051")
      .updateAdSlot("info_left", PlatformType.HUAWEI, "h5xkz3mbr2")
      .updateAdSlot("info_left", PlatformType.CSJ, "974048780")
      .updateAdSlot("info_left", PlatformType.TENCENT, "9294451478852349")
      .updateAdSlot("video", PlatformType.HUAWEI, "testx9dtjwj8hp")
      .updateAdSlot("lscr", PlatformType.HUAWEI, "testb4znbuh3n2")
      .updateAdSlot("ban", PlatformType.HUAWEI, "h5xkz3mbr2")

    NetBasic.baseUrl = "http://zytest.zyapp.net.cn"
    // zyClient.post("zy/v1/hm/app/exp/getP", {
    //   params: {
    //     receive: "北京市丰台区",
    //     send: "北京市北京市东城区",
    //     weight: 1.1,
    //     // weight: "1.0",
    //     com: "annengwuliu",
    //     token: "uuid_weight_c_com"
    //   }
    // }).then((res: ResultDto) => {
    //
    // }).catch((e: BusinessError) => {
    //
    // })

    // zyClient.post("/zy/v1/app/almanac/solarterms", {
    //   params: {
    //     token: "rtype_sid_word_aid_uuid",
    //     word: "立春",
    //     year: "2026"
    //   }
    // }).then((res: ResultDto) => {
    //
    // }).catch((e: BusinessError) => {
    //
    // })

    zyClient.with()
      .urlPath("/zy/v1/hm/app/info")
      .setToken("v_v_uuid_a_r_v")
      .addParams('dtoken', 'VyNzqckkxF0Ug6LqiIGC0zeRRS-2u-mlP1FQJn-fmoc')
      .addParams('uid', 'cf8e9e5ef5')
      .post<ResultDto>()
      .then((res: ResultDto) => {

      })
      .catch((e: BusinessError) => {

      })

    zyClient.with()
      .urlPath('/zy/v1/hm/app/driverexam/info')
      .setToken('tags_type_subject_uuid')
      .addParams({
        pageNum: 1,
        pageSize: 100,
        subject: '1',
        sort: 'rand',
        type: 'C1',
        tag: '',
        tags: '1'
      })
      .cache(1, CacheUnit.HOUR)
      .post<string>()
      .then((res: string) => {
        console.debug('请求结果', res)
      })
      .catch((e: BusinessError) => {

      })

  }

  clearAllData(): void {
    // TODO: 删除所有数据
  }
}