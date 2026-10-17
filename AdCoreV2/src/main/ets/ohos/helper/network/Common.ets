import { HttpRequestConfig } from "./OhosRcp"

/**
 * 浅拷贝字符串键值对象（替代受限的 Object.assign）：逐键复制到新 Record
 * @param src 源对象
 * @returns 新的同键值对象
 */
export function cloneRecord<T extends string | number | boolean | null | undefined>(src: Record<string, T>): Record<string, T> {
  const out: Record<string, T> = {}
  const ks: string[] = Object.keys(src)
  for (const k of ks) {
    out[k] = src[k]
  }
  return out
}

/**
 * HttpRequestConfig 浅层结构克隆（替代受限的 Object.assign/对象展开）：
 * params/header/custom/skip/data 克隆一层实现与源对象脱钩，其余字段逐项复制（引用共享）
 * @param src 源配置；缺省时返回全空配置
 * @returns 新配置对象
 */
export function cloneRequestConfig(src?: HttpRequestConfig): HttpRequestConfig {
  const empty: HttpRequestConfig = {}
  const s: HttpRequestConfig = src === undefined ? empty : src
  const out: HttpRequestConfig = {}
  out.url = s.url
  out.method = s.method
  out.baseURL = s.baseURL
  out.timeout = s.timeout
  out.connectTimeout = s.connectTimeout
  out.transferTimeout = s.transferTimeout
  if (s.params !== undefined) {
    out.params = cloneRecord(s.params)
  }
  if (s.header !== undefined) {
    out.header = cloneRecord(s.header)
  }
  out.data = s.data
  out.rawBody = s.rawBody
  out.multipartFields = s.multipartFields
  out.multipartFiles = s.multipartFiles
  out.filePath = s.filePath
  out.name = s.name
  out.responseType = s.responseType
  out.transferRange = s.transferRange
  out.onUploadProgress = s.onUploadProgress
  out.onDownloadProgress = s.onDownloadProgress
  out.tag = s.tag
  out.cancelToken = s.cancelToken
  out.retry = s.retry
  out.raw = s.raw
  if (s.skip !== undefined) {
    out.skip = s.skip.slice()
  }
  if (s.custom !== undefined) {
    // custom 值类型为 ESObject，逐键复制（ESObject 不作泛型实参）
    const srcCustom: Record<string, ESObject> = s.custom
    const newCustom: Record<string, ESObject> = {}
    const cks: string[] = Object.keys(srcCustom)
    for (const ck of cks) {
      newCustom[ck] = srcCustom[ck]
    }
    out.custom = newCustom
  }
  if (Array.isArray(s.data)) {
    // 数组请求体按数组克隆（对象合并会把数组对象化，破坏 JSON 结构）
    out.data = (s.data as ESObject[]).slice()
  } else if (s.data !== undefined && s.data !== null && typeof s.data === 'object') {
    const srcData: Record<string, ESObject> = s.data as Record<string, ESObject>
    const newData: Record<string, ESObject> = {}
    const dks: string[] = Object.keys(srcData)
    for (const dk of dks) {
      newData[dk] = srcData[dk]
    }
    out.data = newData
  }
  return out
}