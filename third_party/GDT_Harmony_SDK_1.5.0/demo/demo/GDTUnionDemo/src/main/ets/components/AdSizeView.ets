import { GDTAdSize } from '@gdt/gdt-union-sdk';

/**
 * 支持输入以 dp 为单位的宽高
 */
@ComponentV2
export struct AdSizeView {
  defaultHeight: number = 320;
  @Param adWidth: number = 0;
  @Event $adWidth: (val: number) => void = (val: number) => {};
  @Param adHeight: number = 0;
  @Event $adHeight: (val: number) => void = (val: number) => {};
  // 实际展示区域宽度（横屏为右侧分栏宽），由页面传入，取消最大宽度时回退用
  @Param contentWidth: number = 360;
  @Local fillWidth: boolean = false;
  @Local autoHeight: boolean = true;

  // 取实际展示区域宽度并取整，方便展示
  private getContentWidth(): number {
    return Math.floor(this.contentWidth);
  }

  // 转屏后展示区域宽度变化，取消最大宽度时即时回退更新
  @Monitor('contentWidth')
  onContentWidthChange(monitor: IMonitor): void {
    if (!this.fillWidth) {
      this.$adWidth(this.getContentWidth());
    }
  }

  build() {
    Column() {
      Row() {
        Text('宽：').width(40)
        TextInput({ text: !Number.isNaN(this.adWidth) ? this.adWidth.toString() : '' })
          .fontSize(20)
          .showUnderline(true)
          .width(120)
          .onChange((value: string) => {
            const adWidth = Number.parseInt(value);
            if (Number.isNaN(adWidth)) {
              return;
            }
            this.$adWidth(adWidth);
          })
        Checkbox().shape(CheckBoxShape.ROUNDED_SQUARE).select(this.fillWidth)
          .onChange((value: boolean) => {
            this.fillWidth = value;
            if (this.fillWidth) {
              this.$adWidth(GDTAdSize.FULL_WIDTH);
            } else {
              this.$adWidth(this.getContentWidth());
            }
          })
        Text('最大宽度')
      }.width('100%')

      Row() {
        Text('高：').width(40)
        TextInput({ text: !Number.isNaN(this.adHeight) ? this.adHeight.toString() : '' })
          .fontSize(20)
          .showUnderline(true)
          .width(120)
          .onChange((value: string) => {
            const adHeight = Number.parseInt(value);
            if (Number.isNaN(adHeight)) {
              return;
            }
            this.$adHeight(adHeight);
          })
        Checkbox().shape(CheckBoxShape.ROUNDED_SQUARE).select(this.autoHeight)
          .onChange((value: boolean) => {
            this.autoHeight = value;
            if (this.autoHeight) {
              this.$adHeight(GDTAdSize.AUTO_HEIGHT);
            } else {
              this.$adHeight(this.defaultHeight);
            }
          })
        Text('自适应高度')
      }.width('100%')
    }
  }
}
