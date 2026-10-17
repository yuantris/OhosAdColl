import { AdSlot, CSJAdCreator } from '@csj/openadsdk/Index';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 *  Created by xgc on 2024/3/5
 */
export class PrintBiddingTokenUtils {
  //qa要求打印biddingToken测试
  static printBiddingToken(adSlot: AdSlot, adCreator: CSJAdCreator) {
    // let biddingToken = adCreator.getBiddingToken(adSlot, true, 7);
    // if (biddingToken) {
    //   let first = biddingToken.substring(0, biddingToken.length / 2);
    //   let second = biddingToken.substring(biddingToken.length / 2, biddingToken.length);
    //   hilog.info(1, "biddingTokenQA1", first);
    //   hilog.info(1, "biddingTokenQA2", second);
    // } else {
    //   hilog.info(1, "biddingTokenQA3", "error");
    // }
  }
}