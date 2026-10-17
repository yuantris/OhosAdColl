# ZyNet 网络库现状与升级路线

> 覆盖范围：`OhosRcpNet`（底层 HTTP 引擎，基于 RCP）+ `AdCoreV2/.../network/OhosRcp.ts`（业务封装层：签名/缓存/ResultDTO/构建者模式）
> 整理日期：2026-09-20

---

## 一、`dataType: 'json'` 是什么意思？

```typescript
const config: HttpRequestConfig = {
  baseURL: baseUrl,
  timeout: 5000,
  dataType: 'json'   // ← 这里
}
```

- **语义**：来自 axios / uni.request 的遗留配置，含义是"期望响应为 JSON，收到响应后做一次 `JSON.parse`"。
- **在当前实现中的真实状态：已从类型删除**。`request.ts` 的响应处理按 `responseType` 分派：`arraybuffer` → `response.arrayBuffer()`；`text` → `response.toString()`；缺省 → `response.toJSON()`；解析失败抛 `HttpError kind='parse'`。
- **正常网络请求这么写吗？** 现代网络库（axios 1.x、RCP、OkHttp）默认就按 JSON 处理响应，不需要显式声明。保留它无害但有误导性——让人以为"不写就不是 json"。

**处理**：已从 `HttpRequestConfig` 类型删除。真有 text/arraybuffer 需求时用 `responseType`。

---

## 二、当前架构总览

| 文件 | 职责 |
|---|---|
| `OhosRcpNet/request.ts` | HTTP 引擎：rcp.Session 封装、请求拦截器、fullUrl 构建、响应解析、HttpPromise |
| `OhosRcpNet/logger.ts` | 日志体系：zyLog（hilog 明文输出）、ZyNetLogger 请求日志框（#ID/耗时/pretty JSON/warn 框线） |
| `OhosRcpNet/Index.d.ts` | 类型声明：HttpRequestConfig、HttpResponse、HttpPromise、ZyNetLogger 等 |
| `OhosRcp.ts`（AdCoreV2） | 业务封装：签名拦截器（md5 token）、持久化缓存（L1 内存 + L2 磁盘）、ResultDTO\<T\> 自动解包、RequestBuilder 链式构建、setNetContext/updateBaseUrl |

**已实现能力**：请求日志框（并发 #ID 区分）、intercept 调试日志开关、全局/单次 baseURL 切换、SSOT 化 baseURL、内存+磁盘两级 TTL 缓存、ResultDTO 自动解包、RequestBuilder 链式 API、预设（registerPreset）、签名 token、hilog 全量迁移。

### 能力现状矩阵（"任意请求都支持"视角）（历史快照，现状见第六节）

| 能力 | 现状 | 说明 |
|---|---|---|
| 自定义完整 URL（绕过 baseURL） | ✅ 支持 | `buildFullPath` 采用 axios 语义：`isAbsoluteURL(url)` 为真时直接使用该 URL，不拼接 baseURL。`.urlPath('http://other.host/api')` 或 `post('http://...')` 均可。 |
| 单次覆盖 baseURL | ✅ 支持 | Builder `.baseUrl()` / 单次 config.baseURL |
| 跳过默认 params（token/a/v/c/r/uuid） | ❌ 不支持 | 签名拦截器对**所有**请求无条件注入，且会用签名 token **覆盖**业务传入的 token |
| 跳过默认 header（m/s/s1/p1/o/t1/sv 等） | ❌ 不支持 | 同上，无开关 |
| 变通方案 | ⚠️ 不友好 | `new HttpRequest()`（底层类直接实例化）不带签名拦截器，可发"纯净请求"，但这是内部实现细节，无文档、无默认配置、不推荐业务使用 |
| 任意 HTTP method | ✅ 支持 | get/post/put/delete + config.method 直传（CONNECT/HEAD/OPTIONS 等透传） |
| 表单编码（form-urlencoded） | ❌ 未封装 | 可手拼 body 字符串，无 API |
| multipart 文件上传 | ❌ 未封装 | RCP 原生 `rcp.Form` 能力未暴露 |
| 请求取消 | ❌ 不支持 | 无 abort 句柄 |
| 重试 | ❌ 不支持 | — |

**结论**：完整 URL 与任意 method 已支持；**"纯净请求"（跳过默认头/参数）是当前最大缺口**——签名注入是强制的且会改写业务 token，无法按请求关闭。

---

