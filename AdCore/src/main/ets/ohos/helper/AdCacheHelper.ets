import ADUtil, { tryCatch } from '../util/ADUtil';
import ADConfig from './ADConfig';
import AdConfig, { AdType } from './ADConfig';
import { ADControl } from './ADControl';
import { IAd } from './impl/IAd';
import PageConfig from './PageConfig';
import { InfoRequest } from './request/InfoRequest';
import { PageInfo } from '@kit.ArkUI';
import { getPageName } from '../application/UnifiedRouteEvent';

const TAG = 'AdCacheHelper'
const DELAY_OBTAIN = 50 // 50ms请求防抖
let mObtainUUID = 0

export default class AdCacheHelper {
  private constructor() {
  }

  private static instance = new AdCacheHelper();

  public static getInstance(): AdCacheHelper {
    return AdCacheHelper.instance;
  }

  // 广告Id请求缓存池
  private mCacheIds: Map<string, string[]> = new Map()
  // 广告对象缓存池
  private mCacheIAds: Map<string, IAd<ESObject>[]> = new Map()
  // 广告配置缓存池
  private mCacheConfigs: Map<string, AdConfig> = new Map()
  // 广告回调缓存池
  private mCacheCallback: Map<string, OnAdObtainCallback> = new Map()
  // 正在请求的广告ID
  private mRequest: Set<string> = new Set()

  public obtainAd(config: AdConfig, page: PageInfo, callback: OnAdObtainCallback) {
    ADUtil.logD(TAG, `[${config.getLinkADId()}] obtainAd`)
    let obtainUUID = mObtainUUID = ADUtil.getRandomInt(0, Number.MAX_SAFE_INTEGER)

    let id = config.getId()
    let linkAdId = config.getLinkADId()

    if (this.mCacheCallback.has(linkAdId)) {
      ADUtil.logD(TAG, `[${linkAdId}] obtainAd remove pre callback`)
      this.mCacheCallback.get(linkAdId)?.finish()
      this.mCacheCallback.set(linkAdId, callback)
    } else {
      this.mCacheCallback.set(linkAdId, callback)
      // 添加广告id对应回调
      if (this.mCacheIds.has(id)) {
        let linkIds: string[] = this.mCacheIds.get(id)!!
        let temp: string[] = [...linkIds, linkAdId]
        this.mCacheIds.set(id, temp)
      } else {
        this.mCacheIds.set(id, [linkAdId])
      }
    }

    this.mCacheConfigs.set(linkAdId, config)
    // if (AD.isDEBUG()) {
    //   let stringBuilder: string[] = [];
    //   stringBuilder.push('mAdBeans[');
    //
    //   for (let keysElement of this.mCacheIAds.keys()) {
    //     let values: IAd<ESObject>[] | undefined = this.mCacheIAds.get(keysElement)
    //     if (values !== undefined) {
    //       stringBuilder.push(`${keysElement}:${values.length}, `);
    //     }
    //   }
    //   stringBuilder.push("], mAdCallbacks[");
    //   for (let keysElement of this.mCacheIds.keys()) {
    //     let values: string[] | undefined = this.mCacheIds.get(keysElement)
    //     if (values !== undefined) {
    //       stringBuilder.push(`${keysElement}:${values?.toString()}, `);
    //     }
    //   }
    //   // stringBuilder.push(`], mAdConfigs[${Array.from(mAdConfigs.keys())
    //   //   .join(", ")}], mAdCallback[${Array.from(mAdCallback.keys()).join(", ")}]`);
    //   ADUtil.logD(TAG, `[${config.getLinkADId()}] obtainAd todo ${stringBuilder.join('')}`);
    // }
    setTimeout(() => {
      this.triggerAd(obtainUUID, page)
    }, DELAY_OBTAIN)
  }

