import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[Toast]';

// ==================== 类型定义 ====================

/** Toast 时长常量 */
export enum ToastDuration {
  /** 短时（1.5秒） */
  SHORT = 1500,
  /** 长时（3.5秒） */
  LONG = 3500,
}

/** Toast 文本类型 */
export type ToastMessage = ResourceStr;

/** Toast 配置项 */
export interface ToastOptions {
  /** 显示文本 */
  message: ToastMessage;

  /** 显示时长（毫秒），默认 2000 */
  duration?: number;

  /** 距底部距离（vp），默认居中偏下 */
  bottom?: number | string;
}

/** Toast 文本最大长度 */
const MAX_MESSAGE_LENGTH: number = 80;

// ==================== Toast 工具类 ====================

/**
 * Toast 工具类
 * 封装 HarmonyOS promptAction.showToast() / openToast()，提供简洁的静态调用方式
 *
 * 用法示例：
 * ```ts
 * // ① 简单调用（同步，fire-and-forget）
 * Toast.show('操作成功');
 * Toast.show('操作失败', ToastDuration.LONG);
 *
 * // ② 配置对象调用
 * Toast.show({
 *   message: '操作成功',
 *   duration: ToastDuration.SHORT,
 *   bottom: '200vp',
 * });
 *
 * // ③ 语义化快捷方法
 * Toast.success('保存成功');
 * Toast.error('网络异常');
 * Toast.warning('请先登录');
 * Toast.info('默认提示');
 *
 * // ④ 等待 toast 完全消失后再执行逻辑（基于 openToast）
 * await Toast.showAsync('加载完成');
 * await Toast.showAsync({ message: '完成', duration: ToastDuration.LONG });
 * ```
 */
export class Toast {
  private static _lastMessage: Optional<string> = undefined;
  private static _lastTime: number = 0;
  /** 相同时长阈值（ms），防止重复弹出相同内容 */
  private static _dedupInterval: number = 500;

  // ==================== 核心方法（同步） ====================

  /**
   * 显示 Toast（同步，不等待消失）
   * @param options Toast 配置对象
   */
  public static show(options: ToastOptions): void;

  /**
   * 显示 Toast（同步，不等待消失）
   * @param message 显示文本
   * @param duration 显示时长（毫秒），默认 2000
   * @param bottom 距底部距离（vp）
   */
  public static show(message: ToastMessage, duration?: number, bottom?: number | string): void;

  public static show(
    messageOrOptions: ToastMessage | ToastOptions,
    duration?: number,
    bottom?: number | string
  ): void {
    try {
      const options = Toast.normalizeParams(messageOrOptions, duration, bottom);

      // 文本校验与截断
      const text = Toast.sanitizeMessage(options.message);
      if (text === undefined) {
        hilog.warn(0x0000, TAG, 'Toast.show: message is empty, ignored');
        return;
      }

      // 去重：短时间内相同内容不重复弹出
      if (Toast.shouldDedup(text)) {
        hilog.debug(0x0000, TAG, `Toast.show: duplicate message "${text}" within ${Toast._dedupInterval}ms, ignored`);
        return;
      }

      // 记录最后弹出信息（用于去重）
      Toast._lastMessage = text;
      Toast._lastTime = Date.now();

      const durationMs = options.duration ?? ToastDuration.SHORT;
      promptAction.showToast({
        message: options.message,
        duration: durationMs,
        bottom: options.bottom
      });

      hilog.debug(0x0000, TAG, `Toast.show: "${text}" (duration=${durationMs}ms)`);
    } catch (err) {
      logError('show', err);
    }
  }

  // ==================== 核心方法（异步） ====================

  /**
   * 显示 Toast 并等待其完全消失
   * 底层使用 promptAction.openToast() 获取 toastId，然后等待 duration 后 resolve
   * @param options Toast 配置对象
   * @returns Promise，toast 显示完毕并消失后 resolve
   */
  public static showAsync(options: ToastOptions): Promise<void>;

