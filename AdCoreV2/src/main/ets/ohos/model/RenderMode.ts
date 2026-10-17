/**
 * 渲染模式三态
 * TEMPLATE: 平台模板渲染（CSJ express / TX getAdComponent）
 * SELF_RENDER: 宿主自渲染（NativeAdMaterial + bindInteraction）
 * SYSTEM_COMPONENT: 系统组件渲染（华为 AdComponent）
 */
export enum RenderMode {
  TEMPLATE = 0,
  SELF_RENDER = 1,
  SYSTEM_COMPONENT = 2
}