  /**
   * 触发广告请求
   * @param obtainUUID
   * @param page
   */
  private triggerAd(obtainUUID: number, page: PageInfo) {
    let trigger: boolean = mObtainUUID === obtainUUID
    ADUtil.logD(TAG, `[ N/A ] triggerAd ${trigger}`)
    if (trigger) {
      // 触发广告请求
      ADUtil.logD(TAG, `[ N/A ] triggerAd ${getPageName(page)} ${this.mCacheIds.size}`)

      for (let entriesElement of this.mCacheIds.entries()) {
        let id: string = entriesElement?.[0]
        let linkIds: string[] = entriesElement?.[1]
        // 判断是否有缓存的广告
        if (this.mCacheIAds.has(id)) {
          ADUtil.logD(TAG, "[ N/A ] triggerAd has temp");
          // 处理广告
          let iAds: IAd<ESObject>[] | undefined = this.mCacheIAds.get(id)
          let usefulAds: IAd<ESObject>[] = []
          let size = iAds?.length ?? 0
          for (let i = size - 1; i >= 0; i--) {
            let ad: IAd<ESObject> | undefined = iAds?.[i]
            if (ad?.isExpired()) {
              iAds?.splice(i, 1)
            } else if (!ad?.isBusy()) {
              if (ad) {
                usefulAds.push(ad)
              }
            }
          }

          // 判断广告缓存是否可用
          if (usefulAds.length === 0) {
            ADUtil.logD(TAG, "[ N/A ] triggerAd no temp");
            this.mCacheIAds.delete(id)
          } else {
            ADUtil.logD(TAG, "[ N/A ] triggerAd has useful temp");
            let offset = 0
            size = usefulAds.length
            for (let i = linkIds.length - 1; i >= 0; i--) {
              let callback = this.mCacheCallback.get(linkIds[i])
              this.mCacheCallback.delete(linkIds[i])
              linkIds.splice(i, 1)
              if (callback?.isFinish()) {
                //已结束、已请求，不在处理
                continue
              }
              callback?.obtain(offset < size ? usefulAds[offset] : usefulAds[0])
            }
            if (iAds) {
              this.mCacheIAds.set(id, iAds)
            }
          }
        }
        // 接下来判断是否需要发起网络请求
        if (linkIds.length === 0) {
          ADUtil.logD(TAG, "[ N/A ] triggerAd no need request ad");
          this.mCacheIds.delete(entriesElement?.[0])
        } else {
          // 最后判断是否发起新的请求
          let value: string[] = entriesElement?.[1]
          let adConfig: AdConfig | undefined = this.mCacheConfigs.get(linkIds[0])
          ADUtil.logD(TAG, `[ N/A ] triggerAd request ad ${id} ${value?.toString()} ${adConfig?.getLinkADId()}`)
          if (adConfig) {
            this.requestAd(Math.min(3, linkIds.length), id, value, adConfig, page)
          }
        }
      }
    }
  }

  /**
   * 请求广告
   * @param count
   * @param id
   * @param linkIds
   * @param adConfig
   * @param page
   */
  private requestAd(count: number, id: string, linkIds: string[], adConfig: AdConfig, page: PageInfo) {
    let contains = this.mRequest.has(id)
    ADUtil.logD(TAG, "[" + adConfig.getLinkADId() + "] requestAd " + contains);
    if (contains) {
      return
    }
    this.mRequest.add(id)
    ADUtil.logD(TAG,
      `[${adConfig.getLinkADId()}] requestAd ${id} ${linkIds.toString()} ${adConfig.getLinkADId()} ${getPageName(page)}`)

    switch (adConfig.getAdType()) {
      case AdType.INFO:
      case AdType.LINFO:
        // 获取广告
        ADUtil.logD(TAG, `开始获取广告`)
        const infoRequest = new InfoRequest(id, count, linkIds, adConfig, page, {
          onRequested(iAds: IAd<ESObject>[]) {
            // 处理请求成功的逻辑
            ADUtil.logD(TAG, `[ N/A ] requestAd onRequested ${iAds.length}`)
            tryCatch(() => {
              AdCacheHelper.instance.onRequested(id, iAds)
            }, () => {
              AdCacheHelper.instance.mRequest.delete(id)
            })
          },
          onFailed(code: number, error: string) {
            // 处理请求失败的逻辑
            ADUtil.logE(TAG, `[ N/A ] requestAd onFailed ${code} ${error}`)
            tryCatch(() => {
              AdCacheHelper.instance.onFailed(id, code, error)
            }, () => {
              AdCacheHelper.instance.mRequest.delete(id)
            })
          }
        })
        // 执行请求
        infoRequest.execute();
        break
      case AdType.BANNER:

        break
    }
  }