  /**
   * 显示 Toast 并等待其完全消失
   * @param message 显示文本
   * @param duration 显示时长（毫秒），默认 2000
   * @param bottom 距底部距离（vp）
   * @returns Promise，toast 显示完毕并消失后 resolve
   */
  public static showAsync(message: ToastMessage, duration?: number, bottom?: number | string): Promise<void>;

  public static async showAsync(
    messageOrOptions: ToastMessage | ToastOptions,
    duration?: number,
    bottom?: number | string
  ): Promise<void> {
    try {
      const options = Toast.normalizeParams(messageOrOptions, duration, bottom);

      // 文本校验与截断
      const text = Toast.sanitizeMessage(options.message);
      if (text === undefined) {
        hilog.warn(0x0000, TAG, 'Toast.showAsync: message is empty, ignored');
        return;
      }

      // 去重：短时间内相同内容不重复弹出
      if (Toast.shouldDedup(text)) {
        hilog.debug(0x0000, TAG, `Toast.showAsync: duplicate message "${text}" within ${Toast._dedupInterval}ms, ignored`);
        return;
      }

      // 记录最后弹出信息（用于去重）
      Toast._lastMessage = text;
      Toast._lastTime = Date.now();

      const durationMs = options.duration ?? ToastDuration.SHORT;

      // ★ 使用 openToast 而非 showToast，拿到 toastId
      const toastId: number = await promptAction.openToast({
        message: options.message,
        duration: durationMs,
        bottom: options.bottom
      });

      hilog.debug(0x0000, TAG, `Toast.showAsync: opened "${text}" (id=${toastId}, duration=${durationMs}ms)`);

      // ★ 等待 toast 显示完毕（duration 后自动消失）
      await Toast.delay(durationMs);

      hilog.debug(0x0000, TAG, `Toast.showAsync: "${text}" completed (duration=${durationMs}ms)`);
    } catch (err) {
      logError('showAsync', err);
    }
  }

  /**
   * 显示 Toast 并等待其消失，支持外部主动关闭
   * @param options Toast 配置对象
   * @returns 包含 done Promise 和 close() 方法的控制对象
   */
  public static showAsyncWithControl(options: ToastOptions): AsyncToastControl;

  /**
   * 显示 Toast 并等待其消失，支持外部主动关闭
   * @param message 显示文本
   * @param duration 显示时长（毫秒），默认 2000
   * @param bottom 距底部距离（vp）
   * @returns 包含 done Promise 和 close() 方法的控制对象
   */
  public static showAsyncWithControl(
    message: ToastMessage,
    duration?: number,
    bottom?: number | string
  ): AsyncToastControl;

  public static showAsyncWithControl(
    messageOrOptions: ToastMessage | ToastOptions,
    duration?: number,
    bottom?: number | string
  ): AsyncToastControl {
    const options = Toast.normalizeParams(messageOrOptions, duration, bottom);
    const durationMs = options.duration ?? ToastDuration.SHORT;

    let toastId: number = -1;
    let closed: boolean = false;
    let resolveDone: () => void = (): void => {
    };
    const done: Promise<void> = new Promise<void>((resolve) => {
      resolveDone = resolve;
    });

    const closeFn = (): void => {
      if (closed || toastId < 0) {
        return;
      }
      closed = true;
      try {
        promptAction.closeToast(toastId);
        hilog.debug(0x0000, TAG, `showAsyncWithControl: manually closed toast id=${toastId}`);
      } catch (err) {
        logError('closeToast', err);
      }
      resolveDone();
    };

    (async () => {
      try {
        const text = Toast.sanitizeMessage(options.message);
        if (text === undefined) {
          resolveDone();
          return;
        }
        if (Toast.shouldDedup(text)) {
          resolveDone();
          return;
        }

        Toast._lastMessage = text;
        Toast._lastTime = Date.now();

        toastId = await promptAction.openToast({
          message: options.message,
          duration: durationMs,
          bottom: options.bottom
        });

        hilog.debug(0x0000, TAG, `showAsyncWithControl: opened "${text}" (id=${toastId})`);

        await Toast.delay(durationMs);

        if (!closed) {
          closed = true;
          hilog.debug(0x0000, TAG, `showAsyncWithControl: "${text}" auto-dismissed`);
          resolveDone();
        }
      } catch (err) {
        logError('showAsyncWithControl', err);
        resolveDone();
      }
    })();

    // ★ 用 class 实例替代对象字面量
    return new AsyncToastControl(done, closeFn);
  }

