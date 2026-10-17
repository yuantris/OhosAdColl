import { AdConst } from "../../common/AdConst";
import zyAdvertising from "../../config/zyAdvertising";
import { HttpClient } from "../../network/HttpClient";
import { LogUtil } from "../../util/LogUtil";
import { AdErrorCode } from "./AdErrorCode";
import { AdException } from "./AdException";

/**
 * 广告动作配置接口
 */
export interface AdAction {
  action: string | null;
  btn: string;
  categories: any[] | null;
  className: string | null;
  extra: any | null;
  flags: number;
  packageName: string | null;
  retry: boolean;
  type: number;
  url: string;
}

/**
 * 广告数据结构接口
 */
export interface AdData {
  action: AdAction;
  anim: any | null;
  countdownTime: number;
  createType: number;
  description: string;
  icon: string;
  images: string[];
  rewardTime: number;
  source: string;
  title: string;
  type: number;
}

/**
 * 广告响应类型（广告数组）
 */
type AdResponse = AdData[];

export class AdManager {
  static async requestAd(param: zyAdvertising.ZYAdRequestParams): Promise<AdData[]> {
    try {
      // 参数验证
      if (!param || !param.adId) {
        throw AdException.paramError("缺少必需的adId参数", { param });
      }
      // 获取广告数据
      let adInfo: string;
      try {
        adInfo = await HttpClient.getInstance().get<string>(`${AdConst.BASE_URL}${param.adId}`);
      } catch (error) {
        throw AdException.networkError("网络请求失败", { error, url: `${AdConst.BASE_URL}${param.adId}` });
      }
      LogUtil.debug('AdManager', `原始广告数据：${adInfo}`);

      // 安全地解析JSON字符串
      let adBeans: AdResponse;
      try {
        adBeans = JSON.parse(adInfo) as AdResponse;
      } catch (parseError) {
        throw AdException.parseError("JSON解析失败", { parseError, rawData: adInfo });
      }

      // 验证数据完整性
      if (!Array.isArray(adBeans)) {
        throw AdException.businessError("广告数据不是数组格式", { dataType: typeof adBeans });
      }

      if (adBeans.length === 0) {
        throw new AdException(AdErrorCode.BUSINESS_EMPTY_AD_LIST, "获取到空广告列表");
      }

      // 验证数据有效性
      const validAds = adBeans.filter(ad => {
        const isValid = ad &&
        ad.title &&
        ad.action &&
        ad.action.url &&
        ad.images &&
        Array.isArray(ad.images) &&
          ad.images.length > 0;

        if (!isValid) {
          LogUtil.warn('AdManager', '过滤无效广告数据', ad);
        }
        return isValid;
      });

      if (validAds.length === 0) {
        throw new AdException(AdErrorCode.BUSINESS_INVALID_AD_DATA, "所有广告数据均无效");
      }


      // 随机打乱
      this.shuffleArray(validAds);

      // 过滤广告数据
      const adCount = Math.min(3, Math.max(1, param.adCount || 1));

      if (param.createType !== undefined && param.createType >= 0) {
        // 指定创意类型
        const filteredAds = validAds.filter(ad => ad.createType === param.createType);
        const limitedAds = filteredAds.slice(0, adCount);

        const diff = adCount - limitedAds.length;
        if (diff > 0) {
          // 无法返回足够的创意类型，补充其他类型
          const remainingAds = validAds.filter(ad => ad.createType !== param.createType);
          const supplementAds = remainingAds.slice(0, diff);
          const finalAds = [...limitedAds, ...supplementAds];
          LogUtil.debug('AdManager', `指定创意类型${param.createType}，共${finalAds.length}条广告`);
          return finalAds;
        } else {
          // 返回指定的创意类型
          LogUtil.debug('AdManager', `返回指定创意类型${param.createType}，共${limitedAds.length}条广告`);
          return limitedAds;
        }
      } else {
        // 未指定创意类型
        const finalAds = validAds.slice(0, adCount);
        LogUtil.debug('AdManager', `未指定创意类型，返回${finalAds.length}条广告`);
        return finalAds;
      }
    } catch (error) {
      // 如果是AdException，直接抛出
      if (error instanceof AdException) {
        LogUtil.error('AdManager', `广告异常: ${error.code} - ${error.message}`, error.data);
        throw error;
      }
      // 其他异常转换为AdException
      const adException = AdException.systemError("未知系统错误", { originalError: error });
      LogUtil.error('AdManager', '请求广告失败', adException);
      throw adException;
    }
  }

  /**
   * 获取单个广告（简化版）
   */
  static async requestSingleAd(param: zyAdvertising.ZYAdRequestParams): Promise<AdData | null> {
    try {
      const ads = await AdManager.requestAd(param);
      return ads.length > 0 ? ads[0] : null;
    } catch (error) {
      if (error instanceof AdException) {
        LogUtil.error('AdManager', '获取单个广告失败', error);
      }
      return null;
    }
  }

  /**
   * 安全获取广告字段值
   */
  static getSafeAdValue<T>(ad: AdData, field: keyof AdData, defaultValue: T): T {
    return ad && ad[field] !== undefined ? ad[field] as T : defaultValue;
  }

  /**
   * 获取广告展示信息
   */
  static getAdDisplayInfo(ad: AdData): {
    title: string;
    description: string;
    imageUrl: string;
    targetUrl: string;
    buttonText: string;
  } {
    return {
      title: this.getSafeAdValue(ad, 'title', ''),
      description: this.getSafeAdValue(ad, 'description', ''),
      imageUrl: ad.images?.[0] || ad.icon || '',
      targetUrl: ad.action?.url || '',
      buttonText: ad.action?.btn || '查看详情'
    };
  }

  /**
   * 随机打乱数组（Fisher-Yates算法）
   * @param array 要打乱的数组
   */
  private static shuffleArray<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  /**
   * 处理广告异常
   * @param exception 广告异常
   * @returns 用户友好的错误信息
   */
  static handleAdException(exception: AdException): string {
    if (exception.code === AdErrorCode.NETWORK_ERROR) {
      return "网络连接异常，请检查网络后重试";
    } else if (exception.code === AdErrorCode.BUSINESS_EMPTY_AD_LIST) {
      return "暂无可用广告";
    } else if (exception.code === AdErrorCode.BUSINESS_INVALID_AD_DATA) {
      return "广告数据异常，请稍后重试";
    } else if (exception.code === AdErrorCode.PARSE_JSON_ERROR) {
      return "数据解析失败，请稍后重试";
    } else {
      return "系统繁忙，请稍后重试";
    }
  }
}