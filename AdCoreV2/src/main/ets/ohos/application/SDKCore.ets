import { AESCodec, Ohos, Preferences } from '@zycore/common';
import { IS_TEST_ID } from '../components/debug/AdIdInfoComponent';
import { AdSwitchManager } from '../helper/core/AdSwitchManager';
import { AdConstants } from '../helper/const/AdConstants';
import { AdHub } from '../helper/const/AdHub';
import { AdModeManager } from '../helper/core/AdModeManager';
import { AdSlotManager } from '../helper/core/AdSlotManager';
import { ConfigVerifier } from '../helper/core/ConfigVerifier';
import { ZyOFF } from '../helper/entity/ZyOFF';
import { LogManager } from '../helper/logger/LogManager';
import { V4, V5 } from '../helper/network/APIs';
import zyClient from '../helper/network/OhosRcp';
import { PlatformType } from '../model/PlatformType';
import ADUtil from '../utils/ADUtil';
import { VIPRepo } from '../storage/VIPData';

export class SDKCore {
  // 广告模式数据
  static OFF: ZyOFF
  // info.json
  static AD: ESObject
  // 云创info.json
  static EASY_AD: ESObject

  /**
   * 请求广告开关[v4]
   * 需隐私政策授权后请求
   */
  static async requestOFF() {
    try {
      const off: ZyOFF | null = await SDKCore.requestV4();
      if (off) {
        SDKCore.OFF = off;

        if (AdSwitchManager.enableDynamicAD) {
          try {
            ConfigVerifier.verifyConfigAdSwitchManager(off);
          } catch (e) {
            LogManager.error('SDKCore', 'V4校验异常', e);
          }
        }

        try {
          if (Ohos.debug() && Preferences.getBooleanSync(IS_TEST_ID, Ohos.debug())) {
            LogManager.warn('SDKCore', `当前是测试环境，已切换为测试广告ID`);
            const map: Map<string, Map<PlatformType, string>> = new Map([
              ['splash', new Map([
                [PlatformType.HUAWEI, 'testq6zq98hecj'],
                [PlatformType.CSJ, '893734833'],
                [PlatformType.TENCENT, '2284659488139986'],
              ])],
              ['info', new Map([
                [PlatformType.HUAWEI, 'testu7m3hc4gvm'],
                [PlatformType.CSJ, '974048794'],
                [PlatformType.TENCENT, '4254455418564051'],
              ])],
              ['info_left', new Map([
                [PlatformType.HUAWEI, 'testb65czjivt9'],
                [PlatformType.CSJ, '974048780'],
                [PlatformType.TENCENT, '9294451478852349'],
              ])],
              ['video', new Map([
                [PlatformType.HUAWEI, 'testx9dtjwj8hp'],
                [PlatformType.CSJ, '974048742'],
                [PlatformType.TENCENT, '2224656498544987'],
              ])],
              ['lscr', new Map([
                [PlatformType.HUAWEI, 'testb4znbuh3n2'],
                [PlatformType.CSJ, '974048733'],
                [PlatformType.TENCENT, '5284157488847440'],
              ])],
            ]);
            AdSlotManager.getInstance().updateAllAdSlots(map)
          }
        } catch (e) {
          LogManager.error('SDKCore', '测试广告ID异常', e);
        }

        const ss = off.ss.split(',');
        LogManager.warn('SDKCore', `广告模式: ${AdModeManager.getADModeName(AdModeManager.getADMode(off))}`);
        const mode = AdModeManager.getADMode(off);
        AdSwitchManager.setAdPlatformFlags(
          mode == AdConstants.OFF_CSJ,
          mode == AdConstants.OFF_HW,
          mode == AdConstants.OFF_TX,
          mode != AdConstants.OFF_CLOSE
        );
        LogManager.warn('SDKCore', `ss: ${JSON.stringify(ss)}`);
      } else {
        LogManager.error('SDKCore', '请求广告模式开关异常');
      }
    } catch (e) {
      SDKCore.logRequestError('requestOFF', e);
    }
  }

  /**
   * 请求云创广告开关[v5]
   * 需隐私政策授权后请求
   */
  static async requestEasyOFF() {
    try {
      const off: ZyOFF | null = await SDKCore.requestV5();
      if (off) {
        SDKCore.OFF = off;
        if (off.d) {
          const date: string = ADUtil.formatTsToDate(off.d)
          const ltime: string = VIPRepo.instance.props.ltime
          if (date > ltime) {
            // VIP已过期
            VIPRepo.instance.props.updateVip(false)
          }
        }

        if (AdSwitchManager.enableDynamicAD) {
          try {
            ConfigVerifier.verifyEasyConfigAdSwitchManager(off);
          } catch (e) {
            LogManager.error('SDKCore', 'V5校验异常', e);
          }
        }

        try {
          // 测试广告 ID 切换已迁移至 TestLog.checkUpdateAllSlotToTestAdId()
        } catch (e) {
          LogManager.error('SDKCore', '测试广告ID异常', e);
        }

        const ss = off.ss.split(',');
        LogManager.warn('SDKCore', `广告模式: ${AdModeManager.getADModeName(AdModeManager.getADMode(off))}`);
        const mode = AdModeManager.getADMode(off);
        AdSwitchManager.setAdPlatformFlags(
          mode == AdConstants.OFF_CSJ,
          mode == AdConstants.OFF_HW,
          mode == AdConstants.OFF_TX,
          mode != AdConstants.OFF_CLOSE
        );
        LogManager.warn('SDKCore', `ss: ${JSON.stringify(ss)}`);
      } else {
        LogManager.error('SDKCore', '请求广告模式开关异常');
      }
    } catch (e) {
      SDKCore.logRequestError('requestEasyOFF', e);
    }
  }

  /**
   * OFF 请求失败统一诊断：按 HttpError.kind 分支输出，便于区分业务码拦截 / 网络 / HTTP
   */
  private static logRequestError(tag: string, e: ESObject): void {
    const kind: string | undefined = e && typeof e === 'object' && e.kind !== undefined
      ? String(e.kind) : undefined;
    const code: string | undefined = e && typeof e === 'object' && e.code !== undefined
      ? String(e.code) : undefined;
    const msg: string = e instanceof Error ? e.message : String(e);
    LogManager.error('SDKCore', `${tag}请求异常 kind=${kind ?? 'unknown'} code=${code ?? '-'}: ${msg}`, e);
  }

  /**
   * 请求V4开关
   */
  private static async requestV4(): Promise<ZyOFF | null> {
    // 建造者模式：setToken 传入 token 规格，签名插件计算 md5 后注入 params.token
    const zyoff: ZyOFF | null = await zyClient.with()
      .urlPath(V4[0])
      .setToken(V4[1])
      .post<ZyOFF>()
    return zyoff ?? null
  }

  /**
   * 请求V5开关
   */
  private static async requestV5(): Promise<ZyOFF | null> {
    // 建造者模式：addHeader 注入业务头 y，setToken 传入 token 规格
    const zyoff: ZyOFF | null = await zyClient.with()
      .urlPath(V5[0])
      .addHeader('y', SDKCore?.EASY_AD?.ycid ?? '')
      .setToken(V5[1])
      .post<ZyOFF>()
    return zyoff ?? null
  }
}