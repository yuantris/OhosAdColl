import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 日志级别枚举
 */
export enum LogLevel {
  /**
   * 调试级别 - 详细的调试信息
   */
  DEBUG = 0,
  /**
   * 信息级别 - 普通信息
   */
  INFO = 1,
  /**
   * 警告级别 - 警告信息
   */
  WARN = 2,
  /**
   * 错误级别 - 错误信息
   */
  ERROR = 3,
  /**
   * 关闭日志 - 不输出任何日志
   */
  OFF = 4
}

/**
 * 内存日志条目（供调试悬浮球「日志」面板展示，与 hilog 输出同源同文）
 */
export interface LogEntry {
  readonly level: LogLevel;
  readonly tag: string;
  readonly message: string;
  readonly timestamp: number;
}

/** 日志变更监听器（新日志产生时同步回调） */
export type LogListener = (entry: LogEntry) => void;

/**
 * 日志管理工具类
 * 统一管理AdCoreV2模块的日志输出
 *
 * 输出通道：系统 hilog（环形缓冲区，不依赖 JS console 桥接，避免异步/高频场景丢日志）
 * - hilog TAG 字段 = 业务 TAG（即文件名），可用 `hdc shell hilog | grep 文件名` 直接定位日志来源
 * - 消息体统一带 'AdCoreLog' 前缀，标识来自 AdCore SDK
 * - DOMAIN 固定 0x0123；debug 级别遵循系统规则默认不输出（`hdc shell hilog -b D` 打开）
 */
export class LogManager {
  /**
   * 消息前缀，标识日志来源为 AdCore SDK
   */
  private static readonly TAG = 'AdCoreLog';

  /**
   * hilog domain，与 SDK 内其他日志保持一致
   */
  private static readonly DOMAIN = 0x0123;

  /**
   * 当前日志级别
   */
  private static currentLevel: LogLevel = LogLevel.INFO;

  /**
   * 内存日志环形缓冲区（仅存最近 N 条，供调试悬浮球展示）
   */
  private static logEntries: LogEntry[] = [];

  /**
   * 内存日志最大条数
   */
  private static readonly MAX_LOG_ENTRIES = 300;

  /**
   * 日志变更监听器集合
   */
  private static logListeners: Set<LogListener> = new Set();

  /**
   * 设置日志级别
   * @param level 日志级别
   */
  public static setLogLevel(level: LogLevel): void {
    this.currentLevel = level;
    this.log(LogLevel.INFO, this.TAG, `Log level set to ${LogLevel[level]}`);
  }

  /**
   * 获取当前日志级别
   * @returns 当前日志级别
   */
  public static getLogLevel(): LogLevel {
    return this.currentLevel;
  }

  /**
   * 获取内存中的日志条目（最新在前）
   * @returns 日志条目数组
   */
  public static getLogEntries(): LogEntry[] {
    return this.logEntries;
  }

  /**
   * 按级别过滤日志条目（最新在前）
   * @param minLevel 最低级别，null 表示全部
   * @returns 过滤后的日志条目数组
   */
  public static getLogEntriesByLevel(minLevel: LogLevel | null): LogEntry[] {
    if (minLevel === null) {
      return this.logEntries;
    }
    return this.logEntries.filter((entry: LogEntry) => entry.level >= minLevel);
  }

  /**
   * 清空内存日志缓冲区
   */
  public static clearLogEntries(): void {
    this.logEntries = [];
  }

  /**
   * 注册日志变更监听器
   * @param listener 监听器
   */
  public static addLogListener(listener: LogListener): void {
    this.logListeners.add(listener);
  }

  /**
   * 移除日志变更监听器
   * @param listener 监听器
   */
  public static removeLogListener(listener: LogListener): void {
    this.logListeners.delete(listener);
  }

