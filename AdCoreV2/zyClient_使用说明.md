# zyClient 使用说明

> 更新日期：2026-09-20（对应重构后的建造者模式版本，传统方法已标记 `@deprecated`）

## 1. 概述

`zyClient` 是配套 V2 版本的网络请求库，底层基于鸿蒙 RCP（Remote Communication Platform）实现，上层提供**链式建造者（Builder）** API。对齐 axios 的 API 亲和性与 OkHttp 的能力面，做到"任意请求都支持"。

架构分层：

| 层 | 位置 | 职责 |
|---|---|---|
| HTTP 引擎 | `@creative/net`（OhosRcpNet） | rcp.Session 封装、插件链、重试/取消、multipart/下载、统一 HttpError |
| 业务封装 | `AdCoreV2/.../network/OhosRcp.ts` | 签名插件、两级缓存、ResultDTO\<T\> 解包、RequestBuilder、Mock |

## 2. 功能特点

- **建造者模式**：`zyClient.with()` 链式构建请求，语义清晰、可读性强
- **统一错误模型**：所有失败 reject `HttpError { kind, statusCode?, cause?, config? }`，kind ∈ `network / http / parse / cancel / business / unknown`
- **ResultDTO 自动解包**：`.get<T>()` 直接返回 `data: T`
- **业务 code 统一回调**：登录失效等场景一处拦截
- **插件化拦截器**：`use({ name, onRequest, onResponse, onError })` 可叠加，支持异步
- **纯净请求**：`.raw()` 发一个无签名、无缓存、不解包的"原汁原味" HTTP 请求
- **两级缓存**：L1 内存 → L2 磁盘持久化（key 含 baseURL，10MB LRU 淘汰）
- **控制能力**：重试指数退避、请求取消（Call/tag）、超时细分、GET 并发去重、进度回调
- **传输扩展**：multipart 上传、断点续传下载、proxy/dns/tls 透传
- **Mock**：按规则拦截返回本地数据，测试不依赖后端

## 3. 快速开始

### 3.1 导入

```typescript
// SDK 业务方（经 adCoreV2 转导出）
import zyClient, { ResultDTO, setNetContext, updateBaseUrl } from '@zysdk/ad-core-hm';

// AdCoreV2 模块内部
import zyClient from '../helper/network/OhosRcp';
```

### 3.2 调用 SDK 自有接口（走签名插件）

签名插件（`name='sign'`）自动注入公共参数（a/v/c/r/uuid）、公共头（m/s/s1/p1/o/o1/o2/t1/a1/sv/it），并按 token 规格计算 md5 写入 `params.token`。调用方只需提供 **urlPath + token 规格 + 业务参数**：

```typescript
// 查询类接口（带缓存，秒为单位）
const data = await zyClient.with()
  .urlPath('/zy/v1/app/question/list')   // 相对路径自动拼 baseURL
  .setToken('rtype_sid_aid_vid')         // token 规格（决定签名取哪些字段）
  .addParams(query)                      // 对象批量合并（无需展开运算符）
  .addParams('tags', '1')                // 单个参数
  .cache(30 * 24 * 60 * 60)              // 可选：缓存 30 天
  .post<QuestionResp>()                  // 直接得到 data: QuestionResp（无数据为 null）

// 开关类 POST
const zyoff: ZyOFF | null = await zyClient.with()
  .urlPath(V4[0])
  .setToken(V4[1])
  .post<ZyOFF>()

// 需要额外业务头
await zyClient.with()
  .urlPath(V5[0])
  .addHeader('y', ycid)
  .setToken(V5[1])
  .post<ZyOFF>()

// 要 JSON 字符串而非对象（日志/存储场景，消除类型歧义）
const json = await zyClient.with().urlPath(p).setToken(tk).postText()
```

### 3.3 调用其他接口（第三方 / 不走签名）

```typescript
// 完全纯净请求 .raw()：无签名注入、无缓存、无 ResultDTO 解包，
// 请求体/头/参数完全由调用方掌控，直接返回响应体
const body = await zyClient.with()
  .fullUrl('https://api.other.com/v1/weather/now')  // 绝对 URL 不拼 baseURL
  .raw()
  .get<WeatherResp>()

// 只跳过签名，保留其余默认行为
const data = await zyClient.with().urlPath(p).skip('sign').get<Resp>()

// 换基地址调第三方（仅本次生效，不影响全局 baseUrl）
await zyClient.with()
  .baseUrl('https://api.notify.cn')
  .urlPath('/push/send')
  .raw()
  .bodyJson({ title: 'hi', content: 'msg' })
  .post<PushResp>()

// 表单体 / 原始请求体
await zyClient.with().urlPath(url).raw().bodyForm({ a: 1, b: 'x' }).post()
await zyClient.with().urlPath(url).raw().bodyRaw(jsonStr, 'text/plain').post()
```

