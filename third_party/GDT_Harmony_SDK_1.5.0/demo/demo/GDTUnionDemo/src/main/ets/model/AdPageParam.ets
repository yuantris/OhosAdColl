/**
 * 广告 Demo 页面的路由参数基类
 * 广告 Demo 页面在 onReady 中读取，实现自动加载并展示广告。
 */
export interface AdPageParam {
  /** 是否自动加载并展示广告 */
  autoLoadAndShow?: boolean;
  /**
   * 由 SDK 预先计算好的"目标子页路由名"，仅信息流 Entry 页消费。
   * 例如：'NativeAdListPage' / 'NativeAdSimplePage' / 'NativeManualAdListPage' / 'NativeManualAdSimplePage'。
   * 非信息流 Entry 页可忽略此字段。
   */
  subPage?: string;
  /** 屏幕方向：1=竖屏(portrait)，2=横屏(landscape)。未传默认竖屏。 */
  orientation?: number;
}
