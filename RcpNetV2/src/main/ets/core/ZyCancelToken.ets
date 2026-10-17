import { ZyHttpError } from '../error/ZyHttpError';

/**
 * 取消令牌(现代句柄式取消, 类似 AbortController 语义)
 * 使用方式:
 *   const token = new ZyCancelToken();
 *   const task = http.newBuilder().cancelToken(token).path('/big').get();  // 发起
 *   token.cancel();                                                        // 随时取消
 *   await task;                                                            // 抛出 ZyHttpError(kind='cancel')
 *
 * 底层机制: ZyHttp 在请求发出后把"取消回调"注册进令牌; cancel() 触发全部回调
 * (回调内调用官方 session.cancel(request)), 令牌与请求解耦, 可一令牌绑多个请求
 */
export class ZyCancelToken {
  private cancelled: boolean = false;
  private actions: Array<() => void> = new Array<() => void>();

  /**
   * 是否已被取消
   */
  isCancelled(): boolean {
    return this.cancelled;
  }

  /**
   * 取消关联的全部请求(幂等: 重复调用无副作用)
   * 取消后由底层抛出官方取消类错误码, 经 toZyHttpError 标准化为 kind='cancel'
   */
  cancel(): void {
    if (this.cancelled) {
      return;
    }
    this.cancelled = true;
    const actions = this.actions;
    this.actions = new Array<() => void>();
    for (const action of actions) {
      try {
        action();
      } catch (err) {
        // 忽略单个取消回调异常(请求可能已完成, 底层 cancel 抛错属正常现象)
      }
    }
  }

  /**
   * 注册取消回调(内部 API: 由 ZyHttp 在请求发出时调用)
   * @param action 取消动作
   */
  register(action: () => void): void {
    // 注册前已取消: 立即执行回调(避免取消动作丢失)
    if (this.cancelled) {
      try {
        action();
      } catch (err) {
        // 忽略立即执行时的异常
      }
      return;
    }
    this.actions.push(action);
  }

  /**
   * 注销取消回调(请求正常结束后调用, 防止 actions 无限累积)
   * @param action 注册时传入的回调引用
   */
  unregister(action: () => void): void {
    const index: number = this.actions.indexOf(action);
    if (index >= 0) {
      this.actions.splice(index, 1);
    }
  }

  /**
   * 构建标准取消错误(供 ZyHttp 在"已取消令牌发起新请求"时快速失败)
   * @returns kind='cancel' 的标准错误
   */
  static cancelledError(): ZyHttpError {
    return new ZyHttpError('cancel', '请求已被取消(cancelToken)', false);
  }
}
