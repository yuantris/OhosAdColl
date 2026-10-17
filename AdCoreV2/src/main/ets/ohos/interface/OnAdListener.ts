export interface OnAdListener {
  // ========== 加载阶段回调 ==========

  /**
   * 整体失败回调: 所有平台(含平台内重试)均加载失败后触发, 与切换过程无关。
   * 单个平台的失败详情请监听 onAdPlatformFailed。
   */
  onAdShowError?(code: number, msg: string): void;

  /**
   * 平台切换开始: 上一平台重试耗尽发生真实降级, 即将尝试新平台时触发。
   * @param fromPlatform 失败的平台(切换起点)
   * @param toPlatform 即将尝试的平台(切换目标)
   * 首轮尝试/同平台内重试不触发(无切换发生)
   */
  onAdPlatformSwitchStart?(fromPlatform: number, toPlatform: number): void;

  /**
   * 平台切换成功: 切换后的目标平台加载成功时触发。
   * @param fromPlatform 原失败的平台(切换起点)
   * @param toPlatform 加载成功的平台(切换目标)
   * 时序示例: 穿山甲失败 → onAdPlatformFailed(穿山甲) → onAdPlatformSwitchStart(穿山甲, 华为)
   *           → 华为成功 → onAdPlatformSwitchSuccess(穿山甲, 华为)
   */
  onAdPlatformSwitchSuccess?(fromPlatform: number, toPlatform: number): void;


  /**
   * 平台失败回调(标准语义): 某平台重试耗尽彻底失败、即将切往下一平台时触发。
   * @param failedPlatform 彻底失败的平台(切换的起因)
   * @param errorCode 该平台的加载错误码
   * @param errorMsg 该平台的加载错误信息
   * 时序示例: 穿山甲失败 → onAdPlatformFailed(穿山甲, code, msg) → onAdPlatformSwitchStart(穿山甲, 华为)
   *           → 华为成功 → onAdPlatformSwitchSuccess(穿山甲, 华为)
   * 注意: 若失败后已无可用平台则不再触发 onAdPlatformSwitchStart, 整体失败由 onAdShowError 收尾
   */
  onAdPlatformFailed?(failedPlatform: number, errorCode: number, errorMsg: string): void;

  // ========== 展示阶段回调 ==========

  onAdRender?(): void;

  onAdShow?(): void;

  onClick?(): void;

  onAdClose?(): void;

  onAdDestroy?(): void;
}
