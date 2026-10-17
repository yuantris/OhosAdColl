import ADUtil, { getItoken, logD, md5ItokenBlank } from '../util/ADUtil';
import { AD } from './AD';
import { Module, ModuleItem } from '../helper/entity/AppPckInfoResp';
import { AESCodec, Any, Log, StrUtils } from '@zycore/common';
import { TestLog } from '../test/TestLogEnvironment';

let adsAll: string[]

export function configAD(obj: ESObject) {
  try {
    Configs.AD = obj
    AD.APPID = obj?.appid ?? ""
    AD.VID = obj?.versionCode ?? ""
    AD.SID = obj?.sid ?? ""

    const getSafeValue = (value: Any, defaultValue = "") => {
      try {
        return value as string ?? defaultValue
      } catch {
        return defaultValue
      }
    }

    new ADConfigBuilder()
      .setCSJ_APPID(getSafeValue(obj?.hmads?.csj?.appid))
      .setCSJ_SPLASH_ID(getSafeValue(obj?.hmads?.csj?.open))
      .setCSJ_VIDEO_ID(getSafeValue(obj?.hmads?.csj?.exts?.split(',')[0]))
      .setCSJ_INFO_ID(getSafeValue(obj?.hmads?.csj?.exit))
      .setCSJ_INFO_LEFT_ID(getSafeValue(obj?.hmads?.csj?.exts?.split(',')[1]))
      .setCSJ_SCREEN_ID(getSafeValue(obj?.hmads?.csj?.modules?.find((item: ESObject) => item.moduleId ==
        'public')?.lscr[0]?.id))
      .setTX_APPID(getSafeValue(obj?.hmads?.tx?.appid))
      .setTX_SPLASH_DEFAULT_POS_ID(getSafeValue(obj?.hmads?.tx?.open))
      .setTX_REWARD_DEFAULT_POS_ID(getSafeValue(obj?.hmads?.tx?.exts?.split(',')[0]))
      .setTX_NATIVE_DEFAULT_POS_ID(getSafeValue(obj?.hmads?.tx?.exit))
      .setTX_MANUAL_DEFAULT_POS_ID(getSafeValue(obj?.hmads?.tx?.exts?.split(',')[1]))
      .setTX_INTERSTITIAL_DEFAULT_POS_ID(getSafeValue(obj?.hmads?.tx?.modules?.find((item: ESObject) => item.moduleId ==
        'public')?.lscr[0]?.id))
      .setHW_SPLASH_ID(getSafeValue(obj?.hmads?.hw?.open))
      .setHW_SCREEN_ID(getSafeValue(obj?.hmads?.hw?.modules?.find((item: ESObject) => item.moduleId ==
        'public')?.lscr[0]?.id))
      .setHW_VIDEO_ID(getSafeValue(obj?.hmads?.hw?.exts?.split(',')[0]))
      .setHW_INFO_ID(getSafeValue(obj?.hmads?.hw?.exit))
      .setHW_INFO_LEFT_ID(getSafeValue(obj?.hmads?.hw?.exts?.split(',')[1]))

    if (obj?.hap_env && obj?.hap_env !== 'prod') {
      Log.warn(`当前打包环境: ${obj?.hap_env}, 强制展示测试广告ID`)
      TestLog.forceShowTestAd()
    }
  } catch (e) {
    Log.error("configAD error: ", e)
  }
}

export function verifyConfigAD(zyoff: ESObject) {
  logD("<--开始V4校验-->")
  if (StrUtils.isBlank(zyoff?.i)) {
    return
  }
  const i = AESCodec.decrypt(AD.APPID, zyoff?.i) ?? ''
  const v4: ESObject = JSON.parse(i)
  const it = getV4It()

  const getSafeValue = (value: Any, defaultValue = "") => {
    try {
      return value as string ?? defaultValue
    } catch {
      return defaultValue
    }
  }

  if (it != getSafeValue(v4?.it, '')) {
    Log.info("<--iToken校验失败，重新配置广告ID-->")
    // 重新配置广告ID
    new ADConfigBuilder()
      .setCSJ_APPID(getSafeValue(v4?.csj?.appid))
      .setCSJ_SPLASH_ID(getSafeValue(v4?.csj?.open))
      .setCSJ_VIDEO_ID(getSafeValue(v4?.csj?.video))
      .setCSJ_INFO_ID(getSafeValue(v4?.csj?.info))
      .setCSJ_INFO_LEFT_ID(getSafeValue(v4?.csj?.left_info))
      .setCSJ_SCREEN_ID(getSafeValue(v4?.csj?.lscr))
      .setTX_APPID(getSafeValue(v4?.tx?.appid))
      .setTX_SPLASH_DEFAULT_POS_ID(getSafeValue(v4?.tx?.open))
      .setTX_REWARD_DEFAULT_POS_ID(getSafeValue(v4?.tx?.video))
      .setTX_NATIVE_DEFAULT_POS_ID(getSafeValue(v4?.tx?.info))
      .setTX_MANUAL_DEFAULT_POS_ID(getSafeValue(v4?.tx?.left_info))
      .setTX_INTERSTITIAL_DEFAULT_POS_ID(getSafeValue(v4?.tx?.lscr))
      .setHW_SPLASH_ID(getSafeValue(v4?.hw?.open))
      .setHW_SCREEN_ID(getSafeValue(v4?.hw?.lscr))
      .setHW_VIDEO_ID(getSafeValue(v4?.hw?.video))
      .setHW_INFO_ID(getSafeValue(v4?.hw?.info))
      .setHW_INFO_LEFT_ID(getSafeValue(v4?.hw?.left_info))
  } else {
    Log.info('<--iToken校验成功-->')
  }
}

