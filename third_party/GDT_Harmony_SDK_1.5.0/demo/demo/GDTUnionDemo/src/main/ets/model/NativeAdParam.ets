import { GDTAutoPlayPolicy } from '@gdt/gdt-union-sdk';
import { AdPageParam } from './AdPageParam';

export interface NativeAdParam extends AdPageParam {
  posId: string;
  adInterval: number;
  autoPlayPolicy?: GDTAutoPlayPolicy;
  autoPlayMuted?: boolean;
  showCoverImg?: boolean;
  showProgressBar?: boolean;
}
