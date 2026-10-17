import { display, router, window } from '@kit.ArkUI';

@Component
export struct TitleBar {
  @Prop title: string;
  @State statusHeightPercent: number = 0
  safety_value: number = 35

  aboutToAppear(): void {
    window.getLastWindow(getContext())
      .then(win => {
        //状态栏高度
        let statusHeight = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height
        //导航栏高度
        let navigationHeight = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height

        //计算标题栏高度百分比，45是标题栏的高度vp值 safety_value是padding(margin)值
        let screen = display.getDefaultDisplaySync()
        this.statusHeightPercent =
          (45 + this.safety_value) * 100 * screen.densityPixels /
            (screen.availableHeight - statusHeight - navigationHeight)
      })
  }

  build() {
    Row() {
      Image($r('app.media.express_check_express_im_back'))
        .width(25)
        .height(25)
        .margin({ left: 10 })
        .objectFit(ImageFit.Contain)
        .onClick(() => {
          router.back()
        })
      Text(this.title)
        .layoutWeight(1)
        .height('100%')
        .textAlign(TextAlign.Start)
        .fontSize(20)
        .fontColor(Color.White)
        .padding({
          left: 10,
          right: 10
        })
        .margin({ right: 35 })
    }
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .height(this.statusHeightPercent + '%')
    .backgroundColor('#ffa4cf91')
    .padding({
      top: this.safety_value
    })
    .width('100%')

  }
}
