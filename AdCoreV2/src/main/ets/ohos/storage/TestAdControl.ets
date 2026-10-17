import { PersistenceV2 } from "@kit.ArkUI"

@ObservedV2
export class TestAdControl {
  @Trace debugAD: boolean = true
}

/**
 * 应用运行开发环境仓库存储的全局key
 */
const APP_DEVELOPMENT_KEY = 'zy_app_sdk_test_ad_control_repo_key'

export class TestAdRepo {
  private static _instance: TestAdRepo

  private constructor() {
  }

  public static get instance() {
    if (!TestAdRepo._instance) {
      TestAdRepo._instance = new TestAdRepo()
    }
    return TestAdRepo._instance
  }


  /**
   * 开发者环境持久化仓库代理
   */
  get props(): TestAdControl {
    return PersistenceV2.globalConnect({
      type: TestAdControl,
      key: APP_DEVELOPMENT_KEY,
      defaultCreator: () => new TestAdControl()
    })!;
  }
}