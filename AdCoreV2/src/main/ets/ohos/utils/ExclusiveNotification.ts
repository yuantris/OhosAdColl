/**
 * 独占通知类
 * 特性：
 * 1. 支持多处监听
 * 2. 单位时间内只有一个监听者能响应（竞争模式）
 * 3. 响应后自动移除该监听者
 * 4. 未响应的监听者继续等待下次通知
 *
 * @example
 * ```typescript
 * // 创建通知实例
 * const notification = new ExclusiveNotification<string>('login', 3000);
 *
 * // 监听处A
 * notification.on((data) => {
 *   console.log('A 收到通知:', data);
 *   // 处理逻辑...
 * }, 'listener-A');
 *
 * // 监听处B
 * notification.on((data) => {
 *   console.log('B 收到通知:', data);
 *   // 处理逻辑...
 * }, 'listener-B');
 *
 * // 发送通知（只会被一个监听者响应，响应后自动移除）
 * notification.emit('登录成功');
 * ```
 */
import { LogManager } from '../helper/logger/LogManager';

export interface NotificationListener<T> {
  id: string;
  callback: (data: T) => void;
  priority?: number; // 优先级，数值越大优先级越高（可选）
}

export class ExclusiveNotification<T = any> {
  // 单例模式存储所有通知实例
  private static instances: Map<string, ExclusiveNotification<any>> = new Map();

  // 当前通知的标识符
  private readonly name: string;

  // 单位时间阈值（毫秒），默认1000ms
  private readonly throttleTime: number;

  // 所有监听者列表
  private listeners: Map<string, NotificationListener<T>> = new Map();

  // 最后一次通知时间
  private lastEmitTime: number = 0;

  // 最后一次响应的监听者ID
  private lastResponderId: string | null = null;

  // 最后一次响应的时间
  private lastResponseTime: number = 0;

  /**
   * 创建或获取通知实例（单例模式）
   * @param name 通知名称（唯一标识）
   * @param throttleTime 节流时间（毫秒），默认1000ms
   * @returns ExclusiveNotification实例
   */
  static getInstance<T>(name: string, throttleTime: number = 1000): ExclusiveNotification<T> {
    if (!this.instances.has(name)) {
      this.instances.set(name, new ExclusiveNotification<T>(name, throttleTime));
    }
    return this.instances.get(name) as ExclusiveNotification<T>;
  }

  /**
   * 移除指定名称的通知实例
   * @param name 通知名称
   */
  static removeInstance(name: string): void {
    const instance = this.instances.get(name);
    if (instance) {
      instance.removeAllListeners();
      this.instances.delete(name);
    }
  }

  /**
   * 构造函数
   * @param name 通知名称
   * @param throttleTime 节流时间（毫秒）
   */
  private constructor(name: string, throttleTime: number) {
    this.name = name;
    this.throttleTime = throttleTime;
  }

  /**
   * 添加监听者
   * @param callback 回调函数，返回true表示已处理（用于响应），返回false表示未处理
   * @param id 监听者唯一标识（不传则自动生成）
   * @param priority 优先级，数值越大优先级越高（可选）
   * @returns 取消监听的函数
   */
  on(callback: (data: T) => void, id?: string, priority?: number): () => void {
    const listenerId = id || `${this.name}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    this.listeners.set(listenerId, {
      id: listenerId,
      callback,
      priority
    });

    // 返回取消监听的函数
    return () => this.off(listenerId);
  }

  /**
   * 移除指定监听者
   * @param id 监听者ID
   */
  off(id: string): void {
    this.listeners.delete(id);
  }

  /**
   * 移除所有监听者
   */
  removeAllListeners(): void {
    this.listeners.clear();
    this.lastResponderId = null;
    this.lastResponseTime = 0;
  }

  /**
   * 发送通知
   * @param data 通知数据
   * @param force 是否强制发送（忽略节流时间）
   * @returns 是否成功触发某个监听者
   */
  emit(data: T, force: boolean = false): boolean {
    const now = Date.now();

    // 检查是否在节流时间内
    if (!force && this.lastResponderId && (now - this.lastResponseTime) < this.throttleTime) {
      return false;
    }

    // 按优先级排序监听者
    const sortedListeners = Array.from(this.listeners.values())
      .sort((a, b) => (b.priority || 0) - (a.priority || 0));

    // 记录最后发送时间
    this.lastEmitTime = now;

    // 遍历监听者，找到第一个能响应的
    for (const listener of sortedListeners) {
      try {
        // 调用回调
        listener.callback(data);

        // 标记该监听者已响应
        this.lastResponderId = listener.id;
        this.lastResponseTime = now;

        // 移除已响应的监听者
        this.listeners.delete(listener.id);

        return true; // 已成功触发
      } catch (e) {
        LogManager.error('ExclusiveNotification', `Listener ${listener.id} error, name=${this.name}`, e);
        // 继续尝试下一个监听者
        continue;
      }
    }

    return false; // 没有监听者被触发
  }

  /**
   * 发送异步通知
   * @param data 通知数据
   * @param force 是否强制发送（忽略节流时间）
   * @returns Promise<boolean> 是否成功触发某个监听者
   */
  async emitAsync(data: T, force: boolean = false): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        const result = this.emit(data, force);
        resolve(result);
      } catch (e) {
        LogManager.error('ExclusiveNotification', `Async emit error, name=${this.name}`, e);
        resolve(false);
      }
    });
  }

  /**
   * 检查是否有监听者
   */
  hasListeners(): boolean {
    return this.listeners.size > 0;
  }

  /**
   * 获取监听者数量
   */
  getListenerCount(): number {
    return this.listeners.size;
  }

  /**
   * 获取最后一次响应的监听者ID
   */
  getLastResponderId(): string | null {
    return this.lastResponderId;
  }

  /**
   * 获取最后一次响应的时间戳
   */
  getLastResponseTime(): number {
    return this.lastResponseTime;
  }

  /**
   * 检查是否在节流时间内
   */
  isThrottled(): boolean {
    if (!this.lastResponderId) {
      return false;
    }
    return (Date.now() - this.lastResponseTime) < this.throttleTime;
  }

  /**
   * 重置状态（清除节流和响应记录）
   */
  reset(): void {
    this.lastResponderId = null;
    this.lastResponseTime = 0;
    this.lastEmitTime = 0;
  }

  /**
   * 获取通知名称
   */
  getName(): string {
    return this.name;
  }

  /**
   * 获取节流时间
   */
  getThrottleTime(): number {
    return this.throttleTime;
  }
}

/**
 * 便捷函数：创建或获取通知实例
 */
export function createNotification<T>(name: string, throttleTime: number = 1000): ExclusiveNotification<T> {
  return ExclusiveNotification.getInstance<T>(name, throttleTime);
}

/**
 * 便捷函数：移除通知实例
 */
export function removeNotification(name: string): void {
  ExclusiveNotification.removeInstance(name);
}
