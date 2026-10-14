import { ThreadPoll, ThreadPost } from '../model/ForumModels';

/** Safe subset returned by the ArkWeb forum-list extraction script. */
export interface WebThreadSummary {
  id: string;
  title: string;
  authorName: string;
  authorUserId?: string;
  titleColor?: string;
  replyCount: number;
  viewCount: number;
  threadType: string;
  hasImage: boolean;
  /** Original topic creation time extracted beside the original author. */
  createdAt: string;
  isPinned: boolean;
}

/**
 * A visible forum thread type from the current board's `.threadtype` menu.
 * Its numeric value is the same `typeid` accepted by 4D4Y's new-topic form.
 */
export interface ForumThreadType {
  value: string;
  label: string;
}

export interface ForumWebPayload {
  fid: string;
  /** Empty for unfiltered lists; optional for older synthetic fixtures. */
  filterTypeId?: string;
  page: number;
  /** The explicitly linked next board page, or 0 when the forum exposes none. */
  nextPage: number;
  loadSequence: number;
  layout: string;
  threadLinkCount: number;
  forumRowCount: number;
  /** Header-only table confirmed from the actual forum empty-page template. */
  hasEmptyForumTable?: boolean;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  /** Current board-level thread types, never inferred from individual posts. */
  threadTypes: ForumThreadType[];
  threads: WebThreadSummary[];
}

/** Value-free permission probe for one board's new-topic form. */
export interface ForumNewThreadPreflightPayload {
  forumId: string;
  probeSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  hasSubjectField: boolean;
  hasMessageField: boolean;
  hasFormhashField: boolean;
  hasPosttimeField: boolean;
  hasWysiwygField: boolean;
  hasSubmitAction: boolean;
  errorMessage: string;
}

export interface ThreadWebPayload {
  threadId: string;
  /** Optional for older templates; only the trusted forum breadcrumb supplies it. */
  forumId?: string;
  /** Current account id extracted only from the signed-in page header. */
  viewerUserId: string;
  title: string;
  currentPage: number;
  lastPage: number;
  loadSequence: number;
  layout: string;
  postNodeCount: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  /** Visible forum denial/not-found message when no post layout is present. */
  errorMessage: string;
  /** Present only on the first page when 4D4Y supplies a poll form. */
  poll?: ThreadPoll;
  posts: ThreadPost[];
}

/**
 * Deliberately value-free description of a reply form returned by ArkWeb.
 * CSRF values are never logged, rendered, or persisted; the eventual submit
 * implementation must obtain a fresh form and keep its values in memory only.
 */
export interface ReplyPreflightPayload {
  threadId: string;
  loadSequence: number;
  layout: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionPath: string;
  messageFieldName: string;
  hasFormhashField: boolean;
  hasPosttimeField: boolean;
  hasWysiwygField: boolean;
  hasReplySubmitAction: boolean;
  submitControlName: string;
  errorMessage: string;
}

/** Value-free terminal result for one ArkWeb form submission attempt. */
export interface ReplySubmissionPayload {
  threadId: string;
  submissionSequence: number;
  succeeded: boolean;
  loginRequired: boolean;
  errorMessage: string;
}

/** Page-level state observed before DOM extraction results are rendered. */
export enum FourD4yPageAccessState {
  Available = 'available',
  LoginRequired = 'loginRequired'
}

