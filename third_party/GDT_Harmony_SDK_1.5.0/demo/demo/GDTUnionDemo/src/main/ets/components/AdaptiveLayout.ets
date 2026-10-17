import { OrientationSafeArea } from '../utils/OrientationSafeArea';

/**
 * 横竖屏自适应布局容器。
 *
 * - 竖屏：Scroll > Column，依次排列 settings → actions → content（可选），content 不受 padding 限制。
 * - 横屏：Row > [Scroll(settings), Scroll(actions + content)]，左右分栏，各自独立滚动。
 * - 横屏时通过 OrientationSafeArea 获取左右安全区（刘海/挖孔），以 padding 形式避让。
 *
 * @param settingsBuilder 设置区域（广告位选择、配置项、横竖屏切换按钮等）
 * @param actionsBuilder 操作区域（加载/展示按钮等）
 * @param contentBuilder 内容区域（广告渲染区域等，可选；不受 padding 限制以实现全宽展示）
 */
@ComponentV2
export struct AdaptiveLayout {
  @Builder
  emptyBuilder() {
  }

  @BuilderParam settingsBuilder: () => void = this.emptyBuilder;
  @BuilderParam actionsBuilder: () => void = this.emptyBuilder;
  @BuilderParam contentBuilder: () => void = this.emptyBuilder;
  // 回传右侧展示区域（横屏）/全宽区域（竖屏）的实际宽度，供页面按实际展示宽度计算广告尺寸
  @Param onAreaWidthChange: (width: number) => void = (width: number) => {};

  @Local safeArea: OrientationSafeArea = new OrientationSafeArea();

  aboutToAppear(): void {
    this.safeArea.init();
  }

  aboutToDisappear(): void {
    this.safeArea.dispose();
  }

  build() {
    if (this.safeArea.isLandscape) {
      // 横屏：左右分栏，各自独立滚动；左右 padding 避让刘海/挖孔
      Row() {
        Scroll() {
          Column() {
            this.settingsBuilder();
          }
          .width('100%')
          .padding({ left: 16, right: 12, top: 8, bottom: 16 })
        }
        .layoutWeight(1)
        .height('100%')
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)

        Scroll() {
          Column() {
            Column() {
              this.actionsBuilder();
            }
            .width('100%')
            .padding({ left: 12, right: 16, top: 0, bottom: 0 })

            // 广告渲染区域：全宽展示，无左右 padding
            this.contentBuilder();
          }
          .width('100%')
          .padding({ top: 8, bottom: 16 })
        }
        .layoutWeight(1)
        .height('100%')
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          if (typeof newValue.width === 'number') {
            this.onAreaWidthChange(newValue.width);
          }
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.safeArea.leftInset, right: this.safeArea.rightInset })
    } else {
      // 竖屏：单列纵向滚动，从顶部开始排列
      Scroll() {
        Column() {
          Column() {
            this.settingsBuilder();
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 0 })

          Column() {
            this.actionsBuilder();
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 0 })

          // 广告渲染区域：全宽展示，无左右 padding
          this.contentBuilder();
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        if (typeof newValue.width === 'number') {
          this.onAreaWidthChange(newValue.width);
        }
      })
    }
  }
}
