# AdCoreV2 对接审查与升级路线图

> 审查范围：`AdCoreV2` 广告聚合 SDK（穿山甲 CSJ / 华为 AdsKit / 腾讯优量汇 GDT）
> 对照基准：`ad_demo` 官方示例（GDT 1.5.0 / 穿山甲 GroMore 7.6.0.6）
> 交付性质：分析报告，不含代码改动
> 审查日期：2026-10

---

## 1. 背景与审查范围

### 1.1 背景

`AdCoreV2` 是当前使用的广告聚合 SDK，对接三家 ADN（穿山甲、华为、腾讯优量汇），对外以 `ADHelper` 门面提供开屏 / 插屏 / 激励 / 信息流 / Banner 的加载与展示能力。本报告对照 `ad_demo` 目录下 GDT 与穿山甲官方 demo 的标准接入模式，系统审查 `AdCoreV2` 的对接正确性、实现问题与结构性缺点，并给出分阶段升级路线图。

### 1.2 审查范围

| 维度 | 范围 |
| --- | --- |
| 源码 | `AdCoreV2/src/main/ets/ohos/` 全量 |
| 宿主接入 | `entry/src/main/ets/` |
| 对照基准 | `ad_demo/GDT_Harmony_SDK_1.5.0/demo/demo/GDTUnionDemo/`、`ad_demo/穿山甲HarmonyOS_SDK_7.6.0.6/harmonyadsdk/demo/` |
| 不在范围 | Bidding/竞价能力（按需求搁置，待后续单独立项） |

### 1.3 审查方法

1. 逐模块深查 `AdCoreV2` 初始化、平台适配、加载/降级、回调、网络、缓存、对外 API。
2. 对照官方 demo 的 init / load / show / destroy / bidding / 生命周期模式。
3. 核对实现级 bug 与结构性偏差（含 file:line 证据）。
4. 产出分阶段升级路线图（Phase 0–3），按依赖排序、可独立发版。

---

## 2. AdCoreV2 现状深查

### 2.1 初始化流程

宿主继承 `RequestApplication`（AbilityStage），`onCreate` 中：`setNetContext` → 友盟 preInit → `validateConfig()`（读本地 `info.json`，`V4ConfigParser`/`EasyConfigParser` 填充 `AdIdStore` + `AdSlotManager`）→ `autoNetworkConfig()`（`NetBasic` 注入 SID/SV/IT/机型/包名/设备号）。

隐私授权后宿主调 `ADHelper.getInstance().init()`（幂等）：友盟 init → `requestOAID` → `SDKCore.requestOFF()`(V4) 或 `requestEasyOFF()`(V5) 拉取服务端开关 `ZyOFF` → `AdModeManager.getAvailableAdPlatforms()` 解析可用平台（可被 `ForceChannelManager` 强制渠道覆盖）→ 构建 CSJ/TENCENT/HUAWEI 的 `PlatformConfig` → `PlatformManager.init()`（工厂创建平台实例并 init；CSJ/TX 调各自 SDK init+start，HUAWEI 为空实现）→ `HealthChecker.start()`。

热启动：`onWindowStageActive` → `handleWarmStart()`：后台时长 > `adShowWaitingTime`（默认 60s）→ `HotStartManager.pushSplashAdPage()` 创建子窗口 `ZySplashShowPage` 展示热启动开屏；`warmStartDetector()` 加载插屏。

### 2.2 接入的广告平台 / ADN

| 平台 | PlatformType | 适配器 | 底层 SDK | 状态 |
| --- | --- | --- | --- | --- |
| 穿山甲 CSJ | 1 | `helper/platform/CsjAdPlatform.ets` + `loader/CsjAdLoader.ets` | `@csj/openadsdk` 7.6.6 | 完整（开屏/插屏/激励/信息流，含 OAID、dislike、视频监听） |
| 华为 AdsKit | 2 | `helper/platform/HuaweiAdPlatform.ets` + `loader/HwAdLoader.ets` | `@kit.AdsKit` | 开屏经 AdComponent 渲染；信息流 load 完整但事件监听 TODO（`bind()` 为空） |
| 腾讯优量汇 GDT | 3 | `helper/platform/TencentAdPlatform.ets` + `loader/TxAdLoader.ets` | `@gdt/gdt-union-sdk` 1.5.0.har | 完整（init/start、native、render/interaction 监听） |
| 快手 | 无 | 无 | 无 | 未接入；仅 `PlatformType.ts` 注释 `SERVER_SEQUENCE_MAP` 出现 `'3': '快'`、`ZyOFF.k` 字段预留 |

### 2.3 加载 / 展示 / 降级核心流程（`DegradationStrategy.executeWithDegradation`）

- 前置检查：`AdSwitchManager.isAdOpen` 总开关（关闭 → `onAdShowError(AD_CLOSE)`）；可用平台列表。
- 强制渠道模式（`ForceChannelManager`）：只走指定平台，`while(true)` 内重试至 maxRetry 耗尽。
- 常规模式 `executeWithPriorityList`：按 `config.platformPriority`（= 当前可用平台顺序）逐平台：
  - `PlatformManager.isPlatformAvailable()` 熔断检查（同 slot 失败≥3 次 → 熔断 60s，期间记 SKIPPED）；
  - `switchToPlatformByType()` 切换平台（**会重建全部 4 个 Manager**）；触发 `onAdPlatformSwitchStart`；
  - 平台内 while 重试：`getRealAdId()` 换真实 ID → `loadCallback`（→ `Manager.loadIndependentAd` → `XxxIndependentAd.load()` → `XxxAdLoader.load()`）→ 成功记 `AdAttemptRecord(SUCCESS)` 并触发 `onAdPlatformSwitchSuccess`；
  - 失败：`AdError.fromError` → `RetryStrategyManager.determineAction()`（按平台的 `PlatformRetryStrategy` 决定 RETRY/DEGRADE/FAIL）→ RETRY（`retryCount<maxRetry`）或降级下一平台（触发 `onAdPlatformFailed`）；
  - 全部失败：`CallbackGuard` 防重地回调 `onAdShowError(AD_LOAD_FAILED)`，返回 `AdResult(null, attemptRecords, ...)`。