/** Native reader state derived from a checked ArkWeb extraction payload. */
export enum FourD4yReaderOutcome {
  Content = 'content',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

export function parseForumWebPayload(rawResult: string): ForumWebPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: ForumWebPayload = JSON.parse(payloadText) as ForumWebPayload;
    if (typeof payload.fid !== 'string' || typeof payload.page !== 'number' ||
      (payload.filterTypeId !== undefined && (typeof payload.filterTypeId !== 'string' ||
        (payload.filterTypeId !== '' && !/^[1-9]\d*$/.test(payload.filterTypeId)))) ||
      typeof payload.nextPage !== 'number' ||
      typeof payload.loadSequence !== 'number' || typeof payload.layout !== 'string' ||
      typeof payload.threadLinkCount !== 'number' || typeof payload.forumRowCount !== 'number' ||
      (payload.hasEmptyForumTable !== undefined && typeof payload.hasEmptyForumTable !== 'boolean') ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      !Array.isArray(payload.threadTypes) || !areForumThreadTypesValid(payload.threadTypes) ||
      !Array.isArray(payload.threads) || !areWebThreadSummariesValid(payload.threads)) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseThreadWebPayload(rawResult: string): ThreadWebPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: ThreadWebPayload = JSON.parse(payloadText) as ThreadWebPayload;
    if (typeof payload.threadId !== 'string' || typeof payload.viewerUserId !== 'string' ||
      (payload.forumId !== undefined && (typeof payload.forumId !== 'string' ||
        (payload.forumId.length > 0 && !/^\d{1,20}$/.test(payload.forumId)))) ||
      (payload.viewerUserId.length > 0 && !/^\d+$/.test(payload.viewerUserId)) ||
      typeof payload.title !== 'string' ||
      typeof payload.currentPage !== 'number' || typeof payload.lastPage !== 'number' ||
      typeof payload.loadSequence !== 'number' || typeof payload.layout !== 'string' ||
      typeof payload.postNodeCount !== 'number' || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.errorMessage !== 'string' ||
      !Array.isArray(payload.posts) || !areThreadPostsValid(payload.posts) ||
      (payload.poll !== undefined && !isThreadPollValid(payload.poll))) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseForumNewThreadPreflightPayload(rawResult: string): ForumNewThreadPreflightPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: ForumNewThreadPreflightPayload = JSON.parse(payloadText) as ForumNewThreadPreflightPayload;
    if (!isDigitsOnly(payload.forumId) || typeof payload.probeSequence !== 'number' ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
      typeof payload.hasSubjectField !== 'boolean' || typeof payload.hasMessageField !== 'boolean' ||
      typeof payload.hasFormhashField !== 'boolean' || typeof payload.hasPosttimeField !== 'boolean' ||
      typeof payload.hasWysiwygField !== 'boolean' || typeof payload.hasSubmitAction !== 'boolean' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseReplyPreflightPayload(rawResult: string): ReplyPreflightPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: ReplyPreflightPayload = JSON.parse(payloadText) as ReplyPreflightPayload;
    if (typeof payload.threadId !== 'string' || typeof payload.loadSequence !== 'number' ||
      typeof payload.layout !== 'string' || !isFourD4yPageAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.formFound !== 'boolean' ||
      typeof payload.formMethod !== 'string' || typeof payload.actionPath !== 'string' ||
      typeof payload.messageFieldName !== 'string' || typeof payload.hasFormhashField !== 'boolean' ||
      typeof payload.hasPosttimeField !== 'boolean' || typeof payload.hasWysiwygField !== 'boolean' ||
      typeof payload.hasReplySubmitAction !== 'boolean' ||
      typeof payload.submitControlName !== 'string' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseReplySubmissionPayload(rawResult: string): ReplySubmissionPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: ReplySubmissionPayload = JSON.parse(payloadText) as ReplySubmissionPayload;
    if (typeof payload.threadId !== 'string' || typeof payload.submissionSequence !== 'number' ||
      typeof payload.succeeded !== 'boolean' || typeof payload.loginRequired !== 'boolean' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedForumWebPayload(payload: ForumWebPayload, forumId: string,
  page: number, loadSequence: number, filterTypeId: string = ''): boolean {
  return payload.fid === forumId && payload.page === page && payload.loadSequence === loadSequence &&
    (payload.filterTypeId || '') === filterTypeId;
}

export function isExpectedThreadWebPayload(payload: ThreadWebPayload, threadId: string,
  page: number, loadSequence: number): boolean {
  return payload.threadId === threadId && payload.currentPage === page &&
    payload.loadSequence === loadSequence;
}

export function isExpectedForumNewThreadPreflightPayload(payload: ForumNewThreadPreflightPayload,
  forumId: string, probeSequence: number): boolean {
  return payload.forumId === forumId && payload.probeSequence === probeSequence;
}

export function isReadyForumNewThreadForm(payload: ForumNewThreadPreflightPayload): boolean {
  // 4D4Y can include Cloudflare's passive challenge-platform script in an
  // otherwise ordinary page (including an explicit permission-denied page).
  // A complete, same-origin POST form is the authoritative capability signal;
  // the generic marker remains useful only when no such server response exists.
  return payload.accessState === FourD4yPageAccessState.Available &&
    payload.formFound && payload.formMethod === 'post' && payload.hasSubjectField &&
    payload.hasMessageField && payload.hasFormhashField && payload.hasPosttimeField &&
    payload.hasWysiwygField && payload.hasSubmitAction;
}

export function isExpectedReplyPreflightPayload(payload: ReplyPreflightPayload, threadId: string,
  loadSequence: number): boolean {
  return payload.threadId === threadId && payload.loadSequence === loadSequence;
}

export function isExpectedReplySubmissionPayload(payload: ReplySubmissionPayload, threadId: string,
  submissionSequence: number): boolean {
  return payload.threadId === threadId && payload.submissionSequence === submissionSequence;
}

/**
 * ArkWeb lifecycle callbacks can arrive after a newer navigation has started.
 * The app puts an opaque sequence in every reader URL, so callbacks must match
 * both the expected forum endpoint and that current sequence before touching UI.
 */
export function isCurrentFourD4yWebRequest(url: string, endpointPath: string,
  loadSequence: number): boolean {
  const token: RegExp = new RegExp('[?&]oh_load=' + loadSequence + '(?:&|$)');
  return url.indexOf(endpointPath) >= 0 && token.test(url);
}

/**
 * A login form can coexist with a Cloudflare script on the same 4D4Y page.
 * Login therefore wins over the generic verification branch.
 */
export function getForumReaderOutcome(payload: ForumWebPayload): FourD4yReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yReaderOutcome.LoginRequired;
  }
  if (payload.hasChallenge && payload.threads.length === 0) {
    return FourD4yReaderOutcome.VerificationRequired;
  }
  if (payload.threads.length === 0 && payload.hasEmptyForumTable === true &&
    payload.layout === 'legacy-empty' && payload.threadLinkCount === 0 && payload.forumRowCount === 0 &&
    payload.nextPage === 0) {
    return FourD4yReaderOutcome.Content;
  }
  return payload.threads.length === 0 ? FourD4yReaderOutcome.UnsupportedLayout : FourD4yReaderOutcome.Content;
}

export function getThreadReaderOutcome(payload: ThreadWebPayload): FourD4yReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yReaderOutcome.LoginRequired;
  }
  if (payload.hasChallenge && payload.posts.length === 0) {
    return FourD4yReaderOutcome.VerificationRequired;
  }
  return payload.posts.length === 0 ? FourD4yReaderOutcome.UnsupportedLayout : FourD4yReaderOutcome.Content;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function areForumThreadTypesValid(threadTypes: ForumThreadType[]): boolean {
  if (threadTypes.length > 30) {
    return false;
  }
  const seenValues: string[] = [];
  for (let index: number = 0; index < threadTypes.length; index += 1) {
    const threadType: ForumThreadType = threadTypes[index];
    if (typeof threadType.value !== 'string' || !/^\d+$/.test(threadType.value) ||
      threadType.value === '0' || typeof threadType.label !== 'string' ||
      threadType.label.length === 0 || threadType.label.length > 80 ||
      seenValues.indexOf(threadType.value) >= 0) {
      return false;
    }
    seenValues.push(threadType.value);
  }
  return true;
}

function areWebThreadSummariesValid(threads: WebThreadSummary[]): boolean {
  if (threads.length > 200) {
    return false;
  }
  for (let index: number = 0; index < threads.length; index += 1) {
    const thread: WebThreadSummary = threads[index];
    if (typeof thread.id !== 'string' || !/^\d+$/.test(thread.id) ||
      typeof thread.title !== 'string' || typeof thread.authorName !== 'string' ||
      (thread.authorUserId !== undefined && (typeof thread.authorUserId !== 'string' ||
        (thread.authorUserId.length > 0 && !/^\d{1,20}$/.test(thread.authorUserId)))) ||
      (thread.titleColor !== undefined && (typeof thread.titleColor !== 'string' ||
        (thread.titleColor.length > 0 && !/^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i.test(thread.titleColor)))) ||
      typeof thread.replyCount !== 'number' || !Number.isFinite(thread.replyCount) || thread.replyCount < 0 ||
      typeof thread.viewCount !== 'number' || !Number.isFinite(thread.viewCount) || thread.viewCount < 0 ||
      typeof thread.threadType !== 'string' || thread.threadType.length > 80 ||
      typeof thread.hasImage !== 'boolean' ||
      typeof thread.createdAt !== 'string' || typeof thread.isPinned !== 'boolean') {
      return false;
    }
  }
  return true;
}

function areThreadPostsValid(posts: ThreadPost[]): boolean {
  if (posts.length > 200) {
    return false;
  }
  for (let postIndex: number = 0; postIndex < posts.length; postIndex += 1) {
    const post: ThreadPost = posts[postIndex];
    if (typeof post.id !== 'string' || typeof post.threadId !== 'string' ||
      typeof post.floor !== 'number' || !Number.isFinite(post.floor) || post.floor < 1 ||
      (post.hasExplicitFloor !== undefined && typeof post.hasExplicitFloor !== 'boolean') ||
      typeof post.authorName !== 'string' ||
      (post.authorUserId !== undefined && (typeof post.authorUserId !== 'string' ||
        !/^\d{1,20}$/.test(post.authorUserId))) ||
      (post.publishedAt !== undefined && typeof post.publishedAt !== 'string') ||
      (post.statusText !== undefined && (typeof post.statusText !== 'string' || post.statusText.length > 240)) ||
      !Array.isArray(post.content) || post.content.length > 500) {
      return false;
    }
    for (let contentIndex: number = 0; contentIndex < post.content.length; contentIndex += 1) {
      const content = post.content[contentIndex];
      if (content === null || typeof content !== 'object' ||
        ['text', 'quote', 'emoji', 'image', 'attachment', 'link', 'video'].indexOf(content.kind) < 0 ||
        typeof content.value !== 'string' ||
        (content.url !== undefined && typeof content.url !== 'string') ||
        (content.previewUrl !== undefined && typeof content.previewUrl !== 'string') ||
        (content.isSmallText !== undefined && (typeof content.isSmallText !== 'boolean' ||
          (content.isSmallText && content.kind !== 'text' && content.kind !== 'link'))) ||
        (content.quoteAuthor !== undefined && (typeof content.quoteAuthor !== 'string' ||
          content.quoteAuthor.length > 120)) ||
        (content.quoteThreadId !== undefined && (typeof content.quoteThreadId !== 'string' ||
          !/^\d{1,20}$/.test(content.quoteThreadId))) ||
        (content.quotePostId !== undefined && (typeof content.quotePostId !== 'string' ||
          !/^\d{1,20}$/.test(content.quotePostId))) ||
        (content.quoteFloor !== undefined && (typeof content.quoteFloor !== 'number' ||
          !Number.isFinite(content.quoteFloor) || content.quoteFloor < 1)) ||
        (content.quoteTime !== undefined && (typeof content.quoteTime !== 'string' ||
          content.quoteTime.length > 120))) {
        return false;
      }
    }
  }
  return true;
}

/**
 * Poll option ids are transient server selection values, never authentication
 * data. Restrict their shape and size so a changed page cannot turn the
 * ArkWeb bridge into an arbitrary HTML transport.
 */
function isThreadPollValid(poll: ThreadPoll): boolean {
  if (typeof poll.infoText !== 'string' || poll.infoText.length > 240 ||
    typeof poll.footerText !== 'string' || poll.footerText.length > 240 ||
    typeof poll.maxSelections !== 'number' || !Number.isFinite(poll.maxSelections) ||
    poll.maxSelections < 1 || poll.maxSelections > 30 ||
    typeof poll.isMultipleChoice !== 'boolean' || typeof poll.isVoteFormAvailable !== 'boolean' ||
    !Array.isArray(poll.options) || poll.options.length < 2 || poll.options.length > 30) {
    return false;
  }
  const optionIds: string[] = [];
  for (let index: number = 0; index < poll.options.length; index += 1) {
    const option = poll.options[index];
    if (typeof option.id !== 'string' || option.id.length > 20 ||
      (option.id.length > 0 && !/^\d+$/.test(option.id)) ||
      typeof option.label !== 'string' || option.label.length === 0 || option.label.length > 320 ||
      typeof option.resultText !== 'string' || option.resultText.length > 160 ||
      (option.id.length > 0 && optionIds.indexOf(option.id) >= 0)) {
      return false;
    }
    if (option.id.length > 0) {
      optionIds.push(option.id);
    }
  }
  return !poll.isVoteFormAvailable || optionIds.length === poll.options.length;
}

/** The mobile 4D4Y page has 50 posts per page, including the original post. */
export function estimateLastPageFromReplyCount(replyCount: number): number {
  const safeReplyCount: number = Number.isFinite(replyCount) ? Math.max(0, Math.floor(replyCount)) : 0;
  return Math.max(1, Math.ceil((safeReplyCount + 1) / 50));
}

/**
 * Mirrors the current extraction-script guard. Protocol allow-listing is a
 * separate navigation-boundary decision and is intentionally not widened here.
 */
export function isAllowedExtractedContentUrl(value: string): boolean {
  const normalized: string = value.trim().toLowerCase();
  return normalized.length > 0 && normalized.indexOf('javascript:') !== 0 &&
    normalized.indexOf('data:') !== 0 && normalized.indexOf('#') !== 0;
}

/**
 * Mobile 4D4Y pages put a reply author's profile link in `.replytop`, while
 * the original post's author is described by the surrounding `.sub` line.
 * Keep this priority explicit so an original-post header can never overwrite
 * a reply's own author.
 */
export function select4D4yPostAuthor(replyAuthorName: string, originalAuthorLine: string,
  fallbackAuthorName: string = ''): string {
  const replyAuthor: string = normalize4D4yAuthorName(replyAuthorName);
  if (replyAuthor !== '') {
    return replyAuthor;
  }
  const originalAuthorMatch: RegExpExecArray | null =
    new RegExp('^(.*?)\\s*\\u53d1\\u8868\\u4e8e').exec(originalAuthorLine.trim());
  if (originalAuthorMatch !== null) {
    const originalAuthor: string = normalize4D4yAuthorName(originalAuthorMatch[1]);
    if (originalAuthor !== '') {
      return originalAuthor;
    }
  }
  return normalize4D4yAuthorName(fallbackAuthorName);
}

/**
 * A mobile attachment menu belongs to an inline image only when it is marked
 * `attachimg`, or its `aimg_<id>_menu` id points at the rendered image id.
 * Other attachments (APK, archive, and so on) must remain downloadable.
 */
export function is4D4yInlineImageAttachment(classNames: string, attachmentMenuId: string,
  linkedImageId: string): boolean {
  const classes: string[] = classNames.trim().split(/\s+/);
  for (let index: number = 0; index < classes.length; index += 1) {
    if (classes[index] === 'attachimg') {
      return true;
    }
  }
  const prefix: string = 'aimg_';
  const suffix: string = '_menu';
  if (!attachmentMenuId.startsWith(prefix) || !attachmentMenuId.endsWith(suffix)) {
    return false;
  }
  const imageId: string = attachmentMenuId.substring(0, attachmentMenuId.length - suffix.length);
  return imageId === linkedImageId;
}

/**
 * Legacy 4D4Y pages use `post_<number>` for a real floor, but also expose
 * `post_rate_div_<number>` and `post_new` helper elements. Only the former
 * is a post container.
 */
export function is4D4yLegacyPostId(value: string): boolean {
  return /^post_\d+$/.test(value);
}

/**
 * In the authenticated 4D4Y mobile Discovery list, a pinned topic title is
 * rendered with both bold weight and the forum's red #EE1B2E title colour.
 * Requiring both declarations prevents ordinary bold or red titles from being
 * classified as pinned.
 */
export function is4D4yPinnedMobileTitleStyle(style: string): boolean {
  return /font-weight\s*:\s*bold\b/i.test(style) && /color\s*:\s*#ee1b2e\b/i.test(style);
}

function normalize4D4yAuthorName(value: string): string {
  const normalized: string = value.trim();
  return normalized === '发表回复' || normalized === '回复' || normalized === '引用' ? '' : normalized;
}

/**
 * Navigation destinations supported by the native reader.  This deliberately
 * mirrors HiPDA NG's split: recognize its own thread links first, then leave
 * non-forum URLs to the operating system instead of embedding them in ArkWeb.
 */
export enum ForumLinkKind {
  InternalThread = 'internalThread',
  ExternalWeb = 'externalWeb',
  Attachment = 'attachment',
  Email = 'email',
  Phone = 'phone',
  Unsupported = 'unsupported'
}

export interface ForumLinkRoute {
  kind: ForumLinkKind;
  url: string;
  threadId: string;
  page: number;
  floor: number;
}

export function resolveForumLink(url: string, contentKind: string, linkText: string = ''): ForumLinkRoute {
  const normalizedUrl: string = url.trim();
  const unsupported: ForumLinkRoute = createForumLinkRoute(ForumLinkKind.Unsupported, normalizedUrl);
  if (!isAllowedExtractedContentUrl(normalizedUrl)) {
    return unsupported;
  }

  // NG gives forum attachments their own download action before ordinary URL
  // dispatch. The Harmony reader currently delegates that action to a browser.
  if (contentKind === 'attachment') {
    return createForumLinkRoute(ForumLinkKind.Attachment, normalizedUrl);
  }

  const lowercaseUrl: string = normalizedUrl.toLowerCase();
  if (lowercaseUrl.startsWith('mailto:')) {
    return createForumLinkRoute(ForumLinkKind.Email, normalizedUrl);
  }
  if (lowercaseUrl.startsWith('tel:')) {
    return createForumLinkRoute(ForumLinkKind.Phone, normalizedUrl);
  }
  if (!isHttpUrl(lowercaseUrl)) {
    return unsupported;
  }

  const threadId: string = extract4D4yThreadId(normalizedUrl);
  if (threadId !== '') {
    const floor: number = extractQuotedFloor(linkText);
    return {
      kind: ForumLinkKind.InternalThread,
      url: normalizedUrl,
      threadId: threadId,
      page: extract4D4yPage(normalizedUrl, floor),
      floor: floor
    };
  }
  return createForumLinkRoute(ForumLinkKind.ExternalWeb, normalizedUrl);
}

function createForumLinkRoute(kind: ForumLinkKind, url: string): ForumLinkRoute {
  return { kind: kind, url: url, threadId: '', page: 1, floor: 0 };
}

function isHttpUrl(lowercaseUrl: string): boolean {
  return lowercaseUrl.startsWith('https://') || lowercaseUrl.startsWith('http://');
}

function extract4D4yThreadId(url: string): string {
  if (!is4D4yUrl(url)) {
    return '';
  }
  const path: string = getUrlPath(url).toLowerCase();
  if (path !== '/forum/viewthread.php' && path !== '/forum/redirect.php') {
    return '';
  }
  const threadId: string = getQueryValue(url, 'tid') || getQueryValue(url, 'ptid');
  return isDigitsOnly(threadId) ? threadId : '';
}

function extract4D4yPage(url: string, floor: number): number {
  const rawPage: string = getQueryValue(url, 'page');
  if (isDigitsOnly(rawPage)) {
    const page: number = Number(rawPage);
    return Number.isFinite(page) ? Math.max(1, Math.floor(page)) : 1;
  }
  return floor > 0 ? Math.floor((floor - 1) / 50) + 1 : 1;
}

function extractQuotedFloor(linkText: string): number {
  const floorMatch: RegExpExecArray | null = new RegExp('(\\d+)\\s*#').exec(linkText);
  if (floorMatch === null) {
    return 0;
  }
  const floor: number = Number(floorMatch[1]);
  return Number.isFinite(floor) ? Math.max(0, Math.floor(floor)) : 0;
}

function is4D4yUrl(url: string): boolean {
  const protocolSeparator: number = url.indexOf('://');
  if (protocolSeparator <= 0) {
    return false;
  }
  const authorityStart: number = protocolSeparator + 3;
  const pathStart: number = url.indexOf('/', authorityStart);
  const authority: string = (pathStart === -1 ? url.substring(authorityStart) :
    url.substring(authorityStart, pathStart)).toLowerCase();
  const host: string = authority.split(':')[0];
  return host === '4d4y.com' || host === 'www.4d4y.com';
}

function getUrlPath(url: string): string {
  const authorityStart: number = url.indexOf('://') + 3;
  const pathStart: number = url.indexOf('/', authorityStart);
  if (pathStart === -1) {
    return '/';
  }
  const queryStart: number = url.indexOf('?', pathStart);
  const fragmentStart: number = url.indexOf('#', pathStart);
  let pathEnd: number = url.length;
  if (queryStart !== -1) {
    pathEnd = queryStart;
  }
  if (fragmentStart !== -1 && fragmentStart < pathEnd) {
    pathEnd = fragmentStart;
  }
  return url.substring(pathStart, pathEnd);
}

function getQueryValue(url: string, key: string): string {
  const queryStart: number = url.indexOf('?');
  if (queryStart === -1) {
    return '';
  }
  const fragmentStart: number = url.indexOf('#', queryStart);
  const query: string = fragmentStart === -1 ? url.substring(queryStart + 1) :
    url.substring(queryStart + 1, fragmentStart);
  const parts: string[] = query.split('&');
  for (let index: number = 0; index < parts.length; index += 1) {
    const pair: string[] = parts[index].split('=');
    if (pair.length > 1 && pair[0].toLowerCase() === key.toLowerCase()) {
      return pair[1];
    }
  }
  return '';
}

function isDigitsOnly(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let index: number = 0; index < value.length; index += 1) {
    const code: number = value.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
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
