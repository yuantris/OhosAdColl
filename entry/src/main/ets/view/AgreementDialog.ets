// CustomDialogComponent.ets
import router from '@ohos.router';
import View from '../common/View';

// 自定义弹窗
@CustomDialog
export default struct AgreementDialog {
  controller: CustomDialogController = new CustomDialogController({ 'builder': '' });
  // 不同意按钮回调
  cancel: Function = () => {
  };
  // 同意按钮回调
  confirm: Function = () => {
  };

  build() {
    Column() {
      Text('欢迎使用' + getContext().resourceManager.getStringSync($r('app.string.app_name')))
        .width('100%')
        .textAlign(TextAlign.Center)
        .layoutWeight(2)

      Scroll() {
        Text('欢迎您使用本软件。本软件非常重视保护您的个人权益和隐私信息。' +
          '在您使用本软件之前，请您务必认真阅读，并充分理解《用户协议》和《隐私政策》全部条款。' +
          '我们将通过上述协议向您说明我们如何收集、使用和保护您的相关信息。未经您的允许，我们不会获取您的任何权限信息。' +
          '若您点击了“同意”按钮，则代表您已同意上诉协议的全部内容。 \n同时为了保证本软件的使用体验，我们需要告知您在使用过程中获取的手机权限：' +
          '\n1、我们需要获取您的电话权限，用于统计分析服务，校准报表数据准确性； ' +
          '\n2、我们需要获取您的设备信息：包括硬件序列号、设备MAC地址、软件安装列表、唯一设备识别码[如IMEI/android ID/SIM卡IMSI信息等]，' +
          '用于SDK功能的实现; \n3、操作日志：获取应用使用情况及BUG信息，用于不断优化和改善本应用； ' +
          '\n4、电话权限：用于统计分析服务，校准报表数据准确性； \n5、唤醒锁定权限：用于加载并展示视频类型广告。 ' +
          '\n更多详细信息，请您阅读隐私政策、用户协议的完整条款。')
      }.width('100%')
      .padding({ left: 30, right: 30 })
      .layoutWeight(6)
      .scrollBar(BarState.Off)

      Row() {
        Text('点击阅读').fontColor('#b4b4b4').fontSize('13fp')
        Text('《用户协议》').fontColor('#1aa0c7').fontSize('13fp')
          .onClick(() => {
            this.controller.close()
            router.pushUrl({ url: 'view/UserPage' })
          })
        Text('和').fontColor('#b4b4b4').fontSize('13fp')
        Text('《隐私政策》').fontColor('#1aa0c7').fontSize('13fp')
          .onClick(() => {
            this.controller.close()
            router.pushUrl({ url: 'view/PrivatePage' })
          })
      }.width('100%')
      .padding({
        left: 30,
        top: 5,
        right: 30,
        bottom: 3
      })

      Row() {
        Image($r('app.media.agreement_disagree'))
          .height(45).onClick(() => this.cancel())
          .margin({ right: View.SPACE_DIALOG_HALF })
        Image($r('app.media.agreement_agree'))
          .height(45).onClick(() => this.confirm())
          .margin({ left: View.SPACE_DIALOG_HALF })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceEvenly)
      .layoutWeight(2)
    }
    .width(px2vp(1000))
    .height('60%')
    .backgroundColor('#fff')
    .borderRadius(15)

  }
}