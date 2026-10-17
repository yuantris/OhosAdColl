
export interface OnAdListener {

  /**
   * 广告请求
   */
  onAdRequest(): void;

  /**
   * 广告请求失败
   *
   * @param code 错误码
   * @param msg 错误消息
   */
  onAdRequestError(code: number, msg: string): void;

  /**
   * 广告渲染
   */
  onAdRender(): void;

  /**
   * 广告展示
   */
  onAdShow(): void;

  /**
   * 广告展示失败
   *
   * @param code 错误码
   * @param msg 错误消息
   */
  onAdShowError(code: number, msg: string): void;

  /**
   * 广告点击
   */
  onAdClick(): void;

  /**
   * 广告解锁
   */
  onAdUnlock(): void;

  /**
   * 广告跳过
   */
  onAdSkip(): void;

  /**
   * 广告关闭
   */
  onAdClose(): void;

  /**
   * 广告销毁
   */
  onAdDestroy(): void;
}
