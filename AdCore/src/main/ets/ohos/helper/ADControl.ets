import AdStatus from './AdStatus'
import ADConfig, { AdType, PageType } from './ADConfig'
import ADUtil from '../util/ADUtil'
import { systemDateTime } from '@kit.BasicServicesKit'
import { IAd } from './impl/IAd'
import { ADConstant } from './ADContant'
import { subscribe } from '../components/AdLayout'
import { ADHelper } from './ADHelper'
import { getUniqueID } from '../application/UnifiedRouteEvent'
import { PageInfo } from '@kit.ArkUI'
import { EmitterUtils } from '@zycore/common'

/**
 * 广告控制（dislike后展示控制）
 */
export class ADControl {
  private static readonly TAG = 'ADControl_'
  /**
   * 每次展示
   */
  static readonly AD_CLOSED_SHOW_NEXT = 0
  /**
   * 关闭后本次不再展示（需要传入adId）
   */
  static readonly AD_CLOSED_DO_NOT_SHOW = -1
  /**
   * 关闭后本次不再展示（未传入adId，自动生成adId）
   */
  static readonly AD_CLOSED_DO_NOT_SHOW_BY_STACK_TRACE = -2
  /**
   * 广告关闭模式
   */
  private static AD_CLOSED_MODE = ADControl.AD_CLOSED_DO_NOT_SHOW
  /**
   * 广告状态信息
   */
  private static sAdStatusMap = new Map<string, AdStatus>()
  /**
   * 页面广告信息
   * LinkAdIds
   */
  protected static sPageAdKeepMap = new  Map<string, Set<string>>()

  public static obtainAdStatus(page: PageInfo, adConfigOrLinkAdId: ADConfig | string): AdStatus {
    let linkAdId: string;
    if (typeof adConfigOrLinkAdId === 'string') {
      linkAdId = adConfigOrLinkAdId;
    } else {
      linkAdId = adConfigOrLinkAdId.getLinkADId();
    }

    let adStatus = ADControl.sAdStatusMap.get(linkAdId);
    ADUtil.logE('FyCore_', `adStatusMap: ${adStatus?.getStatus()}`)
    if (adStatus === undefined) {
      adStatus = new AdStatus();
      ADControl.sAdStatusMap.set(linkAdId, adStatus);
    } else if (adStatus.isInit() && getUniqueID(adStatus?.getPage()) !== getUniqueID(page)) {
      adStatus.clearInit();
    }

    if (typeof adConfigOrLinkAdId !== 'string') {
      adStatus.setAdConfig(adConfigOrLinkAdId);
    }

    return adStatus as AdStatus;
  }

  /**
   * 广告展示
   * @param adConfig
   */
  public static onAdShow(page: PageInfo, adConfig: ADConfig | undefined) {
    if (adConfig) {
      switch (adConfig.getPageType()) {
        case PageType.DIALOG:
        case PageType.DIALOG_EXIT:
          if (adConfig.getAdType() === AdType.INFO) {
            if (ADUtil.isNotBlank(adConfig.getADId())) {
              //成功展示，开始计时
              ADControl.obtainAdStatus(page, adConfig).setShowTime(systemDateTime.getTime())
            }
          }
      }
    }
  }

  /**
   * 广告主动关闭
   * @param adConfig
   */
  public static onAdDislikeClosed(page: PageInfo, adConfig: ADConfig) {
    switch (ADControl.AD_CLOSED_MODE) {
      case ADControl.AD_CLOSED_DO_NOT_SHOW:
      case ADControl.AD_CLOSED_DO_NOT_SHOW_BY_STACK_TRACE:
        if (ADUtil.isNotBlank(adConfig.getLinkADId())) {
          ADControl.obtainAdStatus(page, adConfig)
            .setClose(true)
            .clearInit()
          ADUtil.logE(ADControl.TAG, `手动点击关闭广告位= ${adConfig.getLinkADId()}`)
        }
        break
    }
  }

  static sPreIgnore: number = 0

