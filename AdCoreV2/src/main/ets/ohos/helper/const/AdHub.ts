import { PlatformType } from "../../model/PlatformType"

export class AdHub {
  private static instance: AdHub | null = null

  private _ban: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()
  private _info: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()
  private _info_left: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()
  private _video: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()
  private _lscr: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()
  private _splash: Map<PlatformType, AdInfo[]> = new Map<PlatformType, AdInfo[]>()

  private constructor() {
  }

  static getInstance(): AdHub {
    if (!AdHub.instance) {
      AdHub.instance = new AdHub()
    }
    return AdHub.instance
  }

  // Getter 方法 - 返回 Map
  get ban(): Map<PlatformType, AdInfo[]> {
    return this._ban
  }

  get info(): Map<PlatformType, AdInfo[]> {
    return this._info
  }

  get infoLeft(): Map<PlatformType, AdInfo[]> {
    return this._info_left
  }

  get video(): Map<PlatformType, AdInfo[]> {
    return this._video
  }

  get lscr(): Map<PlatformType, AdInfo[]> {
    return this._lscr
  }

  get splash(): Map<PlatformType, AdInfo[]> {
    return this._splash
  }

  // Setter 方法 - 设置整个 Map
  set ban(value: Map<PlatformType, AdInfo[]>) {
    this._ban = value
  }

  set info(value: Map<PlatformType, AdInfo[]>) {
    this._info = value
  }

  set infoLeft(value: Map<PlatformType, AdInfo[]>) {
    this._info_left = value
  }

  set video(value: Map<PlatformType, AdInfo[]>) {
    this._video = value
  }

  set lscr(value: Map<PlatformType, AdInfo[]>) {
    this._lscr = value
  }

  set splash(value: Map<PlatformType, AdInfo[]>) {
    this._splash = value
  }

  // 更新方法 - 设置指定平台的广告数据
  updateBan(platform: PlatformType, adInfos: AdInfo[]): void {
    this._ban.set(platform, adInfos)
  }

  updateInfo(platform: PlatformType, adInfos: AdInfo[]): void {
    this._info.set(platform, adInfos)
  }

  updateInfoLeft(platform: PlatformType, adInfos: AdInfo[]): void {
    this._info_left.set(platform, adInfos)
  }

  updateVideo(platform: PlatformType, adInfos: AdInfo[]): void {
    this._video.set(platform, adInfos)
  }

  updateLscr(platform: PlatformType, adInfos: AdInfo[]): void {
    this._lscr.set(platform, adInfos)
  }

  updateSplash(platform: PlatformType, adInfos: AdInfo[]): void {
    this._splash.set(platform, adInfos)
  }

  // 批量更新方法 - 设置所有平台的广告数据
  updateAllBan(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._ban = adInfos
  }

  updateAllInfo(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._info = adInfos
  }

  updateAllInfoLeft(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._info_left = adInfos
  }

  updateAllVideo(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._video = adInfos
  }

  updateAllLscr(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._lscr = adInfos
  }

  updateAllSplash(adInfos: Map<PlatformType, AdInfo[]>): void {
    this._splash = adInfos
  }

  // 获取指定平台的广告数据
  getBanByPlatform(platform: PlatformType): AdInfo[] {
    return this._ban.get(platform) || []
  }

  getInfoByPlatform(platform: PlatformType): AdInfo[] {
    return this._info.get(platform) || []
  }

  getInfoLeftByPlatform(platform: PlatformType): AdInfo[] {
    return this._info_left.get(platform) || []
  }

  getVideoByPlatform(platform: PlatformType): AdInfo[] {
    return this._video.get(platform) || []
  }

  getLscrByPlatform(platform: PlatformType): AdInfo[] {
    return this._lscr.get(platform) || []
  }

  getSplashByPlatform(platform: PlatformType): AdInfo[] {
    return this._splash.get(platform) || []
  }

