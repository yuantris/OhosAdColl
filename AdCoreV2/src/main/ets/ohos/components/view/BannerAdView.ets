import { ADHelper } from '../../helper/core/ADHelper';
import { AdType } from '../../model/AdType';
import { AdSwitchManager } from '../../helper/core/AdSwitchManager';
import { VIPRepo } from '../../storage/VIPData';
import { ExclusiveNotification } from '../../utils/ExclusiveNotification';
import { AdStateManager } from '../../helper/core/AdStateManager';
import { AdSlotManager } from '../../helper/core/AdSlotManager';
import { GlobalAdLoadLogStore } from '../../helper/core/GlobalAdLoadLogStore';
import { AdAttemptRecord, AdAttemptResult, RetryType } from '../../model/AdAttemptRecord';
import { OAIDStore } from '../../helper/core/OAIDStore';
import { AdIdStore } from '../../helper/core/AdIdStore';
import { PlatformType } from '../../model/PlatformType';
import { ErrCode } from '../../helper/const/ErrCode';
import { LogManager } from '../../helper/logger/LogManager';
import { advertising, AutoAdComponent } from '@kit.AdsKit';
import { AdLoadLogComponent } from '../debug/AdLoadLogComponent';
import { AdDebugToggle } from '../debug/AdDebugToggle';
import { Ohos } from '@zycore/common';
import { TestAdRepo } from '../../storage/TestAdControl';

const TAG = 'BannerAdView';
// 华为Ads Kit横幅广告类型值
const HW_BANNER_AD_TYPE = 8;
// 横幅广告位标准宽度(vp)，官方仅支持360*57和360*144两种尺寸
const HW_BANNER_WIDTH = 360;
// 华为测试专用广告位ID，仅debug模式兜底使用
const HW_TEST_BANNER_AD_ID = 'h5xkz3mbr2';
// 轮播时间边界(ms)，官方取值范围[30000, 120000]
export const MIN_REFRESH_TIME = 30000;
export const MAX_REFRESH_TIME = 120000;
// 可见性检测比例与更新间隔
const VISIBLE_RATIOS = [0.0, 1.0];

