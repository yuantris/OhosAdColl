# 网络层薄弱点修复方案（P0–P3）

> 范围：`RcpNetV2`（@creative/net 2.0 引擎）+ `AdCoreV2/src/main/ets/ohos/helper/network`（1.x 兼容外观层）
> 原则：先堵 P0 正确性/安全洞，再收敛 P1 可靠性，P2/P3 结构性问题随版本迭代。
> 每项含：问题 → 根因 → 修法 → 改动点 → 验证 → 风险/工作量。

---

## P0（必须本版本修复）

### P0-1 `execute()` 的 abort 是假取消

| 项 | 内容 |
|---|---|
| 问题 | `Call.abort()` 只 `token.cancel()` 置标志，请求仍完整发出；`ZyCancelToken` 从未传入引擎 |
| 根因 | `HttpClient.execute` 自建 token，仅在 `await doRequest` 后检查 `isCancelled()`；`HttpRequestConfig` 无 `cancelToken` 字段，`doRequest` → `builder` 链路不透传取消令牌 |
| 改动 | ① `OhosRcpTypes.ets`：`HttpRequestConfig` 增加 `cancelToken?: ZyCancelToken`（从 `@creative/net` 导入类型）；② `OhosRcp.ets doRequest`：`if (finalCfg.cancelToken) builder.cancelToken(finalCfg.cancelToken)`；③ `OhosRcp.ets execute`：把 token 写入 cfg 后再 `doRequest`，`abort` 即引擎级 `session.cancel(request)` |
| 伪码 | `const token = new ZyCancelToken(); cfg.cancelToken = token; const promise = this.doRequest(cfg)...; abort: () => token.cancel()` |
| 验证 | 单测：发起大请求后 `abort()`，断言 promise reject `kind==='cancel'` 且底层 fetch 被取消（可用 mock session 记录 `cancel` 调用） |
| 风险/工作量 | 低风险；0.5d |

### P0-2 `cancelAll()` 只能取消带 tag 的请求

| 项 | 内容 |
|---|---|
| 问题 | `ZyHttp.trackTag` 仅 `req.tag !== undefined` 时登记 → `cancelAll` 遍历 `inflight` key，无 tag 请求永不取消 |
| 根因 | 进行中索引只按 tag 建，缺"无 tag 桶" |
| 改动 | `RcpNetV2/src/main/ets/core/ZyHttp.ets`：① 无 tag 请求用保留键 `''`/`'__untagged__'` 登记（`trackTag` 调用处改为 `this.trackTag(req.tag ?? UNTAGGED, token)`）；② `cancelAll` 先取消全部 tag 桶再确保 untagged 桶被清；③ 或独立维护 `allTokens: Set<ZyCancelToken>`，`track/untrack` 双写，`cancelAll` 直接遍历 Set |
| 推荐 | **独立 Set 方案**（语义清晰，不受 tag 语义污染） |
| 验证 | 发 2 个无 tag 请求 → `cancelAll()` → 两个都 reject cancel；带 tag 的行为不回归 |
| 风险/工作量 | 低；0.5d。注意 `untrackTag` 同步移除 Set 防泄漏 |

### P0-3 业务码零校验（`setBusinessCodeHandler` 从未接线）

| 项 | 内容 |
|---|---|
| 问题 | 服务端 `code≠0` 时若无 `data` → 静默 `null`，鉴权失效/限流/降级无法区分 |
| 根因 | AdCore 未注册 handler；`unwrapBusiness` 只在有 handler 且 body 含 `code` 时拦截 |
| 改动 | ① `OhosRcp.ets` 模块初始化处（`zyClient.use(signInterceptor)` 旁）注册默认业务码处理器：`code` 为 `0`/`'0'`/`200`/`'200'` 视为成功，否则 throw `HttpError('business', ...)` 携带整包；② 提供 `setDefaultBusinessCodeHandler` 允许宿主覆盖或传 `null` 关闭；③ `RequestBuilder.send` 的 `unwrap` 已解包 `data`，确认 business 错误能透传到调用方 catch；④ `SDKCore.requestOFF/requestEasyOFF` catch 中按 `e.kind === 'business'` 与 `network` 分别打点（错误码、message），便于诊断 |
| 伪码 | `zyClient.setBusinessCodeHandler((code, body) => code === 0 \|\| code === '0' \|\| code === 200 \|\| code === '200')` |
| 验证 | Mock `{code:500,message:'x'}` → 断言 reject `kind='business'`；`{code:0,data:{...}}` 正常 resolve |
| 风险/工作量 | **注意**：若服务端存在非 0 但带 data 的"部分成功"协议，需在白名单放行；先与服务端核对错误码表。0.5–1d |

