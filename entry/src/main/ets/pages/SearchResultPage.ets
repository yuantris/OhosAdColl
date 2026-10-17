import View from '../common/View';
import { TitleBar } from '../common/view/TitleBar';
import { router } from '@kit.ArkUI';

export class SearchResult {
  title: string
  info: string|null

  constructor(title: string, info: string|null) {
    this.title = title
    this.info = info
  }
}

@Entry
@Component
struct SearchResultPage {
  @State message: SearchResult = router.getParams() as SearchResult;

  build() {
    Column() {

      TitleBar({
        title: '查询结果'
      })

      RelativeContainer() {
        Text(this.message.title)
          .fontColor(Color.Black)

        Row() {
          Text(this.message.info)
            .fontColor(Color.Blue)
            .fontSize(24)
        }
        .alignRules({
          middle: { anchor: View.container, align: HorizontalAlign.Center },
          center: { anchor: View.container, align: VerticalAlign.Center }
        })

        Text('注：价格仅供参考，实际价格以快递公司实际产生的费用为准。')
          .fontColor('#cccccc')
          .fontSize(12)
          .alignRules({
            middle: { anchor: View.container, align: HorizontalAlign.Center },
            bottom: { anchor: View.container, align: VerticalAlign.Bottom }
          })


      }
      .width('93%')
      .height('20%')
      .backgroundColor(Color.White)
      .margin(16)
      .padding(10)
      .borderRadius(10)

    }
    .height('100%')
    .width('100%')
    .backgroundColor('#f6f4f5')
  }
}