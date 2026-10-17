import { getPlatformName, PlatformType } from '../../model/PlatformType';
import { AdConfig } from '../../model/AdConfig';
import { OnAdListener } from '../../interface/OnAdListener';
import { AdType } from '../../model/AdType';
import { AdConstants } from '../const/AdConstants';
import { ForceChannelManager } from './ForceChannelManager';
import { AdSwitchManager } from './AdSwitchManager';
import { PlatformManager } from './PlatformManager';
import { CallbackGuard } from './CallbackGuard';
import { LogManager } from '../logger/LogManager';
import { ErrCode } from '../const/ErrCode';
import { AdResult } from '../../model/AdResult';
import { AdAttemptRecord, AdAttemptResult, RetryType } from '../../model/AdAttemptRecord';
import { RetryStrategyManager } from '../retry/RetryStrategyManager';
import { RetryContext, RetryActionType } from '../retry/RetryStrategy';
import { AdError } from '../error/AdError';

export class DegradationStrategy {
  private static readonly TAG = 'DegradationStrategy';
  private platformManager: PlatformManager;
  private callbackGuard: CallbackGuard;
  /**
   * 加载会话串行队列：并发 loadXxxAd 依次执行，避免互踩 currentPlatform/Manager
   */
  private sessionQueue: Promise<void> = Promise.resolve();

  constructor(platformManager: PlatformManager) {
    this.platformManager = platformManager;
    this.callbackGuard = new CallbackGuard();
  }

  async executeWithDegradation<T>(config: AdConfig,
    loadCallback: (config: AdConfig, retryCount: number) => Promise<T>,
    listener?: OnAdListener): Promise<AdResult<T>> {
    const run = (): Promise<AdResult<T>> =>
      this.doExecuteWithDegradation(config, loadCallback, listener);
    // 串行化会话：前一个会话结束后才启动下一个
    const session: Promise<AdResult<T>> = this.sessionQueue.then(() => run());
    this.sessionQueue = session.then(() => undefined, () => undefined);
    return session;
  }

  private async doExecuteWithDegradation<T>(config: AdConfig,
    loadCallback: (config: AdConfig, retryCount: number) => Promise<T>,
    listener?: OnAdListener): Promise<AdResult<T>> {
    const startTime = Date.now();
    const attemptRecords: AdAttemptRecord[] = [];

    if (!AdSwitchManager.isAdOpen) {
      const errorMsg = 'Ads are globally disabled';
      listener?.onAdShowError?.(ErrCode.AD_CLOSE, errorMsg);
      return new AdResult<T>(null, attemptRecords, null, Date.now() - startTime);
    }

    const availablePlatformTypes = this.platformManager.getAvailablePlatformTypes();
    if (availablePlatformTypes.length === 0) {
      const errorMsg = 'No available ad platforms';
      listener?.onAdShowError?.(ErrCode.AD_LOAD_FAILED, errorMsg);
      return new AdResult<T>(null, attemptRecords, null, Date.now() - startTime);
    }

    const adType = config.getAdType();
    const originalAdSlot = config.getAdId();
    const originalConfigAdId = config.getAdId();

    if (ForceChannelManager.isForceAdChannelEnabled()) {
      return this.executeForcedChannel(config, loadCallback, listener,
        availablePlatformTypes, adType, originalAdSlot, originalConfigAdId,
        attemptRecords, startTime);
    }

    return this.executeWithPriorityList(config, loadCallback, listener,
      availablePlatformTypes, adType, originalAdSlot, originalConfigAdId,
      attemptRecords, startTime);
  }

