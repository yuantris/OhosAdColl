import { IndependentAd } from './IndependentAd';
import { OnAdListener } from '../../interface/OnAdListener';
import { OnVideoRewardListener } from '../../interface/OnVideoRewardListener';
import { LogManager } from '../logger/LogManager';

export abstract class BaseIndependentAd implements IndependentAd {
  protected adListener: OnAdListener | undefined;
  protected videoRewardListener: OnVideoRewardListener | undefined;
  protected valid: boolean = false;
  protected ready: boolean = false;
  protected showed: boolean = false;

  async load(): Promise<void> {
    await this.doLoad();
    this.ready = this.valid;
  }

  show(): void {
    if (!this.isReady()) {
      LogManager.error('BaseIndependentAd', 'show: ad is not ready');
      return;
    }
    this.showed = true;
    this.doShow();
    if (this.adListener && this.adListener.onAdShow) {
      this.adListener.onAdShow();
    }
  }

  isReady(): boolean {
    return this.ready && !this.showed;
  }

  destroy(): void {
    this.doDestroy();
    this.valid = false;
    this.ready = false;
    this.showed = false;
  }

  isValid(): boolean {
    return this.valid;
  }

  setAdListener(listener: OnAdListener): void {
    this.adListener = listener;
  }

  setVideoRewardListener(listener: OnVideoRewardListener | undefined): void {
    this.videoRewardListener = listener;
  }

  protected abstract doLoad(): Promise<void>;
  protected abstract doShow(): void;
  protected abstract doDestroy(): void;
}
