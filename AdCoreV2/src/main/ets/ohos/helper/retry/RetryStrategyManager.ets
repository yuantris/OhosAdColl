import { PlatformType } from '../../model/PlatformType';
import { RetryContext, RetryAction, IRetryStrategy } from './RetryStrategy';
import { PlatformRetryStrategy } from './PlatformRetryStrategy';

export class RetryStrategyManager implements IRetryStrategy {
  private readonly strategies: Map<PlatformType, IRetryStrategy> = new Map();

  constructor() {
    this.strategies.set(PlatformType.CSJ, new PlatformRetryStrategy(PlatformType.CSJ));
    this.strategies.set(PlatformType.TENCENT, new PlatformRetryStrategy(PlatformType.TENCENT));
    this.strategies.set(PlatformType.HUAWEI, new PlatformRetryStrategy(PlatformType.HUAWEI));
  }

  getStrategy(platform: PlatformType): IRetryStrategy | undefined {
    return this.strategies.get(platform);
  }

  setStrategy(platform: PlatformType, strategy: IRetryStrategy): void {
    this.strategies.set(platform, strategy);
  }

  getPlatformStrategy(platform: PlatformType): PlatformRetryStrategy | undefined {
    const strategy = this.strategies.get(platform);
    return strategy instanceof PlatformRetryStrategy ? strategy : undefined;
  }

  determineAction(context: RetryContext): RetryAction {
    const strategy = this.strategies.get(context.platform);
    if (strategy) {
      return strategy.determineAction(context);
    }
    return this.defaultAction(context);
  }

  private defaultAction(context: RetryContext): RetryAction {
    if (context.retryCount < context.maxRetryCount) {
      return RetryAction.retry();
    }
    return RetryAction.degrade();
  }

  private static instance: RetryStrategyManager | null = null;

  static getInstance(): RetryStrategyManager {
    if (!RetryStrategyManager.instance) {
      RetryStrategyManager.instance = new RetryStrategyManager();
    }
    return RetryStrategyManager.instance;
  }
}
