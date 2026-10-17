/**
 * RequestApplication类
 * 继承自AbilityStage，用于管理应用全局状态和生命周期
 */
import { AbilityLifecycleCallback, AbilityStage, bundleManager, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { AppConfig } from './AppConfig';
import { LogManager } from '../helper/logger/LogManager';
import { HotStartManager } from '../helper/core/HotStartManager';
import { V4ConfigParser } from '../helper/core/V4ConfigParser';
import { EasyConfigParser } from '../helper/core/EasyConfigParser';
import { TokenCalculator } from '../helper/core/TokenCalculator';
import ADUtil from '../utils/ADUtil';
import { RuntimeError } from '../helper/error/RuntimeError';
import { ErrCode } from '../helper/const/ErrCode';
import { AdIdStore } from '../helper/core/AdIdStore';
import { AdSwitchManager } from '../helper/core/AdSwitchManager';
import { NetBasic } from '../helper/network/NetBasic';
import { DeviceUtils, Ohos } from '@zycore/common';
import { InternalPlugin, preInit } from '@umeng/analytics';
import { SDKConst } from '../helper/const/SDKConst';
import { TestLog } from '../test/TestLogEnvironment';
import { LifecycleManager } from '../helper/core/LifecycleManager';
import { setNetContext } from '../helper/network/OhosRcp';
import { ZyNetLogger, setNetLogEnabled, setNetLogMask } from '@creative/net';


export abstract class RequestApplication extends AbilityStage {
  /**
   * 全局UI上下文
   */
  public static uiContext: UIContext;
  /**
   * 应用配置
   */
  public static appConfig: AppConfig;
  /**
   * 生命周期回调ID
   */
  private lifecycleId: number = 0;
  /**
   * 窗口舞台对象
   */
  private static windowStage: window.WindowStage;
  /**
   * RequestApplication实例引用
   */
  private static instance: RequestApplication;

  /**
   * AbilityStage创建时调用
   */
  public onCreate(): void {
    const applicationContext = this.context.getApplicationContext();
    this.lifecycleId = applicationContext.on('abilityLifecycle', abilityLifecycleCallback);

    setNetContext(this.context)
    // 日志按 debug 分流：debug 开启 pretty+明文；release 关闭请求日志并强制脱敏
    const netDebug: boolean = Ohos.debug();
    ZyNetLogger.setPretty(netDebug);
    setNetLogEnabled(netDebug);
    setNetLogMask(!netDebug);

    // 保存实例引用
    RequestApplication.instance = this;

    // 初始化应用配置
    RequestApplication.appConfig = this.getAppConfig();

    // 友盟预初始化
    preInit({
      context: this.context.getApplicationContext(),
      plugins: [new InternalPlugin()]
    })

    // 预初始化开始回调
    this.preInitBefore();

    // 验证必填配置
    this.validateConfig();

    // 自动网络配置
    this.autoNetworkConfig();

    // 预初始化完成回调
    this.preInitFinish();
  }

  /**
   * AbilityStage销毁时调用
   */
  onDestroy(): void {
    LogManager.info('RequestApplication', 'onDestroy');

    // 取消应用生命周期回调
    this.context.getApplicationContext().off('abilityLifecycle', this.lifecycleId);
  }

  /**
   * 验证应用配置
   */
  private validateConfig(): void {
    try {
      LogManager.debug('RequestApplication', '[ validateConfig ] 开始广告配置')
      if (!AdSwitchManager.enableEasyConfig) {
        // 配置[info.json]
        V4ConfigParser.configAdSwitchManager(JSON.parse(ADUtil.readInfoJsonString(this.context))[0])
      } else {
        // 配置云创[info.json]
        EasyConfigParser.configEasyAdSwitchManager(JSON.parse(ADUtil.readInfoJsonString(this.context)))
      }
      LogManager.debug('RequestApplication', '[ validateConfig ] 结束广告配置')
    } catch (err) {
      throw new RuntimeError(ErrCode.CONFIG_INFO, "infojson解析失败");
    }

    if (!RequestApplication.appConfig.getSplashEventHandler()) {
      if (!RequestApplication.appConfig.getMainPage()) {
        // throw new Error('请在getAppConfig回调中设置setMainPage');
      }

      if (!RequestApplication.appConfig.getGuidePage()) {
        // throw new Error('请在getAppConfig回调中设置setGuidePage');
      }
    }
  }

  /**
   * 自动网络配置
   */
  private autoNetworkConfig() {
    if (AdSwitchManager.enableAutoNetConfig) {
      try {
        const v4It = TokenCalculator.getV4It()
        const sv = TokenCalculator.parseSV(TokenCalculator.getSdkParams())
        LogManager.warn('RequestApplication',
          `APPID:${AdIdStore.APPID}, VID:${AdIdStore.VID}, SID:${AdIdStore.SID}, V4IT:${v4It}, SV:${sv}`);

        // 网络配置项（空字面量 + 索引赋值，规避 ArkTS 对 Record 非空字面量的限制）
        const netConfig: Record<string, string> = {};
        netConfig['SID'] = AdIdStore.SID;
        netConfig['SV'] = sv;
        netConfig['IT'] = v4It;
        netConfig['MARKET_NAME'] = DeviceUtils.getDisplayVersion().replace(/\(.*?\)/, '');
        netConfig['PACKAGE_NAME'] = Ohos.getBundleName();
        netConfig['DEVICE_ID'] = DeviceUtils.getDeviceId();
        NetBasic.setAllConfig(netConfig);

        LogManager.warn('SDKCore', '【SDK自动网络配置初始化成功✅】')
      } catch (err) {
        LogManager.error('SDKCore', `网络初始化错误❌`, err)
      }
    } else {
      LogManager.warn('SDKCore', `【SDK自动网络配置处于关闭状态，请手动初始化网络配置⚠️】`)
    }
  }

  /**
   * 获取应用配置
   * 抽象方法，由子类实现
   */
  abstract getAppConfig(): AppConfig;

  /**
   * 预初始化开始回调
   * 抽象方法，由子类实现
   */
  abstract preInitBefore(): void;

  /**
   * 预初始化完成回调
   * 抽象方法，由子类实现
   */
  abstract preInitFinish(): void;

  /**
   * 撤消隐私授权回调
   * 抽象方法，由子类实现
   */
  abstract clearAllData(): void;

  /**
   * 静态方法，用于调用子类实现的clearAllData方法
   * SDK内部可以通过此方法调用业务层的clearAllData实现
   */
  public static clearAllData(): void {
    if (RequestApplication.instance) {
      RequestApplication.instance.clearAllData();
    } else {
      LogManager.error('RequestApplication', 'clearAllData: instance not initialized');
    }
  }

  /**
   * 设置窗口舞台
   * @param windowStage 窗口舞台对象
   */
  public static setWindowStage(windowStage: window.WindowStage): void {
    RequestApplication.windowStage = windowStage;
  }

  /**
   * 获取窗口舞台
   * @returns 窗口舞台对象
   */
  public static getWindowStage(): window.WindowStage | undefined {
    return RequestApplication.windowStage;
  }

  /**
   * 处理热启动逻辑
   */
  public static handleWarmStart(): void {
    const currentTime = Date.now();
    const lastBackgroundTime = SDKConst.getLastBackgroundTime();
    const timeDiff = currentTime - lastBackgroundTime;

    if (lastBackgroundTime > 0 && timeDiff > RequestApplication.appConfig.getAdShowWaitingTime()) {
      LogManager.info('handleWarmStart', `Warm start detected, time diff: ${timeDiff}ms`);
      // 触发热启动广告逻辑
      // ADHelper.getInstance().warmStart();
      HotStartManager.pushSplashAdPage()
        .catch((err: BusinessError) => {
          LogManager.error('handleWarmStart', "热启动异常", err)
        })
    }

    SDKConst.updateBackgroundTime(0);
  }
}

/**
 * 应用生命周期回调
 */
const abilityLifecycleCallback: AbilityLifecycleCallback = {
  /**
   * 应用创建时调用
   * @param ability 应用对象
   */
  onAbilityCreate(ability: UIAbility): void {
    LogManager.info('RequestApplication',
      `${bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
        .name} Ability onCreate`)
    // 掌赢通用库初始化
    Ohos.init(ability.context)
    // 测试日志配置环境信息
    TestLog.updateMode(ability)
  },

  /**
   * 窗口舞台创建时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageCreate(ability: UIAbility, windowStage: window.WindowStage): void {
    LogManager.debug('RequestApplication', 'onWindowStageCreate');

    // 保存窗口舞台对象
    RequestApplication.setWindowStage(windowStage);

    // 将窗口舞台传递给ADHelper
    // ADHelper.getInstance().setWindowStage(windowStage);
  },

  /**
   * 窗口舞台激活时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageActive(ability: UIAbility, windowStage: window.WindowStage): void {
    LogManager.debug('RequestApplication', 'onWindowStageActive');

    // 获取UI上下文
    windowStage.getMainWindow().then((mainWindow) => {
      // 保存全局UI上下文
      try {
        RequestApplication.uiContext = mainWindow.getUIContext();
      } catch (error) {
        LogManager.error('RequestApplication', `Failed to get UIContext: ${error}`);
      }
      // LogManager.info('RequestApplication', 'UIContext obtained successfully');
    }).catch((error: BusinessError) => {
      LogManager.error('RequestApplication', `Failed to get UIContext: ${error}`);
    });

    // 处理热启动逻辑
    RequestApplication.handleWarmStart();

    // 分发窗口活跃事件到已注册的组件
    LifecycleManager.getInstance().dispatchWindowStageActive(ability, windowStage);
  },

  /**
   * 窗口舞台失活时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageInactive(ability: UIAbility, windowStage: window.WindowStage): void {
  },

  /**
   * 窗口舞台销毁时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageDestroy(ability: UIAbility, windowStage: window.WindowStage): void {
    // 清除窗口舞台对象
    RequestApplication.setWindowStage(undefined as ESObject);
  },

  /**
   * 应用销毁时调用
   * @param ability 应用对象
   */
  onAbilityDestroy(ability: UIAbility): void {
  },

  /**
   * 应用进入前台时调用
   * @param ability 应用对象
   */
  onAbilityForeground(ability: UIAbility): void {
    LogManager.info('RequestApplication',
      `${bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
        .name} onAbilityForeground`)
  },

  /**
   * 应用进入后台时调用
   * @param ability 应用对象
   */
  onAbilityBackground(ability: UIAbility): void {
    // 记录后台时间（热启动开屏判定依赖此时间）
    LogManager.info('RequestApplication',
      `${bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
        .name} onAbilityBackground`)
    SDKConst.updateBackgroundTime(Date.now());
  },

  /**
   * 应用继续时调用
   * @param ability 应用对象
   */
  onAbilityContinue(ability: UIAbility): void {
  },

  /**
   * 新Want请求时调用
   * @param ability 应用对象
   */
  onNewWant(ability: UIAbility): void {
  },

  /**
   * 即将收到新Want时调用
   * @param ability 应用对象
   */
  onWillNewWant(ability: UIAbility): void {
  },

  /**
   * 应用即将创建时调用
   * @param ability 应用对象
   */
  onAbilityWillCreate(ability: UIAbility): void {
  },

  /**
   * 窗口舞台即将创建时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageWillCreate(ability: UIAbility, windowStage: window.WindowStage): void {
  },

  /**
   * 窗口舞台即将销毁时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageWillDestroy(ability: UIAbility, windowStage: window.WindowStage): void {
  },

  /**
   * 应用即将销毁时调用
   * @param ability 应用对象
   */
  onAbilityWillDestroy(ability: UIAbility): void {
  },

  /**
   * 应用即将进入前台时调用
   * @param ability 应用对象
   */
  onAbilityWillForeground(ability: UIAbility): void {
  },

  /**
   * 应用即将进入后台时调用
   * @param ability 应用对象
   */
  onAbilityWillBackground(ability: UIAbility): void {
  },

  /**
   * 应用即将继续时调用
   * @param ability 应用对象
   */
  onAbilityWillContinue(ability: UIAbility): void {
  },

  /**
   * 窗口舞台即将恢复时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageWillRestore(ability: UIAbility, windowStage: window.WindowStage): void {
  },

  /**
   * 窗口舞台恢复时调用
   * @param ability 应用对象
   * @param windowStage 窗口舞台对象
   */
  onWindowStageRestore(ability: UIAbility, windowStage: window.WindowStage): void {
  },

  /**
   * 应用即将保存状态时调用
   * @param ability 应用对象
   */
  onAbilityWillSaveState(ability: UIAbility): void {
  },

  /**
   * 应用保存状态时调用
   * @param ability 应用对象
   */
  onAbilitySaveState(ability: UIAbility): void {
  }
}