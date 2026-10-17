import { router } from '@kit.ArkUI';

@Entry
@Component
export struct DrawAdPage {

  build() {
    Column() {

      Button("Draw流原生广告")
        .width('100%')
        .margin({
          top: 20
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/draw/DrawNativeAdPage"
          })
        })

    }
  }
}