import { identifier } from '@kit.AdsKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AD } from '../../../../../Index';

export function requestOAIDTrackingConsentPermissions(context: common.Context): void {
  // 进入页面时，向用户请求授权广告跨应用关联访问权限
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  try {
    atManager.requestPermissionsFromUser(context, ["ohos.permission.APP_TRACKING_CONSENT"]).then((data) => {
      if (data.authResults[0] === 0) {
        hilog.info(0x0000, 'testTag', '%{public}s', 'succeeded in requesting permission');
        identifier.getOAID((err: BusinessError, data: string) => {
          if (err.code) {
            hilog.error(0x0000, 'testTag', '%{public}s', `get oaid failed, error: ${err.code} ${err.message}`);
          } else {
            const oaid: string = data;
            AD.OAID = oaid;
            hilog.info(0x0000, 'testTag', '%{public}s', `succeeded in getting oaid by callback , oaid: ${oaid}`);
          }
        });
      } else {
        hilog.error(0x0000, 'testTag', '%{public}s', 'user rejected');
      }
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', '%{public}s', `request permission failed, error: ${err.code} ${err.message}`);
    })
  } catch (err) {
    hilog.error(0x0000, 'testTag', '%{public}s', `catch err->${err.code}, ${err.message}`);
  }
}