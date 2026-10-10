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
  private static writeTail: Promise<void> = Promise.resolve();

  static async hasAcceptedCurrentPolicy(context: common.Context): Promise<boolean> {
    await FourD4yPrivacyConsentStore.writeTail;
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
    return FourD4yPrivacyConsentStore.enqueueWrite(context, FourD4yPrivacyConsentStore.POLICY_VERSION);
  }

  static async withdrawConsent(context: common.Context): Promise<boolean> {
    return FourD4yPrivacyConsentStore.enqueueWrite(context, '');
  }

  private static enqueueWrite(context: common.Context, version: string): Promise<boolean> {
    const result: Promise<boolean> = FourD4yPrivacyConsentStore.writeTail.then(() =>
      FourD4yPrivacyConsentStore.writeLocked(context, version));
    FourD4yPrivacyConsentStore.writeTail = result.then(() => {}, () => {});
    return result;
  }

  private static async writeLocked(context: common.Context, version: string): Promise<boolean> {
    let store: preferences.Preferences | undefined = undefined;
    let previous: string | undefined = undefined;
    try {
      store = await preferences.getPreferences(
        context, FourD4yPrivacyConsentStore.PREFERENCES_NAME);
      previous = store.getSync(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY, '') as string;
      await store.put(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY, version);
      await store.flush();
      return true;
    } catch (_error) {
      if (store !== undefined && previous !== undefined) {
        try {
          await store.put(FourD4yPrivacyConsentStore.ACCEPTED_VERSION_KEY, previous);
        } catch (_rollbackError) {
          // No guaranteed disk rollback; the caller remains at its prior consent gate.
        }
      }
      return false;
    }
  }
}
