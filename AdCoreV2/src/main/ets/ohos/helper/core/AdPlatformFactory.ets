import { PlatformType } from '../../model/PlatformType';
import { IAdPlatform } from '../impl/IAdPlatform';
import { CsjAdPlatform } from '../platform/CsjAdPlatform';
import { HuaweiAdPlatform } from '../platform/HuaweiAdPlatform';
import { TencentAdPlatform } from '../platform/TencentAdPlatform';

export class AdPlatformFactory {
  /**
   * 创建广告平台实例
   */
  static createPlatform(platformType: PlatformType): IAdPlatform {
    switch (platformType) {
      case PlatformType.CSJ:
        return new CsjAdPlatform();
      case PlatformType.HUAWEI:
        return new HuaweiAdPlatform();
      case PlatformType.TENCENT:
        return new TencentAdPlatform();
      default:
        throw new Error(`Unsupported platform type: ${platformType}`);
    }
  }
}
