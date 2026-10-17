import { PlatformType } from '../../model/PlatformType';
import { ErrCode } from '../const/ErrCode';

/**
 * 平台错误码统一命名空间
 * 81xx = CSJ, 82xx = TENCENT, 83xx = HUAWEI
 * 平台原生码经 mapPlatformError 归一，避免 parseFromMessage 启发式误抽
 */
export class PlatformErrorMap {
  private static readonly CSJ_BASE = 8100;
  private static readonly TX_BASE = 8200;
  private static readonly HW_BASE = 8300;

  /**
   * 将平台原生错误码映射到统一命名空间
   * 常见语义码归入 ErrCode，其余保留为平台偏移码
   */
  static map(platform: PlatformType, nativeCode: number): number {
    // 超时语义统一
    if (nativeCode === ErrCode.AD_TIMEOUT) {
      return ErrCode.AD_TIMEOUT;
    }
    switch (platform) {
      case PlatformType.CSJ:
        return PlatformErrorMap.mapCsj(nativeCode);
      case PlatformType.TENCENT:
        return PlatformErrorMap.mapTx(nativeCode);
      case PlatformType.HUAWEI:
        return PlatformErrorMap.mapHw(nativeCode);
      default:
        return nativeCode;
    }
  }

  /** 穿山甲：无广告/填充失败 → AD_LOAD_FAILED */
  private static mapCsj(code: number): number {
    // 40001-40034 等为无广告/配置类错误，统一归加载失败
    if ((code >= 40001 && code <= 40034) || code === -2 || code === -3) {
      return ErrCode.AD_LOAD_FAILED;
    }
    return PlatformErrorMap.CSJ_BASE + (code > 0 ? code % 100 : 0);
  }

  /** 优量汇：5004 无广告、40001/40002 配置错误 */
  private static mapTx(code: number): number {
    if (code === 5004 || code === 40001 || code === 40002) {
      return ErrCode.AD_LOAD_FAILED;
    }
    return PlatformErrorMap.TX_BASE + (code > 0 ? code % 100 : 0);
  }

  /** 华为：21800003/21800004 无广告 */
  private static mapHw(code: number): number {
    if (code === 21800003 || code === 21800004) {
      return ErrCode.AD_LOAD_FAILED;
    }
    return PlatformErrorMap.HW_BASE + (code > 0 ? code % 100 : 0);
  }

  /**
   * 生成统一错误对象所需 message 前缀，便于诊断区分平台原生码
   */
  static describe(platform: PlatformType, nativeCode: number, nativeMessage: string): string {
    const unified = PlatformErrorMap.map(platform, nativeCode);
    return `[${PlatformErrorMap.platformName(platform)}:${nativeCode}] ${nativeMessage} (unified=${unified})`;
  }

  private static platformName(platform: PlatformType): string {
    switch (platform) {
      case PlatformType.CSJ:
        return 'CSJ';
      case PlatformType.TENCENT:
        return 'TX';
      case PlatformType.HUAWEI:
        return 'HW';
      default:
        return 'UNK';
    }
  }
}
