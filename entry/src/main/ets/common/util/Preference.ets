import dataPreferences from '@ohos.data.preferences'
import Util from './Util'

/**
 * Preference model.
 *
 * @param fruitData Fruit data.
 */
export class CCPreference {
  private preference: dataPreferences.Preferences | undefined
  private preferenceTemp: dataPreferences.Preferences | undefined
  private preferencesName = 'Preferences.db'

  /**
   * Read the specified Preferences persistence file and load the data into the Preferences instance.
   */
  private async getPreferencesFromStorage() {
    try {
      this.preference = await dataPreferences.getPreferences(getContext(this), this.preferencesName);
    } catch (err) {
    }
  }

  /**
   * Save the data to the Preferences.
   */
  public async writeData(key: string, value: string) {
    if (Util.isEmpty(key) || Util.isEmpty(value)) {
      return;
    }

    if (!this.preference) {
      await this.getPreferencesFromStorage();
    }

    try {
      await this.preference?.put(key, value);

      // Store the Preference instance in the preference persistence file
      await this.preference?.flush();
    } catch (err) {
    }
  }

  /**
   * Get preference data.
   */
  public async getData(key: string) {
    let value: string | undefined
    if (Util.isEmpty(key)) {
      return value;
    }

    if (!this.preference) {
      await this.getPreferencesFromStorage();
    }
    try {
      if (this.preference) {
        value = (await this.preference?.get(key, '')).toString();
      }
    } catch (err) {
    }

    return value;
  }

  /**
   * 删除保存数据
   */
  public async deleteData(key: string) {
    if (Util.isEmpty(key)) {
      return;
    }

    if (!this.preference) {
      await this.getPreferencesFromStorage();
    }

    let deleteValue = this.preference?.delete(key)
    deleteValue?.then(() => {
    }).catch((err: Error) => {
    });
  }

  /**
   * Deletes the specified Preferences persistence file from memory and removes the Preferences instance.
   */
  public async deletePreferences() {
    try {
      await dataPreferences.deletePreferences(getContext(this), this.preferencesName);
    } catch (err) {
    }
    this.preference = this.preferenceTemp;
  }
}

export default new CCPreference();