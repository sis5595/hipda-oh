import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/**
 * Stores only the accepted policy revision. It deliberately does not contain a
 * forum account, device identifier, network address, or consent timestamp.
 */
export class FourD4yPrivacyConsentStore {
  static readonly POLICY_VERSION: string = '2026-09-20';

  private static readonly PREFERENCES_NAME: string = 'hipdaoh_privacy_consent';
  private static readonly ACCEPTED_VERSION_KEY: string = 'accepted_policy_version';

  static async hasAcceptedCurrentPolicy(context: common.Context): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context, FourD4yPrivacyConsentStore.PREFERENCES_NAME);
      return store.getSync(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY, '') ===
        FourD4yPrivacyConsentStore.POLICY_VERSION;
    } catch (_error) {
      return false;
    }
  }

  static async acceptCurrentPolicy(context: common.Context): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context, FourD4yPrivacyConsentStore.PREFERENCES_NAME);
      await store.put(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY,
        FourD4yPrivacyConsentStore.POLICY_VERSION);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static async withdrawConsent(context: common.Context): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context, FourD4yPrivacyConsentStore.PREFERENCES_NAME);
      await store.delete(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
