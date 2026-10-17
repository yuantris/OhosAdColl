import { EmitterUtils, Log } from '@zycore/common'
import { RequestApplication } from '../application/RequestApplication'
import { StartHelper } from '../config/StartHelper'
import { DialogGT } from '../model/DialogGT'
import { Launcher } from '../util/Launcher'
import { SplashMonitor } from '../util/SplashMonitor'
import { buildPrivateDialog, PrivateParams } from '../widget/dialog/PrivateDialogBuilder'
import { promptAction } from '@kit.ArkUI'

let timer: number = -1

@Component
export struct SplashComponent {
  @Prop privateParams: PrivateParams
  dialogOptions?: promptAction.BaseDialogOptions = undefined
  onReady: Function = (isMain: boolean) => {
  };

  aboutToAppear(): void {
    // onPageShow
    EmitterUtils.onSubscribe<string>(SplashMonitor.ONPAGESHOW, (data) => {
      Launcher.checkPrivateDialogAsync().then((showDialog) => {
        if (showDialog) {
          DialogGT.showPopView<PrivateParams>(wrapBuilder(buildPrivateDialog), {
            background: this.privateParams.background,
            app_name: this.privateParams.app_name,
            titleColor: this.privateParams.titleColor,
            titleSize: this.privateParams.titleSize,
            content: this.privateParams.content,
            privateTextFuc: () => {
              this.privateParams.privateTextFuc()
            },
            disagreeImg: this.privateParams.disagreeImg,
            agreeImg: this.privateParams.agreeImg,
            agreeAction: () => this.startTiming()
          }, this.dialogOptions, 100, this.getUIContext())
        } else {
          this.startTiming()
        }
      })
    })
    // onPageHide
    EmitterUtils.onSubscribe<string>(SplashMonitor.ONPAGEHIDE, (data) => {
      DialogGT.closePopView()
    })
  }

  startTiming(): void {
    if (timer == -1) {
      timer = setInterval(() => {
        Launcher.checkGuideAsync().then((value) => {
          Log.debug(`checkGuideAsync：${value}`)
          this.clearTiming()
          if (value) {
            this.onReady(false)
          } else {
            this.onReady(true)
          }
        })
      }, 700)
    }
  }

  clearTiming(): void {
    if (timer !== -1) {
      clearInterval(timer);
      timer = -1;
    }
  }

  aboutToDisappear(): void {
    this.clearTiming()
    EmitterUtils.off<string>(SplashMonitor.ONPAGESHOW)
    EmitterUtils.off<string>(SplashMonitor.ONPAGEHIDE)
  }

  build() {
    Row() {
      Column() {
        Image(RequestApplication.appConfig.launcherBgRes)
          .width('100%')
          .height('100%')
      }
      .width('100%')
    }
    .height('100%')
  }
}