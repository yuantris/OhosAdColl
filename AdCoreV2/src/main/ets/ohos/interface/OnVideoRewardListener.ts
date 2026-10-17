export interface OnVideoRewardListener {
  /**
   * 视频播放完成，发放奖励
   */
  onVideoComplete?(): void;
  
  /**
   * 视频播放失败
   */
  onVideoError?(code: number, msg: string): void;
  
  /**
   * 视频广告点击
   */
  onVideoClick?(): void;

  /**
   * 视频广告展示
   */
  onVideoShow?(): void;
}
