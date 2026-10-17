import { CSJNativeExpressAd } from "@csj/openadsdk";
import { systemDateTime } from "@kit.BasicServicesKit";
import ADUtil from "../../util/ADUtil";
import ADConfig from "../ADConfig";
import { ADControl } from "../ADControl";
import { NodeController, PageInfo } from "@kit.ArkUI";
import { OnAdListener } from "../interface/OnAdListener";
import PageConfig from "../PageConfig";

function isCsjAd<T>(ad: T): boolean {
  const adAsMyInterface = ad as CSJNativeExpressAd;
  if (adAsMyInterface.getAdComponent() !== undefined && adAsMyInterface.setPrice() !== undefined) {
    return true
  } else {
    return false
  }
}

export abstract class IAd<T> {
  protected static readonly TAG = "IAd"
  /**
   * 广告
   */
  protected mAd: T
  /**
   * 广告失效时间
   */
  private mExpires: number
  /**
   * 被占用的
   */
  private mBusy: boolean = false
  /**
   * 是否已出发展示
   */
  private mShowed: boolean = false
  /**
   * 展示时间
   */
  private mShowTime: number = 0
  /**
   * 是否失效
   */
  private mExpired: boolean = false
  private mPage: PageInfo | undefined
  private mAdConfig: ADConfig | undefined
  private mOnADListener: OnAdListener | undefined

  constructor(ad: T) {
    this.mAd = ad;
    this.mExpires = systemDateTime.getTime() + this.timeout()
    this.bind()
  }

  /**
   * 获取超时时长
   *
   * @return 获取超时时长
   */
  public abstract timeout(): number;

  /**
   * 广告的View
   * @returns
   */
  public abstract view(): NodeController | undefined

  /**
   * 绑定监听事件
   */
  protected abstract bind();

  /**
   * 渲染广告
   */
  public abstract render();

  /**
   * 销毁广告
   */
  public abstract destroy();

  public bindAd(page: PageInfo, adConfig: ADConfig, onADListener?: OnAdListener): boolean {
    if (this.isBusy()) {
      return false
    }

    ADUtil.logD(IAd.TAG, `bindAd() called with: ${adConfig.getLinkADId()}`)
    this.mBusy = true
    if (this.isEnvExpired()) {
      this.mBusy = false
      return false
    }
    this.mPage = page
    this.mAdConfig = adConfig
    this.mOnADListener = onADListener
    // 广告绑定后 无法复用
    this.mShowed = true
    // 渲染
    this.render()
    ADControl.onAdBind(page, adConfig, this)
    if (onADListener) {
      onADListener.onAdRender()
    }
    return true
  }

  protected onRender(): void {
    ADUtil.logD(IAd.TAG, `onRender() called with: ${this.getLinkAdId()}`)
  }

  protected onShow(): void {
    ADUtil.logD(IAd.TAG, `onShow() called with: ${this.getLinkAdId()}`)
    // 标记过期
    this.mExpired = true
    this.mShowTime = new Date().getTime()
    if (this.mPage) {
      ADControl.onAdShow(this.mPage, this.mAdConfig)
    }
  }

  protected onClick(): void {
    ADUtil.logD(IAd.TAG, `onClick() called with: ${this.getLinkAdId()}`)
    let ad: T = this.getAd()
    if (ad) {
      // return typeof ad.someUniqueMethodOrProperty === 'function';
      //TODO 开启广告删除 暂时注释
      // if (isCsjAd(ad)) {
      //   // 穿山甲广告
      // }
    }
    ADControl.onAdClicked(this.mAdConfig!!, this.mPage!!)
  }

  protected onClose(msg?: string) {
    ADUtil.logD(IAd.TAG, `onClose() called with: ${this.getLinkAdId()}`)
    // 标记过期
    this.mExpired = true
    if (this.mPage && this.mAdConfig) {
      ADControl.onAdDislikeClosed(this.mPage, this.mAdConfig)
    }

    if (this.mOnADListener) {
      this.mOnADListener.onAdClose()
      this.mOnADListener = undefined
    }
  }

  public onFlush(): void {
    if (this.mOnADListener) {
      this.mOnADListener.onAdDestroy()
      this.mOnADListener = undefined
    }
  }

  protected onDestroy(): void {
    ADUtil.logD(IAd.TAG, `onDestroy() called with: ${this.getLinkAdId()}`)
    // 标记过期
    this.mExpired = true
    ADControl.onAdDestroy(this.getADConfig()!!, this.getPage()!!)
    this.onFlush()
  }

  protected onFail(code: number, msg: string): void {
    ADUtil.logE(IAd.TAG, `onFail() called with: ${code}, ${msg}`)
    // 标记过期
    this.mExpired = true
    ADControl.onAdFailed(this.getADConfig()!!, this.getPage()!!)
    if (this.mOnADListener) {
      this.mOnADListener.onAdShowError(code, msg)
      this.mOnADListener = undefined
    }
  }


  /**
   * 广告环境是否可用
   */
  isEnvExpired(): boolean {
    // TODO 检测广告环境是否可用
    return false
  }

  isBusy(): boolean {
    if (this.isExpired()) {
      return true
    }
    if (this.mBusy && (this.isEnvExpired())) {
      this.mBusy = false
    }
    return this.mBusy
  }

  isExpired(): boolean {
    if (!this.mExpired && systemDateTime.getTime() >= this.mExpires || this.mShowed) {
      this.mExpired = true
    }
    return this.mExpired
  }

  getAd: () => T = () => {
    return this.mAd
  }

  getPage(): PageConfig | undefined {
    return this.mPage
  }

  getADConfig(): ADConfig | undefined {
    return this.mAdConfig
  }

  getLinkAdId(): string {
    return this.mAdConfig === undefined ? 'NULL' : this.mAdConfig.getLinkADId()
  }
}