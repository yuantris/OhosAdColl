import { Ohos, Preferences } from '@zycore/common'
import { AdSlotManager } from '../../helper/core/AdSlotManager'
import { getPlatformName, PlatformType } from '../../model/PlatformType'
import { bundleManager, Want } from '@kit.AbilityKit'
import { SDKCore } from '../../application/SDKCore'
import { AdModeManager } from '../../helper/core/AdModeManager'
import { AdSlotState, AdStateManager } from '../../helper/core/AdStateManager'
import { AdUIData } from '../../storage/AdUIData'
import { AppStorageV2 } from '@kit.ArkUI'

export const IS_TEST_ID = 'ZY_DEBUG_IS_TEST_ID'

export const AD_LOCATION_SLOT = 'ZY_AD_LOCATION_SLOT'

export const AD_EASY_SLOT = 'ZY_EASY_AD_LOCATION_SLOT'

interface DebugAdInfo {
  adSlot: string,
  platforms: PlatformType[]
}

const ads: DebugAdInfo[] = [
  {
    adSlot: 'splash',
    platforms: [PlatformType.HUAWEI, PlatformType.CSJ, PlatformType.TENCENT]
  },
  {
    adSlot: 'info',
    platforms: [PlatformType.HUAWEI, PlatformType.CSJ, PlatformType.TENCENT]
  },
  {
    adSlot: 'info_left',
    platforms: [PlatformType.HUAWEI, PlatformType.CSJ, PlatformType.TENCENT]
  },
  {
    adSlot: 'video',
    platforms: [PlatformType.HUAWEI, PlatformType.CSJ, PlatformType.TENCENT]
  },
  {
    adSlot: 'lscr',
    platforms: [PlatformType.HUAWEI, PlatformType.CSJ, PlatformType.TENCENT]
  }
]

@Preview
@ComponentV2
export struct AdIdInfoComponent {
  @Local testID: boolean = Ohos.debug()
  @Local adState: AdSlotState[] = []
  @Param forceClose: boolean = false
  @Local uiData: AdUIData = AppStorageV2.connect<AdUIData>(AdUIData, 'ad_debug_ui_data', () => new AdUIData())!;

  aboutToAppear(): void {
    this.testID = Preferences.getBooleanSync(IS_TEST_ID, Ohos.debug())
    this.adState = AdStateManager.getInstance().getAllAdSlots()
  }

  aboutToDisappear(): void {
  }

  @Monitor('uiData.adSlotUpdated')
  onAdSlotUpdated(): void {
    this.adState = AdStateManager.getInstance().getAllAdSlots()
  }

