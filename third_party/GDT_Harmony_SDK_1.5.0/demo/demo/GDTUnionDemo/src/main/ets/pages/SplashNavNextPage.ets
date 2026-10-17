@Builder
export function PageBuilder() {
  SplashNavNextPage()
}

@Component
struct SplashNavNextPage {
  @State message: string = 'Navigation 方案';
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      RelativeContainer() {
        Text(this.message)
          .id('SplashNavNextPageText')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .alignRules({
            center: { anchor: '__container__', align: VerticalAlign.Center },
            middle: { anchor: '__container__', align: HorizontalAlign.Center }
          })
      }
      .height('100%')
      .width('100%')
    }
    .title('开屏广告')
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