  // 获取所有平台的广告数据（合并）
  getAllBan(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._ban.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  getAllInfo(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._info.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  getAllInfoLeft(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._info_left.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  getAllVideo(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._video.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  getAllLscr(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._lscr.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  getAllSplash(): AdInfo[] {
    const allAds: AdInfo[] = []
    this._splash.forEach((ads) => {
      allAds.push(...ads)
    })
    return allAds
  }

  // 清空所有广告数据
  clearAll(): void {
    this._ban.clear()
    this._info.clear()
    this._info_left.clear()
    this._video.clear()
    this._lscr.clear()
    this._splash.clear()
  }

  // 清空指定平台的广告数据
  clearPlatform(platform: PlatformType): void {
    this._ban.delete(platform)
    this._info.delete(platform)
    this._info_left.delete(platform)
    this._video.delete(platform)
    this._lscr.delete(platform)
    this._splash.delete(platform)
  }

  // 获取所有平台的广告数量统计
  getAdCount(): Record<string, number> {
    return {
      ban: this.getAllBan().length,
      info: this.getAllInfo().length,
      infoLeft: this.getAllInfoLeft().length,
      video: this.getAllVideo().length,
      lscr: this.getAllLscr().length,
      splash: this.getAllSplash().length
    }
  }

  // 获取指定平台的广告数量统计
  getAdCountByPlatform(platform: PlatformType): Record<string, number> {
    return {
      ban: this.getBanByPlatform(platform).length,
      info: this.getInfoByPlatform(platform).length,
      infoLeft: this.getInfoLeftByPlatform(platform).length,
      video: this.getVideoByPlatform(platform).length,
      lscr: this.getLscrByPlatform(platform).length,
      splash: this.getSplashByPlatform(platform).length
    }
  }

  // 在 AdHub 类中添加以下方法

  /**
   * 根据广告ID查询广告类型
   * @param adId 广告ID
   * @returns 广告类型字符串，可能的值包括: 'ban', 'info', 'info_left', 'video', 'lscr', 'splash'，如果未找到则返回 null
   */
  getAdTypeByAdId(adId: string): string | null {
    // 遍历所有广告类型，查找匹配的 adId
    for (const [platform, adInfos] of this._ban.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'ban'
      }
    }

    for (const [platform, adInfos] of this._info.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'info'
      }
    }

    for (const [platform, adInfos] of this._info_left.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'info_left'
      }
    }

    for (const [platform, adInfos] of this._video.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'video'
      }
    }

    for (const [platform, adInfos] of this._lscr.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'lscr'
      }
    }

    for (const [platform, adInfos] of this._splash.entries()) {
      if (adInfos.some(info => info.adId === adId)) {
        return 'splash'
      }
    }

    return null // 未找到匹配的广告ID
  }

  /**
   * 根据广告ID查询广告信息和类型
   * @param adId 广告ID
   * @returns 包含广告类型和广告信息的对象，如果未找到则返回 null
   */
  getAdInfoByAdId(adId: string): { type: string; adInfo: AdInfo; platform: PlatformType } | null {
    const types = ['ban', 'info', 'info_left', 'video', 'lscr', 'splash'];
    const maps = [this._ban, this._info, this._info_left, this._video, this._lscr, this._splash];

    for (let i = 0; i < types.length; i++) {
      const type = types[i];
      const map = maps[i];

      for (const [platform, adInfos] of map.entries()) {
        const foundAdInfo = adInfos.find(info => info.adId === adId);
        if (foundAdInfo) {
          return {
            type,
            adInfo: foundAdInfo,
            platform
          };
        }
      }
    }

    return null;
  }

}

export class AdInfo {
  private _adId: string
  private _id: string
  private _name: string

  constructor(adId: string = '', id: string = '', name: string = '') {
    this._adId = adId
    this._id = id
    this._name = name
  }

  get adId(): string {
    return this._adId
  }

  set adId(value: string) {
    this._adId = value
  }

  get id(): string {
    return this._id
  }

  set id(value: string) {
    this._id = value
  }

  get name(): string {
    return this._name
  }

  set name(value: string) {
    this._name = value
  }

  update(adId: string, id: string, name: string): void {
    this._adId = adId
    this._id = id
    this._name = name
  }

  clone(): AdInfo {
    return new AdInfo(this._adId, this._id, this._name)
  }

  toString(): string {
    return `AdInfo(adId: ${this._adId}, id: ${this._id}, name: ${this._name})`
  }
}
