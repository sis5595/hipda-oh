import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/**
 * Read-only description of a fresh edit form for a single post.
 *
 * This deliberately contains no field values: formhash, posttime, cookies,
 * raw HTML and the post body remain entirely inside the isolated ArkWeb
 * document.  It is only the capability check preceding a later deletion
 * action, not a deletion request itself.
 */
export interface FourD4yPostDeletionPreflightPayload {
  threadId: string;
  postId: string;
  forumId: string;
  page: number;
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionKind: string;
  hasMatchingPostId: boolean;
  hasMatchingThreadId: boolean;
  hasFormhashField: boolean;
  hasEditSubmitAction: boolean;
  hasDeleteControl: boolean;
  errorMessage: string;
}

/** Immediate value-free acknowledgement from the freshly validated form. */
export interface FourD4yPostDeletionSubmissionStartPayload {
  threadId: string;
  postId: string;
  submissionSequence: number;
  started: boolean;
  errorMessage: string;
}

/** Server-page facts from one bounded reread after a deletion submission. */
export interface FourD4yPostDeletionVerificationPayload {
  threadId: string;
  postId: string;
  submissionSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  isTargetThreadPage: boolean;
  isForumPage: boolean;
  postStillPresent: boolean;
  errorMessage: string;
}

/**
 * NG's long-standing edit entry is used only for a GET-only capability probe.
 * The form response itself is authoritative; callers must reject it when its
 * own pid/tid/action contract does not match this URL.
 */
export function buildFourD4yPostDeletionPreflightUrl(threadId: string, postId: string,
  forumId: string, loadSequence: number): string | null {
  if (!isDigits(threadId) || !isDigits(postId) || !isDigits(forumId) ||
    !Number.isInteger(loadSequence) || loadSequence < 1) {
    return null;
  }
  // NG has used this precise read-only edit entry for years.  The fixed page
  // value affects only the server's return route; the form's own pid/tid
  // contract remains the authority for this capability probe.
  return 'https://www.4d4y.com/forum/post.php?action=edit&fid=' + forumId +
    '&tid=' + threadId + '&pid=' + postId + '&page=1';
}

export function parseFourD4yPostDeletionPreflightPayload(rawResult: string):
  FourD4yPostDeletionPreflightPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yPostDeletionPreflightPayload =
      JSON.parse(payloadText) as FourD4yPostDeletionPreflightPayload;
    if (!isDigits(payload.threadId) || !isDigits(payload.postId) || !isDigits(payload.forumId) ||
      !Number.isInteger(payload.page) || payload.page < 1 ||
      !Number.isInteger(payload.loadSequence) || payload.loadSequence < 1 ||
      !isAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
      typeof payload.actionKind !== 'string' || typeof payload.hasMatchingPostId !== 'boolean' ||
      typeof payload.hasMatchingThreadId !== 'boolean' || typeof payload.hasFormhashField !== 'boolean' ||
      typeof payload.hasEditSubmitAction !== 'boolean' || typeof payload.hasDeleteControl !== 'boolean' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yPostDeletionSubmissionStartPayload(rawResult: string):
  FourD4yPostDeletionSubmissionStartPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yPostDeletionSubmissionStartPayload =
      JSON.parse(payloadText) as FourD4yPostDeletionSubmissionStartPayload;
    if (!isDigits(payload.threadId) || !isDigits(payload.postId) ||
      !Number.isInteger(payload.submissionSequence) || payload.submissionSequence < 1 ||
      typeof payload.started !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yPostDeletionVerificationPayload(rawResult: string):
  FourD4yPostDeletionVerificationPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yPostDeletionVerificationPayload =
      JSON.parse(payloadText) as FourD4yPostDeletionVerificationPayload;
    if (!isDigits(payload.threadId) || !isDigits(payload.postId) ||
      !Number.isInteger(payload.submissionSequence) || payload.submissionSequence < 1 ||
      !isAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.isTargetThreadPage !== 'boolean' || typeof payload.isForumPage !== 'boolean' ||
      typeof payload.postStillPresent !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yPostDeletionPreflight(
  payload: FourD4yPostDeletionPreflightPayload, threadId: string, postId: string,
  forumId: string, page: number, loadSequence: number): boolean {
  return payload.threadId === threadId && payload.postId === postId && payload.forumId === forumId &&
    payload.page === page && payload.loadSequence === loadSequence;
}

/**
 * This is intentionally stricter than merely finding an edit form.  An edit
 * form is not permission to delete; the current server must explicitly expose
 * a same-post deletion control in the fresh form.
 */
export function isReadyFourD4yPostDeletionForm(payload: FourD4yPostDeletionPreflightPayload): boolean {
  return payload.accessState === FourD4yPageAccessState.Available && payload.formFound &&
    payload.formMethod.toLowerCase() === 'post' && payload.actionKind === 'edit' &&
    payload.hasMatchingPostId && payload.hasMatchingThreadId &&
    payload.hasFormhashField && payload.hasEditSubmitAction && payload.hasDeleteControl;
}

export function isExpectedFourD4yPostDeletionSubmissionStart(
  payload: FourD4yPostDeletionSubmissionStartPayload, threadId: string, postId: string,
  submissionSequence: number): boolean {
  return payload.threadId === threadId && payload.postId === postId &&
    payload.submissionSequence === submissionSequence;
}

export function isExpectedFourD4yPostDeletionVerification(
  payload: FourD4yPostDeletionVerificationPayload, threadId: string, postId: string,
  submissionSequence: number): boolean {
  return payload.threadId === threadId && payload.postId === postId &&
    payload.submissionSequence === submissionSequence;
}

export function isConfirmedFourD4yPostDeletion(payload: FourD4yPostDeletionVerificationPayload,
  isFirstPost: boolean): boolean {
  return payload.accessState === FourD4yPageAccessState.Available && !payload.hasChallenge &&
    ((payload.isTargetThreadPage && !payload.postStillPresent) || (isFirstPost && payload.isForumPage));
}

export function isCurrentFourD4yPostDeletionPreflightRequest(url: string, threadId: string,
  postId: string, forumId: string): boolean {
  if (!isDigits(threadId) || !isDigits(postId) || !isDigits(forumId)) {
    return false;
  }
  return url.indexOf('/forum/post.php') >= 0 &&
    hasQueryField(url, 'action', 'edit') && hasQueryField(url, 'fid', forumId) &&
    hasQueryField(url, 'tid', threadId) && hasQueryField(url, 'pid', postId) &&
    hasQueryField(url, 'page', '1');
}

function isAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigits(value: string): boolean {
  return typeof value === 'string' && /^\d{1,20}$/.test(value);
}

function hasQueryField(url: string, name: string, value: string): boolean {
  return new RegExp('[?&]' + name + '=' + value + '(?:&|$)').test(url);
}

function unwrapWebResult(rawResult: string): string | null {
  if (typeof rawResult !== 'string') {
    return null;
  }
  try {
    return rawResult.startsWith('"') ? JSON.parse(rawResult) as string : rawResult;
  } catch (_error) {
    return null;
  }
}
