import { AdSlotBuilder, CSJAdCreator, CSJAdSdk, CSJNativeExpressAd, NativeExpressAdListener } from '@csj/openadsdk';
import { UIUtil } from '../../util/UIUtil';
import AdConfig from '../ADConfig';
import { IRequest } from '../impl/IRequest';
import { onRequestCallback } from '../interface/OnRequestCallback';
import { ArrayList } from '@kit.ArkTS';
import ADUtil from '../../util/ADUtil';
import { IAd } from '../impl/IAd';
import { CsjInfoAds } from '../CsjHelper';
import { PageInfo } from '@kit.ArkUI';
import { AD } from '../../config/AD';

let screenWidth: number = UIUtil.getScreenWidthVp()
let screenHeight: number = UIUtil.getScreenHeightVp()
let adWidth: number = Math.round(screenWidth)
let adHeight: number = Math.round(screenHeight)

/**
 * 信息流请求
 */
export class InfoRequest extends IRequest {
  private mAdCreator: CSJAdCreator = CSJAdSdk.getAdCreator()

  constructor(requestId: string, count: number, linkIds: string[], adConfig: AdConfig, page: PageInfo,
    callback: onRequestCallback) {
    super(requestId, count, linkIds, adConfig, page, callback)
  }

  protected request(): void {
    // 创建广告加载监听
    const expressLoadAdListener: NativeExpressAdListener = {
      /**
       * 加载失败的
       *
       * @param code
       * @param message
       */
      onError: (code: number, message: string) => {
        ADUtil.logE('TAG', "info_onError " + code + " " + message)
        this.onFail(code, message)
      },

      /**
       * 广告加载成功的，接入方可以在这个中进行渲染
       *
       * @param ads 返回的广告列表
       */
      onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
        ADUtil.logD('TAG', "onNativeExpressAdLoad " + ads.length)
        if (ADUtil.isEmpty(ads)) {
          this.onFail(-1, "广告为空")
          return
        }
        let adList: IAd<ESObject>[] = []
        for (let ad of ads) {
          adList.push(new CsjInfoAds(ad))
        }
        this.onResult(adList)
      }
    }

    // 创建 AdSlot
    let adSlot = new AdSlotBuilder()
      .setCodeId(this.requestId)
      .setAcceptSize(adWidth, 0)
      .setAdCount(1)
      .build()

    this.mAdCreator.loadExpressFeedAd(adSlot, expressLoadAdListener)
  }
}