## 三、现存问题（按优先级）

### P0 — Bug / 高风险

| # | 问题 | 位置 | 说明 |
|---|---|---|---|
| 1 | **缓存 key 不含 baseURL** | `generateCacheKey` | key = `url + method + data + 单次config`。切换 `NetBasic.baseUrl`（如测试环境→正式环境）后 key 不变，会**命中旧环境的缓存**。应把实际使用的 baseURL 纳入 key。 |
| 2 | **POST 默认缓存 10 秒** | `post()` / `get()` 等普通方法 | 非幂等方法默认走缓存，登录、下单、点赞类接口 10 秒内重复提交会被吞掉返回旧数据。语义上只有 GET 才适合默认缓存；POST 必须显式 opt-in（`postWithCache` / Builder `.cache()`）。 |
| 3 | **磁盘缓存无容量上限** | `zy_http_cache` | 只有 TTL 过期清理，没有 LRU/总量上限。接口数量持续增长时磁盘占用无限膨胀（虽然 cacheDir 系统可回收，但不可依赖）。 |

### P1 — 设计缺陷

| # | 问题 | 说明 |
|---|---|---|
| 4 | 错误类型不统一 | validateStatus 失败时 `reject(response)`（原始 Response），网络异常时 `reject(err)`（BusinessError），业务侧 `.catch((e: BusinessError)` 实际可能收到 Response。应统一为 `HttpError { code, message, statusCode, config, isNetworkError }`。 |
| 5 | 拦截器不可组合 | 只有单个 `requestInterceptor.onFulfilled` 同步钩子，不支持链式数组、异步拦截器、响应拦截器。签名/埋点/统一错误处理无法解耦叠加。 |
| 6 | 无重试机制 | 网络抖动、弱网瞬时失败直接抛给业务，SDK 场景（广告请求）对成功率敏感，需要可配置重试 + 指数退避。 |
| 7 | 无请求取消 | 未暴露 abort 能力，页面销毁后回调仍会执行（可能操作已销毁的 UI）。 |
| 8 | `timeout` 单值 | 连接超时与传输超时未分离（RCP 原生支持 connect/transfer 两段）。 |
| 9 | 敏感信息日志无环境开关 | 请求框会打印 token/dtoken/uid 明文。`intercept` 有开关了，但**主日志框常开**，release 包需要静默或脱敏。 |
| 10 | 模块级可变单例 config | `const config = { baseURL: baseUrl, ... }` 是共享可变对象，多处直接引用/修改，存在状态串扰风险。 |

### P2 — 可优化

| # | 问题 | 说明 |
|---|---|---|
| 11 | `ESObject` 泛滥 | 库内 .ts 虽不受 ArkTS 约束，但 ESObject ≈ any，调用侧拿到的是"裸数据"。HttpResponse\<T\>、缓存读写都可收紧为泛型/`Record<string, Object>`。 |
| 12 | params 序列化弱 | 嵌套对象、数组参数（`ids=[1,2]`）序列化策略未定义（brackets/repeat/json 三种风格）。 |
| 13 | 同 URL 并发去重缺失 | 快速翻页/重复点击会发出多个相同请求，可合并 in-flight 请求共享同一 Promise。 |
| 14 | 缓存方法语义混乱 | `postWithCache` 的 cacheTime 按毫秒、Builder `.cache()` 按秒，两套单位并存。 |
| 15 | 业务 code 无统一拦截 | ResultDTO 解包后不校验 code，"登录已失效"（code 4004）等场景每个调用方各自处理；应由响应拦截器统一回调。 |

---

## 四、RCP 原生能力（当前未利用）

| 能力 | 说明 | 适用场景 |
|---|---|---|
| 多级异步拦截器 | `rcp.Interceptor` 支持 `async intercept(context, next)`，可叠加 | 重试、埋点、统一错误、mock |
| Cookie 自动管理 | Session 级 `automaticCookieManagement` + 手动 CookieManager | 登录态维持 |
| 连接/传输超时分离 | `connectTimeout` / `transferTimeout` | 弱网精细化控制 |
| 请求级 configuration | 每个请求可覆盖 Session 配置 | 单请求代理、超时 |
| 下载到文件 / Range | `downloadTo`、`transferRange` 断点续传 | 升级包、资源下载 |
| multipart 上传 | `rcp.Form` 表单/文件上传 | 头像、附件 |
| 流量统计 | TrafficStats 会话/请求级收发字节数 | 成本监控、埋点 |
| 自定义 DNS 解析 | 自定义 DnsResolver | HTTPDNS 防劫持 |
| TLS 定制 | 自定义 CA、客户端证书（mTLS）、证书校验策略 | 自签测试环境、安全通道 |
| HTTP 原生缓存 | Session 配置 HTTP 缓存策略 | 与自研缓存互补（协商缓存 304） |

