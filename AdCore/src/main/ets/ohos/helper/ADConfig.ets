import ADUtil from "../util/ADUtil";

/**
 * 广告信息
 */
export default class AdConfig {
  private static readonly TAG = 'AdConfig'
  /**
   * 是否重试
   */
  private mRetry = true
  /**
   * 广告类型
   */
  private mAD = AdType.UNKNOWN
  /**
   * 页面类型
   */
  private mPageType = PageType.UNKNOWN
  /**
   * AD ID
   */
  private mADId: string = ''
  private mId: string = '';
  private mPosition: number = -1;
  /**
   * 在自定义的adId唯一的前提下，存在同个广告位，多种场景/业务/数据复用的情况，
   * 但广告需要根据不同业务类型，分别进行控制是否展示
   * 常见的情况有 RecyclerView的item实例重复使用； 遥控器匹配页面，多种电器品牌数据使用一个同一个匹配页面
   */
  private mSecondaryIdentifier: string | undefined;
  /**
   * 唯一位置判断Id
   */
  private mLinkADId: string = '';

  getLinkADId(): string {
    if (this.mLinkADId === '') {
      if (this.mADId !== '') {
        this.mLinkADId =
          ADUtil.isBlank(this.mSecondaryIdentifier) ? this.mADId : `${this.mADId}$${this.mSecondaryIdentifier}`
        this.mLinkADId = this.mPageType === PageType.LIST ? `${this.mLinkADId}$${this.mPosition}` : this.mLinkADId
      }
      ADUtil.logD(AdConfig.TAG, `getLinkADId:${this.mADId} --> ${this.mLinkADId}`)
    }
    return this.mLinkADId;
  }

  isRetry(): boolean {
    return this.mRetry
  }

  setRetry(): void {
    this.mRetry = true
  }

  getAdType(): AdType {
    return this.mAD
  }

  setAdType(ad: AdType): AdConfig {
    this.mAD = ad
    return this
  }

  getPageType(): PageType {
    return this.mPageType;
  }

  setPageType(pageType: PageType): AdConfig {
    this.mPageType = pageType;
    return this;
  }

  getADId(): string {
    return this.mADId;
  }

  setADId(adId: string) {
    this.mADId = adId;
    return this;
  }

  getId(): string {
    if (ADUtil.isBlank(this.mId)) {
      // TODO: 暂时取AdID与真实ID一致
      this.mId = this.mADId
    }
    return this.mId;
  }

  getPosition(): number {
    return this.mPosition;
  }

  setPosition(position: number) {
    this.mPosition = position;
    return this;
  }

  getSecondaryIdentifier(): string | undefined {
    return this.mSecondaryIdentifier;
  }

  setSecondaryIdentifier(secondaryIdentifier: string) {
    this.mSecondaryIdentifier = secondaryIdentifier;
    return this;
  }

  static createBuilder(): AdConfigBuilder {
    return new AdConfigBuilder();
  }
}

class AdConfigBuilder {
  private mAdConfig: AdConfig = new AdConfig()

  setAD(ad: AdType): AdConfigBuilder {
    this.mAdConfig.setAdType(ad);
    return this;
  }

  setPageType(pageType: PageType): AdConfigBuilder {
    this.mAdConfig.setPageType(pageType);
    return this;
  }

  setADId(adId: string): AdConfigBuilder {
    this.mAdConfig.setADId(adId);
    return this;
  }

  build(): AdConfig {
    return this.mAdConfig;
  }
}

/**
 * 广告类型
 */
export enum AdType {
  UNKNOWN, INFO, LINFO, BANNER, VIDEO, SCREEN, COOPEN, NATIVE
}

/**
 * 页面类型
 */
export enum PageType {
  UNKNOWN,
  /**
   * 普通页面
   */
  NORMAL,
  /**
   * Dialog弹窗
   */
  DIALOG,
  /**
   * Dialog弹窗 退出弹窗
   */
  DIALOG_EXIT,
  /**
   * 列表
   */
  LIST
}