import { ADHelper } from '../../helper/core/ADHelper';
import { AdType } from '../../model/AdType';
import { AdStatus } from '../../model/AdStatus';
import { IAd } from '../../helper/impl/IAd';
import { RenderMode } from '../../model/RenderMode';

import { LogManager } from '../../helper/logger/LogManager';
import { AppStorageV2, NodeController } from '@kit.ArkUI';
import { AdConfig } from '../../model/AdConfig';
import { AdComponent, advertising } from '@kit.AdsKit';
import { AdSwitchManager } from '../../helper/core/AdSwitchManager';
import { VIPRepo } from '../../storage/VIPData';
import { ExclusiveNotification } from '../../utils/ExclusiveNotification';
import { AdUIData } from '../../storage/AdUIData';
import { AdStateManager } from '../../helper/core/AdStateManager';
import { OnAdListener } from '../../interface/OnAdListener';
import { AdResult } from '../../model/AdResult';
import { AdLoadLogComponent } from '../debug/AdLoadLogComponent';
import { AdDebugToggle } from '../debug/AdDebugToggle';
import { Ohos } from '@zycore/common';
import { LifecycleManager } from '../../helper/core/LifecycleManager';

const TAG = 'FeedAdView';
const REFRESH_THROTTLE_MS = 1500;
const VISIBLE_RATIOS = [0.0, 1.0];

@ComponentV2
export struct FeedAdView {
  @Require @Param adId: string;
  @Require @Param uniqueId: string;
  @Param radius: Length = 0;
  @Param bgColor: ResourceColor = Color.Transparent;
  @Param adWidth: Length = '100%';
  @Local private isVisible: boolean = true;
  @Local private adResult: AdResult<IAd<ESObject>> | null = null;
  @Local private isClosedByUser: boolean = false;
  @Local private showLoadLog: boolean = false;
  @Local private uiData: AdUIData =
    AppStorageV2.connect<AdUIData>(AdUIData, `${this.adId}_${this.uniqueId}`, () => new AdUIData())!;
  private lastRefreshTime: number = 0;

  aboutToAppear(): void {
    LogManager.info(TAG, `当前广告信息：${this.adId}, uniqueId: ${this.uniqueId}`);
    this.registerToLifecycleManager();
    this.loadAd();
  }

  aboutToDisappear(): void {
    this.clearAd();
    this.unregisterFromLifecycleManager();
  }

  @Monitor('isVisible')
  onVisibleChange(monitor: IMonitor): void {
    if (this.isVisible) {
      this.uiData.adEventType = 'opened';
      this.uiData.adEventPayload = this.uniqueId;
    }
  }

  @Monitor('uiData.adState')
  onAdStateChange(monitor: IMonitor): void {
    const state = this.uiData.adState;
    if (state === AdStatus.AD_SHOW_FAILED) {
      this.uiData.adEventType = 'failed';
      this.uiData.adEventPayload = this.uniqueId;
    } else if (state === AdStatus.AD_SHOWN) {
      this.uiData.adEventType = 'showned';
      this.uiData.adEventPayload = this.uniqueId;
    }
  }

  loadAd(): void {
    if (!ADHelper.getInstance().isInitialized) {
      LogManager.warn(TAG, 'SDK未初始化，跳过信息流广告加载');
      return;
    }

    if (!AdSwitchManager.isAdOpen) {
      LogManager.info(TAG, '广告全局开关关闭，跳过信息流广告加载');
      return;
    }

    if (VIPRepo.instance.props.vip) {
      LogManager.info(TAG, 'VIP用户，跳过信息流广告加载');
      return;
    }

    this.isVisible = true;
    this.isClosedByUser = false;
    this.refreshAd();
  }

  private refreshAd(): void {
    if (VIPRepo.instance.props.vip) {
      this.isVisible = false;
      return;
    }

    if (this.isThrottled() || !ADHelper.getInstance().isInitialized) {
      return;
    }

    this.clearAd();
    LogManager.info(TAG, `开始加载信息流广告: ${this.adId}`);

    const adConfig = this.buildAdConfig();
    AdStateManager.getInstance().registerAdSlot(this.adId, AdType.FEED, this.uniqueId);

    ADHelper.getInstance().loadFeedAd(adConfig)
      .then((result: AdResult<IAd<ESObject>>) => {
        this.handleLoadResult(result, adConfig);
      })
      .catch((err: Error) => {
        // 原先此处静默吞异常，现携带配置上下文输出，避免加载异常无迹可循
        this.handleLoadError(adConfig, err);
      });
  }

  private buildAdConfig(): AdConfig {
    return AdConfig.builder()
      .setAdId(this.adId)
      .setAdType(AdType.FEED)
      .setPlatformPriority(ADHelper.getInstance().getAvailablePlatformTypes())
      .build();
  }

