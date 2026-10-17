import { router, window } from '@kit.ArkUI'
import { SplashShowHandler, SPLASH_EVENT } from '../helper/handler/SplashShowHandler'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { Log, Ohos } from '@zycore/common'
import { RequestApplication } from '../application/RequestApplication'

export class StartHelper {
  static pushSplashAdPage(): Promise<void> {
    new SplashShowHandler().registerSplashReceiver()
    Ohos.getWindowStage().createSubWindow("SplashShowPage").then((window) => {
      let storage: LocalStorage = new LocalStorage()
      storage.setOrCreate<window.Window>('window', window)
      window.loadContentByName('SplashShowPage', storage, (err, data) => {
        // 设置窗口透明
        window.setWindowBackgroundColor('#00000000')
        window.showWindow()
      })

    })
    return Promise.resolve()
  }

  static replaceNamedRoute(): Promise<void> {
    new SplashShowHandler().registerSplashReceiver()
    return router.replaceNamedRoute({
      name: 'SplashShowPage'
    })
  }

  static checkSplashEvent() {
    let options: commonEventManager.CommonEventPublishData = {
      parameters: {
        'mainPage': RequestApplication.appConfig.mainPage,
        'guidePage': RequestApplication.appConfig.guidePage,
      }
    }

    // 发布公共事件
    try {
      commonEventManager.publish(SPLASH_EVENT, options, (err: BusinessError) => {
        if (err) {
          Log.error(`Failed to publish checkSplashPage event. Code is ${err.code}, message is ${err.message}`)
          return;
        }
      });
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      Log.error(`Failed to publish checkSplashPage event. Code is ${err.code}, message is ${err.message}`);
    }
  }
}