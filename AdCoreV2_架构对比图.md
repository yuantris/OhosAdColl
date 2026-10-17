# AdCore V1 vs V2 架构对比图

## 一、整体架构对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           V1 架构 (单体式)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐                                                       │
│  │  ADHelper    │ ◄─── 核心入口 (22.38 KB)                                │
│  │  (单例)      │     包含大量业务逻辑                                      │
│  └──────┬───────┘                                                       │
│         │                                                               │
│         ├────────────────────────────────────────────────────────┐      │
│         │                                                        │      │
│         ▼                                                        ▼      │
│  ┌──────────────┐                                     ┌────────────────┐│
│  │ CsjHelper    │                                     │   ADControl    ││
│  │ HwAdHelper   │                                     │ AdCacheHelper  ││
│  │ TxHelper     │                                     │  AdLayout      ││
│  └──────────────┘                                     └────────────────┘│
│         ▼                                                       ▲       │
│  ┌──────────────┐                                               │       │
│  │各平台SDK直接调用│ ──────────────────────────────────────────────┘       │
│  │(穿山甲/华为/腾讯)│                                                │
│  └──────────────┘                                                │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               config层 (配置管理)                         │   │
│  │  AD.ts | ADConfig.ts | ADConfigBuilder.ts | ErrCode.ts │   │
│  └─────────────────────────────────────────────────────────┘   │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               application层 (应用层)                     │   │
│  │  RequestApplication | UnifiedRouteEvent                │   │
│  └─────────────────────────────────────────────────────────┘   │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               components层 (UI组件)                     │   │
│  │  AdLayout | SplashComponent | CustomDislikeComponent   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           V2 架构 (分层式)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐                                                       │
│  │  SDKCore     │ ◄─── SDK核心管理 (8.13 KB)                           │
│  │  (初始化层)  │     requestOFF() | requestEasyOFF()                  │
│  └──────┬───────┘                                                       │
│         │                                                              │
│         ▼                                                              │
│  ┌──────────────┐                                                       │
│  │  ADHelper    │ ◄─── 核心入口 (36.88 KB, 模块化重构)                  │
│  │  (单例)      │     平台健康检查 | 多平台管理                         │
│  └──────┬───────┘                                                       │
│         │                                                              │
│         ├──────────────────────────────────────────────────────────┐   │
│         │                                                          │   │
│         ▼                                                          ▼   │
│  ┌──────────────────────┐                              ┌─────────────────┐│
│  │    AdPlatformFactory  │◄──────────────────────────────│ V4Configuration ││
│  │    (工厂模式)         │                              │ AdStateManager  ││
│  └──────────┬───────────┘                              │ AdModeManager   ││
│             │                                          │ AdSlotManager   ││
│             │                                          └─────────────────┘│
│             ▼                                                    ▲     │
│  ┌──────────────────────┐     implements      ┌─────────────────┐     │
│  │    IAdPlatform       │◄───────────────────│ CsjAdPlatform   │     │
│  │    (平台抽象接口)     │                     │ HuaweiAdPlatform│     │
│  └──────────────────────┘                     │ TencentAdPlatform│     │
│             ▼                                 └─────────────────┘     │
│  ┌──────────────────────┐                              │              │
│  │   Manager层          │◄─────────────────────────────┘              │
│  │ ┌──────────────────┐│                                              │
│  │ │ SplashAdManager  ││  - 基于BaseAdManager                         │
│  │ │ VideoAdManager   ││  - 统一广告加载、展示、销毁接口              │
│  │ │InterstitialAdMgr ││  - 支持独立型广告(IndependentAd)            │
│  │ │  FeedAdManager   ││                                            │
│  │ └──────────────────┘│                                              │
│  └──────────────────────┘                                              │
│             ▼                                                          │
│  ┌──────────────────────┐                                              │
│  │   impl层 (接口实现)   │                                              │
│  │ ┌──────────────────┐│                                              │
│  │ │   IAd           ││                                              │
│  │ │ IndependentAd   ││                                              │
│  │ └──────────────────┘│                                              │
│  └──────────────────────┘                                              │
│             ▼                                                          │
│  ┌──────────────────────┐                                              │
│  │  network层 (网络层)   │                                              │
│  │  OhosRcp | NetBasic   │                                              │
│  └──────────────────────┘                                              │
│             ▼                                                          │
│  ┌──────────────────────┐                                              │
│  │  logger层 (日志层)    │                                              │
│  │  LogManager          │                                              │
│  └──────────────────────┘                                              │
│             ▼                                                          │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │              components层 (UI组件 - 重构升级)                   │     │
│  │  FeedAdComponent (V2) | SplashAdComponent (V2) | AdIdInfoComponent ││
│  └──────────────────────────────────────────────────────────────┘     │
│             ▼                                                          │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │              application层 (应用层)                            │     │
│  │  RequestApplication (V2) | SDKCore                             │     │
│  └──────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

