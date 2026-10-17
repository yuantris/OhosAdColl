import { hilog } from '@kit.PerformanceAnalysisKit';

/** hilog 日志域（取 'ZY' 的 ASCII 组合，便于按域过滤） */
export const ZY_LOG_DOMAIN: number = 0x5A59;
/** hilog 日志标签（沿用 ZYNetLog 标识，便于检索） */
export const ZY_LOG_TAG: string = 'ZYNetLog';

/** 网络日志全局开关：关闭后 debug/info/warn 全部静默，error 仍输出（避免静默吞错） */
let netLogEnabled: boolean = true;

/**
 * 开启/关闭网络日志（全局生效，覆盖请求日志框与 [CACHE] 等库内日志）
 * @param enabled true 开启（默认）/ false 关闭（error 级日志仍会输出，避免异常被静默吞掉）
 */
export function setNetLogEnabled(enabled: boolean): void {
  netLogEnabled = enabled;
}

/** 默认脱敏字段名集合（命中后值打码） */
const DEFAULT_MASK_KEYS: string[] = ['token', 'signToken', 'tk', 'uid', 'sid', 's1', 'o', 'o1', 'o2'];
/** 脱敏开关（默认关闭，保持日志明文便于联调） */
let maskEnabled: boolean = false;
/** 参与脱敏的字段名集合 */
const maskKeySet: Set<string> = new Set<string>(DEFAULT_MASK_KEYS);
/** 值为 JSON 对象、需递归脱敏其内部字段的日志键 */
const maskableJsonKeys: Set<string> = new Set<string>(['params', 'body', 'header', 'data', 'signedParams']);

/**
 * 配置日志脱敏（全局生效）
 * @param on true 开启脱敏 / false 关闭（默认）
 * @param keys 参与脱敏的字段名集合；不传时沿用当前集合（默认 token/signToken/tk/uid/sid/s1/o/o1/o2）
 */
export function setNetLogMask(on: boolean, keys?: string[]): void {
  maskEnabled = on;
  if (keys) {
    maskKeySet.clear();
    keys.forEach((k: string) => maskKeySet.add(k));
  }
}

/**
 * 打码单个敏感值：保留前 4 后 2 位，中间以 **** 代替；短值（≤6 字符）整体打码
 * @param v 原始值（允许带 JSON 字符串引号，打码前自动剥离）
 * @returns 打码后的值
 */
function maskValue(v: string): string {
  if (!v) {
    return v;
  }
  const raw = v.replace(/^"|"$/g, '');
  if (raw.length <= 6) {
    return '****';
  }
  return `${raw.substring(0, 4)}****${raw.substring(raw.length - 2)}`;
}

/**
 * 递归脱敏 JSON 文本中命中 maskKeySet 的字段值（深度上限 3 层；解析失败原样返回）
 * @param text JSON 字符串
 * @returns 脱敏后的 JSON 字符串
 */
function maskJson(text: string): string {
  try {
    const obj: ESObject = JSON.parse(text);
    walkMask(obj, 0);
    return JSON.stringify(obj);
  } catch (e) {
    return text;
  }
}

/**
 * maskJson 的递归实现：遍历对象字段，命中脱敏字段名的字符串值打码，嵌套对象继续下探
 * @param node 当前节点
 * @param depth 当前深度
 */
function walkMask(node: ESObject, depth: number): void {
  if (depth >= 3 || node === null || typeof node !== 'object') {
    return;
  }
  for (const k in node) {
    const v = node[k];
    if (typeof v === 'string' && maskKeySet.has(k)) {
      node[k] = maskValue(v);
    } else if (v && typeof v === 'object') {
      walkMask(v, depth + 1);
    }
  }
}

/**
 * 统一日志输出：以明文（%{public}s）经 hilog 打印，替代原 console 输出
 * 全局开关关闭时静默 debug/info/warn；error 始终输出，避免异常被静默吞掉
 * @param level hilog 级别方法（hilog.debug/info/warn/error）
 * @param msg 已拼接好的日志内容
 */
export function zyLog(level: (domain: number, tag: string, format: string, ...args: ESObject[]) => void, msg: string): void {
  if (!netLogEnabled && level !== hilog.error) {
    return;
  }
  level(ZY_LOG_DOMAIN, ZY_LOG_TAG, '%{public}s', msg);
}

/** 框线长度 */
const FRAME_DASH: string = '────────────────────────';

/** 日志级别枚举：日志行只存级别名，输出时显式映射到 hilog 对应方法（避免函数引用转存导致的级别漂移） */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/** 日志行：级别名 + 已拼好的完整文本 */
interface LogLine {
  kind: LogLevel;
  text: string;
}

