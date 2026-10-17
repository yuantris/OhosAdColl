import { Ohos } from "@zycore/common"
import { window } from "@kit.ArkUI"
import { LogManager } from "../logger/LogManager"
import '../../components/pages/ZySplashShowPage.ets'
import { ADHelper } from "./ADHelper"
import { AdStateManager } from './AdStateManager'
import { AdSwitchManager } from './AdSwitchManager'
import { AdSlotManager } from './AdSlotManager'
import { PlatformType } from '../../model/PlatformType'
import { BusinessError } from '@kit.BasicServicesKit';
import { AD } from "../AD"

export class HotStartManager {
  /**
   * 推送热启动开屏广告页面
   * 加载前依次检查：广告总开关 → 所有已启用平台下"开屏"广告位是否至少有一个有效ID
   * 任一前置条件不满足则跳过加载，避免无效的窗口创建与渲染开销
   * @returns Promise<void> 无论是否真正展示开屏页面，都会 resolve，不阻塞调用方
   */
  static pushSplashAdPage(): Promise<void> {
    // 1) 检查广告总开关：未开启则直接跳过开屏页加载
    if (!AdSwitchManager.isAdOpen) {
      LogManager.info('HotStartManager', '广告总开关未开启，跳过热启动开屏页加载')
      return Promise.resolve()
    }

    // 2) 检查所有已启用平台下"开屏"广告位是否至少存在一个有效ID
    // 实际加载走降级策略，会按可用平台优先级逐个尝试，所以这里要遍历所有启用平台
    // 只要存在任意一个平台能拿到有效开屏ID，就认为开屏可用；只有全部为空才跳过
    const adHelper = ADHelper.getInstance()
    const availablePlatformTypes: PlatformType[] = adHelper.getAvailablePlatformTypes?.() ?? []
    const adSlotManager: AdSlotManager = AdSlotManager.getInstance()
    let hasValidSplashAdId: boolean = false
    for (const platformType of availablePlatformTypes) {
      const splashAdId: string | null = adSlotManager.getRealAdId('splash', platformType)
      if (splashAdId) {
        hasValidSplashAdId = true
        break
      }
    }
    if (!hasValidSplashAdId) {
      LogManager.info('HotStartManager',
        `所有已启用平台的开屏广告位ID均为空（platforms=${JSON.stringify(availablePlatformTypes)}），跳过热启动开屏页加载`)
      return Promise.resolve()
    }
    LogManager.info('HotStartManager',
      `开始加载热启动开屏页，availablePlatforms=${JSON.stringify(availablePlatformTypes)}`)

    // new SplashShowHandler().registerSplashReceiver()
    Ohos.getWindowStage().createSubWindow("ZySplashShowPage").then((window) => {
      let storage: LocalStorage = new LocalStorage()
      storage.setOrCreate<window.Window>('window', window)
      window.loadContentByName('ZySplashShowPage', storage, (err, data) => {
        // 设置窗口透明
        window.setWindowBackgroundColor('#00000000')
        window.showWindow().catch((e: BusinessError) => {
          LogManager.error('HotStartManager', '热启动开屏窗口展示失败', e)
        })
      })

    }).catch((e: BusinessError) => {
      LogManager.error('HotStartManager', '进入热启动开屏页面异常', e)
    })
    return Promise.resolve()
  }

  /**
   * 热启动广告刷新【所有活跃广告】
   */
  static onSplashAdFlush() {
    LogManager.info('HotStartManager', 'onSplashAdFlush: refreshing all active ads')
    // 调用广告状态管理器刷新所有活跃广告
    AdStateManager.getInstance().refreshAds()
  }

  /**
   * 热启动插屏广告展示
   */
  static warmStartDetector() {
    if (AdSwitchManager.enableEasyConfig) {
      ADHelper.getInstance().loadInterstitialAd('public_main_lscr')
    } else {
      ADHelper.getInstance().loadInterstitialAd()
    }
  }
}