/**
 * 广告展示状态枚举类
 * 定义广告的各种展示状态
 */
export enum AdStatus {
  /**
   * 广告成功展示
   */
  AD_SHOWN = 'ad_shown',
  
  /**
   * 广告展示失败
   */
  AD_SHOW_FAILED = 'ad_show_failed',
  
  /**
   * 广告被点击
   */
  AD_CLICKED = 'ad_clicked',
  
  /**
   * 广告被关闭
   */
  AD_CLOSED = 'ad_closed',
  
  /**
   * 广告等待刷新
   */
  AD_WAITING_REFRESH = 'ad_waiting_refresh'
}