## 二、核心模块对比

### 1. 核心入口层 (ADHelper)

| 特性        | V1                               | V2                                         |
|-----------|----------------------------------|--------------------------------------------|
| **文件大小**  | 22.38 KB                         | 36.88 KB                                   |
| **架构模式**  | 单体集中式                            | 模块化分层式                                     |
| **平台管理**  | 简单标志位(isHw/isTx/isCsj)           | Map映射(platformMap) + 平台健康检查                |
| **初始化方式** | `ADHelper.init(successCallback)` | `await ADHelper.getInstance().init()` (异步) |
| **广告加载**  | 直接调用Helper类方法                    | 通过Manager层间接调用                             |
| **平台切换**  | 手动判断标志位                          | 自动健康检查 + 失败计数 + 自动恢复                       |
| **缓存管理**  | AdCacheHelper独立管理                | Manager层统一管理                               |
| **重试机制**  | 简单重试                             | 智能重试 + 平台降级                                |

### 2. 平台抽象层

| 特性        | V1                            | V2                                               |
|-----------|-------------------------------|--------------------------------------------------|
| **抽象方式**  | 无抽象层                          | IAdPlatform接口                                    |
| **工厂模式**  | 无                             | AdPlatformFactory工厂                              |
| **平台实现**  | CsjHelper/HwAdHelper/TxHelper | CsjAdPlatform/HuaweiAdPlatform/TencentAdPlatform |
| **接口一致性** | 各Helper接口不统一                  | 统一IAdPlatform接口                                  |
| **扩展性**   | 难以扩展新平台                       | 易扩展(实现IAdPlatform接口)                             |
| **解耦度**   | 紧耦合(ADHelper直接调用)             | 松耦合(通过接口调用)                                      |

### 3. 广告管理层

| 特性            | V1               | V2                                                                                  |
|---------------|------------------|-------------------------------------------------------------------------------------|
| **管理方式**      | 无专门Manager层      | BaseAdManager + 各类型Manager                                                          |
| **Manager列表** | -                | - SplashAdManager<br>- VideoAdManager<br>- InterstitialAdManager<br>- FeedAdManager |
| **统一接口**      | 各Helper方法独立      | 继承BaseAdManager,统一接口<br>- loadAd()<br>- showAd()<br>- destroyAd()                   |
| **广告实例管理**    | 分散在Helper中       | Manager集中管理                                                                         |
| **独立广告支持**    | IndependentAd较简单 | Enhanced IndependentAd                                                              |

### 4. 配置管理层

| 特性        | V1             | V2                                            |
|-----------|----------------|-----------------------------------------------|
| **配置类**   | AD.ts (4.2 KB) | AD.ts (13.25 KB) + V4Configuration (26.58 KB) |
| **配置方式**  | 静态配置           | 动态配置 + 远程配置(AdHub)                            |
| **广告位管理** | 简单字符串          | AdSlotManager统一管理                             |
| **校验方式**  | 简单校验           | verifyConfigAD + verifyEasyConfigAD           |
| **测试支持**  | 无              | AdIdInfoComponent (调试组件)                      |

### 5. 网络请求层

| 特性        | V1                 | V2                              |
|-----------|--------------------|---------------------------------|
| **网络库**   | @zycore/network    | @creative/net + OhosRcp         |
| **请求方式**  | requestAdOff()     | requestOFF() + requestEasyOFF() |
| **协议版本**  | V4                 | V4 + V5 (双协议)                   |
| **网络层封装** | 简单封装               | NetBasic + OhosRcp分层封装          |
| **日志管理**  | @zycore/common的Log | 独立LogManager                    |

### 6. SDK核心层

| 特性         | V1                           | V2                                                |
|------------|------------------------------|---------------------------------------------------|
| **核心类**    | ADHelper承担核心功能               | SDKCore独立类 (8.13 KB)                              |
| **初始化流程**  | ADHelper.init()              | SDKCore.requestOFF() → V4Configuration配置 → 初始化各平台 |
| **应用管理**   | RequestApplication (5.86 KB) | RequestApplication (12.46 KB) + SDKCore           |
| **生命周期管理** | UnifiedRouteEvent            | HotStartManager (热启动管理)                           |
| **隐私授权**   | 简单检查                         | 严格的隐私授权流程                                         |

### 7. UI组件层

| 特性        | V1                                                          | V2                                                                               |
|-----------|-------------------------------------------------------------|----------------------------------------------------------------------------------|
| **组件数量**  | 较少                                                          | 优化升级                                                                             |
| **核心组件**  | - AdLayout<br>- SplashComponent<br>- CustomDislikeComponent | - SplashAdComponent (V2)<br>- FeedAdComponent (V2)<br>- AdIdInfoComponent (调试组件) |
| **组件封装度** | 通用组件                                                        | 独立型组件 + 独立广告实例                                                                   |
| **调试支持**  | 无                                                           | AdIdInfoComponent (debug环境显示广告信息)                                                |