  private handleLoadResult(result: AdResult<IAd<ESObject>>, adConfig: AdConfig): void {
    this.adResult = result;

    if (!result.ad) {
      // 加载流程结束但无广告实例：输出最后一次尝试的平台与错误详情，便于定位失败原因
      // adConfig.getAdId() 在降级层已被替换为本次实际加载的真实广告ID
      const lastRecord = result.attemptRecords[result.attemptRecords.length - 1];
      LogManager.error(TAG,
        `信息流[${adConfig.getAdSlot()}|${adConfig.getAdId()}]加载失败: 平台=${lastRecord?.platformType ?? '无可用平台'}, ` +
        `code=${lastRecord?.errorCode ?? 'N/A'}, msg=${lastRecord?.errorMessage ?? '无尝试记录'}`);
      this.hideAdContainer();
      this.setAdFailed();
      return;
    }

    LogManager.info(TAG, `信息流广告[${this.adId}]加载成功`);
    this.lastRefreshTime = Date.now();

    const adListener = this.createAdListener();
    result.ad.setAdListener(adListener);
    result.ad.setAdConfig(adConfig);
    AdStateManager.getInstance().updateAdSlot(this.adId, this.uniqueId, result.ad, adListener);
    result.ad.render();
  }

  /**
   * 加载异常兜底处理（loadFeedAd 链路抛错时触发）
   * @param adConfig 本次加载使用的配置（含槽位名与真实广告ID）
   * @param err 异常对象
   */
  private handleLoadError(adConfig: AdConfig, err: Error): void {
    LogManager.error(TAG,
      `信息流[${adConfig.getAdSlot()}|${adConfig.getAdId()}]加载异常: ${err instanceof Error ? err.message : String(err)}`);
    this.hideAdContainer();
    this.setAdFailed();
  }

  private createAdListener(): OnAdListener {
    return {
      onAdShow: () => {
        this.setAdState(AdStatus.AD_SHOWN);
        AdStateManager.getInstance().markAdSlotActive(this.adId, this.uniqueId);
      },
      onAdShowError: () => {
        AdStateManager.getInstance().unregisterAdSlot(this.adId, this.uniqueId);
      },
      onClick: () => {
        this.setAdState(AdStatus.AD_CLICKED);
      },
      onAdClose: () => {
        this.isClosedByUser = true;
        this.setAdState(AdStatus.AD_CLOSED);
        this.hideAdContainer();
      }
    };
  }

  private setAdState(state: AdStatus): void {
    this.uiData.adState = state;
  }

  private getAdState(): AdStatus | undefined {
    return this.uiData.adState;
  }

  private isThrottled(): boolean {
    if (Date.now() - this.lastRefreshTime < REFRESH_THROTTLE_MS) {
      LogManager.warn(TAG, `刷新节流中，跳过广告加载`);
      return true;
    }
    return false;
  }

  private clearAd(): void {
    this.adResult?.ad?.destroy();
    this.adResult = null;
  }

  private hideAdContainer(): void {
    if (this.isVisible) {
      // this.isVisible = Ohos.debug() && this.hasLoadLog();
      this.isVisible = Ohos.debug()
      ExclusiveNotification.getInstance<string>(`easy_ad_closed_${this.adId}`).emit(this.uniqueId);
    }
  }

  private setAdFailed(): void {
    LogManager.error(TAG, `信息流[${this.adId}-${this.uniqueId}]置为失败态（渲染/展示链路）`);
    this.setAdState(AdStatus.AD_SHOW_FAILED);
  }

  private getFeedAd(): IAd<ESObject> | undefined {
    return this.adResult?.ad ?? undefined;
  }

  private getAdView(): NodeController | undefined {
    return this.getFeedAd()?.view();
  }

  private isHuaweiAd(): boolean {
    const ad: IAd<ESObject> | undefined = this.getFeedAd();
    if (!ad) {
      return false;
    }
    return ad.getRenderMode() === RenderMode.SYSTEM_COMPONENT;
  }