/**
 * 级别名 → hilog 输出方法显式映射：flush 时按级别调用对应 hilog 方法，
 * 保证行级别与攒行时声明的一致（info 恒为 info，error 恒为 error）
 * @param kind 级别名
 * @returns 对应的 hilog 方法
 */
function levelToFn(kind: LogLevel): (domain: number, tag: string, format: string, ...args: ESObject[]) => void {
  switch (kind) {
    case 'debug':
      return hilog.debug;
    case 'warn':
      return hilog.warn;
    case 'error':
      return hilog.error;
    default:
      return hilog.info;
  }
}

/** 已收尾待输出的完整日志块队列（FIFO）：保证块与块之间连续输出、互不穿插 */
const blockQueue: ZyNetLogger[] = [];
/** 进行中的日志块：超时未收尾时由兜底机制强制输出，防止异常路径导致块泄漏、队列饿死 */
const openBlocks: ZyNetLogger[] = [];
/** 开放块兜底超时（毫秒）：超过该时长未收尾的块在下一次开块/入队时强制输出 */
const OPEN_TIMEOUT_MS: number = 30000;

/**
 * 清理超时未收尾的开放块：逆序扫描 openBlocks，超过 OPEN_TIMEOUT_MS 的强制补 END 并入队
 * （正常请求都会经 succeed/failed 收尾并自行出队，此机制仅兜底异常路径）
 */
function reapStaleBlocks(): void {
  const now = Date.now();
  for (let i = openBlocks.length - 1; i >= 0; i--) {
    if (now - openBlocks[i].openTime > OPEN_TIMEOUT_MS) {
      const block: ZyNetLogger = openBlocks.splice(i, 1)[0];
      block.forceClose();
      blockQueue.push(block);
    }
  }
}

/**
 * 将收尾完成的日志块入队并立即串行冲刷整个队列：
 * 同步 for 循环逐行输出（JS 单线程 + 无 await），块内所有行必然连续，
 * 并发请求的日志块按收尾顺序整块排队，彻底消除交错
 * @param block 已收尾的日志块
 */
function enqueueBlock(block: ZyNetLogger): void {
  blockQueue.push(block);
  reapStaleBlocks();
  while (blockQueue.length > 0) {
    const b: ZyNetLogger = blockQueue.shift() as ZyNetLogger;
    b.flushLines();
  }
}

/**
 * 长文本截断：hilog 单条日志上限约 4096 字节，超长会被系统硬截断成"断头"日志，
 * 这里主动截断并标注总长，保证日志收尾完整可读
 * @param s 待截断文本
 * @param max 最大保留字符数（默认 3800，纯 ASCII 下 3800 字节，接近但不超 hilog 4096 字节上限；
 *            含大量中文时单字节膨胀 3 倍，极端场景仍可能被系统截断尾部）
 * @returns 截断后的文本（未超长时原样返回）
 */
function truncate(s: string, max: number = 3800): string {
  if (!s) {
    return '';
  }
  if (s.length <= max) {
    return s;
  }
  return `${s.substring(0, max)}...(已截断，总长 ${s.length} 字符)`;
}

/**
 * 网络请求日志框：为每次请求生成唯一自增 ID（如 #000A）。
 * 块内行先攒齐、收尾后经 FIFO 队列整块输出（并发请求的块互不穿插）；
 * #ID 仅出现在框线行（┌/├/└），块内信息行不带 ID。
 *
 * 输出效果（左对齐开放框，避免中文宽度导致右边缘不齐）：
 * ┌──────────────── ZYNet#000A GET /xxx/yyy ────────────────
 * │ baseURL : http://...
 * │ params  : {...}
 * │ fullUrl : http://.../xxx/yyy?a=1
 * │ statusCode : 200
 * ├──────────────── ZYNet#000A · GET /xxx/yyy · 响应成功 · 耗时 128ms ────────────────
 * │ data    : {...}
 * └──────────────── ZYNet#000A END ────────────────
 */
export class ZyNetLogger {
  /** 自增序号（进程内唯一） */
  private static seq: number = 0;
  /** 当前请求 logger（仅在同步钩子窗口内有效，供签名拦截器等同步逻辑写入框内日志） */
  private static current: ZyNetLogger | null = null;
  /** JSON 格式化输出开关：开启后 params/body/header/data 等字段以缩进多行展示（默认关闭，防大响应刷屏） */
  private static pretty: boolean = false;

  /**
   * 开启/关闭 JSON 格式化输出（全局生效）
   * @param on true 开启：JSON 字段按 2 空格缩进逐行打印；false 关闭（默认）：单行紧凑输出
   */
  public static setPretty(on: boolean): void {
    ZyNetLogger.pretty = on;
  }