---

## 五、升级路线图

### 短期（修 bug + 收紧语义）

1. 缓存 key 纳入 baseURL；非 GET 方法默认不缓存，仅显式 opt-in。
2. 统一 `HttpError` 错误模型，`catch` 里永远是同一结构。
3. 磁盘缓存加总量上限（如 10MB）+ LRU 淘汰。
4. 日志加 release 开关（结合 `BuildProfile.ets` 的 DEBUG 标记自动静默），token/uid 脱敏（打码中间段）。
5. 删除/弃用 `dataType`（已从类型删除）；统一缓存时间单位（秒）。

### 中期（架构升级）

6. **拦截器链改造**：`use(请求拦截) / use(响应拦截)`，支持异步；签名、token 失效统一跳转、埋点全部迁移为独立拦截器插件。
7. **重试器**：`retry: { count, backoff, onMethods: ['GET'] }`，指数退避，可按错误类型（网络错误重试 / 4xx 不重试）。
8. **请求取消**：Builder 增加 `abortSignal()` 或返回句柄 `.abort()`，页面销毁时联动取消。
9. **并发去重**：相同 cacheKey 的 in-flight 请求共享 Promise。
10. 类型系统收紧：HttpResponse\<T\> 泛型贯通，逐步消除 ESObject（对外 .d.ts 优先）。

### 长期（能力扩展）

11. 文件上传/下载封装（进度回调、断点续传），服务升级包下载复用。
12. HTTPDNS（自定义 DnsResolver）+ 证书校验策略，防劫持与安全加固。
13. 流量统计 + 耗时分解（连接/TTFB/传输）接入 APM 埋点上报。
14. Mock 层：MockInterceptor 支持按 URL/规则返回固定数据，便于 UI 联调与自动化测试。
15. 协商缓存：ETag/If-None-Match + 304 与本地磁盘缓存打通，长列表接口省流量。
16. 环境配置中心化：`NetBasic` 管理多环境（dev/test/prod）baseURL/超时/开关矩阵，支持远程下发切换。

---

## 六、成熟网络库目标（重构蓝图）— 已于 2026-09-20 落地

> 目标：zyClient 达到"任意请求都支持"的成熟度，对齐 axios（API 亲和）/ OkHttp（能力面）/ RuoYi-Retrofit（业务层）的主流体验。下表为重构完成后的实际落地状态。

### 6.1 请求描述能力（任意请求都能发）

| 能力 | 实现 | 状态 |
|---|---|---|
| 完整 URL / 相对路径 | axios 语义保留（绝对 URL 直接用）；Builder `.fullUrl()` 显式表达 | ✅ |
| **纯净请求开关** | Builder `.raw()`：跳过全部插件注入（签名/公共参数/公共头）、缓存与 ResultDTO 解包，发"原汁原味"的 HTTP 请求 | ✅ |
| 默认注入可选化 | 签名等拆为独立插件（`name='sign'`）；请求级 `.skip('sign', ...)` 精细跳过，实时判定 | ✅（实例级 disable 插件待需再补） |
| 业务 token 不被覆盖 | `Builder.setToken()` 写 `custom.tokenSpec`（不再占用 params.token）；签名插件据此计算 md5；raw/skip('sign') 时业务值完整保留 | ✅ |
| 任意 method | Builder `.request(method)` 直传（自动转大写，HEAD/OPTIONS/PATCH 等均支持） | ✅ |
| 多种 body 格式 | `.bodyJson(obj)` / `.bodyForm(urlencoded)` / `.bodyMultipart(fields, files)` / `.bodyRaw(string|ArrayBuffer, contentType)` | ✅ |
| query 与 body 分离 | `.setQuery()` 只拼 URL（等价 addParams）、`.body()` 只进体 | ✅ |
| 字符集/内容类型 | header/content-type 完全自定义；插件注入前克隆配置不污染调用方原对象 | ✅ |

### 6.2 控制能力（成熟库标配）

