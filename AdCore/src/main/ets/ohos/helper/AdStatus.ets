import ADUtil from "../util/ADUtil"
import ADConfig from "./ADConfig"
import AdConfig from "./ADConfig"
import { IAd } from "./impl/IAd"
import PageConfig from "./PageConfig"
import { PageInfo } from "@kit.ArkUI"

export default class AdStatus {
  static readonly STATUS_INIT = -1
  // 请求广告，拦截重复触发
  static readonly STATUS_REQUEST = 0
  // 展示广告，拦截重复触发
  static readonly STATUS_SHOWING = 1
  // 已被点击，待触发展示
  static readonly STATUS_WAIT = 2
  private mStatus = AdStatus.STATUS_INIT
  private mAd: IAd<ESObject> | undefined
  private mPage: PageInfo | undefined
  private mAdConfig: AdConfig | undefined
  /*-----------------------------*/
  private mClose: boolean = false
  private mShowTime: number | undefined

  isInit(): boolean {
    return this.mStatus !== AdStatus.STATUS_INIT
  }

  isAwait(): boolean {
    return this.mStatus === AdStatus.STATUS_WAIT
  }

  init(status: number): void {
    this.mStatus = status
  }

  clearInit(): void {
    this.mStatus = AdStatus.STATUS_INIT
    this.mPage = undefined
  }

  isRequest(): boolean {
    return this.mStatus === AdStatus.STATUS_REQUEST
  }

  getStatus(): number {
    return this.mStatus
  }

  getPage(): PageInfo | undefined {
    return this.mPage
  }

  setPage(page: PageInfo): AdStatus {
    this.mPage = page
    return this
  }

  getAdConfig(): AdConfig | undefined {
    return this.mAdConfig
  }

  setAdConfig(adConfig: AdConfig): AdStatus {
    this.mAdConfig = adConfig
    return this
  }

  getShowTime(): number | undefined {
    return this.mShowTime
  }

  setShowTime(showTime: number): AdStatus {
    this.mShowTime = showTime
    return this
  }

  getAd(): IAd<ESObject> | undefined {
    return this.mAd
  }

  setAd(ad: IAd<ESObject>): AdStatus {
    this.mAd = ad
    return this
  }

  isClose(): boolean {
    return this.mClose
  }

  setClose(close: boolean): AdStatus {
    this.mClose = close
    return this
  }


  reset(options: ResetOptions): AdStatus {
    if (options.page) {
      this.mPage = options.page;
    }
    if (options.adConfig && options.adConfig instanceof ADConfig) {
      this.mAdConfig = options.adConfig;
    }
    if (options.ad && options.ad instanceof IAd) {
      this.mAd = options.ad;
    }
    if (typeof options.status === 'number') {
      ADUtil.logE('', `AdStatus.reset status: ${options.status}`)
      this.mStatus = options.status;
    }
    return this;
  }
}

interface ResetOptions {
  page?: PageInfo;
  adConfig?: ADConfig;
  ad?: IAd<ESObject>;
  status?: number;
}