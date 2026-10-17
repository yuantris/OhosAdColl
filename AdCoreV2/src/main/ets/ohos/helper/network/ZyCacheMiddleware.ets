import { ZyMiddleware, ZyMiddlewareContext, ZyHttpRequestInternal, zyLog } from '@creative/net';
import { md5Sync, NetBasic } from './NetBasic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';
import { ContextHolder } from '../../application/ContextHolder';

class CacheItem {
  data: ESObject
  expireTime: number

  constructor(data: ESObject, expireTime: number) {
    this.data = data
    this.expireTime = expireTime
  }
}

interface DiskCacheItem {
  url: string
  method: string
  data: ESObject
  expireTime: number
  createTime: number
}

interface DiskCacheFileMeta {
  name: string
  size: number
  mtimeSec: number
}

const CACHE_KEY_FIELD: string = '__cacheKey'
const CACHE_SECONDS_FIELD: string = '__cacheSeconds'

interface CacheKeyIdentity {
  method: string
  url: string
  params: ESObject
  body: ESObject
  tokenSpec: ESObject
}

export class ZyCacheMiddleware implements ZyMiddleware {
  name: string = 'cache'
  private cache: Map<string, CacheItem> = new Map<string, CacheItem>()
  private defaultCacheTime: number = 10
  private lastDiskCleanTime: number = 0
  private static readonly MAX_DISK_CACHE_BYTES: number = 10 * 1024 * 1024
  private static readonly CACHE_KEY_SEP: string = String.fromCharCode(1)

  setDefaultCacheTime(seconds: number): void {
    if (seconds > 0) {
      this.defaultCacheTime = seconds
    }
  }

  getDefaultCacheTime(): number {
    return this.defaultCacheTime
  }

  async onRequest(ctx: ZyMiddlewareContext): Promise<void> {
    const custom = ctx.custom
    const cacheSeconds = this.resolveCacheSeconds(ctx.request.method, custom)
    if (cacheSeconds === undefined) {
      return
    }
    const key = this.generateCacheKey(ctx.request, custom)
    const cachedData: ESObject | null = this.getCache(key)
    if (cachedData !== null) {
      ctx.respond(cachedData)
      return
    }
    if (ctx.request.custom === undefined) {
      ctx.request.custom = {}
    }
    ctx.request.custom[CACHE_KEY_FIELD] = key
    ctx.request.custom[CACHE_SECONDS_FIELD] = cacheSeconds
  }

  async onResponse(ctx: ZyMiddlewareContext): Promise<void> {
    const custom = ctx.request.custom
    if (custom === undefined) {
      return
    }
    const key: ESObject | undefined = custom[CACHE_KEY_FIELD]
    const seconds: ESObject | undefined = custom[CACHE_SECONDS_FIELD]
    if (key === undefined || seconds === undefined) {
      return
    }
    if (ctx.response !== undefined) {
      this.setCache(key as string, ctx.response, seconds as number)
    }
  }

  async onResponseError(ctx: ZyMiddlewareContext): Promise<void> {
  }

  clearMemoryCache(): void {
    this.cache.clear()
    zyLog(hilog.info, '[CACHE] 已清空内存缓存(L1)')
  }

  clearCache(): void {
    this.clearMemoryCache()
    const dir = this.getCacheDir()
    if (!dir) {
      return
    }
    try {
      const files: string[] = fs.listFileSync(dir)
      files.forEach((name: string) => {
        try {
          fs.unlinkSync(`${dir}/${name}`)
        } catch (ignore) {
        }
      })
      zyLog(hilog.info, `[CACHE] 已清空磁盘缓存(L2) ${files.length} 个文件`)
    } catch (e) {
      zyLog(hilog.warn, `[CACHE] 清空磁盘缓存失败: ${e}`)
    }
  }

  getCacheByKey(url: string, method: string, custom?: Record<string, ESObject>): ESObject | null {
    const key = this.buildCacheKey(url, method, custom)
    return this.getCache(key)
  }