- 加载超时兜底：每个 Loader 内 `AD_LOAD_TIMEOUT_MS=8000`（`AdLoaderTypes.ets:43`）setTimeout 强制失败（防止 ADN 不回调导致 Promise 永久 pending）；开屏"曝光即成功"以解除超时对展示时长的约束（`CsjAdLoader.ets:53-60`、`TxAdLoader.ets:50-55`）。
- VIP 短路：`loadVideoAd`/`loadInterstitialAd` 前查 `VIPRepo.instance.props.vip`，VIP 直接返回空 `AdResult`（信息流/开屏不短路）。

### 2.4 回调 / 事件 / 错误码

- `OnAdListener`：加载段 `onAdShowError` / `onAdPlatformSwitchStart` / `onAdPlatformSwitchSuccess` / `onAdPlatformFailed`；展示段 `onAdRender` / `onAdShow` / `onClick` / `onAdClose` / `onAdDestroy`。
- `OnVideoRewardListener`：`onVideoComplete` / `onVideoError` / `onVideoClick` / `onVideoShow`。
- 错误码 `ErrCode`：7000 AD_CLOSE、7001 AD_LOAD_FAILED、7002 AD_TIMEOUT、7003 NO_FULL_VIDEO、7701 CONFIG_INFO。
- 统一错误对象 `AdError` + `AdError.fromError`；`AdAttemptRecord`（平台/序号/结果/错误码/耗时/真实ID/重试类型）逐次记录；`AdResult<T>` 聚合 + `GlobalAdLoadLogStore`（最多 50 条）供调试组件展示。
- `CallbackGuard`：同名回调去重 + try/catch 包裹，防止超时回调与正常回调重复触发。

### 2.5 网络层（`helper/network/OhosRcp.ets`，约 1900 行）

- `zyClient`（默认导出，经 `Index.ets` 全量导出给宿主）：底层 `@creative/net` + `rcp.Session`。
- 链式构建器 `RequestBuilder`（`with().urlPath().setToken().post<T>()` 等，get/post/put/delete/upload/downloadTo/execute/raw/mock/重试/标签取消）。
- 中间件：`ZySignMiddleware`（注入 a/v/c/r/uuid query + m/s/s1/p1/o/o1/o2/t1/a1/sv 头，token 规格按 `_` 拆键映射后 md5 拼接）+ `ZyCacheMiddleware`（L1 内存 + L2 磁盘 `cacheDir/zy_http_cache`，10MB 上限，默认缓存 10s）。
- 统一业务单通道 `runBusiness`：Mock → raw → 缓存 → 并发去重（inFlight map）→ `unwrapBusiness`（业务 code 拦截）→ 写缓存。
- 附带完整 BSCStorage（白山云 S3 兼容）AWS V2 签名实现。
- 服务端地址 `APIs.ts`：baseUrl `https://api.zyapp.net.cn`；V3/V4/V5 开关接口路径与 token 规格。

### 2.6 缓存与线程模型

- 信息流缓存 `AdCache<T>`：按 adId 分桶，`MAX_CACHE_COUNT=5` 淘汰最旧（destroy）；`startAutoClean`/`stopAutoClean`/`markDisplayExpired`（`AdCache.ets:58,95`）已实现但**无任何调用点**（死代码）。
- `AdStateManager`（slot 状态机 QUEUED/ACTIVE/EXPIRED/DESTROYED）+ `ExclusiveNotification`（互斥展示通知）+ `AdUIDataGlobal` 全局刷新时间戳。
- 线程模型：单线程 ArkTS 事件循环；无 Worker/TaskPool。异步全为 Promise + setTimeout/setInterval（CSJ/TX SDK ready 轮询 100ms×5s、HealthChecker 60s、热启动窗口回调）。

### 2.7 对外 API 签名（`Index.ets` 导出，节选）

**ADHelper**（`helper/core/ADHelper.ets`）：

| 方法 | 签名 | 行号 |
| --- | --- | --- |
| getInstance | `static getInstance(): ADHelper` | L37 |
| init | `async init(): Promise<void>` | L44 |
| loadSplashAd | `async loadSplashAd(listener?: OnAdListener): Promise<AdResult<IndependentAd>>` | L93 |
| loadVideoAd | `async loadVideoAd(adId: string, rewardListener?: OnVideoRewardListener): Promise<AdResult<IndependentAd>>` | L118 |
| loadInterstitialAd | `async loadInterstitialAd(adId?: string, listener?: OnAdListener): Promise<AdResult<IndependentAd>>`（缺省 `'lscr'`） | L166 |
| loadFeedAd | `async loadFeedAd(config: AdConfig): Promise<AdResult<IAd<ESObject>>>` | L198 |
| preloadFeedAd | `async preloadFeedAd(adId: string, config: AdConfig): Promise<void>` | L212 |
| destroySplashAd / destroyVideoAd / destroyInterstitialAd | `(): void` | L219/L223/L227 |

> 注意：README 写 `loadSplashAd/loadVideoAd/loadInterstitialAd` 返回 `Promise<IndependentAd>`，实际为 `Promise<AdResult<IndependentAd>>`，文档与实现不一致。

**其他核心类型**：`RequestApplication`（抽象：`getAppConfig`/`preInitBefore`/`preInitFinish`/`clearAllData`）、`AppConfig`（`launcherBgRes` 必配、`adShowWaitingTime` 默认 60000，`AppConfig.ets:33`）、`AD` 静态门面、`OnAdListener`/`OnVideoRewardListener`、`IndependentAd`/`IAd<T>`、`AdConfig`+Builder、`AdResult<T>`、`AdType`（UNKNOWN0/SPLASH1/VIDEO2/INTERSTITIAL3/FEED4/BANNER5/NATIVE6）、`PlatformType`（UNKNOWN0/CSJ1/HUAWEI2/TENCENT3）、`AdSlotManager`/`AdSwitchManager`/`ForceChannelManager`/`AdStateManager`、组件 `SplashAdComponent`/`FeedAdComponent`/`BannerAdComponent` + 调试组件、网络导出 `zyClient` 等。

