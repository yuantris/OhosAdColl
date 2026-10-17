import { AdType } from './AdType';
import { PlatformType } from './PlatformType';

export class AdConfig {
  /**
   * 广告ID
   */
  private adId: string = '';

  /**
   * 广告槽
   */
  private slot?: string
  /**
   * 广告类型
   */
  private adType: AdType = AdType.UNKNOWN;
  /**
   * 页面类型
   */
  private pageType: PageType = PageType.NORMAL;
  /**
   * 位置
   */
  private position: number = -1;
  /**
   * 超时时间（毫秒）
   */
  private timeout: number = 3000;

  /**
   * 平台优先级列表
   */
  private platformPriority: PlatformType[] = [];


  /**
   * 获取广告位
   */
  getAdSlot(): string {
    return this.slot ?? this.adId;
  }

  /**
   * 设置广告位
   * @description 只供DegradationStrategy获取广告位
   */
  setAdSlot(slot: string): AdConfig {
    this.slot = slot;
    return this;
  }

  /**
   * 获取广告ID
   */
  getAdId(): string {
    return this.adId;
  }

  /**
   * 设置广告ID
   */
  setAdId(adId: string): AdConfig {
    this.adId = adId;
    return this;
  }

  /**
   * 获取广告类型
   */
  getAdType(): AdType {
    return this.adType;
  }

  /**
   * 设置广告类型
   */
  setAdType(adType: AdType): AdConfig {
    this.adType = adType;
    return this;
  }

  /**
   * 获取页面类型
   */
  getPageType(): PageType {
    return this.pageType;
  }

  /**
   * 设置页面类型
   */
  setPageType(pageType: PageType): AdConfig {
    this.pageType = pageType;
    return this;
  }

  /**
   * 获取位置
   */
  getPosition(): number {
    return this.position;
  }

  /**
   * 设置位置
   */
  setPosition(position: number): AdConfig {
    this.position = position;
    return this;
  }

  /**
   * 获取超时时间
   */
  getTimeout(): number {
    return this.timeout;
  }

  /**
   * 设置超时时间
   */
  setTimeout(timeout: number): AdConfig {
    this.timeout = timeout;
    return this;
  }

  /**
   * 获取平台优先级列表
   */
  getPlatformPriority(): PlatformType[] {
    return this.platformPriority;
  }

  /**
   * 设置平台优先级列表
   */
  setPlatformPriority(priority: PlatformType[]): AdConfig {
    this.platformPriority = priority;
    return this;
  }

  /**
   * 获取唯一的广告链接ID
   */
  getLinkAdId(): string {
    let linkAdId = this.adId;
    if (this.pageType === PageType.LIST && this.position >= 0) {
      linkAdId += `$${this.position}`;
    }
    return linkAdId;
  }

  /**
   * 创建构建器
   */
  static builder(): AdConfigBuilder {
    return new AdConfigBuilder();
  }
}

/**
 * 页面类型
 */
export enum PageType {
  /**
   * 未知
   */
  UNKNOWN = 0,
  /**
   * 普通页面
   */
  NORMAL = 1,
  /**
   * 列表
   */
  LIST = 2,
  /**
   * 对话框
   */
  DIALOG = 3,
  /**
   * 退出对话框
   */
  DIALOG_EXIT = 4
}

/**
 * 广告配置构建器
 */
export class AdConfigBuilder {
  private adConfig: AdConfig = new AdConfig();

  /**
   * 设置广告ID
   */
  setAdId(adId: string): AdConfigBuilder {
    this.adConfig.setAdId(adId);
    return this;
  }

  /**
   * 设置广告类型
   */
  setAdType(adType: AdType): AdConfigBuilder {
    this.adConfig.setAdType(adType);
    return this;
  }

  /**
   * 设置页面类型
   */
  setPageType(pageType: PageType): AdConfigBuilder {
    this.adConfig.setPageType(pageType);
    return this;
  }

  /**
   * 设置位置
   */
  setPosition(position: number): AdConfigBuilder {
    this.adConfig.setPosition(position);
    return this;
  }

  /**
   * 设置超时时间
   */
  setTimeout(timeout: number): AdConfigBuilder {
    this.adConfig.setTimeout(timeout);
    return this;
  }

  /**
   * 设置平台优先级列表
   */
  setPlatformPriority(priority: PlatformType[]): AdConfigBuilder {
    this.adConfig.setPlatformPriority(priority);
    return this;
  }

  /**
   * 构建广告配置
   */
  build(): AdConfig {
    return this.adConfig;
  }
}
