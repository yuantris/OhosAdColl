import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { OnAdListener } from '../../../interface/OnAdListener';
import { OnVideoRewardListener } from '../../../interface/OnVideoRewardListener';
import { AdSwitchManager } from '../../core/AdSwitchManager';
import { ErrCode } from '../../const/ErrCode';
import { LogManager } from '../../logger/LogManager';

const KEY_REWARD_DATA = "reward_ad_data";
const KEY_REWARD_STATUS = "reward_ad_status";
const TAG = 'RewardAdStatusHandler';

export class RewardAdStatusHandler {
  // 用于保存创建成功的订阅者对象，后续使用其完成订阅及退订的动作
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private isComplete: boolean = false

  // 订阅方法，需要在每次展示广告前调用
  public registerPPSReceiver(callback: (err?: BusinessError) => void, adListener?: OnAdListener,
    videoRewardListener?: OnVideoRewardListener): void {
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
        LogManager.error(TAG, `createSubscriber error, code: ${err.code}, message: ${err.message}`, err);
        return;
      }
      LogManager.info(TAG, 'createSubscriber success');
      this.subscriber = commonEventSubscriber;
      // 订阅公共事件回调
      if (!this.subscriber) {
        LogManager.warn(TAG, 'subscriber is not created');
        return;
      }
      commonEventManager.subscribe(this.subscriber, (err: BusinessError, commonEventSubscriber:
        commonEventManager.CommonEventData) => {
        if (err) {
          LogManager.error(TAG, `subscribe error, code: ${err.code}, message: ${err.message}`, err);
          callback()
        } else {
          LogManager.info(TAG, 'subscribe success');
          const status: string = commonEventSubscriber?.parameters?.[KEY_REWARD_STATUS];
          switch (status) {
            case AdStatus.AD_OPEN:
              LogManager.info(TAG, '华为激励视频onAdOpen')
              // 触发广告展示事件
              adListener?.onAdShow?.();
              videoRewardListener?.onVideoShow?.();
              break;
            case AdStatus.AD_CLICKED:
              LogManager.info(TAG, '华为激励视频onAdClick')
              // 触发广告点击事件
              adListener?.onClick?.();
              videoRewardListener?.onVideoClick?.();
              break;
            case AdStatus.AD_CLOSED:
              LogManager.info(TAG, '华为激励视频onAdClose')
              // 触发广告关闭事件
              adListener?.onAdClose?.();
              if (this.isComplete) {
                // 触发视频播放完成事件
                LogManager.info(TAG, '华为激励视频onVideoComplete')
                videoRewardListener?.onVideoComplete?.();
                callback()
              } else {
                if (AdSwitchManager.isADJumpCheck()) {
                  videoRewardListener?.onVideoError?.(ErrCode.NO_FULL_VIDEO, '未完整观看激励视频')
                  callback({
                    code: ErrCode.NO_FULL_VIDEO,
                    message: '未完整观看激励视频'
                  } as BusinessError)
                } else {
                  callback()
                  // 触发视频播放完成事件
                  LogManager.info(TAG, '华为激励视频onVideoComplete')
                  videoRewardListener?.onVideoComplete?.();
                }
              }
              this.unRegisterPPSReceiver();
              break;
            case AdStatus.AD_REWARDED:
              const rewardData: Record<string, string | number> = commonEventSubscriber?.parameters?.[KEY_REWARD_DATA];
              const rewardType: string = rewardData?.rewardType as string;
              const rewardAmount: number = rewardData?.rewardAmount as number;
              LogManager.info(TAG,
                `华为激励视频 onAdReward, rewardType: ${rewardType}, rewardAmount: ${rewardAmount}`)
              if (!this.isComplete) {
                this.isComplete = true;
              }
              break;
            case AdStatus.AD_VIDEO_START:
              LogManager.info(TAG, '华为激励视频onAdVideoStart')
              break;
            case AdStatus.AD_COMPLETED:
              LogManager.info(TAG, '华为激励视频onAdCompleted')
              if (!this.isComplete) {
                this.isComplete = true
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
        LogManager.error(TAG, `unsubscribe error, code: ${err.code}, message: ${err.message}`, err);
      } else {
        LogManager.info(TAG, 'unsubscribe success');
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