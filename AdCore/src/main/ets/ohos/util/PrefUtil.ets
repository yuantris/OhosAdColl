import preferences from '@ohos.data.preferences';
import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

export class PrefUtil {
  private constructor() {
  }

  private static defaultPreferenceName: string = "SP_ZY_HARMONY_PREFERENCES";
  private static preferences: preferences.Preferences;
  private static context: Context = getContext() as common.UIAbilityContext

  /**
   * 初始化
   * @param name Preferences实例的名称。
   */
  static init(preferenceName: string, context?: Context) {
    PrefUtil.context = context || getContext() as common.UIAbilityContext
    if (!PrefUtil.preferences || preferenceName !== PrefUtil.defaultPreferenceName) {
      PrefUtil.defaultPreferenceName = preferenceName;
      PrefUtil.preferences = dataPreferences.getPreferencesSync(PrefUtil.context, { name: preferenceName });
    }
  }


  /**
   * 获取Preferences实例
   * @param name
   * @returns
   */
  private static getPreferencesSync(preferenceName: string = PrefUtil.defaultPreferenceName): preferences.Preferences {
    if (preferenceName !== PrefUtil.defaultPreferenceName) {
      return dataPreferences.getPreferencesSync(PrefUtil.context, { name: preferenceName });
    } else if (!PrefUtil.preferences) {
      PrefUtil.preferences = dataPreferences.getPreferencesSync(PrefUtil.context, { name: preferenceName });
    }
    return PrefUtil.preferences;
  }

  /**
   * 获取Preferences实例
   * @param name
   * @returns
   */
  private static async getPreferences(preferenceName: string = PrefUtil.defaultPreferenceName): Promise<preferences.Preferences> {
    if (preferenceName !== PrefUtil.defaultPreferenceName) {
      return await dataPreferences.getPreferences(PrefUtil.context, preferenceName);
    } else if (!PrefUtil.preferences) {
      PrefUtil.preferences = await dataPreferences.getPreferences(PrefUtil.context, preferenceName);
    }
    return PrefUtil.preferences;
  }


  /**
   * 将数据缓存
   * @param key
   * @param value
   */
  static putSync(key: string, value: preferences.ValueType,
    preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = PrefUtil.getPreferencesSync(preferenceName); //获取实例
    preferences.putSync(key, value);
    preferences.flush(); //此处一定要flush，要不然不能永久序列化到本地
  }

  /**
   * 将数据缓存
   * @param key
   * @param value
   */
  static async put(key: string, value: preferences.ValueType,
    preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = await PrefUtil.getPreferences(preferenceName); //获取实例
    await preferences.put(key, value);
    await preferences.flush(); //此处一定要flush，要不然不能永久序列化到本地
  }


  /**
   * 获取缓存值
   * @param key
   * @param defValue
   * @returns
   */
  static getSync(key: string, defValue: preferences.ValueType,
    preferenceName: string = PrefUtil.defaultPreferenceName): preferences.ValueType {
    let preferences = PrefUtil.getPreferencesSync(preferenceName); //获取实例
    return preferences.getSync(key, defValue);
  }

  /**
   * 获取缓存值
   * @param key
   * @param defValue
   * @returns
   */
  static async get(key: string, defValue: preferences.ValueType,
    preferenceName: string = PrefUtil.defaultPreferenceName): Promise<preferences.ValueType> {
    let preferences = await PrefUtil.getPreferences(preferenceName); //获取实例
    return preferences.get(key, defValue);
  }


  /**
   * 获取string类型的缓存值
   * @param key
   * @returns
   */
  static getStringSync(key: string, preferenceName: string = PrefUtil.defaultPreferenceName): string {
    return PrefUtil.getSync(key, "", preferenceName) as string;
  }

  /**
   * 获取string类型的缓存值
   * @param key
   * @returns
   */
  static async getString(key: string, preferenceName: string = PrefUtil.defaultPreferenceName): Promise<string> {
    return (await PrefUtil.get(key, "", preferenceName)) as string;
  }


  /**
   * 获取number类型的缓存值
   * @param key
   * @returns
   */
  static getNumberSync(key: string, preferenceName: string = PrefUtil.defaultPreferenceName): number {
    return PrefUtil.getSync(key, 0, preferenceName) as number;
  }

  /**
   * 获取number类型的缓存值
   * @param key
   * @returns
   */
  static async getNumber(key: string, preferenceName: string = PrefUtil.defaultPreferenceName): Promise<number> {
    return (await PrefUtil.get(key, 0, preferenceName)) as number;
  }


  /**
   * 获取boolean类型的缓存值
   * @param key
   * @returns
   */
  static getBooleanSync(key: string, preferenceName: string = PrefUtil.defaultPreferenceName): boolean {
    return PrefUtil.getSync(key, false, preferenceName) as boolean;
  }

  /**
   * 获取boolean类型的缓存值
   * @param key
   * @returns
   */
  static async getBoolean(key: string,
    preferenceName: string = PrefUtil.defaultPreferenceName): Promise<boolean> {
    return (await PrefUtil.get(key, false, preferenceName)) as boolean;
  }


  /**
   * 检查缓存的Preferences实例中是否包含名为给定Key的存储键值对
   * @param key
   * @returns
   */
  static hasSync(key: string, preferenceName: string = PrefUtil.defaultPreferenceName) {
    return PrefUtil.getPreferencesSync(preferenceName).hasSync(key);
  }

  /**
   * 检查缓存的Preferences实例中是否包含名为给定Key的存储键值对
   * @param key
   * @returns
   */
  static async has(key: string, preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = await PrefUtil.getPreferences(preferenceName); //获取实例
    return await preferences.has(key);
  }


  /**
   * 删除缓存值
   * @param key
   * @param preferenceName
   * @returns
   */
  static deleteSync(key: string, preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = PrefUtil.getPreferencesSync(preferenceName); //获取实例
    preferences.deleteSync(key);
    preferences.flush() //此处一定要flush，要不然不能永久序列化到本地
  }

  /**
   * 删除缓存值
   * @param key
   * @param preferenceName
   * @returns
   */
  static async delete(key: string, preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = await PrefUtil.getPreferences(preferenceName); //获取实例
    await preferences.delete(key);
    return await preferences.flush() //此处一定要flush，要不然不能永久序列化到本地
  }


  /**
   * 清空缓存的Preferences实例中的所有数据
   * @param preferenceName
   * @returns
   */
  static clearSync(preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = PrefUtil.getPreferencesSync(preferenceName); //获取实例
    preferences.clearSync();
    preferences.flush() //此处一定要flush，要不然不能永久序列化到本地
  }

  /**
   * 清除缓存的Preferences实例中的所有数据
   * @param preferenceName
   * @returns
   */
  static async clear(preferenceName: string = PrefUtil.defaultPreferenceName) {
    let preferences = await PrefUtil.getPreferences(preferenceName); //获取实例
    await preferences.clear();
    return await preferences.flush() //此处一定要flush，要不然不能永久序列化到本地
  }


  /**
   * 从缓存中移出指定的Preferences实例，若Preferences实例有对应的持久化文件，则同时删除其持久化文件。
   * @param context
   * @param name Preferences实例的名称。
   */
  static deletePreferences(context: Context, name: string) {
    dataPreferences.deletePreferences(context, name);
  }
}