/**
 * Created by Wuzejian on 2024/2/18
 * Usage: feed 主页面
 */
import { router } from '@kit.ArkUI'

@Entry
@Component
export struct feedAdPage {
  private mNum: number = 1 // 请求的广告数量

  build() {
    Column() {
      Row() {
        Text("广告数量：")
        TextInput({ placeholder: "3" })
          .width("80%")
          .onChange((value) => {
            this.mNum = Number.parseInt(value)
            console.log(`adNum onChanage ${value}`)
          })
      }
      .margin({ top: 20 })

      Button("请求模版&自渲染")
        .width('100%')
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/feed/FeedNativeAdPage",
            params: this.mNum
          })
        })
        .margin({ top: 20 })
    }
    .padding({
      left: 30,
      right: 30
    })
  }
}
