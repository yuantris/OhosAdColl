import { PersistenceV2 } from '@kit.ArkUI';

/**
 * 应用运行开发环境仓库存储的全局key
 */
const APP_DEVELOPMENT_KEY = 'zy_app_sdk_vip_repo_key'

@ObservedV2
export class VipProps {
  @Trace ltime: string = ''
  @Trace ps: string = ''
  @Trace _vip: number = 0

  get vip(): boolean {
    return this._vip === 1
  }

  updateVip(vip: boolean){
    this._vip = vip ? 1 : 0
  }
}


export class VIPRepo {
  private static _instance: VIPRepo

  public static get instance() {
    if (!VIPRepo._instance) {
      VIPRepo._instance = new VIPRepo()
    }
    return VIPRepo._instance
  }


  /**
   * 开发者环境持久化仓库代理
   */
  get props(): VipProps {
    return PersistenceV2.globalConnect({
      type: VipProps,
      key: APP_DEVELOPMENT_KEY,
      defaultCreator: () => new VipProps()
    })!;
  }
}