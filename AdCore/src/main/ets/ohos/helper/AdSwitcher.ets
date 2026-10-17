import { Provider } from '../components/AdLayout';
import { AD } from '../config/AD';
import { ADHelper } from './ADHelper';


export function isAdAvailable(p: Provider) {
  if (AD.zyOff) {
    return AD.zyOff.ss.includes(p.toString())
  }
  return false
}

export class AdSwitcher {
  static readonly TAG = 'AdSwitcher';

  public static aa() {
    if (AD.zyOff) {
      const adMode = ADHelper.getADMode(AD.zyOff)


    }

  }

  public static isAdAvailable(type: Provider) {
    if (AD.zyOff) {
      const ss = AD.zyOff.ss.split(',')
      let typeStr = type.toString()
      return ss.includes(typeStr)
    }
    return false
  }
}