> **分界口诀**：SDK 自有接口**不要**加 `.raw()`（要签名注入）；第三方接口**加上** `.raw()`（或 `.skip('sign')`）。

### 3.4 传统方法（已过时）

`zyClient.get/post/put/delete(url, config)` 与 `getWithCache/postWithCache/...` 已标记 `@deprecated`，仅作为 Builder 内部通道保留。IDE 中会显示删除线，新代码请统一使用建造者模式。

## 4. Builder 方法速查

```typescript
zyClient.with('预设名' | 自定义config | 无)
  // ---- 地址与超时 ----
  .urlPath(p)                    // 请求路径（相对 baseURL 或完整 URL）
  .fullUrl(url)                  // 等价 urlPath，语义化表达完整 URL
  .baseUrl(b)                    // 单次覆盖 baseURL（不影响全局）
  .timeout(ms)                   // 单段超时
  .connectTimeout(ms)            // 连接超时（毫秒）
  .transferTimeout(ms)           // 传输超时（毫秒）
  // ---- 参数与头 ----
  .setToken(tk)                  // token 规格（写 custom.tokenSpec，签名插件计算 md5）
  .addParams(k, v | obj)         // 追加参数（对象批量合并）
  .setQuery(k, v | obj)          // 等价 addParams，语义化 query-only
  .addHeader(k, v) / .addHeaders(obj)
  // ---- 请求体 ----
  .body(obj) / .bodyJson(obj)    // JSON 请求体
  .bodyForm(form)                // urlencoded 表单（自动序列化 + content-type）
  .bodyRaw(raw, contentType?)    // string/ArrayBuffer 原样请求体
  .bodyMultipart(fields, files)  // multipart 文本字段 + 文件列表
  // ---- 控制与行为 ----
  .retry(count | { count, delayMs?, maxDelayMs?, retryOn? })
  .tag(tag)                      // 配合 zyClient.cancelTag 批量取消
  .raw()                         // 纯净请求：跳过全部插件/缓存/解包
  .skip('sign', ...)             // 跳过指定插件
  .cache(seconds)                // 缓存时长（秒）
  // ---- 进度 ----
  .onUploadProgress(cb)          // (transferredSize, totalSize) => void
  .onDownloadProgress(cb)
  .transferRange(from?, to?)     // 断点续传范围（配合 downloadTo）
  // ---- 发起 ----
  .get<T>() / .post<T>() / .put<T>() / .delete<T>()   // 返回 data: T
  .getText() / .postText()       // data 的 JSON 字符串
  .request<T>(method)            // 任意 method（HEAD/OPTIONS/PATCH...）
  .upload<T>(filePath, fileKey?) // multipart 上传，返回 data: T
  .downloadTo(folderPath)        // 下载到目录，返回 HttpDownloadResponse
```

### 4.1 `skip()`：按插件名跳过，不只 'sign'

`skip()` 接受任意插件名（变长参数，可同时传多个），按 `zyClient.use()` 注册时的 `name` 匹配：

```typescript
// 当前 SDK 内置注册的插件只有一个：sign（签名 + 公共参数/公共头注入）
.skip('sign')

// 自注册的插件同样可跳过：
zyClient.use({ name: 'track', onRequest: (cfg) => { /* 埋点 */ return cfg } })
.skip('sign', 'track')           // 同时跳过多个
```

- 填了未注册的名字**不报错**，只是匹配不到任何插件，无效果
- `.raw()` 是"跳过全部"的总开关，等价 skip 所有插件（并额外跳过缓存与 ResultDTO 解包）

### 4.2 `with()`：选择基础配置模板

```typescript
with(preset?: string | HttpRequestConfig): RequestBuilder
```

| 传法 | 行为 | 示例 |
|---|---|---|
| 不传 | 用全局默认配置（`baseURL: baseUrl, timeout: 5000`），最常用 | `.with()` |
| 字符串 | 取 `registerPreset` 注册的预设模板，未注册则抛错 | `.with('payApi')` |
| config 对象 | 以该对象作为本次请求的基础模板 | `.with({ header: {...} })` |

预设的价值：一组接口共用一套默认配置时不用每次重复写。

```typescript
// 注册一次（如初始化时）
zyClient.registerPreset('payApi', {
  baseURL: 'https://pay.zyapp.net.cn',
  timeout: 10000,
  header: { channel: 'harmony' }
})

// 之后每次一行带出，链上再覆盖同名字段
await zyClient.with('payApi').urlPath('/order/create').body(order).post<OrderResp>()
```

细节：模板是**复制**进 Builder 的，链式调用只影响本次请求；模板里即使带了 `baseURL`，只要没显式调 `.baseUrl()`，最终仍会由签名插件**实时回填全局最新 baseUrl**（保证 `updateBaseUrl()` 切换环境后预设照样跟随全局），要锁死地址才显式调 `.baseUrl()`。

