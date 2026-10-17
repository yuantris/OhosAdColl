export interface ZYAdvertisement {
  adType: number // 广告类型
  rewardVerifyConfig: Map<string, string> // 服务器验证参数
  uniqueId: string // 广告唯一ID
  rewarded: boolean // 订阅者已经获取奖励
  shown: boolean // 订阅者已经展示
  clicked: boolean // 订阅者已经点击

  // 广告的扩展属性
  [key: string]: Object
}