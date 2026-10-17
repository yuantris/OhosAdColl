export enum PlatformType {

  UNKNOWN = 0,
  /**
   * 穿山甲
   */
  CSJ = 1,
  /**
   * 华为
   */
  HUAWEI = 2,
  /**
   * 腾讯
   */
  TENCENT = 3
}

/**
 * 服务器顺序码映射
 * 1: 穿山甲, 2: 腾讯, 3: 快手, 4: 华为
 */
export const SERVER_SEQUENCE_MAP: Map<string, string> = new Map([
  ['1', '穿'],
  ['2', '腾'],
  ['3', '快'],
  ['4', '华']
]);

/**
 * 将平台类型转换为对应的平台名称
 * @param platformType 平台类型枚举值
 * @returns 平台名称字符串
 */
export function getPlatformName(platformType: PlatformType): string {
  switch (platformType) {
    case PlatformType.CSJ:
      return 'CSJ';
    case PlatformType.HUAWEI:
      return 'HUAWEI';
    case PlatformType.TENCENT:
      return 'TENCENT';
    default:
      return 'UNKNOWN';
  }
}
