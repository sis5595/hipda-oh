import { normalizeFourD4yBlacklistUserName } from '../../domain/blacklist/FourD4yBlacklistContracts';

/** An optional profile-derived suggestion; it never triggers a mutation by itself. */
export interface BlacklistRouteParams {
  suggestedUserName: string;
}

export function createBlacklistRouteParams(userName: string = ''): BlacklistRouteParams {
  return { suggestedUserName: normalizeFourD4yBlacklistUserName(userName) };
}
