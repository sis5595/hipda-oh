import { FourD4yMessageMode } from '../../domain/notice/FourD4yMessageContracts';

/** The main drawer keeps NG's separate message and reminder destinations. */
export interface MessageCenterRouteParams {
  mode: FourD4yMessageMode;
}

export function createMessageCenterRouteParams(
  mode: FourD4yMessageMode = FourD4yMessageMode.PrivateMessages): MessageCenterRouteParams {
  return { mode: mode };
}

export function readMessageCenterRouteMode(route: MessageCenterRouteParams | null | undefined): FourD4yMessageMode {
  if (route !== undefined && route !== null && route.mode === FourD4yMessageMode.ThreadNotices) {
    return FourD4yMessageMode.ThreadNotices;
  }
  if (route !== undefined && route !== null && route.mode === FourD4yMessageMode.SystemNotices) {
    return FourD4yMessageMode.SystemNotices;
  }
  return FourD4yMessageMode.PrivateMessages;
}
