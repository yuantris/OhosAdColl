import { IndependentAd } from '../helper/impl/IndependentAd';
import { OnAdListener } from '../interface/OnAdListener';
import { AdComponent, advertising } from '@kit.AdsKit';
import { LogManager } from '../helper/logger/LogManager';
import { ErrCode } from '../helper/const/ErrCode';
import { RequestApplication } from '../../../../../Index';
import { CallbackGuard } from '../helper/core/CallbackGuard';

@ComponentV2
export struct SplashAdComponent {
  @Require @Param ad: IndependentAd | null;
  @Require @Param adListener: OnAdListener;
  private timeoutId: number | undefined = undefined;
  private callbackGuard: CallbackGuard = new CallbackGuard();

  aboutToAppear(): void {
    if (!this.ad) {
      return;
    }

    this.callbackGuard.reset();

    // 组件层超时仅保护"华为 AdComponent 渲染路径"（展示生命周期经 onAdOpen/onAdClose 可清定时器）。
    // 非华为开屏（如穿山甲）由平台 SDK 自绘全屏展示，不经本组件渲染，
    // 其加载超时由各 loader 自管（如 CsjAdLoader 的 AD_LOAD_TIMEOUT_MS），
    // 此处启动定时器只会因无人清理而在广告正常展示关闭后误报 AD_TIMEOUT，故直接跳过
    const huaweiParams = this.ad.getHuaweiAdParams?.();
    if (!huaweiParams || huaweiParams.ads.length === 0) {
      return;
    }

    this.timeoutId = setTimeout(() => {
      LogManager.error('SplashAdComponent', 'Splash ad timed out after 10 seconds');
      this.callbackGuard.guard('onAdShowError', () => {
        this.adListener?.onAdShowError?.(ErrCode.AD_TIMEOUT, 'Splash ad timed out');
      });
    }, 10000);

  }

  /**
   * 组件销毁兜底清理超时定时器：
   * 开屏窗口 destroyWindow 等销毁路径不会自动取消 setTimeout，
   * 不清理的话定时器随全局 event loop 存活，到点仍会误报 onAdShowError(AD_TIMEOUT)
   */
  aboutToDisappear(): void {
    this.clearTimeout();
  }

  private clearTimeout(): void {
    if (this.timeoutId !== undefined) {
      clearTimeout(this.timeoutId);
      this.timeoutId = undefined;
    }
  }

  build() {
    Column() {
      // 检查广告实例是否存在
      if (this.ad) {
        // 检查是否是华为开屏广告
        if (this.ad.getHuaweiAdParams) {
          if (this.ad.getHuaweiAdParams() && this.ad.getHuaweiAdParams().ads.length > 0) {
            // 华为开屏广告需要使用AdComponent展示
            AdComponent({
              ads: this.ad.getHuaweiAdParams().ads,
              displayOptions: this.ad.getHuaweiAdParams().displayOptions,
              interactionListener: {
                onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
                  LogManager.info('SplashAdComponent', 'Ad status:', status);
                  switch (status) {
                    case 'onAdOpen':
                      // 广告打开，清除超时定时器
                      this.clearTimeout();
                      // 广告打开
                      this.adListener?.onAdShow?.()
                      break;
                    case 'onAdClick':
                      // 广告点击
                      this.adListener.onClick?.();
                      break;
                    case 'onAdClose':
                      // 广告关闭，清除超时定时器
                      this.clearTimeout();
                      // 广告关闭
                      this.adListener.onAdClose?.();
                      break;
                    case 'onAdFail':
                      this.callbackGuard.guard('onAdShowError', () => {
                        this.adListener?.onAdShowError?.(ErrCode.AD_RENDER_FAILED, 'Splash ad render failed');
                      });
                      break
                  }
                }
              }
            })
              .width('100%')
              .height('100%')
          }
        }
        // 非华为开屏广告在aboutToAppear中已经处理，这里不需要重复处理
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .backgroundImage(RequestApplication.appConfig.getLauncherBgRes())
    .backgroundImageSize(ImageSize.FILL)
  }
}
