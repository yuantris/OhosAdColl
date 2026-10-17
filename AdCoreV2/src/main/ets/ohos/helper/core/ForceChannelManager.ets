import { LogManager } from '../logger/LogManager';
import { AdConstants } from '../const/AdConstants';
import { PlatformType } from '../../model/PlatformType';

export class ForceChannelManager {
  private static _forceEnableAdChannel: number = -1

  static get forceEnableAdChannel(): number { return ForceChannelManager._forceEnableAdChannel }

  static setForceAdChannel(channel: number): void {
    if (channel === AdConstants.OFF_CSJ || channel === AdConstants.OFF_TX || channel === AdConstants.OFF_HW || channel === -1) {
      ForceChannelManager._forceEnableAdChannel = channel
      LogManager.info('ForceChannelManager', `强制启用广告渠道: ${channel}`)
    } else {
      throw new Error(`不存在的渠道类型: ${channel}`)
    }
  }

  static clearForceAdChannel(): void {
    ForceChannelManager._forceEnableAdChannel = -1
    LogManager.info('ForceChannelManager', `清除强制启用的广告渠道`)
  }

  static isForceAdChannelEnabled(): boolean {
    return ForceChannelManager._forceEnableAdChannel > 0
  }

  static toPlatformType(): PlatformType | null {
    switch (ForceChannelManager._forceEnableAdChannel) {
      case AdConstants.OFF_CSJ:
        return PlatformType.CSJ
      case AdConstants.OFF_TX:
        return PlatformType.TENCENT
      case AdConstants.OFF_HW:
        return PlatformType.HUAWEI
      default:
        return null
    }
  }
}