  private resolveCacheSeconds(method: string, custom?: Record<string, ESObject>): number | undefined {
    if (custom === undefined) {
      return method === 'GET' ? this.defaultCacheTime : undefined
    }
    const cs: ESObject | undefined = custom['cacheSeconds']
    if (cs !== undefined && typeof cs === 'number' && cs >= 0) {
      return cs
    }
    if (cs === undefined && method === 'GET') {
      return this.defaultCacheTime
    }
    return undefined
  }

  private generateCacheKey(req: ZyHttpRequestInternal, custom?: Record<string, ESObject>): string {
    const url = req.url
    const method = req.method
    let tokenSpec: ESObject = null
    if (custom !== undefined && custom['tokenSpec'] !== undefined) {
      tokenSpec = custom['tokenSpec']
    }
    const params: ESObject = custom !== undefined && custom['params'] !== undefined ? custom['params'] : {}
    const body: ESObject = req.content !== undefined ? req.content : ({} as Record<string, ESObject>)
    const identityObj: CacheKeyIdentity = {
      method: method,
      url: url,
      params: params,
      body: body,
      tokenSpec: tokenSpec
    }
    const identity = ZyCacheMiddleware.stableStringify(identityObj as ESObject)
    return [url, method, identity].join(ZyCacheMiddleware.CACHE_KEY_SEP)
  }

  private buildCacheKey(url: string, method: string, custom?: Record<string, ESObject>): string {
    let tokenSpec: ESObject = null
    if (custom !== undefined && custom['tokenSpec'] !== undefined) {
      tokenSpec = custom['tokenSpec']
    }
    const params: ESObject = custom !== undefined && custom['params'] !== undefined ? custom['params'] : ({} as Record<string, ESObject>)
    const identityObj: CacheKeyIdentity = {
      method: method,
      url: url,
      params: params,
      body: {} as Record<string, ESObject>,
      tokenSpec: tokenSpec
    }
    const identity = ZyCacheMiddleware.stableStringify(identityObj as ESObject)
    return [url, method, identity].join(ZyCacheMiddleware.CACHE_KEY_SEP)
  }

  private getCache(key: string): ESObject | null {
    const parts: string[] = key.split(ZyCacheMiddleware.CACHE_KEY_SEP)
    const url: string = parts[0]
    const method: string = parts[1]

    const cacheItem: CacheItem | undefined = this.cache.get(key)
    if (cacheItem !== undefined) {
      if (Date.now() < cacheItem.expireTime) {
        zyLog(hilog.info, `[CACHE] 内存命中: [${method}] ${url}`)
        return cacheItem.data
      }
      this.cache.delete(key)
    }

    const dir: string | null = this.getCacheDir()
    if (dir !== null) {
      const file: string = `${dir}/${md5Sync(key)}`
      try {
        if (fs.accessSync(file)) {
          const text: string = fs.readTextSync(file)
          const item: DiskCacheItem = JSON.parse(text) as DiskCacheItem
          if (Date.now() < item.expireTime) {
            this.cache.set(key, new CacheItem(item.data, item.expireTime))
            zyLog(hilog.info, `[CACHE] 磁盘命中(持久化): [${method}] ${url}`)
            return item.data
          }
          fs.unlinkSync(file)
        }
      } catch (e) {
        zyLog(hilog.warn, `[CACHE] 磁盘缓存读取失败: ${e}`)
      }
    }
    return null
  }

