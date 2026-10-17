import Emitter from '@ohos.events.emitter';
import { EmitterUtils } from '@zycore/common';

export class SplashMonitor {

  // 定义业务状态标识常量
  static readonly ONPAGESHOW = "onPageShow_zy_father_splash";
  static readonly ONPAGEHIDE = "onPageHide_zy_father_splash";


  /**
   * 在组件的`aboutToAppear`生命周期钩子中调用，监听父组件事件
   * @param callback 事件回调函数，接受一个`EmitterData`对象作为参数
   */
  static onPageShow() {
    EmitterUtils.post<string>(SplashMonitor.ONPAGESHOW, "onPageShow")
  }

  static onPageHide(){
    EmitterUtils.post<string>(SplashMonitor.ONPAGEHIDE, "onPageHide")
  }

}
