# AdCoreV2 SDK接入说明

## 1. 项目介绍

AdCoreV2是掌赢的鸿蒙平台广告SDK

## 2. 快速开始

### 2.1 环境要求

- HarmonyOS SDK版本：API 12+

### 2.2 集成方式

在项目的`oh-package.json`文件中添加依赖：

```json
{
  "dependencies": {
    "@zysdk/ad-core-hm": "2.0.0-alpha15"
  }
}
```

### 2.3 权限配置

在项目的`module.json5`文件中添加必要的权限：

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO"
      },
    ]
  }
}
```

## 3. RequestApplication配置

`RequestApplication` 是一个抽象类，继承自 `AbilityStage`，用于管理应用全局状态和生命周期。SDK 内部依赖 `RequestApplication`
来处理应用的生命周期事件、热启动广告等功能。

### 3.1 功能说明

- 管理应用全局状态和生命周期
- 处理热启动广告逻辑
- 初始化应用配置
- 管理全局UI上下文
- 处理应用前后台切换事件

### 3.2 使用方法

#### 3.2.1 继承实现RequestApplication

应用需要创建自己的 Application 类，继承自 `RequestApplication`，并实现必要的抽象方法。

> ⚠️ **重要注意事项：**
> 1. 非必要不要重写`onCreate()`方法，可用`preInitFinish()`替代
> 2. 如必须重写`onCreate()`，则需要主动调用`super.onCreate()`，否则会导致SDK无法正常工作。

#### 3.2.2 示例代码

```typescript
import { AppConfig, RequestApplication } from '@zysdk/ad-core-hm';

export class MyApplication extends RequestApplication {
  /**
   * 获取应用配置
   * 必须实现此方法，返回应用的配置信息
   */
  getAppConfig(): AppConfig {
    const appConfig = new AppConfig();

    // 设置主页面路径（过时，可不配置）
    appConfig.setMainPage('pages/MainPage');

    // 设置引导页路径（过时，可不配置）
    appConfig.setGuidePage('pages/GuidePage');

    // 设置启动页背景图，SDK会用到做为背景（必须配置）
    appConfig.setLauncherBgRes($r('app.media.app_start'));

    // 设置广告显示等待时间（毫秒），非必要不可修改，默认60s
    appConfig.setAdShowWaitingTime(3000);

    // 如果需要自定义开屏广告事件处理，可以设置事件处理器（过时，可不配置）
    // appConfig.setSplashEventHandler(new MySplashEventHandler());

    return appConfig;
  }

  /**
   * 预初始化完成回调
   * 必须实现此方法，预初始化完成后会调用
   */
  preInitFinish(): void {
    // 预初始化完成后的逻辑
    console.log('MyApplication preInitFinish');
  }
}
```

#### 3.2.3 配置module.json5

在应用的 `module.json5` 文件中，需要配置 `srcEntry` 指向自定义的 Application 类：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "srcEntry": "./ets/MyApplication.ets"
    // 其他配置...
  }
}
```

### 3.3 注意事项

1. **必须实现抽象方法**：`getAppConfig()` 和 `preInitFinish()` 是抽象方法，必须在子类中实现
2. **正确配置module.json5**：确保 `srcEntry` 配置正确，否则 SDK 无法正常工作
3. **设置必要的配置项**：至少需要设置启动页背景图

## 4. SDK初始化

SDK初始化需要在应用启动时进行，建议在Splash页面的`aboutToAppear`方法中初始化。

> ⚠️ **重要注意事项：**
> 必须在用户同意隐私协议后才能进行SDK初始化，否则可能导致合规问题。

### 4.1 初始化示例

```typescript
import {
  AD, ADHelper, OnAdListener, PlatformConfig, PlatformType,
} from '@zysdk/ad-core-hm';

@Entry
@Component
struct Splash {
  async aboutToAppear() {
    // 异步初始化广告SDK
    await ADHelper.getInstance().init();
  }
}
```

## 5. 功能模块

### 5.1 开屏广告

开屏广告是应用启动时展示的全屏广告，展示完成后自动关闭或跳转到主页面。

#### 5.1.1 使用示例