  private setCache(key: string, data: ESObject, cacheTime: number): void {
    const expireTime: number = Date.now() + cacheTime * 1000
    this.cache.set(key, new CacheItem(data, expireTime))
    this.clearExpiredCache()

    const dir: string | null = this.getCacheDir()
    if (dir === null) {
      zyLog(hilog.warn, '[CACHE] 未注入 Context(setNetContext)，本次缓存仅驻内存，进程退出即失效')
      return
    }
    try {
      const parts: string[] = key.split(ZyCacheMiddleware.CACHE_KEY_SEP)
      const item: DiskCacheItem = {
        url: parts[0],
        method: parts[1],
        data: data,
        expireTime: expireTime,
        createTime: Date.now()
      }
      const file: string = `${dir}/${md5Sync(key)}`
      const f: fs.File = fs.openSync(file, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(f.fd, JSON.stringify(item))
      fs.closeSync(f.fd)
      zyLog(hilog.info, `[CACHE] 已写入持久化缓存: [${parts[1]}] ${parts[0]} (有效期至 ${new Date(expireTime).toLocaleString()})`)
      this.maintainDiskCache(dir)
    } catch (e) {
      zyLog(hilog.warn, `[CACHE] 持久化写入失败: ${e}`)
    }
  }

  private clearExpiredCache(): void {
    const now: number = Date.now()
    this.cache.forEach((cacheItem: CacheItem, key: string) => {
      if (now >= cacheItem.expireTime) {
        this.cache.delete(key)
      }
    })
  }

  private getCacheDir(): string | null {
    const ctx = ContextHolder.getContext()
    if (!ctx) {
      return null
    }
    const dir: string = ctx.cacheDir + '/zy_http_cache'
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true)
      }
      return dir
    } catch (e) {
      zyLog(hilog.warn, `[CACHE] 缓存目录创建失败: ${e}`)
      return null
    }
  }

  private maintainDiskCache(dir: string): void {
    const now: number = Date.now()
    if (now - this.lastDiskCleanTime < 10 * 60 * 1000) {
      return
    }
    this.lastDiskCleanTime = now
    try {
      const files: string[] = fs.listFileSync(dir)
      const metas: DiskCacheFileMeta[] = []
      let totalSize: number = 0
      files.forEach((name: string) => {
        const path: string = `${dir}/${name}`
        try {
          const stat: fs.Stat = fs.statSync(path)
          // 粗筛：mtime 距今超过最大 TTL 的文件必过期，免读内容直接删
          const maxTtlMs = 24 * 60 * 60 * 1000
          if (now - stat.mtime > maxTtlMs) {
            fs.unlinkSync(path)
            return
          }
          const item: DiskCacheItem = JSON.parse(fs.readTextSync(path)) as DiskCacheItem
          if (now >= item.expireTime) {
            fs.unlinkSync(path)
            return
          }
          metas.push({ name: name, size: stat.size, mtimeSec: stat.mtime })
          totalSize += stat.size
        } catch (e) {
          try {
            fs.unlinkSync(path)
          } catch (ignore) {
          }
        }
      })
      if (totalSize > ZyCacheMiddleware.MAX_DISK_CACHE_BYTES) {
        metas.sort((a: DiskCacheFileMeta, b: DiskCacheFileMeta) => a.mtimeSec - b.mtimeSec)
        for (let i = 0; i < metas.length && totalSize > ZyCacheMiddleware.MAX_DISK_CACHE_BYTES; i++) {
          fs.unlinkSync(`${dir}/${metas[i].name}`)
          totalSize -= metas[i].size
        }
        zyLog(hilog.info, `[CACHE] 磁盘缓存超限，已按最旧优先淘汰，当前容量 ${Math.round(totalSize / 1024)}KB`)
      }
    } catch (e) {
      zyLog(hilog.warn, `[CACHE] 磁盘缓存维护失败: ${e}`)
    }
  }

  private static stableStringify(value: ESObject): string {
    if (value === null || value === undefined) {
      return 'null'
    }
    if (typeof value !== 'object') {
      return JSON.stringify(value)
    }
    if (Array.isArray(value)) {
      const items: string[] = (value as ESObject[]).map((v: ESObject) => ZyCacheMiddleware.stableStringify(v))
      return `[${items.join(',')}]`
    }
    const obj: ESObject = value
    const keys: string[] = Object.keys(obj).sort()
    const parts: string[] = keys.map((k: string) =>
      `${JSON.stringify(k)}:${ZyCacheMiddleware.stableStringify(obj[k])}`)
    return `{${parts.join(',')}}`
  }
}
