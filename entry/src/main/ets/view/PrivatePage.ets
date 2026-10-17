import { TitleBar } from '../common/view/TitleBar';
import { webview } from '@kit.ArkWeb';

const web = 'https://short.ss.bscstorage.com/privacy/hm/78325b981900.html?v=3419'

@Entry
@Component
struct Private {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {

      TitleBar(
        {
          title: '隐私协议'
        }
      )

      Column() {
        // 通过$rawfile加载本地资源文件。
        Web({ src: web, controller: this.controller })
      }
      .width('100%')
      .layoutWeight(1)
      .margin(10)
    }

  }
}