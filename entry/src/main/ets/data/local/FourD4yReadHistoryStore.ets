import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { FourD4yReadHistoryEntry, parseFourD4yReadHistory,
  serializeFourD4yReadHistory } from '../../domain/history/FourD4yReadHistory';

const PREFERENCES_NAME: string = 'four_d4y_read_history';
const HISTORY_KEY: string = 'entries_v1';

/** One local store for the small, privacy-safe reading progress list. */
export class FourD4yReadHistoryStore {
  static async load(context: common.Context): Promise<FourD4yReadHistoryEntry[]> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      return parseFourD4yReadHistory(store.getSync(HISTORY_KEY, '') as string);
    } catch (_error) {
      return [];
    }
  }

  static async save(context: common.Context, entries: FourD4yReadHistoryEntry[]): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await store.put(HISTORY_KEY, serializeFourD4yReadHistory(entries));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static async clear(context: common.Context): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await store.delete(HISTORY_KEY);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
