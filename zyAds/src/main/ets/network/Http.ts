// RemoteHttp.ts
import { rcp } from '@kit.RemoteCommunicationKit';
import { LogInterceptor } from './intercept/LogInterceptor';

export class Http {
  private static session: rcp.Session;

  static init(cfg?: rcp.SessionConfiguration) {
    const requestConfig: rcp.Configuration = {
      transfer: {
        timeout: {
          connectMs: 5000,
          transferMs: 5000
        },
      }
    }
    const defaultCfg: rcp.SessionConfiguration = {
      requestConfiguration: requestConfig,
      interceptors: [new LogInterceptor()]    // 全局日志拦截
    };
    Http.session = rcp.createSession(cfg ?? defaultCfg);
  }

  static getInstance() {
    return Http.session;
  }
}

export default Http