### P0-4 日志默认明文全开（token/deviceId 进 hilog）

| 项 | 内容 |
|---|---|
| 问题 | `netLogEnabled=true`、`maskEnabled=false`、`setPretty(true)` 无条件开启；signKey/signToken/params/body 明文 |
| 根因 | 库默认偏联调；AdCore 在 `RequestApplication.onCreate` 无条件 pretty |
| 改动 | ① `RequestApplication.onCreate`：`setPretty`/`setNetLogEnabled`/`setNetLogMask` 仅 `Ohos.debug()`（或 `AdSwitchManager` 调试开关）时开启，release 恒 `setNetLogEnabled(false)` + `setNetLogMask(true)`；② `logger.ts` 默认值收紧：`netLogEnabled` 默认 `true` 改为仅 debug（保持库默认 true 可以，由 AdCore 侧控制——**推荐改 AdCore 侧**，库保持通用）；③ `SignInterceptor` 的 `signToken` 行改为仅 `getCurrent()` 且 mask 开启时输出，或始终走 mask 字段名单（已含 `signKey`? 确认：mask keys 含 `signToken` 不含 `signKey`——把 `signKey` 加入 `DEFAULT_MASK_KEYS` 或直接不输出 signKey 明文）；④ 磁盘缓存命中日志的整包 `缓存数据` 输出在 release 一并静默 |
| 验证 | release 构建抓 hilog：搜 `ZYNetLog`，断言无 `signToken` 明文、无完整 `params` |
| 风险/工作量 | 极低风险；0.5d |

### P0-5 依赖断层（本地 RcpNetV2 改动不生效）

| 项 | 内容 |
|---|---|
| 问题 | `"@creative/net": "^2.0.0"` 走 registry，`file:../RcpNetV2` 被注释 |
| 根因 | 联调期未固定本地路径 |
| 改动 | 二选一，**写进团队约定**：① 日常开发：恢复 `"@creative/net": "file:../RcpNetV2"`，发版前切回 `^x.y.z`（可用 hvigor/脚本切换，或 oh-package 双配置）；② 双轨：CI 校验 registry 版本号 ≥ 本地 RcpNetV2 `oh-package.json5` 版本号，不一致则 fail。**推荐 ①+发版 checklist** |
| 验证 | 改本地 RcpNetV2 加一行日志 → `hvigorw assembleHar` → 宿主 hilog 可见 |
| 风险/工作量 | 0.5d（含发版流程文档） |

---

## P1（本迭代修复）

### P1-6 隐式全局重试 3 次（POST 重复提交 + 注释与实现不符）

| 项 | 内容 |
|---|---|
| 问题 | `req.retry === undefined` 时默认 `maxRetries=3` 对所有 method 生效；网络类错误重试 POST 可能重复提交；OhosRcp 注释称"5xx 默认可重试"与 `kind='http'` 不重试矛盾 |
| 改动 | ① `ZyHttp.execute`：默认重试仅对**幂等方法**（GET/HEAD/PUT/DELETE/OPTIONS，或显式配置才对 POST 生效）——在取 `maxRetries` 时：`const defaults = isIdempotent(req.method) ? DEFAULT_RETRY : NO_RETRY`；② `OhosRcp.ets` 修正 `retry` 注释为"仅网络类可重试错误（network kind），http 5xx 不重试"；③ `RequestBuilder.retry()` 文档注明 method 影响；④ 可选：`RetryConfig` 增加 `methods?: string[]` |
| 验证 | 单测：POST + 注入网络错误 → 断言 fetch 只调 1 次；GET → 4 次（1+3） |
| 风险/工作量 | 改变默认行为，需回归弱网场景；0.5d |

### P1-7 签名静默失败