## 三、设计模式对比

### V1采用的设计模式：
- **单例模式** - ADHelper
- **策略模式** - 简单的多平台切换(标志位)
- **观察者模式** - UnifiedRouteEvent

### V2采用的设计模式：
- **单例模式** - ADHelper, AdSlotManager
- **工厂模式** - AdPlatformFactory
- **策略模式** - IAdPlatform接口 + 平台切换
- **管理器模式** - BaseAdManager + 各类Manager
- **状态模式** - AdStateManager
- **建造者模式** - ADConfigBuilder
- **适配器模式** - IndependentAd适配不同广告类型
- **观察者模式** - OnAdListener, OnVideoRewardListener

## 四、关键架构改进

### 1. 平台抽象层 (V2新增)
```
V1: ADHelper → CsjHelper/HwAdHelper/TxHelper → 各平台SDK
V2: ADHelper → AdPlatformFactory → IAdPlatform接口
                ↓                ↓
          CsjAdPlatform   HuaweiAdPlatform   TencentAdPlatform
                ↓                ↓                ↓
          各平台SDK封装   各平台SDK封装    各平台SDK封装
```

**优势：**
- 统一接口,易于扩展新平台
- 平台解耦,降低维护成本
- 易于测试(Mock平台)

### 2. 管理器模式 (V2新增)
```
V1: ADHelper直接调用Helper方法
     ↓
  loadSplashAd() → CsjHelper.loadSplashAd()

V2: ADHelper → Manager层 → Platform
     ↓              ↓           ↓
  loadSplashAd() → SplashAdManager → HuaweiAdPlatform.createSplashAd()
                                        → IndependentAd
```

**优势：**
- 职责分离,广告生命周期管理独立
- 统一接口,不同类型广告操作一致
- 易于扩展新广告类型

### 3. 状态管理 (V2新增)
```
V2新增类:
- AdStateManager: 管理SDK状态
- AdModeManager: 管理广告模式
- HotStartManager: 管理热启动
```

### 4. 广告位管理 (V2优化)
```
V1: 字符串存储广告位ID
V2: AdSlotManager统一管理
    - Map<广告类型, Map<平台类型, 广告位ID>>
    - 支持动态更新
    - 支持测试广告ID切换
```

## 五、目录结构对比

### V1目录结构：
```
AdCore/
├── config/             # 配置层
│   ├── AD.ets
│   ├── ADConfig.ts
│   ├── ADConfigBuilder.ets
│   └── ErrCode.ets
├── helper/             # 核心层
│   ├── ADHelper.ets
│   ├── ADControl.ets
│   ├── AdCacheHelper.ets
│   ├── CsjHelper.ets
│   ├── HwAdHelper.ets
│   └── TxHelper.ets
├── components/         # UI组件
│   ├── AdLayout.ets
│   ├── SplashComponent.ets
│   └── CustomDislikeComponent.ets
└── application/        # 应用层
    ├── RequestApplication.ets
    └── UnifiedRouteEvent.ets
```

### V2目录结构：
```
AdCoreV2/
├── helper/
│   ├── core/            # 核心层
│   │   ├── ADHelper.ets
│   │   ├── AdPlatformFactory.ets
│   │   ├── V4Configuration.ets
│   │   ├── AdStateManager.ets
│   │   ├── AdModeManager.ets
│   │   ├── AdSlotManager.ets
│   │   └── HotStartManager.ets
│   ├── impl/            # 接口实现
│   │   ├── IAdPlatform.ts
│   │   ├── IAd.ts
│   │   └── IndependentAd.ts
│   ├── manager/         # 管理器层
│   │   ├── BaseAdManager.ets
│   │   ├── SplashAdManager.ets
│   │   ├── VideoAdManager.ets
│   │   ├── InterstitialAdManager.ets
│   │   └── FeedAdManager.ets
│   ├── platform/        # 平台实现
│   │   ├── CsjAdPlatform.ets
│   │   ├── HuaweiAdPlatform.ets
│   │   ├── TencentAdPlatform.ets
│   │   ├── csj/
│   │   ├── huawei/
│   │   └── tencent/
│   ├── network/         # 网络层
│   │   ├── APIs.ts
│   │   ├── NetBasic.ts
│   │   └── OhosRcp.ts
│   ├── cache/           # 缓存层
│   │   └── AdCache.ts
│   ├── const/           # 常量
│   │   ├── AdHub.ts
│   │   ├── ErrCode.ts
│   │   └── SDKConst.ts
│   ├── entity/          # 实体
│   │   ├── AppPckInfoResp.ets
│   │   ├── ResultDto.ets
│   │   └── ZyOFF.ets
│   ├── error/           # 错误处理
│   │   └── RuntimeError.ets
│   └── logger/          # 日志
│       └── LogManager.ts
├── application/         # 应用层
│   ├── RequestApplication.ets
│   └── SDKCore.ets
└── components/          # UI组件
    ├── SplashAdComponent.ets
    ├── FeedAdComponent.ets
    └── debug/
        └── AdIdInfoComponent.ets
```