---

## 3. 官方 demo 接入模式摘要

### 3.1 GDT 优量汇 1.5.0 demo（`ad_demo/GDT_Harmony_SDK_1.5.0/demo/demo/GDTUnionDemo`）

- **初始化**：`GDTAdSDK.init(context,{appId})` → `GDTAdSDK.start()` 两阶段（`SDKInitHelper.ets:21-45`）；在 `onWindowStageCreate` 调用。
- **标准 load/show 分离**：`loadXxxAd` 只加载；`ad.show(windowStage)` 由业务显式调用（InterstitialPage:110-119、RewardPage:117-126）。
- **Bidding**：官方 demo 含 client/S2S bidding（本期搁置，细节从略）。
- **生命周期**：重载前/关闭时/`aboutToDisappear` 均 `destroy()`；开屏 `setCloseOnClick`、`setBackground(CustomNodeController)`、`show(windowStage, bottomView)` 可定制。
- **超时**：`GDTAdLoadConfig.timeoutMillis` 参数化。

### 3.2 穿山甲 GroMore 7.6.0.6 demo（`ad_demo/穿山甲HarmonyOS_SDK_7.6.0.6/harmonyadsdk`）

- **初始化**：`SDKConfigBuilder` + `MediationConfigBuilder`（本地 `GroMore-config.json` 加密配置）→ `CSJAdSdk.init` + `start()`。
- **Bidding**：官方 demo 含 bidding token/`setBidAdm`（本期搁置，细节从略）。
- **预加载**：`CSJAdSdk.getMediationManager().preload(List<AdSlot>, parallelNum, requestIntervalS)`。
- **渠道**：`adapter_gdt` / `adapter_ks`（快手）已接入 GroMore 聚合。
- **生命周期**：show 后清引用、item.destroy()、dislike 回调、`registerViewForInteraction` 自渲染。

---

## 4. 对接正确性结论

### 4.1 总体判断

AdCoreV2 的**三方 SDK 基础调用链是通的**（init → load → 回调 → 展示），但相对官方 demo 的标准接入模式存在**系统性偏差**，不能算"对接正确"：

| 维度 | 官方 demo 做法 | AdCoreV2 现状 | 判定 |
| --- | --- | --- | --- |
| load / show 分离 | `loadXxxAd` 只加载，`ad.show()` 显式调用 | 激励/插屏/腾讯开屏在 Loader 的 `onAdLoad` 内**自动 show**（`TxAdLoader.ets:81,154,235`、`HwAdLoader.ets:120,194`）；`IndependentAd.show()` 被注释为死代码 | ❌ 偏差大 |
| 释放资源 | `ad.destroy()` 全覆盖 | TX/CSJ Loader 闭包持有原生 ad 且从不 destroy；`destroy()` 只翻标志位（`TencentAdPlatform.ets:214-223`） | ❌ 泄漏 |
| Bidding | demo 含 client/S2S bidding 与 eCPM 透出 | 未实现 | ⏸ 本期搁置 |
| 开屏定制 | 背景/底栏/关闭按钮可定制 | 腾讯开屏直接 `show(windowStage)` 无定制 | ⚠️ 部分 |
| 失败语义 | load 失败与 show 失败分开回调 | TX 开屏以 `onAdExposure` 为"加载成功"，加载成功 ≠ 可展示 | ❌ 语义混乱 |
| 超时 | `timeoutMillis`/`loadTimeout` 参数化 | 写死 8s（`AdLoaderTypes.ets:43`）+ 华为 UI 层 10s 兜底，各平台成功语义不一致 | ⚠️ 不一致 |
| 渠道覆盖 | GroMore 有 adapter_gdt / adapter_ks | 快手协议位预留但无实现 | ❌ 缺失 |

### 4.2 已核实的对接级 Bug

1. **HealthChecker 恢复失效**：`PlatformManager.ets:127,147` 键为 `` `${adType}:${adSlot}` ``（数值枚举如 `1:splash`），`HealthChecker.ets:48-71` 却 switch 字符串 `'SPLASH'|'VIDEO'|...`，永远落到 `AdType.UNKNOWN`，`resetPlatformStatus` 清不掉真实键。熔断仅剩 `isPlatformAvailable` 惰性恢复。
2. **华为插屏事件断链**：`InterstitialAdStatusHandler.ets:22` 写死 `publisherBundleName: 'com.cooking.listzyhm'`（激励视频正确用 `com.huawei.hms.adsservice`，`RewardAdStatusHandler.ets:28`）。宿主包名一旦不同，插屏回调永远收不到；且 loader 创建 handler 时 `adListener` 未挂上。
3. **插屏/激励 show 链路死代码**：Manager 层 `showIndependentAd` 中 `this.currentAd.show()` 被注释，真实 show 藏在 Loader 加载回调里。
4. **`BaseAdManager.loadAd` Promise 永不 resolve**（Splash/Video/Interstitial Manager）：
   - `SplashAdManager.ets:31`：`return new Promise<IAd<ESObject>>(resolve => {});`
   - `VideoAdManager.ets` 同构；
   - `InterstitialAdManager.ets:32`：`return new Promise<IAd<ESObject>>(resolve => {});`
   调用即挂死。
5. **缓存清理从未启动**：`AdCache.startAutoClean()`/`markDisplayExpired()`（`AdCache.ets:58,95`）无调用点；Manager 内 cache 在 `switchToPlatformByType`（`PlatformManager.ets:54-58`）重建时被丢弃。
6. **Huawei appId 占位符**：`ADHelper.ets:79` `.setAppId('huawei_app_id')`；华为信息流 `bind()` 空 TODO（`HuaweiAdPlatform.ets:257-262`）——宿主收不到华为信息流点击/曝光/关闭事件。