@ComponentV2
export struct BannerAdView {
  /**
   * 逻辑广告槽位，对应云创配置modules.ban中的adId，通常为'ban'
   */
  @Require @Param adId: string;
  /**
   * 广告唯一标识，用于区分不同位置的横幅广告
   */
  @Require @Param uniqueId: string;
  @Param adWidth: Length = '100%';
  @Param bgColor: ResourceColor = Color.Transparent;
  @Param radius: Length = 0;
  /**
   * 轮播时间间隔(ms)。<=0不轮播；否则自动收敛到[30000, 120000]
   */
  @Param refreshTime: number = 0;
  /**
   * 横幅高度(vp)，仅支持57或144。默认57为小信息流合并模式的小尺寸横幅
   */
  @Param bannerHeight: number = 57;
  @Local private isVisible: boolean = false;
  @Local private shouldMount: boolean = false;
  @Local private isClosedByUser: boolean = false;
  @Local private showLoadLog: boolean = false;
  @Local private attemptRecords: AdAttemptRecord[] = [];
  @Local private totalDuration: number = 0;
  @Local private isSuccess: boolean = false;
  private realAdId: string = '';
  private loadStartTime: number = 0;
  private requestParams: advertising.AdRequestParams = {
    adId: '',
    adType: HW_BANNER_AD_TYPE,
    adWidth: HW_BANNER_WIDTH,
    adHeight: this.bannerHeight
  };
  private adOptions: advertising.AdOptions = {};
  private displayOptions: advertising.AdDisplayOptions = {};
  private interactionListener: advertising.AdInteractionListener = {
    onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
      this.handleStatusChanged(status, data);
    }
  };

  aboutToAppear(): void {
    LogManager.info(TAG, `横幅广告初始化: ${this.adId}, uniqueId: ${this.uniqueId}`);
    this.loadAd();
  }

  /**
   * 加载/重新加载横幅广告
   * 关闭后调用可重新挂载广告并恢复广告展示高度
   */
  public loadAd(): void {
    if (!ADHelper.getInstance().isInitialized) {
      LogManager.warn(TAG, 'SDK未初始化，跳过横幅广告加载');
      return;
    }

    if (!AdSwitchManager.isAdOpen) {
      LogManager.info(TAG, '广告全局开关关闭，跳过横幅广告加载');
      return;
    }

    if (VIPRepo.instance.props.vip) {
      LogManager.info(TAG, 'VIP用户，跳过横幅广告加载');
      return;
    }

    this.resolveRealAdId();
    if (!this.realAdId) {
      LogManager.error(TAG, `华为横幅广告位[${this.adId}]未配置`);
      this.reportLoadLog(false, ErrCode.AD_LOAD_FAILED, '华为横幅广告位未配置');
      this.isVisible = Ohos.debug();
      return;
    }

    this.requestParams = {
      adId: this.realAdId,
      adType: HW_BANNER_AD_TYPE,
      adWidth: HW_BANNER_WIDTH,
      adHeight: this.getSafeBannerHeight(),
      oaid: OAIDStore.OAID
    };

    const clampedRefreshTime = this.getClampedRefreshTime();
    if (clampedRefreshTime > 0) {
      this.displayOptions = { refreshTime: clampedRefreshTime };
    }

    AdStateManager.getInstance().registerAdSlot(this.adId, AdType.BANNER, this.uniqueId);
    this.isClosedByUser = false;
    this.loadStartTime = Date.now();
    this.shouldMount = true;
    this.isVisible = true;
    LogManager.info(TAG, `横幅广告开始请求: ${this.realAdId}, refreshTime: ${clampedRefreshTime}`);
  }

  aboutToDisappear(): void {
    AdStateManager.getInstance().unregisterAdSlot(this.adId, this.uniqueId);
  }

  /**
   * 解析华为平台真实广告位ID
   * 优先级：槽位注册(云创/手动) > AdIdStore兜底 > debug模式测试ID
   */
  private resolveRealAdId(): void {
    const configuredId = AdSlotManager.getInstance().getRealAdId(this.adId, PlatformType.HUAWEI);
    if (configuredId) {
      this.realAdId = configuredId;
      return;
    }

    if (AdIdStore.HW_BANNER_ID) {
      this.realAdId = AdIdStore.HW_BANNER_ID;
      return;
    }

    if (TestAdRepo.instance.props.debugAD === true && Ohos.debug()) {
      this.realAdId = HW_TEST_BANNER_AD_ID;
      LogManager.warn(TAG, `debug模式使用华为测试广告位: ${HW_TEST_BANNER_AD_ID}`);
    }
  }

  /**
   * 轮播时间收敛规则(与官方一致)：
   * 非数字或<=0不轮播；小于30000取30000；大于120000取120000
   */
  private getClampedRefreshTime(): number {
    if (typeof this.refreshTime !== 'number' || Number.isNaN(this.refreshTime) || this.refreshTime <= 0) {
      return 0;
    }
    return Math.min(Math.max(Math.floor(this.refreshTime), MIN_REFRESH_TIME), MAX_REFRESH_TIME);
  }

  /**
   * 高度合法性校验，官方仅支持57和144两种尺寸
   */
  private getSafeBannerHeight(): number {
    return this.bannerHeight === 144 ? 144 : 57;
  }

  private handleStatusChanged(status: string, data: string): void {
    LogManager.info(TAG, `横幅广告[${this.adId}-${this.uniqueId}]状态: ${status}, data: ${data}`);

    switch (status) {
      case 'onAdLoad':
        this.reportLoadLog(true, 0, '');
        break;
      case 'onAdOpen':
        AdStateManager.getInstance().markAdSlotActive(this.adId, this.uniqueId);
        break;
      case 'onAdClick':
        LogManager.info(TAG, `横幅广告被点击: ${this.uniqueId}`);
        break;
      case 'onAdClose':
        this.hideBanner();
        break;
      case 'onAdFail':
        this.reportLoadLog(false, ErrCode.AD_LOAD_FAILED, data || 'onAdFail');
        this.hideBanner();
        break;
      default:
        break;
    }
  }

  /**
   * 用户关闭或加载失败时收起广告并同步状态(官方要求必须隐藏)
   * - release：整体隐藏不占位
   * - debug：广告内容卸载，容器收缩为40px调试区，可查看加载日志
   * 调用loadAd()可重新挂载广告恢复高度
   */
  private hideBanner(): void {
    this.isClosedByUser = true;
    this.shouldMount = false;
    AdStateManager.getInstance().unregisterAdSlot(this.adId, this.uniqueId);
    if (this.isVisible) {
      this.isVisible = Ohos.debug() && this.hasLoadLog();
      ExclusiveNotification.getInstance<string>(`easy_ad_closed_${this.adId}`).emit(this.uniqueId);
    }
  }

  private hasLoadLog(): boolean {
    return this.attemptRecords.length > 0;
  }

  /**
   * 上报加载日志到全局日志组件(GlobalAdLoadLogComponent)，并同步本地调试展示数据
   * 横幅为自请求组件不走降级链，因此由组件内部自行构造尝试记录
   */
  private reportLoadLog(success: boolean, errorCode: number, errorMessage: string): void {
    try {
      const duration = this.loadStartTime > 0 ? Date.now() - this.loadStartTime : 0;
      const record = new AdAttemptRecord(
        PlatformType.HUAWEI,
        0,
        success ? AdAttemptResult.SUCCESS : AdAttemptResult.FAILED,
        errorCode,
        errorMessage,
        duration,
        this.realAdId,
        RetryType.NONE
      );

      this.attemptRecords = [record];
      this.totalDuration = duration;
      this.isSuccess = success;

      GlobalAdLoadLogStore.getInstance().addLog(
        AdType.BANNER,
        this.adId,
        [record],
        duration,
        success,
        ADHelper.getInstance().getAvailablePlatformTypes()
      );
    } catch (e) {
      LogManager.error(TAG, `上报横幅加载日志异常: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  private canShowAd(): boolean {
    return !this.isClosedByUser && this.shouldMount && !!this.realAdId && this.isVisible && AdSwitchManager.isAdOpen;
  }

  @Builder
  buildBannerContent(): void {
    Row() {
      AutoAdComponent({
        adParam: this.requestParams,
        adOptions: this.adOptions,
        displayOptions: this.displayOptions,
        interactionListener: this.interactionListener
      })
    }
    .width('100%')
    .aspectRatio(HW_BANNER_WIDTH / this.getSafeBannerHeight())
    .backgroundColor(this.bgColor)
    .borderRadius(this.radius)
    .clip(true)
  }

  build(): void {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.canShowAd()) {
          this.buildBannerContent()
        }

        if (this.showLoadLog) {
          Column() {
            AdLoadLogComponent({
              attemptRecords: this.attemptRecords,
              totalDuration: this.totalDuration,
              isSuccess: this.isSuccess,
              radius: this.radius,
              adSlot: this.adId,
              availablePlatforms: ADHelper.getInstance().getAvailablePlatformTypes()
            })
          }
          .width('100%')
          .transition(
            TransitionEffect.OPACITY
              .animation({ duration: 250, curve: Curve.EaseOut })
              .combine(TransitionEffect.translate({ y: -10 })
                .animation({ duration: 250, curve: Curve.EaseOut }))
          )
        }

        if (Ohos.debug()) {
          AdDebugToggle({
            expanded: this.showLoadLog,
            onToggle: () => {
              this.showLoadLog = !this.showLoadLog;
            },
            positionX: '10%'
          })
        }
      }
      .width('100%')
      .constraintSize({ minHeight: Ohos.debug() ? 40 : 0 })
    }
    .width(this.adWidth)
    .visibility(this.isVisible ? Visibility.Visible : Visibility.None)
    .borderRadius(this.radius)
    .backgroundColor(this.bgColor)
    .clip(true)
    .onVisibleAreaApproximateChange(
      { ratios: VISIBLE_RATIOS, expectedUpdateInterval: 1000 },
      (isExpanding: boolean, currentRatio: number) => {
        if (currentRatio >= 1.0) {
          LogManager.info(TAG, `横幅广告完全可见: ${this.uniqueId}, expanding: ${isExpanding}`);
        }
      }
    )
  }
}