  /**
   * 广告请求完成
   * @param id
   * @param ads
   */
  private onRequested(id: string, ads: IAd<ESObject>[]) {
    ADUtil.logD(TAG, "[ N/A ] onRequested " + id + " " + ads.length);
    let size = ads.length
    let linkIds: string[] | undefined = this.mCacheIds.get(id)
    this.mCacheIds.delete(id)
    if (linkIds) {
      ADUtil.logD(TAG, `[ N/A ] onRequested has callbacks ${linkIds?.toString()}`)
      let offset = 0
      for (let linkId of linkIds) {
        let callback = this.mCacheCallback.get(linkId)
        this.mCacheCallback.delete(linkId)
        if (callback?.isFinish()) {
          ADUtil.logD(TAG, '[ N/A ] onRequested has callbacks skip')
          this.mCacheConfigs.delete(linkId)
          continue
        }
        if (offset >= size) {
          offset = 0
        }
        ADUtil.logD(TAG, `[ N/A ] onRequested has callbacks todo ${offset}`)
        let ad: IAd<ESObject> = ads[offset++]
        ADUtil.logD(TAG, `[ N/A ] onRequested has callbacks ${ad?.view()===undefined}`)
        callback?.obtain(ad)
      }
    }

    if (this.mCacheIAds.has(id)) {
      let iAds: IAd<ESObject>[] | undefined = this.mCacheIAds.get(id)
      const temp: IAd<ESObject>[] = new Array(iAds!!.length + ads.length);
      iAds?.forEach((ad: IAd<ESObject>, index) => {
        temp[index] = ad;
      })
      // 将新获取的广告添加到新数组中
      ads.forEach((ad: IAd<ESObject>, index) => {
        temp[iAds!!.length + index] = ad;
      })
      // 更新缓存
      this.mCacheIAds.set(id, temp);
    } else {
      // 如果缓存中没有现有广告，直接将新获取的广告添加到缓存中
      this.mCacheIAds.set(id, ads);
    }
  }

  /**
   * 广告请求失败
   * @param id
   * @param code
   * @param err
   */
  private onFailed(id: string, code: number, err: string) {
    ADUtil.logD(TAG, `[${id}] onFailed ${code} ${err}`)
    if (this.mCacheIds.has(id)) {
      const linkIds: string[] = this.mCacheIds.get(id)!
      this.mCacheIds.delete(id);

      for (const linkId of linkIds) {
        const adConfig: ADConfig | undefined = this.mCacheConfigs.get(linkId);
        const callback: OnAdObtainCallback | undefined = this.mCacheCallback.get(linkId);

        if (adConfig) {
          this.mCacheConfigs.delete(linkId);
          ADControl.onAdRequestFailed(adConfig);
        }

        if (callback) {
          this.mCacheCallback.delete(linkId);
          if (callback.isFinish()) {
            continue;
          }
          callback.onAdFailed(code, err)
        }
      }
    }
  }
}


export abstract class OnAdObtainCallback {
  private mFinish: boolean = false
  private mRequest: boolean = false

  public isFinish(): boolean {
    return this.mFinish
  }

  public finish() {
    this.mFinish = true
  }

  public isRequest(): boolean {
    return this.mRequest
  }

  protected request() {
    this.mRequest = true
  }

  public obtain(ad: IAd<ESObject>) {
    if (this.mFinish) {
      return
    }
    this.finish()
    this.onAdObtained(ad)
  }

  protected fail(code: number, err: string) {
    if (this.mFinish) {
      return
    }
    this.finish()
    this.onAdFailed(code, err)
  }

  public abstract onAdObtained(ad: IAd<ESObject>): void

  public abstract onAdFailed(code: number, err: string): void
}