  private getHuaweiAdObject(): advertising.Advertisement | undefined {
    if (!this.isHuaweiAd()) {
      return undefined;
    }
    try {
      const props = this.getFeedAd()?.getSystemProps();
      if (props && props.ads.length > 0) {
        return props.ads[0] as advertising.Advertisement;
      }
      return undefined;
    } catch (error) {
      LogManager.error(TAG, `信息流[${this.adId}]获取华为广告对象失败: ${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }
  }

  private getHuaweiDisplayOptions(): advertising.AdDisplayOptions | undefined {
    if (!this.isHuaweiAd()) {
      return undefined;
    }
    try {
      const props = this.getFeedAd()?.getSystemProps();
      return props?.displayOptions as advertising.AdDisplayOptions | undefined;
    } catch (error) {
      LogManager.error(TAG, `信息流[${this.adId}]获取华为广告展示选项失败: ${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }
  }

  private handleHuaweiAdStatus(status: string): void {
    if (!status) {
      return;
    }
    LogManager.info(TAG, `广告状态变化: ${status}`);

    // 转发到 IAd 统一事件契约（宿主 setAdListener 可收到）
    const feedAd: IAd<ESObject> | undefined = this.getFeedAd();
    if (feedAd) {
      feedAd.handleAdStatus(status);
    }

    switch (status) {
      case 'onAdOpen':
        this.setAdState(AdStatus.AD_SHOWN);
        AdStateManager.getInstance().markAdSlotActive(this.adId, this.uniqueId);
        break;
      case 'onAdClick':
        this.setAdState(AdStatus.AD_CLICKED);
        break;
      case 'onAdFail':
        this.emitAdClosed();
        this.setAdFailed();
        AdStateManager.getInstance().unregisterAdSlot(this.adId, this.uniqueId);
        break;
      case 'onAdClose':
        this.emitAdClosed();
        this.isClosedByUser = true;
        this.hideAdContainer();
        this.setAdState(AdStatus.AD_CLOSED);
        break;
    }
  }

  private emitAdClosed(): void {
    ExclusiveNotification.getInstance<string>(`easy_ad_closed_${this.adId}`).emit(this.uniqueId);
  }

  private shouldRefreshAd(): boolean {
    const state = this.getAdState();
    return !this.isClosedByUser &&
      (state === AdStatus.AD_CLICKED || state === AdStatus.AD_WAITING_REFRESH);
  }

  build(): void {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.canShowAd()) {
          this.buildAdContent();
        }

        if (this.showLoadLog) {
          Column() {
            AdLoadLogComponent({
              attemptRecords: this.adResult?.attemptRecords ?? [],
              totalDuration: this.adResult?.totalDuration ?? 0,
              isSuccess: this.adResult?.isSuccess ?? false,
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
            positionX: '100%'
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
      this.onAdVisibleAreaChange.bind(this)
    )
  }

  private hasLoadLog(): boolean {
    return (this.adResult?.attemptRecords?.length ?? 0) > 0;
  }

  private canShowAd(): boolean {
    return AdSwitchManager.isAdOpen && !!this.adResult?.ad && this.isVisible;
  }

  @Builder
  buildAdContent(): void {
    if (this.getAdView()) {
      this.buildNodeContainerAd();
    } else if (this.isHuaweiAd() && this.getHuaweiAdObject()) {
      this.buildHuaweiAd();
    }
  }

  @Builder
  buildNodeContainerAd(): void {
    NodeContainer(this.getAdView())
      .clip(true)
      .width('100%')
      .borderRadius(this.radius)
      .backgroundColor(this.bgColor || Color.Transparent);
  }

  @Builder
  buildHuaweiAd(): void {
    AdComponent({
      ads: [this.getHuaweiAdObject()!],
      displayOptions: this.getHuaweiDisplayOptions(),
      interactionListener: {
        onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
          this.handleHuaweiAdStatus(status);
        }
      }
    })
      .width('100%')
      .backgroundColor(this.bgColor || Color.Transparent)
      .borderRadius(this.radius)
  }

  private onAdVisibleAreaChange(isExpanding: boolean, currentRatio: number): void {
    LogManager.info(TAG, `可见性检测 called, adState: ${this.getAdState()}`);

    if (this.getAdState() === AdStatus.AD_SHOW_FAILED) {
      this.emitAdClosed();
    }

    if (isExpanding && currentRatio >= 1.0 && this.shouldRefreshAd()) {
      LogManager.info(TAG, `广告状态为${this.getAdState()}，重新刷新广告`);
      this.refreshAd();
      this.uiData.adState = undefined;
    }
  }

  private registerToLifecycleManager(): void {
    const id = `${this.adId}_${this.uniqueId}`;
    LifecycleManager.getInstance().registerWindowStageActive(id, (ability, windowStage) => {
      LogManager.info(TAG, `应用窗口活跃 called, adState: ${this.getAdState()}`);
      if (this.shouldRefreshAd()) {
        LogManager.info(TAG, `广告状态为${this.getAdState()}，重新刷新广告`);
        this.refreshAd();
        this.uiData.adState = undefined;
      }
    });
  }

  private unregisterFromLifecycleManager(): void {
    const id = `${this.adId}_${this.uniqueId}`;
    LifecycleManager.getInstance().unregisterWindowStageActive(id);
  }
}