## 5. 常用能力示例

### 5.1 请求取消（页面销毁联动）

```typescript
// 单请求取消：execute 返回句柄（promise 为完整 HttpResponse，不解包）
const call = zyClient.with().urlPath(p).execute<Resp>('GET')
call.promise.then((resp: HttpResponse<Resp>) => { /* resp.statusCode / resp.data */ })
  .catch((e: HttpError) => { /* e.kind === 'cancel' */ })
call.abort()

// 按 tag 批量取消
zyClient.with().urlPath(p).tag('homePage').get<Resp>()
zyClient.cancelTag('homePage')   // 返回实际取消数
zyClient.cancelAll()             // 取消全部进行中请求
```

### 5.2 重试（指数退避）

```typescript
// 默认仅 network + HTTP 5xx 可重试；cancel/parse 永不重试
await zyClient.with().urlPath(p)
  .retry({ count: 3, delayMs: 500, maxDelayMs: 8000 })
  .get<Resp>()
// retryOn 可自定义可重试类型，如 ['network', 'http']
```

### 5.3 文件上传（multipart + 进度）

```typescript
await zyClient.with()
  .urlPath('/upload')
  .setToken(tk)
  .onUploadProgress((done: number, total: number) => { /* 进度 */ })
  .upload<UploadResp>(filePath, 'file')
```

### 5.4 文件下载（断点续传）

```typescript
const dl = await zyClient.with()
  .fullUrl(fileUrl)
  .onDownloadProgress((done: number, total: number) => { /* 进度 */ })
  .transferRange(1024)              // 可选：从 1024 字节处续传
  .downloadTo(cacheDir + '/pkg')    // 返回 HttpDownloadResponse（含 tempFilePath）
```

### 5.5 统一错误处理

```typescript
try {
  await zyClient.with().urlPath(p).setToken(tk).get<Resp>()
} catch (e) {
  const he = e as HttpError
  switch (he.kind) {
    case 'network':  /* 网络异常 */ break
    case 'http':     /* he.statusCode */ break
    case 'business': /* 业务码被 setBusinessCodeHandler 拦截 */ break
    case 'cancel':   /* 已取消，通常静默 */ break
    case 'parse':    /* 响应解析失败 */ break
    default:         /* unknown */ break
  }
}
```

### 5.6 Mock（测试不依赖后端）

```typescript
// 模拟数据为服务端响应体结构（{ code, message, data }），行为与真实链路一致
zyClient.registerMock({
  match: (url: string, method: string) => url.includes('/question/list'),
  respond: () => ({ code: 0, message: 'ok', data: { list: [] } })
})
zyClient.setMockEnabled(true)   // 总开关（默认关），命中后不发真实请求、不写缓存
zyClient.clearMocks()           // 清空规则
```

### 5.7 插件化拦截器

```typescript
zyClient.use({
  name: 'myPlugin',                    // 配合 .skip('myPlugin') 跳过
  onRequest: (cfg, ctx) => {           // 可异步；前一个输出为下一个输入
    return cfg
  },
  onResponse: (resp, ctx) => resp,
  onError: (err: HttpError, ctx) => err
})
```

### 5.8 原生 RCP 逃生舱（单次使用底层实例）

zyClient 不可能也不必要封装 RCP 全部能力。需要未封装能力时，把底层共享的 `rcp.Session` 抛给上层单次使用，不必为每个能力加包装：

```typescript
// 方式一：直接拿共享 Session 实例
const session: rcp.Session = zyClient.getSession()

// 方式二：回调式单次原生调用（返回值透传）
import { rcp } from '@kit.RemoteCommunicationKit';

const resp = await zyClient.requestNative<rcp.Response>((session: rcp.Session) => {
  const request = new rcp.Request('https://example.com/api', 'POST', headers, content)
  return session.fetch(request)
})

// 典型场景：流式下载（downloadToStream）、流式上传（uploadFromStream）、
// TaskPool 跨线程请求（fetchForSendable）等 Builder 未覆盖的能力
const streamResp = await zyClient.requestNative<rcp.Response>((session) =>
  session.downloadToStream(request, myStream))
```

注意：经逃生舱发出的请求**不经过**插件链（无签名注入）、缓存、日志框与 ResultDTO 解包；但会话与 zyClient 共享（连接复用，`cancelTag/cancelAll` 可取消其请求）。

### 5.9 RCP 尚未封装的能力（按需演进）

以下为 RCP 文档中 Session/Configuration 具备、zyClient 暂未包装的能力（标注起始版本），临时需求走 5.8 逃生舱，高频需求再评估包装：

