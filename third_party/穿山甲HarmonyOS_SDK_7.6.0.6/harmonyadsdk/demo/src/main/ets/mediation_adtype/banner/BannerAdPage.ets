import { router } from '@kit.ArkUI'

@Entry
@Component
export struct BannerAdPage {
  build() {
    Column() {
      Button("banner流模板广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/banner/BannerExpressAdPage"
          })
        })
    }
  }
}