  /**
   * 将 JSON 字符串格式化为带缩进的多行文本（pretty 开启时使用）
   * @param jsonStr JSON 字符串
   * @param maxLines 最大输出行数，超出省略中间（防刷屏）
   * @returns 行数组；非 JSON 或解析失败时返回原字符串单行
   */
  private static formatJsonLines(jsonStr: string, maxLines: number = 60): string[] {
    try {
      const obj: ESObject = JSON.parse(jsonStr);
      const lines: string[] = JSON.stringify(obj, null, 2).split('\n');
      if (lines.length <= maxLines) {
        return lines;
      }
      return lines.slice(0, maxLines).concat([`...(已省略，共 ${lines.length} 行)`]);
    } catch (e) {
      // 非 JSON 文本原样单行输出
      return [jsonStr];
    }
  }

  /**
   * 写入一个"key: value"字段行；pretty 开启且内容为 JSON 时按 2 空格缩进逐行写入（行内不带 #ID，
   * 唯一 ID 仅由框线行承载）
   * @param logger 写入的 logger 实例
   * @param key 字段名
   * @param value 字段值（JSON 字符串）
   * @param kind 日志级别名（默认 'info'）
   */
  private static logField(logger: ZyNetLogger, key: string, value: string, kind: LogLevel = 'info'): void {
    // 脱敏处理：字段名直接命中 → 整值打码；JSON 字段 → 递归打码内部敏感字段
    let out = value;
    if (maskEnabled) {
      if (maskKeySet.has(key)) {
        out = maskValue(value);
      } else if (maskableJsonKeys.has(key)) {
        out = maskJson(value);
      }
    }
    if (!ZyNetLogger.pretty) {
      // 关闭：单行紧凑输出
      logger.pushLine(kind, `│ ${key.padEnd(11, ' ')}: ${truncate(out)}`);
      return;
    }
    // 开启：格式化多行输出（非 JSON 文本 formatJsonLines 返回单行，行为与关闭时一致）
    const lines = ZyNetLogger.formatJsonLines(out);
    logger.pushLine(kind, `│ ${key.padEnd(11, ' ')}: ${truncate(lines[0])}`);
    // 后续行与首行内容的起始列对齐（key 区 11 字符 + ": " 2 字符）
    const indent = ' '.repeat(13);
    for (let i = 1; i < lines.length; i++) {
      logger.pushLine(kind, `│ ${indent}${truncate(lines[i])}`);
    }
  }

  /**
   * 注册"当前请求"logger（仅限同步调用窗口，如请求拦截器执行期间；
   * JS 单线程模型下同步窗口内不会被其他请求的注册覆盖）
   * @param logger 当前请求的 logger 实例；钩子执行完毕后传 null 注销
   */
  public static setCurrent(logger: ZyNetLogger | null): void {
    ZyNetLogger.current = logger;
  }

  /**
   * 获取"当前请求"logger（同步钩子窗口内可取到，用于把签名等信息写入对应请求的框内）
   * @returns 当前请求的 logger；窗口外（异步回调中）返回 null
   */
  public static getCurrent(): ZyNetLogger | null {
    return ZyNetLogger.current;
  }

  /** 本次请求唯一标识 */
  private id: string;
  /** HTTP 方法 */
  private method: string;
  /** 请求路径 */
  private url: string;
  /** 开始时间戳（毫秒），用于计算耗时 */
  private startTime: number;
  /** 攒行缓冲：请求全程的日志行先攒齐，收尾时经队列整块输出（防并发交错） */
  private lines: LogLine[] = [];
  /** 是否已收尾：succeed/failed 之后不再接收新行 */
  private closed: boolean = false;
  /** 块开放时间戳（超时兜底用） */
  public openTime: number = Date.now();

  /**
   * 构造函数：生成本次请求的唯一 ID 并记录开始时间
   * @param method HTTP 方法（GET/POST/...）
   * @param url 请求路径
   */
  constructor(method: string, url: string) {
    ZyNetLogger.seq++;
    this.id = ZyNetLogger.seq.toString(16).toUpperCase().padStart(4, '0');
    this.method = method;
    this.url = url;
    this.startTime = Date.now();
    this.openTime = this.startTime;
  }

  /**
   * 向攒行缓冲追加一行（队列化输出核心）：
   * - 已收尾的块拒绝新行
   * - 全局开关关闭时 info/warn 静默（error 始终保留，避免异常被吞）
   * @param kind 级别名（'debug'|'info'|'warn'|'error'）
   * @param text 已拼好的完整行文本
   */
  private pushLine(kind: LogLevel, text: string): void {
    if (this.closed) {
      return;
    }
    if (!netLogEnabled && kind !== 'error') {
      return;
    }
    this.lines.push({ kind: kind, text: text });
  }