| 项 | 内容 |
|---|---|
| 问题 | ① 无 `setToken`/规格解析不出：注入公共头但不写 `token`，无告警；② `md5Sync` 异常返回空串 MD5；③ `header["s"]` 恒 `''`；④ `NetBasic.isConfigured()` 从未前置校验 |
| 改动 | ① `SignInterceptor.ets`：`token_str` 为空时 `zyLog(hilog.warn, '[SIGN] token 规格解析失败: url=... spec=...')`；② `NetBasic.md5Sync` catch 改为 `zyLog(hilog.error, ...)` + 返回空串（或抛出——**推荐返回 ''+error 日志**，避免整请求炸掉）；③ `s` 头：确认协议——若服务端已不校验则删除字段；若需要，补真实值计算（待协议确认，暂改：缺失时 warn）；④ `doRequest` 发请求前（或 `RequestBuilder.build`）：非 raw 请求且 `!NetBasic.isConfigured()` → `zyLog(warn)` 并继续（不阻断，防止误伤已配置部分字段的场景），debug 模式可升级为 throw |
| 验证 | 清空 NetBasic → 发 V4 → hilog 出现 `[SIGN]`/`[NET]` 告警；md5 异常路径有 error 日志 |
| 风险/工作量 | 1d（含协议确认 `s` 头） |

### P1-8 默认 GET 缓存 10s + truthy 判断导致 `data=0` 永久 miss

| 项 | 内容 |
|---|---|
| 问题 | 不显式配置也缓存 10s；`if (cachedData)` 对 `0`/`''`/`false` 判 miss |
| 改动 | ① `OhosRcp.ets getCache` 调用点：`if (cachedData !== null && cachedData !== undefined)`；`setCache` 与 `getCache` 间统一用 `null` 表示未命中（现状 `getCache` 未命中返回 `null`，命中可能返回 falsy——调用方改判空即可）；② `runBusiness` 中 `if (cachedData)` → 显式空值判断；③ `defaultCacheTime`：评估业务是否真要默认 10s——广告开关接口是 POST 不受影响；若无 GET 依赖，可把默认降为 0（=不缓存），需要缓存显式 `.cache(n)`；**推荐默认 0，语义更安全**；④ `generateCacheKey` 文档补充：identity 不含 header，V5 的 `y` 头不同但同 URL+params 的 GET 会共享缓存/去重——当前业务无此组合，文档标注陷阱 |
| 验证 | Mock 缓存写入 `data:0` → 二次请求命中（不再回源）；默认路径断网 GET 不再读缓存（若默认改 0） |
| 风险/工作量 | 0.5d |

### P1-9 错误处理/重试策略未与网络层接线

| 项 | 内容 |
|---|---|
| 问题 | `RetryStrategyManager` 独立；V4/V5 失败仅打日志，无降级/回源/诊断 |
| 改动 | ① `SDKCore.requestOFF/requestEasyOFF`：catch 中区分 `HttpError.kind`（`business`/`network`/`http`），network 时可走 `RetryStrategyManager` 一次有间隔的业务重试（或依赖引擎重试，业务层只做**慢重试**：冷启动失败 → 下次前台再拉）；② 失败时写入 `GlobalAdLoadLogStore`（已有诊断存储）记录 kind/code/message；③ 可选：连续失败 N 次上报埋点（友盟已有） |
| 验证 | 断网启动 → OFF 请求失败有诊断记录；恢复网络后前台回调能重拉成功 |
| 风险/工作量 | 1d |

### P1-10 下载/断点续传旁路引擎（无重试/无错误标准化）

| 项 | 内容 |
|---|---|
| 问题 | `needNative` 直接 `session.fetch`，绕过重试、中间件、`toZyHttpError` |
| 改动 | ① 最小修：native 分支 catch 后 `toZyHttpError(err)` 标准化再抛，外层 `logger.failed` 不变；② 重试：native 分支外包一层与引擎一致的退避循环（复用 `ZyHttp` 内逻辑需抽公共函数——`RcpNetV2` 抽 `retryLoop` util 导出，或 AdCore 侧对 download 手动重试）；③ 长期：把 `transferRange`/`destination` 能力下沉进 `ZyRequestBuilder`，消灭双分支 |
| 验证 | 下载注入连接错误 → 断言有重试且错误 `instanceof ZyHttpError` |
| 风险/工作量 | ①+② 1d；③ 归入 P3 |

### P1-11 宿主未注入 Context 时磁盘缓存静默降级

| 项 | 内容 |
|---|---|
| 改动 | `setNetContext` 未调用时，首次 `getCacheDir()===null` 打一次 warn（已有写路径 warn，补读路径/首次探测）；`RequestApplication` 提供 abstract/配置项提示宿主必须走标准初始化 |
| 验证 | 裸调（不走 RequestApplication）→ 单条 warn 不刷屏 |
| 风险/工作量 | 0.25d |

