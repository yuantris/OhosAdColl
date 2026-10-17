import { rcp } from '@kit.RemoteCommunicationKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ZyHttpError } from '../error/ZyHttpError';

/**
 * 官方 HTTP 响应缓存(rcp.ResponseCache)最低 API 版本:
 * 6.0.0(20) 起提供; 本库按 5.0.0(12) 兼容编译时类型仍可见, 但低版本运行时不可创建,
 * 须在运行期按 deviceInfo.sdkApiVersion 门控(编译兼容 ≠ 运行可用)
 */
export const HTTP_CACHE_MIN_API: number = 20;

/**
 * 运行环境是否达到官方 HTTP 缓存最低 API(20)
 * 低版本(如 5.0.0(12) 设备)恒 false, ZyHttpCache 静默降级为无缓存
 * deviceInfo.sdkApiVersion: SDK API 版本号(number), 如 12/20/23
 * @returns true 表示 API >= 20 可创建 rcp.ResponseCache
 */
export function isHttpCacheApiSupported(): boolean {
  const api: number = deviceInfo.sdkApiVersion;
  return Number.isNaN(api) ? false : api >= HTTP_CACHE_MIN_API;
}

/**
 * 缓存过期策略类型(官方 ExpirationPolicy)
 * - never: 永不过期(NeverExpirationPolicy)
 * - absolute: 绝对时间过期(AbsoluteTimeExpirationPolicy, 官方 time 为 Date)
 * - relative: 相对时间过期(RelativeTimeExpirationPolicy, 官方 time 为 TimeInterval)
 * - sliding: 滑动时间过期(SlidingTimeExpirationPolicy, 官方 time 为 TimeInterval)
 */
export interface ZyExpirationPolicy {
  kind: 'never' | 'absolute' | 'relative' | 'sliding';
  /** absolute 策略的过期时间点 */
  expireAt?: Date;
  /** relative/sliding 策略的时间数值(官方 TimeInterval.value) */
  value?: number;
  /** 时间单位(官方 TimeIntervalUnits: 'seconds' | 'minutes' | 'hours' | 'days') */
  units?: 'seconds' | 'minutes' | 'hours' | 'days';
}

/** 缓存状态(官方 CacheState: getState 返回) */
export interface ZyCacheState {
  /** 持久化存储缓存的字节数(Byte) */
  size: number;
  /** 当前持久化存储的缓存数量 */
  count: number;
  /** 缓存命中数 */
  hitCount: number;
}

/** 默认缓存目录(硬编码 entry 模块名; 仅 entry 宿主默认可用, SDK 场景请显式传 pathToFolder) */
const DEFAULT_CACHE_FOLDER: string = '/data/storage/el2/base/entry/temp/ZyHttpCache';

/**
 * HTTP 缓存封装(官方 rcp.ResponseCache, 遵循 RFC 9111)
 * 通过 ZyHttpConfig.cache 挂载到实例会话; 官方 defaultExpirationPolicy 为构造期配置,
 * setExpirationPolicy 采用"保存策略 + 重建实例"方式生效(重建后需重新挂载实例配置)
 *
 * 官方约束: HTTP 缓存自 6.0.0(20) 开始支持; 本工程按 5.0.0(12) 兼容编译,
 * 运行期先 isHttpCacheApiSupported() 门控, 再 try/catch 兜底 → isSupported() 探测
 * API < 20 时恒降级为无缓存, 调用方(AdCore)业务缓存走自建 L1/L2, 不受本类影响
 */
export class ZyHttpCache {
  private cache?: rcp.ResponseCache;
  private policy?: ZyExpirationPolicy;
  private pathToFolder: string;

  /**
   * @param policy 默认过期策略(可选; never/未设置时不传官方默认策略, 由每次请求 Cache-Control 决定)
   * @param pathToFolder 持久化目录(建议传 context.cacheDir + '/ZyHttpCache';
   *                     默认路径硬编码 entry 模块, 仅 entry 宿主可用, SDK 场景应显式传入)
   */
  constructor(policy?: ZyExpirationPolicy, pathToFolder: string = DEFAULT_CACHE_FOLDER) {
    this.pathToFolder = pathToFolder;
    this.policy = policy;
    this.recreate();
  }