  private async executeForcedChannel<T>(config: AdConfig,
    loadCallback: (config: AdConfig, retryCount: number) => Promise<T>,
    listener: OnAdListener | undefined,
    availablePlatformTypes: PlatformType[],
    adType: AdType, originalAdSlot: string, originalConfigAdId: string,
    attemptRecords: AdAttemptRecord[], startTime: number): Promise<AdResult<T>> {

    const forcePlatformType = ForceChannelManager.toPlatformType() ?? PlatformType.UNKNOWN;
    this.platformManager.switchToPlatformByType(forcePlatformType);
    LogManager.info(DegradationStrategy.TAG, `using forced platform ${getPlatformName(forcePlatformType)}`);

    let retryCount = 0;

    while (true) {
      const attemptStart = Date.now();
      try {
        config.setAdId(originalConfigAdId);
        config.setAdSlot(originalAdSlot);
        let currentAdId = originalConfigAdId;
        if (this.platformManager.getCurrentPlatformType()) {
          const realAdId = this.platformManager.getRealAdId(originalConfigAdId, forcePlatformType);
          if (realAdId) {
            config.setAdId(realAdId);
            currentAdId = realAdId;
          }
        }
        const ad = await loadCallback(config, retryCount);
        attemptRecords.push(new AdAttemptRecord(forcePlatformType, attemptRecords.length + 1,
          AdAttemptResult.SUCCESS, 0, '', Date.now() - attemptStart, currentAdId));
        return new AdResult<T>(ad, attemptRecords, forcePlatformType, Date.now() - startTime);
      } catch (error) {
        const adError = AdError.fromError(error);
        attemptRecords.push(new AdAttemptRecord(forcePlatformType, attemptRecords.length + 1,
          AdAttemptResult.FAILED, adError.code, adError.message, Date.now() - attemptStart, config.getAdId()));

        // 统一错误日志：强制渠道模式下同样输出槽位名与真实广告ID
        LogManager.error(DegradationStrategy.TAG,
          `[广告加载失败] 平台=${getPlatformName(forcePlatformType)}(强制渠道), 类型=${adType}, 槽位=${originalAdSlot}, ` +
          `真实ID=${config.getAdId()}, 第${attemptRecords.length}次尝试, code=${adError.code}, msg=${adError.message}`);

        this.platformManager.recordPlatformFailure(forcePlatformType, adType, originalAdSlot);

        const context: RetryContext = {
          platform: forcePlatformType,
          errorCode: adError.code,
          errorMessage: adError.message,
          retryCount: retryCount,
          maxRetryCount: AdConstants.DEFAULT_MAX_RETRY,
          adSlot: originalAdSlot
        };

        const action = RetryStrategyManager.getInstance().determineAction(context);

        switch (action.type) {
          case RetryActionType.RETRY:
            const maxRetry = action.maxRetry ?? 1;
            if (retryCount < maxRetry) {
              retryCount++;
              LogManager.info(DegradationStrategy.TAG,
                `Retrying forced platform ${getPlatformName(forcePlatformType)} (attempt ${retryCount}/${maxRetry}): ${adError.message}`);
            } else {
              LogManager.info(DegradationStrategy.TAG,
                `Retry exhausted for forced platform ${getPlatformName(forcePlatformType)} after ${maxRetry} attempts`);
              return this.returnFailedResult(listener, attemptRecords, startTime, 'Failed to load ad from forced platform');
            }
            break;
          case RetryActionType.DEGRADE:
          case RetryActionType.FAIL:
            LogManager.warn(DegradationStrategy.TAG, `Forced platform failed: ${adError.message}`);
            return this.returnFailedResult(listener, attemptRecords, startTime, 'Failed to load ad from forced platform');
        }
      }
    }
  }

  private returnFailedResult<T>(listener: OnAdListener | undefined,
    attemptRecords: AdAttemptRecord[], startTime: number, message: string): AdResult<T> {
    this.callbackGuard.reset();
    this.callbackGuard.guard('onAdShowError', () => {
      listener?.onAdShowError?.(ErrCode.AD_LOAD_FAILED, message);
    });
    return new AdResult<T>(null, attemptRecords, null, Date.now() - startTime);
  }

