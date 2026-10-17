import { getPlatformName, PlatformType } from '../../model/PlatformType';
import { AdHub } from '../const/AdHub';
import { LogManager } from '../logger/LogManager';

/**
 * 广告位ID管理类
 * 用于管理广告位字符串到各个平台真实广告ID的映射
 */
export class AdSlotManager {
  /**
   * 日志标签
   */
  private static readonly TAG = 'AdSlotManager';

  /**
   * 单例实例
   */
  private static instance: AdSlotManager | null = null;

  /**
   * 广告位映射表
   * 结构：adSlot -> (platformType -> realAdId)
   */
  private adSlotMap: Map<string, Map<PlatformType, string>> = new Map<string, Map<PlatformType, string>>();

  /**
   * 私有构造函数，防止外部实例化
   */
  private constructor() {
    // LogManager.info(AdSlotManager.TAG, 'AdSlotManager initialized');
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): AdSlotManager {
    if (!AdSlotManager.instance) {
      AdSlotManager.instance = new AdSlotManager();
    }
    return AdSlotManager.instance;
  }

  /**
   * 注册广告位映射
   * @param adSlot 广告位字符串
   * @param platformType 平台类型
   * @param realAdId 真实广告ID
   */
  public registerAdSlot(adSlot: string, platformType: PlatformType, realAdId: string): void {
    if (!adSlot || !realAdId) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.error(AdSlotManager.TAG,
        `registerAdSlot: invalid parameters, adSlot='${adSlot}', platform=${getPlatformName(platformType)}(${platformType}), realAdId='${realAdId}'`);
      return;
    }

    let platformMap = this.adSlotMap.get(adSlot);
    if (!platformMap) {
      platformMap = new Map<PlatformType, string>();
      this.adSlotMap.set(adSlot, platformMap);
    }