  build() {
    if (Ohos.debug() && !this.forceClose) {
      Scroll() {
        Column({ space: 12 }) {
          // 测试ID开关区域
          this.buildTestIDSection()

          // 广告模式信息
          if (SDKCore.OFF) {
            this.buildAdModeInfo()
          }

          // 信息流广告位详情
          this.buildAdSlotSection()

          // 广告真实ID展示
          this.buildAdIdSection()

          // 诊断信息区域
          this.buildDiagnosticSection()
        }
        .borderRadius(12)
        .padding(16)
        .width('90%')
        .constraintSize({ minHeight: 200 })
        .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.LIGHT, adaptiveColor: AdaptiveColor.DEFAULT })
        .backgroundBrightness({ rate: 0.5, lightUpDegree: -0.1 })
      }
    }
  }

  @Builder
  buildTestIDSection() {
    Column({ space: 8 }) {
      Row() {
        Text('测试ID模式')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Red)
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.testID })
          .selectedColor('#007DFF')
          .switchPointColor('#FFFFFF')
          .onChange((isOn: boolean) => {
            Preferences.putSync(IS_TEST_ID, isOn)
            this.getUIContext().getPromptAction().showToast({ message: '正在重启APP...' })
            setTimeout(() => {
              let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
                bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_ABILITY;
              const ability = bundleManager.getBundleInfoForSelfSync(bundleFlags)
              let want: Want = {
                deviceId: '',
                bundleName: Ohos.getBundleName(),
                abilityName: ability.hapModulesInfo[0].mainElementName,
              };
              this.getUIContext().getHostContext()?.getApplicationContext()?.restartApp(want)
            }, 1000)
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 8, right: 8 })
      .backgroundColor('rgba(255, 255, 255, 0.05)')
      .borderRadius(6)

    }
  }

  @Builder
  buildAdModeInfo() {
    Text(`当前广告模式: ${JSON.stringify(SDKCore.OFF.ss)} | 展示: ${AdModeManager.getADMode(SDKCore.OFF)}`)
      .fontSize(10)
      .fontColor(Color.Red)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(6)
      .backgroundColor('rgba(255, 0, 0, 0.08)')
      .borderRadius(4)
      .margin({ top: 2, bottom: 2 })
  }

  @Builder
  buildAdSlotSection() {
    Column({ space: 6 }) {
      Text('[信息流广告位详情]')
        .fontSize(11)
        .fontColor(0xFF69B4)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 4 })

      List() {
        ForEach(this.adState, (ad: AdSlotState, index) => {
          ListItem() {
            this.adSlotInfo(ad)
          }
        }, (item: AdSlotState, index) => item.adId)
      }
      .divider({ strokeWidth: 1, color: 'rgba(255, 255, 255, 0.1)' })
      .scrollBar(BarState.Off)
      .listDirection(Axis.Vertical)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('auto')
      .backgroundColor('rgba(255, 255, 255, 0.03)')
      .borderRadius(6)
      .padding(4)
    }
  }

  @Builder
  buildAdIdSection() {
    Column({ space: 6 }) {
      Text('[广告真实ID展示]')
        .fontSize(11)
        .fontColor(0xFF69B4)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 4 })

      List() {
        ForEach(ads, (ad: DebugAdInfo) => {
          ListItem() {
            this.buildAdIdInfo(ad)
          }
        }, (item: DebugAdInfo, index) => `${item.adSlot}_${index}`)
      }
      .divider({ strokeWidth: 1, color: 'rgba(255, 255, 255, 0.1)' })
      .scrollBar(BarState.Off)
      .listDirection(Axis.Vertical)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height(200)
      .backgroundColor('rgba(255, 255, 255, 0.03)')
      .borderRadius(6)
      .padding(4)
    }
  }

  @Builder
  buildAdIdInfo(info: DebugAdInfo) {
    Column({ space: 4 }) {
      Text(`${info.adSlot.toUpperCase()}:`)
        .fontSize(13)
        .fontColor(0xE0E0E0)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 4 })

      Column({ space: 2 }) {
        ForEach(info.platforms, (platform: PlatformType) => {
          Row() {
            Text(`${getPlatformName(platform)}:`)
              .fontSize(11)
              .fontColor(0xB0B0B0)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)

            Text(`${AdSlotManager.getInstance().getRealAdId(info.adSlot, platform)}`)
              .fontSize(11)
              .fontColor(0x80FF80)
              .fontWeight(FontWeight.Normal)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({
            left: 12,
            right: 4,
            top: 1,
            bottom: 1
          })
          .backgroundColor('rgba(255, 255, 255, 0.02)')
          .borderRadius(3)
        }, (item: PlatformType, index) => `${item.toString()}_${index}`)
      }
      .margin({ left: 4 })
    }
    .padding(6)
    .backgroundColor('rgba(255, 255, 255, 0.02)')
    .borderRadius(4)
    .margin({ top: 2, bottom: 2 })
  }

  @Builder
  adSlotInfo(info: AdSlotState) {
    Column({ space: 3 }) {
      Text(`广告位: ${info.pageId}`)
        .fontSize(11)
        .fontColor(0xB0B0B0)
        .fontWeight(FontWeight.Normal)
        .width('100%')

      Text(`${info.adId.toUpperCase()}`)
        .fontSize(12)
        .fontColor(0x80FF80)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)
    }
    .padding(6)
    .backgroundColor('rgba(255, 255, 255, 0.02)')
    .borderRadius(4)
    .margin({ top: 2, bottom: 2 })
  }

  @Builder
  buildDiagnosticSection() {
    Column({ space: 6 }) {
      Text('[诊断信息]')
        .fontSize(11)
        .fontColor(0xFF69B4)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 4 })

      List() {
        ForEach(this.adState, (state: AdSlotState) => {
          ListItem() {
            this.diagnosticSlotInfo(state)
          }
        }, (item: AdSlotState, index) => `${item.adId}_${index}`)
      }
      .divider({ strokeWidth: 1, color: 'rgba(255, 255, 255, 0.1)' })
      .scrollBar(BarState.Off)
      .listDirection(Axis.Vertical)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('auto')
      .backgroundColor('rgba(255, 255, 255, 0.03)')
      .borderRadius(6)
      .padding(4)
    }
  }

  @Builder
  diagnosticSlotInfo(state: AdSlotState) {
    Column({ space: 3 }) {
      Text(`${state.adId} @ ${state.pageId}`)
        .fontSize(11)
        .fontColor(0xB0B0B0)
        .fontWeight(FontWeight.Normal)
        .width('100%')

      Text(`状态: ${state.status}`)
        .fontSize(11)
        .fontColor(0x80FF80)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Text(`活跃: ${Date.now() - state.lastActiveTime}ms前`)
        .fontSize(10)
        .fontColor(0x909090)
        .width('100%')
    }
    .padding(6)
    .backgroundColor('rgba(255, 255, 255, 0.02)')
    .borderRadius(4)
    .margin({ top: 2, bottom: 2 })
  }
}