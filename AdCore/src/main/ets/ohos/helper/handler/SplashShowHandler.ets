import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { Log } from '@zycore/common';
import { Launcher } from '../../util/Launcher';
import { RequestApplication } from '../../application/RequestApplication';

export const SPLASH_EVENT = 'com.zy.sdk.action.SPLASH_SHOW';

export class SplashShowHandler {
  // 用于保存创建成功的订阅者对象，后续使用其完成订阅及退订的动作
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;

  /**
   * 订阅方法，需要在每次展示前调用
   */
  public registerSplashReceiver(): void {
    if (this.subscriber) {
      this.unRegisterSplashReceiver();
    }
    // 订阅者信息
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [SPLASH_EVENT],
    };
    // 创建订阅者回调
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, commonEventSubscriber: 
      commonEventManager.CommonEventSubscriber) => {
      if (err) {
        return;
      }
      this.subscriber = commonEventSubscriber;
      // 订阅公共事件回调
      if (!this.subscriber) {
        return;
      }
      commonEventManager.subscribe(this.subscriber, (err: BusinessError, eventData: 
        commonEventManager.CommonEventData) => {
        if (err) {
        } else {
          Launcher.checkGuideAsync().then((value) => {
            // 从RequestApplication获取配置的回调
            const appConfig = RequestApplication.appConfig;
            if (appConfig?.splashEventHandler) {
              // 调用外部配置的回调
              appConfig.splashEventHandler(eventData, value);
              this.unRegisterSplashReceiver();
            } else {
              // 默认处理逻辑
              this.handleEventDefault(eventData, value);
            }
          })

        }
      });
    });
  }

  /**
   * 默认事件处理逻辑
   * @param eventData 公共事件数据
   * @param hasGuide 是否需要显示引导页
   */
  private handleEventDefault(eventData: commonEventManager.CommonEventData, hasGuide: boolean): void {
    if (!hasGuide) {
      const url: string = eventData?.parameters?.['mainPage']
      router.replaceUrl({
        url: url
      }).then(() => {
        Log.debug(`成功跳转应用首页: ${url}`)
        this.unRegisterSplashReceiver()
      }).catch((err: BusinessError) => {
        Log.error(`跳转应用首页失败！当前预备跳转url: ${url}`, err.message)
      })
    } else {
      const url: string = eventData?.parameters?.['guidePage']
      router.replaceUrl({
        url: url
      }).then(() => {
        Log.debug(`成功跳转应用引导页面: ${url}`)
        this.unRegisterSplashReceiver()
      }).catch((err: BusinessError) => {
        Log.error(`成功跳转应用引导页面！当前预备跳转url: ${url}`, err.message)
      })
    }
  }

  /**
   * 取消订阅
   */
  public unRegisterSplashReceiver(): void {
    commonEventManager.unsubscribe(this.subscriber, (err: BusinessError) => {
      if (err) {
        Log.error('取消订阅失败')
      } else {
        this.subscriber = null;
      }
    });
  }
}