  /**
   * 将攒好的日志块同步整块输出（enqueueBlock 队列冲刷时调用）：
   * 同步循环逐行打印，级别经 levelToFn 显式映射；单线程模型下块内行不会被其他请求的日志插入
   */
  public flushLines(): void {
    for (const line of this.lines) {
      levelToFn(line.kind)(ZY_LOG_DOMAIN, ZY_LOG_TAG, '%{public}s', line.text);
    }
    this.lines = [];
  }

  /**
   * 从开放块列表移除自己（正常收尾时调用）
   */
  private removeFromOpen(): void {
    const idx = openBlocks.indexOf(this);
    if (idx >= 0) {
      openBlocks.splice(idx, 1);
    }
  }

  /**
   * 超时兜底强制收尾：仅补 END 标注行（正常收尾逻辑未执行，无耗时/data 行）
   */
  public forceClose(): void {
    this.closed = true;
    this.lines.push({ kind: 'error', text: `└${FRAME_DASH} ZYNet#${this.id} END(超时兜底) ${FRAME_DASH}` });
  }

  /**
   * 开启请求日志框：框头 + baseURL/params/body/header 信息行写入攒行缓冲
   * （此时不打印，待响应收尾后随整块经队列输出，保证块内行连续）
   * @param info 请求关键信息（可选字段，缺省不打印对应行）
   */
  begin(info?: ESObject): void {
    // 登记开放块（超时兜底用）并顺带清理历史超时块
    openBlocks.push(this);
    reapStaleBlocks();
    this.pushLine('error', `┌${FRAME_DASH} ZYNet#${this.id} ${this.method} ${this.url} ${FRAME_DASH}`);
    if (!info) {
      return;
    }
    if (info.baseURL) {
      ZyNetLogger.logField(this, 'baseURL', String(info.baseURL));
    }
    if (info.header) {
      ZyNetLogger.logField(this, 'header', JSON.stringify(info.header));
    }
    if (info.params) {
      ZyNetLogger.logField(this, 'params', JSON.stringify(info.params));
    }
    if (info.data) {
      ZyNetLogger.logField(this, 'body', JSON.stringify(info.data));
    }
  }

  /**
   * 框内补充一行信息（如 fullUrl、statusCode）
   * @param key 字段名（不足 11 字符自动补齐对齐）
   * @param value 字段值（超长自动截断）
   * @param kind 日志级别名（默认 'info'；HTTP 错误等特殊场景可传 'warn'/'error'）
   */
  step(key: string, value: string, kind: LogLevel = 'info'): void {
    ZyNetLogger.logField(this, key, value, kind);
  }

  /**
   * 响应成功收尾：耗时分隔行 + data + END 框尾写入缓冲，随后整块入队输出
   * @param data 服务端响应（整包打印，超长截断）
   */
  succeed(data: ESObject): void {
    if (this.closed) {
      return;
    }
    const cost = Date.now() - this.startTime;
    this.pushLine('error', `├${FRAME_DASH} ZYNet#${this.id} · ${this.method} ${this.url} · 响应成功 · 耗时 ${cost}ms ${FRAME_DASH}`);
    // data 行用 error 级别（控制台醒目）：一眼区分哪个接口返回了什么，且不会被当异常过滤
    ZyNetLogger.logField(this, 'data', JSON.stringify(data), 'error');
    this.pushLine('error', `└${FRAME_DASH} ZYNet#${this.id} END ${FRAME_DASH}`);
    this.closed = true;
    this.removeFromOpen();
    enqueueBlock(this);
  }

  /**
   * 请求失败收尾：耗时分隔行 + 失败原因 + 错误对象 + END 框尾写入缓冲，随后整块入队输出
   * @param err 错误对象（JSON 序列化打印）
   * @param reason 人类可读的失败原因（可选）
   */
  failed(err: ESObject, reason?: string): void {
    if (this.closed) {
      return;
    }
    const cost = Date.now() - this.startTime;
    this.pushLine('error', `├${FRAME_DASH} ZYNet#${this.id} · ${this.method} ${this.url} · 请求失败 · 耗时 ${cost}ms ${FRAME_DASH}`);
    if (reason) {
      this.pushLine('info', `│ reason  : ${reason}`);
    }
    ZyNetLogger.logField(this, 'err', JSON.stringify(err), 'error');
    this.pushLine('error', `└${FRAME_DASH} ZYNet#${this.id} END ${FRAME_DASH}`);
    this.closed = true;
    this.removeFromOpen();
    enqueueBlock(this);
  }
}
