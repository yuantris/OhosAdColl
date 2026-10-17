import { i18n } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AD } from '../config/AD';
import { ArrayList, HashMap, HashSet, List, util } from '@kit.ArkTS';
import { Log, MD5, ObjectGT } from '@zycore/common';
import { BusinessError } from '@kit.BasicServicesKit';

export type CommonSingleType = Object | String | Number | Boolean | null | undefined; //通用单个联合类型

export type CommonAllType = CommonSingleType | Array<CommonSingleType> | ArrayList<CommonSingleType>
  | HashMap<CommonSingleType, CommonSingleType> | HashSet<CommonSingleType>; //通用所有联合类型

// 定义函数类型
type Runnable = () => void;

export function tryCatch(execute: Runnable, finallyExecute: Runnable): void {
  try {
    execute();
  } catch (e) {
    console.error(e);
  } finally {
    finallyExecute();
  }
}

export function logD(msg: string, tag: string = "zy_yuan") {
  hilog.info(0x0000, tag, msg);
}

export function logE(msg: string, tag: string = "zy_yuan") {
  hilog.error(0x0000, tag, msg);
}

export function getItoken(ids: Array<string> | []): string {
  let result = '';
  if (ids.length > 0) {
    const concatenated = ids.filter((it: string) => it.length > 6).join('');
    const charArray = concatenated.split('');
    charArray.sort();
    result = charArray.join('');
  }
  return md5ItokenStr(result, 6);
}

function md5ItokenStr(str: string, size: number): string {
  const md5 = MD5.digestSync(str);
  let adjustedSize = size;
  if (size % 2 !== 0) {
    adjustedSize = size - 1;
  } else if (size > 31 || size < 6) {
    adjustedSize = 32;
  }
  const start = 16 - Math.floor(adjustedSize / 2);
  const end = 16 + Math.floor(adjustedSize / 2);
  return md5.substring(start, end);
}

export function md5ItokenBlank(size: number): string {
  // 空字符串标准MD5值
  const md5 = 'd41d8cd98f00b204e9800998ecf8427e';
  let adjustedSize = size;
  if (size % 2 !== 0) {
    adjustedSize = size - 1;
  } else if (size > 31 || size < 6) {
    adjustedSize = 32;
  }
  const start = 16 - Math.floor(adjustedSize / 2);
  const end = 16 + Math.floor(adjustedSize / 2);
  return md5.substring(start, end);
}

export default class ADUtil {
  static readonly TAG = 'zyAdCore_'

  public static logD(tag: string, msg: string, allShow?: boolean, ...args: object[]) {
    if (allShow || AD.isDEBUG()) {
      hilog.debug(hilog.LogLevel.DEBUG, ADUtil.TAG + tag, msg, args)
    }
  }

  public static logE(tag: string, msg: string | number, allShow?: boolean, ...args: object[]) {
    if (allShow || AD.isDEBUG()) {
      hilog.error(hilog.LogLevel.DEBUG, ADUtil.TAG + tag, String(msg), args)
    }
  }

  public static logI(tag: string, msg: string, allShow?: boolean, ...args: object[]) {
    if (allShow || AD.isDEBUG()) {
      hilog.info(hilog.LogLevel.DEBUG, ADUtil.TAG + tag, msg, args)
    }
  }

  public static logW(tag: string, msg: string, allShow?: boolean, ...args: object[]) {
    if (allShow || AD.isDEBUG()) {
      hilog.warn(hilog.LogLevel.DEBUG, ADUtil.TAG + tag, msg, args)
    }
  }

  public static logF(tag: string, msg: string, allShow?: boolean, ...args: object[]) {
    if (allShow || AD.isDEBUG()) {
      hilog.fatal(hilog.LogLevel.DEBUG, ADUtil.TAG + tag, msg, args)
    }
  }

  /**
   * 判断对象是否为空
   * @param source
   * @returns
   */
  static isNull(source: Object) {
    return source === null || source === undefined;
  }

