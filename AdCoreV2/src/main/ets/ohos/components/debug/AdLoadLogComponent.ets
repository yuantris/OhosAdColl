import { getPlatformName, PlatformType, SERVER_SEQUENCE_MAP } from '../../model/PlatformType'
import { AdAttemptRecord, AdAttemptResult, RetryType } from '../../model/AdAttemptRecord'
import { SDKCore } from '../../application/SDKCore'
import { AdSwitchManager } from '../../helper/core/AdSwitchManager'

@ComponentV2
export struct AdLoadLogComponent {
  @Param attemptRecords: AdAttemptRecord[] = []
  @Param totalDuration: number = 0
  @Param isSuccess: boolean = false
  @Param radius: Length = 8
  @Param availablePlatforms: PlatformType[] = []
  @Param adSlot: string = ''

  @Computed
  get hasBasicInfo() {
    const hasBasicInfo = this.adSlot || this.availablePlatforms.length > 0 || SDKCore.OFF?.ss;
    return hasBasicInfo
  }

  @Computed
  get hasAttemptRecords() {
    const hasAttemptRecords = this.attemptRecords.length > 0;
    return hasAttemptRecords
  }

  @Computed
  get isAdSwitchOff() {
    const isAdSwitchOff = !AdSwitchManager.isAdOpen;
    return isAdSwitchOff
  }

  build() {
    if (this.hasBasicInfo || this.hasAttemptRecords || this.isAdSwitchOff) {
      Scroll() {
        Column({ space: 8 }) {
          Text('加载日志')
            .fontSize(12)
            .fontColor(0xFF69B4)
            .fontWeight(FontWeight.Bold)
            .width('100%')

          if (this.isAdSwitchOff) {
            Row() {
              Text('⚠ 广告全局开关已关闭')
                .fontSize(10)
                .fontColor(0xFF6060)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .padding(4)
            .backgroundColor('rgba(255, 96, 96, 0.2)')
            .borderRadius(4)
          }

          if (this.hasBasicInfo) {
            this.buildBasicInfo()
          }

          if (this.hasAttemptRecords) {
            Column({ space: 4 }) {
              ForEach(this.attemptRecords, (record: AdAttemptRecord, index: number) => {
                this.buildAttemptItem(record, index)
              }, (record: AdAttemptRecord, index: number) => `${index}_${record.platformType}_${record.result}`)
            }
            .width('100%')

            Row() {
              Text(`总耗时: ${this.totalDuration}ms`)
                .fontSize(10)
                .fontColor(0x909090)

              Blank()

              Text(this.isSuccess ? '✓ 成功' : '✗ 失败')
                .fontSize(10)
                .fontColor(this.isSuccess ? 0x80FF80 : 0xFF6060)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .padding({ top: 4 })
          }
        }
        .width('100%')
        .padding(8)
      }
      .width('100%')
      .constraintSize({ maxHeight: 300 })
      .scrollBar(BarState.Auto)
      .scrollBarColor('rgba(245, 245, 245, 0.6)')
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor('rgba(0, 0, 0, 0.6)')
      .borderRadius(this.radius)
      .backdropBlur(12)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })
    }
  }

  @Builder
  buildBasicInfo() {
    Column({ space: 2 }) {
      if (this.adSlot) {
        Row() {
          Text('广告位: ')
            .fontSize(9)
            .fontColor(0xA0A0A0)

          Text(this.adSlot)
            .fontSize(9)
            .fontColor(0xE0E0E0)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
      }

      if (this.availablePlatforms.length > 0) {
        Row() {
          Text('可用平台: ')
            .fontSize(9)
            .fontColor(0xA0A0A0)

          Text(this.availablePlatforms.map((p: PlatformType) => getPlatformName(p)).join(', '))
            .fontSize(9)
            .fontColor(0x80FF80)
        }
        .width('100%')
      }

      if (SDKCore.OFF?.ss) {
        Row() {
          Text('服务器顺序: ')
            .fontSize(9)
            .fontColor(0xA0A0A0)

          Text(`[${this.parseServerSequence(SDKCore.OFF.ss)}]`)
            .fontSize(9)
            .fontColor(0xFFD700)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ bottom: 4 })
    .border({ width: { bottom: 1 }, color: 'rgba(255, 255, 255, 0.1)' })
  }

  private parseServerSequence(ss: string): string {
    return ss.split(',')
      .map((s: string) => SERVER_SEQUENCE_MAP.get(s.trim()) ?? s)
      .join('');
  }

  @Builder
  buildAttemptItem(record: AdAttemptRecord, index: number) {
    Column({ space: 2 }) {
      Row() {
        Text(`#${record.attemptIndex}`)
          .fontSize(10)
          .fontColor(0x808080)
          .width(24)

        Text(getPlatformName(record.platformType))
          .fontSize(11)
          .fontColor(0xE0E0E0)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)

        Text(this.getResultText(record.result))
          .fontSize(10)
          .fontColor(this.getResultColor(record.result))
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      if (record.adId) {
        Row() {
          Text('')
            .width(24)

          Text(`ID: ${record.adId}`)
            .fontSize(9)
            .fontColor(0x80FF80)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 1 })
      }

      if (record.result === AdAttemptResult.FAILED && record.errorMessage) {
        Row() {
          Text('')
            .width(24)

          Text(`${record.errorMessage}`)
            .fontSize(9)
            .fontColor(0xFF8080)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 1 })
      }

      if (record.retryType !== RetryType.NONE) {
        Row() {
          Text('')
            .width(24)

          Text(this.getRetryTypeText(record.retryType))
            .fontSize(9)
            .fontColor(this.getRetryTypeColor(record.retryType))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding({ top: 1 })
      }

      Row() {
        Text('')
          .width(24)

        Text(`${record.duration}ms`)
          .fontSize(9)
          .fontColor(0x707070)
      }
      .width('100%')

      if (index < this.attemptRecords.length - 1) {
        Row() {
          Text('')
            .width(24)

          Text('↓')
            .fontSize(12)
            .fontColor('#f5f5f5')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
  }

  private getResultText(result: AdAttemptResult): string {
    switch (result) {
      case AdAttemptResult.SUCCESS:
        return '成功'
      case AdAttemptResult.FAILED:
        return '失败'
      case AdAttemptResult.SKIPPED:
        return '跳过'
      default:
        return '未知'
    }
  }

  private getResultColor(result: AdAttemptResult): ResourceColor {
    switch (result) {
      case AdAttemptResult.SUCCESS:
        return 0x80FF80
      case AdAttemptResult.FAILED:
        return 0xFF6060
      case AdAttemptResult.SKIPPED:
        return 0xFFAA00
      default:
        return 0x909090
    }
  }

  private getRetryTypeText(retryType: RetryType): string {
    switch (retryType) {
      case RetryType.SELF_RETRY:
        return '⟳ 自身重试'
      case RetryType.CHANNEL_RETRY:
        return '→ 渠道间降级'
      default:
        return ''
    }
  }

  private getRetryTypeColor(retryType: RetryType): ResourceColor {
    switch (retryType) {
      case RetryType.SELF_RETRY:
        return 0xFFC800
      case RetryType.CHANNEL_RETRY:
        return 0x00BFFF
      default:
        return 0x909090
    }
  }
}
