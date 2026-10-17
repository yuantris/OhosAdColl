import { ButtonItem } from './ButtonItem';
import { GDTAdSDK } from '@gdt/gdt-union-sdk';
import { BiddingUtil } from '../utils/BiddingUtil';

@ComponentV2
export struct LoadAndShowCard {
  @Param posId: string = '';
  @Event $posId: (val: string) => void = (val: string) => {};
  @Param onLoadAdClick?: () => void = undefined;
  @Param onAdValidClick?: () => void = undefined;
  @Param onShowAdClick?: () => void = undefined;
  @Param onGetS2STokenClick?: (token: string) => void = undefined;
  @Param onLoadAndShowAdClick?: () => void = undefined;

  build() {
    Column() {
      ButtonItem({ title: '加载广告' })
        .onClick(() => {
          this.onLoadAdClick?.();
        })
      Blank(10)
      ButtonItem({ title: '检查广告是否有效' })
        .onClick(() => {
          this.onAdValidClick?.();
        })
      Blank(10)
      ButtonItem({ title: '展示广告' })
        .onClick(() => {
          this.onShowAdClick?.();
        })
      Blank(10)
      ButtonItem({ title: '获取 S2S TOKEN' })
        .onClick(async () => {
          const buyerId = await GDTAdSDK.getBuyerId();
          const sdkInfo = await GDTAdSDK.getSDKInfo(this.posId);
          const token = await BiddingUtil.getToken(this.posId, buyerId, sdkInfo);
          token && this.onGetS2STokenClick?.(token);
        })
      Blank(10)
      ButtonItem({ title: '加载并展示广告' })
        .onClick(() => {
          this.onLoadAndShowAdClick?.();
        })
    }
  }
}