---

## 5. 实现问题清单

### 5.1 TODO 与未完成实现

- `CsjAdPlatform.ets:50`、`TencentAdPlatform.ets:56`、`HuaweiAdPlatform.ets:32`：过期 TODO 注释（CSJ/TX 已实现 init；华为 init 确为空实现）。
- `HuaweiAdPlatform.ets:257-265`：`HuaweiFeedAd.bind()` 空壳，华为信息流无事件回调。
- `HotStartManager.ets:56-58`：`showWindow().catch(() => {/* TODO */})` 静默吞错。

### 5.2 硬编码

- `ADHelper.ets:79`：华为 appId `'huawei_app_id'` 占位符。
- `SDKCore.ets:46-72`：测试环境广告 ID 映射表硬编码。
- `AdIdStore.ts:8-59`：CSJ_APPID `'5477447'`、各槽位 ID、腾讯 14 个 posId 默认值硬编码。
- `APIs.ts:1`：baseUrl 硬编码；`SignInterceptor.ets:34-35`：`c_from='harmony'`、`r_from=7`。
- 超时常量分散：`AD_LOAD_TIMEOUT_MS=8000`（`AdLoaderTypes.ets:43`）、SDK ready 等待 5000ms、Splash 组件超时 10000ms、Feed 30000、HealthChecker 60s（`HealthChecker.ets:9`）、熔断阈值 3、AdCache MAX 5、网络 5000ms。
- `oh-package.json5` 注释依赖本地/远端手动切换，发版事故风险。

### 5.3 死代码 / 危险地雷

- `SplashAdManager.loadAd`（`SplashAdManager.ets:31`）/ `VideoAdManager.loadAd` / `InterstitialAdManager.loadAd`（`InterstitialAdManager.ets:32`）：`return new Promise(... => {})` 永不 resolve。
- `BaseAdManager.onLoadFail` 恒返回 null；`CsjAdPlatform.waitForInit` 从未被调用。
- `AdCache` 自动清理死代码；`getValidAd`（`AdCache.ets:40`）命中后不消费条目（可能重复返回）。
- `SDKCore.ets:124-170`：整段测试 ID 切换逻辑注释保留。
- `SplashAdManager.showIndependentAd`：`// this.currentAd.show();` 注释掉。

### 5.4 设计 / 一致性问题

- **错误契约不统一**：manager 未初始化时既回调 `onAdShowError` 又 throw；正常失败返回失败 `AdResult` 不抛错——调用方必须同时处理 reject 与 `isSuccess` 两种失败形态。
- **平台切换丢缓存**：`switchToPlatformByType` 每次重建 4 个 Manager（`PlatformManager.ets:181-189`），`currentAd` 与 Feed 缓存随之作废。
- **熔断恢复双路径冗余**：`isPlatformAvailable` 惰性恢复 与 `HealthChecker` 定时 reset 重复实现（后者还是坏的）。
- **三平台 `XxxIndependentAd` 近 100% 复制粘贴**；`TencentIndependentAd.setVideoRewardListener` 签名与接口不一致（缺 `| undefined`）。
- **双重 show 路径**：`CsjIndependentAd.show()`/`HuaweiIndependentAd.show()` 内手动触发 `onAdShow`，与 Loader 回调并存，`showed` 标记可能失同步。
- `SplashAdComponent.ets:88-91`：任何华为开屏失败都被报成 `AD_TIMEOUT`，错误语义失真。
- `SplashAdComponent.ets:6`：HAR 内部反向 import 包根 `Index`，自引用环。
- `ErrCode.AD_CLOSE` 语义混用（广告开关关闭 vs manager 未初始化）。
- `ADHelper.init()` 失败仅 log，无重试/无回调，状态对宿主不可见。
- `AdModeManager.getADMode`（单平台互斥）与 `getAvailableAdPlatforms`（多平台列表）两套解析可能不一致。
- VIP 只短路 video/interstitial，splash/feed 无 VIP 处理。
- README 返回值与实际不符；版本记录章节编号错误。

### 5.5 安全 / 合规

- 签名为参数拼接 MD5，无防重放（t1 时间戳有传未见校验）。
- 设备号/机型/包名明文 header 发送。
- `setSecurityConfig`（证书锁定）已实现但 SDK 未默认启用。
- `Index.ets` 将整个 `zyClient`（含 BSC 对象存储、Mock）default 导出，攻击面偏大。

### 5.6 并发

- 无 Worker/TaskPool；CSJ/TX ready 为 100ms 忙等轮询。
- `PlatformManager` 可变 Map 无并发互斥：两次 `loadXxxAd` 交错会互踩 `currentPlatform`/Manager。
- `HttpClient.inFlight` 并发去重对 POST 也生效（幂等性需注意）。

### 5.7 AdCache 缓存链路专项分析（信息流 / Banner）

**结论：当前 AdCache 对「每次请求即展示」的组件化路径基本无意义，甚至有害；Banner 则完全不走缓存。**

实际展示链路：

```
FeedAdComponent
 ├─ isBannerMode(华为+enableBanMerge) → BannerAdView   ← 直连 advertising.AdLoader(adType=8)，零缓存
 └─ 否则 → FeedAdView.aboutToAppear/refreshAd
              └─ ADHelper.loadFeedAd → DegradationStrategy → FeedAdManager.loadAd
                    ├─ getFromCache → AdCache.getValidAd   （命中不移除）
                    ├─ miss → platform.loadFeedAd → addToCache
                    └─ 返回 ad → FeedAdView.render()
```

问题逐条：

| # | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| 1 | **Banner 路径完全绕过缓存** | `BannerAdView.ets` 直接 `advertising.AdLoader`/`AutoAdComponent`，不经 `FeedAdManager`/`AdCache` | 缓存对 Banner 零作用 |
| 2 | **命中不消费**：`getValidAd` 返回 `entry.ad` 后条目仍留在缓存 | `AdCache.ets:40-56` | 同一原生 ad 可能被两个 `FeedAdView` 同时持有（重复 render/双重 destroy） |
| 3 | **展示后不失效**：`markDisplayExpired` 从未被调用 | 全库仅定义（`AdCache.ets:58`），无调用点 | 已展示广告仍被当作 valid 再次返回 |
| 4 | **Use-after-destroy**：`FeedAdView.clearAd()` 会 `ad.destroy()`，但缓存条目不移除、不失效 | `FeedAdView.ets:200-201` + `getValidAd` 逻辑 | 刷新后再 load 命中缓存 → **拿到已 destroy 的僵尸广告**，render 失败或异常 |
| 5 | **自动清理死代码**：`startAutoClean`/`clearExpiredAds` 无调用；TTL=60s 仅靠 FIFO>5 淘汰 | `AdCache.ets:95`、`CachedAdEntry.ets:7` | 过期项堆积直至超 5 条才挤掉 |
| 6 | **唯一合理消费场景未接线**：`preloadFeedAd`（预热进缓存、组件出现时取）全库无调用 | 仅定义 `ADHelper.ets:212` | 缓存"预加载-复用"设计从未被使用 |
| 7 | **组件路径 = 即请求即展示**：`FeedAdView` 每次 appear/refresh 都 `loadFeedAd` 并立刻 `render()` | `FeedAdView.ets:41-45,109-149` | 与"缓存复用"目标正交；每次都是新请求（除非命中脏缓存） |
| 8 | **平台切换丢缓存**：`switchToPlatformByType` 重建 4 个 Manager，`new AdCache()` | `PlatformManager.ets:181-190`、`BaseAdManager.ets:29` | 降级过程缓存全部作废 |
| 9 | **缓存与展示生命周期脱节**：destroy 只发生在 View 侧/`clearCache`，Manager 不感知 | `FeedAdView.clearAd` vs `AdCache` | 状态机 `isDisplayExpired` 形同虚设 |

**定性**：AdCache 目前是「半成品 + 负资产」——

- 设计意图应是：`preloadFeedAd` 预取 → 组件取缓存即时展示（降低首屏等待）。
- 实际现状：组件即请求即展示；预加载未接线；命中不消费、不失效、与 destroy 脱节。
- 因此缓存**没有正收益**，反而引入僵尸广告/重复展示风险。

**修复方向**（并入 Phase 0/1）：

1. **短期去害**：`getValidAd` 改为取出即移除（或 `markDisplayExpired` 在 View destroy 时必调）；`clearAd()` 同步 `cache.clearCache(adId)` 或 `markDisplayExpired`。
2. **接线预加载**：在开屏结束/网络恢复/页面预热时调用 `preloadFeedAd`；`FeedAdView` 优先取缓存命中即 render（跳过网络等待）。
3. **生命周期绑定**：`CachedAdEntry` 与 `IAd.destroy` 联动；`startAutoClean()` 在 `ADHelper.init` 启动。
4. **架构取舍**（二选一）：
   - **A. 保留并修好**：缓存只服务「preload → 复用」场景，组件路径禁止把已展示 ad 再入缓存；
   - **B. 简化删除**：承认信息流即请求即展示，删除 `AdCache` 及相关死代码，降低维护面（Banner 本就无缓存）。
5. Banner 若需缓存/预取，必须先进 `IAdPlatform` 统一栈（Phase 1.3），否则永远无法复用。

### 5.8 IAd\<T\> 信息类广告基类专项分析（信息流 / Banner / 自渲染）

**结论：现有 `IAd<T>` 只够支撑「模板渲染信息流」，撑不起 Banner 统一栈与原生自渲染；需重构为「生命周期 + 渲染模式 + 素材」三段式抽象。**

现状契约（`helper/impl/IAd.ts`）：

```
IAd<T>:
  abstract timeout(): number
  abstract view(): NodeController | undefined   // 仅适配 getAdComponent()，IAd.ts:61
  abstract bind(): void                         // 构造函数里调用，IAd.ts:50
  abstract render(): void
  abstract destroy(): void
  + 状态: expires/showed/expired/displayExpired + OnAdListener 转发
  + getAd(): T                                  // IAd.ts:173，泄漏原生对象
```

三端实现对照：

| 实现 | view() | render() | bind() | 备注 |
| --- | --- | --- | --- | --- |
| `CsjFeedInfoAd`（模板） | `ad.getAdComponent()` | `ad.render(uiContext)` | express 监听 + dislike | 契约吻合 |
| `TencentFeedAd`（模板） | `ad.getAdComponent()` | `ad.render(windowStage, uiContext)` | render/interaction/video | 契约吻合 |
| `HuaweiFeedAd` | **恒 `undefined`** | **空实现** | **空 TODO** | 实际靠 `FeedAdView` 特判 `AdComponent(ads, displayOptions)` 渲染，**契约被架空** |
| Banner | 不在 IAd 体系 | — | — | `BannerAdView` 直连 `advertising`/`AutoAdComponent` |
| 原生自渲染 | 无实现 | — | — | GDT `loadManualAd`+素材、CSJ `registerViewForInteraction` 均未封装 |

#### 5.8.1 问题清单

