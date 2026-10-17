import { urpc } from '@kit.RemoteCommunicationKit';
import { ZyHttpError, toZyHttpError } from '../error/ZyHttpError';

/**
 * URPC 连接配置(映射官方 urpc.UrpcInitConfiguration)
 * URPC(Unified Remote Procedure Call): 高性能 RPC 通信库, 具有抗弱网传输、多径传输(蜂窝+Wi-Fi)特性
 * 官方约束: 需配合部署远程服务器; 支持 Phone/2in1/Tablet/Wearable, 5.1.1(19) 起支持 TV
 * 官方字面量约束: mode 仅支持 'client'; protocol 仅支持 'eat'
 */
export interface ZyUrpcConfig {
  /** 超时(ms, 官方示例 3000; 官方标注为预留字段, 当前版本不生效) */
  timeout?: number;
  /** 运行模式(官方 UrpcMode 字面量, 当前仅 'client') */
  mode?: 'client';
  /** 远程服务器地址 */
  ip: string;
  /** 远程服务器端口 */
  port: number;
  /** 传输协议(官方 UrpcProtocol 字面量, 当前仅 'eat') */
  protocol?: 'eat';
  /** 远程方法名列表(funcList, 官方 urpcStubCreate 第二参数) */
  funcList: string[];
}

/**
 * URPC 客户端封装(官方 urpc.urpcStubCreate / UrpcStub.call / cancel / destroy)
 * 生命周期: create(连接) → call/cancel(调用/取消) → destroy(释放资源)
 * call 返回官方 UrpcPromise 原始句柄(含 callingId), 调用方 await .promise 取响应、
 * 持 .callingId 可定向 cancel; 需要自动错误标准化时使用 callAsync
 */
export class ZyUrpc {
  private stub?: urpc.UrpcStub;

  /**
   * 创建 URPC Stub 并连接远程服务器
   * @param config 连接配置
   * @throws ZyHttpError 连接失败(底层 BusinessError 经 toZyHttpError 标准化)
   */
  async create(config: ZyUrpcConfig): Promise<void> {
    try {
      const node: urpc.IpAndPort = { ip: config.ip, port: config.port };
      const connect: urpc.UrpcConnectConfiguration = {
        node: node,
        protocol: config.protocol ?? 'eat'
      };
      const initConfig: urpc.UrpcInitConfiguration = {
        timeout: config.timeout ?? 3000,
        mode: config.mode ?? 'client',
        connect: connect
      };
      const stubPromise: Promise<urpc.UrpcStub> = urpc.urpcStubCreate(initConfig, config.funcList);
      this.stub = await stubPromise;
    } catch (err) {
      throw toZyHttpError(err);
    }
  }

  /**
   * 发起远程调用(官方 UrpcStub.call, 返回原始 UrpcPromise 句柄)
   * @param method 远程方法名(需在 funcList 中)
   * @param request 请求消息对象(FlowbufElement 结构, 由调用方定义)
   * @param response 响应消息对象(接收返回值)
   * @param priority 调用优先级(官方 CallingOption.priority, 0~3, 官方标注预留字段)
   * @returns 官方 UrpcPromise(访问 .callingId 用于定向取消, await .promise 取响应)
   * @throws ZyHttpError 未连接时抛出
   */
  call(method: string, request: object, response: object, priority: number = 0): urpc.UrpcPromise {
    const stub = this.stub;
    if (stub === undefined) {
      throw new ZyHttpError('unknown', 'URPC 未连接, 请先调用 create()', false);
    }
    const option: urpc.CallingOption = { priority: priority };
    // 官方 UrpcCall: (funcName: string, request: object, returnValue: object, config?: CallingOption) => UrpcPromise
    return stub.call(method, request, response, option);
  }

  /**
   * 发起远程调用并等待响应(call 的 await 版, 错误经 toZyHttpError 标准化)
   * @param method 远程方法名(需在 funcList 中)
   * @param request 请求消息对象
   * @param response 响应消息对象(接收返回值)
   * @param priority 调用优先级(0~3)
   * @returns 远程响应对象
   * @throws ZyHttpError 未连接或调用失败
   */
  async callAsync(method: string, request: object, response: object, priority: number = 0): Promise<object> {
    const calling: urpc.UrpcPromise = this.call(method, request, response, priority);
    try {
      return await calling.promise;
    } catch (err) {
      throw toZyHttpError(err);
    }
  }

  /**
   * 取消指定调用(官方 UrpcCancel: callingId 为 number | number[]); 不传则取消全部
   * @param callingId 调用 ID(call 返回的 UrpcPromise.callingId, 取值范围 [0, 2147483647])
   * @throws ZyHttpError 取消失败
   */
  cancel(callingId?: number | number[]): void {
    const stub = this.stub;
    if (stub === undefined) {
      return;
    }
    try {
      if (callingId !== undefined) {
        stub.cancel(callingId);
      } else {
        stub.cancel();
      }
    } catch (err) {
      throw toZyHttpError(err);
    }
  }

  /**
   * 销毁 Stub 并释放 URPC 资源(官方 UrpcStub.destroy, 请求完成后必须调用)
   */
  destroy(): void {
    const stub = this.stub;
    if (stub === undefined) {
      return;
    }
    try {
      stub.destroy();
    } catch (err) {
      // 忽略销毁异常(官方要求请求完成后释放, 重复销毁可能抛错)
    }
    this.stub = undefined;
  }
}