| 能力 | 说明 | 起始版本 |
|---|---|---|
| 流式传输 | `session.downloadToStream / uploadFromStream`（大文件边收边写、直播流） | 4.1.0(11) |
| 跨线程请求 | `session.fetchForSendable`（TaskPool 子线程发请求） | 5.0.0(12)+ |
| HTTP 请求级缓存 | `Request.cacheControl`（HTTP 协商缓存，可与自研缓存互补） | 6.0.0(20) |
| 会话级 Cookie | SessionConfiguration.cookies / cookieRepository（跨会话共享 Cookie 仓库） | 6.1.0(23) |
| 证书锁定 | SecurityConfiguration.certificatePinning（防中间人） | 5.0.0(12) |
| mTLS 客户端证书 | certificate / certificateEnc（双向认证、国密 TLCP） | 12 / 26 |
| 认证挑战回调 | OnAuthenticationChallenge（401/407 代理与服务器认证自定义处理） | 5.0.0(12) |
| DNS over HTTPS | DnsOverHttpsConfiguration（加密 DNS 防劫持） | 12+ |
| 会话事件监听 | sessionListener（会话取消/关闭事件通知） | 12+ |
| 连接/TCP 细化 | ConnectionConfiguration / TcpConfiguration（连接数、TCP 参数调优） | 12+ |
| 链路追踪 | TracingConfiguration（网络 trace 排查） | 12+ |

> 当前项目 compatible SDK 为 5.0.0(12)，标注更高版本的 API 需升级 SDK 后使用。

## 6. 缓存机制

| 规则 | 说明 |
|---|---|
| 生效范围 | **GET 默认缓存 10 秒**；POST/PUT/DELETE 非幂等不缓存，需显式 `.cache(seconds)` 或 WithCache 方法 |
| 缓存键 | url + method + **baseURL** + data + config（切换环境不会串缓存） |
| 两级结构 | L1 内存 Map（进程内）→ L2 磁盘 `cacheDir/zy_http_cache/<md5>.json`（需先 `setNetContext`） |
| 容量控制 | 磁盘总量上限 10MB，超限按最旧优先淘汰；TTL 过期自动清理 |
| 并发去重 | 同 key GET 进行中时共享同一 Promise（日志 `[CACHE] 并发去重命中(进行中)`） |
| 纯净请求 | `.raw()` 不走缓存 |
| 默认时长 | `zyClient.setDefaultCacheTime(seconds)` 修改（仅 GET 生效） |

命中日志：`[CACHE] 内存命中` / `[CACHE] 磁盘命中(持久化)`，可与真实网络请求明确区分。

## 7. 日志说明

| 控制项 | API | 默认 |
|---|---|---|
| 网络日志总开关 | `setNetLogEnabled(false)` | 开（error 级始终输出） |
| 日志脱敏 | `setNetLogMask(true, keys?)` | 关（默认打码 token/signToken/tk/uid/sid/s1/o/o1/o2） |
| intercept 调试日志 | `setInterceptLogEnabled(bool)` | 关 |
| JSON 格式化 | `ZyNetLogger.setPretty(true)` | 关 |

格式：hilog 域 `ZY_LOG_DOMAIN`，唯一请求 ID（ZyNet#0001、#0002）区分并发，warn 级（黄色）ASCII 框线；输出顺序 baseURL → header → params → body → 签名细节 → response。

## 8. 全局配置 API

```typescript
setNetContext(this.context)      // 注入 Context，启用磁盘持久化缓存（建议 AbilityStage/EntryAbility 调用）
updateBaseUrl('http://...')      // 运行期切换 baseURL（等价 NetBasic.baseUrl = '...'，SSOT 全局生效）
zyClient.registerPreset('name', cfg)   // 注册预设，供 .with('name') 复用
zyClient.setBusinessCodeHandler((code, body) => boolean)
                                 // 每个含 code 的响应解包前回调；false → reject HttpError(kind='business')
                                 // 传 null 取消；适合登录失效统一跳转、黑名单 code 统一弹窗
```

## 9. 注意事项

1. **建造者优先**：传统方法已过时，新代码统一 `zyClient.with()`
2. **缓存单位是秒**：`.cache(60)` 即 60 秒，不要再乘 1000
3. **data 缺失时为 null**：`.get<T>()` 的 data 无值时运行时为 null，调用侧请用可选链兜底
4. **要字符串用 getText/postText**：泛型运行时擦除，库内无法感知 T 是否为 string
5. **token 规格与业务 token**：`setToken()` 传的是签名规格；业务需要原样传 token 时请用 `.raw()` 或 `.skip('sign')`
6. **单请求覆盖 baseURL**：`.baseUrl()` 仅本次生效；全局切换用 `updateBaseUrl()`
7. **错误统一 HttpError**：catch 中按 `kind` 分支处理，不要依赖 BusinessError/Response 混合类型