  private async executeWithPriorityList<T>(config: AdConfig,
    loadCallback: (config: AdConfig, retryCount: number) => Promise<T>,
    listener: OnAdListener | undefined,
    availablePlatformTypes: PlatformType[],
    adType: AdType, originalAdSlot: string, originalConfigAdId: string,
    attemptRecords: AdAttemptRecord[], startTime: number): Promise<AdResult<T>> {

    const priorityList = config.getPlatformPriority();
    const platformTypesToTry = priorityList.length > 0 ? priorityList : availablePlatformTypes;

    const platformNamesToTry = platformTypesToTry.map((p: PlatformType) => getPlatformName(p)).join(', ');
    LogManager.info(DegradationStrategy.TAG,
      `Platform priority list for ${originalAdSlot}: [${platformNamesToTry}], total ${platformTypesToTry.length} platforms`);

    // 平台切换回调的基准状态: 上一个重试耗尽的平台(切换起点), null 表示尚未发生任何失败(首轮)
    let lastFailedPlatform: PlatformType | null = null;
    let lastErrorCode: number = 0;
    let lastErrorMsg: string = '';

    for (const platformType of platformTypesToTry) {
      if (!this.platformManager.isPlatformAvailable(platformType, adType, originalAdSlot)) {
        const skippedAdId = this.platformManager.getRealAdId(originalConfigAdId, platformType) || originalConfigAdId;
        attemptRecords.push(new AdAttemptRecord(platformType, attemptRecords.length + 1,
          AdAttemptResult.SKIPPED, 0, 'Platform unavailable', 0, skippedAdId));
        LogManager.info(DegradationStrategy.TAG, `Skipping unavailable platform ${getPlatformName(platformType)}`);
        continue;
      }

      this.platformManager.switchToPlatformByType(platformType);
      LogManager.info(DegradationStrategy.TAG, `Trying platform ${getPlatformName(platformType)}`);

      // 仅在真实平台切换时触发: 上一平台重试耗尽后开始尝试新平台(首轮无切换, 不触发)
      if (lastFailedPlatform !== null) {
        listener?.onAdPlatformSwitchStart?.(
          lastFailedPlatform as PlatformType as number, platformType as number);
      }

      let shouldDegrade = false;
      let retryCount = 0;

      while (!shouldDegrade) {
        const attemptStart = Date.now();
        try {
          config.setAdId(originalConfigAdId);
          config.setAdSlot(originalAdSlot);
          let currentAdId = originalConfigAdId;
          const realAdId = this.platformManager.getRealAdId(originalConfigAdId, platformType);
          if (realAdId) {
            config.setAdId(realAdId);
            currentAdId = realAdId;
          }
          const ad = await loadCallback(config, retryCount);
          attemptRecords.push(new AdAttemptRecord(platformType, attemptRecords.length + 1,
            AdAttemptResult.SUCCESS, 0, '', Date.now() - attemptStart, currentAdId));
          // 仅在真实平台切换后成功时触发(首轮直接成功无切换, 不触发)
          if (lastFailedPlatform !== null) {
            listener?.onAdPlatformSwitchSuccess?.(
              lastFailedPlatform as PlatformType as number, platformType as number);
          }
          return new AdResult<T>(ad, attemptRecords, platformType, Date.now() - startTime);
        } catch (error) {
          const adError = AdError.fromError(error);
          this.platformManager.recordPlatformFailure(platformType, adType, originalAdSlot);
          // 记录最新错误, 供切换失败回调使用
          lastErrorCode = adError.code;
          lastErrorMsg = adError.message;

          const context: RetryContext = {
            platform: platformType,
            errorCode: adError.code,
            errorMessage: adError.message,
            retryCount: retryCount,
            maxRetryCount: AdConstants.DEFAULT_MAX_RETRY,
            adSlot: originalAdSlot
          };

          const action = RetryStrategyManager.getInstance().determineAction(context);
          const retryType = action.type === RetryActionType.RETRY ? RetryType.SELF_RETRY :
            action.type === RetryActionType.DEGRADE ? RetryType.CHANNEL_RETRY : RetryType.NONE;

          attemptRecords.push(new AdAttemptRecord(platformType, attemptRecords.length + 1,
            AdAttemptResult.FAILED, adError.code, adError.message, Date.now() - attemptStart, config.getAdId(), retryType));

          // 统一错误日志：所有平台加载失败的必经点，确保每条失败都能看到槽位名与真实广告ID
          LogManager.error(DegradationStrategy.TAG,
            `[广告加载失败] 平台=${getPlatformName(platformType)}, 类型=${adType}, 槽位=${originalAdSlot}, ` +
            `真实ID=${config.getAdId()}, 第${attemptRecords.length}次尝试, code=${adError.code}, msg=${adError.message}`);

          switch (action.type) {
            case RetryActionType.RETRY:
              const maxRetry = action.maxRetry ?? 1;
              if (retryCount < maxRetry) {
                retryCount++;
                LogManager.info(DegradationStrategy.TAG,
                  `Retrying platform ${getPlatformName(platformType)} (attempt ${retryCount}/${maxRetry}): ${adError.message}`);
              } else {
                shouldDegrade = true;
                LogManager.info(DegradationStrategy.TAG,
                  `Retry exhausted for ${getPlatformName(platformType)} after ${maxRetry} attempts`);
              }
              break;
            case RetryActionType.DEGRADE:
              shouldDegrade = true;
              LogManager.info(DegradationStrategy.TAG,
                `Degrading from platform ${getPlatformName(platformType)}: ${adError.message}`);
              break;
            case RetryActionType.FAIL:
              LogManager.warn(DegradationStrategy.TAG, `Ad loading failed: ${adError.message}`);
              // FAIL 策略不允许继续降级, 当前平台彻底失败, 触发平台失败回调(标准+过时双发)后整体失败收尾
              listener?.onAdPlatformFailed?.(platformType as number, adError.code, adError.message);
              return new AdResult<T>(null, attemptRecords, null, Date.now() - startTime);
          }
        }
      }

      LogManager.info(DegradationStrategy.TAG,
        `All retries failed for platform ${getPlatformName(platformType)}`);

      // 当前平台重试耗尽彻底失败: 触发平台失败回调(标准+过时双发), 参数携带该平台自身的错误信息
      listener?.onAdPlatformFailed?.(platformType as number, lastErrorCode, lastErrorMsg);
      // 当前平台成为下一轮切换的起点
      lastFailedPlatform = platformType;
    }

    LogManager.warn(DegradationStrategy.TAG, `Failed to load ad from all platforms`);
    this.callbackGuard.reset();
    this.callbackGuard.guard('onAdShowError', () => {
      listener?.onAdShowError?.(ErrCode.AD_LOAD_FAILED,
        `Failed to load ad from all platforms after ${attemptRecords.length} attempts`);
    });
    return new AdResult<T>(null, attemptRecords, null, Date.now() - startTime);
  }
}
