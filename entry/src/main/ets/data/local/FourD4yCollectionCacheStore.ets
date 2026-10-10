import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** Only numeric IDs; serialized IO, no cookies, form tokens or private page content. */
export class FourD4yCollectionCacheStore {
  private static tail: Promise<void> = Promise.resolve();

  static async load(context: common.Context, uid: string, item: string): Promise<string[]> {
    const key: string = FourD4yCollectionCacheStore.key(uid, item);
    await FourD4yCollectionCacheStore.tail;
    const store: preferences.Preferences = await preferences.getPreferences(context, 'four_d4y_collection_cache');
    const raw: string = store.getSync(key, '[]') as string;
    if (typeof raw !== 'string' || raw.length > 8000) throw new Error('collection-cache-invalid');
    const ids: string[] = JSON.parse(raw) as string[];
    if (!Array.isArray(ids) || ids.length > 300 ||
      ids.some((id: string) => typeof id !== 'string' || !/^\d{1,20}$/.test(id))) {
      throw new Error('collection-cache-invalid');
    }
    return ids;
  }

  static save(context: common.Context, uid: string, item: string, ids: string[]): Promise<void> {
    const key: string = FourD4yCollectionCacheStore.key(uid, item);
    const raw: string = JSON.stringify(ids.filter((id: string) => /^\d{1,20}$/.test(id)).slice(-300));
    const result: Promise<void> = FourD4yCollectionCacheStore.tail.then(async () => {
      const store: preferences.Preferences = await preferences.getPreferences(context, 'four_d4y_collection_cache');
      const previous: string = store.getSync(key, '[]') as string;
      try {
        await store.put(key, raw);
        await store.flush();
      } catch (_error) {
        try { await store.put(key, previous); } catch (_rollbackError) {}
        throw new Error('collection-cache-write-failed');
      }
    });
    FourD4yCollectionCacheStore.tail = result.then(() => {}, () => {});
    return result;
  }

  private static key(uid: string, item: string): string {
    if (!/^\d{1,16}$/.test(uid) || (item !== 'favorites' && item !== 'attention')) {
      throw new Error('collection-cache-owner-invalid');
    }
    return item + '_' + uid;
  }
}
