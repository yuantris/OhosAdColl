import {
  GDTAdSDK,
  GDTBiddingConstants,
  GDTClientBidding,
} from '@gdt/gdt-union-sdk';
import { LogUtil } from './LogUtil';
import { ToastUtil } from '../utils/ToastUtil';
import { LossReason } from '../pages/BiddingSettingPage';
import { DemoConstants } from '../constants/DemoConstants';
import { rcp } from '@kit.RemoteCommunicationKit';
import { http } from '@kit.NetworkKit';
import { uri } from '@kit.ArkTS';
import { getAppId } from '@gdt/gdt-union-demo/ets/utils/AdUtils';
import { getBiddingSetting } from '../model/BiddingSetting';

interface ServerResponseType {
  token?: string;
}

export class BiddingUtil {
  // C2S 请求广告成功时竞胜/竞败
  public static handleAdLoadSuccess(ad: GDTClientBidding): void {
    LogUtil.info(`getEcpm: ${ad.getEcpm()}`);
    const hasAdSetting = getBiddingSetting().hasAdSetting;
    if (hasAdSetting) {
      const isLoss = Object.values(LossReason).includes(hasAdSetting as LossReason);
      isLoss && ad?.sendLossNotification(new Map([
        [GDTBiddingConstants.WIN_PRICE, '100'],
        [GDTBiddingConstants.LOSS_REASON, '1'],
        [GDTBiddingConstants.ADN_ID, ''],
      ]));
      !isLoss && ad?.sendWinNotification(new Map([
        [GDTBiddingConstants.EXPECT_COST_PRICE, '100'],
        [GDTBiddingConstants.HIGHEST_LOSS_PRICE, '99'],
      ]));
    }
  }

  // C2S 请求广告失败时
  public static handleAdLoadError(posId: string): void {
    const noAdSetting = getBiddingSetting().noAdSetting;
    if (noAdSetting) {
      GDTAdSDK.sendLossNotification(new Map([
        [GDTBiddingConstants.POS_ID, posId],
        [GDTBiddingConstants.WIN_PRICE, '1'],
        [GDTBiddingConstants.LOSS_REASON, '1'],
        [GDTBiddingConstants.ADN_ID, '11'],
        [GDTBiddingConstants.WATERFALL_REQ_ID, '22'],
      ]));
    }
  }

  // 模拟服务端S2S请求，参考文档：https://ylh.qq.com/help_detail.html?cid=4429&pid=10898
  public static async getToken(posId: string, buyerId: string, sdkInfo: string): Promise<string | undefined> {
    LogUtil.info(`buyerId-${buyerId}, sdkInfo-${sdkInfo}`);
    const reqUri = new uri.URI(DemoConstants.SERVER_BIDDING_URL);
    const rcpReq = new rcp.Request(reqUri.toString(), http.RequestMethod.POST);
    rcpReq.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-OpenRTB-Version': '2.5',
    };
    rcpReq.configuration = {
      transfer: {
        timeout: { connectMs: 5000, transferMs: 5000 }
      }
    };
    // 替换SERVER_BIDDING_POST_DATA里的posId, buyerId, sdkInfo
    let jsonString = DemoConstants.SERVER_BIDDING_POST_DATA;
    jsonString = jsonString.replace(/_APPID_/g, getAppId());
    jsonString = jsonString.replace(/_POSID_/g, posId || '');
    jsonString = jsonString.replace(/_BUYERID_/g, buyerId);
    jsonString = jsonString.replace(/_SDKINFO_/g, sdkInfo);
    rcpReq.content = jsonString;

    const session = rcp.createSession();
    try {
      const res = await session.fetch(rcpReq);
      const parsedRes = JSON.parse(res.toString() || '{}') as ServerResponseType;
      LogUtil.info(`S2S TOKEN,${parsedRes}`);
      session.close();
      ToastUtil.showToast(parsedRes.token ? '请求 token 成功' : '回包中无 token');
      return parsedRes.token || undefined;
    } catch (err) {
      LogUtil.error(`onError: ${err.code}, ${err.message}`);
      session.close();
      ToastUtil.showToast('请求 token 失败');
      return undefined;
    }
  }
}
