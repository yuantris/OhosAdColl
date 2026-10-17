import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AD } from '../../config/AD';
import { ErrCode } from '../../config/ErrCode';

const KEY_REWARD_DATA = "reward_ad_data";
const KEY_REWARD_STATUS = "reward_ad_status";

export class RewardAdStatusHandler {
  // 用于保存创建成功的订阅者对象，后续使用其完成订阅及退订的动作
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private isComplete: boolean = false

  // 订阅方法，需要在每次展示广告前调用
  public registerPPSReceiver(callback: (err?: BusinessError) => void): void {
    if (this.subscriber) {
      this.unRegisterPPSReceiver();
    }
    // 订阅者信息
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['com.huawei.hms.pps.action.PPS_REWARD_STATUS_CHANGED'],
      // publisherBundleName被设置为"com.huawei.hms.adsservice",这意味着只有来自该包名的事件才会被订阅者接受和处理。
      // 如果没有明确声明publisherBundleName，那么订阅者可能会收到来自其它包名的伪造事件，从而导致安全性问题或误导。
      publisherBundleName: 'com.huawei.hms.adsservice'
    };
    // 创建订阅者回调
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, commonEventSubscriber:
      commonEventManager.CommonEventSubscriber) => {
      if (err) {
        hilog.error(0x0000, 'testTag', '%{public}s',
          `createSubscriber error, code: ${err.code}, message: ${err.message}`);
        return;
      }
      hilog.info(0x0000, 'testTag', '%{public}s', 'Succeeded in creating subscriber');
      this.subscriber = commonEventSubscriber;
      // 订阅公共事件回调
      if (!this.subscriber) {
        hilog.warn(0x0000, 'testTag', '%{public}s', 'Need create subscriber');
        return;
      }
      commonEventManager.subscribe(this.subscriber, (err: BusinessError, commonEventSubscriber:
        commonEventManager.CommonEventData) => {
        if (err) {
          hilog.error(0x0000, 'testTag', '%{public}s', `Subscribe error, code: ${err.code}, message: ${err.message}`);
          callback()
        } else {
          hilog.info(0x0000, 'testTag', '%{public}s', 'Subscribe data');
          const status: string = commonEventSubscriber?.parameters?.[KEY_REWARD_STATUS];
          switch (status) {
            case AdStatus.AD_OPEN:
              hilog.info(0x0000, 'testTag', '%{public}s', 'onAdOpen');
              break;
            case AdStatus.AD_CLICKED:
              hilog.info(0x0000, 'testTag', '%{public}s', 'onAdClick');
              break;
            case AdStatus.AD_CLOSED:
              hilog.info(0x0000, 'testTag', '%{public}s', 'onAdClose');
              if (this.isComplete) {
                callback()
              } else {
                if (AD.isADJumpCheck()) {
                  callback({
                    code: ErrCode.NO_FULL_VIDEO,
                    message: '未完整观看激励视频'
                  } as BusinessError)
                } else {
                  callback()
                }
              }
              this.unRegisterPPSReceiver();
              break;
            case AdStatus.AD_REWARDED:
              const rewardData: Record<string, string | number> = commonEventSubscriber?.parameters?.[KEY_REWARD_DATA];
              const rewardType: string = rewardData?.rewardType as string;
              const rewardAmount: number = rewardData?.rewardAmount as number;
              hilog.info(0x0000, 'testTag', '%{public}s',
                `onAdReward, rewardType: ${rewardType}, rewardAmount: ${rewardAmount}`);
              if (!this.isComplete) {
                this.isComplete = true;
              }
              break;
            case AdStatus.AD_VIDEO_START:
              hilog.info(0x0000, 'testTag', '%{public}s', 'onAdVideoStart');
              break;
            case AdStatus.AD_COMPLETED:
              hilog.info(0x0000, 'testTag', '%{public}s', 'onAdCompleted');
              if (!this.isComplete) {
                this.isComplete=true
              }
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
        hilog.error(0x0000, 'testTag', '%{public}s', `Unsubscribe error, code: ${err.code}, message: ${err.message}`);
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
  AD_REWARDED = 'onAdReward',
  AD_VIDEO_START = 'onVideoPlayBegin',
  AD_COMPLETED = 'onVideoPlayEnd'
}