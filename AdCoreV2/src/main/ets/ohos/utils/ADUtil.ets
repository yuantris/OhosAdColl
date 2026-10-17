import { util } from "@kit.ArkTS";
import { LogManager } from "../helper/logger/LogManager";
import { BusinessError } from '@kit.BasicServicesKit';

export default class ADUtil{
  static readInfoJsonString(context: Context): string {
    let result = '';
    try {
      let rawFile = context.resourceManager.getRawFileContentSync("info.json");
      let textDecoderOptions: util.TextDecoderOptions = {
        fatal: false,
        ignoreBOM: true
      }
      let decodeToStringOptions: util.DecodeToStringOptions = {
        stream: false
      }
      let textDecoder = util.TextDecoder.create('utf-8', textDecoderOptions);
      result = textDecoder.decodeToString(rawFile, decodeToStringOptions);
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;

      LogManager.error('ADUtil',`getInfoJsonStr failed, error code: ${code}, message: ${message}.`);
    }
    return result;
  }

  /**
   * 毫秒时间戳转 yyyy-MM-dd
   * @param ts 毫秒时间戳 number
   * @returns "2026-07-15"
   */
  static formatTsToDate(ts: number): string {
    const date = new Date(ts);
    const year = date.getFullYear();
    // 月从0开始，+1，不足2位补0
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}