import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export class DemoConstants {
  public static windowStage: window.WindowStage;
  public static uiAbilityContext: common.UIAbilityContext;
  public static readonly SERVER_BIDDING_URL = 'https://mi.gdt.qq.com/server_bidding';
  public static readonly SERVER_BIDDING_POST_DATA = '{"id":"0ffaa9f932e248839e69482593f3c692","imp":[{"id":"6082091648d742a2afd0113f70eeab5e","tagid":"_POSID_","bidfloor":1,"bidfloorcur":"CNY","video":{"h":606,"w":1080},"ad_count":1}],"app":{"id":"_APPID_","bundle":"com.qq.e.union.demo","name":""},"device":{"ua":"Mozilla/5.0 (Phone; OpenHarmony 5.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36  ArkWeb/4.1.6.1 Mobile","ip":"218.86.120.226","ipv6":"","h":1080,"w":2400,"connectiontype":2,"geo":{"lat":-7.2484,"lon":112.7419},"make":"HUAWEI","model":"ALN-AL80","os":"Harmony","osv":"OpenHarmony-5.0.1.73(Beta2)","devicetype":4,"language":"zh","ext":{"oaid":"BE8FF29C-2F3D-4014-808D-2CE02BB2775A","time_zone":"Asia/Shanghai"}},"cur":["CNY"],"ext":{"buyer_id":"_BUYERID_","support_h265":true,"sdk_info":"_SDKINFO_"}}';
  /** Preferences 存储名称 */
  public static readonly PREF_NAME: string = 'gdt_demo_settings';
  /** 音频并发混音模式 Key */
  public static readonly KEY_AUDIO_CONCURRENCY: string = 'audio_concurrency_mix';
}
