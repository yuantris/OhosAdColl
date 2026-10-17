import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OnAdListener } from '../../../interface/OnAdListener';
import { LogManager } from '../../logger/LogManager';

const KEY_INTERSTITIAL_STATUS = 'interstitial_ad_status';

export class InterstitialAdStatusHandler {
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private adListener: OnAdListener | undefined;

  setAdListener(listener: OnAdListener | undefined): void {
    this.adListener = listener;
  }

  public registerPPSReceiver(): void {
    if (this.subscriber) {
      this.unRegisterPPSReceiver();
    }
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['com.huawei.hms.pps.action.PPS_INTERSTITIAL_STATUS_CHANGED'],
      publisherBundleName: 'com.huawei.hms.adsservice'
    };
    commonEventManager.createSubscriber(subscribeInfo,
      (err: BusinessError, commonEventSubscriber: commonEventManager.CommonEventSubscriber) => {
        if (err) {
          LogManager.error('InterstitialAdStatusHandler', `CreateSubscriber error: ${err.code}, ${err.message}`);
          return;
        }
        LogManager.info('InterstitialAdStatusHandler', 'Succeeded in creating subscriber');
        this.subscriber = commonEventSubscriber;
        if (!this.subscriber) {
          LogManager.warn('InterstitialAdStatusHandler', 'Need to create subscriber');
          return;
        }
        commonEventManager.subscribe(this.subscriber,
          (err: BusinessError, commonEventData: commonEventManager.CommonEventData) => {
            if (err) {
              LogManager.error('InterstitialAdStatusHandler', `Subscribe error: ${err.code}, ${err.message}`);
            } else {
              LogManager.info('InterstitialAdStatusHandler', 'Succeeded subscribing data');
              const status: string = commonEventData?.parameters?.[KEY_INTERSTITIAL_STATUS];
              switch (status) {
                case AdStatus.AD_OPEN:
                  LogManager.info('InterstitialAdStatusHandler', 'onAdOpen');
                  this.adListener?.onAdShow?.();
                  break;
                case AdStatus.AD_CLICKED:
                  LogManager.info('InterstitialAdStatusHandler', 'onAdClick');
                  this.adListener?.onClick?.();
                  break;
                case AdStatus.AD_CLOSED:
                  LogManager.info('InterstitialAdStatusHandler', 'onAdClose');
                  this.adListener?.onAdClose?.();
                  this.unRegisterPPSReceiver();
                  break;
                case AdStatus.AD_VIDEO_START:
                  LogManager.info('InterstitialAdStatusHandler', 'onAdVideoStart');
                  break;
                case AdStatus.AD_COMPLETED:
                  LogManager.info('InterstitialAdStatusHandler', 'onAdCompleted');
                  break;
                default:
                  break;
              }
            }
          });
      });
  }

  public unRegisterPPSReceiver(): void {
    commonEventManager.unsubscribe(this.subscriber, (err: BusinessError) => {
      if (err) {
        LogManager.error('InterstitialAdStatusHandler', `Unsubscribe error: ${err.code}, ${err.message}`);
      } else {
        LogManager.info('InterstitialAdStatusHandler', 'Succeeded in unsubscribing');
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