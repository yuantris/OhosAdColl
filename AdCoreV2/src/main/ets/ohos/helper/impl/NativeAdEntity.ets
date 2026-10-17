import { NodeController, UIContext } from '@kit.ArkUI';
import { IAd } from './IAd';
import { RenderMode } from '../../model/RenderMode';
import { NativeAdMaterial } from '../../model/NativeAdMaterial';

/**
 * 原生自渲染广告实体（SELF_RENDER 模式）
 * 素材经 NativeAdMaterial 暴露，宿主自绘 UI 后 bindInteraction 注册点击
 */
export class NativeAdEntity extends IAd<object> {
  private material: NativeAdMaterial;
  private destroyed: boolean = false;

  constructor(nativeAd: object, material: NativeAdMaterial) {
    super(nativeAd);
    this.material = material;
  }

  timeout(): number {
    return 30000;
  }

  view(): NodeController | undefined {
    // 自渲染无 NodeController，宿主自绘
    return undefined;
  }

  protected bind(): void {
    // 自渲染交互经 bindInteraction 显式注册，此处无原生事件可绑
  }

  render(): void {
    // 自渲染由宿主绘制，此处仅记录
  }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    this.onDestroy();
  }

  public getRenderMode(): RenderMode {
    return RenderMode.SELF_RENDER;
  }

  public getMaterial(): NativeAdMaterial | undefined {
    return this.material;
  }

  /**
   * 注册自渲染点击区域（GDT registerViewForInteraction / CSJ 同名 API）
   * @param uiContext UI 上下文
   * @param rootId 根组件 id
   * @param clickIds 可点击区域组件 id 列表
   * @param creativeIds 可点击创意区域组件 id 列表（可选）
   */
  public bindInteraction(uiContext: UIContext, rootId: string, clickIds: string[], creativeIds?: string[]): void {
    // 由平台子类覆写，调用三方 SDK 的 registerViewForInteraction
    this.onRender();
    this.onShow();
  }
}
