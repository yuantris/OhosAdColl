import { AESCodec, Ohos, StrUtils } from '@zycore/common';
import { AdIdStore } from './AdIdStore';
import { AdSlotManager } from './AdSlotManager';
import { AdSwitchManager } from './AdSwitchManager';
import { PlatformType } from '../../model/PlatformType';
import { LogManager } from '../logger/LogManager';
import { SafeValueUtil } from '../../utils/SafeValueUtil';
import { AdConfigBuilder } from './AdConfigBuilder';
import { TokenCalculator } from './TokenCalculator';
import { TestLog } from '../../test/TestLogEnvironment';
import { TestAdRepo } from '../../storage/TestAdControl';

const TAG = 'ConfigVerifier';

export class ConfigVerifier {
  static verifyConfigAdSwitchManager(zyoff: ESObject): void {
    LogManager.warn(TAG, '开始V4校验')
    if (StrUtils.isBlank(zyoff?.i)) {
      // i 为空说明服务端未下发加密配置, 补日志避免静默返回造成日志断链
      LogManager.error(TAG, 'V4校验停止: zyoff.i 为空, 服务端未下发配置, 使用本地默认广告ID')
      return
    }
    const i = AESCodec.decrypt(AdIdStore.APPID, zyoff?.i) ?? ''
    const v4: ESObject = JSON.parse(i)
    const it = TokenCalculator.getV4It()

    if (it != SafeValueUtil.getSafeValue(v4?.it, '')) {
      LogManager.warn(TAG, 'iToken校验失败, 正在重新配置广告ID')
      new AdConfigBuilder()
        .setCSJ_APPID(SafeValueUtil.getSafeValue(v4?.csj?.appid))
        .setCSJ_SPLASH_ID(SafeValueUtil.getSafeValue(v4?.csj?.open))
        .setCSJ_VIDEO_ID(SafeValueUtil.getSafeValue(v4?.csj?.video))
        .setCSJ_INFO_ID(SafeValueUtil.getSafeValue(v4?.csj?.info))
        .setCSJ_INFO_LEFT_ID(SafeValueUtil.getSafeValue(v4?.csj?.left_info))
        .setCSJ_SCREEN_ID(SafeValueUtil.getSafeValue(v4?.csj?.lscr))
        .setTX_APPID(SafeValueUtil.getSafeValue(v4?.tx?.appid))
        .setTX_SPLASH_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(v4?.tx?.open))
        .setTX_REWARD_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(v4?.tx?.video))
        .setTX_MANUAL_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(v4?.tx?.info))
        .setTX_MANUAL_DEFAULT_LEFT_POS_ID(SafeValueUtil.getSafeValue(v4?.tx?.left_info))
        .setTX_INTERSTITIAL_DEFAULT_POS_ID(SafeValueUtil.getSafeValue(v4?.tx?.lscr))
        .setHW_SPLASH_ID(SafeValueUtil.getSafeValue(v4?.hw?.open))
        .setHW_SCREEN_ID(SafeValueUtil.getSafeValue(v4?.hw?.lscr))
        .setHW_VIDEO_ID(SafeValueUtil.getSafeValue(v4?.hw?.video))
        .setHW_INFO_ID(SafeValueUtil.getSafeValue(v4?.hw?.info))
        .setHW_INFO_LEFT_ID(SafeValueUtil.getSafeValue(v4?.hw?.left_info))

      let splashMap = new Map<PlatformType, string>();
      splashMap.set(PlatformType.HUAWEI, SafeValueUtil.getSafeValue(v4?.hw?.open));
      splashMap.set(PlatformType.CSJ, SafeValueUtil.getSafeValue(v4?.csj?.open));
      splashMap.set(PlatformType.TENCENT, SafeValueUtil.getSafeValue(v4?.tx?.open));

      let infoMap = new Map<PlatformType, string>();
      infoMap.set(PlatformType.HUAWEI, SafeValueUtil.getSafeValue(v4?.hw?.info));
      infoMap.set(PlatformType.CSJ, SafeValueUtil.getSafeValue(v4?.csj?.info));
      infoMap.set(PlatformType.TENCENT, SafeValueUtil.getSafeValue(v4?.tx?.info));

      let infoleftMap = new Map<PlatformType, string>();
      infoleftMap.set(PlatformType.HUAWEI, SafeValueUtil.getSafeValue(v4?.hw?.left_info));
      infoleftMap.set(PlatformType.CSJ, SafeValueUtil.getSafeValue(v4?.csj?.left_info));
      infoleftMap.set(PlatformType.TENCENT, SafeValueUtil.getSafeValue(v4?.tx?.left_info));

      let lscrMap = new Map<PlatformType, string>();
      lscrMap.set(PlatformType.HUAWEI, SafeValueUtil.getSafeValue(v4?.hw?.lscr));
      lscrMap.set(PlatformType.CSJ, SafeValueUtil.getSafeValue(v4?.csj?.lscr));
      lscrMap.set(PlatformType.TENCENT, SafeValueUtil.getSafeValue(v4?.tx?.lscr));

      let videoMap = new Map<PlatformType, string>();
      videoMap.set(PlatformType.HUAWEI, SafeValueUtil.getSafeValue(v4?.hw?.video));
      videoMap.set(PlatformType.CSJ, SafeValueUtil.getSafeValue(v4?.csj?.video));
      videoMap.set(PlatformType.TENCENT, SafeValueUtil.getSafeValue(v4?.tx?.video));

      AdSlotManager.getInstance()
        .updateAdSlotMappings("splash", splashMap)
        .updateAdSlotMappings("info", infoMap)
        .updateAdSlotMappings("info_left", infoleftMap)
        .updateAdSlotMappings("lscr", lscrMap)
        .updateAdSlotMappings("video", videoMap);
    } else {
      LogManager.warn(TAG, 'iToken校验成功')
    }
  }

  static verifyEasyConfigAdSwitchManager(zyoff: ESObject): void {
    LogManager.warn(TAG, '开始V5校验')
    if (StrUtils.isBlank(zyoff?.i)) {
      // i 为空说明服务端未下发加密配置, 补日志避免静默返回造成日志断链
      LogManager.error(TAG, 'V5校验停止: zyoff.i 为空, 服务端未下发配置, 使用本地默认广告ID')
      return
    }
    if (TestLog.huaweiTestReport) {
      LogManager.warn(TAG, '当前是华为测试工具启动, 默认跳过云端下发更新广告ID');
      LogManager.warn(TAG, 'V5校验停止')
      return
    }
    if (TestAdRepo.instance.props.debugAD === true && Ohos.debug()) {
      LogManager.warn(TAG, '当前是测试环境且设置测试广告ID, 默认跳过云端下发更新广告ID, 并更换为测试广告');
      ConfigVerifier.changeTestAd()
      LogManager.warn(TAG, 'V5校验停止')
      return
    }
    const i = AESCodec.decrypt(AdIdStore.APPID, zyoff?.i) ?? ''
    LogManager.warn(TAG, `线上广告ID: \n${JSON.stringify(i, null, 2)}`);
    const v5: ESObject = JSON.parse(i)
    const it = TokenCalculator.getV4It()

    if (it != SafeValueUtil.getSafeValue(v5?.it, '')) {
      LogManager.warn(TAG, 'iToken校验失败, 正在重新配置广告ID')

      const csj = new Map(Object.entries((v5?.csj ?? {}) as Record<string, string>))
      const tx = new Map(Object.entries((v5?.tx ?? {}) as Record<string, string>))
      const hw = new Map(Object.entries((v5?.hw ?? {}) as Record<string, string>))

      csj.forEach((id: string, adId: string) => {
        AdSlotManager.getInstance().updateAdSlot(adId, PlatformType.CSJ, id)
      })
      tx.forEach((id: string, adId: string) => {
        AdSlotManager.getInstance().updateAdSlot(adId, PlatformType.TENCENT, id)
      })
      hw.forEach((id: string, adId: string) => {
        AdSlotManager.getInstance().updateAdSlot(adId, PlatformType.HUAWEI, id)
        // 动态广告模式下后端约定（AdSwitchManager.enableBanMerge=true时生效）：
        // hw的info_left与ban合二为一，共用同一广告位ID；false时还原旧行为
        if (AdSwitchManager.enableBanMerge && adId.includes('info_left')) {
          AdSlotManager.getInstance().updateAdSlot('ban', PlatformType.HUAWEI, id)
          LogManager.info(TAG, `info_left与ban合并更新: ${id}`);
        }
      })

      LogManager.info(TAG, 'V5校验广告ID配置成功');
    } else {
      LogManager.warn(TAG, 'iToken校验成功')
    }
  }

  private static changeTestAd() {
    AdSlotManager.getInstance().updateAllAdSlotsByAdType({
      'splash': new Map([
        [PlatformType.HUAWEI, 'testq6zq98hecj'],
        [PlatformType.TENCENT, '2284659488139986'],
        [PlatformType.CSJ, '893734833']
      ]),
      'lscr': new Map([
        [PlatformType.HUAWEI, 'testb4znbuh3n2'],
        [PlatformType.TENCENT, '5284157488847440'],
        [PlatformType.CSJ, '974048733']
      ]),
      'video': new Map([
        [PlatformType.HUAWEI, 'testx9dtjwj8hp'],
        [PlatformType.TENCENT, '2224656498544987'],
        [PlatformType.CSJ, '974048742']
      ]),
      'info': new Map([
        [PlatformType.HUAWEI, 'testu7m3hc4gvm'],
        [PlatformType.TENCENT, '4254455418564051'],
        [PlatformType.CSJ, '974048794']
      ]),
      'info_left': new Map([
        [PlatformType.HUAWEI, AdSwitchManager.enableBanMerge ? 'h5xkz3mbr2' : 'testb65czjivt9'],
        [PlatformType.TENCENT, '9294451478852349'],
        [PlatformType.CSJ, '974048780']
      ]),
      'ban': new Map([
        [PlatformType.HUAWEI, 'h5xkz3mbr2'],
      ]),
    })
    LogManager.warn(TAG, '已更换为测试广告');
  }
}
