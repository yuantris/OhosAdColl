import { AdStatus } from "../model/AdStatus";

@ObservedV2
export class AdUIData {
  @Trace public adState: AdStatus | undefined = undefined
  @Trace public adEventType: string | undefined = undefined
  @Trace public adEventPayload: string | undefined = undefined
  @Trace public diagnosticInfo: ESObject | null = null
  @Trace public adSlotUpdated: number = 0
  @Trace public adEasySlotUpdated: number = 0
  @Trace public adRefreshTimestamp: number = 0
}
