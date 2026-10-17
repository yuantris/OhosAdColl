/**
 * Created by Wuzejian on 2024/2/18
 * Usage: feed 主页面
 */
import { router } from '@kit.ArkUI'

@Entry
@Component
export struct feedAdPage {
  private mBiddingAdm = '' //服务端Bidding才需要设置

  build() {
    Column() {
      Row() {
        Text("adm：")
        TextInput({ placeholder: "adm" })
          .width("80%")
          .onChange((value) => {
            this.mBiddingAdm = value
            console.log(`csjAdm onChanage ${value}`)
          })
      }.margin({ top: 20 })

      Button("Feed信息流广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "adtype/feed/FeedNativeAdPage",
            params: this.mBiddingAdm
          })
        })

      Button("Feed信息流模板广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "adtype/feed/FeedExpressAdPage",
            params: this.mBiddingAdm
          })
        })
    }
  }
}
