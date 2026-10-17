@Entry
@Component
struct SplashRouterNextPage {
  @State message: string = 'Router 方案';

  build() {
    Column() {
      Button('返回')
        .margin({ top: 50, left: 20 })
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

      RelativeContainer() {
        Text(this.message)
          .id('SplashRouterNextPageText')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .alignRules({
            center: { anchor: '__container__', align: VerticalAlign.Center },
            middle: { anchor: '__container__', align: HorizontalAlign.Center }
          })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
  }
}
