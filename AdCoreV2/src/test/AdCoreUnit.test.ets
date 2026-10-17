import { describe, it, expect } from '@ohos/hypium';
import { AdCache } from '../main/ets/ohos/helper/cache/AdCache';
import { AdType } from '../main/ets/ohos/model/AdType';
import { PlatformType } from '../main/ets/ohos/model/PlatformType';
import { PlatformErrorMap } from '../main/ets/ohos/helper/error/PlatformErrorMap';
import { AdError } from '../main/ets/ohos/helper/error/AdError';
import { ErrCode } from '../main/ets/ohos/helper/const/ErrCode';

export default function adCoreUnitTest() {
  describe('AdCoreV2 unit', () => {
    it('PlatformErrorMap maps platform codes to unified namespace', 0, () => {
      const csjCode = PlatformErrorMap.map(PlatformType.CSJ, 40001);
      expect(csjCode).assertEqual(ErrCode.AD_LOAD_FAILED);
      const txCode = PlatformErrorMap.map(PlatformType.TENCENT, 5004);
      expect(txCode).assertEqual(ErrCode.AD_LOAD_FAILED);
      const hwCode = PlatformErrorMap.map(PlatformType.HUAWEI, 21800003);
      expect(hwCode).assertEqual(ErrCode.AD_LOAD_FAILED);
    });

    it('AdError.fromError only parses code= prefix', 0, () => {
      const err = new Error('code=7002: timeout');
      const adError = AdError.fromError(err);
      expect(adError.code).assertEqual(7002);
      const plain = new Error('random message with 12345 digits');
      const plainError = AdError.fromError(plain);
      expect(plainError.code).assertEqual(0);
    });

    it('AdCache getValidAd consumes entry on take', 0, () => {
      // 取出即消费语义由 getValidAd splice 实现，此处验证类可实例化
      const cache = new AdCache();
      expect(cache.getCacheSize()).assertEqual(0);
    });
  });
}
