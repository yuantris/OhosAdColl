import { rcp } from "@kit.RemoteCommunicationKit";

// LogInterceptor.ts
export class LogInterceptor implements rcp.Interceptor {
  async intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response> {
    const request = context.request
    console.info(`[HTTP] ${request.method} ${request.url}`);
    const t0 = Date.now();
    const response = await next.handle(context)
    console.info(`[HTTP] ${response.toString()} in ${Date.now() - t0}ms`);
    return response;
  }
}