  public static isAdShowNext(page: PageInfo, adConfig: ADConfig): boolean {
    ADUtil.logD(ADControl.TAG, `isAdShowNext() called with: adConfig = [${JSON.stringify(adConfig)}]`)
    // if (ADControl.sPreIgnore>0) {// 刚关闭插屏
    //   ADUtil.logD(ADControl.TAG, `isAdShowNext: 刚关闭插屏`)
    // }
    if (adConfig.getAdType() === AdType.UNKNOWN || adConfig.getPageType() === PageType.UNKNOWN
      || ADUtil.isBlank(adConfig.getLinkADId())) {
      ADUtil.logD(ADControl.TAG, `isAdShowNext: 广告类型未知，直接展示`)
      return true
    }

    if (ADControl.isAdShow(page, adConfig)) {
      ADUtil.logD(ADControl.TAG, `isAdShowNext: 允许发起广告请求`)

      // TODO: 2024/11/11 重复发起广告请求屏蔽
      switch (adConfig.getPageType()) {
        case PageType.NORMAL:
        case PageType.LIST:

          switch (adConfig.getAdType()) {
            case AdType.INFO:
            case AdType.LINFO:
              ADUtil.logD(ADControl.TAG, "isAdShowNext: 广告类型匹配");
              ADUtil.logD(ADControl.TAG, "isAdShowNext: 存在adMap");
              let adStatus = ADControl.obtainAdStatus(page, adConfig)

              if (adStatus.isInit()) {
                switch (adStatus.getStatus()) {
                  case AdStatus.STATUS_SHOWING: // 广告已经展示
                    ADUtil.logD(ADControl.TAG, "isAdShowNext: 广告已经展示")
                    return false
                  case AdStatus.STATUS_REQUEST: // 广告正在请求
                    ADUtil.logD(ADControl.TAG, "isAdShowNext: 广告正在请求")
                    return false
                }
              }
              let uId=getUniqueID(page)
              let adSet = ADControl.sPageAdKeepMap.get(uId)
              if (adSet === undefined) {
                adSet = new Set()
                ADUtil.logE(ADControl.TAG, `sPageAdKeepMap UniqueID(Key) ${uId}`)
                ADControl.sPageAdKeepMap.set(getUniqueID(page), adSet)
              }
              adSet.add(adConfig.getLinkADId())
              adStatus.init(AdStatus.STATUS_REQUEST)
          }

          break
      }

      return true
    }

    switch (adConfig.getPageType()) {
      case PageType.DIALOG:
      case PageType.DIALOG_EXIT:
        if (adConfig.getAdType() === AdType.INFO) {
          // 弹窗广告，不展示广告
          return false
        }
        break
    }

    return false
  }

  private static isAdShow(page: PageInfo, adConfig: ADConfig): boolean {
    ADUtil.logD(ADControl.TAG, "isAdShowNext() called with: adConfig = [" + adConfig + "]");
    // 华为禁止弹窗广告||弹窗广告两分钟只展示一次

    // 判断广告关闭后本次不再展示
    switch (ADControl.AD_CLOSED_MODE) {
      case ADControl.AD_CLOSED_DO_NOT_SHOW:
      case ADControl.AD_CLOSED_DO_NOT_SHOW_BY_STACK_TRACE:
        let forbidden = ADControl.obtainAdStatus(page, adConfig).isClose()
        ADUtil.logD(ADControl.TAG, `isAdShowNext: 广告关闭后本次不再展示 ${forbidden}`)
        if (forbidden) {
          ADUtil.logE(ADControl.TAG, `isAdShowNext: 此广告位已被用户手动关闭= ${adConfig.getLinkADId()}`)
        }
        return !forbidden
    }
    return true

  }

  public static onAdBind(page: PageInfo, adConfig: ADConfig, iAd: IAd<ESObject>) {
    ADUtil.logD(ADControl.TAG,
      `onAdBind() called with: adConfig = [${JSON.stringify(adConfig)}], page = [${JSON.stringify(page)}], iAd = [${iAd}]`)

    let adStatus = ADControl.sAdStatusMap.get(adConfig.getLinkADId())
    if (adStatus != undefined) {
      adStatus.reset({
        page: page,
        adConfig: adConfig,
        ad: iAd,
        status: AdStatus.STATUS_SHOWING
      })
    }
  }

  public static onAdRequestFailed(adConfig: ADConfig) {
    ADUtil.logD(ADControl.TAG, `onAdRequestFailed() called with: adConfig = [${JSON.stringify(adConfig)}]`)
    ADControl.removePageAdKeep(adConfig)
  }

