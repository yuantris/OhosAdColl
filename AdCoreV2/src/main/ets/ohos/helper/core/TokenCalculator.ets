import { MD5, StrUtils } from '@zycore/common';
import { SDKCore } from '../../application/SDKCore';
import { AdSwitchManager } from '../core/AdSwitchManager';
import { AdIdStore } from './AdIdStore';
import { Module, ModuleItem } from '../entity/AppPckInfoResp';
import { LogManager } from '../logger/LogManager';

let adsAll: string[]

export class TokenCalculator {
  static getV4It(): string {
    let it = ''
    try {
      const ads: string[] = TokenCalculator.parseConfig()
      it = TokenCalculator.getItoken(ads)
    } catch (e) {
      it = TokenCalculator.md5ItokenBlank(6)
    }
    return it
  }

  static getItoken(ids: Array<string>): string {
    let result = '';
    if (ids.length > 0) {
      const concatenated = ids.filter((it: string) => it.length > 6).join('');
      const charArray = concatenated.split('');
      charArray.sort();
      result = charArray.join('');
    }
    return TokenCalculator.md5ItokenStr(result, 6);
  }

  static md5ItokenStr(str: string, size: number): string {
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

  static md5ItokenBlank(size: number): string {
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

  static getSdkParams(): ESObject {
    return AdSwitchManager.enableEasyConfig ? SDKCore.EASY_AD?.sdk : SDKCore.AD?.sdk
  }

  static parseSV(sdk: ESObject): string {
    const zy: string = (sdk?.hzy ?? '0') || '0'
    const um: string = (sdk?.hum ?? '0') || '0'
    const csj: string = (sdk?.hcsj ?? '0') || '0'
    const tx: string = (sdk?.htx ?? '0') || '0'
    const ks: string = (sdk?.ks ?? '0') || '0'
    const hw: string = (sdk?.hw ?? '0') || '0'

    const digits = zy.replace(/[^0-9]/, '').padEnd(6, '0').substring(0, 6)
    const zy_num = parseInt(digits) || 111600

    return `${zy_num},${um},${csj},${tx},${ks},${hw}`
  }

  private static parseConfig(): string[] {
    let ad: ESObject = SDKCore.AD
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
      if (StrUtils.isNotBlank(csj?.appid)) {
        csjAds.set("appid", csj?.appid);
        csjAds.set("open", csj?.open);
      }
    }
    if (JSON.stringify(tx) != null && JSON.stringify(tx).length > 0) {
      if (StrUtils.isNotBlank(tx?.appid)) {
        txAds.set("appid", tx?.appid);
        txAds.set("open", tx?.open);
      }
    }
    if (JSON.stringify(ks) != null && JSON.stringify(ks).length > 0) {
      if (StrUtils.isNotBlank(ks?.appid)) {
        ksAds.set("appid", ks?.appid);
        ksAds.set("open", ks?.open);
      }
    }
    if (JSON.stringify(hw) != null && JSON.stringify(hw).length > 0) {
      if (StrUtils.isNotBlank(hw?.appid)) {
        hwAds.set("appid", hw?.appid);
        hwAds.set("open", hw?.open);
      }
    }
    TokenCalculator.getHarmonyAdMap(csj).forEach((value, key) => {
      csjAds.set(key, value);
    })
    TokenCalculator.getHarmonyAdMap(tx).forEach((value, key) => {
      txAds.set(key, value);
    })
    TokenCalculator.getHarmonyAdMap(ks).forEach((value, key) => {
      ksAds.set(key, value);
    })
    TokenCalculator.getHarmonyAdMap(hw).forEach((value, key) => {
      hwAds.set(key, value);
    })

    adsAll = [];

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

  private static getHarmonyAdMap(ad: ESObject): Map<string, string> {
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
    TokenCalculator.getModulesAdMap(m).forEach((value, key) => {
      if (key.includes("lscr")) {
        adMap.set(key, value)
      }
    })
    return adMap
  }

  private static getModulesAdMap(modules: Module[]): Map<string, string> {
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
}
