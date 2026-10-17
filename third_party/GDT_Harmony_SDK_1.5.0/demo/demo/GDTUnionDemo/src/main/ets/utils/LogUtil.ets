import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'GDT_AD_DEMO';

export class LogUtil {
  public static debug(msg: string): void {
    hilog.debug(DOMAIN, TAG, msg);
  }

  public static info(msg: string): void {
    hilog.info(DOMAIN, TAG, msg);
  }

  public static warn(msg: string): void {
    hilog.warn(DOMAIN, TAG, msg);
  }

  public static error(msg: string): void {
    hilog.error(DOMAIN, TAG, msg);
  }

  public static fatal(msg: string): void {
    hilog.fatal(DOMAIN, TAG, msg);
  }
}
