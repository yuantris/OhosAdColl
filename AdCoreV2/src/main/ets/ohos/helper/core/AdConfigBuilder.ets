import { AdIdStore } from './AdIdStore';
import { LogManager } from '../logger/LogManager';

export class AdConfigBuilder {
  private static readonly TAG = 'AdConfigBuilder';

  setCSJ_APPID(appid: string): AdConfigBuilder {
    AdIdStore.CSJ_APPID = appid;
    return this;
  }

  setCSJ_SPLASH_ID(splashId: string): AdConfigBuilder {
    AdIdStore.CSJ_SPLASH_ID = splashId;
    return this;
  }

  setCSJ_VIDEO_ID(id: string): AdConfigBuilder {
    AdIdStore.CSJ_VIDEO_ID = id;
    return this;
  }

  setCSJ_INFO_ID(id: string): AdConfigBuilder {
    AdIdStore.CSJ_INFO_ID = id;
    return this;
  }

  setCSJ_INFO_LEFT_ID(id: string): AdConfigBuilder {
    AdIdStore.CSJ_INFO_LEFT_ID = id;
    return this;
  }

  setCSJ_INFO_NATIVE_ID(id: string): AdConfigBuilder {
    AdIdStore.CSJ_INFO_NATIVE_ID = id;
    return this;
  }

  setCSJ_SCREEN_ID(id: string): AdConfigBuilder {
    AdIdStore.CSJ_SCREEN_ID = id
    return this;
  }

  setTX_APPID(id: string): AdConfigBuilder {
    AdIdStore.TX_APP_ID = id
    return this;
  }

  setTX_SPLASH_DEFAULT_POS_ID(id: string): AdConfigBuilder {
    AdIdStore.TX_SPLASH_DEFAULT_POS_ID = id
    return this;
  }

  setTX_REWARD_DEFAULT_POS_ID(id: string): AdConfigBuilder {
    AdIdStore.TX_REWARD_DEFAULT_POS_ID = id
    return this;
  }

  setTX_MANUAL_DEFAULT_POS_ID(id: string): AdConfigBuilder {
    AdIdStore.TX_MANUAL_DEFAULT_POS_ID = id
    return this;
  }

  setTX_MANUAL_DEFAULT_LEFT_POS_ID(id: string): AdConfigBuilder {
    AdIdStore.TX_MANUAL_DEFAULT_LEFT_POS_ID = id
    return this;
  }

  setTX_INTERSTITIAL_DEFAULT_POS_ID(id: string): AdConfigBuilder {
    AdIdStore.TX_INTERSTITIAL_DEFAULT_POS_ID = id
    return this;
  }

  setHW_SPLASH_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_SPLASH_ID = id
    return this;
  }

  setHW_SCREEN_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_SCREEN_ID = id
    return this;
  }

  setHW_VIDEO_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_VIDEO_ID = id
    return this;
  }

  setHW_INFO_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_INFO_ID = id
    return this;
  }

  setHW_INFO_LEFT_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_INFO_LEFT_ID = id
    return this;
  }

  setHW_INFO_NATIVE_ID(id: string): AdConfigBuilder {
    AdIdStore.HW_INFO_NATIVE_ID = id
    return this;
  }
}
