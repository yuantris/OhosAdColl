/**
 * SDK自用常量 类
 */
export class SDKConst {
  /**
   * 上次后台时间戳（RequestApplication使用）
   */
  private static lastBackgroundTime: number = 0;

  /**
   * 更新后台记录时间戳（外部禁止调用）
   * @param time
   */
  static updateBackgroundTime(time: number) {
    SDKConst.lastBackgroundTime = time;
  }

  /**
   * 获取上次后台时间戳
   */
  static getLastBackgroundTime() {
    return SDKConst.lastBackgroundTime;
  }
}