  /**
   * 依据当前策略重建底层 ResponseCache(官方 defaultExpirationPolicy 仅构造期可配置)
   * 先按运行时 API 门控(>=20), 再 try/catch 兜底(厂商裁剪/符号缺失等异常路径)
   */
  private recreate(): void {
    if (!isHttpCacheApiSupported()) {
      // API < 20(如 5.0.0(12)): 不创建 ResponseCache, 调用方走业务层自建缓存
      this.cache = undefined;
      return;
    }
    try {
      const config: rcp.CacheConfiguration = {
        persistent: {
          kind: 'file-system',
          pathToFolder: this.pathToFolder
        }
      };
      // 官方 defaultExpirationPolicy 仅接受 TimeLimitedExpirationPolicy(absolute/relative/sliding);
      // never/未设置时不传
      const timeLimited: rcp.TimeLimitedExpirationPolicy | undefined = this.toTimeLimitedPolicy(this.policy);
      if (timeLimited !== undefined) {
        config.defaultExpirationPolicy = timeLimited;
      }
      this.cache = new rcp.ResponseCache(config);
    } catch (err) {
      // API >= 20 但创建失败(目录权限/厂商裁剪等): 静默降级为无缓存
      this.cache = undefined;
    }
  }

  /**
   * ZyNet 过期策略 → 官方 TimeLimitedExpirationPolicy(逐分支构造官方联合类型)
   */
  private toTimeLimitedPolicy(policy?: ZyExpirationPolicy): rcp.TimeLimitedExpirationPolicy | undefined {
    if (policy === undefined || policy.kind === 'never') {
      return undefined;
    }
    if (policy.kind === 'absolute' && policy.expireAt !== undefined) {
      // 官方 AbsoluteTimeExpirationPolicy: { kind: 'absolute', time: Date }
      const absolute: rcp.AbsoluteTimeExpirationPolicy = { kind: 'absolute', time: policy.expireAt };
      return absolute;
    }
    if (policy.kind === 'relative' && policy.value !== undefined) {
      // 官方 RelativeTimeExpirationPolicy: { kind: 'relative', time: TimeInterval }
      const interval: rcp.TimeInterval = { units: policy.units ?? 'seconds', value: policy.value };
      const relative: rcp.RelativeTimeExpirationPolicy = { kind: 'relative', time: interval };
      return relative;
    }
    if (policy.kind === 'sliding' && policy.value !== undefined) {
      // 官方 SlidingTimeExpirationPolicy: { kind: 'sliding', time: TimeInterval }
      const interval: rcp.TimeInterval = { units: policy.units ?? 'seconds', value: policy.value };
      const sliding: rcp.SlidingTimeExpirationPolicy = { kind: 'sliding', time: interval };
      return sliding;
    }
    return undefined;
  }

  /**
   * 探测当前运行环境是否支持 HTTP 缓存(运行时 API >= 20 且实例创建成功)
   */
  isSupported(): boolean {
    return this.cache !== undefined;
  }

  /**
   * 静态探测: 当前设备 API 是否达到官方 HTTP 缓存门槛(不创建实例, 供业务预分支)
   * @returns true 表示 API >= 20
   */
  static isApiSupported(): boolean {
    return isHttpCacheApiSupported();
  }

  /**
   * 取底层 ResponseCache(供 ZyHttpConfig.cache 挂载会话)
   * @returns rcp.ResponseCache; 环境不支持时返回 undefined
   */
  getCache(): rcp.ResponseCache | undefined {
    return this.cache;
  }

  /**
   * 配置默认过期策略(内部通过重建实例生效; 重建后需重新创建 ZyHttp 实例挂载)
   * @param policy 过期策略(如 { kind: 'relative', value: 3, units: 'seconds' })
   * @throws ZyHttpError 环境不支持时抛出
   */
  setExpirationPolicy(policy: ZyExpirationPolicy): void {
    this.policy = policy;
    this.recreate();
    if (this.cache === undefined) {
      throw new ZyHttpError('unknown',
        `当前运行环境不支持HTTP缓存(需API ${HTTP_CACHE_MIN_API}+, 当前${deviceInfo.sdkApiVersion}), 策略未生效`, false);
    }
  }

  /**
   * 查询缓存状态(官方 getState: Promise<CacheState>)
   * @throws ZyHttpError 缓存不可用或查询失败
   */
  async getState(): Promise<ZyCacheState> {
    const cache = this.cache;
    if (cache === undefined) {
      throw new ZyHttpError('unknown',
        `当前运行环境不支持HTTP缓存(需API ${HTTP_CACHE_MIN_API}+, 当前${deviceInfo.sdkApiVersion})`, false);
    }
    try {
      const state: rcp.CacheState = await cache.getState();
      const result: ZyCacheState = {
        size: state.size,
        count: state.count,
        hitCount: state.hitCount
      };
      return result;
    } catch (err) {
      throw new ZyHttpError('unknown', '查询缓存状态失败', false, undefined, undefined, err);
    }
  }
}