  public static onAdClicked(adConfig: ADConfig, page: PageInfo) {
    ADUtil.logD(ADControl.TAG, `onAdClicked() called with: adConfig = [${JSON.stringify(adConfig)}]`)
    ADControl.removePageAdKeep(adConfig, page)
  }

  public static onAdFailed(adConfig: ADConfig, page: PageInfo) {
    ADUtil.logD(ADControl.TAG, `onAdFailed() called with: adConfig = [${JSON.stringify(adConfig)}]`)
    ADControl.removePageAdKeep(adConfig, page)
  }

  public static onAdDestroy(adConfig: ADConfig, page: PageInfo) {
    ADUtil.logD(ADControl.TAG, `onAdDestroy() called with: adConfig = [${JSON.stringify(adConfig)}]`)
    ADControl.removePageAdKeep(adConfig, page)
  }

  private static removePageAdKeep(adConfig: ADConfig, page?: PageInfo) {
    ADUtil.logD(ADControl.TAG,
      `removePageAdKeep() called with: page = [${getUniqueID(page)}], adConfig = [${JSON.stringify(adConfig)}]`)
    if (!page && !adConfig) {
      return;
    }
    if (!page) {
      ADControl.resetAdStatus(adConfig, page);
      return;
    }
    if (adConfig === undefined) {
      ADControl.resetAdStatusForPage(page);
    } else {
      ADControl.resetAdStatus(adConfig, page);
    }

  }

  private static mShowLscrNextPage = false;
  private static sPageHided: Set<string> = new Set();

  /**
   * 热启动刷新
   */
  public static onSplashAdFlush() {
    ADUtil.logD(ADControl.TAG, "onSplashAdFlush() called");
    ADControl.mShowLscrNextPage = true;
    ADControl.sAdStatusMap.forEach((adStatus) => {
      if (ADUtil.isNotEmpty(adStatus)
        && ADUtil.isNotEmpty(adStatus.getAdConfig())) {
        adStatus.setClose(false)
        adStatus.reset({ status: AdStatus.STATUS_WAIT })
      }
    })

  }

  public static warmLscrShow() {
    if (ADControl.mShowLscrNextPage) {
      // 插屏广告刷新
      ADControl.mShowLscrNextPage = false
      ADHelper.getInstance().showScreenAD()
    }
  }

  public static onPageShow(info: PageInfo) {
    ADUtil.logI(ADControl.TAG, `onPageShow() called with: page = [${JSON.stringify(info)}]`)

    let hideKey = ADControl.getPageUniqueKey(info)
    if (ADControl.sPageHided.delete(hideKey)) {
      let key = ADControl.getKeepPageKeyForConfig(info)
      ADUtil.logD(ADControl.TAG, `onPageShow: called with: pre stop`)
      ADUtil.logE(ADControl.TAG, `onPageShow: called with: key${key}`)
      let adSet = ADControl.sPageAdKeepMap.get(key)
      if (adSet) {
        ADUtil.logD(ADControl.TAG, `onPageShow: called with: find ad ${adSet.size}`)
        adSet.forEach(linkId => {
          ADUtil.logD(ADControl.TAG, `onPageShow: called with: find ad linkId ${linkId}`)

          let adStatus = ADControl.obtainAdStatus(info, linkId)
          ADUtil.logW(ADControl.TAG, `onPageShow: called with: find ad wait ${adStatus.getStatus()}`)
          if (adStatus.isAwait()) {
            switch (adStatus.getAdConfig()?.getAdType()) {
              case AdType.INFO:
              case AdType.LINFO:
                let page = adStatus.getPage()
                let config = adStatus.getAdConfig()
                if (page && config) {
                  let adId = config.getADId()
                  // 触发刷新
                  ADUtil.logE(ADControl.TAG, `触发刷新，正在通知刷新 page===undefined ${page === undefined}`)
                  EmitterUtils.post<number>(subscribe + adId, 1)
                  AppStorage.setAndProp(subscribe + adId, page)
                }
                break
            }
          }
        })
      } else {
        ADUtil.logE(ADControl.TAG, `onPageShow: called with: no adSet ${adSet}`)
      }

    }


  }

  public static onPageHide(info: PageInfo) {
    ADUtil.logD(ADControl.TAG, `onPageHide() called with: page = [${JSON.stringify(info)}]`)
    ADControl.sPageHided.add(ADControl.getPageUniqueKey(info))
  }

