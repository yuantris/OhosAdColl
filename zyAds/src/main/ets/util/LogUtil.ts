/**
 * 日志工具类 - 提供统一的日志输出和管理功能
 * 支持不同级别的日志输出，便于调试和生产环境使用
 */
export class LogUtil {
  /**
   * 日志级别枚举
   */
  private static readonly LogLevel = {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3
  } as const;

  /**
   * 当前日志级别
   * 开发环境建议设置为DEBUG，生产环境建议设置为WARN或ERROR
   */
  private static currentLogLevel: number = LogUtil.LogLevel.DEBUG;

  /**
   * 默认日志标签
   */
  private static readonly DEFAULT_TAG = 'zyAds_';

  /**
   * 设置日志级别
   * @param level 日志级别字符串
   */
  public static setLogLevel(level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR'): void {
    const levelMap = {
      'DEBUG': LogUtil.LogLevel.DEBUG,
      'INFO': LogUtil.LogLevel.INFO,
      'WARN': LogUtil.LogLevel.WARN,
      'ERROR': LogUtil.LogLevel.ERROR
    };
    LogUtil.currentLogLevel = levelMap[level] || LogUtil.LogLevel.INFO;
  }

  /**
   * 获取当前时间戳字符串
   * @returns 格式化的时间字符串
   */
  private static getTimeStamp(): string {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const seconds = now.getSeconds().toString().padStart(2, '0');
    const milliseconds = now.getMilliseconds().toString().padStart(3, '0');
    return `${hours}:${minutes}:${seconds}.${milliseconds}`;
  }

  /**
   * 格式化日志消息
   * @param level 日志级别
   * @param tag 日志标签
   * @param message 日志消息
   * @param optionalParams 可选参数
   * @returns 格式化后的日志字符串
   */
  private static formatMessage(
    level: string,
    tag: string,
    message: string,
    optionalParams: any[]
  ): string {
    const timeStamp = LogUtil.getTimeStamp();
    const formattedMessage = `[${timeStamp}] ${level}/${tag}: ${message}`;

    if (optionalParams.length > 0) {
      const paramsString = optionalParams.map(param =>
      typeof param === 'object' ? JSON.stringify(param, null, 2) : String(param)
      ).join(', ');
      return `${formattedMessage} ${paramsString}`;
    }

    return formattedMessage;
  }

  /**
   * 调试日志（带标签）
   * @param tag 日志标签
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static debug(tag: string, message: string, ...optionalParams: any[]): void;

  /**
   * 调试日志（使用默认标签）
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static debug(message: string, ...optionalParams: any[]): void;

  /**
   * 调试日志实现
   */
  public static debug(tagOrMessage: string, messageOrFirstParam?: string | any, ...optionalParams: any[]): void {
    let tag: string;
    let message: string;
    let params: any[];

    if (messageOrFirstParam === undefined || typeof messageOrFirstParam === 'string') {
      // 第一种调用方式：debug(message, ...params)
      tag = LogUtil.DEFAULT_TAG;
      message = tagOrMessage;
      params = messageOrFirstParam ? [messageOrFirstParam, ...optionalParams] : optionalParams;
    } else {
      // 第二种调用方式：debug(tag, message, ...params)
      tag = tagOrMessage;
      message = messageOrFirstParam as string;
      params = optionalParams;
    }

    if (LogUtil.currentLogLevel <= LogUtil.LogLevel.DEBUG) {
      const formattedMessage = LogUtil.formatMessage('DEBUG', tag, message, params);
      console.debug(formattedMessage);
    }
  }

  /**
   * 信息日志（带标签）
   * @param tag 日志标签
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static info(tag: string, message: string, ...optionalParams: any[]): void;

  /**
   * 信息日志（使用默认标签）
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static info(message: string, ...optionalParams: any[]): void;

  /**
   * 信息日志实现
   */
  public static info(tagOrMessage: string, messageOrFirstParam?: string | any, ...optionalParams: any[]): void {
    let tag: string;
    let message: string;
    let params: any[];

    if (messageOrFirstParam === undefined || typeof messageOrFirstParam === 'string') {
      // 第一种调用方式：info(message, ...params)
      tag = LogUtil.DEFAULT_TAG;
      message = tagOrMessage;
      params = messageOrFirstParam ? [messageOrFirstParam, ...optionalParams] : optionalParams;
    } else {
      // 第二种调用方式：info(tag, message, ...params)
      tag = tagOrMessage;
      message = messageOrFirstParam as string;
      params = optionalParams;
    }

    if (LogUtil.currentLogLevel <= LogUtil.LogLevel.INFO) {
      const formattedMessage = LogUtil.formatMessage('INFO', tag, message, params);
      console.info(formattedMessage);
    }
  }

  /**
   * 警告日志（带标签）
   * @param tag 日志标签
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static warn(tag: string, message: string, ...optionalParams: any[]): void;

  /**
   * 警告日志（使用默认标签）
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static warn(message: string, ...optionalParams: any[]): void;

  /**
   * 警告日志实现
   */
  public static warn(tagOrMessage: string, messageOrFirstParam?: string | any, ...optionalParams: any[]): void {
    let tag: string;
    let message: string;
    let params: any[];

    if (messageOrFirstParam === undefined || typeof messageOrFirstParam === 'string') {
      // 第一种调用方式：warn(message, ...params)
      tag = LogUtil.DEFAULT_TAG;
      message = tagOrMessage;
      params = messageOrFirstParam ? [messageOrFirstParam, ...optionalParams] : optionalParams;
    } else {
      // 第二种调用方式：warn(tag, message, ...params)
      tag = tagOrMessage;
      message = messageOrFirstParam as string;
      params = optionalParams;
    }

    if (LogUtil.currentLogLevel <= LogUtil.LogLevel.WARN) {
      const formattedMessage = LogUtil.formatMessage('WARN', tag, message, params);
      console.warn(formattedMessage);
    }
  }