| # | 问题 | 证据/影响 |
| --- | --- | --- |
| 1 | **`view(): NodeController\|undefined` 过窄** | 模板渲染要 NodeController；华为要 `AdComponent(ads, displayOptions)` 入参；自渲染要的是**素材数据**不是 Node。三种渲染模式被硬塞进一个方法 |
| 2 | **无素材（Material）抽象** | 自渲染需要 title/desc/icon/images/video/pattern(单图/三图/视频)/logo/adLogo（GDT `GDTAdPattern`、`GDTManualAd`）；`IAd` 完全没有 |
| 3 | **无交互注册抽象** | GDT `registerViewForInteraction(uiContext, rootViewId, clickableViewIds)`、CSJ 同名 API 依赖组件树 id；应是 `bindInteraction(...)` 契约，现不存在 |
| 4 | **`bind()` 在构造函数调用**（`IAd.ts:50`） | `HuaweiFeedAd` 构造时 `super(undefined as ESObject)`，广告未就绪，`bind()` 必然空转；华为事件监听因此缺失 |
| 5 | **状态语义自相矛盾** | `onShow()` 置 `expired=true`（`IAd.ts:105-107`）→ 展示后 `isExpired()` 恒 true，与 `AdCache.isValid` 复用目标冲突（§5.7） |
| 6 | **`getAd(): T` 泄漏原生对象**（`IAd.ts:173`） | 宿主可拿到 `GDTNativeAd`/`CSJNativeExpressAd`，抽象被击穿，升级底层 SDK 即破坏兼容 |
| 7 | **双体系并行** | 展示类广告走 `IndependentAd`（load/show/destroy），信息类走 `IAd`；命名（I 前缀却是 abstract class）、生命周期不统一 |
| 8 | **Banner 特性未建模** | 轮播 `refreshTime`、关闭后重挂、尺寸 57/144 只存在于 `BannerAdView`，无法参与降级/缓存/统计 |
| 9 | **无 `isDestroyed` / 幂等 destroy** | `destroy()` 后状态仍可能被查询；与 §5.7 僵尸广告叠加 |
| 10 | **`timeout()` 做成抽象方法** | 各实现硬编码 30000；应来自 `AdConfig.timeout`/常量配置 |

#### 5.8.2 重构方向（推荐）

**目标：同一套 `IAd` 生命周期与事件，支撑 TEMPLATE / SELF_RENDER / SYSTEM_COMPONENT 三种渲染模式 + Banner。**

```
                    ┌─ AdLifecycle（load/show/destroy 状态机，幂等）
IAd / AdEntity ─────┼─ AdEvents（onRender/onShow/onClick/onClose/onDestroy/onFail）
                    ├─ getRenderMode(): TEMPLATE | SELF_RENDER | SYSTEM_COMPONENT
                    ├─ templateView?(): NodeController          // CSJ/TX 模板
                    ├─ systemProps?(): {ads, displayOptions}    // 华为 AdComponent
                    ├─ material?(): NativeAdMaterial            // 自渲染素材
                    └─ bindInteraction?(ctx, rootId, clickIds, creativeIds?)
```

要点：

1. **拆渲染模式**：`RenderMode` 枚举 + 可选能力方法，取代"万能 `view()`/`render()`"；`FeedAdView`/`NativeAdView`/`BannerAdView` 按 mode 分支，消灭华为特判。
2. **新增 `NativeAdMaterial`**：`title/desc/iconUrl/imageUrls/videoUrl/pattern(adPattern)/adLogoUrl/actionText` 等；GDT Manual、CSJ native、华为 native 统一映射。
3. **`bindInteraction` 入契约**：自渲染在 `aboutToAppear` 后拿 `uiContext`+组件 id 注册点击/可点区域；模板/系统组件可空实现。
4. **`bind()` 改为 load 成功后调用**（或 `attach(ad)`），修复华为空绑；事件转发统一在基类，子类只做原生回调映射。
5. **状态机与缓存解耦**：`showed/destroyed/expired` 明确转移；`onShow` 不再把 `expired` 置 true；`destroy()` 幂等并回调 `onDestroy` 后不可再 render。
6. **收口 `getAd()`**：改为 `protected` 或删除，宿主只依赖 `IAd` + `material`/`systemProps`。
7. **Banner 入栈**：`BannerEntity extends IAd`（`refreshTime`、close/reload），走统一降级与统计；内部可仍用 `AutoAdComponent`。
8. **与 `IndependentAd` 合并层级**：开屏/激励/插屏本质是"全屏展示型"，可作为 `IAd` 的 `FULLSCREEN` 子类或共用 `AdEntity` 基座，消除双体系。

建议拆文件：`helper/impl/AdEntity.ts`（生命周期+事件）、`helper/impl/RenderMode.ts`、`model/NativeAdMaterial.ts`、`helper/impl/IAdPlatform` 增加 `loadNativeAd`/`loadBannerAd`。

### 5.9 宿主 `entry` 使用侧问题

- 激励视频 `loadVideoAd` 返回的 `AdResult` 从不检查（`ExpressCheck.ets:92,486`）。
- 插屏 `loadInterstitialAd()` 无监听、无展示、未销毁（`Index.ets:38`）——死代码。
- 全程无 `destroyXxxAd` 调用。
- Banner 槽位用 `FeedAdComponent` 渲染，`BannerAdComponent` 引而未用。
- `ADHelper.init()` 放在 Splash 页 `aboutToAppear`，时机偏晚。

---

## 6. 作为聚合 SDK 的结构性缺点

### A. 生命周期与资源治理

- load/show 融合，无法预加载后择机展示，也无法做"就绪再展示"体验。
- 原生广告对象闭包泄漏；华为 PPS 订阅注册/反注册不对称。
- 展示后 destroy 语义缺失（仅翻标志位）。
- **AdCache 半成品且有害**：组件即请求即展示、`preloadFeedAd` 未接线、命中不消费、展示/destroy 不失效，可能返回已销毁广告；Banner 完全不走缓存（详见 §5.7）。

### B. 广告形态补齐

- Banner 仅华为直连 `advertising`（`BannerAdView.ets`），**绕过** IAdPlatform/降级/熔断/重试；`AdIdStore.TX_BANNER_POS_ID_LIST` 闲置。
- `AdType.NATIVE` 仅枚举无实现；GDT manual 自渲染、CSJ `registerViewForInteraction` 均未封装。
- 快手渠道协议预留未实现。
- CSJ 全屏/新插屏（Full）无统一抽象。

### C. 并发与可观测性

- `switchToPlatformByType` 无并发互斥。
- `AdDiagnosticInfo`/`AdResult.toDiagnosticInfo` 从未被调用，诊断 UI 无数据。
- 错误码三套并存：`ErrCode` + 各平台原生码透传 + 魔法码 `333`；`AdError.parseFromMessage` 正则可误抽码。
- 重试默认值冲突：`DEFAULT_MAX_RETRY=1` vs `RetryAction.retry(maxRetry=3)`。
- 各平台"加载成功"语义不一致。

