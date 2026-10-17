import { homePageMap, HomeScreen, homeScreenName, onTripleTap } from '@gdt/gdt-union-demo/ets/components/HomeScreen';
import { onIndexAboutToAppear, onIndexAboutToDisappear } from '@gdt/gdt-union-demo/ets/utils/AbilityHooks';

const storage: LocalStorage = new LocalStorage();

@Entry(storage)
@ComponentV2
struct Index {
  @Provider() pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    onIndexAboutToAppear(this.pathStack);
  }

  aboutToDisappear(): void {
    onIndexAboutToDisappear();
  }

  @Builder
  pageMap(name: string, param: Object) {
    homePageMap(name, param);
  }

  build() {
    Navigation(this.pathStack) {
      Scroll() {
        Column() {
          HomeScreen(this.pathStack);
        }
        .width('100%')
        .align(Alignment.TopStart)
      }
      .width('100%')
      .padding(20)
      .scrollBar(BarState.Off)
    }
    .title(homeScreenName())
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .parallelGesture(
      TapGesture({ fingers: 3, count: 1 })
        .onAction(() => {
          onTripleTap(this.pathStack);
        })
    )
  }
}
