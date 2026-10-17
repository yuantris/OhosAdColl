import { OnAdListener } from '../../interface/OnAdListener';
import { HuaweiSplashAdParams } from '../../interface/HuaweiSplashAdParams';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';

/**
 * 独立型广告接口
 * 适用于：开屏广告、插屏广告、激励视频广告等独立展示的广告
 * 标准生命周期：load() → isReady() → show() → destroy()
 */
export interface IndependentAd {
  /**
   * 加载广告（素材就绪后 resolve，不自动展示）
   */
  load(): Promise<void>;

  /**
   * 展示广告（load 成功后调用）
   */
  show(): void;

  /**
   * 广告是否就绪可展示
   */
  isReady(): boolean;

  /**
   * 销毁广告
   */
  destroy(): void;

  /**
   * 检查广告是否有效
   */
  isValid(): boolean;

  /**
   * 设置广告监听器
   */
  setAdListener?(listener: OnAdListener): void;

  /**
   * 设置激励视频监听器
   */
  setVideoRewardListener?(listener:OnVideoRewardListener):void

  /**
   * 获取华为开屏广告所需参数
   * 仅对华为开屏广告有效
   */
  getHuaweiAdParams?(): HuaweiSplashAdParams;
}