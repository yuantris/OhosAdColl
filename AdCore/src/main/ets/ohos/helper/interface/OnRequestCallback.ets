import { IAd } from "../impl/IAd";

export interface onRequestCallback {
  /**
   * 请求成功
   * @param iAds
   */
  onRequested: (iAds: IAd<ESObject>[]) => void

  /**
   * 请求失败
   * @param code
   * @param error
   */
  onFailed: (code: number, error: string) => void
}