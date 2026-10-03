import { normalizeFourD4yBlacklistUserName } from '../../domain/blacklist/FourD4yBlacklistContracts';

/** An optional profile-derived suggestion; it never triggers a mutation by itself. */
export interface BlacklistRouteParams {
  suggestedUserName: string;
  promptForSuggestedUser: boolean;
}

export function createBlacklistRouteParams(userName: string = '', promptForSuggestedUser: boolean = false):
  BlacklistRouteParams {
  const suggestedUserName: string = normalizeFourD4yBlacklistUserName(userName);
  return { suggestedUserName, promptForSuggestedUser: promptForSuggestedUser && suggestedUserName.length > 0 };
}
