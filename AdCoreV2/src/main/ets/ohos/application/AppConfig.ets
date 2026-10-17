import { commonEventManager } from "@kit.BasicServicesKit";

/**
 * 开屏广告事件处理回调接口
 * @param eventData 公共事件数据
 * @param hasGuide 是否需要显示引导页
 */
export type SplashEventHandler = (eventData: commonEventManager.CommonEventData, hasGuide: boolean) => void;

/**
 * 应用配置类
 * 用于管理应用的基本配置信息
 */
export class AppConfig {
  /**
   * 主页面路径
   */
  private mainPage: string = '';
  
  /**
   * 引导页路径
   */
  private guidePage: string = '';
  
  /**
   * 启动页背景资源
   */
  private launcherBgRes: ResourceStr = '';

  /**
   * 热启动广告等待时间（毫秒）
   */
  private adShowWaitingTime: number = 60000;

  /**
   * 开屏广告事件处理回调接口(HW回调)
   */
  private splashEventHandler: SplashEventHandler | null = null;

  
  /**
   * 获取主页面路径
   * @returns 主页面路径
   */
  getMainPage(): string {
    return this.mainPage;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 设置主页面路径
   * @param mainPage 主页面路径
   * @returns AppConfig实例，支持链式调用
   */
  setMainPage(mainPage: string): AppConfig {
    this.mainPage = mainPage;
    return this;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 获取引导页路径
   * @returns 引导页路径
   */
  getGuidePage(): string {
    return this.guidePage;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 设置引导页路径
   * @param guidePage 引导页路径
   * @returns AppConfig实例，支持链式调用
   */
  setGuidePage(guidePage: string): AppConfig {
    this.guidePage = guidePage;
    return this;
  }
  
  /**
   * 获取启动页背景资源
   * @returns 启动页背景资源
   */
  getLauncherBgRes(): ResourceStr {
    return this.launcherBgRes;
  }
  
  /**
   * 设置启动页背景资源
   * @param launcherBgRes 启动页背景资源
   * @returns AppConfig实例，支持链式调用
   */
  setLauncherBgRes(launcherBgRes: ResourceStr): AppConfig {
    this.launcherBgRes = launcherBgRes;
    return this;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 是否开启华为开屏广告回调
   * @returns 调试开关状态
   */
  getSplashEventHandler(): boolean {
    return this.splashEventHandler!= null;
  }

  /**
   * @deprecated
   * @since 2.0.0
   * 设置开屏广告事件处理回调
   * @param handler 外部传入的事件处理回调
   */
  setSplashEventHandler(handler: SplashEventHandler): AppConfig {
    this.splashEventHandler = handler;
    return this;
  }
  
  /**
   * 获取热启动广告等待时间
   * @returns 热启动广告等待时间（毫秒）
   */
  getAdShowWaitingTime(): number {
    return this.adShowWaitingTime;
  }
  
  /**
   * 设置热启动广告等待时间
   * @param adShowWaitingTime 热启动广告等待时间（毫秒）
   * @returns AppConfig实例，支持链式调用
   */
  setAdShowWaitingTime(adShowWaitingTime: number): AppConfig {
    this.adShowWaitingTime = adShowWaitingTime;
    return this;
  }
  
  /**
   * 创建AppConfig构建器
   * @returns AppConfigBuilder实例
   */
  static create(): AppConfigBuilder {
    return new AppConfigBuilder();
  }
}

/**
 * AppConfig构建器类
 * 用于创建和配置AppConfig实例
 */
export class AppConfigBuilder {
  private config: AppConfig = new AppConfig();
  
  /**
   * @deprecated
   * @since 2.0.0
   * 设置主页面路径
   * @param mainPage 主页面路径
   * @returns AppConfigBuilder实例，支持链式调用
   */
  setMainPage(mainPage: string): AppConfigBuilder {
    this.config.setMainPage(mainPage);
    return this;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 设置引导页路径
   * @param guidePage 引导页路径
   * @returns AppConfigBuilder实例，支持链式调用
   */
  setGuidePage(guidePage: string): AppConfigBuilder {
    this.config.setGuidePage(guidePage);
    return this;
  }
  
  /**
   * 设置启动页背景资源
   * @param launcherBgRes 启动页背景资源
   * @returns AppConfigBuilder实例，支持链式调用
   */
  setLauncherBgRes(launcherBgRes: Resource): AppConfigBuilder {
    this.config.setLauncherBgRes(launcherBgRes);
    return this;
  }
  
  /**
   * @deprecated
   * @since 2.0.0
   * 设置华为开屏广告事件处理回调
   * @param handler 外部传入的回调
   * @returns AppConfigBuilder实例，支持链式调用
   */
  setSplashEventHandler(handler: SplashEventHandler): AppConfigBuilder {
    this.config.setSplashEventHandler(handler);
    return this;
  }
  
  /**
   * 设置热启动广告等待时间
   * @param adShowWaitingTime 热启动广告等待时间（毫秒）
   * @returns AppConfigBuilder实例，支持链式调用
   */
  setAdShowWaitingTime(adShowWaitingTime: number): AppConfigBuilder {
    this.config.setAdShowWaitingTime(adShowWaitingTime);
    return this;
  }
  
  /**
   * 构建AppConfig实例
   * @returns 配置完成的AppConfig实例
   */
  build(): AppConfig {
    return this.config;
  }
}