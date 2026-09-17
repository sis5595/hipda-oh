import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { createDefaultFourD4yUserSettings, FourD4yThemeMode, FourD4yUserSettings,
  parseFourD4yUserSettings, serializeFourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';

const PREFERENCES_NAME: string = 'four_d4y_user_settings';
const SETTINGS_KEY: string = 'settings_v1';

/**
 * Small local preference store for display-only choices. Forum authentication,
 * cookies, form fields, and page content are never read or written here.
 */
export class FourD4yUserSettingsStore {
  static async load(context: common.Context): Promise<FourD4yUserSettings> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      const rawValue: string = store.getSync(SETTINGS_KEY, '') as string;
      return parseFourD4yUserSettings(rawValue);
    } catch (_error) {
      return createDefaultFourD4yUserSettings();
    }
  }

  static async save(context: common.Context, settings: FourD4yUserSettings): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await store.put(SETTINGS_KEY, serializeFourD4yUserSettings(settings));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
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
