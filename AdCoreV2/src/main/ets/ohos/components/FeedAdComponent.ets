import { AdSwitchManager } from '../helper/core/AdSwitchManager';
import { AdHub } from '../helper/const/AdHub';
import { BannerAdView, MAX_REFRESH_TIME, MIN_REFRESH_TIME } from './view/BannerAdView';
import { FeedAdView } from './view/FeedAdView';

@ComponentV2
export struct FeedAdComponent {
  @Require @Param adId: string;
  @Require @Param uniqueId: string;
  @Param radius: Length = 0;
  @Param bgColor: ResourceColor = Color.Transparent;
  @Param adWidth: Length = '100%';

  /**
   * 合并ban模式判定（不依赖 adId 子串匹配）：
   * 合并开关开启 + 华为平台 + 当前 adId 属于"小信息流(info_left)槽位"。
   * - V4/ConfigVerifier 路径：组件 adId 即字面槽位名 'info_left'
   * - EasyConfig 路径：AdHub 按配置自定义 adId 登记类型，用类型识别
   */
  private get isBannerMode(): boolean {
    const adOpen = AdSwitchManager.isAdOpen;
    const enableBanMerge = AdSwitchManager.enableBanMerge;
    const isHw = AdSwitchManager.isHw;

    // adOpen=true 只校验enableBanMerge；adOpen=false 校验enableBanMerge || isHw
    const checkFail = adOpen ? !enableBanMerge : (!enableBanMerge || !isHw);
    if (checkFail) return false;

    const target = ['info_left', 'ban'];
    const adType = AdHub.getInstance().getAdTypeByAdId(this.adId);
    return target.includes(this.adId) || target.includes(adType ?? '');
  }


  build(): void {
    if (this.isBannerMode) {
      // 合并ban模式：以华为横幅(adType=8)渲染，复用 info_left 华为真实广告位ID，默认尺寸144
      BannerAdView({
        adId: this.adId,
        uniqueId: this.uniqueId,
        adWidth: this.adWidth,
        bgColor: this.bgColor,
        radius: this.radius,
        refreshTime: MIN_REFRESH_TIME,
        bannerHeight: 144
      })
    } else {
      FeedAdView({
        adId: this.adId,
        uniqueId: this.uniqueId,
        radius: this.radius,
        bgColor: this.bgColor,
        adWidth: this.adWidth
      })
    }
  }
}
