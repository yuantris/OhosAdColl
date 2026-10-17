import { UIAbility } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { AD } from '../config/AD';
import { Log } from '@zycore/common';
import { ADConfigBuilder } from '../config/ADConfigBuilder';

export class TestLog {
  /**
   * 惊鸿动能广告测试日志，配置华为渠道、测试广告ID
   * @param ability
   */
  static updateMode(ability: UIAbility) {
    if (ability.launchWant?.parameters?.['hwtest']) {
      const params = ability.launchWant?.parameters?.['hwtest']
      const salt = md5Sync(`${ability.launchWant.bundleName}_hwtest_salt`).toLowerCase()
      if (params === salt) {
        // 启动华为渠道，并启动测试广告
        AD.forceEnableAdChannel = AD.OFF_HW
        Log.warn('TestLog', `惊鸿动能广告测试脚本启动-->强制切换华为渠道--->切换为测试广告ID`);
        new ADConfigBuilder()
          .setHW_SPLASH_ID('testq6zq98hecj')
          .setHW_SCREEN_ID('testb4znbuh3n2')
          .setHW_VIDEO_ID('testx9dtjwj8hp')
          .setHW_INFO_ID('testu7m3hc4gvm')
          .setHW_INFO_LEFT_ID('testb65czjivt9')
      }
    }
  }

  /**
   * 强制展示测试广告，ADHelper.init之前调用
   */
  static forceShowTestAd(){
    AD.enableV4AD = false
    // 启动华为渠道，并启动测试广告
    AD.forceEnableAdChannel = AD.OFF_HW
    Log.warn('TestLog', `惊鸿动能广告测试脚本启动-->强制切换华为渠道--->切换为测试广告ID`);
    new ADConfigBuilder()
      .setHW_SPLASH_ID('testq6zq98hecj')
      .setHW_SCREEN_ID('testb4znbuh3n2')
      .setHW_VIDEO_ID('testx9dtjwj8hp')
      .setHW_INFO_ID('testu7m3hc4gvm')
      .setHW_INFO_LEFT_ID('testb65czjivt9')
  }
}

/**
 * 计算字符串的 MD5 哈希值，返回十六进制字符串
 * @param msg 要计算 MD5 的字符串
 * @returns 32 位十六进制 MD5 字符串
 */
const md5Sync = (msg: string): string => {
  // 如果 msg 是空字符串或未定义，返回空字符串的十六进制字符串
  if (!msg || msg === '') {
    return 'd41d8cd98f00b204e9800998ecf8427e';
  }

  try {
    let mdAlgName = 'MD5'; // 摘要算法名
    let message = msg; // 待摘要的数据
    let md = cryptoFramework.createMd(mdAlgName);

    // 更新数据，将字符串转换为 Uint8Array
    md.updateSync({ data: new Uint8Array(buffer.from(message, 'utf-8').buffer) });

    // 计算摘要，得到 Uint8Array
    let mdResult = md.digestSync();
    let mdData = mdResult.data;

    // 将 Uint8Array 转换为十六进制字符串
    let hexString = '';
    for (let i = 0; i < mdData.length; i++) {
      // 转换为十六进制，确保两位数
      const hex = mdData[i].toString(16).padStart(2, '0');
      hexString += hex;
    }

    return hexString;
  } catch (e) {
    // 报错也返回空字符串的十六进制字符串
    return 'd41d8cd98f00b204e9800998ecf8427e';
  }
}