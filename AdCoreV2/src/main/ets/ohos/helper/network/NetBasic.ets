import { cryptoFramework } from "@kit.CryptoArchitectureKit"
import { buffer } from "@kit.ArkTS"
import { zyLog } from '@creative/net';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class NetBasic {
  private static _SID = ''
  private static _SV = ''
  private static _IT = ''
  private static _MARKET_NAME = ''
  private static _PACKAGE_NAME = ''
  private static _DEVICE_ID = ''
  private static _onBaseUrlChange: ((url: string) => void) | null = null

  public static get SID(): string {
    return this._SID;
  }

  public static set SID(value: string) {
    this._SID = value;
  }

  public static get SV(): string {
    return this._SV;
  }

  public static set SV(value: string) {
    this._SV = value;
  }

  public static get IT(): string {
    return this._IT;
  }

  public static set IT(value: string) {
    this._IT = value;
  }

  public static get MARKET_NAME(): string {
    return this._MARKET_NAME;
  }

  public static set MARKET_NAME(value: string) {
    this._MARKET_NAME = value;
  }

  public static get PACKAGE_NAME(): string {
    return this._PACKAGE_NAME;
  }

  public static set PACKAGE_NAME(value: string) {
    this._PACKAGE_NAME = value;
  }

  public static get DEVICE_ID(): string {
    return this._DEVICE_ID;
  }

  public static set DEVICE_ID(value: string) {
    this._DEVICE_ID = value;
  }

  public static set baseUrl(value: string) {
    if (NetBasic._onBaseUrlChange !== null) {
      NetBasic._onBaseUrlChange(value)
    }
  }

  public static set onBaseUrlChange(handler: ((url: string) => void) | null) {
    NetBasic._onBaseUrlChange = handler;
  }

  /**
   * 重置所有网络配置信息
   */
  public static reset(): void {
    NetBasic._SID = '';
    NetBasic._SV = '';
    NetBasic._IT = '';
    NetBasic._MARKET_NAME = '';
    NetBasic._PACKAGE_NAME = '';
    NetBasic._DEVICE_ID = '';
  }

  /**
   * 检查是否所有必要的网络配置都已设置
   * @returns 是否所有必要配置都已设置
   */
  public static isConfigured(): boolean {
    return !!(NetBasic._SID && NetBasic._SV && NetBasic._IT);
  }

  /**
   * 获取所有网络配置信息
   * @returns 包含所有网络配置的对象
   */
  public static getAllConfig(): Record<string, string> {
    // 空字面量 + 索引赋值（规避 ArkTS 对 Record 非空字面量的限制）
    const conf: Record<string, string> = {};
    conf['SID'] = NetBasic._SID;
    conf['SV'] = NetBasic._SV;
    conf['IT'] = NetBasic._IT;
    conf['MARKET_NAME'] = NetBasic._MARKET_NAME;
    conf['PACKAGE_NAME'] = NetBasic._PACKAGE_NAME;
    conf['DEVICE_ID'] = NetBasic._DEVICE_ID;
    return conf;
  }

  /**
   * 从对象中设置所有网络配置信息
   * @param config 包含网络配置的对象
   */
  public static setAllConfig(config: Record<string, string>): void {
    if (config.SID) {
      NetBasic._SID = config.SID;
    }
    if (config.SV) {
      NetBasic._SV = config.SV;
    }
    if (config.IT) {
      NetBasic._IT = config.IT;
    }
    if (config.MARKET_NAME) {
      NetBasic._MARKET_NAME = config.MARKET_NAME;
    }
    if (config.PACKAGE_NAME) {
      NetBasic._PACKAGE_NAME = config.PACKAGE_NAME;
    }
    if (config.DEVICE_ID) {
      NetBasic._DEVICE_ID = config.DEVICE_ID;
    }
  }
}

/**
 * 计算字符串的 MD5 哈希值，返回十六进制字符串
 * @param msg 要计算 MD5 的字符串
 * @returns 32 位十六进制 MD5 字符串
 */
export const md5Sync = (msg: string): string => {
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
    // P1-7②: md5 异常打 error 日志并返回空md5串
    zyLog(hilog.error, `[SIGN] md5Sync 计算失败: ${e}`);
    return 'd41d8cd98f00b204e9800998ecf8427e';
  }
}