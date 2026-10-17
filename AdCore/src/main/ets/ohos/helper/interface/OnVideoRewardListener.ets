
export interface OnVideoRewardListener {
  /**
   * 请求成功
   * @param iAds
   */
  onVideoSuccess: () => void

  /**
   * 请求失败
   * @param code
   * @param error
   */
  onVideoFailed: (code: number, error: string) => void
}