import { AdSlot, AdSlotBuilder, AdSlotType, CSJAdSdk } from '@csj/openadsdk'
import { List } from '@kit.ArkTS'

/**
 * 聚合功能使用示例
 * 如服务端激励验证处理逻辑示例、首次预缓存功能等
 */
export class AdUtils {

  /**
   * 首次预缓存功能，使用注意
   * 1、使用该接口时，创建AdSlot时codeId和adType是必传的，否则广告位无效。
   * 2、该接口传入的AdSlot要与后续发起请求的AdSlot参数设置完全一致，否则会导致无法命中预缓存。
   * 3、初始化后，开发者仅能调用一次该接口，多次调用不生效。
   * 4、调用该接口的最早时机：SDK初始化完成后；该时机与开屏广告加载的时机非常近，因此不建议开屏广告用该接口提前加载。
   */
  preload() {
    // 第一步：准备需要预缓存的AdSlot list
    let adSlotList: List<AdSlot> = new List()
    let adSlot1 = new AdSlotBuilder()
      .setCodeId("102922441") // 预缓存必传！
      .setAdType(AdSlotType.TYPE_REWARD_VIDEO) // 预缓存必传！
      .build()

    let adSlot2 = new AdSlotBuilder()
      .setCodeId("103056846")
      .setAdType(AdSlotType.TYPE_REWARD_VIDEO) // 激励类型广告位
      .setRewardName("金币")
      .setRewardAmount(1)
      .build()

    let adSlot3 = new AdSlotBuilder()
      .setCodeId("103086407")
      .setAdType(AdSlotType.TYPE_FULL_SCREEN_VIDEO) // 插屏类型广告位
      .build()

    adSlotList.add(adSlot1)
    adSlotList.add(adSlot2)
    adSlotList.add(adSlot3)

    // 第二步：设置并行加载的数量和时间间隔
    let parallelNum = 2
    let requestIntervalS = 2

    // 第三步：发起预请求
    CSJAdSdk.getMediationManager().preload(adSlotList, parallelNum, requestIntervalS)
  }
}