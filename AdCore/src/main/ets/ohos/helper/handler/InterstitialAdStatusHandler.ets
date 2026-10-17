import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const KEY_INTERSTITIAL_STATUS = 'interstitial_ad_status';

export class InterstitialAdStatusHandler {
  // 用于保存创建成功的订阅者对象，后续使用其完成订阅及退订的动作
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;

  // 订阅方法，需要在每次展示广告前调用
  public registerPPSReceiver(): void {
    if (this.subscriber) {
      this.unRegisterPPSReceiver();
    }
    // 订阅者信息
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['com.huawei.hms.pps.action.PPS_INTERSTITIAL_STATUS_CHANGED'],
      publisherBundleName: 'com.cooking.listzyhm'
    };
    // 创建订阅者回调
    commonEventManager.createSubscriber(subscribeInfo,
      (err: BusinessError, commonEventSubscriber: commonEventManager.CommonEventSubscriber) => {
        if (err) {
          hilog.error(0x0000, 'testTag', '%{public}s', `CreateSubscriber error, ${err.code}, message: ${err.message}}`);
          return;
        }
        hilog.info(0x0000, 'testTag', '%{public}s', 'Succeeded in creating subscriber');
        this.subscriber = commonEventSubscriber;
        // 订阅公共事件回调
        if (!this.subscriber) {
          hilog.warn(0x0000, 'testTag', '%{public}s', 'Need to create subscriber');
          return;
        }
        commonEventManager.subscribe(this.subscriber,
          (err: BusinessError, commonEventData: commonEventManager.CommonEventData) => {
            if (err) {
              hilog.error(0x0000, 'testTag', '%{public}s', `Subscribe error, ${err.code}, message: ${err.message}`);
            } else {
              // 订阅者成功接收到公共事件
              hilog.info(0x0000, 'testTag', '%{public}s', 'Succeeded subscribing data');
              // 获取插屏广告页面变化状态
              const status: string = commonEventData?.parameters?.[KEY_INTERSTITIAL_STATUS];
              switch (status) {
                case AdStatus.AD_OPEN:
                  hilog.info(0x0000, 'testTag', '%{public}s', 'onAdOpen');
                  break;
                case AdStatus.AD_CLICKED:
                  hilog.info(0x0000, 'testTag', '%{public}s', 'onAdClick');
                  break;
                case AdStatus.AD_CLOSED:
                  hilog.info(0x0000, 'testTag', '%{public}s', 'onAdClose');
                  this.unRegisterPPSReceiver();
                  break;
                case AdStatus.AD_VIDEO_START:
                  hilog.info(0x0000, 'testTag', '%{public}s', 'onAdVideoStart');
                  break;
                case AdStatus.AD_COMPLETED:
                  hilog.info(0x0000, 'testTag', '%{public}s', 'onAdCompleted');
                  break;
                default:
                  break;
              }
            }
          });
      });
  }

  // 取消订阅
  public unRegisterPPSReceiver(): void {
    commonEventManager.unsubscribe(this.subscriber, (err: BusinessError) => {
      if (err) {
        hilog.error(0x0000, 'testTag', '%{public}s', `Unsubscribe error, ${err.code}, message: ${err.message}}`);
      } else {
        hilog.info(0x0000, 'testTag', '%{public}s', 'Succeeded in unsubscribing');
        this.subscriber = null;
      }
    });
  }
}

enum AdStatus {
  AD_OPEN = 'onAdOpen',
  AD_CLICKED = 'onAdClick',
  AD_CLOSED = 'onAdClose',
  AD_VIDEO_START = 'onVideoPlayBegin',
  AD_COMPLETED = 'onVideoPlayEnd'
}