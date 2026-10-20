/**
 * Per-destination data. Keeping it in NavPathStack rather than a shared
 * singleton lets a nested thread link return to the original thread intact.
 */
export interface ThreadRouteParams {
  threadId: string;
  threadTitle: string;
  /** Known when opened from a forum list; required for 4D4Y image preflight. */
  forumId: string;
  replyCount: number;
  initialPage: number;
  initialFloor: number;
  /** Stable Discuz post identity; preferred over a derived floor number. */
  initialPostId: string;
  /** Authoritative only when the route was created from the server favorites list. */
  initialFavoriteState: boolean;
  /** Page that established initialFavoriteState; used for removal verification. */
  initialFavoritePage: number;
  /** Authoritative only when the route was created from the server attention list. */
  initialAttentionState: boolean;
  /** Page that established initialAttentionState; used for removal verification. */
  initialAttentionPage: number;
  /** Show the inline attention action only at the reminder's target post. */
  openedFromNotice?: boolean;
}

export function createThreadRouteParams(threadId: string, threadTitle: string,
  replyCount: number, initialPage: number = 1, initialFloor: number = 0,
  forumId: string = '', initialFavoriteState: boolean = false, initialFavoritePage: number = 1,
  initialPostId: string = '', initialAttentionState: boolean = false, initialAttentionPage: number = 1,
  openedFromNotice: boolean = false): ThreadRouteParams {
  return {
    threadId: threadId,
    threadTitle: threadTitle,
    forumId: /^\d+$/.test(forumId) ? forumId : '',
    replyCount: Number.isFinite(replyCount) ? Math.max(replyCount, 0) : 0,
    initialPage: Number.isFinite(initialPage) ? Math.max(1, Math.floor(initialPage)) : 1,
    initialFloor: Number.isFinite(initialFloor) ? Math.max(0, Math.floor(initialFloor)) : 0,
    initialPostId: /^\d+$/.test(initialPostId) ? initialPostId : '',
    initialFavoriteState: initialFavoriteState,
    initialFavoritePage: Number.isFinite(initialFavoritePage) ? Math.max(1, Math.floor(initialFavoritePage)) : 1,
    initialAttentionState: initialAttentionState,
    openedFromNotice: openedFromNotice,
    initialAttentionPage: Number.isFinite(initialAttentionPage) ? Math.max(1, Math.floor(initialAttentionPage)) : 1
  };
}
