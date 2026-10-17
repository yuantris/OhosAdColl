import { ButtonItem } from './ButtonItem';
import { SDKInitHelper } from '../utils/SDKInitHelper';

@Builder
export function HomeScreen(pathStack: NavPathStack) {
  ButtonItem({ title: '启动 SDK' })
    .onClick(() => {
      SDKInitHelper.startSDK();
    })
  Blank(10)
  ButtonItem({ title: '激励广告' })
    .onClick(() => {
      pathStack.pushPath({ name: 'RewardPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: '开屏广告' })
    .onClick(() => {
      pathStack.pushPath({ name: 'SplashPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: '插屏广告' })
    .onClick(() => {
      pathStack.pushPath({ name: 'InterstitialPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: 'Banner广告' })
    .onClick(() => {
      pathStack.pushPath({ name: 'BannerPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: '原生广告（腾讯营销联盟渲染）' })
    .onClick(() => {
      pathStack.pushPath({ name: 'NativeAdEntryPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: '原生广告（开发者自渲染）' })
    .onClick(() => {
      pathStack.pushPath({ name: 'NativeManualAdEntryPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(10)
  ButtonItem({ title: '上报腾讯营销联盟竞价结果' })
    .onClick(() => {
      pathStack.pushPath({ name: 'BiddingSettingPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
  Blank(20)
  Text('设置')
    .fontSize(12)
    .fontColor('#999999')
    .onClick(() => {
      pathStack.pushPath({ name: 'SettingsPage' }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON });
    })
}

export function homeScreenName(): string {
  return '腾讯营销联盟：结盟而赢';
}

@Builder
export function homePageMap(name: string, param: Object) {
}

// do nothing
export function onTripleTap(_pathStack: NavPathStack): void {
}
