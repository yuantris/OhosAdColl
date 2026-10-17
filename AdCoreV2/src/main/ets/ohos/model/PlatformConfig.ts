export class PlatformConfig {
  /**
   * 应用ID
   */
  private appId: string = '';
  
  /**
   * 日志开关
   */
  private debug: boolean = false;
  
  /**
   * 是否允许流量下载
   */
  private allowMobileTraffic: number = 0;
  
  /**
   * 个性化广告开关
   */
  private personalizedAd: boolean = true;
  
  /**
   * 初始化超时时间（毫秒）
   */
  private initTimeout: number = 5000;
  
  /**
   * 获取应用ID
   */
  getAppId(): string {
    return this.appId;
  }
  
  /**
   * 设置应用ID
   */
  setAppId(appId: string): PlatformConfig {
    this.appId = appId;
    return this;
  }
  
  /**
   * 是否开启调试
   */
  isDebug(): boolean {
    return this.debug;
  }
  
  /**
   * 设置调试开关
   */
  setDebug(debug: boolean): PlatformConfig {
    this.debug = debug;
    return this;
  }
  
  /**
   * 是否允许流量下载
   */
  getAllowMobileTraffic(): number {
    return this.allowMobileTraffic;
  }
  
  /**
   * 设置是否允许流量下载
   */
  setAllowMobileTraffic(allow: number): PlatformConfig {
    this.allowMobileTraffic = allow;
    return this;
  }
  
  /**
   * 是否开启个性化广告
   */
  isPersonalizedAd(): boolean {
    return this.personalizedAd;
  }
  
  /**
   * 设置个性化广告开关
   */
  setPersonalizedAd(personalized: boolean): PlatformConfig {
    this.personalizedAd = personalized;
    return this;
  }
  
  /**
   * 获取初始化超时时间
   */
  getInitTimeout(): number {
    return this.initTimeout;
  }
  
  /**
   * 设置初始化超时时间
   */
  setInitTimeout(timeout: number): PlatformConfig {
    this.initTimeout = timeout;
    return this;
  }
  
  /**
   * 创建构建器
   */
  static builder(): PlatformConfigBuilder {
    return new PlatformConfigBuilder();
  }
}

/**
 * 平台配置构建器
 */
export class PlatformConfigBuilder {
  private config: PlatformConfig = new PlatformConfig();
  
  /**
   * 设置应用ID
   */
  setAppId(appId: string): PlatformConfigBuilder {
    this.config.setAppId(appId);
    return this;
  }
  
  /**
   * 设置调试开关
   */
  setDebug(debug: boolean): PlatformConfigBuilder {
    this.config.setDebug(debug);
    return this;
  }
  
  /**
   * 设置是否允许流量下载
   */
  setAllowMobileTraffic(allow: number): PlatformConfigBuilder {
    this.config.setAllowMobileTraffic(allow);
    return this;
  }
  
  /**
   * 设置个性化广告开关
   */
  setPersonalizedAd(personalized: boolean): PlatformConfigBuilder {
    this.config.setPersonalizedAd(personalized);
    return this;
  }
  
  /**
   * 设置初始化超时时间
   */
  setInitTimeout(timeout: number): PlatformConfigBuilder {
    this.config.setInitTimeout(timeout);
    return this;
  }
  
  /**
   * 构建平台配置
   */
  build(): PlatformConfig {
    return this.config;
  }
}