    platformMap.set(platformType, realAdId);
    LogManager.info(AdSlotManager.TAG, `registerAdSlot: ${adSlot} -> ${getPlatformName(platformType)} -> ${realAdId}`);
  }

  /**
   * 批量注册广告位映射
   * @param adSlot 广告位字符串
   * @param mappings 平台类型到真实广告ID的映射
   */
  public registerAdSlotMappings(adSlot: string, mappings: Map<PlatformType, string>): AdSlotManager {
    if (!adSlot || !mappings || mappings.size === 0) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.error(AdSlotManager.TAG,
        `registerAdSlotMappings: invalid parameters, adSlot='${adSlot}', mappings=${mappings ? `size=${mappings.size}` : 'null'}`);
      return this;
    }

    mappings.forEach((realAdId, platformType) => {
      this.registerAdSlot(adSlot, platformType, realAdId);
    });

    return this
  }

  /**
   * 根据广告位和平台类型获取真实广告ID
   * @param adSlot 广告位字符串
   * @param platformType 平台类型
   * @returns 真实广告ID，如果没有找到则返回null
   */
  public getRealAdId(adSlot: string, platformType: PlatformType): string | null {
    if (!adSlot) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.error(AdSlotManager.TAG, `getRealAdId: invalid adSlot='${adSlot}', platform=${getPlatformName(platformType)}(${platformType})`);
      return null;
    }

    const platformMap = this.adSlotMap.get(adSlot);
    if (!platformMap) {
      LogManager.error(AdSlotManager.TAG, `getRealAdId: adSlot ${adSlot} not registered`);
      return null;
    }

    const realAdId = platformMap.get(platformType);
    if (!realAdId) {
      LogManager.error(AdSlotManager.TAG,
        `getRealAdId: platform ${getPlatformName(platformType)} not registered for adSlot ${adSlot}`);
      return null;
    }

    LogManager.info(AdSlotManager.TAG, `getRealAdId: ${adSlot} -> ${getPlatformName(platformType)} -> ${realAdId}`);
    return realAdId;
  }

  /**
   * 静默获取真实广告ID（不输出任何日志）
   * 供调试悬浮球等高频轮询场景使用，避免 getRealAdId 的日志刷屏
   * @param adSlot 广告位字符串
   * @param platformType 平台类型
   * @returns 真实广告ID，未注册时返回 null
   */
  public peekRealAdId(adSlot: string, platformType: PlatformType): string | null {
    const platformMap = this.adSlotMap.get(adSlot);
    if (!platformMap) {
      return null;
    }
    return platformMap.get(platformType) ?? null;
  }

  /**
   * 检查广告位是否已注册
   * @param adSlot 广告位字符串
   * @returns 是否已注册
   */
  public isAdSlotRegistered(adSlot: string): boolean {
    return this.adSlotMap.has(adSlot);
  }

  /**
   * 移除指定广告位的映射
   * @param adSlot 广告位字符串
   */
  public removeAdSlot(adSlot: string): void {
    this.adSlotMap.delete(adSlot);
    LogManager.info(AdSlotManager.TAG, `removeAdSlot: ${adSlot}`);
  }

  /**
   * 清空所有广告位映射
   */
  public clearAllAdSlots(): void {
    this.adSlotMap.clear();
    LogManager.info(AdSlotManager.TAG, 'clearAllAdSlots: all ad slots cleared');
  }

  /**
   * 获取所有已注册的广告位
   * @returns 广告位字符串数组
   */
  public getAllAdSlots(): string[] {
    return Array.from(this.adSlotMap.keys());
  }

  /**
   * 更新广告位映射
   * @param adSlot 广告位字符串
   * @param platformType 平台类型
   * @param realAdId 真实广告ID
   */
  public updateAdSlot(adSlot: string, platformType: PlatformType, realAdId: string): AdSlotManager {
    if (!adSlot) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.warn(AdSlotManager.TAG,
        `updateAdSlot: invalid parameters, adSlot='${adSlot}', platform=${getPlatformName(platformType)}(${platformType}), realAdId='${realAdId}'`);
      return this;
    }

    let platformMap = this.adSlotMap.get(adSlot);
    if (!platformMap) {
      platformMap = new Map<PlatformType, string>();
      this.adSlotMap.set(adSlot, platformMap);
    }

    platformMap.set(platformType, realAdId);
    LogManager.info(AdSlotManager.TAG, `updateAdSlot: ${adSlot} -> ${getPlatformName(platformType)} -> ${realAdId}`);

    return this
  }

  /**
   * 更新多个广告位映射
   * @param adSlot 广告位字符串
   * @param mappings 平台类型到真实广告ID的映射
   */
  public updateAdSlotMappings(adSlot: string, mappings: Map<PlatformType, string>): AdSlotManager {
    if (!adSlot || !mappings || mappings.size === 0) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.warn(AdSlotManager.TAG,
        `updateAdSlotMappings: invalid parameters, adSlot='${adSlot}', mappings=${mappings ? `size=${mappings.size}` : 'null'}`);
      return this;
    }

    mappings.forEach((realAdId, platformType) => {
      this.updateAdSlot(adSlot, platformType, realAdId);
    });

    return this;
  }

  /**
   * 更新所有平台的广告ID
   * @param mappings 广告位到平台映射的映射
   */
  public updateAllAdSlots(mappings: Map<string, Map<PlatformType, string>>): void {
    if (!mappings || mappings.size === 0) {
      // 输出实际传入值, 便于定位哪个参数无效
      LogManager.warn(AdSlotManager.TAG,
        `updateAllAdSlots: invalid parameters, mappings=${mappings ? `size=${mappings.size}` : 'null'}`);
      return;
    }

    mappings.forEach((platformMap, adSlot) => {
      this.updateAdSlotMappings(adSlot, platformMap);
    });

    LogManager.info(AdSlotManager.TAG, `updateAllAdSlots: updated ${mappings.size} ad slots`);
  }

  /**
   * 根据广告类型更新所有广告位映射
   * 广告类型字符串，可能的值包括: 'ban', 'info', 'info_left', 'video', 'lscr', 'splash'
   * @param mappings 广告类型到平台映射的映射
   */
  public updateAllAdSlotsByAdType(mappings: Record<string, Map<PlatformType, string>>): void {
    this.getAllAdSlots().forEach(slot => {
      const adType = AdHub.getInstance().getAdTypeByAdId(slot)
      if (adType && mappings[adType]) {
        this.updateAdSlotMappings(slot, mappings[adType])
      }
    })
  }
}