| 能力 | 实现 | 状态 |
|---|---|---|
| 请求取消 | Builder `.execute<T>(method)` 返回 `Call<T>{promise, abort}`；实例级 `zyClient.cancelTag(tag)` / `cancelAll()` 批量取消 | ✅ |
| 超时细分 | `.connectTimeout(ms)` / `.transferTimeout(ms)`，未设置时单段 `timeout` 生效 | ✅ |
| 重试 | `.retry(count \| RetryConfig)`：指数退避（delayMs×2ⁿ 封顶 maxDelayMs），默认仅 network+5xx 可重试，cancel/parse 永不重试 | ✅ |
| 并发控制 | GET 同 key in-flight 去重（get/getWithCache 共享索引，进行中请求共享同一 Promise） | ✅（全局并发上限队列待需再补） |
| 拦截器插件化 | `zyClient.use({name, onRequest?, onResponse?, onError?})` 链式叠加（支持异步）；插件异常不中断请求 | ✅ |
| 统一错误模型 | 所有失败统一 `HttpError{kind, statusCode?, cause?, config?}`，kind ∈ network/http/parse/cancel/business/unknown | ✅ |
| 回调生命周期 | `.onUploadProgress(cb)` / `.onDownloadProgress(cb)`（transferredSize, totalSize） | ✅ |
| 重试可观测 | `retry.onRetry(attempt, error, delayMs)`：sleep 前回调；不重走插件链（重试复用首次已签名的同一 rcp.Request） | ✅ |

### 6.3 传输扩展

| 能力 | 实现 | 状态 |
|---|---|---|
| 文件上传 | `.bodyMultipart(fields, files)` 或 `.upload(filePath, fileKey)`（multipart + onUploadProgress 进度） | ✅ |
| 文件下载 | `.downloadTo(folderPath)` + `.transferRange(from, to)` 断点续传 + 进度回调 | ✅ |
| 流式响应 | RCP 当前不支持 SSE/chunked 回调，关注版本演进 | ⏸ |
| DNS/TLS 定制 | config 透传 `proxy` / `dns` / `tlsOptions`（含 `sslVerify:false` 跳过校验、TlsV12Option 等），HTTPDNS 由业务侧实现 DnsResolver 注入 | ✅ |

### 6.4 数据层

| 能力 | 实现 | 状态 |
|---|---|---|
| ResultDTO 可选解包 | `.raw()` 跳过解包；`zyClient.setBusinessCodeHandler((code, body) => boolean)` 解包前统一校验业务码，返回 false 时 reject `HttpError(kind='business')`（登录失效全局跳转等） | ✅ |
| 缓存体系 | key 含 baseURL（环境切换不串缓存）；GET 默认缓存、写请求显式 opt-in（WithCache/Builder.cache()）；单位统一秒；磁盘 LRU 上限 10MB 最旧优先淘汰 | ✅（ETag 协商缓存缓后：SDK 12 无 ResponseCache，自实现成本高） |
| Mock | `zyClient.registerMock({match(url, method), respond()})` + `setMockEnabled(true)`：命中不发真实请求，模拟数据为服务端响应体结构，行为与真实链路一致（业务码校验同样生效） | ✅ |
| 类型安全 | 对外 API 全泛型化（`get<T>()` 返回 data 类型）；调用侧无 ESObject；内部实现保留 ESObject（.ts 不受 ArkTS 约束） | ✅ |

---

## 七、重构后 API 速查

