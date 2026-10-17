/**
 * 自渲染素材：GDT Manual / CSJ native / 华为 native 统一映射
 */
export interface NativeAdMaterial {
  title: string;
  desc: string;
  iconUrl: string;
  imageUrls: string[];
  videoUrl: string;
  /** single | triple | video */
  pattern: string;
  adLogoUrl: string;
  actionText: string;
}