```typescript
import {
  AD,
  ADHelper,
  IndependentAd,
  OnAdListener,
  PlatformConfig,
  PlatformType,
  SplashAdComponent
} from '@zysdk/ad-core-hm';

@Entry
@Component
struct Splash {
  @State ad: IndependentAd | undefined = undefined;
  // 广告监听器
  private adListener: OnAdListener = {
    onAdClose: () => {
      // 广告关闭，跳转到主页面
      router.replaceUrl({ url: 'pages/Index' });
    },
    onAdShowError: (code: number, msg: string) => {
      // 广告异常，跳转到主页面
      router.replaceUrl({ url: 'pages/Index' });
    }
  };

  async aboutToAppear() {
    // SDK初始化代码...
    
    // 加载广告并获取实例
    this.ad = await ADHelper.getInstance().loadSplashAd(this.adListener);
  }

  build() {
    Column() {
      SplashAdComponent({
        ad: this.ad,
        adListener: this.adListener
      })
    }
    .backgroundImage($r('app.media.app_start'))
    .backgroundImageSize(ImageSize.FILL)
  }
}
```

#### 5.1.2 主要方法

| 方法           | 说明     | 参数                     | 返回值                    |
|--------------|--------|------------------------|------------------------|
| loadSplashAd | 加载开屏广告 | listener: OnAdListener | Promise<IndependentAd> |

### 5.2 插屏广告

插屏广告是在应用使用过程中弹出的半屏或全屏广告，用户可以关闭或点击。

#### 5.2.1 使用示例

```typescript
import { ADHelper, AdConfig, AdType } from '@zysdk/ad-core-hm';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 加载插屏广告
    ADHelper.getInstance().loadInterstitialAd();
  }
}
```

#### 5.2.2 主要方法

| 方法                 | 说明     | 参数                                    | 返回值                    |
|--------------------|--------|---------------------------------------|------------------------|
| loadInterstitialAd | 加载插屏广告 | adId: string, listener?: OnAdListener | Promise<IndependentAd> |

### 5.3 信息流广告

信息流广告是嵌入在应用内容流中的广告，与应用内容融合度高，用户体验好。

#### 5.3.1 使用示例

```typescript
import { FeedAdComponent } from '@zysdk/ad-core-hm';

@Entry
@Component
struct ExpressCheck {
  build() {
    Scroll() {
      Column() {
        // 信息流广告组件
        FeedAdComponent({
          adId: 'info',
          uniqueId: "express_home",
          adWidth: '100%',
          bgColor: Color.White,
          radius: 12
        })
      }
    }
  }
}
```

#### 5.3.2 组件属性

| 属性       | 类型     | 说明                    |
|----------|--------|-----------------------|
| adId     | string | 广告位ID                 |
| uniqueId | string | 广告唯一标识，用于区分不同位置的信息流广告 |
| adWidth  | string | 广告宽度，默认为'100%'        |
| bgColor  | Color  | 广告背景色，默认为Color.White  |
| radius   | number | 广告圆角半径，默认为0           |

### 5.4 激励视频广告

激励视频广告是用户观看完整视频后获得奖励的广告形式，常用于解锁功能、获取虚拟货币等场景。

#### 5.4.1 使用示例

```typescript
import { ADHelper, OnVideoRewardListener } from '@zysdk/ad-core-hm';

function getAd(oid: string, phone: string | null, loadingDialog: CustomDialogController): void {
  // 加载并展示激励视频广告
  ADHelper.getInstance().loadVideoAd("video", {
    onVideoComplete: () => {
      // 视频观看完成，执行奖励逻辑
      search(oid, phone, loadingDialog);
    },
    onVideoError: (code, msg) => {
      console.error("激励视频错误", `code: ${code}, msg: ${msg}`);
    },
    onVideoClick: () => {
      console.log("激励视频点击");
    },
    onVideoShow: () => {
      console.log("激励视频展示");
    }
  });
}
```

#### 5.4.2 主要方法

| 方法          | 说明       | 参数                                                   | 返回值                    |
|-------------|----------|------------------------------------------------------|------------------------|
| loadVideoAd | 加载激励视频广告 | adId: string, rewardListener?: OnVideoRewardListener | Promise<IndependentAd> |

