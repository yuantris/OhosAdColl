import { systemDateTime } from '@kit.BasicServicesKit';
import { NodeController, UIContext } from '@kit.ArkUI';
import { AdConfig } from '../../model/AdConfig';
import { OnAdListener } from '../../interface/OnAdListener';
import { RenderMode } from '../../model/RenderMode';
import { NativeAdMaterial } from '../../model/NativeAdMaterial';

/**
 * 系统组件渲染参数（SYSTEM_COMPONENT 模式）
 */
export interface SystemAdProps {
  ads: object[];
  displayOptions: object;
}

/** 华为 AdComponent 状态回调接收器 */
export interface AdStatusReceiver {
  handleAdStatus(status: string): void;
}

export abstract class IAd<T> {
  protected static readonly TAG = 'IAd';

  protected ad: T;

  private expires: number;
  private showed: boolean = false;
  private expired: boolean = false;
  private displayExpired: boolean = false;
  private adConfig: AdConfig | undefined;
  private onAdListener: OnAdListener | undefined;

  constructor(ad: T) {
    this.ad = ad;
    this.expires = systemDateTime.getTime() + this.timeout();
    // bind 延后到 load 成功后由 attach() 调用，避免构造时广告未就绪
  }

  public abstract timeout(): number;

  /**
   * 获取广告的View控制器（TEMPLATE 模式）
   */
  public abstract view(): NodeController | undefined;

  /**
   * 绑定广告事件（在 attach() 即 load 成功后调用）
   */
  protected abstract bind(): void;

  public abstract render(): void;

  public abstract destroy(): void;

  /**
   * 渲染模式三态，默认 TEMPLATE
   */
  public getRenderMode(): RenderMode {
    return RenderMode.TEMPLATE;
  }

  /**
   * 自渲染素材（SELF_RENDER 模式）
   */
  public getMaterial(): NativeAdMaterial | undefined {
    return undefined;
  }

  /**
   * 系统组件渲染参数（SYSTEM_COMPONENT 模式，华为 AdComponent）
   */
  public getSystemProps(): SystemAdProps | undefined {
    return undefined;
  }

  /**
   * 自渲染交互绑定（SELF_RENDER 模式）
   */
  public bindInteraction(uiContext: UIContext, rootId: string, clickIds: string[], creativeIds?: string[]): void {
    // 模板/系统组件可空实现
  }

  /**
   * 系统组件状态回调转发（华为 AdComponent 等）
   */
  public handleAdStatus(status: string): void {
    // 默认空实现，SYSTEM_COMPONENT 模式覆写
  }


  /**
   * 广告配置
   */
  public setAdConfig(config?: AdConfig): void {
    this.adConfig = config
  }

  /**
   * load 成功后调用：绑定原生事件（替代构造时 bind）
   */
  public attach(): void {
    this.bind();
  }

  /**
   * 设置广告监听器
   */
  public setAdListener(onAdListener?: OnAdListener): void {
    this.onAdListener = onAdListener;
  }

  /**
   * 广告渲染成功时调用
   */
  protected onRender(): void {
    if (this.onAdListener && this.onAdListener.onAdRender) {
      this.onAdListener.onAdRender();
    }
  }

  /**
   * 广告展示成功时调用
   */
  protected onShow(): void {
    this.showed = true;
    if (this.onAdListener && this.onAdListener.onAdShow) {
      this.onAdListener.onAdShow();
    }
  }

  /**
   * 广告点击时调用
   */
  protected onClick(): void {
    if (this.onAdListener && this.onAdListener.onClick) {
      this.onAdListener.onClick();
    }
  }

  /**
   * 广告关闭时调用
   */
  protected onClose(): void {
    this.expired = true;
    this.displayExpired = true;
    if (this.onAdListener && this.onAdListener.onAdClose) {
      this.onAdListener.onAdClose();
    }
    this.onAdListener = undefined;
  }

  /**
   * 广告销毁时调用
   */
  protected onDestroy(): void {
    this.expired = true;
    if (this.onAdListener && this.onAdListener.onAdDestroy) {
      this.onAdListener.onAdDestroy();
    }
    this.onAdListener = undefined;
  }

  /**
   * 广告展示失败时调用
   */
  protected onFail(code: number, msg: string): void {
    this.expired = true;
    if (this.onAdListener && this.onAdListener.onAdShowError) {
      this.onAdListener.onAdShowError(code, msg);
    }
  }


  /**
   * 广告是否失效
   */
  isExpired(): boolean {
    if (!this.expired && systemDateTime.getTime() >= this.expires) {
      this.expired = true;
    }
    return this.expired;
  }

  isDisplayExpired(): boolean {
    return this.displayExpired;
  }

  /**
   * 获取广告实例
   */
  protected getAd(): T {
    return this.ad;
  }

  /**
   * 获取广告配置
   */
  getAdConfig(): AdConfig | undefined {
    return this.adConfig;
  }

  /**
   * 获取广告链接ID
   */
  getLinkAdId(): string {
    return this.adConfig ? this.adConfig.getLinkAdId() : 'NULL';
  }
}
