import { GDTAdPattern, GDTManualAd } from '@gdt/gdt-union-sdk';
import { util } from '@kit.ArkTS';
import { NativeAdParam } from '../model/NativeAdParam';
import { ManualAdVideoSize } from '../model/ManualAdVideoSize';

@Builder
export function ManualAdItemView(ad: GDTManualAd, uiContext: UIContext,
  param?: NativeAdParam,
  videoSize?: ManualAdVideoSize,
  rootViewId = util.generateRandomUUID(),
  clickableViewIds: string[] = []) {
  Column() {
    Row() {
      // 广告小图
      Image(ad.getAdData().getIconUrl())
        .height('100%').aspectRatio(1)
        .id(addViewId(clickableViewIds, util.generateRandomUUID()))
      Column() {
        // 广告标题
        Text(`${ad.getAdData().getTitle()}`)
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .id(addViewId(clickableViewIds, util.generateRandomUUID()))
        // 广告描述
        Text(`${ad.getAdData().getDesc()}`)
          .fontSize(12)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin(4)
          .id(addViewId(clickableViewIds, util.generateRandomUUID()))
      }
      .layoutWeight(2)
      .margin({ left: 12, right: 12 })

      Column() {
        // 转化按钮
        Stack() {
          Text(`${ad.getAdData().getButtonText()}`)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(40)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 10, right: 10 })
            .minFontSize(12)
            .maxFontSize(18)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .backgroundColor(0x317aff)
        .borderRadius('50%')
        .width('100%')
        .height(40)
        .id(addViewId(clickableViewIds, util.generateRandomUUID()))
      }.layoutWeight(1)
    }
    .height(64)
    .margin({ top: 12, bottom: 12 })

    if (ad.getAdPattern() === GDTAdPattern.Video) {
      Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
        Row() {
          Checkbox().shape(CheckBoxShape.ROUNDED_SQUARE).select(param?.autoPlayMuted)
            .onChange((value: boolean) => {
              ad.getVideoController()?.setAudioMute(value);
            })
          Text('静音')
        }

        Button('播放')
          .onClick((event) => {
            ad.getVideoController()?.start();
          })
          .height(35)
        Button('暂停')
          .onClick((event) => {
            ad.getVideoController()?.pause();
          })
          .height(35)
        Button('停止')
          .onClick((event) => {
            ad.getVideoController()?.stop();
          })
          .height(35)
      }
      .width('100%')
      .margin({ bottom: 12 })
    }

    Flex() {
      if (ad.getAdPattern() === GDTAdPattern.NormalImage || ad.getAdPattern() === GDTAdPattern.Video) {
        RelativeContainer() {
          if (ad.getAdPattern() === GDTAdPattern.NormalImage) {
            Stack() {
              // 模糊背景层：Cover 填满容器，超出部分被 blur + clip 柔化
              Image(ad.getAdData().getImgUrl())
                .width('100%').height('100%')
                .objectFit(ImageFit.Cover)
                // eslint-disable-next-line @performance/hp-arkui-suggest-use-effectkit-blur
                .blur(20)
              // 前景图片：Contain 完整显示，不裁剪不变形，留白处透出下层模糊背景
              Image(ad.getAdData().getImgUrl())
                .width('100%').height('100%')
                .objectFit(ImageFit.Contain)
                .id(addViewId(clickableViewIds, util.generateRandomUUID()))
            }.width('100%').height('100%')
          } else {
            NodeContainer(ad.getAdComponent())
          }
          GDTAdLogoView(ad);
        }
        .width(`${videoSize?.widthPercent ?? 100}%`)
        .aspectRatio(videoSize?.aspectRatio ?? (16 / 9))

      } else if (ad.getAdPattern() === GDTAdPattern.ThreeImage) {
        // 三小图
        Flex({ justifyContent: FlexAlign.SpaceBetween }) {
          Image(ad.getAdData().getImgList()[0])
            .width('31%')
            .aspectRatio(3 / 2)
            .id(addViewId(clickableViewIds, util.generateRandomUUID()))
          Image(ad.getAdData().getImgList()[1])
            .width('31%')
            .aspectRatio(3 / 2)
            .id(addViewId(clickableViewIds, util.generateRandomUUID()))
          RelativeContainer() {
            Image(ad.getAdData().getImgList()[2])
              .width('100%').height('100%')
              .id(addViewId(clickableViewIds, util.generateRandomUUID()))
            GDTAdLogoView(ad);
          }.width('31%')
          .aspectRatio(3 / 2)
        }.width('100%')
      }
    }

  }
  .id(rootViewId)
  .width('100%')
  .padding(12)
  .onAppear(() => {
    // 注册交互事件，影响曝光点击
    ad.registerViewForInteraction(uiContext, rootViewId, clickableViewIds);
  })
}

@Builder
function GDTAdLogoView(ad: GDTManualAd) {
  // 广告角标
  NodeContainer(ad.getAdLogoView()).width(44).height(16)
    .alignRules({
      'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
      'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
    })
}

function addViewId(clickableViewIds: string[], viewId: string): string {
  clickableViewIds.push(viewId);
  return viewId;
}
