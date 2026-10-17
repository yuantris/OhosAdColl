import { SDKCore } from '../../application/SDKCore';
import { AdIdStore } from './AdIdStore';
import { AdSwitchManager } from './AdSwitchManager';
import { AdSlotManager } from './AdSlotManager';
import { PlatformType } from '../../model/PlatformType';
import { LogManager } from '../logger/LogManager';
import { AdHub, AdInfo } from '../const/AdHub';
import { SafeValueUtil } from '../../utils/SafeValueUtil';
import { AdConfigBuilder } from './AdConfigBuilder';
import { Module } from '../entity/AppPckInfoResp';

export class EasyConfigParser {
  static configEasyAdSwitchManager(obj: ESObject): void {
    try {
      LogManager.warn('SDKCore', `【开始配置云创Ad】`)
      SDKCore.EASY_AD = obj
      AdIdStore.APPID = obj?.appid ?? ""
      AdIdStore.VID = obj?.versionCode ?? ""
      AdIdStore.SID = obj?.sid ?? ""
      AdSwitchManager.AD_VJUMP = obj?.hmads?.vjump ?? 0

      const builder = new AdConfigBuilder()
      if (SafeValueUtil.getSafeValue(obj?.hmads?.csj?.appid)) {
        builder.setCSJ_APPID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.appid))
      }