### P1-12 官方 HTTP 缓存需按运行时 API 门控（编译 12 ≠ 运行 20）

| 项 | 内容 |
|---|---|
| 问题 | 工程 `compatibleSdkVersion: 5.0.0(12)`，`rcp.ResponseCache` 自 6.0.0(20) 才可用；仅靠 `try/catch` 静默降级无法在低版本设备上预分支，且 `DEFAULT_CACHE_FOLDER` 硬编码 `entry` 模块路径在宿主应用中必错 |
| 根因 | 编译期类型可见（SDK 含 API20 声明）≠ 运行期能力存在；缺显式 `deviceInfo.sdkApiVersion` 门控 |
| 改动 | ① **已落地** `RcpNetV2/src/main/ets/cache/ZyHttpCache.ets`：新增 `HTTP_CACHE_MIN_API=20`、`isHttpCacheApiSupported()`（`deviceInfo.sdkApiVersion >= 20`，number）；`recreate()` 先 API 门控再 try/catch 兜底；`ZyHttpCache.isApiSupported()` 静态探测；错误信息带当前 API；`Index.ets` 导出两符号；② **AdCore 分流策略**：业务缓存（OhosRcp 自建 L1/L2，纯 fs+Map，**API 无关，12 上全功能**）为唯一业务缓存——低版本设备不感知差异；`ZyHttpCache` 仅当 `isHttpCacheApiSupported()` 为 true 且需要协议级缓存时由宿主可选挂载（AdCore 当前不挂）；③ **P3 补充**：`DEFAULT_CACHE_FOLDER` 改为构造必传 `context.cacheDir + '/ZyHttpCache'`（或 `setNetContext` 同步注入路径），删除硬编码 `entry`；④ 文档：README/方案标注"API<20 无官方 HTTP 缓存，业务缓存不受影响" |
| 分流表 | 能力 \| API 12–19 \| API 20+：<br>自建 L1/L2 业务缓存 \| ✅ \| ✅<br>官方 rcp.ResponseCache \| ❌ 静默跳过 \| ✅ 可选挂载<br>并发去重 inFlight \| ✅ \| ✅ |
| 验证 | ① API12 设备/模拟器：`new ZyHttpCache()` → `isSupported()===false`、`getCache()===undefined`、发请求正常、无 crash；② API20+ 设备：`isSupported()===true` 且 `getState()` 有值；③ `ZyHttp.create({cache})` 在 12 上会话创建成功不带 `requestConfig.cache`；④ 业务 GET/POST 缓存行为两版本一致 |
| 风险/工作量 | 库侧已改完 0.25d；AdCore 文档/可选挂载策略 0.25d；路径注入归 P3-15b |

---

## P2（安全加固，下迭代）

### P2-12 MD5 签名可伪造 + `t1` 客户端时钟

| 改动 | ① 与服务端协商：token 增加服务端随机 challenge 或缩短有效窗 + `t1` 服务端校验容差；② 短期端侧：`t1` 改用 `Date.now()` 保持，但 `o/o1/o2`（deviceId md5）评估是否应换 HMAC(secret)——**secret 不能放端上，需服务端下发短时效密钥**；③ 若协议短期不动，至少在文档标注"客户端签名仅防随意篡改，非安全边界" |
| 验证 | 与服务端联调改时间戳被拒 |
| 风险/工作量 | 需服务端配合，端侧 1–2d + 协同 |

### P2-13 未启用 certificate pinning

| 改动 | `ZyHttp.create` 时传 `security: { certificatePinning: {...} }`（`RcpNetV2` 已支持 `translateSecurityConfig`）；从配置文件读公钥 SHA256 BASE64，支持多 pin 轮换；**注意**：pin 失效会导致全部请求失败——加 `remoteValidation:'system'` 回退策略或双 pin |
| 验证 | 抓包工具 MITM → 请求失败；正常设备不受影响 |
| 风险/工作量 | 1d + 证书轮换运维约定 |

### P2-14 baseUrl 双入口不同步

| 改动 | ① `APIs.ts` 去掉 `export let baseUrl`，改 `export const DEFAULT_BASE_URL`，修改走 `NetBasic.baseUrl=`；② 或 getter 绑定 `zyClient.config.baseURL`；③ 全局 grep 消灭直接改 `APIs.baseUrl` 的调用 |
| 验证 | `NetBasic.baseUrl = x` 后所有请求 host 变 x；无第二入口 |
| 风险/工作量 | 0.25d |

