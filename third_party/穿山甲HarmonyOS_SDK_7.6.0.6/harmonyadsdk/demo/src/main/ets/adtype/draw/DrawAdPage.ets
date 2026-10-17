import { router } from '@kit.ArkUI';

@Entry
@Component
export struct DrawAdPage {
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

      Button("Draw流原生广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "adtype/draw/DrawNativeAdPage",
            params: this.mBiddingAdm
          })
        })

      Button("Draw流模板广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "adtype/draw/DrawExpressAdPage",
            params: this.mBiddingAdm
          })
        })
    }
  }
}