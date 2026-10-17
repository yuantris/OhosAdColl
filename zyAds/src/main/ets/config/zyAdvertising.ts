import type { ZYAdvertisement as _ZYAdvertisement } from './Advertisement';
import { common } from '@kit.AbilityKit';
import { AdData, AdManager } from '../core/ad/AdManager';
import { AdException } from '../core/ad/AdException';
import { LogUtil } from '../util/LogUtil';

namespace zyAdvertising {
  export type ZYAdvertisement = _ZYAdvertisement


  /**
   * 广告请求参数
   */
  export interface ZYAdRequestParams {
    adId: string // 广告ID
    adType?: number // 广告请求类型
    adCount?: number // 广告数量
    adWidth?: number // 广告宽度
    adHeight?: number // 广告高度
    adSearchKeyword?: string // 广告标志关键词

    // 请求参数的扩展属性
    [key: string]: number | boolean | string | undefined;
  }

  /**
   * 加载广告的广告选项
   */
  export interface ZYAdOptions {
    tagForChildProtection?: number // 子内容标签
    adContentClassification?: string // 广告内容分类设置
    nonPersonalizedAd?: number // 非个性化广告设置

    // 广告选项的扩展属性
    [key: string]: number | boolean | string | undefined;
  }

  /**
   * 广告的展示信息
   */
  export interface ZYAdDisplayOptions {
    customData?: string // 广告个性化数据
    userId?: string // 用户ID
    useMobileDataReminder?: boolean // 指示是否显示对话框，通知用户非Wi-Fi场景下的视频播放
    mute?: boolean // 指示是否将广告视频的播放静音
    audioFocusType?: number // 音频焦点类型

    // 展示选项的扩展属性
    [key: string]: number | boolean | string | undefined;
  }

  /**
   * 广告状态监听
   */
  export interface ZYAdInteractionListener {
    onStatusChanged(status: string, ad: ZYAdvertisement, data: string);
  }

  /**
   * 广告加载监听
   */
  export interface ZYAdLoadListener {
    onAdLoadFailure(errorCode: number, errorMsg: string): void;

    onAdLoadSuccess(ads: Array<ZYAdvertisement>): void;
  }

  /**
   * 展示广告
   * @param ad 广告
   * @param options 展示参数
   * @param context 上下文信息
   */
  function showAd(ad: ZYAdvertisement, options: ZYAdDisplayOptions, context?: common.UIAbilityContext) {

  }

  /**
   * 将AdData转换为ZYAdvertisement
   * @param adData 广告数据
   * @returns ZYAdvertisement对象
   */
  function convertAdDataToAdvertisement(adData: AdData): ZYAdvertisement {
    // 创建唯一ID，可以使用时间戳+随机数
    const uniqueId = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // 从AdData中提取扩展属性
    const extendedProps: Record<string, Object> = {};

    // 将AdData中的字段作为扩展属性
    extendedProps['description'] = adData.description;
    extendedProps['icon'] = adData.icon;
    extendedProps['images'] = adData.images;
    extendedProps['source'] = adData.source;
    extendedProps['action'] = adData.action;
    extendedProps['anim'] = adData.anim;
    extendedProps['countdownTime'] = adData.countdownTime;
    extendedProps['createType'] = adData.createType;
    extendedProps['rewardTime'] = adData.rewardTime;
    extendedProps['title'] = adData.title;

    return {
      adType: adData.type,
      rewardVerifyConfig: new Map<string, string>(), // 初始化空的验证配置
      uniqueId: uniqueId,
      rewarded: false, // 默认未获取奖励
      shown: false, // 默认未展示
      clicked: false, // 默认未点击
      ...extendedProps // 扩展属性
    };
  }

  // 广告加载器
  export class ZYAdLoader {
    constructor(context: common.Context) {
    }

    /**
     * 加载广告
     * @param adParam 广告核心参数
     * @param adOptions 广告设置项
     * @param listener 广告加载监听
     */
    loadAd(adParam: ZYAdRequestParams, adOptions: ZYAdOptions, listener: ZYAdLoadListener) {
      AdManager.requestAd(adParam)
        .then(adData => {
          let ads: ZYAdvertisement[] = [];
          adData.forEach((ad, index) => {
            try {
              const advertisement = convertAdDataToAdvertisement(ad);
              ads.push(advertisement);
              // 记录日志
              LogUtil.info(`广告${index + 1}: ${advertisement.title}`);
            } catch (error) {
              LogUtil.error(`转换第${index + 1}个广告失败:`, error);
            }
          });
          listener.onAdLoadSuccess(ads)

        }).catch((e: AdException) => {
        listener.onAdLoadFailure(e.code, e.message)
      })

    }
  }
}

export default zyAdvertising;