### D. 信息类广告抽象能力不足（详见 §5.8）

- `IAd<T>` 仅适配模板渲染信息流，华为契约被架空、Banner 在体系外、自渲染无素材/交互抽象。
- 双体系（`IndependentAd` vs `IAd`）生命周期不统一；`getAd()` 泄漏原生对象。

> 注：Bidding/竞价能力本期暂不纳入文档与路线图（按需求搁置）。

### E. 结论

该 SDK 为典型的**串行降级型聚合 SDK**（非竞价、非并行瀑布）：服务端开关决定平台优先级 → `ADHelper` 门面 → `DegradationStrategy` 按序尝试（平台内重试、平台间降级、熔断+健康巡检）→ 平台适配器 + Loader 对接穿山甲/华为/腾讯。配置双轨（本地 info.json + V4/V5 云端）、槽位-ID 映射、回调防重、加载超时兜底等工程化程度较高；网络层功能异常丰富。主要风险：华为信息流事件缺失、华为 appId 占位符、永不 resolve 的空 Promise、三平台适配器大量重复、错误契约不统一、README 与实现不符、**AdCache 与组件路径脱节且可能返回已销毁广告**、**`IAd<T>` 抽象撑不起 Banner/自渲染（华为契约被架空）**。Bidding 能力本期搁置。

---

## 7. 升级路线图（按依赖排序，可独立发版）

### Phase 0 — 对接正确性与稳定性修复（P0，建议 1 个迭代）

| # | 事项 | 关键文件 |
| --- | --- | --- |
| 0.1 | 修复 HealthChecker 键解析（统一数值 AdType 或 key 改枚举名） | `HealthChecker.ets:48-71`、`PlatformManager.ets:127,147` |
| 0.2 | 华为插屏 `publisherBundleName` → `com.huawei.hms.adsservice`，并把 listener 挂上 Handler | `InterstitialAdStatusHandler.ets:22`、`HwAdLoader.ets:119` |
| 0.3 | 资源释放：Loader 持有原生 ad 引用，`destroy()` 真调 `ad.destroy()`；PPS 订阅成对反注册 | `TxAdLoader.ets`、`CsjAdLoader.ets`、`TencentAdPlatform.ets:214`、`HuaweiAdPlatform.ets:278` |
| 0.4 | 删除/实现 `BaseAdManager.loadAd` 永不 resolve 的 Promise | `SplashAdManager.ets:31`、`VideoAdManager.ets`、`InterstitialAdManager.ets:32` |
| 0.5 | AdCache 去害：`getValidAd` 取出即移除/失效；`FeedAdView.clearAd` 同步失效；启动 `startAutoClean()`；平台切换显式清缓存。并在「修好缓存」与「删除缓存」间拍板（见 §5.7） | `AdCache.ets`、`CachedAdEntry.ets`、`FeedAdView.ets`、`BaseAdManager.ets`、`PlatformManager.initAdManagers` |
| 0.6 | 华为 appId 配置化；`HuaweiFeedAd.bind()` 补事件转发；魔法码 333 入 `ErrCode`；`SplashAdComponent` 失败语义修正 | `ADHelper.ets:79`、`HuaweiAdPlatform.ets:257-273`、`HwAdLoader.ets:64`、`SplashAdComponent.ets:88-91` |
| 0.7 | 统一重试默认值；统一错误契约（初始化失败显式回调，不 throw+callback 双轨） | `AdConstants.ets:6`、`RetryStrategy.ets:15`、`ADHelper.ets` |
| 0.8 | 清理过期 TODO/注释死代码；`init()` 失败可重试+回调 | 各 Platform、`SDKCore.ets:124-170` |
| 0.9 | 宿主侧：检查 `AdResult`、补 destroy、插屏走完整 load→show、Banner 用 `BannerAdComponent`、init 时机前置 | `entry/src/main/ets/**` |

**验收**：对照 GDT/穿山甲 demo 同场景——加载失败可降级、展示后无泄漏、HealthChecker 能真正恢复熔断平台、华为插屏事件可达。

### Phase 1 — 生命周期标准化 + 广告形态补齐（P1）

| # | 事项 | 说明 |
| --- | --- | --- |
| 1.1 | **load/show 分离**：`IndependentAd` 标准化为 `load() → ready → show() → destroy()`；Loader 只 load | 对齐 GDT demo；保留"自动展示"兼容开关 |
| 1.2 | 统一成功语义：load 仅在"素材就绪可展示"时 resolve；曝光/关闭走独立 listener | 消除 TX 开屏 exposure 即成功 |
| 1.2b | 缓存价值落地：接线 `preloadFeedAd` 预热（开屏后/网络恢复），组件命中缓存即时展示；或按 §5.7-B 删除缓存简化实现 | 需与 0.5 决策一致 |
| 1.3 | Banner 走 `IAdPlatform` + 降级栈：补 TX/CSJ Banner loader；废除直连华为 | 细节并入 Phase 3.4（BannerEntity） |
| 1.4 | NATIVE 自渲染封装（GDT `loadManualAd`、CSJ `registerViewForInteraction`） | 细节并入 Phase 3.3/3.5（NativeAdMaterial） |
| 1.5 | CSJ 全屏/新插屏（Full）纳入统一 `AdType` 抽象 | 对齐 GroMore FullAdPage |
| 1.6 | 快手渠道：`PlatformType.KS` + adapter（参考 `adapter_ks.har` 3.0.6） | 解锁 `ss=3` |

**验收**：可预加载插屏/激励再择机 show；Banner 三端可降级；NATIVE demo 页可渲染。

### Phase 2 — 并发安全 + 可观测性（P1.5，可与 Phase 1 并行）