## 六、代码质量对比

| 指标        | V1        | V2                   |
|-----------|-----------|----------------------|
| **代码行数**  | ~5000行    | ~8000行               |
| **文件数量**  | 59个.ets文件 | 41个.ets文件 + 22个.ts文件 |
| **模块化程度** | 中等        | 高(分层清晰)              |
| **可测试性**  | 中等        | 高(依赖注入,接口抽象)         |
| **可维护性**  | 中等        | 高(职责分离)              |
| **扩展性**   | 中等        | 高(工厂模式,接口抽象)         |
| **代码复用性** | 中等        | 高(Manager层抽象)        |

## 七、功能对比

### 基础功能 (V1已有)
✅ 开屏广告
✅ 插屏广告
✅ 信息流广告
✅ 激励视频广告
✅ 多平台支持(穿山甲、腾讯、华为)
✅ 广告缓存
✅ 热启动广告
✅ 隐私授权

### V2新增/优化功能
✅ **平台健康检查机制** - 自动检测平台可用性
✅ **多平台智能切换** - 失败自动切换其他平台
✅ **平台自动恢复** - 失败后定期检查恢复
✅ **独立型广告** - IndependentAd更完善的封装
✅ **测试广告ID** - 调试环境自动切换测试ID
✅ **广告位动态管理** - AdSlotManager统一管理
✅ **调试信息组件** - AdIdInfoComponent显示当前广告信息
✅ **双协议支持** - V4 + V5协议
✅ **网络层重构** - OhosRcp更高效的网络请求
✅ **日志系统** - LogManager统一日志管理
✅ **状态管理** - AdStateManager统一状态管理
✅ **热启动优化** - HotStartManager独立管理

## 八、性能对比

| 指标         | V1   | V2              |
|------------|------|-----------------|
| **初始化速度**  | 基准   | 优化(异步初始化)       |
| **广告加载速度** | 基准   | 优化(平台健康检查+智能切换) |
| **内存占用**   | 较低   | 略高(多一层抽象,但可控)   |
| **包体积**    | 基准   | 略增(新功能+调试组件)    |
| **广告成功率**  | 基准   | 提升(多平台+智能切换)    |
| **故障恢复**   | 手动重启 | 自动恢复            |

## 九、开发体验对比

| 方面         | V1   | V2                     |
|------------|------|------------------------|
| **集成复杂度**  | 简单   | 简单(接口统一)               |
| **API易用性** | 中等   | 高(异步+类型安全)             |
| **文档完整性**  | 一般   | 完善(README + 接入说明)      |
| **调试支持**   | 基本日志 | AdIdInfoComponent可视化调试 |
| **错误处理**   | 简单   | 完善的ErrCode + 日志系统      |
| **类型安全**   | 中等   | 高(更多TypeScript接口)      |

## 十、总结

### V1架构特点：
- ✅ 简单直接,易于理解
- ✅ 快速上手,集成简单
- ✅ 代码量较少,包体积小
- ❌ 耦合度高,难以扩展
- ❌ 缺乏平台抽象,维护成本高
- ❌ 错误处理简单,调试困难

### V2架构特点：
- ✅ 分层清晰,职责分离
- ✅ 平台抽象,易于扩展
- ✅ 智能切换,成功率高
- ✅ 完善的日志和调试工具
- ✅ 健壮的错误处理和恢复机制
- ❌ 代码量增加,学习曲线略陡
- ❌ 多层抽象,包体积略增

### 适用场景：

**V1适用于：**
- 简单项目,不需要多平台智能切换
- 对包体积敏感
- 快速原型开发
- 广告类型单一

**V2适用于：**
- 商业项目,需要高广告成功率
- 需要多平台智能切换
- 需要完善的调试和日志
- 需要长期维护和扩展
- 复杂的广告业务场景

### 升级建议：

从V1升级到V2的主要改动：
1. **API改动** - `ADHelper.init()` → `await ADHelper.getInstance().init()`
2. **组件改动** - `SplashComponent` → `SplashAdComponent`
3. **配置改动** - 新增 `SDKCore.requestOFF()` 远程配置
4. **兼容性** - V2保持向后兼容,逐步迁移

---

**文档版本**: 1.0
**生成时间**: 2026-01-26
**项目**: OhosAdCore - 鸿蒙广告SDK
**版本对比**: AdCore V1 vs AdCoreV2
