import { CSJAdSdk, SDKConfig, SDKConfigBuilder, MediationConfigBuilder, MediationUserInfoForSegmentBuilder } from '@csj/openadsdk/Index'
import { common } from '@kit.AbilityKit'
import router from '@ohos.router'
import { ToastUtil } from '../util/ToastUtil'

@Entry
@Component
struct Index {
  private mInit: boolean = false;

  build() {
    Column() {
      Button("第一步：初始化穿山甲SDK", { type: ButtonType.Capsule })
        .fontSize(20)
        .fontColor("#333333")
        .fontWeight(FontWeight.Bold)
        .border({
          style: BorderStyle.Solid,
          color: "#ff6666",
          width: 1
        })
        .backgroundColor(Color.Transparent)
        .height(70)
        .width('90%')
        .onClick(() => {
          //第一步：初始化穿山甲SDK
          if (!this.mInit) {
            let adConfigBuilder = new SDKConfigBuilder()
            let config: SDKConfig = adConfigBuilder
              .appId("5477447")
              .appName("穿山甲Demo")
              .allowShowNotify(true)
              .debug(true)
              .setMediationConfig(
                new MediationConfigBuilder()
                  .useMediation(true)
                  .setCustomLocalConfig("GroMore-config.json")
                  .infoForSegment(
                    new MediationUserInfoForSegmentBuilder()
                      .userId('xxx_user_id')
                      .channel('xxx_channel')
                      .build()
                  )
                  .build()
              )
              .build()
            CSJAdSdk.init(getContext(this), config)
            this.mInit = true;
            ToastUtil.showToast("初始化成功")
          } else {
            ToastUtil.showToast("您已经初始化了")
          }
        })

      Button("第二步：开始展示广告", { type: ButtonType.Capsule })
        .fontSize(20)
        .fontColor("#333333")
        .fontWeight(FontWeight.Bold)
        .border({
          style: BorderStyle.Solid,
          color: "#ff6666",
          width: 1
        })
        .backgroundColor(Color.Transparent)
        .margin({ top: 100 })
        .height(70)
        .width('90%')
        .onClick(() => {
          //第二步：开始穿山甲使用穿山甲SDK
          if (this.mInit) {
            CSJAdSdk.start().then((result) => {
              if (result) {
                if (result.code == 0 || result.code == 4200) {
                  router.replaceUrl({ url: 'pages/selectIndex' })
                } else {
                  ToastUtil.showToast(result.msg);
                }
              }
            })
          } else {
            ToastUtil.showToast("请您先点击第一步进行初始化");
          }
        })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}