function parseConfig(adArray: string[] | undefined = undefined) {
  let ad: ESObject = Configs.AD
  const map1: Map<string, ESObject> = new Map<string, string>(Object.entries(JSON.parse(JSON.stringify(ad.hmads))));
  const csj: ESObject = map1.get("csj")
  const tx: ESObject = map1.get("tx")
  const ks: ESObject = map1.get("ks")
  const hw: ESObject = map1.get("hw")

  const csjAds: Map<string, string> = new Map<string, string>();
  const txAds: Map<string, string> = new Map<string, string>();
  const ksAds: Map<string, string> = new Map<string, string>();
  const hwAds: Map<string, string> = new Map<string, string>();
  if (JSON.stringify(csj) != null && JSON.stringify(csj).length > 0) {
    if (ADUtil.isNotBlank(csj?.appid)) {
      csjAds.set("appid", csj?.appid);
      csjAds.set("open", csj?.open);
    }
  }
  if (JSON.stringify(tx) != null && JSON.stringify(tx).length > 0) {
    if (ADUtil.isNotBlank(tx?.appid)) {
      txAds.set("appid", tx?.appid);
      txAds.set("open", tx?.open);
    }
  }
  if (JSON.stringify(ks) != null && JSON.stringify(ks).length > 0) {
    if (ADUtil.isNotBlank(ks?.appid)) {
      ksAds.set("appid", ks?.appid);
      ksAds.set("open", ks?.open);
    }
  }
  if (JSON.stringify(hw) != null && JSON.stringify(hw).length > 0) {
    if (ADUtil.isNotBlank(hw?.appid)) {
      hwAds.set("appid", hw?.appid);
      hwAds.set("open", hw?.open);
    }
  }
  getHarmonyAdMap(csj).forEach((value, key) => {
    csjAds.set(key, value);
  })
  getHarmonyAdMap(tx).forEach((value, key) => {
    txAds.set(key, value);
  })
  getHarmonyAdMap(ks).forEach((value, key) => {
    ksAds.set(key, value);
  })
  getHarmonyAdMap(hw).forEach((value, key) => {
    hwAds.set(key, value);
  })

  // 初始化adsAll数组
  adsAll = [];

  // 将所有广告Map中的value添加到adsAll数组
  if (txAds.has("appid")) {
    txAds.forEach((value) => adsAll.push(value));
  }
  if (csjAds.has("appid")) {
    csjAds.forEach((value) => adsAll.push(value));
  }
  if (ksAds.has("appid")) {
    ksAds.forEach((value) => adsAll.push(value));
  }
  if (hwAds.has("appid")) {
    hwAds.forEach((value) => adsAll.push(value));
  }

  return adsAll;
}

export function getV4It(): string {
  let it = ''
  try {
    const ads: string[] = parseConfig()
    it = getItoken(ads)
  } catch (e) {
    it = md5ItokenBlank(6)
  }
  return it
}

export function getSdkParams(): ESObject {
  return Configs.AD.sdk
}

function getHarmonyAdMap(ad: ESObject): Map<string, string> {
  const adMap: Map<string, string> = new Map<string, string>();
  adMap.set("info", ad?.exit)
  const ext_split: string[] = ad.exts.split(",")
  if (ext_split.length > 1) {
    if (ext_split[0].length > 6) {
      adMap.set("video", ext_split[0])
    }
    if (ext_split[1].length > 6) {
      adMap.set("left_info", ext_split[1])
    }
  }

  const m = JSON.parse(JSON.stringify(ad.modules)) as Module[];
  getModulesAdMap(m).forEach((value, key) => {
    if (key.includes("lscr")) {
      adMap.set(key, value)
    }
  })
  return adMap
}

