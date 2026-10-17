import { AppStorageV2 } from '@kit.ArkUI';

@ObservedV2
export class BiddingSetting {
  // '': 不上报, '0': 不上报, '-1': 上报竞胜，其他为竞败
  @Trace public hasAdSetting: string = '';
  @Trace public noAdSetting: string = '';
}

const BIDDING_SETTING_KEY = 'gdt_bidding_setting';

export function getBiddingSetting(): BiddingSetting {
  return AppStorageV2.connect(BiddingSetting, BIDDING_SETTING_KEY, () => new BiddingSetting())!;
}
