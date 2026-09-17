import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** Search modes supported by the current 4D4Y server form. */
export enum FourD4ySearchMode {
  Title = 'title',
  FullText = 'fulltext',
  Author = 'author'
}

/**
 * Value-free capability report from the current server-rendered search form.
 * Form values (including any account-specific fields) never leave ArkWeb.
 */
export interface FourD4ySearchFormPayload {
  probeSequence: number;
  /** Numeric account context read from the signed-in page; never persisted. */
  viewerUserId: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionPath: string;
  hasKeywordField: boolean;
  searchTypes: string[];
  hasAuthorNameField: boolean;
  hasAuthorIdField: boolean;
  hasForumFilter: boolean;
  forumFieldName: string;
  hasSubmitControl: boolean;
  errorMessage: string;
}

/** One thread rendered by a 4D4Y server search result. */
export interface FourD4ySearchThread {
  /** Owning thread, when the result link exposes tid/ptid directly. */
  threadId: string;
  /** Exact matching post. Full-text results commonly expose only this id. */
  postId: string;
  forumId: string;
  title: string;
  /** Matching text rendered by the full-text search result. */
  summary: string;
  forumName: string;
  authorName: string;
  replyCount: number;
  lastReplyAt: string;
}

/** Exact native-reader destination resolved from a full-text gotopost link. */
export interface FourD4ySearchPostTargetPayload {
  resolveSequence: number;
  requestedPostId: string;
  threadId: string;
  page: number;
  floor: number;
  title: string;
  postFound: boolean;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  errorMessage: string;
}

/** Value-free result extracted from a server-rendered search page. */
export interface FourD4ySearchPagePayload {
  loadSequence: number;
  page: number;
  lastPage: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  resultLayoutFound: boolean;
  previousPageUrl: string;
  nextPageUrl: string;
  errorMessage: string;
  threads: FourD4ySearchThread[];
}

