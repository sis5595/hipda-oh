import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/**
 * Read-only private-message conversation contract.  The route matches the
 * one used by NG and current MY 4D4Y after a user selects a PM sender.
 */
export interface FourD4yPrivateConversationMessage {
  /** Server PM id when exposed by the template; otherwise a bounded row key. */
  messageId: string;
  senderUserId: string;
  senderName: string;
  body: string;
  occurredAt: string;
  isMine: boolean;
  isUnread: boolean;
}

export interface FourD4yPrivateConversationPayload {
  loadSequence: number;
  participantUserId: string;
  viewerUserId: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  conversationLayoutFound: boolean;
  errorMessage: string;
  messages: FourD4yPrivateConversationMessage[];
}

export enum FourD4yPrivateConversationReaderOutcome {
  Content = 'content',
  Empty = 'empty',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

/** The GET-only conversation view used by NG; it has no send/delete action. */
export function buildFourD4yPrivateConversationUrl(participantUserId: string): string | null {
  if (!isDigitsOnly(participantUserId)) {
    return null;
  }
  return 'https://www.4d4y.com/forum/pm.php?daterange=5&uid=' + participantUserId;
}

/**
 * Do not accept arbitrary pm.php actions. `sid` is the bounded session mirror
 * appended by the native cookie bridge and is not retained by the UI.
 */
export function isAllowedFourD4yPrivateConversationUrl(url: string): boolean {
  const match: RegExpMatchArray | null = url.match(
    /^https:\/\/www\.4d4y\.com\/forum\/pm\.php\?daterange=5&uid=(\d+)(?:&sid=[A-Za-z0-9._~%-]{1,768})?$/i);
  return match !== null && isDigitsOnly(match[1]);
}

export function readFourD4yPrivateConversationParticipantId(url: string): string {
  if (!isAllowedFourD4yPrivateConversationUrl(url)) {
    return '';
  }
  const match: RegExpMatchArray | null = url.match(/[?&]uid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
}

export function isExpectedFourD4yPrivateConversationPayload(payload: FourD4yPrivateConversationPayload,
  participantUserId: string, loadSequence: number): boolean {
  return payload.loadSequence === loadSequence && payload.participantUserId === participantUserId &&
    isDigitsOnly(payload.participantUserId) && (payload.viewerUserId.length === 0 || isDigitsOnly(payload.viewerUserId)) &&
    isFourD4yPageAccessState(payload.accessState) && typeof payload.hasChallenge === 'boolean' &&
    typeof payload.conversationLayoutFound === 'boolean' && typeof payload.errorMessage === 'string' &&
    areMessagesValid(payload.messages);
}

export function getFourD4yPrivateConversationReaderOutcome(payload: FourD4yPrivateConversationPayload):
  FourD4yPrivateConversationReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yPrivateConversationReaderOutcome.LoginRequired;
  }
  if (payload.messages.length > 0) {
    return FourD4yPrivateConversationReaderOutcome.Content;
  }
  if (payload.conversationLayoutFound) {
    return FourD4yPrivateConversationReaderOutcome.Empty;
  }
  if (payload.hasChallenge) {
    return FourD4yPrivateConversationReaderOutcome.VerificationRequired;
  }
  return FourD4yPrivateConversationReaderOutcome.UnsupportedLayout;
}

function areMessagesValid(messages: FourD4yPrivateConversationMessage[]): boolean {
  if (!Array.isArray(messages) || messages.length > 200) {
    return false;
  }
  const identifiers: Set<string> = new Set<string>();
  for (const message of messages) {
    if (!/^(?:pm|row):\d+$/.test(message.messageId) || identifiers.has(message.messageId) ||
      (message.senderUserId.length > 0 && !isDigitsOnly(message.senderUserId)) ||
      typeof message.senderName !== 'string' || typeof message.body !== 'string' ||
      typeof message.occurredAt !== 'string' || typeof message.isMine !== 'boolean' ||
      typeof message.isUnread !== 'boolean') {
      return false;
    }
    identifiers.add(message.messageId);
  }
  return true;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigitsOnly(value: string): boolean {
  return typeof value === 'string' && /^\d+$/.test(value) && value.length <= 20;
}
