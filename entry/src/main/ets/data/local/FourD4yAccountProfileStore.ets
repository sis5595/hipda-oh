import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { createDefaultFourD4yAccountRegistry, FourD4yAccountRegistry,
  normalizeFourD4yAccountRegistry, parseFourD4yAccountRegistry,
  serializeFourD4yAccountRegistry } from '../../domain/account/FourD4yAccountContracts';

const PREFERENCES_NAME: string = 'four_d4y_account_registry';
const REGISTRY_KEY: string = 'registry_v1';

/**
 * Stores only the non-sensitive account picker metadata. Session cookies and
 * credentials are expressly excluded; see FourD4yAccountSessionStore.
 */
export class FourD4yAccountProfileStore {
  static async load(context: common.Context): Promise<FourD4yAccountRegistry> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      return parseFourD4yAccountRegistry(store.getSync(REGISTRY_KEY, '') as string);
    } catch (_error) {
      return createDefaultFourD4yAccountRegistry();
    }
  }

  static async save(context: common.Context, registry: FourD4yAccountRegistry): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await store.put(REGISTRY_KEY, serializeFourD4yAccountRegistry(normalizeFourD4yAccountRegistry(registry)));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
