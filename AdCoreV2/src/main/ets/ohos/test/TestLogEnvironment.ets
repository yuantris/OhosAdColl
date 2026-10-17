import { UIAbility } from '@kit.AbilityKit';
import { AdConstants } from '../helper/const/AdConstants';
import { AdSlotManager } from '../helper/core/AdSlotManager';
import { AdSwitchManager } from '../helper/core/AdSwitchManager';
import { ForceChannelManager } from '../helper/core/ForceChannelManager';
import { LogManager } from '../helper/logger/LogManager';
import { md5Sync } from '../helper/network/NetBasic';
import { PlatformType } from '../model/PlatformType';

export class TestLog {
  private static isHuaweiTestReport: boolean = false

  /**
   * 惊鸿动能广告测试日志，配置华为渠道、测试广告ID
   * @param ability
   */
  static updateMode(ability: UIAbility) {
    LogManager.debug('TestLogEnvironment', `${md5Sync(`${ability.launchWant.bundleName}_hwtest_salt`).toLowerCase()}`)
    if (ability.launchWant?.parameters?.['hwtest']) {
      const params = ability.launchWant?.parameters?.['hwtest']
      const salt = md5Sync(`${ability.launchWant.bundleName}_hwtest_salt`).toLowerCase()
      if (params === salt) {
        TestLog.isHuaweiTestReport = true
        // 启动华为渠道，并启动测试广告
        ForceChannelManager.setForceAdChannel(AdConstants.OFF_HW)
        LogManager.warn('TestLogEnvironment', `惊鸿动能广告测试脚本启动-->强制切换华为渠道--->切换为测试广告ID`);
        TestLog.checkUpdateAllSlotToTestAdId()
      }
    }
  }

  /**
   * 华为测试报告 工具启动
   * @returns true 是工具启动，false 不是
   */
  static get huaweiTestReport(): boolean {
    return TestLog.isHuaweiTestReport
  }


  /**
   * 更新所有广告位中的广告ID为测试ID
   */
  static async checkUpdateAllSlotToTestAdId() {
    if (TestLog.isHuaweiTestReport) {
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
      })
    } else {
      LogManager.warn('TestLogEnvironment', `非惊鸿动能广告测试脚本启动-->无需切换为测试广告ID`);
    }
  }
}