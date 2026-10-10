import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { addFourD4ySearchHistoryEntry, FourD4ySearchHistoryEntry,
  parseFourD4ySearchHistory } from '../../domain/search/FourD4ySearchHistory';

/** Local metadata only. All pages share one queue; no forum session or content is stored. */
export class FourD4ySearchHistoryStore {
  private static writeTail: Promise<void> = Promise.resolve();

  static async load(context: common.Context): Promise<FourD4ySearchHistoryEntry[]> {
    await FourD4ySearchHistoryStore.writeTail;
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, 'four_d4y_search_history');
      return parseFourD4ySearchHistory(store.getSync('entries', '') as string);
    } catch (_error) {
      throw new Error('search-history-read-failed');
    }
  }

  static record(context: common.Context, entry: FourD4ySearchHistoryEntry): Promise<FourD4ySearchHistoryEntry[]> {
    const requested: FourD4ySearchHistoryEntry = { keyword: entry.keyword, mode: entry.mode, forumId: entry.forumId };
    return FourD4ySearchHistoryStore.enqueue(context, requested);
  }

  static clear(context: common.Context): Promise<FourD4ySearchHistoryEntry[]> {
    return FourD4ySearchHistoryStore.enqueue(context, undefined);
  }

  private static enqueue(context: common.Context, entry: FourD4ySearchHistoryEntry | undefined):
    Promise<FourD4ySearchHistoryEntry[]> {
    const result: Promise<FourD4ySearchHistoryEntry[]> = FourD4ySearchHistoryStore.writeTail.then(() =>
      FourD4ySearchHistoryStore.writeLocked(context, entry));
    FourD4ySearchHistoryStore.writeTail = result.then(() => {}, () => {});
    return result;
  }

  private static async writeLocked(context: common.Context, entry: FourD4ySearchHistoryEntry | undefined):
    Promise<FourD4ySearchHistoryEntry[]> {
    let store: preferences.Preferences | undefined = undefined;
    let previous: string | undefined = undefined;
    try {
      store = await preferences.getPreferences(context, 'four_d4y_search_history');
      previous = store.getSync('entries', '') as string;
      const next: FourD4ySearchHistoryEntry[] = entry === undefined ? [] :
        addFourD4ySearchHistoryEntry(parseFourD4ySearchHistory(previous), entry);
      await store.put('entries', JSON.stringify(next));
      await store.flush();
      return next;
    } catch (_error) {
      if (store !== undefined && previous !== undefined) {
        try {
          await store.put('entries', previous);
        } catch (_rollbackError) {
          // Best-effort in-memory rollback, not a guaranteed disk transaction.
        }
      }
      throw new Error('search-history-write-failed');
    }
  }
}