      if (SafeValueUtil.getSafeValue(obj?.hmads?.tx?.appid)) {
        builder.setTX_APPID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.appid))
      }

    } catch (e) {
      LogManager.error('configEasyAdSwitchManager', `[ 配置广告ID发生错误 ]`, e)
    }

    EasyConfigParser.updateAdHubFromConfig(obj)

    const adHub = AdHub.getInstance()
    const map: Map<string, Map<PlatformType, string>> = new Map()

    const platforms = [PlatformType.CSJ, PlatformType.TENCENT, PlatformType.HUAWEI]

    platforms.forEach(platform => {
      const splashAds = adHub.getSplashByPlatform(platform)
      if (splashAds.length > 0) {
        splashAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    platforms.forEach(platform => {
      const lscrAds = adHub.getLscrByPlatform(platform)
      if (lscrAds.length > 0) {
        lscrAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    platforms.forEach(platform => {
      const infoAds = adHub.getInfoByPlatform(platform)
      if (infoAds.length > 0) {
        infoAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    platforms.forEach(platform => {
      const infoLeftAds = adHub.getInfoLeftByPlatform(platform)
      if (infoLeftAds.length > 0) {
        infoLeftAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    platforms.forEach(platform => {
      const videoAds = adHub.getVideoByPlatform(platform)
      if (videoAds.length > 0) {
        videoAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    platforms.forEach(platform => {
      const banAds = adHub.getBanByPlatform(platform)
      if (banAds.length > 0) {
        banAds.forEach((ad: AdInfo) => {
          if (!map.has(ad.adId)) {
            map.set(ad.adId, new Map<PlatformType, string>())
          }
          const platformMap = map.get(ad.adId)!
          platformMap.set(platform, ad.id)
        })
      }
    })

    // 动态广告模式下后端约定（AdSwitchManager.enableBanMerge=true时生效）：
    // banner在华为平台直接复用info_left在华为平台的真实广告位id（仅华为，其他平台保留自身配置）
    // false时还原旧行为：ban与info_left各自使用独立配置
    if (AdSwitchManager.enableBanMerge) {
      let infoLeftHuaweiId: string | undefined = undefined
      map.forEach((platformMap: Map<PlatformType, string>, adId: string) => {
        if (adId.includes('info_left')) {
          const hwId = platformMap.get(PlatformType.HUAWEI)
          if (hwId) {
            infoLeftHuaweiId = hwId
          }
        }
      })
      if (infoLeftHuaweiId) {
        map.forEach((platformMap: Map<PlatformType, string>, adId: string) => {
          if (adId.includes('ban')) {
            platformMap.set(PlatformType.HUAWEI, infoLeftHuaweiId!)
            LogManager.info('configEasyAdSwitchManager', `[ ban合并info_left ] ${adId} -> 华为ID: ${infoLeftHuaweiId}`)
          }
        })
      }
    }

    AdSlotManager.getInstance().updateAllAdSlots(map)
  }

  private static updateAdHubFromConfig(obj: ESObject): void {
    try {
      const adHub = AdHub.getInstance()
      const platforms = ['csj', 'tx', 'hw']

      platforms.forEach(platform => {
        const platformData: ESObject = obj?.hmads?.[platform]
        if (!platformData) {
          return
        }

        const adsPlatformData: ESObject = obj?.ads?.[platform]

        let platformType: PlatformType
        switch (platform) {
          case 'csj':
            platformType = PlatformType.CSJ
            break
          case 'tx':
            platformType = PlatformType.TENCENT
            break
          case 'hw':
            platformType = PlatformType.HUAWEI
            break
          default:
            return
        }

        const banAds: AdInfo[] = []
        const infoAds: AdInfo[] = []
        const infoLeftAds: AdInfo[] = []
        const videoAds: AdInfo[] = []
        const lscrAds: AdInfo[] = []
        const splashAds: AdInfo[] = []

        if (platformData.modules && Array.isArray(platformData.modules)) {
          platformData.modules.forEach((module: Module, moduleIndex: number) => {
            const adsModule: ESObject = adsPlatformData?.modules?.[moduleIndex]

            if (module.ban && Array.isArray(module.ban)) {
              module.ban.forEach((item: ESObject, itemIndex: number) => {
                let id: string | undefined = item.id
                if (!id && adsModule?.ban?.[itemIndex]?.id) {
                  id = adsModule.ban[itemIndex].id
                }
                if (item.adId) {
                  banAds.push(new AdInfo(item.adId, id, item.name))
                }
              })
            }

            if (module.info && Array.isArray(module.info)) {
              module.info.forEach((item: ESObject, itemIndex: number) => {
                let id: string | undefined = item.id
                if (!id && adsModule?.info?.[itemIndex]?.id) {
                  id = adsModule.info[itemIndex].id
                }
                if (item.adId) {
                  infoAds.push(new AdInfo(item.adId, id, item.name))
                }
              })
            }

            if (module.info_left && Array.isArray(module.info_left)) {
              module.info_left.forEach((item: ESObject, itemIndex: number) => {
                let id: string | undefined = item.id
                if (!id && adsModule?.info_left?.[itemIndex]?.id) {
                  id = adsModule.info_left[itemIndex].id
                }
                if (item.adId) {
                  infoLeftAds.push(new AdInfo(item.adId, id, item.name))
                }
              })
            }

            if (module.video && Array.isArray(module.video)) {
              module.video.forEach((item: ESObject, itemIndex: number) => {
                let id: string | undefined = item.id
                if (!id && adsModule?.video?.[itemIndex]?.id) {
                  id = adsModule.video[itemIndex].id
                }
                if (item.adId) {
                  videoAds.push(new AdInfo(item.adId, id, item.name))
                }
              })
            }

            if (module.lscr && Array.isArray(module.lscr)) {
              module.lscr.forEach((item: ESObject, itemIndex: number) => {
                let id: string | undefined = item.id
                if (!id && adsModule?.lscr?.[itemIndex]?.id) {
                  id = adsModule.lscr[itemIndex].id
                }
                if (item.adId) {
                  lscrAds.push(new AdInfo(item.adId, id, item.name))
                }
              })
            }
          })
        }

        if (platformData.open) {
          splashAds.push(new AdInfo(`splash`, platformData.open, `${platform}开屏广告`))
        }

        adHub.updateBan(platformType, banAds)
        adHub.updateInfo(platformType, infoAds)
        adHub.updateInfoLeft(platformType, infoLeftAds)
        adHub.updateVideo(platformType, videoAds)
        adHub.updateLscr(platformType, lscrAds)
        adHub.updateSplash(platformType, splashAds)

        LogManager.info('updateAdHubFromConfig', `[ 成功设置 ${platform} 平台广告 ]`, {
          platform: platform,
          ban: banAds.length,
          info: infoAds.length,
          infoLeft: infoLeftAds.length,
          video: videoAds.length,
          lscr: lscrAds.length,
          splash: splashAds.length
        })
      })
    } catch (e) {
      LogManager.error('updateAdHubFromConfig', `[ 更新AdHub发生错误 ]`, e)
    }
  }
}
