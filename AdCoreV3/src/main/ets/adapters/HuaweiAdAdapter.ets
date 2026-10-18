import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { advertising } from '@kit.AdsKit';
import { AdAdapter } from '../core/AdAdapter';
import { AdError, AdErrorCode, AdFormat, AdHandle, AdRequest } from '../core/AdCoreTypes';
import { AdProviderRuntime, resolvePlacementId } from './AdProviderRuntime';
import { AdVendorHandle } from './AdVendorHandle';
import { AdPrivacyGate } from '../core/AdPrivacyGate';

const REWARD_EVENT = 'com.huawei.hms.pps.action.PPS_REWARD_STATUS_CHANGED';
const INTERSTITIAL_EVENT = 'com.huawei.hms.pps.action.PPS_INTERSTITIAL_STATUS_CHANGED';

export class HuaweiAdAdapter implements AdAdapter {
  readonly id: string = 'huawei';
  readonly supportedFormats: AdFormat[] = [AdFormat.Interstitial, AdFormat.Rewarded];
  private readonly runtime: AdProviderRuntime;

  constructor(runtime: AdProviderRuntime) { this.runtime = runtime; }

  async load(request: AdRequest): Promise<AdHandle> {
    AdPrivacyGate.requireConsent(this.id);
    if (request.format !== AdFormat.Interstitial && request.format !== AdFormat.Rewarded) {
      throw new AdError(AdErrorCode.InvalidRequest,
        'Huawei AdsKit adapter currently supports interstitial and rewarded formats only.', this.id);
    }
    return new Promise((resolve, reject) => {
      let settled = false;
      const adType = request.format === AdFormat.Interstitial ? 12 : 7;
      const adOptions: advertising.AdOptions = {
        nonPersonalizedAd: 0, allowMobileTraffic: 0, tagForChildProtection: -1,
        tagForUnderAgeOfPromise: -1, adContentClassification: 'A'
      };
      const params: advertising.AdRequestParams = { adType: adType, adId: resolvePlacementId(request, this.id), oaid: this.runtime.oaid };
      const listener: advertising.AdLoadListener = {
        onAdLoadFailure: (code: number, message: string): void => {
          if (settled) { return; }
          settled = true;
          reject(new AdError(AdErrorCode.LoadFailed, '[' + code + '] ' + message, this.id));
        },
        onAdLoadSuccess: (ads: Array<advertising.Advertisement>): void => {
          if (settled) { return; }
          if (ads.length === 0) {
            settled = true;
            reject(new AdError(AdErrorCode.LoadFailed, 'Huawei AdsKit returned an empty ad list.', this.id));
            return;
          }
          settled = true;
          const ad = ads[0];
          const eventName = request.format === AdFormat.Interstitial ? INTERSTITIAL_EVENT : REWARD_EVENT;
          const statusKey = request.format === AdFormat.Interstitial ? 'interstitial_ad_status' : 'reward_ad_status';
          let rewarded = false;
          let watcher: HuaweiPpsWatcher | null = null;
          const handle = new AdVendorHandle(request.requestId, this.id, request.format, async (): Promise<void> => {
            watcher = new HuaweiPpsWatcher(eventName, statusKey, (status: string): void => {
              if (status === 'onAdReward' || status === 'onVideoPlayEnd') { rewarded = true; }
              if (status === 'onAdClose') {
                if (request.format === AdFormat.Interstitial || rewarded) { handle.notifyCompleted(); }
                else { handle.notifyFailed(-1, 'Rewarded video closed before reward completion.'); }
                watcher?.stop();
              }
            });
            await watcher.start();
            if (request.format === AdFormat.Interstitial) {
              advertising.showAd(ad, { mute: true, colorMode: 1 }, this.runtime.context);
            } else {
              advertising.showAd(ad, {
                nonPersonalizedAd: 0, allowMobileTraffic: 0, tagForChildProtection: -1,
                tagForUnderAgeOfPromise: -1, adContentClassification: 'A'
              }, this.runtime.context);
            }
          }, (): void => { watcher?.stop(); });
          resolve(handle);
        }
      };
      new advertising.AdLoader(this.runtime.context).loadAd(params, adOptions, listener);
    });
  }
}

class HuaweiPpsWatcher {
  private readonly eventName: string;
  private readonly statusKey: string;
  private readonly onStatus: (status: string) => void;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;

  constructor(eventName: string, statusKey: string, onStatus: (status: string) => void) {
    this.eventName = eventName;
    this.statusKey = statusKey;
    this.onStatus = onStatus;
  }

  start(): Promise<void> {
    return new Promise((resolve, reject) => {
      const info: commonEventManager.CommonEventSubscribeInfo = {
        events: [this.eventName], publisherBundleName: 'com.huawei.hms.adsservice'
      };
      commonEventManager.createSubscriber(info,
        (error: BusinessError, subscriber: commonEventManager.CommonEventSubscriber): void => {
          if (error) {
            reject(new AdError(AdErrorCode.LoadFailed,
              'Unable to subscribe to Huawei ad lifecycle: ' + error.message, 'huawei'));
            return;
          }
          this.subscriber = subscriber;
          commonEventManager.subscribe(subscriber,
            (subscribeError: BusinessError, data: commonEventManager.CommonEventData): void => {
              if (subscribeError) { return; }
              const status = data?.parameters?.[this.statusKey];
              if (typeof status === 'string') { this.onStatus(status); }
            });
          resolve();
        });
    });
  }

  stop(): void {
    const subscriber = this.subscriber;
    if (subscriber === null) { return; }
    commonEventManager.unsubscribe(subscriber, (): void => { this.subscriber = null; });
  }
}
