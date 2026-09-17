/**
 * Resolves the initial board without assuming catalog order. The last visited
 * board wins; a user's first quick board is the fallback, followed by the
 * catalog's first valid board.
 */
export function resolveFourD4yHomeForumId(lastForumId: string, quickForumIds: string[],
  availableForumIds: string[]): string {
  const normalizedLastForumId: string = normalizeFourD4yLastForumId(lastForumId, availableForumIds);
  if (normalizedLastForumId.length > 0) {
    return normalizedLastForumId;
  }
  for (let index: number = 0; index < quickForumIds.length; index += 1) {
    const normalizedQuickForumId: string = normalizeFourD4yLastForumId(quickForumIds[index], availableForumIds);
    if (normalizedQuickForumId.length > 0) {
      return normalizedQuickForumId;
    }
  }
  return availableForumIds.length > 0 ? availableForumIds[0] : '';
}

export function normalizeFourD4yLastForumId(forumId: string, availableForumIds: string[]): string {
  if (!/^\d{1,10}$/.test(forumId) || availableForumIds.indexOf(forumId) < 0) {
    return '';
  }
  return forumId;
}
