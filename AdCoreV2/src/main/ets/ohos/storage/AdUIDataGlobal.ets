import { AdUIData } from './AdUIData';
import { AppStorageV2 } from '@kit.ArkUI';

export class AdUIDataGlobal {
  private static readonly AD_UI_DATA_KEY = 'ad_ui_data';

  static set adSlotUpdated(value: number) {
    const data = AppStorageV2.connect(AdUIData, AdUIDataGlobal.AD_UI_DATA_KEY, () => new AdUIData());
    if (data) {
      data.adSlotUpdated = value;
    }
  }

  static set adEasySlotUpdated(value: number) {
    const data = AppStorageV2.connect(AdUIData, AdUIDataGlobal.AD_UI_DATA_KEY, () => new AdUIData());
    if (data) {
      data.adEasySlotUpdated = value;
    }
  }

  static set adRefreshTimestamp(value: number) {
    const data = AppStorageV2.connect(AdUIData, AdUIDataGlobal.AD_UI_DATA_KEY, () => new AdUIData());
    if (data) {
      data.adRefreshTimestamp = value;
    }
  }

  static set adEventType(value: string | undefined) {
    const data = AppStorageV2.connect(AdUIData, AdUIDataGlobal.AD_UI_DATA_KEY, () => new AdUIData());
    if (data) {
      data.adEventType = value;
    }
  }

  static set adEventPayload(value: string | undefined) {
    const data = AppStorageV2.connect(AdUIData, AdUIDataGlobal.AD_UI_DATA_KEY, () => new AdUIData());
    if (data) {
      data.adEventPayload = value;
    }
  }
}