| # | 事项 | 说明 |
| --- | --- | --- |
| 2.1 | `PlatformManager` 加载会话隔离（独立 session / 串行队列），不共享可变 `currentPlatform` | 消除并发互踩 |
| 2.2 | 启用 `AdDiagnosticInfo`：降级结束写入 `AdResult`/`AdUIData`，debug 组件展示 waterfall 轨迹 | 已有模型直接接线 |
| 2.3 | 错误码治理：`ErrCode` 统一命名空间（平台前缀映射表），废除 `parseFromMessage` 启发式 | 便于聚合报表 |
| 2.4 | 超时参数化（透传 `timeoutMillis`/`loadTimeout`），区分 loadTimeout / showTimeout / renderTimeout | 对齐 demo |
| 2.5 | `AdAttemptRecord` 接埋点上报（友盟已有依赖） | 填充率/收益归因 |
| 2.6 | 对外 API 收敛：`zyClient` 等网络/存储能力不 default 导出，减少攻击面 | `Index.ets` |

### Phase 3 — IAd 信息类广告抽象重构（P2，支撑 Banner 统一 + 自渲染）

| # | 事项 | 说明 |
| --- | --- | --- |
| 3.1 | 拆 `AdEntity` 基座：生命周期状态机（幂等 destroy）+ 事件转发；`bind()` 改 load 后调用 | 见 §5.8.2 |
| 3.2 | 引入 `RenderMode`（TEMPLATE / SELF_RENDER / SYSTEM_COMPONENT）+ 可选 `templateView`/`systemProps`/`material`/`bindInteraction` | 消灭华为特判 |
| 3.3 | 定义 `NativeAdMaterial` 并映射 GDT Manual / CSJ native / 华为 native | 支撑自渲染 |
| 3.4 | Banner 入统一栈：`BannerEntity`（refreshTime/close/reload）+ TX/CSJ Banner loader | 替换 `BannerAdView` 直连 |
| 3.5 | 自渲染 API：`loadNativeAd` + `NativeAdComponent`/宿主自绘 + `bindInteraction` | 对齐 GDT `loadManualAd`、CSJ `registerViewForInteraction` |
| 3.6 | 合并 `IndependentAd` 与 `IAd` 层级（FULLSCREEN 子类或共用基座）；收口 `getAd()` | API 兼容策略见风险节 |

**验收**：三端信息流共用同一 `IAd` 事件契约（含华为）；Banner 可降级；自渲染 demo 可点击跳转并上报曝光/点击。

> Bidding/竞价（client/S2S、eCPM 排序、win-loss 上报）本期按需求**移出路线图**，待后续单独立项。

---

## 8. 风险与兼容性说明

### 8.1 load/show 分离的 API 版本策略

Phase 1.1 将 `IndependentAd` 标准化为 load/show 分离，对现有宿主是破坏性变更。建议：

1. **过渡期双轨**：保留现有 `loadXxxAd`（内部 load 后自动 show）作为兼容入口，标记 `@deprecated`；新增 `loadXxxAdSeparated` / `showXxxAd` 显式接口。
2. **行为开关**：`AdConfig.autoShow`（默认 true 保持兼容，新接入方可显式 false 走分离模式）。
3. **版本策略**：次版本引入新 API，主版本删除旧自动 show 路径。

### 8.2 AdCache 取舍风险

| 选项 | 风险 | 收益 |
| --- | --- | --- |
| A. 保留并修好 | 需正确接线 preload + 生命周期，工作量大 | 预加载命中降低首屏等待 |
| B. 删除简化 | 若未来要做预加载需重建 | 立即消除僵尸广告/重复展示风险，降低维护面 |

**建议**：当前组件路径即请求即展示，预加载从未接线，**短期选 B（删除）更安全**；若确定要预加载收益，再以 Phase 1.2b 立项重建。

### 8.3 华为契约修复风险

`HuaweiFeedAd.bind()` 补事件转发需确认华为 PPS 订阅 API 的注册/反注册对称性，避免泄漏；`publisherBundleName` 修正后需真机验证插屏事件可达。

### 8.4 其他

- 错误契约统一（0.7）需与宿主同步，调用方从"既 catch 又判 isSuccess"迁移为单一失败通道。
- `getAd()` 收口（3.6）若宿主已依赖原生对象，需提供迁移期 `@deprecated` 导出。

---

## 9. 附录：关键文件索引

| 用途 | 路径 |
| --- | --- |
| GDT 官方 demo | `ad_demo/GDT_Harmony_SDK_1.5.0/demo/demo/GDTUnionDemo/` |
| 穿山甲 GroMore demo | `ad_demo/穿山甲HarmonyOS_SDK_7.6.0.6/harmonyadsdk/demo/` |
| 聚合 SDK 源码 | `AdCoreV2/src/main/ets/ohos/` |
| 初始化门面 | `AdCoreV2/src/main/ets/ohos/helper/core/ADHelper.ets` |
| 降级策略 | `AdCoreV2/src/main/ets/ohos/helper/core/DegradationStrategy.ets` |
| 平台管理 | `AdCoreV2/src/main/ets/ohos/helper/core/PlatformManager.ets` |
| 健康巡检 | `AdCoreV2/src/main/ets/ohos/helper/core/HealthChecker.ets` |
| 信息流缓存 | `AdCoreV2/src/main/ets/ohos/helper/cache/AdCache.ets` |
| 信息类广告基类 | `AdCoreV2/src/main/ets/ohos/helper/impl/IAd.ts` |
| 网络层 | `AdCoreV2/src/main/ets/ohos/helper/network/OhosRcp.ets` |
| 华为插屏事件 | `AdCoreV2/src/main/ets/ohos/helper/platform/huawei/InterstitialAdStatusHandler.ets` |
| 现有架构文档 | `AdCoreV2/广告整体逻辑流程.md`、`AdCoreV2/README.md`、`AdCoreV2_架构对比图.md` |
| 宿主接入 | `entry/src/main/ets/` |

---

*本报告为分析型交付，未改动业务代码。后续若启动 Phase 0 修复，再单独立项实施。*
