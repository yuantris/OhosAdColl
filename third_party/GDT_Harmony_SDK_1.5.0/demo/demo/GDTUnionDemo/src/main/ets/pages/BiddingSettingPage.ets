import { BiddingSetting, getBiddingSetting } from '../model/BiddingSetting';

export enum LossReason {
  InadequateCompetitiveness = '1', // 竞争力不足
  Timeout = '2', // 返回超时
  NoAdResponse = '3', // 无广告回包
  InvalidResponse = '4', // 回包不合法
  Other = '10000', // 其他
}

@Builder
export function PageBuilder() {
  BiddingSettingPage()
}

@ComponentV2
struct BiddingSettingPage {
  pathStack: NavPathStack = new NavPathStack();
  // '': 不上报, '-1': 上报竞胜，其他为竞败
  @Local setting: BiddingSetting = getBiddingSetting();

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Column() {
            Row() {
              Text('请求广告成功时')
            }.width('100%').margin({ bottom: 5 })

            Divider().margin({ top: 5, bottom: 8 })

            Column() {
              Row() {
                Text('不上报').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: '0', group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === '0')
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = '0');
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞胜').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: '-1', group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === '-1')
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = '-1');
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败_LOW_PRICE').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.InadequateCompetitiveness, group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === LossReason.InadequateCompetitiveness)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = LossReason.InadequateCompetitiveness);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败_TIMEOUT').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.Timeout, group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === LossReason.Timeout)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = LossReason.Timeout);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败无回包_NO_AD').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.NoAdResponse, group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === LossReason.NoAdResponse)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = LossReason.NoAdResponse);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败有回包不合法_INVALID').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.InvalidResponse, group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === LossReason.InvalidResponse)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = LossReason.InvalidResponse);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败_OTHER').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.Other, group: 'hasAdSettingGroup' })
                  .checked(this.setting.hasAdSetting === LossReason.Other)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.hasAdSetting = LossReason.Other);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })
            }
          }
          .width('100%')
          .backgroundColor(0xFFFFFF)
          .borderRadius(10)
          .padding(15)
          .margin({ bottom: 30 })

          Column() {
            Row() {
              Text('请求广告失败时')
            }.width('100%').margin({ bottom: 5 })

            Divider().margin({ top: 5, bottom: 8 })

            Column() {
              Row() {
                Text('不上报').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: '0', group: 'noAdSettingGroup' })
                  .checked(this.setting.noAdSetting === '0')
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.noAdSetting = '0');
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Row() {
                Text('上报竞败').fontColor('#6B6B6B')
                Blank(20)
                Radio({ value: LossReason.Other, group: 'noAdSettingGroup' })
                  .checked(this.setting.noAdSetting === LossReason.Other)
                  .height(24)
                  .width(24)
                  .margin({ left: 'auto' })
                  .onChange((isChecked: boolean) => {
                    isChecked && (this.setting.noAdSetting = LossReason.Other);
                  })
              }
              .width('100%')
              .margin({ bottom: 10 })
            }
          }
          .width('100%')
          .backgroundColor(0xFFFFFF)
          .borderRadius(10)
          .padding(15)
        }
      }
      .padding(20)
    }
    .title('上报腾讯营销联盟竞价结果')
    .backgroundColor('#F1F3F5')
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    }).onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
