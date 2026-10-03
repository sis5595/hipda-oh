/** Per-destination identity for one server-owned private-message conversation. */
export interface PrivateMessageRouteParams {
  participantUserId: string;
  participantName: string;
  composeOnly?: boolean;
}

export function createPrivateMessageRouteParams(participantUserId: string,
  participantName: string, composeOnly: boolean = false): PrivateMessageRouteParams {
  return {
    participantUserId: /^\d{1,20}$/.test(participantUserId) ? participantUserId : '',
    participantName: participantName.trim().slice(0, 120),
    composeOnly
  };
}
