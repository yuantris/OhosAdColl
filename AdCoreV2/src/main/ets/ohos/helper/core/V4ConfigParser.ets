import { SDKCore } from '../../application/SDKCore';
import { AdIdStore } from './AdIdStore';
import { AdSwitchManager } from './AdSwitchManager';
import { AdSlotManager } from './AdSlotManager';
import { PlatformType } from '../../model/PlatformType';
import { LogManager } from '../logger/LogManager';
import { SafeValueUtil } from '../../utils/SafeValueUtil';
import { AdConfigBuilder } from './AdConfigBuilder';

export class V4ConfigParser {
  static configAdSwitchManager(obj: ESObject): void {
    try {
      SDKCore.AD = obj
      AdIdStore.APPID = obj?.appid ?? ""
      AdIdStore.VID = obj?.versionCode ?? ""
      AdIdStore.SID = obj?.sid ?? ""
      AdSwitchManager.AD_VJUMP = obj?.hmads?.vjump ?? 0

      new AdConfigBuilder()
        .setCSJ_APPID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.appid))
        .setCSJ_SPLASH_ID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.open))
        .setCSJ_VIDEO_ID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.exts?.split(',')[0]))
        .setCSJ_INFO_ID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.exit))
        .setCSJ_INFO_LEFT_ID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.exts?.split(',')[1]))
        .setCSJ_SCREEN_ID(SafeValueUtil.getSafeValue(obj?.hmads?.csj?.modules?.find((item: ESObject) => item.moduleId ==
          'public')?.lscr[0]?.id))
        .setTX_APPID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.appid))
        .setTX_SPLASH_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.open))
        .setTX_REWARD_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.exts?.split(',')[0]))
        .setTX_MANUAL_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.exit))
        .setTX_MANUAL_DEFAULT_LEFT_POS_ID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.exts?.split(',')[1]))
        .setTX_INTERSTITIAL_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(obj?.hmads?.tx?.modules?.find((item: ESObject) => item.moduleId ==
          'public')?.lscr[0]?.id))
        .setHW_SPLASH_ID(SafeValueUtil.getSafeValue(obj?.hmads?.hw?.open))
        .setHW_SCREEN_ID(SafeValueUtil.getSafeValue(obj?.hmads?.hw?.modules?.find((item: ESObject) => item.moduleId ==
          'public')?.lscr[0]?.id))
        .setHW_VIDEO_ID(SafeValueUtil.getSafeValue(obj?.hmads?.hw?.exts?.split(',')[0]))
        .setHW_INFO_ID(SafeValueUtil.getSafeValue(obj?.hmads?.hw?.exit))
        .setHW_INFO_LEFT_ID(SafeValueUtil.getSafeValue(obj?.hmads?.hw?.exts?.split(',')[1]))
    } catch (e) {
      LogManager.error('configAdSwitchManager', `[ 配置广告ID发生错误 ]`, e)
    }

    let splashMap = new Map<PlatformType, string>();
    splashMap.set(PlatformType.HUAWEI, AdIdStore.HW_SPLASH_ID);
    splashMap.set(PlatformType.CSJ, AdIdStore.CSJ_SPLASH_ID);
    splashMap.set(PlatformType.TENCENT, AdIdStore.TX_SPLASH_DEFAULT_POS_ID);

    let infoMap = new Map<PlatformType, string>();
    infoMap.set(PlatformType.HUAWEI, AdIdStore.HW_INFO_ID);
    infoMap.set(PlatformType.CSJ, AdIdStore.CSJ_INFO_ID);
    infoMap.set(PlatformType.TENCENT, AdIdStore.TX_MANUAL_DEFAULT_POS_ID);

    let infoleftMap = new Map<PlatformType, string>();
    infoleftMap.set(PlatformType.HUAWEI, AdIdStore.HW_INFO_LEFT_ID);
    infoleftMap.set(PlatformType.CSJ, AdIdStore.CSJ_INFO_LEFT_ID);
    infoleftMap.set(PlatformType.TENCENT, AdIdStore.TX_MANUAL_DEFAULT_LEFT_POS_ID);

    let lscrMap = new Map<PlatformType, string>();
    lscrMap.set(PlatformType.HUAWEI, AdIdStore.HW_SCREEN_ID);
    lscrMap.set(PlatformType.CSJ, AdIdStore.CSJ_SCREEN_ID);
    lscrMap.set(PlatformType.TENCENT, AdIdStore.TX_INTERSTITIAL_DEFAULT_POS_ID);

    let videoMap = new Map<PlatformType, string>();
    videoMap.set(PlatformType.HUAWEI, AdIdStore.HW_VIDEO_ID);
    videoMap.set(PlatformType.CSJ, AdIdStore.CSJ_VIDEO_ID);
    videoMap.set(PlatformType.TENCENT, AdIdStore.TX_REWARD_DEFAULT_POS_ID);

    AdSlotManager.getInstance()
      .registerAdSlotMappings("splash", splashMap)
      .registerAdSlotMappings("info", infoMap)
      .registerAdSlotMappings("info_left", infoleftMap)
      .registerAdSlotMappings("lscr", lscrMap)
      .registerAdSlotMappings("video", videoMap);
  }
}
