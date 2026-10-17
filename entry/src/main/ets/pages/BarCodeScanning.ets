import { router } from '@kit.ArkUI'
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { scanCore } from '@kit.ScanKit';
import { scanBarcode } from '@kit.ScanKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import View from '../common/View'
import Util from '../common/util/Util';
import { getBarCode } from '../service/default';
import { Log } from '@zycore/common';

@Entry
@Component
struct BarCodeScanning {
  @State code:string = ''
  @State pageNum:number=1
  @State pageSize:number = 30
  aboutToAppear(): void {
  this.get_code()
  }
  get_code(){
    let options: scanBarcode.ScanOptions = { scanTypes: [scanCore.ScanType.ONE_D_CODE], enableMultiMode: false, enableAlbum: true };
    try {
      scanBarcode.startScanForResult(getContext(this), options).then((result: scanBarcode.ScanResult) => {
        this.code = result.originalValue
        console.log('result', result.originalValue)
        // hilog.info(0x0001, '[Scan Sample]',
        //   `Succeeded in getting ScanResult by promise with options, result is ${JSON.stringify(result)}`);
        getBarCode({
          code:this.code,
          pageNum:this.pageNum,
          pageSize:this.pageSize
        }).then((res)=>{
          Log.debug('kkkkkkkkkkkkkkk',JSON.parse(JSON.stringify(res)))
          console.log(res?.pageSize+'')
        })
      }).catch((error: BusinessError) => {
        hilog.error(0x0001, '[Scan Sample]',
          `Failed to get ScanResult by promise with options. Code: ${error.code}, message: ${error.message}`);
      });
    } catch (error) {
      hilog.error(0x0001, '[Scan Sample]', `Failed to startScanForResult. Code: ${error.code}, message: ${error.message}`);
    }
  }


  permissions: Array<Permissions> = ['ohos.permission.CAMERA'];

  async checkPermissionGrant(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to get bundle info for self. Code is ${err.code}, message is ${err.message}`);
    }

    // 校验应用是否被授予权限
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, permission);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to check access token. Code is ${err.code}, message is ${err.message}`);
    }

    return grantStatus;
  }

  async checkPermissions(): Promise<void> {
    let grantStatus: abilityAccessCtrl.GrantStatus = await this.checkPermissionGrant(this.permissions[0]);

    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      // 已经授权，可以继续访问目标操作
      Util.toast('granted')
    } else {
      Util.toast('no granted')
    }
    router.replaceUrl({ url: 'pages/BarCodeResult' })
  }

  build() {
    Column() {
      Image($r('app.media.im_back'))
        .width('56vp')
        .height('56vp')
        .offset({ top: View.statusBarHeight })
        .padding({
          left: View.SPACE,
          top: View.SPACE,
          right: View.SPACE,
          bottom: View.SPACE
        })
        .objectFit(ImageFit.Contain)
        .onClick(() => router.back())

      Button('获取相机权限')
        .onClick(() => this.checkPermissions())

    }
    .height('100%')
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}