  // ==================== 语义化快捷方法 ====================

  /**
   * 显示成功提示
   * @param message 显示文本
   * @param duration 显示时长，默认 SHORT
   */
  public static success(message: ToastMessage, duration?: number): void {
    Toast.show(message, duration);
  }

  /**
   * 显示错误提示
   * @param message 显示文本
   * @param duration 显示时长，默认 LONG（错误信息通常更长）
   */
  public static error(message: ToastMessage, duration?: number): void {
    Toast.show(message, duration ?? ToastDuration.LONG);
  }

  /**
   * 显示警告提示
   * @param message 显示文本
   * @param duration 显示时长，默认 LONG
   */
  public static warning(message: ToastMessage, duration?: number): void {
    Toast.show(message, duration ?? ToastDuration.LONG);
  }

  /**
   * 显示信息提示
   * @param message 显示文本
   * @param duration 显示时长，默认 SHORT
   */
  public static info(message: ToastMessage, duration?: number): void {
    Toast.show(message, duration);
  }

  // ==================== 配置方法 ====================

  /**
   * 设置去重间隔时间
   * @param ms 间隔毫秒数，设为 0 关闭去重
   */
  public static setDedupInterval(ms: number): void {
    Toast._dedupInterval = Math.max(0, ms);
  }

  // ==================== 私有方法 ====================

  /**
   * 延时工具
   */
  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  /**
   * 将多种调用签名统一为 ToastOptions
   */
  private static normalizeParams(
    messageOrOptions: ResourceStr | ToastOptions,
    duration?: number,
    bottom?: number | string
  ): ToastOptions {
    if (typeof messageOrOptions === 'string') {
      return { message: messageOrOptions, duration: duration, bottom: bottom };
    }
    const opts = messageOrOptions as ToastOptions;
    if (opts.message !== undefined) {
      return opts;
    }
    return { message: messageOrOptions as ResourceStr, duration: duration, bottom: bottom };
  }

  /**
   * 校验并截断文本
   * @param message 原始文本
   * @returns 处理后的文本，无效时返回 undefined
   */
  private static sanitizeMessage(message: ResourceStr): Optional<string> {
    if (typeof message !== 'string') {
      return 'resource';
    }

    const text = message.trim();
    if (text.length === 0) {
      return undefined;
    }

    if (text.length > MAX_MESSAGE_LENGTH) {
      hilog.warn(0x0000, TAG, `sanitizeMessage: message too long (${text.length} > ${MAX_MESSAGE_LENGTH}), truncated`);
      return text.substring(0, MAX_MESSAGE_LENGTH) + '...';
    }

    return text;
  }

  /**
   * 判断是否应被去重
   * @param text 文本内容
   * @returns true 表示应被忽略
   */
  private static shouldDedup(text: string): boolean {
    const now = Date.now();
    return (
      text === Toast._lastMessage &&
        (now - Toast._lastTime) < Toast._dedupInterval
    );
  }
}

// ==================== 类型定义（补充） ====================

/**
 * 异步 Toast 控制对象
 * ArkTS 要求对象字面量必须对应显式声明的类，故用 class 替代 interface
 */
export class AsyncToastControl {
  /** toast 完全消失后 resolve */
  readonly done: Promise<void>;
  /** 关闭函数引用（内部使用） */
  private readonly _closeFn: () => void;

  constructor(done: Promise<void>, closeFn: () => void) {
    this.done = done;
    this._closeFn = closeFn;
  }

  /** 手动关闭 toast */
  close(): void {
    this._closeFn();
  }
}

// ==================== 内部方法 ====================

/**
 * 统一的错误日志记录
 * @param operation 操作名称
 * @param error 错误对象
 */
function logError(operation: string, error: ESObject): void {
  const errorMessage = error instanceof Error
    ? error.message
    : JSON.stringify(error);
  hilog.error(0x0000, TAG, `toast ${operation} failed:: ${errorMessage}`);
}