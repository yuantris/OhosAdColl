import { BarCodeBean } from '../common/entity/BarCodeBean'
import View from '../common/View'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct BarCodeResult {
  barCode: string = '123456789'
  private scroller: Scroller = new Scroller()
  @State barCodes: Array<BarCodeBean> = [new BarCodeBean('商品名称', 6.8),
    new BarCodeBean('商品名称', 6.8), new BarCodeBean('商品名称', 6.8), new BarCodeBean('商品名称', 6.8)
    , new BarCodeBean('商品名称', 6.8), new BarCodeBean('商品名称', 6.8), new BarCodeBean('商品名称', 6.8)]

  build() {
    Scroll(this.scroller) {
      Column() {
        Row() {
          Image($r('app.media.im_back'))
            .width('56vp')
            .height('56vp')
            .offset({ top: View.statusBarHeight })
            .padding({
              left: View.SPACE,
              top: View.SPACE,
              right: View.SPACE,
              bottom: View.SPACE
            })
            .objectFit(ImageFit.Contain)
            .onClick(() => router.back())

          Text('查询结果')
            .fontColor('#fff')

        }.width('100%')
        .backgroundColor('#7d85ff')

        Row() {
          Image($r('app.media.app_icon'))
            .width('160vp')
            .height('160vp')
          Column() {
            Text('这是商品名称')
            Row() {
              Text('参考价格：')
              Text('¥6.8')
                .fontColor('#ff0000')
            }
          }
          .height('160vp')
          .padding({
            left: View.SPACE,
            top: View.SPACE,
            right: View.SPACE,
            bottom: View.SPACE
          })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .height('160vp')
        .borderRadius(15)
        .backgroundColor('#fff')

        Text('比价').width('100%')
          .fontColor('#000')
          .padding({
            left: View.SPACE,
            top: View.SPACE,
            right: View.SPACE,
            bottom: View.SPACE
          })

        ForEach(this.barCodes, (item: BarCodeBean, index: number) => {
          Column() {
            Row() {
              Image($r('app.media.app_icon'))
                .width('100vp')
                .height('100vp')
              Column() {
                Text('这是商品名称')
                Blank()
                Text('券后价格')
                Row() {
                  Text('¥6.8')
                    .fontColor('#ff0000')
                  Blank()
                  Text('来源：')
                  Image($r('app.media.taobao_icon'))
                    .width('30')
                    .height('30')
                }.width('100%')
              }
              .height('100vp')
              .padding({
                left: View.SPACE,
                top: View.SPACE,
                right: View.SPACE,
                bottom: View.SPACE
              })
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.SpaceBetween)
            }.width('100%')
            .height('100vp')
            .borderRadius(15)
            .backgroundColor('#fff')
          }.width('100%')
          .height('110vp')
          .padding({ top: 5, bottom: 5 })
        })

      }.width('100%')
      .padding({
        left: View.SPACE,
        top: View.SPACE,
        right: View.SPACE,
        bottom: View.SPACE
      })
    }
    .height('100%')
    .width('100%')
    .scrollable(ScrollDirection.Vertical) // 滚动方向为垂直方向
    .scrollBar(BarState.Off) // 滚动条常驻显示
    .scrollBarColor(Color.Gray) // 滚动条颜色
    .scrollBarWidth(10) // 滚动条宽度
    .edgeEffect(EdgeEffect.Spring) // 滚动到边沿后回弹
    .backgroundColor('#f0f1f4')
  }
}