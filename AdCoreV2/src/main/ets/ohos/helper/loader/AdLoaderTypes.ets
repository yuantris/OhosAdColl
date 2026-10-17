import { OnAdListener } from "../../interface/OnAdListener";
import { OnVideoRewardListener } from "../../interface/OnVideoRewardListener";


export interface AdLoadResult {
  readonly success: boolean;
  readonly errorCode?: number;
  readonly errorMessage?: string;
  readonly data?: ESObject;
  /** 原生广告句柄，deferShow 模式下由 IndependentAd 持有并交给 show */
  readonly nativeHandle?: Object;
}

export namespace AdLoadResult {
  export function success(data?: ESObject, nativeHandle?: Object): AdLoadResult {
    return { success: true, data, nativeHandle };
  }

  export function failure(code: number, message: string): AdLoadResult {
    return { success: false, errorCode: code, errorMessage: message };
  }
}

/** load 选项：deferShow=true 时加载完成即 resolve（不自动展示），由调用方后续 show */
export interface AdLoadOptions {
  readonly deferShow?: boolean;
  /** 加载超时(ms)，不传则用 AD_LOAD_TIMEOUT_MS */
  readonly loadTimeout?: number;
}

export interface SplashAdLoader {
  load(adId: string, listener?: OnAdListener, options?: AdLoadOptions): Promise<AdLoadResult>;
  show?(nativeHandle: Object): void;
}

export interface InterstitialAdLoader {
  load(adId: string, listener?: OnAdListener, options?: AdLoadOptions): Promise<AdLoadResult>;
  show?(nativeHandle: Object): void;
}

export interface RewardVideoAdLoader {
  load(adId: string, listener?: OnVideoRewardListener, options?: AdLoadOptions): Promise<AdLoadResult>;
  show?(nativeHandle: Object): void;
}

export interface AdLoaders {
  readonly splash: SplashAdLoader;
  readonly interstitial: InterstitialAdLoader;
  readonly rewardVideo: RewardVideoAdLoader;
}

// 广告加载超时时间（毫秒）。各渠道 SDK 的 loadAd/loadXxxAd 不保证一定回调，
// 为避免 Promise 永久 pending 导致外部无任何回调（单渠道场景尤为明显），
// 各 loader 应在超时后统一以 AD_TIMEOUT 失败兜底。
export const AD_LOAD_TIMEOUT_MS = 8000;