```typescript
// ========== 链式 Builder（推荐） ==========
const data = await zyClient.with('预设名' | 自定义config | 无)
  .urlPath(p)                    // 请求路径（相对 baseURL 或完整 URL）
  .fullUrl(url)                  // 等价 urlPath，语义化表达完整 URL
  .baseUrl(b)                    // 单次覆盖 baseURL（不影响全局）
  .timeout(ms)                   // 单段超时
  .connectTimeout(ms)            // 连接超时（毫秒）
  .transferTimeout(ms)           // 传输超时（毫秒）
  .setToken(tk)                  // token 规格（写 custom.tokenSpec，签名插件计算 md5）
  .addParams(k, v | obj)         // 追加参数（对象批量合并，无需展开运算符）
  .setQuery(k, v | obj)          // 等价 addParams，语义化 query-only
  .addHeader(k, v).addHeaders(obj)
  .body(obj) / .bodyJson(obj)    // JSON 请求体
  .bodyForm(form)                // urlencoded 表单（自动序列化 + content-type）
  .bodyRaw(raw, contentType?)    // string/ArrayBuffer 原样请求体
  .bodyMultipart(fields, files)  // multipart 文本字段 + 文件列表
  .onUploadProgress(cb)          // (transferredSize, totalSize) => void
  .onDownloadProgress(cb)
  .transferRange(from?, to?)     // 断点续传范围（配合 downloadTo）
  .retry(count | {count, delayMs?, maxDelayMs?, retryOn?, onRetry?})
  .tag(tag)                      // 标签，配合 zyClient.cancelTag 批量取消
  .raw()                         // 纯净请求：跳过全部插件/缓存/解包
  .skip('sign', ...)             // 跳过指定插件
  .cache(seconds)                // 缓存时长（秒）
  .get<T>() / .post<T>() / .put<T>() / .delete<T>()   // 返回 data: T
  .getText() / .postText()       // data 的 JSON 字符串
  .request<T>(method)            // 任意 method（HEAD/OPTIONS/PATCH...）
  .upload<T>(filePath, fileKey?) // multipart 上传，返回 data: T
  .downloadTo(folderPath)        // 下载到目录，返回 HttpDownloadResponse

// ========== 取消（页面销毁联动） ==========
const call = zyClient.with().urlPath(p).execute<T>('GET')  // promise + abort 句柄
call.promise.then((resp: HttpResponse<T>) => { /* 完整响应，不解包 */ })
call.abort()                                     // 取消本次请求 → HttpError(kind='cancel')
zyClient.cancelTag(tag)                          // 批量取消同 tag 进行中请求，返回取消数
zyClient.cancelAll()                             // 取消全部进行中请求

// ========== 传统方法（@deprecated 已过时，仅内部兼容保留；业务代码统一使用建造者模式） ==========
zyClient.get/post/put/delete(url, config?/data?)          // → zyClient.with().urlPath(url).get<T>()
zyClient.getWithCache/postWithCache/putWithCache/deleteWithCache(url, cacheTime_秒, ...)
                                                          // → zyClient.with().urlPath(url).cache(seconds).get<T>()
// raw 请求：config.raw = true 时同样跳过缓存/插件/解包（Builder 用 .raw()）

// ========== 插件化拦截器 ==========
zyClient.use({
  name: 'myPlugin',              // 配合 .skip(name) 跳过
  onRequest?:  (cfg, ctx) => cfg // 可异步；前一个输出为下一个输入
  onResponse?: (resp, ctx) => resp
  onError?:    (err: HttpError, ctx) => HttpError
})
// 内置插件：sign（签名+公共参数/公共头），raw 或 skip('sign') 时整体跳过

// ========== 数据层 ==========
zyClient.setBusinessCodeHandler((code, body) => boolean)  // null 取消；false → reject HttpError(kind='business')
zyClient.registerMock({ match: (url, method) => boolean, respond: () => ESObject })
zyClient.setMockEnabled(true)    // Mock 总开关（默认关）；模拟数据为服务端响应体结构
zyClient.clearMocks()

// ========== 全局控制 ==========
NetBasic.baseUrl = '...'         // 全局切换（SSOT，运行期生效）
updateBaseUrl('...')             // 等价
setNetContext(context)           // 注入 Context，启用磁盘持久化缓存
setNetLogEnabled(false)          // 网络日志总开关（error 始终输出）
setNetLogMask(true, keys?)       // 日志脱敏（默认打码 token/signToken/tk/uid/sid/s1/o/o1/o2）
setInterceptLogEnabled(bool)     // intercept 调试日志开关（默认关）
ZyNetLogger.setPretty(bool)      // 日志 JSON 格式化输出（默认关）
zyClient.setDefaultCacheTime(s)  // 默认缓存时长（秒，仅 GET）

// ========== 统一错误处理 ==========
// catch 里永远是 HttpError：{ kind, statusCode?, cause?, config? }
// kind: 'network' | 'http' | 'parse' | 'cancel' | 'business' | 'unknown'

// ========== 缓存行为 ==========
// L1 内存 Map（进程内）→ L2 磁盘 cacheDir/zy_http_cache/<md5>.json（TTL 过期清理 + 总量 10MB LRU 淘汰）
// key 含 baseURL（环境切换不串缓存）；GET 默认缓存 10s，写请求必须显式 WithCache/.cache()
// GET 并发去重：同 key 进行中请求共享同一 Promise（日志 [CACHE] 并发去重命中(进行中)）
```
