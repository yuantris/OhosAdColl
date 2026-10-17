import { ZyHttpError } from '../error/ZyHttpError';
import { ZyHttpRequestInternal } from '../core/ZyHttpRequestInternal';
import { ZyHttpLogger } from '../core/ZyHttpConfig';

/**
 * 中间件上下文(洋葱模型)
 * - request: 当前请求的可变对象(可直接修改 url/headers/content 等)
 * - response: 响应阶段才有值(onResponse 时为已解析数据, onResponseError 时为 undefined)
 * - error: 响应错误阶段才有值(onResponseError 时为标准化错误)
 * - respond(): 改写响应/吞错降级:
 *   onResponse 链中调用 → 用给定数据替换响应体(如统一加解密解包)
 *   onResponseError 链中调用 → 吞掉错误返回兜底数据(降级不中断业务)
 *   调用后短路后续中间件链
 */
export interface ZyMiddlewareContext {
  request: ZyHttpRequestInternal;
  response?: ESObject;
  error?: ZyHttpError;
  /** 改写响应数据/吞错降级(调用后短路当前链) */
  respond: (data: ESObject) => void;
  /** 请求级自定义数据(调用方可通过 builder.custom() 传入, 中间件可读取) */
  custom?: Record<string, ESObject>;
}

/**
 * 中间件接口(洋葱模型, 类似 Koa 中间件)
 * 调用顺序: onRequest → [实际请求] → onResponse | onResponseError
 * - onRequest:        请求发出前, 可修改请求(如注入鉴权头/签名)
 * - onResponse:       收到响应后, 可修改响应数据或抛出错误(如业务码校验)
 * - onResponseError: 请求失败后, 可观察错误或重抛/转换为其他错误
 */
export interface ZyMiddleware {
  /** 名称(用于 skip 跳过) */
  name: string;
  /** 请求阶段(可异步) */
  onRequest?(ctx: ZyMiddlewareContext): Promise<void> | void;
  /** 响应阶段(可异步; 抛错将中断后续中间件并走 onResponseError 链) */
  onResponse?(ctx: ZyMiddlewareContext): Promise<void> | void;
  /** 响应错误阶段(可异步; 重抛或抛新错误将传递给下一个中间件) */
  onResponseError?(ctx: ZyMiddlewareContext): Promise<void> | void;
}

/**
 * 内置: 结构化日志中间件
 * 输出请求边界、响应耗时摘要; 错误时输出错误码与扩展字段
 * 日志出口可注入(宿主 hilog/LogManager), 未注入时走 console
 */
export class LoggingMiddleware implements ZyMiddleware {
  name: string = 'log';
  private tag: string;
  private logger?: ZyHttpLogger;

  /**
   * @param tag 日志 TAG
   * @param logger 自定义日志出口(可选, 默认 console)
   */
  constructor(tag: string = 'ZyHttp', logger?: ZyHttpLogger) {
    this.tag = tag;
    this.logger = logger;
  }

  /**
   * 统一日志出口: 注入 logger 时走宿主系统, 否则 console
   */
  private out(level: 'debug' | 'info' | 'warn' | 'error', msg: string): void {
    if (this.logger !== undefined) {
      this.logger(level, msg);
      return;
    }
    if (level === 'error') {
      console.error(`[${this.tag}] ${msg}`);
    } else if (level === 'warn') {
      console.warn(`[${this.tag}] ${msg}`);
    } else {
      console.info(`[${this.tag}] ${msg}`);
    }
  }

  async onRequest(ctx: ZyMiddlewareContext): Promise<void> {
    const req = ctx.request;
    this.out('warn', `------ #${req.requestId} ${req.method} ${req.url} ------`);
    if (req.headers.size > 0) {
      const headerPairs: string[] = [];
      req.headers.forEach((v: string, k: string) => {
        headerPairs.push(`${k}=${v}`);
      });
      this.out('info', `#${req.requestId} headers: ${headerPairs.join(', ')}`);
    }
    if (req.content !== undefined) {
      this.out('info', `#${req.requestId} body: ${req.content}`);
    }
  }

  async onResponse(ctx: ZyMiddlewareContext): Promise<void> {
    const req = ctx.request;
    const status: number = req.resolvedStatus ?? 0;
    const dur: string = req.resolvedDurationMs !== undefined ? `${req.resolvedDurationMs}ms` : 'n/a';
    this.out('warn', `------ #${req.requestId} ${status} ${dur} ------`);
  }

  async onResponseError(ctx: ZyMiddlewareContext): Promise<void> {
    const req = ctx.request;
    const err = ctx.error;
    if (err !== undefined) {
      this.out('error', `#${req.requestId} FAIL kind=${err.kind} code=${err.code ?? '-'} ${err.message}`);
    }
  }
}

/**
 * 内置: 默认头注入中间件
 * 请求发出前注入实例级默认头(请求级同名头优先, 不覆盖)
 */
export class DefaultHeaderMiddleware implements ZyMiddleware {
  name: string = 'default-header';
  private defaultHeaders: Map<string, string>;

  /**
   * @param headers 默认头表
   */
  constructor(headers: Map<string, string>) {
    this.defaultHeaders = headers;
  }

  async onRequest(ctx: ZyMiddlewareContext): Promise<void> {
    this.defaultHeaders.forEach((v: string, k: string) => {
      if (!ctx.request.headers.has(k)) {
        ctx.request.headers.set(k, v);
      }
    });
  }
}

/**
 * 内置: 签名中间件示例(占位实现, 接入方可替换为真实签名算法)
 */
export class SignMiddleware implements ZyMiddleware {
  name: string = 'sign';
  private signer: (req: ZyHttpRequestInternal) => Map<string, string>;

  /**
   * @param signer 签名函数: 输入请求, 返回需追加的头(如 X-Sign)
   */
  constructor(signer: (req: ZyHttpRequestInternal) => Map<string, string>) {
    this.signer = signer;
  }

  async onRequest(ctx: ZyMiddlewareContext): Promise<void> {
    const signHeaders: Map<string, string> = this.signer(ctx.request);
    signHeaders.forEach((v: string, k: string) => {
      ctx.request.headers.set(k, v);
    });
  }
}