  /**
   * 判断属性内容是否为空
   * @param property
   * @returns
   */
  static isEmpty(property: CommonAllType): boolean {
    if (ObjectGT.isNull(property)) {
      return true
    } else if (Array.isArray(property) || property instanceof Array) {
      return property.length == 0
    } else if (property instanceof List) {
      return property.isEmpty()
    } else if (property instanceof ArrayList) {
      return property.isEmpty()
    } else if (property instanceof HashMap) {
      return property.isEmpty()
    }
    return property == '';
  }

  public static isNotEmpty(property: CommonAllType): boolean {
    return !ADUtil.isEmpty(property)
  }

  /**
   * 判断字符串是否为空和空白符(空白符包括空格、制表符、全角空格和不间断空格)。true为空，否则false
   * @param str
   * @returns
   */
  public static isBlank(str: string | undefined | null): boolean {
    let length: number = 0;
    if ((str == undefined) || (str == null) || ((length = str.length) == 0)) {
      return true;
    }
    for (let i = 0; i < length; i++) {
      if (false == CharUtil.isBlankChar(str.charCodeAt(i))) {
        return false; //只要有一个非空字符即为非空字符串
      }
    }
    return true;
  }

  /**
   * 判断字符串是否为非空和空白符(空白符包括空格、制表符、全角空格和不间断空格)true为非空，否则false
   * @param str
   * @returns
   */
  public static isNotBlank(str: string | undefined | null): boolean {
    return false == ADUtil.isBlank(str)
  }

  public static getRandomInt(min: number, max: number): number {
    // 参数验证
    if (min > max) {
      throw new Error("min must be less than or equal to max");
    }
    // 使用 Number.MAX_SAFE_INTEGER 避免溢出
    const range = Math.min(max - min, Number.MAX_SAFE_INTEGER);
    // 生成随机数
    return Math.floor(Math.random() * (range + 1)) + min;
  }

  static readInfoJsonFromRawFile(context: Context): string {
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
      Log.error(`getRawFileContentSync failed, error code: ${code}, message: ${message}.`);
    }
    return result;
  }
}

class CharUtil {
  /**
   * 判断字符串char是否是数字
   * @param char
   * @returns
   */
  static isDigit(char: string): boolean {
    return i18n.Unicode.isDigit(char);
  }

  /**
   * 判断字符串char是否是字母
   * @param char
   * @returns
   */
  static isLetter(char: string): boolean {
    return i18n.Unicode.isLetter(char);
  }

  /**
   * 判断字符串char是否是小写字母
   * @param char
   * @returns
   */
  static isLowerCase(char: string): boolean {
    return i18n.Unicode.isLowerCase(char);
  }

  /**
   * 判断字符串char是否是大写字母
   * @param char
   * @returns
   */
  static isUpperCase(char: string): boolean {
    return i18n.Unicode.isUpperCase(char);
  }

  /**
   * 判断字符串char是否是空格符
   * @param char
   * @returns
   */
  static isSpaceChar(char: string): boolean {
    return i18n.Unicode.isSpaceChar(char);
  }

  /**
   * 判断字符串char是否是空白符
   * @param char
   * @returns
   */
  static isWhitespace(char: string): boolean {
    return i18n.Unicode.isWhitespace(char);
  }

  /**
   * 判断字符串char是否是从右到左语言的字符
   * @param char
   * @returns
   */
  static isRTL(char: string): boolean {
    return i18n.Unicode.isRTL(char);
  }

  /**
   * 判断字符串char是否是表意文字
   * @param char
   * @returns
   */
  static isIdeograph(char: string): boolean {
    return i18n.Unicode.isIdeograph(char);
  }

  /**
   * 判断是否空白符 空白符包括空格、制表符、全角空格和不间断空格
   * @param c
   * @returns
   */
  static isBlankChar(c: number): boolean {
    return CharUtil.isWhitespace(c.toString())
      || CharUtil.isSpaceChar(c.toString())
      || c == 0xFEFF || c == 0x202A || c == 0x0000;
  }

  /**
   * 判断字符是否位于ASCII范围内（其中0-31是控制字符，32-127表示从A到Z的字母字符）
   * @param char 字符
   * @returns
   */
  static isAscii(char: string): boolean {
    if (char.length == 1) { //确保输入的是单个字符
      return char.charCodeAt(0) < 128;
    } else {
      return false;
    }
  }
}