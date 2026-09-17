import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { normalizeFourD4yLastForumId } from '../../domain/navigation/FourD4yHomeForumState';

const PREFERENCES_NAME: string = 'four_d4y_navigation_state';
const LAST_FORUM_ID_KEY: string = 'last_forum_id_v1';
const availableForumIds: string[] = getFourD4yForums().map((forum) => forum.id);

/** Stores only one validated catalog ID; it never contains page or session data. */
export class FourD4yLastForumStore {
  static async load(context: common.Context): Promise<string> {
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
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await store.put(LAST_FORUM_ID_KEY, normalizedForumId);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
