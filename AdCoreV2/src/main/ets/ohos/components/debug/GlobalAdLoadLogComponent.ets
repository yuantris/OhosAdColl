import { getPlatformName, PlatformType } from '../../model/PlatformType';
import { AdType } from '../../model/AdType';
import { GlobalAdLoadLogStore, GlobalAdLogEntry } from '../../helper/core/GlobalAdLoadLogStore';
import { AdSwitchManager } from '../../helper/core/AdSwitchManager';
import { SDKCore } from '../../application/SDKCore';
import { AdLoadLogComponent } from './AdLoadLogComponent';
import { ADHelper } from '../../helper/core/ADHelper';

const AD_TYPE_LABELS: Map<AdType, string> = new Map([
  [AdType.SPLASH, '开屏广告'],
  [AdType.VIDEO, '激励视频'],
  [AdType.INTERSTITIAL, '插屏广告'],
  [AdType.FEED, '信息流广告'],
  [AdType.BANNER, '横幅广告'],
]);

@ComponentV2
export struct GlobalAdLoadLogComponent {
  @Local refreshKey: number = 0;
  private store: GlobalAdLoadLogStore = GlobalAdLoadLogStore.getInstance();

  aboutToAppear(): void {
    this.refreshKey = Date.now();
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('全局广告加载日志')
          .fontSize(14)
          .fontColor(0xFF69B4)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        this.buildGlobalStatus()

        this.buildLogList()
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    // .constraintSize({ maxHeight: 400 })
    .height('auto')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .borderRadius(12)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
    // .backdropBlur(12)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  @Builder
  buildGlobalStatus() {
    Column({ space: 6 }) {
      Row() {
        Text('广告开关: ')
          .fontSize(11)
          .fontColor(0xA0A0A0)

        Text(AdSwitchManager.isAdOpen ? '开启' : '关闭')
          .fontSize(11)
          .fontColor(AdSwitchManager.isAdOpen ? 0x80FF80 : 0xFF6060)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      if (SDKCore.OFF?.ss) {
        Row() {
          Text('服务器顺序: ')
            .fontSize(11)
            .fontColor(0xA0A0A0)

          Text(`[${this.parseServerSequence(SDKCore.OFF.ss)}]`)
            .fontSize(11)
            .fontColor(0xFFD700)
        }
        .width('100%')
      }

      Row() {
        Text('可用平台: ')
          .fontSize(11)
          .fontColor(0xA0A0A0)

        Text(this.getAvailablePlatformNames())
          .fontSize(11)
          .fontColor(0x80FF80)
      }
      .width('100%')
    }
    .width('100%')
    .padding(8)
    .backgroundColor('rgba(255, 255, 255, 0.05)')
    .borderRadius(6)
    .border({ width: { bottom: 1 }, color: 'rgba(255, 255, 255, 0.1)' })
  }

  @Builder
  buildLogList() {
    Column({ space: 8 }) {
      ForEach(this.getAdTypes(), (adType: AdType) => {
        this.buildAdTypeSection(adType)
      }, (adType: AdType) => `${adType}`)
    }
    .width('100%')
  }

  @Builder
  buildAdTypeSection(adType: AdType) {
    Column({ space: 4 }) {
      Row() {
        Text(AD_TYPE_LABELS.get(adType) ?? '未知类型')
          .fontSize(12)
          .fontColor(0xE0E0E0)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`${this.store.getLogsByType(adType).length} 条记录`)
          .fontSize(10)
          .fontColor(0x707070)
      }
      .width('100%')

      ForEach(this.getSortedLogsByType(adType), (entry: GlobalAdLogEntry, index: number) => {
        Column({ space: 2 }) {
          Row() {
            Text(`#${index + 1}`)
              .fontSize(9)
              .fontColor(0x707070)
              .width(24)

            Text(entry.adSlot)
              .fontSize(10)
              .fontColor(0xE0E0E0)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)

            Text(this.formatTimestamp(entry.timestamp))
              .fontSize(9)
              .fontColor(0xA0A0A0)

            Text(entry.isSuccess ? '✓' : '✗')
              .fontSize(10)
              .fontColor(entry.isSuccess ? 0x80FF80 : 0xFF6060)
              .margin({ left: 4 })
          }
          .width('100%')

          AdLoadLogComponent({
            attemptRecords: entry.attemptRecords,
            totalDuration: entry.totalDuration,
            isSuccess: entry.isSuccess,
            adSlot: entry.adSlot,
            availablePlatforms: entry.availablePlatforms,
            radius: 6
          })
        }
        .width('100%')
      }, (entry: GlobalAdLogEntry) => `${entry.adSlot}_${entry.timestamp}`)
    }
    .width('100%')
    .padding({ bottom: 4 })
    .border({ width: { bottom: 1 }, color: 'rgba(255, 255, 255, 0.08)' })
  }

  private getSortedLogsByType(adType: AdType): GlobalAdLogEntry[] {
    return this.store.getLogsByType(adType)
      .slice()
      .sort((a: GlobalAdLogEntry, b: GlobalAdLogEntry) => b.timestamp - a.timestamp);
  }

  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    const s = date.getSeconds().toString().padStart(2, '0');
    const ms = date.getMilliseconds().toString().padStart(3, '0');
    return `${h}:${m}:${s}.${ms}`;
  }

  private getAdTypes(): AdType[] {
    const types: AdType[] = [AdType.SPLASH, AdType.VIDEO, AdType.INTERSTITIAL, AdType.FEED, AdType.BANNER];
    return types.filter((t: AdType) => this.store.getLogsByType(t).length > 0);
  }

  private getAvailablePlatformNames(): string {
    const platforms = ADHelper.getInstance().getAvailablePlatformTypes();
    if (platforms.length === 0) {
      return '无';
    }
    return platforms.map((p: PlatformType) => getPlatformName(p)).join(', ');
  }

  private parseServerSequence(ss: string): string {
    return ss.split(',')
      .map((s: string) => {
        switch (s.trim()) {
          case '1': return '穿';
          case '2': return '腾';
          case '3': return '快';
          case '4': return '华';
          default: return s.trim();
        }
      })
      .join('');
  }
}
