import { CSJAdSdk } from '@csj/openadsdk/Index';
/**
 *  Created by xgc on 2024/4/22
 */

import router from '@ohos.router';
import { common } from '@kit.AbilityKit';

@Entry
@Component
export struct MainPage {
  private topMargin: number = 5
  private feedUrl = "pages/FeedAdPages"

  aboutToAppear() {
    CSJAdSdk.requestPermissionIfNeed(getContext(this) as common.UIAbilityContext);
  }

  build() {
    Column() {
      Text($r('app.string.app_name'))
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({
          top: 20,
        })
      Text($r('app.string.app_version'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Gray)
        .margin({
          top: this.topMargin,
        })
      Button("Feed信息流广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/feed/FeedAdPages"
          })
        })
      Button("开屏广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/splash/SplashAdDemoPage"
          })
        })
      Button("激励广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/reward/RewardAdPage"
          })
        })
      Button("新插屏广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/full/FullAdPage"
          })
        })
      Button("Banner广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/banner/BannerAdPage"
          })
        })
      Button("Draw广告")
        .width('100%')
        .margin({
          top: this.topMargin
        })
        .onClick(() => {
          router.pushUrl({
            url: "mediation_adtype/draw/DrawAdPage"
          })
        })
      Blank()
      Text(`SDK Version ${CSJAdSdk.getSDKVersion()}`).fontSize(14).fontColor('#999999')
    }.width('100%').height('100%')
    .padding({
      top: 10,
      left: 20,
      right: 20,
      bottom: 10
    })

  }
}