function getModulesAdMap(modules: Module[]): Map<string, string> {
  const adMap: Map<string, string> = new Map<string, string>();
  modules.forEach(module => {
    module.ban.filter((item: ModuleItem) => item.id.length > 6)
      .forEach((item: ModuleItem) => {
        adMap.set(item.adId, item.id);
      });
    module.info.filter((item: ModuleItem) => item.id.length > 6)
      .forEach((item: ModuleItem) => {
        adMap.set(item.adId, item.id);
      });
    module.info_left.filter((item: ModuleItem) => item.id.length > 6)
      .forEach((item: ModuleItem) => {
        adMap.set(item.adId, item.id);
      });
    module.video.filter((item: ModuleItem) => item.id.length > 6)
      .forEach((item: ModuleItem) => {
        adMap.set(item.adId, item.id);
      });
    module.lscr.filter((item: ModuleItem) => item.id.length > 6)
      .forEach((item: ModuleItem) => {
        adMap.set(item.adId, item.id);
      });
  })
  return adMap;
}


export class ADConfigBuilder {
  /**
   * 设置穿山甲应用ID
   */
  setCSJ_APPID(appid: string): ADConfigBuilder {
    AD.CSJ_APPID = appid;
    return this;
  }

  /**
   * 设置穿山甲开屏广告ID
   */
  setCSJ_SPLASH_ID(splashId: string): ADConfigBuilder {
    AD.CSJ_SPLASH_ID = splashId;
    return this;
  }

  /**
   * 设置穿山甲视频广告ID
   */
  setCSJ_VIDEO_ID(id: string): ADConfigBuilder {
    AD.CSJ_VIDEO_ID = id;
    return this;
  }

  /**
   * 设置穿山甲信息流广告ID
   */
  setCSJ_INFO_ID(id: string): ADConfigBuilder {
    AD.CSJ_INFO_ID = id;
    return this;
  }

  /**
   * 设置穿山甲信息流小图广告ID
   */
  setCSJ_INFO_LEFT_ID(id: string): ADConfigBuilder {
    AD.CSJ_INFO_LEFT_ID = id;
    return this;
  }

  /**
   * 设置穿山甲原生信息流广告ID
   */
  setCSJ_INFO_NATIVE_ID(id: string): ADConfigBuilder {
    AD.CSJ_INFO_NATIVE_ID = id;
    return this;
  }

  /**
   * 设置穿山甲插屏广告ID
   */
  setCSJ_SCREEN_ID(id: string): ADConfigBuilder {
    AD.CSJ_SCREEN_ID = id
    return this;
  }

  /**
   * 设置腾讯应用ID
   */
  setTX_APPID(id: string): ADConfigBuilder {
    AD.TX_APP_ID = id
    return this;
  }

  /**
   * 设置腾讯开屏广告ID
   */
  setTX_SPLASH_DEFAULT_POS_ID(id: string): ADConfigBuilder {
    AD.TX_SPLASH_DEFAULT_POS_ID = id
    return this;
  }

  /**
   * 设置腾讯激励视频广告ID
   */
  setTX_REWARD_DEFAULT_POS_ID(id: string): ADConfigBuilder {
    AD.TX_REWARD_DEFAULT_POS_ID = id
    return this;
  }

  /**
   * 设置腾讯信息流广告ID
   */
  setTX_NATIVE_DEFAULT_POS_ID(id: string): ADConfigBuilder {
    AD.TX_NATIVE_DEFAULT_POS_ID = id
    return this;
  }

  /**
   * 设置腾讯信息流小图广告ID
   */
  setTX_MANUAL_DEFAULT_POS_ID(id: string): ADConfigBuilder {
    AD.TX_MANUAL_DEFAULT_POS_ID = id
    return this;
  }

  /**
   * 设置腾讯插屏广告ID
   */
  setTX_INTERSTITIAL_DEFAULT_POS_ID(id: string): ADConfigBuilder {
    AD.TX_INTERSTITIAL_DEFAULT_POS_ID = id
    return this;
  }

  setHW_SPLASH_ID(id: string): ADConfigBuilder {
    AD.HW_SPLASH_ID = id
    return this;
  }

  setHW_SCREEN_ID(id: string): ADConfigBuilder {
    AD.HW_SCREEN_ID = id
    return this;
  }

  setHW_VIDEO_ID(id: string): ADConfigBuilder {
    AD.HW_VIDEO_ID = id
    return this;
  }

  setHW_INFO_ID(id: string): ADConfigBuilder {
    AD.HW_INFO_ID = id
    return this;
  }

  setHW_INFO_LEFT_ID(id: string): ADConfigBuilder {
    AD.HW_INFO_LEFT_ID = id
    return this;
  }

  setHW_INFO_NATIVE_ID(id: string): ADConfigBuilder {
    AD.HW_INFO_NATIVE_ID = id
    return this;
  }
}

class Configs {
  static AD: ESObject
}
