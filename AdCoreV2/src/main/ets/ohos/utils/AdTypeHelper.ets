import { PlatformType } from '../model/PlatformType';
import { AdType } from '../model/AdType';
import { AdConstants } from '../helper/const/AdConstants';

export class AdTypeHelper {
  static toPlatformType(channel: number): PlatformType {
    switch (channel) {
      case AdConstants.OFF_CSJ:
        return PlatformType.CSJ;
      case AdConstants.OFF_TX:
        return PlatformType.TENCENT;
      case AdConstants.OFF_HW:
        return PlatformType.HUAWEI;
      default:
        return PlatformType.UNKNOWN;
    }
  }

  static parseAdType(adTypeStr: string): AdType {
    switch (adTypeStr) {
      case 'SPLASH':
        return AdType.SPLASH;
      case 'VIDEO':
        return AdType.VIDEO;
      case 'INTERSTITIAL':
        return AdType.INTERSTITIAL;
      case 'FEED':
        return AdType.FEED;
      case 'BANNER':
        return AdType.BANNER;
      case 'NATIVE':
        return AdType.NATIVE;
      default:
        return AdType.UNKNOWN;
    }
  }
}
