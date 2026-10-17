import Util from '../common/util/Util'

@CustomDialog
@Component
export struct SFExpressDialog {
  @Link textValue: string
  controller?: CustomDialogController
  // 若尝试在CustomDialog中传入多个其他的Controller，以实现在CustomDialog中打开另一个或另一些CustomDialog，那么此处需要将指向自己的controller放在所有controller的后面
  cancel: () => void = () => {
  }
  confirm: (phone: string) => void = () => {
  }

  build() {
    Column() {
      Text('温馨提示').fontSize(20).margin({ top: 20, bottom: 20 })
      TextInput({ placeholder: '', text: this.textValue }).height(45).width('90%')
        .onChange((value: string) => {
          this.textValue = value
        })
      Text("请输入手机号/虚拟号后查询，示例：\n" +
        "0755-81234567输入075581234567、81234567、4567均可\n" +
        "1380138000输入1380138000、8000均可\n" +
        "1380138000-1234输入13801380001234、1234均可")
        .fontColor('#A9A9A9')
        .fontSize(13)
        .padding({
          left: 16,
          right: 16
        })
        .margin({ bottom: 10, top: 20 })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button('取消')
          .onClick(() => {
            if (this.controller != undefined) {
              this.controller.close()
              this.cancel()
            }
          }).backgroundColor(0xffffff).fontColor(Color.Black)
        Button('确认')
          .onClick(() => {
            if (this.controller != undefined) {
              const verify = /^\d{4,}$/;
              if (!verify.test(this.textValue)) {
                Util.toast('请最少输入4位有效虚拟号');
                return
              }

              this.controller.close()
              this.confirm(this.textValue)
              this.textValue = ''
            }
          }).backgroundColor(0xffffff).fontColor(Color.Red)
      }.margin({ bottom: 20, top: 10 })

    }.borderRadius(10)

    // 如果需要使用border属性或cornerRadius属性，请和borderRadius属性一起使用。
  }
}