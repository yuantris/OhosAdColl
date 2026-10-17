@ComponentV2
export struct ButtonItem {
  @Require @Param title: string;

  build() {
    Button(this.title, { stateEffect: true, type: ButtonType.Normal })
      .width('100%')
      .borderRadius(8)
      .backgroundColor(0x317aff)
      .height(40)
  }
}
