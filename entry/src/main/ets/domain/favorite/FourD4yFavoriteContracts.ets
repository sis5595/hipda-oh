import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** A server-side 4D4Y favorite, as rendered by `my.php?item=favorites`. */
export interface FourD4yFavoriteThread {
  threadId: string;
  forumId: string;
  title: string;
  forumName: string;
  replyCount: number;
  lastReplyAt: string;
}

/** Value-free result extracted from one server favorites page. */
export interface FourD4yFavoritePagePayload {
  page: number;
  lastPage: number;
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  hasDeletionControl: boolean;
  errorMessage: string;
  threads: FourD4yFavoriteThread[];
}

/** A current server-rendered operation link for one thread. */
export interface FourD4yFavoriteOperationPayload {
  threadId: string;
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  actionUrl: string;
  actionLabel: string;
  errorMessage: string;
}

/** Immediate acknowledgement that an in-page server operation was started. */
export interface FourD4yFavoriteMutationStartPayload {
  threadId: string;
  operationSequence: number;
  started: boolean;
  errorMessage: string;
}

/**
 * A read-only verification of one server-rendered favorites page after a
 * user-initiated mutation. The page's deletion checkbox is the authoritative
 * indication that this exact thread is still favorited.
 */
export interface FourD4yFavoriteVerificationPayload {
  threadId: string;
  operationSequence: number;
  page: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  favoritePresent: boolean;
  errorMessage: string;
}

export enum FourD4yFavoriteReaderOutcome {
  Content = 'content',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

export function parseFourD4yFavoritePagePayload(rawResult: string): FourD4yFavoritePagePayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yFavoritePagePayload = JSON.parse(payloadText) as FourD4yFavoritePagePayload;
    if (!isPositiveInteger(payload.page) || !isPositiveInteger(payload.lastPage) ||
      typeof payload.loadSequence !== 'number' || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.formFound !== 'boolean' ||
      typeof payload.hasDeletionControl !== 'boolean' || typeof payload.errorMessage !== 'string' ||
      !Array.isArray(payload.threads) || !areFavoriteThreadsValid(payload.threads)) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yFavoriteOperationPayload(rawResult: string): FourD4yFavoriteOperationPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yFavoriteOperationPayload = JSON.parse(payloadText) as FourD4yFavoriteOperationPayload;
    if (!isDigitsOnly(payload.threadId) || typeof payload.loadSequence !== 'number' ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.actionUrl !== 'string' || typeof payload.actionLabel !== 'string' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yFavoriteMutationStartPayload(rawResult: string): FourD4yFavoriteMutationStartPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yFavoriteMutationStartPayload =
      JSON.parse(payloadText) as FourD4yFavoriteMutationStartPayload;
    if (!isDigitsOnly(payload.threadId) || typeof payload.operationSequence !== 'number' ||
      typeof payload.started !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yFavoriteVerificationPayload(rawResult: string): FourD4yFavoriteVerificationPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yFavoriteVerificationPayload =
      JSON.parse(payloadText) as FourD4yFavoriteVerificationPayload;
    if (!isDigitsOnly(payload.threadId) || typeof payload.operationSequence !== 'number' ||
      !isPositiveInteger(payload.page) || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.formFound !== 'boolean' ||
      typeof payload.favoritePresent !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yFavoritePagePayload(payload: FourD4yFavoritePagePayload, page: number,
  loadSequence: number): boolean {
  return payload.page === page && payload.loadSequence === loadSequence;
}

export function isExpectedFourD4yFavoriteOperationPayload(payload: FourD4yFavoriteOperationPayload,
  threadId: string, loadSequence: number): boolean {
  return payload.threadId === threadId && payload.loadSequence === loadSequence;
}

export function isExpectedFourD4yFavoriteMutationStartPayload(payload: FourD4yFavoriteMutationStartPayload,
  threadId: string, operationSequence: number): boolean {
  return payload.threadId === threadId && payload.operationSequence === operationSequence;
}

export function isExpectedFourD4yFavoriteVerificationPayload(payload: FourD4yFavoriteVerificationPayload,
  threadId: string, operationSequence: number, page: number): boolean {
  return payload.threadId === threadId && payload.operationSequence === operationSequence && payload.page === page;
}

export function getFourD4yFavoriteReaderOutcome(payload: FourD4yFavoritePagePayload): FourD4yFavoriteReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yFavoriteReaderOutcome.LoginRequired;
  }
  // A valid favorites form is authoritative, including the empty-favorites
  // state. Cloudflare's passive bootstrap script is sometimes present too.
  if (payload.formFound || payload.threads.length > 0) {
    return FourD4yFavoriteReaderOutcome.Content;
  }
  if (payload.hasChallenge) {
    return FourD4yFavoriteReaderOutcome.VerificationRequired;
  }
  return FourD4yFavoriteReaderOutcome.UnsupportedLayout;
}

/** Only a same-origin operation emitted for this exact thread may be invoked. */
export function isAllowedFourD4yFavoriteOperationUrl(url: string, threadId: string): boolean {
  if (!isDigitsOnly(threadId) || url.length === 0 ||
    url.indexOf('https://www.4d4y.com/forum/my.php?') !== 0 || /\s/.test(url)) {
    return false;
  }
  const itemToken: RegExp = /(?:[?&])item=favorites(?:&|$)/;
  const threadToken: RegExp = new RegExp('(?:[?&])tid=' + threadId + '(?:&|$)');
  const actionToken: RegExp = /(?:[?&])action=(?:add|remove)(?:&|$)/;
  return itemToken.test(url) && threadToken.test(url) && actionToken.test(url);
}

/**
 * The server's Discuz favorite action used by NG: the user still initiates
 * the mutation, while the later favorites-form readback remains authoritative.
 */
export function buildFourD4yFavoriteAddUrl(threadId: string): string {
  if (!isDigitsOnly(threadId)) {
    return '';
  }
  return 'https://www.4d4y.com/forum/my.php?item=favorites&action=add&inajax=1&ajaxtarget=favorite_msg&tid=' +
    threadId;
}

function areFavoriteThreadsValid(threads: FourD4yFavoriteThread[]): boolean {
  const seenThreadIds: Set<string> = new Set<string>();
  for (const thread of threads) {
    if (!isDigitsOnly(thread.threadId) || (thread.forumId.length > 0 && !isDigitsOnly(thread.forumId)) ||
      typeof thread.title !== 'string' || typeof thread.forumName !== 'string' ||
      typeof thread.replyCount !== 'number' || !Number.isFinite(thread.replyCount) ||
      thread.replyCount < 0 || typeof thread.lastReplyAt !== 'string' || seenThreadIds.has(thread.threadId)) {
      return false;
    }
    seenThreadIds.add(thread.threadId);
  }
  return true;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isPositiveInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 1;
}

function isDigitsOnly(value: string): boolean {
  return typeof value === 'string' && /^\d+$/.test(value);
}

function unwrapWebResult(rawResult: string): string | null {
  let payloadText: string = rawResult;
  try {
    if (payloadText.startsWith('"')) {
      payloadText = JSON.parse(payloadText) as string;
    }
    return payloadText;
  } catch (_error) {
    return null;
  }
}
