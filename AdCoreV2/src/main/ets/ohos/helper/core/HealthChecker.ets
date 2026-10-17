import { getPlatformName, PlatformType } from '../../model/PlatformType';
import { AdType } from '../../model/AdType';
import { PlatformManager } from './PlatformManager';
import { LogManager } from '../logger/LogManager';

export class HealthChecker {
  private platformManager: PlatformManager;
  private healthCheckTimer: number | null = null;
  static readonly HEALTH_CHECK_INTERVAL = 60000;

  constructor(platformManager: PlatformManager) {
    this.platformManager = platformManager;
  }

  start(): void {
    if (this.healthCheckTimer !== null) {
      clearInterval(this.healthCheckTimer);
      this.healthCheckTimer = null;
    }
    this.healthCheckTimer = setInterval(() => {
      this.performHealthCheck();
    }, HealthChecker.HEALTH_CHECK_INTERVAL);
    LogManager.info('HealthChecker', 'Health check started');
  }

  stop(): void {
    if (this.healthCheckTimer !== null) {
      clearInterval(this.healthCheckTimer);
      this.healthCheckTimer = null;
      LogManager.info('HealthChecker', 'Health check stopped');
    }
  }

  private performHealthCheck(): void {
    LogManager.info('HealthChecker', 'Performing health check');

    const now = Date.now();
    const checkInterval = HealthChecker.HEALTH_CHECK_INTERVAL;

    this.platformManager.getPlatformFailureTime().forEach((timeMap, platformType) => {
      timeMap.forEach((failureTime, adKey) => {
        if (now - failureTime >= checkInterval) {
          const adKeyParts = adKey.split(':');
          const adTypeStr = adKeyParts[0];
          const adSlot = adKeyParts[1];

          if (adTypeStr && adSlot) {
            // key 格式为 `${AdType 数值}:${adSlot}`（见 PlatformManager.recordPlatformFailure）
            const parsed = Number(adTypeStr);
            const isValidAdType = Number.isInteger(parsed) && parsed >= AdType.UNKNOWN && parsed <= AdType.NATIVE;
            const adType: AdType = isValidAdType ? parsed as AdType : AdType.UNKNOWN;

            this.platformManager.resetPlatformStatus(platformType, adType, adSlot);
            LogManager.info('HealthChecker',
              `Reset status for platform ${getPlatformName(platformType)}, adType: ${adTypeStr}, adSlot: ${adSlot}`);
          }
        }
      });
    });

    LogManager.info('HealthChecker', 'Health check completed');
  }
}
