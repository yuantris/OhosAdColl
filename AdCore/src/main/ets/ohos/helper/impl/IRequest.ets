import ADUtil, { tryCatch } from "../../util/ADUtil"
import { UIUtil } from "../../util/UIUtil"
import AdConfig from "../ADConfig"
import { ADConstant } from "../ADContant"
import { ADControl } from "../ADControl"
import { onRequestCallback } from "../interface/OnRequestCallback"
import PageConfig from "../PageConfig"
import { IAd } from "./IAd"
import { PageInfo } from "@kit.ArkUI"

const TAG = '[IRequest]'
// 默认重试次数
const RETRY_COUNT = 1
// 默认超时时间
const REQUEST_TIMEOUT = 10000

export abstract class IRequest {
  private _requestId: string
  private _idCount: number
  private _linkIds: string[]
  private _adConfig: AdConfig
  private _page: PageInfo
  private _onRequestCallback: onRequestCallback
  private _retryCount: number = RETRY_COUNT
  private _finished: boolean = false

  protected constructor(requestId: string, count: number, linkIds: string[], adConfig: AdConfig, page: PageInfo,
    onRequestCallback: onRequestCallback) {
    this._requestId = requestId
    this._idCount = count
    this._linkIds = linkIds
    this._adConfig = adConfig
    this._page = page
    this._onRequestCallback = onRequestCallback
  }

  public get requestId(): string {
    return this._requestId
  }

  public get idCount(): number {
    return this._idCount
  }

  public get linkIds(): string[] {
    return this._linkIds
  }

  public get adConfig(): AdConfig {
    return this._adConfig
  }

  public get page(): PageInfo {
    return this._page
  }

  protected abstract request()

  /**
   * 请求成功结果
   * @param iAds
   */
  protected onResult(iAds: IAd<ESObject>[]) {
    // 标记请求结束
    this._finished = true
    ADUtil.logD(TAG, `onResult ${this.linkIds} ${iAds.length}`)
    this._onRequestCallback.onRequested(iAds)
  }

  protected onFail(code: number, error: string) {
    if (this._finished) {
      return
    }
    ADUtil.logE(TAG, `onError ${this.linkIds} ${code} ${error}`, true)
    if (ADControl.isRequestNext(code, error, true) && this._retryCount-- > 0) {
      // 重试
      ADUtil.logE(TAG, `onFail ${this.linkIds} retry`, true);
      this.execute()
    } else {
      // 标记请求结束
      this._finished = true
      this._onRequestCallback.onFailed(code, error)
    }
  }

  public execute() {
    ADUtil.logD(TAG, `execute ${this.linkIds.toString()}`)
    const timeUUID = this.mTimeUUID = ADUtil.getRandomInt(0, Number.MAX_SAFE_INTEGER)
    tryCatch(() => {
      this.request()
    }, () => {
      setTimeout(() => {
        this.timeout(timeUUID)
      }, REQUEST_TIMEOUT)
    })
  }

  private mTimeUUID: number | undefined

  timeout(ms: number) {
    if (this.mTimeUUID !== ms || this._finished) {
      return
    }
    // 标记请求结束
    this._finished = true
    let error = `广告位[${this.linkIds}]，广告ID[${this._adConfig.getId()}]请求${REQUEST_TIMEOUT / 1000}s超时！请检查网络或广告ID配置。`
    this._onRequestCallback.onFailed(ADConstant.AD_ERROR_TIMEOUT, error)
  }
}