import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** The two account-owned lists exposed by the current 4D4Y desktop site. */
export enum FourD4yMyContentMode {
  Threads = 'threads',
  Replies = 'posts'
}

export interface FourD4yMyContentItem {
  threadId: string;
  /** Present for “我的回复”, so the native reader can locate the exact floor. */
  postId: string;
  forumId: string;
  title: string;
  summary: string;
  forumName: string;
  lastReplyAt: string;
}

/** Value-only result parsed from my.php. No cookie or response HTML survives. */
export interface FourD4yMyContentPagePayload {
  loadSequence: number;
  mode: FourD4yMyContentMode;
  page: number;
  lastPage: number;
  /** Current account marker read from this authenticated response; never persisted. */
  viewerUserId: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  resultLayoutFound: boolean;
  errorMessage: string;
  items: FourD4yMyContentItem[];
}

export enum FourD4yMyContentReaderOutcome {
  Content = 'content',
  Empty = 'empty',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

export function buildFourD4yMyContentUrl(mode: FourD4yMyContentMode, page: number): string | null {
  if (!isFourD4yMyContentMode(mode) || !isPositiveInteger(page) || page > 1000000) {
    return null;
  }
  return 'https://www.4d4y.com/forum/my.php?item=' + mode + '&page=' + page;
}

/**
 * Accept only the two read-only my.php routes used by NG and current MY 4D4Y.
 * `_t` is MY's cache buster; `sid` is its bounded session mirror.
 */
export function isAllowedFourD4yMyContentUrl(url: string): boolean {
  const prefix: string = 'https://www.4d4y.com/forum/my.php?';
  if (!url.startsWith(prefix) || /[\s#]/.test(url)) {
    return false;
  }
  const parts: string[] = url.slice(prefix.length).split('&');
  let mode: string = '';
  let page: number = 0;
  let itemCount: number = 0;
  let pageCount: number = 0;
  for (let index: number = 0; index < parts.length; index += 1) {
    const part: string = parts[index];
    const separator: number = part.indexOf('=');
    if (separator <= 0) {
      return false;
    }
    const name: string = part.slice(0, separator);
    const value: string = part.slice(separator + 1);
    if (name === 'item') {
      itemCount += 1;
      mode = value;
    } else if (name === 'page') {
      pageCount += 1;
      if (!/^\d+$/.test(value)) {
        return false;
      }
      page = Number.parseInt(value, 10);
    } else if (name === '_t') {
      if (!/^\d{1,20}$/.test(value)) {
        return false;
      }
    } else if (name === 'sid') {
      if (value.length === 0 || value.length > 768 || !/^[A-Za-z0-9._~%-]+$/.test(value)) {
        return false;
      }
    } else {
      return false;
    }
  }
  return itemCount === 1 && pageCount === 1 && isFourD4yMyContentMode(mode as FourD4yMyContentMode) &&
    isPositiveInteger(page) && page <= 1000000;
}

export function readFourD4yMyContentMode(url: string): FourD4yMyContentMode | null {
  if (!isAllowedFourD4yMyContentUrl(url)) {
    return null;
  }
  const match: RegExpMatchArray | null = url.match(/[?&]item=(threads|posts)(?:&|$)/);
  return match === null ? null : match[1] as FourD4yMyContentMode;
}

export function isExpectedFourD4yMyContentPagePayload(payload: FourD4yMyContentPagePayload,
  mode: FourD4yMyContentMode, page: number, loadSequence: number): boolean {
  return payload.loadSequence === loadSequence && payload.mode === mode && payload.page === page &&
    isPositiveInteger(payload.lastPage) && payload.lastPage >= page &&
    (payload.viewerUserId.length === 0 || /^\d+$/.test(payload.viewerUserId)) &&
    isFourD4yPageAccessState(payload.accessState) && typeof payload.hasChallenge === 'boolean' &&
    typeof payload.resultLayoutFound === 'boolean' && typeof payload.errorMessage === 'string' &&
    areItemsValid(payload.items);
}

export function getFourD4yMyContentReaderOutcome(payload: FourD4yMyContentPagePayload):
  FourD4yMyContentReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yMyContentReaderOutcome.LoginRequired;
  }
  if (payload.items.length > 0) {
    return FourD4yMyContentReaderOutcome.Content;
  }
  if (payload.resultLayoutFound) {
    return FourD4yMyContentReaderOutcome.Empty;
  }
  if (payload.hasChallenge) {
    return FourD4yMyContentReaderOutcome.VerificationRequired;
  }
  return FourD4yMyContentReaderOutcome.UnsupportedLayout;
}

function areItemsValid(items: FourD4yMyContentItem[]): boolean {
  if (!Array.isArray(items) || items.length > 100) {
    return false;
  }
  const seenTargets: Set<string> = new Set<string>();
  for (const item of items) {
    const target: string = item.postId.length > 0 ? 'post:' + item.postId : 'thread:' + item.threadId;
    if (!/^\d+$/.test(item.threadId) || (item.postId.length > 0 && !/^\d+$/.test(item.postId)) ||
      (item.forumId.length > 0 && !/^\d+$/.test(item.forumId)) || item.title.length === 0 ||
      typeof item.summary !== 'string' || typeof item.forumName !== 'string' ||
      typeof item.lastReplyAt !== 'string' || seenTargets.has(target)) {
      return false;
    }
    seenTargets.add(target);
  }
  return true;
}

function isFourD4yMyContentMode(value: FourD4yMyContentMode): boolean {
  return value === FourD4yMyContentMode.Threads || value === FourD4yMyContentMode.Replies;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isPositiveInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 1;
}
