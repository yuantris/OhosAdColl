// CustomDialogComponent.ets
import View from '../common/View';

// 自定义弹窗
@CustomDialog
export default struct LoadingDialog {
  msg: string = ''
  controller: CustomDialogController = new CustomDialogController({ 'builder': '' });

  build() {
    Column() {
      LoadingProgress()
      Text(this.msg)
    }
    .padding({
      left: View.SPACE_DIALOG,
      top: View.SPACE_DIALOG,
      right: View.SPACE_DIALOG,
      bottom: View.SPACE_DIALOG
    })
    .width('30%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceAround)
    .borderRadius(15)
    .backgroundColor(Color.White)
  }
}