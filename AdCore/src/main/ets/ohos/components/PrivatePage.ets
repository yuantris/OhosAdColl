import { webview } from '@kit.ArkWeb'
import { ComposeTitleBar, router } from '@kit.ArkUI'
import { Ohos } from '@zycore/common';

const TITLE = '隐私协议'

export interface PrivatePageParams {
  pageTitle?: string,
  ysxy: string | Resource
}

export class PrivatePageConfig {
  private pageTitle: string = '';
  private ysxy: string | Resource = '';

  /**
   * 设置页面标题
   * @param title 页面标题
   * @returns 当前实例，支持链式调用
   */
  setPageTitle(title: string): PrivatePageConfig {
    this.pageTitle = title;
    return this;
  }

  /**
   * 设置隐私协议内容
   * @param content 隐私协议内容
   * @returns 当前实例，支持链式调用
   */
  setRawFile(content: string | Resource): PrivatePageConfig {
    this.ysxy = content;
    return this;
  }

  /**
   * 构建并跳转页面
   */
  buildAndPushPage(): void {
    router.pushNamedRoute({
      name: 'ZyPrivatePage',
      params: {
        pageTitle: this.pageTitle,
        ysxy: this.ysxy
      }
    });
  }

  /**
   * 创建PrivatePageConfig实例
   * @returns 新的PrivatePageConfig实例
   */
  static create(): PrivatePageConfig {
    return new PrivatePageConfig();
  }
}

@Entry({
  routeName: 'ZyPrivatePage'
})
@Component
struct ZyPrivatePage {
  controller: webview.WebviewController = new webview.WebviewController();
  @State title: string = TITLE
  @State src: string | Resource = ''

  aboutToAppear(): void {
    let params = router.getParams() as PrivatePageParams
    this.title = params.pageTitle ?? TITLE
    this.src = params.ysxy ?? ''
  }

  build() {
    Column() {
      ComposeTitleBar({ title: this.title ?? TITLE })
      Column() {
        Web({ src: this.src, controller: this.controller })
      }
      .margin(10)
      .layoutWeight(1)

    }.width('100%')
    .height('100%')
    .padding({ top: `${Ohos.getStatusBarHeight()}px` })

  }
}