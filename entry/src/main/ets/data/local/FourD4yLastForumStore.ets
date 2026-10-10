import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { normalizeFourD4yLastForumId } from '../../domain/navigation/FourD4yHomeForumState';

const PREFERENCES_NAME: string = 'four_d4y_navigation_state';
const LAST_FORUM_ID_KEY: string = 'last_forum_id_v1';
const availableForumIds: string[] = getFourD4yForums().map((forum) => forum.id);

/** Stores only one validated catalog ID; it never contains page or session data. */
export class FourD4yLastForumStore {
  private static writeTail: Promise<void> = Promise.resolve();
  static async load(context: common.Context): Promise<string> {
    await FourD4yLastForumStore.writeTail;
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      const forumId: string = store.getSync(LAST_FORUM_ID_KEY, '') as string;
      return normalizeFourD4yLastForumId(forumId, availableForumIds);
    } catch (_error) {
      return '';
    }
  }

  static async save(context: common.Context, forumId: string): Promise<boolean> {
    const normalizedForumId: string = normalizeFourD4yLastForumId(forumId, availableForumIds);
    if (normalizedForumId.length === 0) {
      return false;
    }
    const result: Promise<boolean> = FourD4yLastForumStore.writeTail.then(() =>
      FourD4yLastForumStore.saveLocked(context, normalizedForumId));
    FourD4yLastForumStore.writeTail = result.then(() => {}, () => {});
    return result;
  }

  private static async saveLocked(context: common.Context, normalizedForumId: string): Promise<boolean> {
    let store: preferences.Preferences | undefined = undefined;
    let previousRaw: string | undefined = undefined;
    try {
      store = await preferences.getPreferences(context, PREFERENCES_NAME);
      previousRaw = store.getSync(LAST_FORUM_ID_KEY, '') as string;
      await store.put(LAST_FORUM_ID_KEY, normalizedForumId);
      await store.flush();
      return true;
    } catch (_error) {
      if (store !== undefined && previousRaw !== undefined) {
        try {
          await store.put(LAST_FORUM_ID_KEY, previousRaw);
        } catch (_rollbackError) {
          // Best-effort cache repair, not an atomic disk transaction.
        }
      }
      return false;
    }
  }
}
