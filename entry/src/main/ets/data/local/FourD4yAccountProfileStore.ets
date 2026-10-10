import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { FourD4yAccountRegistry,
  normalizeFourD4yAccountRegistry, parseFourD4yAccountRegistry,
  serializeFourD4yAccountRegistry } from '../../domain/account/FourD4yAccountContracts';

const PREFERENCES_NAME: string = 'four_d4y_account_registry';
const REGISTRY_KEY: string = 'registry_v1';

/**
 * Stores only the non-sensitive account picker metadata. Session cookies and
 * credentials are expressly excluded; see FourD4yAccountSessionStore.
 */
export class FourD4yAccountProfileStore {
  private static writeTail: Promise<void> = Promise.resolve();

  static async load(context: common.Context): Promise<FourD4yAccountRegistry> {
    await FourD4yAccountProfileStore.writeTail;
    // Missing registry is a valid first launch; storage I/O failure is not.
    // Propagate failures so a subsequent save cannot replace existing accounts
    // with an empty registry that was fabricated from a read error.
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      return parseFourD4yAccountRegistry(store.getSync(REGISTRY_KEY, '') as string);
    } catch (_error) {
      throw new Error('account-registry-read-failed');
    }
  }

  static async save(context: common.Context, registry: FourD4yAccountRegistry,
    isCurrentOperation: () => boolean = () => true): Promise<boolean> {
    const serialized: string = serializeFourD4yAccountRegistry(normalizeFourD4yAccountRegistry(registry));
    const result: Promise<boolean> = FourD4yAccountProfileStore.writeTail.then(() =>
      FourD4yAccountProfileStore.saveLocked(context, serialized, isCurrentOperation));
    FourD4yAccountProfileStore.writeTail = result.then(() => {}, () => {});
    return result;
  }

  private static async saveLocked(context: common.Context, serialized: string,
    isCurrentOperation: () => boolean): Promise<boolean> {
    let store: preferences.Preferences | undefined = undefined;
    let previousRaw: string | undefined = undefined;
    try {
      if (!isCurrentOperation()) {
        return false;
      }
      store = await preferences.getPreferences(context, PREFERENCES_NAME);
      if (!isCurrentOperation()) {
        return false;
      }
      previousRaw = store.getSync(REGISTRY_KEY, '') as string;
      await store.put(REGISTRY_KEY, serialized);
      if (!isCurrentOperation()) {
        await store.put(REGISTRY_KEY, previousRaw);
        return false;
      }
      await store.flush();
      if (!isCurrentOperation()) {
        // Keep the queue locked during compensation: a later valid registry
        // write must never be overwritten by this expired verification.
        // This is not a crash-safe transaction across Preferences and Asset.
        await store.put(REGISTRY_KEY, previousRaw);
        await store.flush();
        return false;
      }
      return true;
    } catch (_error) {
      if (store !== undefined && previousRaw !== undefined) {
        try {
          // Preferences put changes its process cache before flush succeeds.
          // A failed registry write must not leave a phantom selected account.
          await store.put(REGISTRY_KEY, previousRaw);
        } catch (_rollbackError) {
          // Best-effort cache repair, not an atomic disk transaction.
        }
      }
      return false;
    }
  }
}
