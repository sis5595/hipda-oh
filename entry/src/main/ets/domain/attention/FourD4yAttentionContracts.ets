import { FourD4yFavoriteMutationStartPayload, FourD4yFavoriteOperationPayload,
  FourD4yFavoritePagePayload, FourD4yFavoriteThread,
  FourD4yFavoriteVerificationPayload, getFourD4yFavoriteReaderOutcome,
  isExpectedFourD4yFavoriteMutationStartPayload, isExpectedFourD4yFavoriteOperationPayload,
  isExpectedFourD4yFavoritePagePayload, isExpectedFourD4yFavoriteVerificationPayload,
  parseFourD4yFavoriteMutationStartPayload, parseFourD4yFavoriteOperationPayload,
  parseFourD4yFavoritePagePayload, parseFourD4yFavoriteVerificationPayload } from '../favorite/FourD4yFavoriteContracts';
import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';
export { FourD4yFavoriteReaderOutcome as FourD4yAttentionReaderOutcome } from
  '../favorite/FourD4yFavoriteContracts';

/**
 * 4D4Y exposes topic attention through the same server-rendered list shape as
 * favorites, but it is a different server collection (`item=attention`).
 * These aliases intentionally reuse the already validated, value-free DOM
 * payload shape while keeping all attention-facing code semantically named.
 */
export type FourD4yAttentionThread = FourD4yFavoriteThread;
export type FourD4yAttentionPagePayload = FourD4yFavoritePagePayload;
export type FourD4yAttentionOperationPayload = FourD4yFavoriteOperationPayload;
export type FourD4yAttentionMutationStartPayload = FourD4yFavoriteMutationStartPayload;

export interface FourD4yAttentionVerificationPayload {
  threadId: string;
  operationSequence: number;
  page: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  attentionPresent: boolean;
  errorMessage: string;
}

export const parseFourD4yAttentionPagePayload = parseFourD4yFavoritePagePayload;
export const parseFourD4yAttentionOperationPayload = parseFourD4yFavoriteOperationPayload;
export const parseFourD4yAttentionMutationStartPayload = parseFourD4yFavoriteMutationStartPayload;
export const isExpectedFourD4yAttentionPagePayload = isExpectedFourD4yFavoritePagePayload;
export const isExpectedFourD4yAttentionOperationPayload = isExpectedFourD4yFavoriteOperationPayload;
export const isExpectedFourD4yAttentionMutationStartPayload = isExpectedFourD4yFavoriteMutationStartPayload;
export const getFourD4yAttentionReaderOutcome = getFourD4yFavoriteReaderOutcome;

export function parseFourD4yAttentionVerificationPayload(rawResult: string): FourD4yAttentionVerificationPayload | null {
  const favoritePayload: FourD4yFavoriteVerificationPayload | null = parseFourD4yFavoriteVerificationPayload(rawResult);
  if (favoritePayload === null) {
    return null;
  }
  return {
    threadId: favoritePayload.threadId,
    operationSequence: favoritePayload.operationSequence,
    page: favoritePayload.page,
    accessState: favoritePayload.accessState,
    hasChallenge: favoritePayload.hasChallenge,
    formFound: favoritePayload.formFound,
    attentionPresent: favoritePayload.favoritePresent,
    errorMessage: favoritePayload.errorMessage
  };
}

export function isExpectedFourD4yAttentionVerificationPayload(payload: FourD4yAttentionVerificationPayload,
  threadId: string, operationSequence: number, page: number): boolean {
  return isExpectedFourD4yFavoriteVerificationPayload({
    threadId: payload.threadId,
    operationSequence: payload.operationSequence,
    page: payload.page,
    accessState: payload.accessState,
    hasChallenge: payload.hasChallenge,
    formFound: payload.formFound,
    favoritePresent: payload.attentionPresent,
    errorMessage: payload.errorMessage
  }, threadId, operationSequence, page);
}

/** Only an exact same-origin topic-attention action rendered by 4D4Y is callable. */
export function isAllowedFourD4yAttentionOperationUrl(url: string, threadId: string): boolean {
  if (!/^\d+$/.test(threadId) || url.length === 0 ||
    url.indexOf('https://www.4d4y.com/forum/my.php?') !== 0 || /\s/.test(url)) {
    return false;
  }
  const itemToken: RegExp = /(?:[?&])item=attention(?:&|$)/;
  const threadToken: RegExp = new RegExp('(?:[?&])tid=' + threadId + '(?:&|$)');
  return itemToken.test(url) && threadToken.test(url);
}

/**
 * Current 4D4Y topic-attention contract, independently used by NG and MY
 * 4D4Y. The caller still verifies the final server-rendered attention list.
 */
export function buildFourD4yAttentionOperationUrl(threadId: string, isRemoving: boolean = false): string {
  if (!/^\d+$/.test(threadId)) {
    return '';
  }
  return 'https://www.4d4y.com/forum/my.php?item=attention&action=' +
    (isRemoving ? 'remove' : 'add') + '&inajax=1&ajaxtarget=favorite_msg&tid=' + threadId;
}
