/**
 * Banner 广告尺寸选择组件，支持输入以 dp 为单位的宽高。
 * Banner 广告仅支持具体数值，最大宽度取实际展示区域宽度。
 */
@ComponentV2
export struct BannerAdSizeView {
  defaultWidth: number = 360;
  defaultHeight: number = 96;
  @Param adWidth: number = 360;
  @Event $adWidth: (val: number) => void = (val: number) => {};
  @Param adHeight: number = 96;
  @Event $adHeight: (val: number) => void = (val: number) => {};
  // 实际展示区域宽度（横屏为右侧分栏宽），由页面传入
  @Param contentWidth: number = 360;
  @Local isMaxWidth: boolean = true;
  // 用本地文本变量管理 TextInput 显示，避免 @Param 回传与 onChange 形成循环
  @Local widthText: string = '360';
  @Local heightText: string = '96';

  // 最大宽度：取实际展示区域宽度并取整，方便展示
  private getMaxWidth(): number {
    return Math.floor(this.contentWidth);
  }

  aboutToAppear(): void {
    // 默认勾选最大宽度，初始显示值跟随 contentWidth
    if (this.isMaxWidth) {
      this.widthText = this.getMaxWidth().toString();
    }
  }

  // 转屏后展示区域宽度变化，勾选最大宽度时即时同步显示与回传
  @Monitor('contentWidth')
  onContentWidthChange(monitor: IMonitor): void {
    if (this.isMaxWidth) {
      this.widthText = this.getMaxWidth().toString();
      this.$adWidth(this.getMaxWidth());
    }
  }

  build() {
    Column() {
      Row() {
        Text('宽：').width(40)
        if (this.isMaxWidth) {
          TextInput({ text: this.widthText })
            .fontSize(20)
            .showUnderline(true)
            .width(200)
            .enabled(false)
        } else {
          TextInput({ text: this.widthText })
            .fontSize(20)
            .showUnderline(true)
            .width(200)
            .onChange((value: string) => {
              this.widthText = value;
              const adWidth = Number.parseInt(value);
              if (Number.isNaN(adWidth)) {
                return;
              }
              const clampedWidth = Math.min(adWidth, this.getMaxWidth());
              this.$adWidth(clampedWidth);
              // 输入值等于最大宽度时，自动勾选
              if (clampedWidth === this.getMaxWidth()) {
                this.widthText = this.getMaxWidth().toString();
                this.isMaxWidth = true;
              }
            })
        }
        Checkbox().shape(CheckBoxShape.ROUNDED_SQUARE).select(this.isMaxWidth)
          .onChange((value: boolean) => {
            this.isMaxWidth = value;
            if (this.isMaxWidth) {
              this.widthText = this.getMaxWidth().toString();
              this.$adWidth(this.getMaxWidth());
            } else {
              this.widthText = this.defaultWidth.toString();
              this.$adWidth(this.defaultWidth);
            }
          })
        Text('最大宽度')
      }.width('100%')

      Row() {
        Text('高：').width(40)
        TextInput({ text: this.heightText })
          .fontSize(20)
          .showUnderline(true)
          .width(200)
          .onChange((value: string) => {
            this.heightText = value;
            const adHeight = Number.parseInt(value);
            if (Number.isNaN(adHeight)) {
              return;
            }
            this.$adHeight(adHeight);
          })
      }.width('100%')
    }
  }
}
