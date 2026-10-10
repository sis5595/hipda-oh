import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { FourD4yCollectionCache } from '../../domain/favorite/FourD4yCollectionCache';
import { FourD4yCollectionCacheStore } from '../../data/local/FourD4yCollectionCacheStore';
import { buildFourD4yAccountIdentityScript } from '../../domain/account/FourD4yAccountIdentityScript';
import { parseFourD4yAccountIdentity } from '../../domain/account/FourD4yAccountContracts';

/** Bind from the authenticated self menu, never saved account labels or post authors. */
export async function bindFourD4yCollectionCache(context: common.Context, controller: webview.WebviewController,
  cache: FourD4yCollectionCache, item: 'favorites' | 'attention', isCurrent: () => boolean): Promise<void> {
  if (!isCurrent()) return;
  try {
    const raw: string = await controller.runJavaScript(buildFourD4yAccountIdentityScript());
    if (!isCurrent()) return;
    const identity = parseFourD4yAccountIdentity(raw);
    if (identity === null) return;
    await cache.bind(identity.userId,
      () => FourD4yCollectionCacheStore.load(context, identity.userId, item),
      (ids: string[]) => FourD4yCollectionCacheStore.save(context, identity.userId, item, ids), isCurrent);
  } catch (_error) {
    // Optional cache failure must not masquerade as a forum login failure.
  }
}
