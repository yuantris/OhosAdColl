import { GDTAdSDK } from '@gdt/gdt-union-sdk';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { DemoConstants } from '../constants/DemoConstants';

@Builder
export function PageBuilder() {
  SettingsPage()
}

@ComponentV2
struct SettingsPage {
  pathStack: NavPathStack = new NavPathStack();
  @Local audioSessionManager: audio.AudioSessionManager =
    audio.getAudioManager().getSessionManager();
  @Local mixEnabled: boolean = false;

  aboutToAppear(): void {
    try {
      const pref = preferences.getPreferencesSync(DemoConstants.uiAbilityContext, { name: DemoConstants.PREF_NAME });
      this.mixEnabled = pref.getSync(DemoConstants.KEY_AUDIO_CONCURRENCY, false) as boolean;
      if (this.mixEnabled) {
        this.activateMixMode();
      }
    } catch (err) {
      // 首次进入无缓存，保持默认 false
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // SDK 版本信息
          Column() {
            Row() {
              Text('SDK 版本号')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .margin({ bottom: 8 })

            Divider().margin({ bottom: 12 })

            Row() {
              Text(`${GDTAdSDK.getSDKVersion()}`)
                .fontSize(16)
                .fontColor('#317aff')
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor(0xFFFFFF)
          .borderRadius(10)
          .padding(15)
          .margin({ bottom: 20 })

          // 音频并发模式设置
          Column() {
            Row() {
              Text('音频并发模式')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .margin({ bottom: 8 })

            Divider().margin({ bottom: 12 })

            Row() {
              Column() {
                Text('混音模式 (CONCURRENCY_MIX_WITH_OTHERS)')
                  .fontSize(14)
                  .fontColor('#333333')
                Text('开启后与其他应用同时播放音频，互不打断')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.mixEnabled })
                .onChange((isOn: boolean) => {
                  this.mixEnabled = isOn;
                  if (isOn) {
                    this.activateMixMode();
                  } else {
                    this.deactivateMixMode();
                  }
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .backgroundColor(0xFFFFFF)
          .borderRadius(10)
          .padding(15)
        }
      }
      .padding(20)
    }
    .title('设置')
    .backgroundColor('#F1F3F5')
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  private activateMixMode(): void {
    const strategy: audio.AudioSessionStrategy = {
      concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS
    };
    this.audioSessionManager.activateAudioSession(strategy)
      .then(() => {
        this.saveAudioConcurrencyMode(true);
        console.info('SettingsPage: 混音模式已激活');
      })
      .catch((err: BusinessError) => {
        console.error(`SettingsPage: 激活混音模式失败 ${err.code} ${err.message}`);
        this.mixEnabled = false;
        this.saveAudioConcurrencyMode(false);
      });
  }

  private deactivateMixMode(): void {
    this.audioSessionManager.deactivateAudioSession()
      .then(() => {
        this.saveAudioConcurrencyMode(false);
        console.info('SettingsPage: 混音模式已停用');
      })
      .catch((err: BusinessError) => {
        console.error(`SettingsPage: 停用混音模式失败 ${err.code} ${err.message}`);
        this.mixEnabled = true;
        this.saveAudioConcurrencyMode(true);
      });
  }

  private saveAudioConcurrencyMode(enabled: boolean): void {
    try {
      const pref = preferences.getPreferencesSync(DemoConstants.uiAbilityContext, { name: DemoConstants.PREF_NAME });
      pref.putSync(DemoConstants.KEY_AUDIO_CONCURRENCY, enabled);
      pref.flush();
    } catch (err) {
      console.error('SettingsPage: 保存混音模式状态失败');
    }
  }
}
