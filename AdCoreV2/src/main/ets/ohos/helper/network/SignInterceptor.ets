import { ZyMiddleware, ZyMiddlewareContext } from '@creative/net';
import { INJECT_IT_PATHS } from './APIs';
import { util } from '@kit.ArkTS';
import { AdIdStore } from '../core/AdIdStore';
import { md5Sync, NetBasic } from './NetBasic';
import { zyLog } from '@creative/net';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class ZySignMiddleware implements ZyMiddleware {
  name: string = 'sign';
  private baseURLProvider: () => string;

  constructor(baseURLProvider: () => string) {
    this.baseURLProvider = baseURLProvider;
  }

  async onRequest(ctx: ZyMiddlewareContext): Promise<void> {
    const req = ctx.request;
    const custom = ctx.custom;

    let tk: string | undefined;
    if (custom !== undefined && custom['tokenSpec'] !== undefined) {
      tk = custom['tokenSpec'] as string;
    }

    if (tk === undefined) {
      zyLog(hilog.warn, `[SIGN] 缺少 token 规格，未计算签名: url=${req.url}`);
      return;
    }

    const uuid = util.generateRandomUUID().replaceAll('-', '');
    const a_from = AdIdStore.APPID;
    const v_from = AdIdStore.VID;
    const c_from = 'harmony';
    const r_from = 7;
    const sid_from = NetBasic.SID;

    const queryParts: string[] = [];
    queryParts.push(`a=${encodeURIComponent(a_from)}`);
    queryParts.push(`v=${encodeURIComponent(v_from)}`);
    queryParts.push(`c=${encodeURIComponent(c_from)}`);
    queryParts.push(`r=${String(r_from)}`);
    queryParts.push(`uuid=${encodeURIComponent(uuid)}`);

    const m_header = NetBasic.MARKET_NAME;
    const s1_header = sid_from;
    const p1_header = NetBasic.PACKAGE_NAME;
    const o_header = md5Sync(NetBasic.DEVICE_ID);
    const t1_header = Date.now();

    req.headers.set('m', m_header);
    req.headers.set('s', '');
    req.headers.set('s1', s1_header);
    req.headers.set('p1', p1_header);
    req.headers.set('o', o_header);
    req.headers.set('o1', o_header);
    req.headers.set('o2', o_header);
    req.headers.set('t1', t1_header.toString());
    req.headers.set('a1', a_from);

    try {
      req.headers.set('sv', NetBasic.SV);
    } catch (e) {
      req.headers.set('sv', '1.0.0');
    }

    if (INJECT_IT_PATHS.some((path: string) => req.url.includes(path))) {
      req.headers.set('it', NetBasic.IT);
    }

    const keys = tk.split('_') as string[];
    let token_str: string | null = null;

    const keyMapping: Map<string, string> = new Map<string, string>();
    keyMapping.set('rtype', 'r');
    keyMapping.set('sid', 's1');
    keyMapping.set('aid', 'a');
    keyMapping.set('vid', 'v');

    const queryMap: Record<string, string> = {};
    queryMap['a'] = a_from;
    queryMap['v'] = v_from;
    queryMap['c'] = c_from;
    queryMap['r'] = String(r_from);
    queryMap['uuid'] = uuid;

    const customParams: Record<string, ESObject> | undefined =
      custom !== undefined && custom['params'] !== undefined ? custom['params'] as Record<string, ESObject> : undefined;

    keys.forEach((k: string) => {
      const mappedKey: string = keyMapping.get(k) ?? k;
      let kv: string | null = null;

      if (queryMap[mappedKey] !== undefined) {
        kv = queryMap[mappedKey];
      } else if (customParams !== undefined && customParams[mappedKey] !== undefined) {
        kv = String(customParams[mappedKey]);
      } else if (req.headers.has(mappedKey)) {
        kv = req.headers.get(mappedKey) ?? null;
      } else if (req.content !== undefined && typeof req.content === 'object' && !(req.content instanceof ArrayBuffer)) {
        const body: Record<string, ESObject> = req.content as Record<string, ESObject>;
        if (body[mappedKey] !== undefined) {
          kv = String(body[mappedKey]);
        }
      }

      if (kv != null && kv !== undefined) {
        if (token_str == null) {
          token_str = kv;
        } else {
          token_str += ('_' + kv);
        }
      }
    });

    if (token_str) {
      const tokenValue = md5Sync(token_str);
      queryParts.push(`token=${encodeURIComponent(tokenValue)}`);
    } else {
      zyLog(hilog.warn, `[SIGN] token 规格解析失败: url=${req.url} spec=${tk}`);
    }

    if (queryParts.length > 0) {
      const sep = req.url.includes('?') ? '&' : '?';
      req.url = `${req.url}${sep}${queryParts.join('&')}`;
    }
  }
}

/**
 * @deprecated 不再需要导出实例；HttpClient 内部自行创建并注册 ZySignMiddleware。
 * 保留以兼容存量引用，新代码无需使用
 */
export const zySignMiddleware: ZySignMiddleware = new ZySignMiddleware(() => '');
