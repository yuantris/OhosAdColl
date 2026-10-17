/** 自渲染视频区域尺寸（仅 Demo 用）。 */
@ObservedV2
export class ManualAdVideoSize {
  /** 宽度百分比，1~100，默认 100 */
  @Trace public widthPercent: number = 100;
  /** 高宽比 width / height，默认 16/9 */
  @Trace public aspectRatio: number = 16 / 9;
}
