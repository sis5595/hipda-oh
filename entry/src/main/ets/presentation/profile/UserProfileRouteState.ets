/**
 * Per-destination profile identity. The id comes only from an author link
 * extracted from the current thread, never from free-form user input.
 */
export interface UserProfileRouteParams {
  userId: string;
  userName: string;
}

export function createUserProfileRouteParams(userId: string, userName: string): UserProfileRouteParams {
  const normalizedName: string = typeof userName === 'string' ? userName.trim() : '';
  return {
    userId: typeof userId === 'string' && /^\d{1,20}$/.test(userId) ? userId : '',
    userName: normalizedName.substring(0, 160)
  };
}
