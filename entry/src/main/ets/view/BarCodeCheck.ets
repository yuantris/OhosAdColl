import { TitleBar } from '../common/view/TitleBar';

@Component
export default struct BarCodeCheck {
  @State message: string = 'Hello World';

  build() {
    Stack() {

      Column() {
        TitleBar()

        Text('示例：')
          .textAlign(TextAlign.Start)
          .fontColor(Color.White)
          .margin({ left: 15, top: 20 })

        Row() {
          defaultBuilder($r('app.media.express_check_code_step1'), '1.点击条形码扫描按钮')
          defaultBuilder($r('app.media.express_check_code_step2'), '2.对准商品的条形码进行扫描')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)

        Row() {
          Text('3.扫描完成，列表显示不同\n平台价格对比')
            .fontColor(Color.White)
          Image($r('app.media.express_check_code_step3'))
            .fitOriginalSize(true)
        }
        .margin({ top: 30 })
        .justifyContent(FlexAlign.SpaceAround)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)

      RelativeContainer() {
        Image($r('app.media.express_check_code_check_bt'))
          .fitOriginalSize(true)
          .margin({ top: 70 })
          .alignRules({
            middle: { anchor: '__container__', 'align': HorizontalAlign.Center }
          })
      }
      .width('100%')
      .height('40%')
      .offset({ y: '70%' })
      .backgroundImage($r('app.media.express_check_code_bottom_bg'))
    }
    .stackBgStyle()
  }
}

@Builder
function defaultBuilder(icon: Resource, text: string) {
  Column({ space: 30 }) {
    Text(text)
      .fontColor(Color.White)
    Image(icon)
      .fitOriginalSize(true)

  }.width('50%')
  .alignItems(HorizontalAlign.Center)
}

@Extend(Stack)
function stackBgStyle() {
  .width('100%')
  .height('100%')
  .backgroundImage($r('app.media.express_check_code_check_bg'))
  .backgroundImageSize({ width: '100%', height: '100%' })
  .alignContent(Alignment.Top)
}