export enum FourD4ySearchReaderOutcome {
  Content = 'content',
  Empty = 'empty',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

export function parseFourD4ySearchFormPayload(rawResult: string): FourD4ySearchFormPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4ySearchFormPayload = JSON.parse(payloadText) as FourD4ySearchFormPayload;
    if (typeof payload.probeSequence !== 'number' || typeof payload.viewerUserId !== 'string' ||
      (payload.viewerUserId.length > 0 && !isDigitsOnly(payload.viewerUserId)) ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
      typeof payload.actionPath !== 'string' || typeof payload.hasKeywordField !== 'boolean' ||
      !Array.isArray(payload.searchTypes) || !areSearchTypesValid(payload.searchTypes) ||
      typeof payload.hasAuthorNameField !== 'boolean' || typeof payload.hasAuthorIdField !== 'boolean' ||
      typeof payload.hasForumFilter !== 'boolean' || !isAllowedForumFieldName(payload.forumFieldName) ||
      typeof payload.hasSubmitControl !== 'boolean' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4ySearchPagePayload(rawResult: string): FourD4ySearchPagePayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4ySearchPagePayload = JSON.parse(payloadText) as FourD4ySearchPagePayload;
    if (typeof payload.loadSequence !== 'number' || !isPositiveInteger(payload.page) ||
      !isPositiveInteger(payload.lastPage) || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.resultLayoutFound !== 'boolean' ||
      typeof payload.previousPageUrl !== 'string' || typeof payload.nextPageUrl !== 'string' ||
      typeof payload.errorMessage !== 'string' || !Array.isArray(payload.threads) ||
      !areSearchThreadsValid(payload.threads)) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4ySearchPostTargetPayload(rawResult: string): FourD4ySearchPostTargetPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4ySearchPostTargetPayload = JSON.parse(payloadText) as FourD4ySearchPostTargetPayload;
    if (!isPositiveInteger(payload.resolveSequence) || !isDigitsOnly(payload.requestedPostId) ||
      (payload.threadId.length > 0 && !isDigitsOnly(payload.threadId)) || !isPositiveInteger(payload.page) ||
      typeof payload.floor !== 'number' || !Number.isFinite(payload.floor) || payload.floor < 0 ||
      Math.floor(payload.floor) !== payload.floor || typeof payload.title !== 'string' ||
      typeof payload.postFound !== 'boolean' || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4ySearchFormPayload(payload: FourD4ySearchFormPayload,
  probeSequence: number): boolean {
  return payload.probeSequence === probeSequence;
}

export function isExpectedFourD4ySearchPagePayload(payload: FourD4ySearchPagePayload,
  loadSequence: number): boolean {
  return payload.loadSequence === loadSequence;
}

export function isExpectedFourD4ySearchPostTargetPayload(payload: FourD4ySearchPostTargetPayload,
  postId: string, resolveSequence: number): boolean {
  return payload.requestedPostId === postId && payload.resolveSequence === resolveSequence;
}

/**
 * Builds the exact find-post endpoint used by the current MY 4D4Y client.
 * Full-text rows do not always expose ptid, so an empty ptid is deliberate:
 * the server can still resolve the owning thread from the verified pid.
 */
export function buildFourD4ySearchPostTargetUrl(threadId: string, postId: string): string | null {
  if ((threadId.length > 0 && !isDigitsOnly(threadId)) || !isDigitsOnly(postId)) {
    return null;
  }
  return 'https://www.4d4y.com/forum/redirect.php?goto=findpost&ptid=' + threadId + '&pid=' + postId;
}

/**
 * Builds Discuz's read-only single-post fragment endpoint.  Current MY 4D4Y
 * uses the same `viewpid` contract when it needs one exact post.  Unlike the
 * mobile find-post destination, this response exposes the server-computed
 * floor in `postnum<pid>` and therefore does not require guessing from a page
 * index or from the number of DOM nodes returned.
 */
export function buildFourD4ySearchPostViewUrl(threadId: string, postId: string): string | null {
  if (!isDigitsOnly(threadId) || !isDigitsOnly(postId)) {
    return null;
  }
  return 'https://www.4d4y.com/forum/viewthread.php?tid=' + threadId + '&viewpid=' + postId +
    '&inajax=1&mobile=no';
}

/** Only the forum's bounded, same-origin find-post targets may be followed. */
export function isAllowedFourD4ySearchPostTargetUrl(url: string): boolean {
  return /^https:\/\/www\.4d4y\.com\/forum\/(?:redirect|viewthread)\.php\?(?:[^\s#]+)(?:#\S*)?$/i.test(url);
}

/**
 * Drops a full-text hit only when the visible keyword can be proven to occur
 * exclusively inside quoted/link BBCode. If the server omitted the matching
 * fragment from its excerpt, keep the row rather than guessing.
 */
export function isMeaningfulFourD4yFullTextResult(thread: FourD4ySearchThread, keyword: string): boolean {
  const normalizedKeyword: string = keyword.trim().toLowerCase();
  if (normalizedKeyword.length === 0 || containsSearchKeyword(thread.title, normalizedKeyword)) {
    return true;
  }
  if (!containsSearchKeyword(thread.summary, normalizedKeyword)) {
    return true;
  }
  return containsSearchKeyword(removeFourD4yReferenceMarkup(thread.summary), normalizedKeyword);
}

/**
 * Enables a mode only after the authenticated search page proves the shared
 * fields it needs. Full-text is the one deliberate exception to the page's
 * radio values: current 4D4Y omits that choice from the HTML form, while both
 * NG and MY 4D4Y use the stable search.php full-text contract directly.
 */
export function isFourD4ySearchModeSupported(payload: FourD4ySearchFormPayload,
  mode: FourD4ySearchMode, keyword: string): boolean {
  if (payload.accessState !== FourD4yPageAccessState.Available || !payload.formFound ||
    !payload.hasSubmitControl || keyword.trim().length === 0) {
    return false;
  }
  if (mode === FourD4ySearchMode.Author) {
    return payload.hasAuthorNameField || (isDigitsOnly(keyword.trim()) && payload.hasAuthorIdField);
  }
  if (mode === FourD4ySearchMode.FullText) {
    return payload.hasKeywordField;
  }
  return payload.hasKeywordField && payload.searchTypes.indexOf(mode) >= 0;
}

export function getFourD4ySearchReaderOutcome(payload: FourD4ySearchPagePayload): FourD4ySearchReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4ySearchReaderOutcome.LoginRequired;
  }
  if (payload.threads.length > 0) {
    return FourD4ySearchReaderOutcome.Content;
  }
  if (payload.resultLayoutFound) {
    return FourD4ySearchReaderOutcome.Empty;
  }
  if (payload.hasChallenge) {
    return FourD4ySearchReaderOutcome.VerificationRequired;
  }
  return FourD4ySearchReaderOutcome.UnsupportedLayout;
}

/** Only same-origin server-generated search pagination targets may be loaded. */
export function isAllowedFourD4ySearchPageUrl(url: string): boolean {
  return /^https:\/\/www\.4d4y\.com\/forum\/search\.php\?(?:[^\s#]+)$/i.test(url);
}

function areSearchTypesValid(searchTypes: string[]): boolean {
  if (searchTypes.length > 10) {
    return false;
  }
  for (let index: number = 0; index < searchTypes.length; index += 1) {
    const searchType: string = searchTypes[index];
    if ((searchType !== FourD4ySearchMode.Title && searchType !== FourD4ySearchMode.FullText) ||
      searchTypes.indexOf(searchType) !== index) {
      return false;
    }
  }
  return true;
}

function areSearchThreadsValid(threads: FourD4ySearchThread[]): boolean {
  const seenTargets: Set<string> = new Set<string>();
  for (const thread of threads) {
    const hasThreadId: boolean = isDigitsOnly(thread.threadId);
    const hasPostId: boolean = isDigitsOnly(thread.postId);
    const targetKey: string = hasPostId ? 'post:' + thread.postId : 'thread:' + thread.threadId;
    if ((!hasThreadId && !hasPostId) ||
      (thread.threadId.length > 0 && !hasThreadId) || (thread.postId.length > 0 && !hasPostId) ||
      (thread.forumId.length > 0 && !isDigitsOnly(thread.forumId)) ||
      typeof thread.title !== 'string' || thread.title.length === 0 || typeof thread.summary !== 'string' ||
      typeof thread.forumName !== 'string' ||
      typeof thread.authorName !== 'string' || typeof thread.replyCount !== 'number' ||
      !Number.isFinite(thread.replyCount) || thread.replyCount < 0 || typeof thread.lastReplyAt !== 'string' ||
      seenTargets.has(targetKey)) {
      return false;
    }
    seenTargets.add(targetKey);
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

function isAllowedForumFieldName(value: string): boolean {
  return value === '' || value === 'srchfid[0]' || value === 'srchfid[]' || value === 'srchfid';
}

function containsSearchKeyword(value: string, normalizedKeyword: string): boolean {
  return value.toLowerCase().indexOf(normalizedKeyword) >= 0;
}

function removeFourD4yReferenceMarkup(value: string): string {
  let result: string = value;
  // Repeat a small fixed number of times so nested quote/link wrappers are
  // removed without introducing an unbounded HTML/BBCode parser here.
  for (let pass: number = 0; pass < 4; pass += 1) {
    const previous: string = result;
    result = result.replace(/\[url(?:=[^\]]*)?\][\s\S]*?\[\/url\]/gi, ' ')
      .replace(/\[quote(?:=[^\]]*)?\][\s\S]*?\[\/quote\]/gi, ' ')
      .replace(/\[img(?:=[^\]]*)?\][\s\S]*?\[\/img\]/gi, ' ');
    if (result === previous) {
      break;
    }
  }
  return result.replace(/https?:\/\/[^\s\[\]]+/gi, ' ')
    .replace(/\[[^\]]+\]/g, ' ');
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
