import { Any } from '@zycore/common';
import { LogManager } from '../helper/logger/LogManager';

export class SafeValueUtil {
  static getSafeValue(value: Any, defaultValue: string = ''): string {
    try {
      return value as string ?? defaultValue
    } catch {
      return defaultValue
    }
  }
}

export namespace safe {
  /**
   * 安全解析json字符串，失败返回空对象
   * @param str 原始json字符串
   * @returns Record<string, string>
   */
  export function parseJson(str?: string): Record<string, string> {
    try {
      return JSON.parse(JSON.stringify(str)) as Record<string, string>;
    } catch (err) {
      // 解析异常，返回空对象避免业务报错
      LogManager.error('SafeValueUtil', `json解析失败: ${str}`, err);
      return {};
    }
  }
}
