import { PlatformType } from '../model/PlatformType';

export interface OnAdShowListener {
  onAdShow?(platformType: PlatformType): void;
  onAdClose?(platformType: PlatformType): void;
  onClick?(platformType: PlatformType): void;
  onAdRender?(platformType: PlatformType): void;
  onAdDestroy?(platformType: PlatformType): void;
}
