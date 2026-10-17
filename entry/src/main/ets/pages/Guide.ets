import router from '@ohos.router';
import Util from '../common/util/Util';

const SHOW_GUIDE_KEY = "ShowGuideKey"
const SHOW_GUIDE_VALUE = "ShowGuide"

@Entry
@Component
struct Guide {
  @State isVisible: boolean = false;
  private swiperController: SwiperController = new SwiperController();
  private data: Resource[] = [$r('app.media.splash_1'), $r('app.media.splash_2'), $r('app.media.splash_3')];

  jumpToMainPage(): void {
    router.replaceUrl({
      url: 'pages/Index'
    });
  }

  build() {
    Row() {
      Column() {
        Swiper(this.swiperController) {
          ForEach(this.data, (item: Resource) => {
            Image(item)
              .width('100%')
              .height('100%')
              .objectFit(Util.isSpecialShapedScreen() ? ImageFit.Contain : ImageFit.Cover)

          })
        }
        .indicator(false)
        .loop(false)
        .effectMode(EdgeEffect.Spring)
        .onChange((index: number) => {
          this.isVisible = index == 2;
        })

        Image($r('app.media.splash_btn'))
          .fitOriginalSize(true)
          .offset({
            y: `-${'15%'}`
          })
          .objectFit(ImageFit.Contain)
          .visibility(this.isVisible ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => this.jumpToMainPage())

      }
      .width('100%')
    }
    .height('100%')
  }
}