---

## P3（结构收敛，随大版本）

### P3-15 双层冗余（缓存/错误/中间件）

| 改动 | 分三步，**不建议一次推平**： |
|---|---|
| 15a 错误统一 | `OhosRcpTypes.HttpError` 改为 `export { ZyHttpError as HttpError }` 或加 `fromZy` 转换层：`doRequest` catch 里统一 `toZyHttpError` 后映射旧 `kind` 字符串，保证调用方 `instanceof` 行为一致 |
| 15b 缓存收敛 | 业务缓存（ResultDTO data、去重）保留自建 L1/L2，**全 API 段（12+）统一行为**；官方 HTTP 缓存仅 API≥20 可选挂载（`isHttpCacheApiSupported()` 预检），AdCore 默认不挂避免双缓存语义。修正 `ZyHttpCache.DEFAULT_CACHE_FOLDER` 硬编码 `entry`：改为 `setNetContext` 时注入 `context.cacheDir + '/ZyHttpCache'`，未注入则 `isSupported()` 恒 false |
| 15c 签名迁移 | `signInterceptor` 从 1.x `NetInterceptor` 迁为 `ZyMiddleware`（`onRequest(ctx)` 改 `ctx.request.headers/queries`），注册进 `ZyHttp.create({middlewares:[sign]})`；`SignMiddleware` 占位删除或指向真实实现 |
| 验证 | 签名回归（V4/V5 抓包对比 token/headers 一致）；错误 `kind` 兼容旧调用方 |
| 风险/工作量 | 15a 1d、15b 1d、15c 2d（含回归） |

### P3-16 `with('default')` preset baseURL 被强制清空

| 改动 | `RequestBuilder.build()`：仅当"全局模板 config 来源且未显式改过"才清 `baseURL`；preset 显式带 `baseURL` 应保留——给 `applyBase` 打标 `baseFromPreset`，`build()` 只在 `!explicitBaseURL && !baseFromPreset` 时清空；或文档明确"preset 不支持 baseURL，只支持 header/params" |
| 验证 | `registerPreset('p', {baseURL:'https://x'})` + `with('p')` → 请求打到 x |
| 风险/工作量 | 0.5d |

### P3-17 死代码/类型谎言/未用导入

| 改动 | ① `SignInterceptor`：删 `typeof cfg.params === 'string'` 分支；② `OhosRcp.ets`：删未用 `AdIdStore`/`NetBasic` 导入（确认 `md5Sync` 仍用）；③ `ZyRequestBuilder.method()`：扩展 `ZyHttpRequestInternal.method` 类型为 `string` 或 HttpMethod 联合含 PATCH/OPTIONS，去掉 `as` 断言；④ `V3` 常量：使用或删除；⑤ `it` 头：`url.includes(V4[0])` 改为按 path 前缀匹配常量数组 `INJECT_IT_PATHS = [V4[0], ...]`，V5 若需 it 一并加 |
| 验证 | 编译零告警；codelinter 通过 |
| 风险/工作量 | 0.5d |

### P3-18 零测试

| 改动 | 建 `RcpNetV2/src/test` + `AdCoreV2/src/test`（Local Test）： |
|---|---|
| 用例清单 | ① 签名：token 规格→md5、缺失告警、raw/skip 跳过；② 缓存键 stableStringify、falsy data 命中、过期淘汰；③ 重试：method×错误类型矩阵；④ 取消：abort/cancelTag/cancelAll；⑤ 业务码 handler 白名单；⑥ cloneRequestConfig 深浅拷贝隔离 |
| 验证 | `hvigorw test` / DevEco Local Test 全绿 |
| 风险/工作量 | 2d（首批核心路径） |

### P3-19 磁盘缓存维护全目录 JSON.parse

| 改动 | `maintainDiskCache`：先 `statSync` 按 mtime 粗筛（mtime+TTL > now 才 parse），或文件名携带过期时间戳 `md5_<expireAt>` 免读内容 |
| 验证 | 1000 缓存文件写入耗时基准对比 |
| 风险/工作量 | 0.5d |

---

## 实施顺序与里程碑

