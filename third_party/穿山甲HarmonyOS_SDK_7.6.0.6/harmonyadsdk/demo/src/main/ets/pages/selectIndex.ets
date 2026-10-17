import router from '@ohos.router'

@Entry
@Component
struct selectIndex {
  build() {
    Column() {
      Button("CSJ广告加载", { type: ButtonType.Capsule })
        .fontSize(20)
        .fontColor("#ffffffff")
        .margin({ top: 50 })
        .height(50)
        .width('80%')
        .onClick(() => {
          router.pushUrl({ url: 'adtype/main/MainPage'})
        })

      Button("聚合广告加载", { type: ButtonType.Capsule })
        .fontSize(20)
        .fontColor("#ffffffff")
        .margin({ top: 20 })
        .height(50)
        .width('80%')
        .onClick(() => {
          router.pushUrl({ url: 'mediation_adtype/main/MainPage'})
        })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Center)
  }
}