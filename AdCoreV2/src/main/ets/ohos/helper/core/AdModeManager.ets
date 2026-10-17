import { PlatformType } from "../../model/PlatformType";
import { AdConstants } from '../const/AdConstants';
import { ForceChannelManager } from './ForceChannelManager';
import { ZyOFF } from "../entity/ZyOFF";
import { LogManager } from '../logger/LogManager';

// 广告模式管理
export class AdModeManager {
  private static readonly TAG = 'AdModeManager';

  /**
   * 广告模式
   * @param off - zyOff配置对象
   * @returns 广告模式(0:关闭,1:穿山甲,2:腾讯,3:华为)
   */
  static getADMode(off: ZyOFF): number {
    if (ForceChannelManager.isForceAdChannelEnabled()) {
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_CSJ) {
        return AdConstants.OFF_CSJ
      }
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_TX) {
        return AdConstants.OFF_TX
      }
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_HW) {
        return AdConstants.OFF_HW
      }
    }

    const ss: string[] = off.ss.split(',');
    const c: number = off.c;
    const h: number = off.h;
    const t: number = off.t;

    const modeMap: Map<string, number> = new Map([
      ['1', c === 1 ? AdConstants.OFF_CSJ : AdConstants.OFF_CLOSE],
      ['2', t === 1 ? AdConstants.OFF_TX : AdConstants.OFF_CLOSE],
      ['4', h === 1 ? AdConstants.OFF_HW : AdConstants.OFF_CLOSE],
    ]);

    for (let i = 0; i < ss.length; i++) {
      const currentMode = modeMap.get(ss[i]);
      if (currentMode && currentMode !== 0) {
        return currentMode;
      }
    }

    return AdConstants.OFF_CLOSE;
  }

  /**
   * 广告模式编号转可读名称(日志输出用, 避免裸数字不可读)
   * @param mode 广告模式编号(0:关闭,1:穿山甲,2:腾讯,3:华为)
   * @returns 模式名称
   */
  static getADModeName(mode: number): string {
    switch (mode) {
      case AdConstants.OFF_CSJ:
        return 'CSJ(穿山甲)';
      case AdConstants.OFF_TX:
        return 'TX(腾讯)';
      case AdConstants.OFF_HW:
        return 'HW(华为)';
      default:
        return 'CLOSE(关闭)';
    }
  }

  /**
   * 获取当前可用的广告平台
   * @param off - zyOff配置对象
   * @returns 可用的广告平台数组，按优先级排序
   */
  static getAvailableAdPlatforms(off: ZyOFF): PlatformType[] {
    if (!off || !off.ss) {
      return [];
    }

    const ss: string[] = Array.from(new Set(off.ss.split(',').filter(p => p.trim() !== '')));
    const availablePlatforms: PlatformType[] = [];

    // 检查每个广告平台是否启用
    for (const platform of ss) {
      switch (platform) {
        case '1': // 穿山甲
          if (off.c === 1) {
            availablePlatforms.push(PlatformType.CSJ);
          }
          break;
        case '2': // 腾讯
          if (off.t === 1) {
            availablePlatforms.push(PlatformType.TENCENT);
          }
          break;
        case '4': // 华为
          if (off.h === 1) {
            availablePlatforms.push(PlatformType.HUAWEI);
          }
          break;
        default:
          LogManager.warn(AdModeManager.TAG, `Unknown ad platform type: ${platform}`);
          break;
      }
    }

    if (ForceChannelManager.isForceAdChannelEnabled()) {
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_CSJ) {
        return [PlatformType.CSJ]
      }
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_TX) {
        return [PlatformType.TENCENT]
      }
      if (ForceChannelManager.forceEnableAdChannel == AdConstants.OFF_HW) {
        return [PlatformType.HUAWEI]
      }
    }
    return availablePlatforms;
  }


}