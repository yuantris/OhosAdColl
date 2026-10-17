# OhosAdCore 项目 Code Wiki

## 目录

1. [项目概述](#项目概述)
2. [项目架构](#项目架构)
3. [模块结构](#模块结构)
4. [核心类与接口说明](#核心类与接口说明)
5. [广告平台集成](#广告平台集成)
6. [依赖关系](#依赖关系)
7. [项目运行方式](#项目运行方式)
8. [使用示例](#使用示例)

---

## 项目概述

**OhosAdCore** 是一个面向鸿蒙(HarmonyOS)平台的广告SDK项目，提供统一的多平台广告聚合能力。该项目支持穿山甲(CSJ)、华为(Huawei)、腾讯(Tencent)三大主流广告平台，实现了开屏广告、激励视频、插屏广告、信息流广告等多种广告类型的加载与展示。

### 项目特点

- **多平台聚合**：支持穿山甲、华为、腾讯三大广告平台
- **智能降级策略**：平台加载失败时自动切换到备用平台
- **统一API接口**：提供简洁统一的广告加载接口
- **平台熔断机制**：防止频繁请求失败的平台
- **缓存管理**：支持广告缓存和过期清理
- **网络请求封装**：内置HTTP客户端，支持缓存和拦截器

---

## 项目架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         Application Layer                        │
│                     (entry / 业务应用层)                          │
├─────────────────────────────────────────────────────────────────┤
│                         SDK Layer                                │
│                      (AdCoreV2 / AdCore)                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    ADHelper (核心入口)                    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌───────────────────────────┼───────────────────────────┐      │
│  │                           │                            │      │
│  ▼                           ▼                            ▼      │
│ ┌─────────────┐      ┌─────────────┐           ┌─────────────┐  │
│ │PlatformManager│     │DegradationStrategy│     │HealthChecker│  │
│ └─────────────┘      └─────────────┘           └─────────────┘  │
│        │                                                         │
│        ▼                                                         │
│ ┌─────────────────────────────────────────────────────────┐     │
│ │              AdPlatformFactory (平台工厂)                 │     │
│ └─────────────────────────────────────────────────────────┘     │
│        │                    │                    │               │
│        ▼                    ▼                    ▼               │
│ ┌─────────────┐     ┌─────────────┐      ┌─────────────┐        │
│ │CsjAdPlatform│     │HuaweiAdPlatform│   │TencentAdPlatform│    │
│ └─────────────┘     └─────────────┘      └─────────────┘        │
│        │                    │                    │               │
│        ▼                    ▼                    ▼               │
│ ┌─────────────┐     ┌─────────────┐      ┌─────────────┐        │
│ │SplashAdManager│   │VideoAdManager│    │InterstitialAdManager│ │
│ │FeedAdManager  │   │              │    │                      │ │
│ └─────────────┘     └─────────────┘      └─────────────┘        │
├─────────────────────────────────────────────────────────────────┤
│                      Network Layer                               │
│                     (OhosRcpNet)                                 │
│              HTTP Client + Cache + Interceptor                   │
└─────────────────────────────────────────────────────────────────┘
```

### 核心设计模式

1. **工厂模式**：`AdPlatformFactory` 负责创建不同广告平台实例
2. **策略模式**：`DegradationStrategy` 实现广告加载降级策略
3. **单例模式**：`ADHelper`、`AdSlotManager` 等核心类采用单例
4. **Builder模式**：`AdConfig.builder()` 构建广告配置
5. **观察者模式**：`OnAdListener` 监听广告生命周期事件

---

## 模块结构

### 1. AdCoreV2 模块 (推荐使用)

当前主推的广告SDK版本，版本号 `2.0.0-alpha25`。

#### 目录结构

```
AdCoreV2/
├── Index.ets                    # 模块入口，导出所有公共API
├── src/main/ets/ohos/
│   ├── application/             # 应用层配置
│   │   ├── AppConfig.ets        # 应用配置
│   │   ├── RequestApplication.ets # 请求应用配置
│   │   └── SDKCore.ets          # SDK核心初始化
│   │
│   ├── components/              # UI组件
│   │   ├── SplashAdComponent.ets  # 开屏广告组件
│   │   ├── FeedAdComponent.ets    # 信息流广告组件
│   │   ├── debug/                 # 调试组件
│   │   └── pages/                 # 页面组件
│   │
│   ├── helper/                  # 核心辅助类
│   │   ├── core/                # 核心逻辑
│   │   │   ├── ADHelper.ets           # 广告加载核心入口
│   │   │   ├── PlatformManager.ets    # 平台管理器
│   │   │   ├── AdPlatformFactory.ets  # 平台工厂
│   │   │   ├── DegradationStrategy.ets # 降级策略
│   │   │   ├── AdSlotManager.ts       # 广告位管理
│   │   │   ├── AdSwitchManager.ets    # 广告开关管理
│   │   │   └── HealthChecker.ets      # 健康检查
│   │   │
│   │   ├── platform/            # 平台实现
│   │   │   ├── CsjAdPlatform.ets      # 穿山甲平台
│   │   │   ├── HuaweiAdPlatform.ets   # 华为平台
│   │   │   ├── TencentAdPlatform.ets  # 腾讯平台
│   │   │   └── csj/                   # 穿山甲特定实现
│   │   │
│   │   ├── manager/             # 广告管理器
│   │   │   ├── BaseAdManager.ets      # 基础管理器
│   │   │   ├── SplashAdManager.ets    # 开屏广告管理
│   │   │   ├── VideoAdManager.ets     # 激励视频管理
│   │   │   ├── InterstitialAdManager.ets # 插屏广告管理
│   │   │   └── FeedAdManager.ets      # 信息流广告管理
│   │   │
│   │   ├── loader/              # 广告加载器
│   │   │   ├── CsjAdLoader.ets        # 穿山甲加载器
│   │   │   ├── HwAdLoader.ets         # 华为加载器
│   │   │   └── TxAdLoader.ets         # 腾讯加载器
│   │   │
│   │   ├── impl/                # 接口实现
│   │   │   ├── IAd.ts                 # 广告接口
│   │   │   ├── IAdPlatform.ts         # 平台接口
│   │   │   └── IndependentAd.ts       # 独立型广告接口
│   │   │
│   │   ├── cache/               # 缓存管理
│   │   │   ├── AdCache.ets            # 广告缓存
│   │   │   └── CachedAdEntry.ets      # 缓存条目
│   │   │
│   │   ├── retry/               # 重试策略
│   │   │   ├── RetryStrategy.ets      # 重试策略
│   │   │   └── RetryStrategyManager.ets # 重试管理
│   │   │
│   │   ├── network/             # 网络请求
│   │   │   ├── OhosRcp.ts             # HTTP客户端
│   │   │   ├── NetBasic.ts            # 网络基础
│   │   │   └── APIs.ts                # API定义
│   │   │
│   │   ├── const/               # 常量定义
│   │   │   ├── AdConstants.ets        # 广告常量
│   │   │   ├── ErrCode.ts             # 错误码
│   │   │   └── SDKConst.ts            # SDK常量
│   │   │
│   │   ├── error/               # 错误处理
│   │   │   ├── AdError.ets            # 广告错误
│   │   │   └── RuntimeError.ets       # 运行时错误
│   │   │
│   │   ├── entity/              # 数据实体
│   │   │   ├── ZyOFF.ets              # 开关配置
│   │   │   └── ResultDto.ets          # 响应DTO
│   │   │
│   │   └── logger/              # 日志
│   │       └── LogManager.ts           # 日志管理
│   │
│   ├── interface/               # 接口定义
│   │   ├── OnAdListener.ts            # 广告监听器
│   │   ├── OnAdLoadListener.ets       # 加载监听器
│   │   ├── OnAdShowListener.ets       # 展示监听器
│   │   └── OnVideoRewardListener.ts   # 激励视频监听器
│   │
│   ├── model/                   # 数据模型
│   │   ├── AdConfig.ts                # 广告配置
│   │   ├── AdType.ts                  # 广告类型
│   │   ├── PlatformType.ts            # 平台类型
│   │   ├── PlatformConfig.ts          # 平台配置
│   │   ├── AdResult.ets               # 广告结果
│   │   └── AdStatus.ts                # 广告状态
│   │
│   ├── storage/                 # 存储管理
│   │   ├── AdUIData.ets               # 广告UI数据
│   │   └── AdUIDataGlobal.ets         # 全局UI数据
│   │
│   └── utils/                   # 工具类
│       ├── ADUtil.ets                 # 广告工具
│       ├── OAIDUtil.ets               # OAID工具
│       └── UIUtil.ets                 # UI工具
│
├── libs/                        # 第三方库
│   └── GDTUnionSDK-1.2.0.har    # 腾讯广告SDK
│
├── oh-package.json5             # 模块依赖配置
└── build-profile.json5          # 构建配置
```

### 2. AdCore 模块 (旧版本)

旧版广告SDK，版本号 `1.1.39-fix`，保留用于兼容旧项目。

### 3. OhosRcpNet 模块

网络请求模块，提供HTTP客户端能力。

### 4. entry 模块

示例应用入口，展示SDK使用方式。

---

## 核心类与接口说明

### 1. ADHelper - 广告加载核心入口

**文件位置**: [ADHelper.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/core/ADHelper.ets)

**职责**: SDK初始化、广告加载、平台切换

```typescript
class ADHelper {
  // 单例获取
  static getInstance(): ADHelper
  
  // SDK初始化
  async init(): Promise<void>
  
  // 加载开屏广告
  async loadSplashAd(listener?: OnAdListener): Promise<AdResult<IndependentAd>>
  
  // 加载激励视频
  async loadVideoAd(adId: string, listener?: OnVideoRewardListener): Promise<AdResult<IndependentAd>>
  
  // 加载插屏广告
  async loadInterstitialAd(adId?: string, listener?: OnAdListener): Promise<AdResult<IndependentAd>>
  
  // 加载信息流广告
  async loadFeedAd(config: AdConfig): Promise<AdResult<IAd<ESObject>>>
  
  // 销毁广告
  destroySplashAd(): void
  destroyVideoAd(): void
  destroyInterstitialAd(): void
}
```

### 2. PlatformManager - 平台管理器

**文件位置**: [PlatformManager.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/core/PlatformManager.ets)

**职责**: 管理广告平台实例、平台切换、熔断机制

```typescript
class PlatformManager {
  // 初始化平台
  init(platformConfigs: Map<PlatformType, ESObject>, availAd: PlatformType[]): void
  
  // 切换平台
  switchToPlatformByType(platformType: PlatformType): void
  
  // 获取可用平台列表
  getAvailablePlatformTypes(): PlatformType[]
  
  // 检查平台可用性
  isPlatformAvailable(platformType: PlatformType, adType: AdType, adSlot: string): boolean
  
  // 记录平台失败
  recordPlatformFailure(platformType: PlatformType, adType: AdType, adSlot: string): void
  
  // 获取广告管理器
  getSplashAdManager(): SplashAdManager | null
  getVideoAdManager(): VideoAdManager | null
  getInterstitialAdManager(): InterstitialAdManager | null
  getFeedAdManager(): FeedAdManager | null
}
```

### 3. DegradationStrategy - 降级策略

**文件位置**: [DegradationStrategy.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/core/DegradationStrategy.ets)

**职责**: 实现广告加载失败时的平台降级策略

```typescript
class DegradationStrategy {
  // 执行降级加载
  async executeWithDegradation<T>(
    config: AdConfig,
    loadCallback: (config: AdConfig, retryCount: number) => Promise<T>,
    listener?: OnAdListener
  ): Promise<AdResult<T>>
}
```

**降级流程**:
1. 检查广告开关是否开启
2. 获取可用平台列表
3. 按优先级依次尝试加载
4. 失败时记录失败信息并尝试下一平台
5. 所有平台失败后返回错误

### 4. IAdPlatform - 广告平台接口

**文件位置**: [IAdPlatform.ts](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/impl/IAdPlatform.ts)

```typescript
interface IAdPlatform {
  // 初始化平台
  init(config: PlatformConfig): void
  
  // 获取平台类型
  getPlatformType(): PlatformType
  
  // 创建开屏广告
  createSplashAd(config: AdConfig): IndependentAd
  
  // 创建激励视频
  createVideoAd(config: AdConfig): IndependentAd
  
  // 创建插屏广告
  createInterstitialAd(config: AdConfig): IndependentAd
  
  // 加载信息流广告
  loadFeedAd(config: AdConfig): Promise<IAd<ESObject>>
}
```

### 5. IndependentAd - 独立型广告接口

**文件位置**: [IndependentAd.ts](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/impl/IndependentAd.ts)

**适用场景**: 开屏广告、插屏广告、激励视频等独立展示的广告

```typescript
interface IndependentAd {
  // 加载广告
  load(): Promise<void>
  
  // 销毁广告
  destroy(): void
  
  // 检查有效性
  isValid(): boolean
  
  // 设置广告监听器
  setAdListener?(listener: OnAdListener): void
  
  // 设置激励视频监听器
  setVideoRewardListener?(listener: OnVideoRewardListener): void
  
  // 获取华为开屏广告参数(仅华为平台)
  getHuaweiAdParams?(): HuaweiSplashAdParams
}
```

### 6. AdConfig - 广告配置

**文件位置**: [AdConfig.ts](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/model/AdConfig.ts)

```typescript
class AdConfig {
  // 广告ID
  private adId: string
  
  // 广告类型
  private adType: AdType
  
  // 页面类型
  private pageType: PageType
  
  // 超时时间(毫秒)
  private timeout: number
  
  // 平台优先级列表
  private platformPriority: PlatformType[]
  
  // Builder模式创建
  static builder(): AdConfigBuilder
}

enum AdType {
  UNKNOWN = 0,    // 未知
  SPLASH = 1,     // 开屏
  VIDEO = 2,      // 激励视频
  INTERSTITIAL = 3, // 插屏
  FEED = 4,       // 信息流
  BANNER = 5,     // 横幅
  NATIVE = 6      // 原生
}

enum PageType {
  UNKNOWN = 0,    // 未知
  NORMAL = 1,     // 普通页面
  LIST = 2,       // 列表
  DIALOG = 3,     // 对话框
  DIALOG_EXIT = 4 // 退出对话框
}
```

### 7. OnAdListener - 广告监听器

**文件位置**: [OnAdListener.ts](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/interface/OnAdListener.ts)

```typescript
interface OnAdListener {
  // 加载阶段回调
  onAdShowError?(code: number, msg: string): void
  onAdPlatformSwitchStart?(currentPlatform: number, nextPlatform: number): void
  onAdPlatformSwitchSuccess?(previousPlatform: number, currentPlatform: number): void
  onAdPlatformSwitchFailed?(platform: number, errorCode: number, errorMsg: string): void
  
  // 展示阶段回调
  onAdRender?(): void
  onAdShow?(): void
  onClick?(): void
  onAdClose?(): void
  onAdDestroy?(): void
}
```

### 8. AdSlotManager - 广告位管理

**文件位置**: [AdSlotManager.ts](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/core/AdSlotManager.ts)

**职责**: 管理广告位字符串到各平台真实广告ID的映射

```typescript
class AdSlotManager {
  // 获取单例
  static getInstance(): AdSlotManager
  
  // 注册广告位映射
  registerAdSlot(adSlot: string, platformType: PlatformType, realAdId: string): void
  
  // 批量注册
  registerAdSlotMappings(adSlot: string, mappings: Map<PlatformType, string>): AdSlotManager
  
  // 获取真实广告ID
  getRealAdId(adSlot: string, platformType: PlatformType): string | null
  
  // 更新广告位
  updateAdSlot(adSlot: string, platformType: PlatformType, realAdId: string): AdSlotManager
}
```

### 9. SDKCore - SDK核心

**文件位置**: [SDKCore.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/application/SDKCore.ets)

**职责**: 请求广告开关配置

```typescript
class SDKCore {
  // 广告模式数据
  static OFF: ZyOFF
  
  // 请求V4开关
  static async requestOFF(): Promise<void>
  
  // 请求V5开关(云创)
  static async requestEasyOFF(): Promise<void>
}
```

---

## 广告平台集成

### 支持的广告平台

| 平台 | PlatformType | SDK依赖 | 说明 |
|------|-------------|---------|------|
| 穿山甲(CSJ) | CSJ = 1 | @csj/openadsdk 7.3.0 | 字节跳动广告平台 |
| 华为(Huawei) | HUAWEI = 2 | @kit.AdsKit | 华为广告平台 |
| 腾讯(Tencent) | TENCENT = 3 | GDTUnionSDK 1.2.0 | 腾讯广告平台 |

### 平台实现类

#### 1. CsjAdPlatform - 穿山甲平台

**文件位置**: [CsjAdPlatform.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/platform/CsjAdPlatform.ets)

```typescript
class CsjAdPlatform implements IAdPlatform {
  // 初始化SDK
  init(config: PlatformConfig): void {
    let csjConfig: SDKConfig = new SDKConfigBuilder()
      .appId(config.getAppId())
      .allowShowNotify(true)
      .customController(new CSJController())
      .debug(config.isDebug())
      .build()
    CSJAdSdk.init(context, csjConfig)
    CSJAdSdk.start()
  }
  
  // 创建开屏广告
  createSplashAd(config: AdConfig): IndependentAd
  
  // 加载信息流广告
  async loadFeedAd(config: AdConfig): Promise<IAd<ESObject>>
}
```

#### 2. HuaweiAdPlatform - 华为平台

**文件位置**: [HuaweiAdPlatform.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/platform/HuaweiAdPlatform.ets)

```typescript
class HuaweiAdPlatform implements IAdPlatform {
  // 使用华为AdsKit
  // advertising.AdLoader 加载广告
  // AdComponent 展示广告
}
```

#### 3. TencentAdPlatform - 腾讯平台

**文件位置**: [TencentAdPlatform.ets](file:///d:/ZyProject/SDK/OhosAdCore/AdCoreV2/src/main/ets/ohos/helper/platform/TencentAdPlatform.ets)

```typescript
class TencentAdPlatform implements IAdPlatform {
  // 使用GDTUnionSDK
}
```

---

## 依赖关系

### 项目依赖图

```
┌─────────────────────────────────────────────────────────────┐
│                      OhosAdCore (Root)                       │
│  @ohos/pinyin4js ^2.0.0                                     │
│  @ohos/axios ^2.2.2                                         │
│  @zycore/common latest                                      │
│  @zycore/network latest                                     │
│  @yunkss/ef_crypto ^1.0.1                                   │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    AdCoreV2     │  │     AdCore      │  │   OhosRcpNet    │
│                 │  │    (旧版本)      │  │                 │
│ @csj/openadsdk  │  │                 │  │ @creative/net   │
│   7.3.0         │  │ @csj/openadsdk  │  │   1.0.1         │
│                 │  │   7.3.0         │  │                 │
│ GDTUnionSDK     │  │                 │  │                 │
│   1.2.0         │  │ GDTUnionSDK     │  │                 │
│                 │  │   1.2.0         │  │                 │
│ @umeng/common   │  │                 │  │                 │
│ @umeng/analytics│  │ @umeng/common   │  │                 │
│                 │  │ @umeng/analytics│  │                 │
│ @zycore/common  │  │                 │  │                 │
│ @creative/net   │  │ @zycore/common  │  │                 │
│   1.0.1         │  │ @zycore/network │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### 主要依赖说明

| 依赖包 | 版本 | 用途 |
|--------|------|------|
| @csj/openadsdk | 7.3.0 | 穿山甲广告SDK |
| GDTUnionSDK | 1.2.0 | 腾讯广告SDK |
| @kit.AdsKit | 系统API | 华为广告SDK |
| @creative/net | 1.0.1 | 网络请求库 |
| @zycore/common | latest | 通用工具库 |
| @umeng/analytics | latest | 友盟统计 |
| @ohos/axios | 2.2.2 | HTTP客户端 |

---

## 项目运行方式

### 环境要求

- **DevEco Studio**: 5.0+
- **HarmonyOS SDK**: API 12+
- **Node.js**: 16+

### 构建配置

项目使用 Hvigor 构建系统，配置文件 `build-profile.json5`:

```json5
{
  "app": {
    "signingConfigs": [...],
    "products": [{
      "name": "default",
      "signingConfig": "default",
      "compatibleSdkVersion": "5.0.0(12)",
      "runtimeOS": "HarmonyOS"
    }]
  },
  "modules": [
    { "name": "entry", "srcPath": "./entry" },
    { "name": "adCore", "srcPath": "./AdCore" },
    { "name": "adCoreV2", "srcPath": "./AdCoreV2" },
    { "name": "OhosRcpNet", "srcPath": "./OhosRcpNet" }
  ]
}
```

### 运行步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd OhosAdCore
   ```

2. **安装依赖**
   ```bash
   ohpm install
   ```

3. **打开DevEco Studio**
   - 导入项目
   - 等待同步完成

4. **配置签名**
   - 在 `build-profile.json5` 中配置签名信息
   - 或使用自动签名

5. **运行应用**
   - 连接鸿蒙设备或启动模拟器
   - 点击运行按钮

### 构建命令

```bash
# Debug构建
hvigorw assembleHap --mode module -p product=default

# Release构建
hvigorw assembleHap --mode module -p product=default -p buildMode=release
```

---

## 使用示例

### 1. 初始化SDK

```typescript
import { ADHelper } from '@zysdk/ad-core-hm';

// 在Ability的onCreate中初始化
async function initSDK() {
  await ADHelper.getInstance().init();
}
```

### 2. 加载开屏广告

```typescript
import { ADHelper, IndependentAd, OnAdListener } from '@zysdk/ad-core-hm';

@Entry
@Component
struct SplashPage {
  @State ad: IndependentAd | undefined = undefined;
  
  private adListener: OnAdListener = {
    onAdClose: () => {
      // 广告关闭，跳转主页
      this.gotoMainPage();
    },
    onAdShowError: (code: number, msg: string) => {
      // 加载失败，跳转主页
      this.gotoMainPage();
    },
    onAdPlatformSwitchStart: (current, next) => {
      console.log(`平台切换: ${current} -> ${next}`);
    }
  };
  
  async aboutToAppear() {
    // 初始化SDK
    await ADHelper.getInstance().init();
    
    // 加载开屏广告
    const result = await ADHelper.getInstance().loadSplashAd(this.adListener);
    this.ad = result.ad ?? undefined;
  }
  
  build() {
    Column() {
      SplashAdComponent({
        ad: this.ad,
        adListener: this.adListener
      })
    }
  }
}
```

### 3. 加载激励视频

```typescript
import { ADHelper, OnVideoRewardListener } from '@zysdk/ad-core-hm';

async function showRewardVideo() {
  const listener: OnVideoRewardListener = {
    onVideoShow: () => console.log('视频展示'),
    onVideoClick: () => console.log('视频点击'),
    onVideoComplete: () => {
      console.log('视频完成，发放奖励');
      // 发放奖励逻辑
    },
    onVideoError: (code, msg) => console.log(`视频错误: ${msg}`)
  };
  
  const result = await ADHelper.getInstance().loadVideoAd('video_ad_id', listener);
  if (result.ad) {
    // 展示广告
  }
}
```

### 4. 加载信息流广告

```typescript
import { ADHelper, AdConfig, AdType, FeedAdComponent } from '@zysdk/ad-core-hm';

async function loadFeedAd() {
  const config = AdConfig.builder()
    .setAdId('feed_ad_id')
    .setAdType(AdType.FEED)
    .build();
  
  const result = await ADHelper.getInstance().loadFeedAd(config);
  if (result.ad) {
    // 使用FeedAdComponent展示
  }
}
```

### 5. 配置广告位映射

```typescript
import { AdSlotManager, PlatformType } from '@zysdk/ad-core-hm';

// 注册广告位
AdSlotManager.getInstance()
  .registerAdSlotMappings('splash', new Map([
    [PlatformType.CSJ, '穿山甲广告ID'],
    [PlatformType.HUAWEI, '华为广告ID'],
    [PlatformType.TENCENT, '腾讯广告ID']
  ]))
  .registerAdSlotMappings('video', new Map([
    [PlatformType.CSJ, '穿山甲视频ID'],
    [PlatformType.HUAWEI, '华为视频ID']
  ]));
```

---

## 错误码说明

| 错误码 | 常量名 | 说明 |
|--------|--------|------|
| -1 | AD_CLOSE | 广告开关关闭 |
| -2 | AD_LOAD_FAILED | 广告加载失败 |
| -3 | AD_TIMEOUT | 广告加载超时 |
| -4 | NO_FULL_VIDEO | 无完整视频广告 |

---

## 注意事项

1. **隐私政策**: 必须在用户同意隐私政策后才能初始化SDK和请求广告
2. **OAID获取**: 需要用户授权OAID权限
3. **平台配置**: 各平台需要在各自后台配置应用和广告位
4. **测试模式**: 开发阶段可使用测试广告ID
5. **版本选择**: 推荐使用AdCoreV2模块，AdCore为旧版本

---

## 更新日志

### AdCoreV2 (2.0.0-alpha25)
- 重构架构，支持多平台聚合
- 新增降级策略和熔断机制
- 优化广告加载流程
- 改进错误处理

### AdCore (1.1.39-fix)
- 基础广告功能
- 单平台支持

---

*文档生成时间: 2026-05-26*
