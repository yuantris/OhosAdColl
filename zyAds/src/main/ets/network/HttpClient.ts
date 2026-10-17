import { rcp } from "@kit.RemoteCommunicationKit";
import { GzipUtils } from "../util/GzipUtil";
import pako from 'pako';
import Http from "./Http";

// HttpClient.ts
export class HttpClient {
  private static instance: HttpClient;
  private session = Http.getInstance();

  private constructor() {}

  public static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  // 重载声明
  get(url: string): Promise<string>;
  get<T>(url: string): Promise<T>;
  async get<T>(url: string): Promise<T | string> {
    try {
      const resp = await this.session.get(url);
      const respText = resp.toString();
      if (!respText) {
        return undefined as unknown as T;
      }
      try {
        return JSON.parse(respText) as T;
      } catch (parseError) {
        return GzipUtils.ungzipFromBase64(respText); // 自动推断为 string
      }
    } catch (error) {
      throw new Error(`HTTP GET 请求失败: ${error}`);
    }
  }

  async post(url: string, body: any, returnType?: 'json' | 'text'): Promise<any> {
    try {
      const content: rcp.RequestContent = { fields: body };
      const resp = await this.session.post(url, content);
      const respText = resp.toString();

      if (!respText) {
        return Promise.resolve(returnType === 'text' ? '' : undefined as any);
      }

      if (returnType === 'text') {
        return Promise.resolve(respText);
      }

      // 默认或明确指定json时
      try {
        const data = JSON.parse(respText);
        return Promise.resolve(data);
      } catch (parseError) {
        // JSON解析失败时返回原始文本
        return Promise.resolve(respText as any);
      }
    } catch (error) {
      return Promise.reject(new Error(`HTTP POST请求失败: ${error}`));
    }
  }

  // 其余 put/delete 类似 ……


  /* 取消单个/全部请求 */
  cancel(id: string) { /* 内部维护 Map<id, AbortController> */ }
}