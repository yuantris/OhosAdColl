import { TitleBar } from '../common/view/TitleBar';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct User {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {

      TitleBar(
        {
          title: '用户协议'
        }
      )

      Column() {
        // 通过$rawfile加载本地资源文件。
        Web({ src: $rawfile("yhxy.html"), controller: this.controller })
      }
      .width('100%')
      .layoutWeight(1)
      .margin(10)
    }

  }
}