| 批次 | 内容 | 预估 | 状态 |
|---|---|---|---|
| M1（本周） | P0-1 ~ P0-5 全部 + P1-7①②④ 轻量告警 | 3d | **✅ 已完成（2026-09-24）** 编译通过：`RcpNetV2` assembleHar、`adCoreV2-2.0.138.har` |
| M2（下迭代） | P1-6、P1-8、P1-9、P1-10①、P1-11、P1-12（AdCore 策略部分）、P2-14 | 4d | 待排期（P1-12 库侧门控已随 M1 落地） |
| M3 | P2-12（协同服务端）、P2-13、P3-15/16/17 | 5d+ | 待排期 |
| M4 | P3-18 测试补齐、P3-19 | 2.5d | 待排期 |

### M1 落地记录

| 项 | 改动摘要 | 关键文件 |
|---|---|---|
| P0-1 | `HttpRequestConfig.cancelToken?`；`doRequest` 引擎 `builder.cancelToken` + 原生路径 register/`trackInflight`/`session.cancel`；`execute` 透传 token | `OhosRcpTypes.ets`、`Common.ets`、`OhosRcp.ets` |
| P0-2 | `ZyHttp.allTokens: Map` 引用计数 + `trackAll/untrackAll`；无 tag 请求补建 token；公开 `trackInflight/untrackInflight`；`cancelAll` 遍历 allTokens + tag 桶兜底 | `RcpNetV2/.../ZyHttp.ets` |
| P0-3 | zyClient 默认 handler 白名单 `1/'1'/0/'0'/200/'200'`（**真机回归：本服务端成功码为 `1`，初版漏配导致 V5 被误拦**），宿主可 `setBusinessCodeHandler` 覆盖/`null` 关闭；`SDKCore.logRequestError` 按 kind/code 输出 | `OhosRcp.ets`、`SDKCore.ets` |
| P0-4 | `RequestApplication` 按 `Ohos.debug()` 分流：debug pretty 明文，release `setNetLogEnabled(false)+setNetLogMask(true)`；`DEFAULT_MASK_KEYS` 补 `signKey` | `RequestApplication.ets`、`compat/logger.ts` |
| P0-5 | `"@creative/net": "file:../RcpNetV2"`（**发版前切回 `^2.0.0`**，HAR 打包已有 local dependency 告警） | `AdCoreV2/oh-package.json5` |
| P1-7①②④ | token 规格解析失败/缺规格 warn；`md5Sync` catch error+返回 `''`；非 raw 且未配置 NetBasic 时 warn（不阻断） | `SignInterceptor.ets`、`NetBasic.ets`、`OhosRcp.ets` |
| P1-12（库侧） | `HTTP_CACHE_MIN_API=20` + `deviceInfo.sdkApiVersion` 门控 + `isHttpCacheApiSupported()` 导出 | `ZyHttpCache.ets`、`Index.ets` |

## 回归清单（每批必跑）

1. 冷启动 V4/V5 开关拉取成功（含签名字段抓包比对）。
2. 断网 → 联网：失败日志含 kind/code，恢复后可重拉。
3. release 包 hilog：无 token/signToken 明文。
4. `assembleHar` + 宿主 HAP 集成构建通过（**编译基准 compatibleSdkVersion 5.0.0(12)**）。
5. 取消：页面销毁 `cancelTag`/`cancelAll` 后无在飞请求（hilog 无迟到响应）。
6. **缓存分 API 回归**：API12 运行时——`isHttpCacheApiSupported()===false`、`new ZyHttpCache().isSupported()===false`、请求正常、自建 L1/L2 命中不受影响；API20+——官方缓存 `isSupported()===true` 可选启用。

## 待确认项（阻塞部分修复）

| 项 | 阻塞 | 对象 | 状态 |
|---|---|---|---|
| 服务端业务 code 全集（成功值、部分成功） | P0-3 白名单 | 服务端 | ⚠️ 真机确认成功码=`1`；白名单已加 `1/'1'`；`4004`=登录失效已拦截；全集仍待服务端核对 |
| `s` 头协议语义（恒空是否合法） | P1-7③ | 服务端 | ⏳ 未改（M1 不含） |
| V5 是否需要 `it` 头 | P3-17⑤ | 服务端 | ⏳ |
| 发版流程用 file: 还是版本号对齐 | P0-5 | 团队 | ⏳ 当前 file:，发版 checklist 待写 |
| 签名是否升级 challenge 机制 | P2-12 | 服务端 | ⏳ |
