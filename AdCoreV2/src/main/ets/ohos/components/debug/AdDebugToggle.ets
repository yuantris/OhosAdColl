/**
 * 调试日志开关按钮（纯展示组件）
 * 仅负责按钮的 UI 与点击回调，不持有任何业务状态；
 * 展开态与翻转逻辑均由父组件通过 @Param 注入，符合"展示与状态分离"。
 */
@ComponentV2
export struct AdDebugToggle {
  /**
   * 是否展开日志面板（= 父组件的 showLoadLog），控制图标旋转
   */
  @Require @Param expanded: boolean;
  /**
   * 点击回调，由父组件翻转 showLoadLog
   */
  @Require @Param onToggle: () => void;
  /**
   * 水平定位：横幅传 '10%'，信息流传 '100%'
   */
  @Param positionX: string = '100%';

  build(): void {
    Row() {
      Image(this.expanded ? $r('sys.media.ohos_ic_public_close') : $r('sys.media.ohos_ic_public_more'))
        .width('100%')
        .fillColor(Color.White)
        .rotate({ angle: this.expanded ? 90 : 0 })
        .animation({ duration: 250, curve: Curve.EaseOut })
    }
    .width(24)
    .height(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(12)
    .backdropBlur(48, { grayscale: [24, 36] })
    .animation({ duration: 250, curve: Curve.EaseOut })
    .position({ x: this.positionX, y: 0 })
    .translate({ x: -28, y: 8 })
    .onClick(() => {
      this.onToggle();
    })
  }
}
