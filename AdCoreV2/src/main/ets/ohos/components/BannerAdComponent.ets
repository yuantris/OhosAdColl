import { BannerAdView } from './view/BannerAdView';

@ComponentV2
export struct BannerAdComponent {
  /**
   * 逻辑广告槽位，对应云创配置modules.ban中的adId，通常为'ban'
   */
  @Require @Param adId: string;
  /**
   * 广告唯一标识，用于区分不同位置的横幅广告
   */
  @Require @Param uniqueId: string;
  @Param adWidth: Length = '100%';
  @Param bgColor: ResourceColor = Color.Transparent;
  @Param radius: Length = 0;
  /**
   * 轮播时间间隔(ms)。<=0不轮播；否则自动收敛到[30000, 120000]
   */
  @Param refreshTime: number = 30000;
  /**
   * 横幅高度(vp)，仅支持57或144
   */
  @Param bannerHeight: number = 144;

  build(): void {
    BannerAdView({
      adId: this.adId,
      uniqueId: this.uniqueId,
      adWidth: this.adWidth,
      bgColor: this.bgColor,
      radius: this.radius,
      refreshTime: this.refreshTime,
      bannerHeight: this.bannerHeight
    })
  }
}
