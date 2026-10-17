import { identifier } from '@kit.AdsKit';
import { abilityAccessCtrl, common, PermissionRequestResult } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { OAIDStore } from '../helper/core/OAIDStore';
import { LogManager } from '../helper/logger/LogManager';

const TAG = 'OAIDUtil';

/**
 * 向用户请求授权广告跨应用关联访问权限
 * @param context 上下文
 */
export function requestOAIDTrackingConsentPermissions(context: common.Context): void {
  // 进入页面时，向用户请求授权广告跨应用关联访问权限
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  try {
    atManager.requestPermissionsFromUser(context, ["ohos.permission.APP_TRACKING_CONSENT"]).then((data) => {
      if (data.authResults[0] === 0) {
        LogManager.debug(TAG, 'succeeded in requesting permission');
        identifier.getOAID((err: BusinessError, data: string) => {
          if (err.code) {
            LogManager.error(TAG, `get oaid failed, error: ${err.code} ${err.message}`, err);
          } else {
            const oaid: string = data;
            OAIDStore.OAID = oaid;
            LogManager.info(TAG, `succeeded in getting oaid by callback, oaid: ${oaid}`);
          }
        });
      } else {
        LogManager.error(TAG, 'user rejected');
      }
    }).catch((err: BusinessError) => {
      LogManager.error(TAG, `request permission failed, error: ${err.code} ${err.message}`, err);
    })
  } catch (err) {
    LogManager.error(TAG, `catch err, code: ${err.code}, message: ${err.message}`, err);
  }
}

/**
 * 向用户请求授权广告跨应用关联访问权限
 * @param context 上下文
 */
export async function requestOAID(context: Context): Promise<string | undefined> {
  // 向用户请求授权广告跨应用关联访问权限
  let isPermissionGranted: boolean = false;
  try {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result: PermissionRequestResult =
      await atManager.requestPermissionsFromUser(context, ['ohos.permission.APP_TRACKING_CONSENT']);
    isPermissionGranted = result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  } catch (err) {
    LogManager.error(TAG, `failed to request permission, code: ${err.code}, message: ${err.message}`, err);
  }
  if (isPermissionGranted) {
    LogManager.debug(TAG, 'succeeded in requesting permission');
    try {
      const oaid = await identifier.getOAID();
      OAIDStore.OAID = oaid;
      LogManager.info(TAG, `succeeded in getting OAID: ${oaid}`);
      return oaid;
    } catch (err) {
      LogManager.error(TAG, `failed to get OAID, code: ${err.code}, message: ${err.message}`, err);
    }
  } else {
    LogManager.error(TAG, 'failed to request permission, user rejected');
  }
  return undefined;
}
