import { commonEventManager } from '@kit.BasicServicesKit';

/**
 * 开屏广告事件处理回调接口
 * @param eventData 公共事件数据
 * @param hasGuide 是否需要显示引导页
 */
export type SplashEventHandler = (eventData: commonEventManager.CommonEventData, hasGuide: boolean) => void;

/**
 * App配置类
 */
export class AppConfig {
  private _launcherBgRes: ResourceStr
  private _mainPage: string
  private _guidePage: string
  private _splashEventHandler: SplashEventHandler | null

  constructor(builder: AppConfigBuilder) {
    this._launcherBgRes = builder.launcherBgRes
    this._mainPage = builder.mainPage
    this._guidePage = builder.guidePage
    this._splashEventHandler = builder.splashEventHandler
  }

  get launcherBgRes(): ResourceStr {
    return this._launcherBgRes
  }

  get mainPage(): string {
    return this._mainPage
  }

  get guidePage(): string {
    return this._guidePage
  }

  get splashEventHandler(): SplashEventHandler | null {
    return this._splashEventHandler
  }

  /**
   * 创建Builder实例
   */
  static create(): AppConfigBuilder {
    return new AppConfigBuilder()
  }
}

/**
 * 独立的Builder类
 */
class AppConfigBuilder {
  private _launcherBgRes: ResourceStr = ''
  private _mainPage: string = ''
  private _guidePage: string = ''
  private _splashEventHandler: SplashEventHandler | null = null

  setLauncherBgRes(res: Resource): AppConfigBuilder {
    this._launcherBgRes = res
    return this
  }

  setMainPage(page: string): AppConfigBuilder {
    this._mainPage = page
    return this
  }

  setGuidePage(page: string): AppConfigBuilder {
    this._guidePage = page
    return this
  }

  /**
   * 设置开屏广告事件处理回调
   * @param handler 外部传入的事件处理回调
   */
  setSplashEventHandler(handler: SplashEventHandler): AppConfigBuilder {
    this._splashEventHandler = handler
    return this
  }

  build(): AppConfig {
    return new AppConfig(this)
  }

  get launcherBgRes(): ResourceStr {
    return this._launcherBgRes
  }

  get mainPage(): string {
    return this._mainPage
  }

  get guidePage(): string {
    return this._guidePage
  }

  get splashEventHandler(): SplashEventHandler | null {
    return this._splashEventHandler
  }

}