  /**
   * 错误日志（带标签）
   * @param tag 日志标签
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static error(tag: string, message: string, ...optionalParams: any[]): void;

  /**
   * 错误日志（使用默认标签）
   * @param message 日志消息
   * @param optionalParams 可选参数
   */
  public static error(message: string, ...optionalParams: any[]): void;

  /**
   * 错误日志实现
   */
  public static error(tagOrMessage: string, messageOrFirstParam?: string | any, ...optionalParams: any[]): void {
    let tag: string;
    let message: string;
    let params: any[];

    if (messageOrFirstParam === undefined || typeof messageOrFirstParam === 'string') {
      // 第一种调用方式：error(message, ...params)
      tag = LogUtil.DEFAULT_TAG;
      message = tagOrMessage;
      params = messageOrFirstParam ? [messageOrFirstParam, ...optionalParams] : optionalParams;
    } else {
      // 第二种调用方式：error(tag, message, ...params)
      tag = tagOrMessage;
      message = messageOrFirstParam as string;
      params = optionalParams;
    }

    if (LogUtil.currentLogLevel <= LogUtil.LogLevel.ERROR) {
      const formattedMessage = LogUtil.formatMessage('ERROR', tag, message, params);
      console.error(formattedMessage);
    }
  }

  /**
   * 断言日志 - 当条件为false时记录错误日志（带标签）
   * @param tag 日志标签
   * @param condition 断言条件
   * @param message 错误消息
   */
  public static assert(tag: string, condition: boolean, message: string): void;

  /**
   * 断言日志 - 当条件为false时记录错误日志（使用默认标签）
   * @param condition 断言条件
   * @param message 错误消息
   */
  public static assert(condition: boolean, message: string): void;

  /**
   * 断言日志实现
   */
  public static assert(tagOrCondition: string | boolean, conditionOrMessage: boolean | string, message?: string): void {
    let tag: string;
    let condition: boolean;
    let msg: string;

    if (typeof tagOrCondition === 'boolean') {
      // 第一种调用方式：assert(condition, message)
      tag = LogUtil.DEFAULT_TAG;
      condition = tagOrCondition;
      msg = conditionOrMessage as string;
    } else {
      // 第二种调用方式：assert(tag, condition, message)
      tag = tagOrCondition;
      condition = conditionOrMessage as boolean;
      msg = message!;
    }

    if (!condition) {
      LogUtil.error(tag, `ASSERT FAILED: ${msg}`);
    }
  }

  /**
   * 性能计时器（带标签）
   * @param tag 日志标签
   * @param label 计时器标签
   * @returns 返回一个函数，调用该函数记录耗时
   */
  public static timer(tag: string, label: string): () => void;

  /**
   * 性能计时器（使用默认标签）
   * @param label 计时器标签
   * @returns 返回一个函数，调用该函数记录耗时
   */
  public static timer(label: string): () => void;

  /**
   * 性能计时器实现
   */
  public static timer(tagOrLabel: string, label?: string): () => void {
    let tag: string;
    let timerLabel: string;

    if (label === undefined) {
      // 第一种调用方式：timer(label)
      tag = LogUtil.DEFAULT_TAG;
      timerLabel = tagOrLabel;
    } else {
      // 第二种调用方式：timer(tag, label)
      tag = tagOrLabel;
      timerLabel = label;
    }

    const startTime = Date.now();
    LogUtil.info(tag, `Timer started: ${timerLabel}`);

    return (): void => {
      const duration = Date.now() - startTime;
      LogUtil.info(tag, `Timer ended: ${timerLabel}`, `耗时: ${duration}ms`);
    };
  }

  /**
   * 记录异常信息（带标签）
   * @param tag 日志标签
   * @param error 错误对象
   * @param context 上下文信息
   */
  public static logError(tag: string, error: Error, context?: string): void;

  /**
   * 记录异常信息（使用默认标签）
   * @param error 错误对象
   * @param context 上下文信息
   */
  public static logError(error: Error, context?: string): void;

  /**
   * 记录异常信息实现
   */
  public static logError(tagOrError: string | Error, errorOrContext?: Error | string, context?: string): void {
    let tag: string;
    let error: Error;
    let ctx: string | undefined;

    if (tagOrError instanceof Error) {
      // 第一种调用方式：logError(error, context)
      tag = LogUtil.DEFAULT_TAG;
      error = tagOrError;
      ctx = errorOrContext as string | undefined;
    } else {
      // 第二种调用方式：logError(tag, error, context)
      tag = tagOrError;
      error = errorOrContext as Error;
      ctx = context;
    }

    const errorMessage = {
      message: error.message,
      stack: error.stack,
      context: ctx || '无上下文信息'
    };

    LogUtil.error(tag, '捕获到异常', errorMessage);
  }
}

/**
 * 日志标签常量定义
 * 用于统一管理各个模块的日志标签
 */
export class LogTags {
  public static readonly HTTP = 'HttpClient';
  public static readonly GZIP = 'GzipUtil';
  public static readonly SDK = 'ZyAdSdk';
  public static readonly CONFIG = 'Config';
  public static readonly TRACKER = 'Tracker';
  public static readonly CACHE = 'Cache';
}