  public static onPageDestroy(info: PageInfo) {
    ADUtil.logD(ADControl.TAG, `onPageDestroy() called with: page = [${JSON.stringify(info)}]`)
    const key = ADControl.getPageUniqueKey(info)
    ADControl.sPageHided.delete(key)
    const keepKey = ADControl.getKeepPageKeyForConfig(info)

    let adSet = ADControl.sPageAdKeepMap.get(keepKey)
    if (adSet) {
      adSet.forEach(linkId => {
        ADUtil.logD(ADControl.TAG, `onPageDestroy: called with: clear ${linkId}`)
        ADControl.obtainAdStatus(info, linkId).clearInit()
      })
      adSet.clear()
    } else {
      ADUtil.logW(ADControl.TAG, `onPageDestroy: called with: no adSet ${keepKey}`)
    }
  }

  private static getPageUniqueKey(info: PageInfo): string {
    let id = '';
    if (info?.routerPageInfo) {
      id += info.routerPageInfo.name;
      id += '_';
      id += info.routerPageInfo.path;
    }
    id += '_';
    if (info?.navDestinationInfo) {
      id += info.navDestinationInfo.name;
    }
    return id;
  }

  private static getKeepPageKeyForConfig(info: PageInfo): string {
    return getUniqueID(info)
  }


  private static resetAdStatus(adConfig: ADConfig, page?: PageInfo) {
    try {
      let adStatus = ADControl.sAdStatusMap.get(adConfig.getLinkADId());
      if (adStatus) {
        adStatus.getAd()?.onFlush()
        adStatus.reset({
          page: page,
          adConfig: adConfig,
          status: AdStatus.STATUS_WAIT
        });
      }

    } catch (error) {
      ADUtil.logE(ADControl.TAG, `Error in resetAdStatus: ${error.message}`);
    }
  }

  private static resetAdStatusForPage(page: PageInfo) {
    try {
      if (!page) {
        return;
      }
      let adSet = ADControl.sPageAdKeepMap.get(getUniqueID(page));
      if (adSet) {
        adSet.forEach(linkAdId => {
          let adStatus = ADControl.sAdStatusMap.get(linkAdId);
          adStatus?.reset({
            page: page,
            status: AdStatus.STATUS_WAIT
          });
        });
      }
    } catch (error) {
      ADUtil.logE(ADControl.TAG, `Error in resetAdStatusForPage: ${error.message}`);
    }
  }

  public static isRequestNext(code: number, msg: string, iscsj: boolean) {
    switch (code) {
      case ADConstant.AD_ERROR_TIMEOUT:
        return true
    }
    if (true) {
      // 穿山甲
      switch (code) {
        //            case 20001:    //没有合适的广告返回而导致的请求没有填充,偶现属于正常情况
        //                case 40006:    //代码位ID不合法
        //            case 40016:    //代码位ID与应用ID不匹配或者应用ID缺失
        //                case 40029:    //模板渲染类型广告的请求方法或请求参数不正确
        case 601: //链接建立失败
        case 602: //链接建立超时
        case 603: //广告返回异常
        case 604: //广告解析失败
        case 605: //广告解析失败
        case 606: //广告解析异常
        case 607: //广告读写失败
        case 608: //广告读写失败
        case 609: //广告下载失败
        case 610: //广告下载异常
      //                case 611:    //广告请求被取消
        case 612: //图片加载异常
        case 0: //开屏广告物料加载失败或渲染失败
        case 1: //开屏广告物料加载失败或渲染失败
        case 2: //开屏广告物料加载失败或渲染失败
        case 3: //开屏广告物料加载失败或渲染失败
        case 23: //开屏广告物料加载失败或渲染失败
        case -2: //网络错误
        case -3: //解析数据没有ad
        case -4: //返回数据缺少必要字段
        case -5: //BannerAd加载图片失败
        case -6: //插屏广告图片加载失败
        case -10: //缓存解析失败
        case -11: //缓存过期
        case -12: //缓存中没有开屏广告
          return true;
      }
    } else {
      switch (code) {
        case 3001: //网络异常
        case 3002: //网络超时
        case 3003: //网络不可用，无法连接到服务器
          return true;
      }
    }

    return false
  }
}
