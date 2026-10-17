import * as pako from 'pako';
import { util } from '@kit.ArkTS';

// 创建Base64解码器
const base64Helper: util.Base64Helper = new util.Base64Helper();
const textEncoder = util.TextEncoder.create('UTF-8')
const textDecoder = util.TextDecoder.create('UTF-8')

function stringToUint8Array(str: string): Uint8Array {
  return textEncoder.encodeInto(str)
}

function uint8ArrayToString(uint8Array: Uint8Array): string {
  return textDecoder.decodeToString(uint8Array)
}

/**
 * Gzip压缩解压工具类
 * 修复了pako.ungzip返回类型与TextDecoder参数类型不匹配的问题
 */
export class GzipUtils {
  private static readonly DEFAULT_ENCODING: string = 'utf-8';

  /**
   * 解压Base64编码的gzip数据
   * @param base64Data - Base64编码的压缩数据
   * @returns 解压后的字符串
   * @throws 解压失败时抛出错误
   */
  static ungzipFromBase64(base64Data: string): string {
    if (!base64Data || base64Data.trim() === '') {
      throw new Error('输入数据不能为空');
    }

    try {
      // 解码Base64数据
      const binaryUint8Array: Uint8Array = base64Helper.decodeSync(base64Data,util.Type.BASIC_URL_SAFE);

      // 解压数据 - 显式指定返回类型为Uint8Array
      const decompressed: Uint8Array | string = pako.ungzip(binaryUint8Array);

      // 确保返回的是Uint8Array类型
      if (typeof decompressed === 'string') {
        throw new Error('解压结果格式错误：期望Uint8Array但获得字符串');
      }

      if (!decompressed || decompressed.length === 0) {
        throw new Error('解压结果为空');
      }

      // 转换为字符串并返回
      return uint8ArrayToString(decompressed as Uint8Array);
    } catch (error) {
      throw new Error(`解压失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 解压Uint8Array格式的gzip数据
   * @param compressedData - 压缩的二进制数据
   * @returns 解压后的Uint8Array
   * @throws 解压失败时抛出错误
   */
  static ungzip(compressedData: Uint8Array): Uint8Array {
    if (!compressedData || compressedData.length === 0) {
      throw new Error('输入数据不能为空');
    }

    try {
      const result: Uint8Array | string = pako.ungzip(compressedData);

      // 确保返回的是Uint8Array类型
      if (typeof result === 'string') {
        throw new Error('解压结果格式错误：期望Uint8Array但获得字符串');
      }

      if (!result || result.length === 0) {
        throw new Error('解压结果为空');
      }

      return result as Uint8Array;
    } catch (error) {
      throw new Error(`解压失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 解压并转换为指定编码的字符串
   * @param compressedData - 压缩的二进制数据
   * @param encoding - 字符编码，默认为utf-8
   * @returns 解压后的字符串
   * @throws 解压失败时抛出错误
   */
  static ungzipToString(compressedData: Uint8Array, encoding: string = this.DEFAULT_ENCODING): string {
    if (!compressedData || compressedData.length === 0) {
      throw new Error('输入数据不能为空');
    }

    try {
      const decompressed: Uint8Array = this.ungzip(compressedData);
      const textDecoder: util.TextDecoder = new util.TextDecoder(encoding);
      return textDecoder.decode(decompressed);
    } catch (error) {
      throw new Error(`解压转换失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 压缩字符串为Base64格式的gzip数据
   * @param data - 要压缩的字符串
   * @returns Base64编码的压缩数据
   * @throws 压缩失败时抛出错误
   */
  static gzipToBase64(data: string): string {
    if (!data || data.trim() === '') {
      throw new Error('输入数据不能为空');
    }

    try {
      // 将字符串编码为Uint8Array
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const bytes: Uint8Array = textEncoder.encode(data);

      // 压缩数据
      const compressed: Uint8Array = pako.gzip(bytes);

      // 创建Base64编码器
      const base64Helper: util.Base64Helper = new util.Base64Helper();
      return base64Helper.encodeToStringSync(compressed);
    } catch (error) {
      throw new Error(`压缩失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 压缩Uint8Array数据为gzip格式
   * @param data - 要压缩的二进制数据
   * @returns 压缩后的Uint8Array
   * @throws 压缩失败时抛出错误
   */
  static gzip(data: Uint8Array): Uint8Array {
    if (!data || data.length === 0) {
      throw new Error('输入数据不能为空');
    }

    try {
      const result: Uint8Array = pako.gzip(data);

      if (!result || result.length === 0) {
        throw new Error('压缩结果为空');
      }

      return result;
    } catch (error) {
      throw new Error(`压缩失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }
}