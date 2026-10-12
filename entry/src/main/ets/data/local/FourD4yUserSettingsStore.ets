import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { createDefaultFourD4yUserSettings, FourD4yThemeMode, FourD4yUserSettings,
  parseFourD4yUserSettings, serializeFourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';
import { mergeFourD4yUserSettingsChanges, normalizeFourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';

const PREFERENCES_NAME: string = 'four_d4y_user_settings';
const SETTINGS_KEY: string = 'settings_v1';

/**
 * Small local preference store for presentation and opt-in post-tail choices. Forum authentication,
 * cookies, form fields, and page content are never read or written here.
 */
export class FourD4yUserSettingsStore {
  private static writeTail: Promise<void> = Promise.resolve();
  static async load(context: common.Context): Promise<FourD4yUserSettings> {
    // Preferences.put changes the shared memory cache before flush settles.
    // Readers must wait for confirmed writes (or their rollback), too.
    await FourD4yUserSettingsStore.writeTail;
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      const rawValue: string = store.getSync(SETTINGS_KEY, '') as string;
      return parseFourD4yUserSettings(rawValue);
    } catch (_error) {
      throw new Error('user-settings-read-failed');
    }
  }

  static async save(context: common.Context, settings: FourD4yUserSettings,
    before: FourD4yUserSettings): Promise<FourD4yUserSettings | undefined> {
    const next: FourD4yUserSettings = normalizeFourD4yUserSettings(settings);
    const baseline: FourD4yUserSettings = normalizeFourD4yUserSettings(before);
    const result: Promise<FourD4yUserSettings | undefined> = FourD4yUserSettingsStore.writeTail.then(() =>
      FourD4yUserSettingsStore.saveChangesLocked(context, next, baseline));
    FourD4yUserSettingsStore.writeTail = result.then(() => {}, () => {});
    return result;
  }

  private static async saveChangesLocked(context: common.Context, next: FourD4yUserSettings,
    before: FourD4yUserSettings): Promise<FourD4yUserSettings | undefined> {
    let store: preferences.Preferences | undefined = undefined;
    let previousRaw: string | undefined = undefined;
    try {
      store = await preferences.getPreferences(context, PREFERENCES_NAME);
      previousRaw = store.getSync(SETTINGS_KEY, '') as string;
      const merged: FourD4yUserSettings = mergeFourD4yUserSettingsChanges(
        parseFourD4yUserSettings(previousRaw), before, next);
      await store.put(SETTINGS_KEY, serializeFourD4yUserSettings(merged));
      await store.flush();
      return merged;
    } catch (_error) {
      // put modifies the Preferences memory cache before flush. Do not let a
      // failed write masquerade as a confirmed baseline for the next writer.
      if (store !== undefined && previousRaw !== undefined) {
        try {
          await store.put(SETTINGS_KEY, previousRaw);
        } catch (_rollbackError) {
          // Report failure; this is not a disk transaction or a guaranteed rollback.
        }
      }
      return undefined;
    }
  }

  static applyAppearance(applicationContext: common.ApplicationContext,
    settings: FourD4yUserSettings): void {
    try {
      applicationContext.setColorMode(toColorMode(settings.themeMode));
      applicationContext.setFontSizeScale(settings.fontScale);
    } catch (_error) {
      // Appearance falls back to the system default if the runtime rejects a change.
    }
  }

  static async restoreAndApply(context: common.Context,
    applicationContext: common.ApplicationContext): Promise<FourD4yUserSettings> {
    let settings: FourD4yUserSettings = createDefaultFourD4yUserSettings();
    try {
      settings = await FourD4yUserSettingsStore.load(context);
    } catch (_error) {
      // The application remains usable with safe defaults when local storage is unavailable.
    }
    FourD4yUserSettingsStore.applyAppearance(applicationContext, settings);
    return settings;
  }
}

function toColorMode(themeMode: FourD4yThemeMode): ConfigurationConstant.ColorMode {
  if (themeMode === FourD4yThemeMode.Light) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  if (themeMode === FourD4yThemeMode.Dark) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}