  /**
   * 将一条日志写入内存缓冲区并通知监听器（在 log() 输出 hilog 后调用）
   */
  private static captureEntry(level: LogLevel, tag: string, message: string): void {
    // 单条上限，避免 Error.stack 等超长文本占用过多内存
    const text = message.length > 800 ? `${message.substring(0, 800)}…` : message;
    const entry: LogEntry = {
      level: level,
      tag: tag,
      message: text,
      timestamp: Date.now()
    };
    this.logEntries.unshift(entry);
    if (this.logEntries.length > LogManager.MAX_LOG_ENTRIES) {
      this.logEntries.pop();
    }
    this.logListeners.forEach((listener: LogListener) => {
      try {
        listener(entry);
      } catch (e) {
        // 监听器异常不得影响日志主链路
      }
    });
  }

  /**
   * 输出调试日志
   * @param tag 日志标签
   * @param message 日志消息
   * @param args 可变参数
   */
  public static debug(tag: string, message: string, ...args: any[]): void {
    if (this.currentLevel <= LogLevel.DEBUG) {
      this.log(LogLevel.DEBUG, tag, message, args);
    }
  }

  /**
   * 输出信息日志
   * @param tag 日志标签
   * @param message 日志消息
   * @param args 可变参数
   */
  public static info(tag: string, message: string, ...args: any[]): void {
    if (this.currentLevel <= LogLevel.INFO) {
      this.log(LogLevel.INFO, tag, message, args);
    }
  }

  /**
   * 输出警告日志
   * @param tag 日志标签
   * @param message 日志消息
   * @param args 可变参数
   */
  public static warn(tag: string, message: string, ...args: any[]): void {
    if (this.currentLevel <= LogLevel.WARN) {
      this.log(LogLevel.WARN, tag, message, args);
    }
  }

  /**
   * 输出错误日志
   * @param tag 日志标签
   * @param message 日志消息
   * @param args 可变参数
   */
  public static error(tag: string, message: string, ...args: any[]): void {
    if (this.currentLevel <= LogLevel.ERROR) {
      this.log(LogLevel.ERROR, tag, message, args);
    }
  }

  /**
   * 序列化附加参数
   * Error 对象提取 name/message/stack（避免 JSON.stringify 序列化成 {} 丢失关键信息），
   * 其余对象走 JSON.stringify，失败时降级 String()
   * @param args 可变参数
   * @returns 拼接好的附加串（首字符为空格），无参数时返回空串
   */
  private static serializeArgs(args: any[]): string {
    if (!args || args.length === 0) {
      return '';
    }
    const parts = args.map((arg: any): string => {
      if (arg instanceof Error) {
        return `${arg.name}: ${arg.message}${arg.stack ? `\n${arg.stack}` : ''}`;
      }
      try {
        return JSON.stringify(arg);
      } catch (e) {
        return String(arg);
      }
    });
    return ' ' + parts.join(' ');
  }

  /**
   * 实际日志输出方法（hilog 通道）
   * @param level 日志级别
   * @param tag 日志标签（文件名）
   * @param message 日志消息
   * @param args 可变参数
   */
  private static log(level: LogLevel, tag: string, message: string, args: any[] = []): void {
    const formattedMessage = `${message} ${LogManager.serializeArgs(args)}`;

    // %{public}s 保证内容明文输出，不被隐私脱敏
    switch (level) {
      case LogLevel.DEBUG:
        hilog.debug(LogManager.DOMAIN, `${LogManager.TAG}_${tag}`, '%{public}s', formattedMessage);
        break;
      case LogLevel.INFO:
        hilog.info(LogManager.DOMAIN, `${LogManager.TAG}_${tag}`, '%{public}s', formattedMessage);
        break;
      case LogLevel.WARN:
        hilog.warn(LogManager.DOMAIN, `${LogManager.TAG}_${tag}`, '%{public}s', formattedMessage);
        break;
      case LogLevel.ERROR:
        hilog.error(LogManager.DOMAIN, `${LogManager.TAG}_${tag}`, '%{public}s', formattedMessage);
        break;
      default:
        break;
    }

    // 同步写入内存缓冲区，供调试悬浮球「日志」面板展示
    LogManager.captureEntry(level, tag, formattedMessage);
  }
}
