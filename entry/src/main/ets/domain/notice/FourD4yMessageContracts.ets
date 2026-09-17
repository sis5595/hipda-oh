import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** The three read-only message feeds exposed by the current 4D4Y site. */
export enum FourD4yMessageMode {
  PrivateMessages = 'private',
  ThreadNotices = 'threads',
  SystemNotices = 'system'
}

export enum FourD4yMessageKind {
  PrivateMessage = 'private',
  Thread = 'thread',
  Quote = 'quote',
  Reply = 'reply',
  System = 'system',
  Other = 'other'
}

/** Value-only row parsed from a message/notice listing. */
export interface FourD4yMessageItem {
  /** Stable server id, either pmid or notice id. */
  itemId: string;
  kind: FourD4yMessageKind;
  senderUserId: string;
  senderName: string;
  title: string;
  summary: string;
  occurredAt: string;
  threadId: string;
  postId: string;
  isUnread: boolean;
}

export interface FourD4yMessagePagePayload {
  loadSequence: number;
  mode: FourD4yMessageMode;
  page: number;
  lastPage: number;
  /** Current account marker from the authenticated response; never persisted. */
  viewerUserId: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  resultLayoutFound: boolean;
  errorMessage: string;
  items: FourD4yMessageItem[];
}

/** Counts exposed in the signed-in page's myprompt element. */
export interface FourD4yMessagePromptPayload {
  loadSequence: number;
  privateMessageCount: number;
  threadNoticeCount: number;
  systemNoticeCount: number;
  /** Included in NG's aggregate information-reminder count. */
  friendNoticeCount: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  promptFound: boolean;
}

export enum FourD4yMessageReaderOutcome {
  Content = 'content',
  Empty = 'empty',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

export function buildFourD4yMessagePageUrl(mode: FourD4yMessageMode, page: number): string | null {
  if (!isFourD4yMessageMode(mode) || !isPositiveInteger(page) || page > 1000000) {
    return null;
  }
  if (mode === FourD4yMessageMode.PrivateMessages) {
    return 'https://www.4d4y.com/forum/pm.php?filter=privatepm&page=' + page;
  }
  if (mode === FourD4yMessageMode.ThreadNotices) {
    return 'https://www.4d4y.com/forum/notice.php?filter=threads&page=' + page;
  }
  return 'https://www.4d4y.com/forum/notice.php?filter=systempm&page=' + page;
}

/**
 * Only the three read-only list URLs above may go through the native client.
 * This deliberately excludes PM views, deletion actions, and notice mutations.
 */
export function isAllowedFourD4yMessagePageUrl(url: string): boolean {
  const match: RegExpMatchArray | null = url.match(
    /^https:\/\/www\.4d4y\.com\/forum\/(pm|notice)\.php\?filter=(privatepm|threads|systempm)&page=(\d+)(?:&(?:_t=\d{1,20}|sid=[A-Za-z0-9._~%-]{1,768}))*$/i);
  if (match === null || !isPositiveInteger(Number.parseInt(match[3], 10)) ||
    Number.parseInt(match[3], 10) > 1000000) {
    return false;
  }
  return (match[1] === 'pm' && match[2] === 'privatepm') ||
    (match[1] === 'notice' && (match[2] === 'threads' || match[2] === 'systempm'));
}

export function readFourD4yMessageMode(url: string): FourD4yMessageMode | null {
  if (!isAllowedFourD4yMessagePageUrl(url)) {
    return null;
  }
  if (/\/pm\.php\?filter=privatepm(?:&|$)/i.test(url)) {
    return FourD4yMessageMode.PrivateMessages;
  }
  if (/\/notice\.php\?filter=threads(?:&|$)/i.test(url)) {
    return FourD4yMessageMode.ThreadNotices;
  }
  return FourD4yMessageMode.SystemNotices;
}

export function isExpectedFourD4yMessagePagePayload(payload: FourD4yMessagePagePayload,
  mode: FourD4yMessageMode, page: number, loadSequence: number): boolean {
  return payload.loadSequence === loadSequence && payload.mode === mode && payload.page === page &&
    isPositiveInteger(payload.lastPage) && payload.lastPage >= page &&
    (payload.viewerUserId.length === 0 || isDigitsOnly(payload.viewerUserId)) &&
    isFourD4yPageAccessState(payload.accessState) && typeof payload.hasChallenge === 'boolean' &&
    typeof payload.resultLayoutFound === 'boolean' && typeof payload.errorMessage === 'string' &&
    areItemsValid(payload.items);
}

export function isExpectedFourD4yMessagePromptPayload(payload: FourD4yMessagePromptPayload,
  loadSequence: number): boolean {
  return payload.loadSequence === loadSequence && isNonNegativeInteger(payload.privateMessageCount) &&
    isNonNegativeInteger(payload.threadNoticeCount) && isNonNegativeInteger(payload.systemNoticeCount) &&
    isNonNegativeInteger(payload.friendNoticeCount) &&
    isFourD4yPageAccessState(payload.accessState) && typeof payload.hasChallenge === 'boolean' &&
    typeof payload.promptFound === 'boolean';
}

export function getFourD4yMessageReaderOutcome(payload: FourD4yMessagePagePayload): FourD4yMessageReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yMessageReaderOutcome.LoginRequired;
  }
  if (payload.items.length > 0) {
    return FourD4yMessageReaderOutcome.Content;
  }
  if (payload.resultLayoutFound) {
    return FourD4yMessageReaderOutcome.Empty;
  }
  if (payload.hasChallenge) {
    return FourD4yMessageReaderOutcome.VerificationRequired;
  }
  return FourD4yMessageReaderOutcome.UnsupportedLayout;
}

function areItemsValid(items: FourD4yMessageItem[]): boolean {
  if (!Array.isArray(items) || items.length > 100) {
    return false;
  }
  const ids: Set<string> = new Set<string>();
  for (const item of items) {
    if (!/^(?:pm|notice):\d+$/.test(item.itemId) || !isFourD4yMessageKind(item.kind) ||
      (item.senderUserId.length > 0 && !isDigitsOnly(item.senderUserId)) ||
      typeof item.senderName !== 'string' || typeof item.title !== 'string' || item.title.length === 0 ||
      typeof item.summary !== 'string' || typeof item.occurredAt !== 'string' ||
      (item.threadId.length > 0 && !isDigitsOnly(item.threadId)) ||
      (item.postId.length > 0 && !isDigitsOnly(item.postId)) || typeof item.isUnread !== 'boolean' ||
      ids.has(item.itemId)) {
      return false;
    }
    ids.add(item.itemId);
  }
  return true;
}

function isFourD4yMessageMode(value: FourD4yMessageMode): boolean {
  return value === FourD4yMessageMode.PrivateMessages || value === FourD4yMessageMode.ThreadNotices ||
    value === FourD4yMessageMode.SystemNotices;
}

function isFourD4yMessageKind(value: FourD4yMessageKind): boolean {
  return value === FourD4yMessageKind.PrivateMessage || value === FourD4yMessageKind.Thread ||
    value === FourD4yMessageKind.Quote || value === FourD4yMessageKind.Reply ||
    value === FourD4yMessageKind.System || value === FourD4yMessageKind.Other;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigitsOnly(value: string): boolean {
  return typeof value === 'string' && /^\d+$/.test(value);
}

function isPositiveInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 1;
}

function isNonNegativeInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 0;
}