## 6. API参考

### 6.1 主要类说明

| 类名                    | 说明                       |
|-----------------------|--------------------------|
| AD                    | 广告配置类，包含广告平台ID、开关状态等配置信息 |
| ADHelper              | 广告帮助类，提供广告初始化、加载、展示等核心功能 |
| IndependentAd         | 独立广告类，封装了不同类型广告的通用方法     |
| OnAdListener          | 广告监听器，用于接收广告事件回调         |
| OnVideoRewardListener | 激励视频监听器，用于接收激励视频事件回调     |
| SplashAdComponent     | 开屏广告组件，用于展示开屏广告          |
| FeedAdComponent       | 信息流广告组件，用于展示信息流广告        |

### 6.2 主要方法说明

#### ADHelper.getInstance()

获取ADHelper单例实例。

#### ADHelper.init()

初始化广告SDK。

#### ADHelper.loadSplashAd(listener?: OnAdListener)

加载开屏广告。

#### ADHelper.loadInterstitialAd(adId: string, listener?: OnAdListener)

加载插屏广告。

#### ADHelper.loadVideoAd(adId: string, rewardListener?: OnVideoRewardListener)

加载激励视频广告。

## 7. 常见问题

### 7.1 广告加载失败

- 检查广告平台配置是否正确
- 检查网络连接是否正常
- 检查广告位ID是否正确
- 检查广告平台是否返回了广告

### 6.2 广告无法展示

- 检查广告是否已经加载成功
- 检查广告是否已经过期
- 检查设备是否支持广告展示

## 8. 版本更新记录

### v1.0.0-alpha1

- 初始版本，支持开屏广告、插屏广告、信息流广告和激励视频广告
- 支持穿山甲、腾讯、华为三个广告平台(腾讯暂未 支持，增加中)
- 支持多平台切换和广告位管理

### v1.0.0-alpha2

- 增加友盟初始化相关代码

### v1.0.0-alpha3

- 修改`FeedAdLayout`->`FeedAdComponent`，统一SDK组件命名格式
- 导出`ErrCode`，激励视频可根据`ErrCode.NO_FULL_VIDEO`的值来判断未完整观看激励视频的业务逻辑

### v1.0.0-alpha4

- 优化网络请求日志输出

### v1.0.0-alpha5

- 腾讯广告平台基础集成
- 修复穿山甲激励视频不回调的问题

### v1.0.0-alpha6

- `SplashAdComponent`增加广告超时机制，超时后回调`onAdShowError()`

### v1.0.0-alpha7

- 修复`IndependentAd`系广告展示时，重试机制致实例销毁，导致后续异步中调用的`getCurrentAd()`为null问题

### v1.0.0-alpha8

- 增加Failed to load ad from all platforms后回调`onAdShowError`

### v1.0.0-alpha9

- 修复腾讯开屏回调子线程的导致方法内路由失效问题
- 新增穿山甲自动获取OAID
- 更新穿山甲版本为`7.3.0`

### v2.0.0-alpha1

- 版本创建

### v2.0.0-alpha2

- 增加`AdIdInfoComponent`组件，展示当前广告信息，只在`debug`环境展示

### v2.0.0-alpha3

- 修复热启动页面广告加载错误不销毁的问题

### v2.0.0-alpha4

- 编译版本降回`5.0.0(12)`

### v2.0.0-alpha5

- 修复广告开关关闭时`IndependentAd`系广告无回调问题

### v2.0.0-alpha8

- 修复信息流小图加载异常问题

### v2.0.0-alpha9

- 修复`AdIdInfoComponent`组件在极端情况下异常问题

### v2.0.0-alpha10

- 增加`NetBasic`导出

### v2.0.0-alpha11

- 增加`OAID`存储`AD`

### v2.0.0-alpha12

- 增加只有开启未完整观看激励视频回调`onVideoError`

### v2.0.0-alpha13

- `FeedAdComponent`组件升级V2
- `SplashAdComponent`组件升级V2

### v2.0.0-alpha15

- 优化`zyClient`请求方法，传递`params`参数

### v2.0.0-alpha16

- 优化`AdIdInfoComponent`组件