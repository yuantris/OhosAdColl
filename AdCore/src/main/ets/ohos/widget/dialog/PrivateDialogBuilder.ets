import { ClickUtils, Ohos, ResUtils } from '@zycore/common'
import { DialogGT } from '../../model/DialogGT'
import { Launcher } from '../../util/Launcher'

export interface PrivateParams {
  background: ResourceStr
  app_name: Resource
  titleColor?: ResourceColor
  titleSize?: number
  content: ResourceStr
  privateTextFuc: Function
  privateTextColor?: ResourceColor
  disagreeImg: Resource
  agreeImg: Resource
  agreeAction?: Function
}

@Builder
export function buildPrivateDialog(_obj: PrivateParams) {
  Column() {
    Text('欢迎使用' + ResUtils.getStringSync(_obj.app_name))
      .width('100%')
      .fontColor(_obj.titleColor)
      .fontSize(_obj.titleSize)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Center)
      .layoutWeight(2.5)

    Scroll() {
      Text(_obj.content)
    }.width('100%')
    .padding({ left: 30, right: 30 })
    .layoutWeight(6)
    .scrollBar(BarState.Off)

    Row() {
      Text('点击阅读').fontColor('#b4b4b4').fontSize('13fp')
      Text('《隐私政策》').fontColor(_obj.privateTextColor ?? '#1aa0c7').fontSize('13fp')
        .onClick(() => {
          ClickUtils.throttle(() => {
            DialogGT.closeDialog()
            setTimeout(() => {
              _obj.privateTextFuc()
            }, 100)
          })
        })
    }.width('100%')
    .margin({ top: 5 })
    .padding({
      left: 30,
      top: 5,
      right: 30,
      bottom: 3
    })

    Row() {
      Image(_obj.disagreeImg)
        .height(45).onClick(() => Ohos.exit())
        .margin({ right: '10vp' })

      Image(_obj.agreeImg)
        .height(45).onClick(() => Launcher.authorizationPrivacyPolicy().then(() => {
        DialogGT.closeDialog()
        _obj.agreeAction?.()
      }))
        .margin({ left: '10vp' })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceEvenly)
    .layoutWeight(2)
  }
  .width('90%')
  .height('60%')
  .backgroundImage(_obj.background)
  .backgroundImageSize(ImageSize.FILL)
}