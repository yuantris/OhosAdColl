import { promptAction, router } from '@kit.ArkUI'
import { bundleManager, Want } from '@kit.AbilityKit'
import Util from '../common/util/Util';
import { Log, Ohos } from '@zycore/common';
import { AdIdInfoComponent, FeedAdComponent } from '@zysdk/ad-core-hm';

function startBrowsableAbility(): void {
  let want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: 'https://beian.miit.gov.cn/'
  };
  Ohos.getContext().startAbility(want)
    .catch((err: object) => {
      Log.debug('startBrowsableAbility failed: ' + JSON.stringify(err))
      Util.toast('无法开启系统浏览器')
    });
}

@Component
export default struct SetPage {
  scroller: Scroller = new Scroller();

  build() {

    Scroll(this.scroller) {
      Column({ space: 10 }) {

        Column({ space: 10 }) {

          Image($r('app.media.set_version'))
            .width('100%')
            .fitOriginalSize(true)
            .onClick(() => {
              promptAction.showToast({
                message: bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
                  | bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA).versionName
              })
            })

          Image($r('app.media.set_beian'))
            .width('100%')
            .fitOriginalSize(true)

          Image($r('app.media.set_ysxy'))
            .width('100%')
            .fitOriginalSize(true)
            .onClick(() => {
              // PrivatePageConfig.create()
              //   .setPageTitle("隐私协议")
              //   .setRawFile($rawfile('ysxy.html'))
              //   .buildAndPushPage()
            })

          Image($r('app.media.set_yhxy'))
            .width('100%')
            .fitOriginalSize(true)
            .onClick(() => {
              router.pushUrl({ url: 'view/UserPage' })
            })

        }.width('90%')
        .padding({
          top: 10,
          bottom: 10,
          left: 15,
          right: 15
        })
        .backgroundImage($r('app.media.set_item_bg'))
        .backgroundImageSize(ImageSize.FILL)

        FeedAdComponent({
          adId: "info_left",
          uniqueId: "设置",
          adWidth: '90%',
        })

        AdIdInfoComponent({
          forceClose: false
        })

      }
      .width('100%')
    }
    .padding({ top: 54 })
    .backgroundImage($r('app.media.set_bg'))
    .backgroundImageSize(ImageSize.FILL)
    .scrollBar(BarState.Off)

  }

  @Builder
  mineItemBuilder(icon: Resource, title: string, callback: () => void) {
    Row({ space: 10 }) {
      Image(icon)
        .width(24)
        .height(24)
      Text(title)
        .fontSize(16)
        .height(24)
        .fontWeight(FontWeight.Medium)
      Blank()
      Image($r('app.media.my_more_right'))
        .fitOriginalSize(true)
    }.width('100%')
    .height(40)
    .onClick(() => {
      callback();
    })
  }
}

