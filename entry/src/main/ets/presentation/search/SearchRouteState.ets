/** A profile shortcut searches by the immutable forum UID, not a display name. */
export interface SearchRouteParams {
  authorUserId: string;
  authorName: string;
}

export function createAuthorSearchRouteParams(userId: string, userName: string): SearchRouteParams {
  return {
    authorUserId: /^\d{1,20}$/.test(userId) ? userId : '',
    authorName: userName.trim().slice(0, 120)
  };
}
