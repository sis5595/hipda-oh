import { ForumSmileyButton } from '../composer/ForumSmileyButton';
import { common, Want } from '@kit.AbilityKit';
import { bindFourD4yCollectionCache } from '../common/FourD4yCollectionCacheBinding';
import { FourD4yRowVersions } from '../common/FourD4yRowVersions';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { PostContent, ThreadPoll, ThreadPollOption, ThreadPost } from '../../domain/model/ForumModels';
import { estimateLastPageFromReplyCount, ForumLinkKind, FourD4yPageAccessState, FourD4yReaderOutcome, getThreadReaderOutcome, isCurrentFourD4yWebRequest, isExpectedReplyPreflightPayload, isExpectedReplySubmissionPayload, isExpectedThreadWebPayload, parseReplyPreflightPayload, parseReplySubmissionPayload, parseThreadWebPayload, ReplyPreflightPayload, ReplySubmissionPayload, resolveForumLink, ThreadWebPayload } from '../../domain/reader/FourD4yReaderContracts';
import { WebRouteState } from '../web/WebRouteState';
import { ImageViewerItem, ImageViewerRouteState } from '../image/ImageViewerRouteState';
import { createThreadRouteParams, ThreadRouteParams } from './ThreadRouteState';
import { createUserProfileRouteParams } from '../profile/UserProfileRouteState';
import { buildFourD4yAvatarUrl } from '../../domain/profile/FourD4yAvatar';
import { createEditComposerRouteParams, createQuoteComposerRouteParams, createReplyComposerRouteParams,
  isForumComposerPostEditedResult, isForumComposerReplyPublishedResult } from '../composer/ForumComposerRouteState';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { buildFourD4yPostFormBoundaryScript, isCurrentFourD4yPostPreflightUrl } from '../../domain/composer/FourD4yPostFormBoundary';
import { FourD4yFavoriteState } from '../../domain/favorite/FourD4yFavoriteState';
import { buildFourD4yCollectionPaginationScript, buildFourD4yCollectionVerificationBoundaryScript, FourD4yCollectionVerificationStep,
  getFourD4yCollectionVerificationStep } from '../../domain/favorite/FourD4yCollectionPagination';
import { buildFourD4yFavoriteOperationUrl, FourD4yFavoriteMutationStartPayload, FourD4yFavoriteOperationPayload, FourD4yFavoriteVerificationPayload,
  isAllowedFourD4yFavoriteOperationUrl,
  isExpectedFourD4yFavoriteMutationStartPayload, isExpectedFourD4yFavoriteOperationPayload,
  isExpectedFourD4yFavoriteVerificationPayload, parseFourD4yFavoriteMutationStartPayload,
  parseFourD4yFavoriteOperationPayload, parseFourD4yFavoriteVerificationPayload } from '../../domain/favorite/FourD4yFavoriteContracts';
import { FourD4yAttentionState } from '../../domain/attention/FourD4yAttentionState';
import { FourD4yAttentionMutationStartPayload, FourD4yAttentionVerificationPayload,
  buildFourD4yAttentionOperationUrl, isAllowedFourD4yAttentionOperationUrl,
  isExpectedFourD4yAttentionMutationStartPayload, isExpectedFourD4yAttentionVerificationPayload,
  parseFourD4yAttentionMutationStartPayload, parseFourD4yAttentionVerificationPayload } from
  '../../domain/attention/FourD4yAttentionContracts';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';
import { FourD4yBlacklistPagePayload, FourD4yBlacklistReaderOutcome, buildFourD4yBlacklistUrl,
  getFourD4yBlacklistReaderOutcome, isCurrentFourD4yBlacklistRequest,
  isExpectedFourD4yBlacklistPagePayload, normalizeFourD4yBlacklistUserName,
  parseFourD4yBlacklistPagePayload } from '../../domain/blacklist/FourD4yBlacklistContracts';
import { FourD4yVotePreflightPayload, FourD4yVoteSubmissionStartPayload,
  FourD4yVoteVerificationPayload, isConfirmedFourD4yVoteResult,
  isExpectedFourD4yVotePreflightPayload, isExpectedFourD4yVoteSubmissionStartPayload,
  isExpectedFourD4yVoteVerificationPayload, isReadyFourD4yVoteForm,
  parseFourD4yVotePreflightPayload, parseFourD4yVoteSubmissionStartPayload,
  parseFourD4yVoteVerificationPayload } from '../../domain/poll/FourD4yPollContracts';
import { FourD4yUserSettingsStore } from '../../data/local/FourD4yUserSettingsStore';
import { FourD4yImageLoadPolicy, FourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';
import { appendFourD4yPostTail } from '../../domain/settings/FourD4yPostTail';
import { FourD4yReadHistoryEntry } from '../../domain/history/FourD4yReadHistory';
import { FourD4yReadHistoryState } from '../../domain/history/FourD4yReadHistoryState';
import { createFourD4yAttachmentFileName, isAllowedFourD4yAttachmentDownloadUrl } from
  '../../domain/attachment/FourD4yAttachmentContracts';
import { buildFourD4yPostDeletionPreflightUrl, FourD4yPostDeletionPreflightPayload,
  FourD4yPostDeletionSubmissionStartPayload, FourD4yPostDeletionVerificationPayload,
  isConfirmedFourD4yPostDeletion,
  isCurrentFourD4yPostDeletionPreflightRequest, isExpectedFourD4yPostDeletionPreflight,
  isExpectedFourD4yPostDeletionSubmissionStart, isExpectedFourD4yPostDeletionVerification,
  isReadyFourD4yPostDeletionForm, parseFourD4yPostDeletionPreflightPayload,
  parseFourD4yPostDeletionSubmissionStartPayload, parseFourD4yPostDeletionVerificationPayload } from
  '../../domain/post/FourD4yPostDeletionContracts';
import { appendFourD4yThreadPosts, buildFourD4yPostCopyText, buildFourD4yPostShareText,
  buildFourD4yThreadPublicUrl, buildFourD4yThreadReaderUrl, buildFourD4yThreadShareText,
  normalizeFourD4yThreadActionId } from
  '../../domain/thread/FourD4yThreadActions';
import { isQualifiedFourD4yRightSwipe } from '../../domain/navigation/FourD4yHorizontalGesture';
import { countObservedLastPageReplies, FourD4yObservedReplyCounts } from
  '../../domain/thread/FourD4yObservedReplyCounts';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { FourD4yThreadMutationState } from '../../domain/thread/FourD4yThreadMutationState';

// Multiple topic pages may retain downloads at once. A page-local counter
// alone can point two independent downloads at the same sandbox file.
let attachmentArtifactSequence: number = 0;

enum ReplyWebOperation {
  Preflight = 'preflight',
  Submit = 'submit'
}

/** Mirrors NG's three reply entry intents without leaking form markup into ArkTS. */
enum QuickReplyMode {
  Thread = 'thread',
  Reply = 'reply',
  Quote = 'quote'
}

/** Source dimensions observed by ArkUI for images on the currently loaded topic page. */
interface FourD4yPostImageSize {
  url: string;
  width: number;
  height: number;
}

@Component
export struct ThreadDetailPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('webRoute') webRoute: WebRouteState;
  @Consume('imageViewerRoute') imageViewerRoute: ImageViewerRouteState;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('favoriteState') favoriteState: FourD4yFavoriteState;
  @Consume('attentionState') attentionState: FourD4yAttentionState;
  @Consume('blacklistState') blacklistState: FourD4yBlacklistState;
  @Consume('readHistoryState') readHistoryState: FourD4yReadHistoryState;
  @Consume('observedReplyCounts') observedReplyCounts: FourD4yObservedReplyCounts;
  @Consume('accountState') accountState: FourD4yAccountState;
  @Consume('threadMutationState') threadMutationState: FourD4yThreadMutationState;
  @State route: ThreadRouteParams = {
    threadId: '',
    threadTitle: '',
    forumId: '',
    replyCount: 0,
    initialPage: 1,
    initialFloor: 0,
    initialPostId: '',
    initialFavoriteState: false,
    initialFavoritePage: 1,
    initialAttentionState: false,
    initialAttentionPage: 1
  };
  @State posts: ThreadPost[] = [];
  private readonly postRowVersions: FourD4yRowVersions<ThreadPost> =
    new FourD4yRowVersions<ThreadPost>((post: ThreadPost): string => post.id);
  @State currentPage: number = 1;
  // currentPage is the loaded range's end after append, not its visible top.
  private firstRenderedPage: number = 1;
  @State lastPage: number = 1;
  @State selectedPage: number = 1;
  @State isPagePickerVisible: boolean = false;
  @State isLoading: boolean = false;
  /** Native pull-to-refresh reloads the visible page without hiding its list. */
  @State isRefreshing: boolean = false;
  @State isLoadingMore: boolean = false;
  @State loadError: string = '';
  @State loadMoreError: string = '';
  @State resolvedTitle: string = '';
  @State threadPageUrl: string = 'https://www.4d4y.com/forum/';
  @State needsWebVerification: boolean = false;
  @State isReplyComposerVisible: boolean = false;
  @State replyDraft: string = '';
  @State smileySelectionStart: number = -1;
  @State smileySelectionEnd: number = -1;
  private readonly smileyTextController: TextAreaController = new TextAreaController();
  @State quickReplyMode: QuickReplyMode = QuickReplyMode.Thread;
  @State quickReplyTargetPostId: string = '';
  @State quickReplyTargetFloor: number = 0;
  @State quickReplyTargetAuthorName: string = '';
  @State isReplyPreflightLoading: boolean = false;
  @State isReplySubmitting: boolean = false;
  @State replyPreflightMessage: string = '';
  @State replySubmissionErrorMessage: string = '';
  @State isReplyFormReady: boolean = false;
  @State replyFormUrl: string = 'about:blank';
  @State isFavoriteOperationLoading: boolean = false;
  @State isFavoriteSubmitting: boolean = false;
  @State isFavorite: boolean = false;
  @State favoriteActionLabel: string = '';
  @State favoriteActionMessage: string = '';
  @State isAttentionOperationLoading: boolean = false;
  @State isAttentionSubmitting: boolean = false;
  @State isAttentioned: boolean = false;
  @State attentionActionMessage: string = '';
  @State initialPostListIndex: number = 0;
  /** Poll data is a read-only projection of the current ArkWeb document. */
  @State poll: ThreadPoll | undefined = undefined;
  /** Kept only in the active page instance; choices are never persisted. */
  @State selectedPollOptionIds: string[] = [];
  @State isVotePreflightLoading: boolean = false;
  @State isVoteSubmitting: boolean = false;
  @State pollActionMessage: string = '';
  /** A value-only copy makes ArkUI re-render when the server snapshot changes. */
  @State blacklistedUserNames: string[] = [];
  @State imageLoadPolicy: FourD4yImageLoadPolicy = FourD4yImageLoadPolicy.Automatic;
  @State postLineSpacing: number = 1;
  @State loadedPostImageUrls: string[] = [];
  /** Keeps ordinary pictures naturally sized while long images stay compact in the post stream. */
  @State postImageSizes: FourD4yPostImageSize[] = [];
  /** Current signed-in UID observed in the active thread document. */
  @State viewerUserId: string = '';
  /** NG's topic-level "only author" mode is a server query, never a local page-only filter. */
  @State authorOnlyUserId: string = '';
  @State threadAuthorUserId: string = '';
  @State threadAuthorName: string = '';
  @State isThreadAuthorResolving: boolean = false;
  /** A single post can temporarily switch to NG-style plain-text selection mode. */
  @State selectablePostId: string = '';
  /** P-16 begins with a GET-only capability probe; no deletion is sent here. */
  @State isPostDeletionPreflightLoading: boolean = false;
  @State isPostDeletionSubmitting: boolean = false;
  @State postDeletionMessage: string = '';

  private readonly threadWebController: webview.WebviewController = new webview.WebviewController();
  private readonly replyWebController: webview.WebviewController = new webview.WebviewController();
  private readonly postDeletionWebController: webview.WebviewController = new webview.WebviewController();
  private readonly voteWebController: webview.WebviewController = new webview.WebviewController();
  private readonly favoriteVerificationWebController: webview.WebviewController = new webview.WebviewController();
  private readonly attentionVerificationWebController: webview.WebviewController = new webview.WebviewController();
  private readonly blacklistSnapshotWebController: webview.WebviewController = new webview.WebviewController();
  private readonly attachmentDownloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private readonly postListScroller: Scroller = new Scroller();
  private webLoadSequence: number = 0;
  private requestedPage: number = 1;
  private isAppendingThreadPage: boolean = false;
  private pendingFloor: number = 0;
  private pendingPostId: string = '';
  private postLayoutAnchorIndex: number = -1;
  private postLayoutAnchorRevision: number = 0;
  private postLayoutAnchorQueued: boolean = false;
  /** One-shot endpoint target used by the double-tap page picker. */
  private pendingFirstPostOfPage: boolean = false;
  /**
   * NG returns to the last floor of the freshly loaded last page after a
   * confirmed reply.  This is intentionally a one-shot UI target instead of
   * a calculated floor number: another member may reply between the form
   * submission and the read-back, and only the loaded page is authoritative.
   */
  private pendingLastPostOfPage: boolean = false;
  /** Captured before Refresh replaces the server-rendered page projection. */
  private pendingRefreshScrollOffset: number = -1;
  private readonly webLoadTimeoutMillis: number = 30000;
  private webLoadTimeoutId: number = -1;
  private terminalLoadSequence: number = 0;
  private isThreadWebControllerAttached: boolean = false;
  private isReplyWebControllerAttached: boolean = false;
  private isPostDeletionWebControllerAttached: boolean = false;
  private isVoteWebControllerAttached: boolean = false;
  private isFavoriteVerificationWebControllerAttached: boolean = false;
  private isAttentionVerificationWebControllerAttached: boolean = false;
  private isBlacklistSnapshotWebControllerAttached: boolean = false;
  private replyPreflightSequence: number = 0;
  private replyPreflightTimeoutId: number = -1;
  private replySubmissionSequence: number = 0;
  private replyWebOperation: ReplyWebOperation = ReplyWebOperation.Preflight;
  private pendingReplyDraft: string = '';
  private postTailSettings: FourD4yUserSettings | undefined = undefined;
  private readingReplyPreflightSequence: number = -1;
  private readonly quickReplyInputId: string = 'hipda-oh-quick-reply-input';
  private quickReplySendLongPressed: boolean = false;
  private previousQuickReplyKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private hasAdjustedQuickReplyKeyboardAvoidMode: boolean = false;
  private isPostContextMenuVisible: boolean = false;
  private postDeletionPreflightUrl: string = '';
  private postDeletionPreflightSequence: number = 0;
  private postDeletionPreflightPostId: string = '';
  private postDeletionPreflightPage: number = 1;
  private postDeletionPreflightTimeoutId: number = -1;
  private postDeletionFormReady: boolean = false;
  private postDeletionConfirmationPending: boolean = false;
  private postDeletionSubmissionSequence: number = 0;
  private postDeletionSubmissionTimeoutId: number = -1;
  private postDeletionVerificationPollTimeoutId: number = -1;
  private postDeletionVerificationAttempt: number = 0;
  private isPostDeletionVerificationLoading: boolean = false;
  private postDeletionTargetWasFirstPost: boolean = false;
  private voteFormUrl: string = 'about:blank';
  private votePreflightSequence: number = 0;
  private voteSubmissionSequence: number = 0;
  private voteVerificationAttempt: number = 0;
  private voteOperationTimeoutId: number = -1;
  private voteVerificationPollTimeoutId: number = -1;
  /** The menu must react when ArkWeb finishes discovering/falling back to an action. */
  @State favoriteOperationUrl: string = '';
  private favoriteOperationSequence: number = 0;
  private favoriteSubmissionSequence: number = 0;
  private favoriteSubmissionWasRemoval: boolean = false;
  private favoriteVerificationAttempt: number = 0;
  private favoriteVerificationPage: number = 1;
  private favoriteVerificationExpectedState: boolean = false;
  private favoriteSubmissionTimeoutId: number = -1;
  private favoriteSubmissionPollTimeoutId: number = -1;
  // Both topic actions feed bindMenu, so their operation URLs are reactive.
  @State attentionOperationUrl: string = '';
  private attentionOperationSequence: number = 0;
  private attentionSubmissionSequence: number = 0;
  private attentionSubmissionWasRemoval: boolean = false;
  private attentionVerificationAttempt: number = 0;
  private attentionVerificationPage: number = 1;
  private attentionVerificationExpectedState: boolean = false;
  private attentionSubmissionTimeoutId: number = -1;
  private attentionSubmissionPollTimeoutId: number = -1;
  private blacklistSnapshotUrl: string = '';
  private blacklistSnapshotLoadSequence: number = 0;
  private blacklistSnapshotTerminalSequence: number = 0;
  private blacklistSnapshotTimeoutId: number = -1;
  private blacklistStateListenerId: number = -1;
  private readonly blacklistSnapshotTimeoutMillis: number = 30000;
  private isAttachmentDownloadDelegateAttached: boolean = false;
  private isAttachmentPickerActive: boolean = false;
  private isAttachmentDownloadActive: boolean = false;
  private attachmentDownloadSequence: number = 0;
  private attachmentDownloadStartTimeoutId: number = -1;
  private pendingAttachmentUrl: string = '';
  private attachmentDestinationUri: string = '';
  private attachmentTemporaryPath: string = '';
  private attachmentDisplayName: string = '';
  private attachmentDownloadGuid: string = '';
  private isThreadPageAlive: boolean = false;

  aboutToAppear(): void {
    this.isThreadPageAlive = true;
    this.observedReplyCounts.syncSession(this.accountState.getSessionGeneration());
    this.subscribeToBlacklistState();
    void this.restoreReaderSettings();
  }

  aboutToDisappear(): void {
    this.isThreadPageAlive = false;
    this.cancelPostLayoutAnchor();
    this.webLoadSequence += 1;
    this.replyPreflightSequence += 1;
    this.replySubmissionSequence += 1;
    this.votePreflightSequence += 1;
    this.voteSubmissionSequence += 1;
    this.favoriteOperationSequence += 1;
    this.favoriteSubmissionSequence += 1;
    this.attentionOperationSequence += 1;
    this.attentionSubmissionSequence += 1;
    this.blacklistSnapshotLoadSequence += 1;
    this.postDeletionPreflightSequence += 1;
    this.postDeletionSubmissionSequence += 1;
    this.clearThreadLoadWatchdog();
    this.clearReplyPreflightWatchdog();
    this.clearPostDeletionPreflightWatchdog();
    this.clearPostDeletionSubmissionWatchdog();
    this.clearVoteOperationWatchdog();
    this.clearFavoriteSubmissionWatchdog();
    this.clearAttentionSubmissionWatchdog();
    this.clearBlacklistSnapshotWatchdog();
    this.unsubscribeFromBlacklistState();
    this.restoreQuickReplyKeyboardAvoidMode();
  }

  private initializeRoute(route: ThreadRouteParams): void {
    this.route = route;
    this.pendingFloor = route.initialFloor;
    this.pendingPostId = route.initialPostId;
    this.pendingFirstPostOfPage = false;
    this.pendingLastPostOfPage = false;
    this.pendingRefreshScrollOffset = -1;
    this.isRefreshing = false;
    this.isReplyComposerVisible = false;
    this.replyDraft = '';
    this.quickReplyMode = QuickReplyMode.Thread;
    this.quickReplyTargetPostId = '';
    this.quickReplyTargetFloor = 0;
    this.quickReplyTargetAuthorName = '';
    this.restoreQuickReplyKeyboardAvoidMode();
    this.lastPage = Math.max(this.estimateLastPage(), this.route.initialPage);
    this.isLoadingMore = false;
    this.loadMoreError = '';
    this.isAppendingThreadPage = false;
    this.favoriteOperationUrl = '';
    this.isFavorite = route.initialFavoriteState || this.favoriteState.isFavorite(route.threadId);
    this.favoriteActionLabel = '';
    this.favoriteActionMessage = '';
    this.isFavoriteOperationLoading = false;
    this.isFavoriteSubmitting = false;
    this.favoriteSubmissionWasRemoval = false;
    this.favoriteVerificationAttempt = 0;
    this.favoriteVerificationPage = 1;
    this.clearFavoriteSubmissionWatchdog();
    this.attentionOperationUrl = '';
    this.isAttentioned = route.initialAttentionState || this.attentionState.isAttentioned(route.threadId);
    this.attentionActionMessage = '';
    this.isAttentionOperationLoading = false;
    this.isAttentionSubmitting = false;
    this.attentionSubmissionWasRemoval = false;
    this.attentionVerificationAttempt = 0;
    this.attentionVerificationPage = 1;
    this.clearAttentionSubmissionWatchdog();
    this.poll = undefined;
    this.selectedPollOptionIds = [];
    this.isVotePreflightLoading = false;
    this.isVoteSubmitting = false;
    this.pollActionMessage = '';
    this.loadedPostImageUrls = [];
    this.viewerUserId = '';
    this.postTailSettings = undefined;
    this.authorOnlyUserId = '';
    this.threadAuthorUserId = '';
    this.threadAuthorName = '';
    this.isThreadAuthorResolving = false;
    this.selectablePostId = '';
    this.isPostDeletionPreflightLoading = false;
    this.isPostDeletionSubmitting = false;
    this.postDeletionMessage = '';
    this.postDeletionPreflightUrl = '';
    this.postDeletionPreflightPostId = '';
    this.postDeletionPreflightPage = 1;
    this.postDeletionPreflightSequence += 1;
    this.postDeletionSubmissionSequence += 1;
    this.postDeletionFormReady = false;
    this.postDeletionConfirmationPending = false;
    this.postDeletionVerificationAttempt = 0;
    this.isPostDeletionVerificationLoading = false;
    this.postDeletionTargetWasFirstPost = false;
    this.clearPostDeletionPreflightWatchdog();
    this.clearPostDeletionSubmissionWatchdog();
    this.votePreflightSequence += 1;
    this.voteSubmissionSequence += 1;
    this.clearVoteOperationWatchdog();
    this.syncBlacklistedUsersFromState();
    this.requestBlacklistSnapshotIfNeeded();
    this.loadPage(this.route.initialPage);
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Web({ src: '', controller: this.threadWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onThreadControllerAttached();
          })
          .onPageBegin((event) => {
            if (this.isCurrentThreadRequest(event.url) && !this.isThreadLoadTerminal()) {
              if (this.isAppendingThreadPage) {
                this.isLoadingMore = true;
                this.loadMoreError = '';
              } else if (!this.isRefreshing) {
                this.isLoading = true;
                this.loadError = '';
              }
            }
          })
          .onPageEnd((event) => {
            if (this.isCurrentThreadRequest(event.url) && !this.isThreadLoadTerminal()) {
              this.readThreadFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl = event.request.getRequestUrl();
            if (!event.request.isMainFrame() || !this.isCurrentThreadRequest(requestUrl)) {
              return;
            }
            this.failThreadLoad(this.webLoadSequence, '暂时无法读取帖子，请检查网络后重试。');
          })
          .width('100%')
          .height('100%')

        // Reply preparation uses an isolated ArkWeb instance so it can never
        // replace the thread currently visible to the user. It only reads the
        // value-free form contract; no fields are set and no form is submitted.
        Web({ src: '', controller: this.replyWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onReplyControllerAttached();
          })
          .onPageEnd((event) => {
            this.handleCompletedReplyWebLoad(event.url);
          })
          .onLoadFinished((event) => {
            this.handleCompletedReplyWebLoad(event.url);
          })
          .onErrorReceive((event) => {
            const requestUrl = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isReplySubmitting) {
              this.failReplySubmission('发表回复时网络出错，请确认结果后再重试。');
              return;
            }
            if (event.request.isMainFrame() && this.isCurrentReplyPreflightRequest(requestUrl)) {
              this.failReplyPreflight('暂时无法打开回复表单，请检查网络后重试。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // Isolated deletion form: GET eligibility, one confirmed POST, then
        // inspect its actual redirect without replacing an in-flight request.
        Web({ src: '', controller: this.postDeletionWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onPostDeletionControllerAttached();
          })
          .onPageEnd((event) => {
            if (this.isPostDeletionSubmitting) {
              this.onPostDeletionResultPageEnd();
              return;
            }
            if (this.isCurrentPostDeletionPreflightRequest(event.url)) {
              this.readPostDeletionPreflightFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isPostDeletionSubmitting) {
              this.failPostDeletionSubmission('无法读取服务器删除结果，请稍后核对该帖子。');
              return;
            }
            if (event.request.isMainFrame() && this.isCurrentPostDeletionPreflightRequest(requestUrl)) {
              this.failPostDeletionPreflight('暂时无法校验删除资格，请检查网络后重试。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // Voting reads and submits only through this isolated document. It
        // cannot replace the topic the user is reading, and it never exposes
        // formhash or the raw poll form to ArkTS.
        Web({ src: '', controller: this.voteWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onVoteControllerAttached();
          })
          .onPageEnd((event) => {
            if (this.isCurrentVotePreflightRequest(event.url)) {
              this.readVotePreflightFromWeb();
              return;
            }
            if (this.isCurrentVoteVerificationRequest(event.url)) {
              this.readVoteVerificationFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (!event.request.isMainFrame()) {
              return;
            }
            if (this.isCurrentVotePreflightRequest(requestUrl)) {
              this.failVoteOperation('暂时无法读取投票表单，请检查网络后重试。');
              return;
            }
            if (this.isCurrentVoteVerificationRequest(requestUrl)) {
              this.failVoteOperation('无法读取服务器投票结果，请稍后核对。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // A separate, hidden Web instance verifies a completed favorite
        // action by reading the server's favorites list. It never replaces the
        // thread being read or displayed by the primary controller.
        Web({ src: '', controller: this.favoriteVerificationWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onFavoriteVerificationControllerAttached();
          })
          .onPageEnd((event) => {
            if (this.isCurrentFavoriteVerificationRequest(event.url)) {
              this.readFavoriteVerificationFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentFavoriteVerificationRequest(requestUrl)) {
              this.failFavoriteSubmission('服务器收藏列表读取失败；请稍后重试。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // Attention is a server collection independent from favorites, so it
        // verifies through its own isolated document and cannot replace the
        // visible thread or the favorite verifier's in-flight page.
        Web({ src: '', controller: this.attentionVerificationWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onAttentionVerificationControllerAttached();
          })
          .onPageEnd((event) => {
            if (this.isCurrentAttentionVerificationRequest(event.url)) {
              this.readAttentionVerificationFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentAttentionVerificationRequest(requestUrl)) {
              this.failAttentionSubmission('服务器关注列表读取失败；请稍后重试。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // This fixed read-only page supplies the server blacklist snapshot.
        // It is isolated so it cannot replace the visible topic document.
        Web({ src: '', controller: this.blacklistSnapshotWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onBlacklistSnapshotControllerAttached();
          })
          .onPageEnd((event) => {
            if (this.isCurrentBlacklistSnapshotRequest(event.url)) {
              this.readBlacklistSnapshotFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentBlacklistSnapshotRequest(requestUrl)) {
              this.finishBlacklistSnapshotLoad(this.blacklistSnapshotLoadSequence);
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        if (this.needsWebVerification) {
          this.buildVerificationHeader();
        } else {
          Column() {
        this.buildThreadPageStrip();

        if (this.favoriteActionMessage.length > 0) {
          Text(this.favoriteActionMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 6 })
        }
        if (this.attentionActionMessage.length > 0) {
          Text(this.attentionActionMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 6 })
        }

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(32)
              .height(32)
            Text('正在读取帖子…')
              .fontSize(15)
              .fontColor($r('app.color.text_quiet'))
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else if (this.loadError.length > 0) {
          Column({ space: 12 }) {
            Text(this.loadError)
              .fontSize(15)
              .fontColor($r('app.color.text_quiet'))
              .textAlign(TextAlign.Center)
            Button('重试')
              .onClick(() => {
                this.loadPage(this.currentPage);
              })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .padding(28)
          .width('100%')
        } else {
          // Refresh owns the top-edge pull gesture while List remains the
          // only scrolling surface, so it cannot race reach-end paging.
          Refresh({ refreshing: $$this.isRefreshing, offset: 64, friction: 65 }) {
            List({ space: 0, scroller: this.postListScroller, initialIndex: this.initialPostListIndex }) {
              ForEach(this.posts, (post: ThreadPost) => {
                ListItem() {
                  this.buildPost(post);
                }
                .onSizeChange(() => {
                  this.onPostLayoutSizeChanged(post.id);
                })
              }, (post: ThreadPost) => this.postRowVersions.key(post))
              ListItem() {
                this.buildThreadLoadFooter();
              }
            }
            .layoutWeight(1)
            .width('100%')
            .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 12, endMargin: 12 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.cancelPostLayoutAnchor();
              }
            })
            .onReachEnd(() => {
              this.loadNextThreadPage();
            })
          }
          .onRefreshing(() => {
            this.refreshCurrentThreadPage();
          })
          .layoutWeight(1)
          .width('100%')
          .padding({ top: 4, bottom: 6 })
        }

          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.surface'))
        }

        if (this.shouldShowQuickReplyFab()) {
          this.buildQuickReplyFab();
        }
        if (this.isReplyComposerVisible) {
          this.buildQuickReplyComposer();
        }
      }
      .width('100%')
      .height('100%')
      .priorityGesture(
        PanGesture({ fingers: 1, direction: PanDirection.Right, distance: 24 })
          .onActionEnd((event: GestureEvent) => {
            this.returnFromThreadSwipe(event);
          })
      )
    }
    .title(this.resolvedTitle || this.route.threadTitle || '主题详情')
    .menus(this.buildThreadTitleActions)
    .onReady((context: NavDestinationContext) => {
      const route: ThreadRouteParams = context.pathInfo.param as ThreadRouteParams;
      this.initializeRoute(route);
    })
    .onBackPressed((): boolean => {
      if (!this.isReplyComposerVisible) {
        return false;
      }
      this.closeQuickReply(true);
      return true;
    })
  }

  private returnFromThreadSwipe(event: GestureEvent): void {
    // NG disables full-width swipe-back while its quick-reply surface is open.
    // Keep both native sheets modal so a background pan cannot discard work.
    if (this.isReplyComposerVisible || this.isPagePickerVisible ||
      !isQualifiedFourD4yRightSwipe(event.offsetX, event.offsetY)) {
      return;
    }
    this.pathStack.pop();
  }

  @Builder
  private buildVerificationHeader() {
    Row({ space: 12 }) {
      Text('请在下方完成 4D4Y 的安全验证')
        .fontSize(14)
        .fontColor($r('app.color.text_body'))
        .layoutWeight(1)
      Button('完成后重试')
        .fontSize(13)
        .onClick(() => {
          this.needsWebVerification = false;
          this.loadPage(this.currentPage);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.warning_background'))
  }

  @Builder
  private buildThreadPageStrip() {
    Row() {
      Text('第 ' + this.currentPage + ' / ' + this.lastPage + ' 页')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .height(30)
    .backgroundColor($r('app.color.surface_subtle'))
  }

  @Builder
  private buildThreadLoadFooter() {
    Row({ space: 8 }) {
      if (this.isLoadingMore) {
        LoadingProgress()
          .width(18)
          .height(18)
        Text('正在加载下一页…')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      } else if (this.loadMoreError.length > 0) {
        Text(this.loadMoreError + ' 点击重试')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.loadNextThreadPage();
          })
      } else if (this.posts.length > 0 && this.currentPage >= this.lastPage) {
        Text('— 已到底 —')
          .fontSize(12)
          .fontColor($r('app.color.text_quiet'))
      }
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildThreadTitleActions() {
    Row({ space: 2 }) {
      Image($r('app.media.toolbar_more'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .bindMenu(this.getThreadMenuItems())
        .bindSheet(this.isPagePickerVisible, this.buildPagePicker(), {
          // A compact stable height matches NG's sheet baseline. FIT_CONTENT
          // becomes too short for one-line titles while a fixed 460vp leaves
          // a conspicuous blank area. 290vp still accommodates two lines.
          height: 290,
          dragBar: false,
          showClose: false,
          onDisappear: () => {
            this.isPagePickerVisible = false;
          }
        })
    }
  }

  private getThreadMenuItems(): MenuElement[] {
    return [
      {
        value: '回复',
        enabled: this.isLoggedIn && !this.isLoading && this.route.threadId.length > 0,
        action: () => { this.openReplyComposer(); }
      },
      {
        value: '刷新',
        enabled: !this.isLoading,
        action: () => { this.loadPage(this.currentPage); }
      },
      {
        value: '页面跳转',
        enabled: this.lastPage > 1,
        action: () => { this.openPagePicker(); }
      },
      {
        value: this.isFavorite ? '取消收藏' : '添加收藏',
        enabled: this.isLoggedIn && this.favoriteOperationUrl.length > 0 && !this.isFavoriteOperationLoading &&
          !this.isFavoriteSubmitting && !this.isAttentionSubmitting && !this.isLoading,
        action: () => { this.submitFavoriteOperation(); }
      },
      {
        value: this.isAttentioned ? '取消关注' : '添加关注',
        enabled: this.isLoggedIn && this.attentionOperationUrl.length > 0 && !this.isAttentionOperationLoading &&
          !this.isAttentionSubmitting && !this.isFavoriteSubmitting && !this.isLoading,
        action: () => { this.submitAttentionOperation(); }
      },
      {
        value: this.authorOnlyUserId.length > 0 ? '显示全部' :
          (this.isThreadAuthorResolving ? '正在读取楼主…' : '只看楼主'),
        enabled: !this.isLoading && !this.isThreadAuthorResolving &&
          (this.authorOnlyUserId.length > 0 || this.threadAuthorUserId.length > 0 || this.posts.length > 0),
        action: () => { this.toggleThreadAuthorFilter(); }
      },
      {
        value: '浏览器打开',
        enabled: normalizeFourD4yThreadActionId(this.route.threadId).length > 0,
        action: () => { this.openThreadInSystemBrowser(); }
      },
      {
        value: '复制帖子地址',
        enabled: normalizeFourD4yThreadActionId(this.route.threadId).length > 0,
        action: () => { void this.copyThreadUrl(); }
      },
      {
        value: '分享',
        enabled: normalizeFourD4yThreadActionId(this.route.threadId).length > 0,
        action: () => { void this.shareThread(); }
      }
    ];
  }

  private toggleThreadAuthorFilter(): void {
    if (this.isLoading || this.isThreadAuthorResolving) {
      return;
    }
    if (this.authorOnlyUserId.length > 0) {
      this.authorOnlyUserId = '';
      this.isThreadAuthorResolving = false;
      this.loadPage(1);
      return;
    }
    if (normalizeFourD4yThreadActionId(this.threadAuthorUserId).length > 0) {
      this.authorOnlyUserId = this.threadAuthorUserId;
      this.loadPage(1);
      return;
    }
    if (this.posts.length === 0) {
      this.showLinkToast('当前页面还没有可识别的楼主信息');
      return;
    }
    // NG also resolves the topic author from page 1 when the reader was opened
    // on a later page. Keep that lookup in the visible, request-correlated
    // ArkWeb chain instead of issuing an untracked native HTTP request.
    this.isThreadAuthorResolving = true;
    this.loadPage(1);
  }

  private captureThreadAuthor(posts: ThreadPost[]): void {
    const firstPost: ThreadPost | undefined = posts.find((post: ThreadPost) => post.floor === 1);
    if (firstPost === undefined || firstPost.authorUserId === undefined ||
      normalizeFourD4yThreadActionId(firstPost.authorUserId).length === 0) {
      return;
    }
    this.threadAuthorUserId = firstPost.authorUserId;
    this.threadAuthorName = firstPost.authorName;
  }

  private openThreadInSystemBrowser(): void {
    const url: string = buildFourD4yThreadPublicUrl(this.route.threadId, this.currentPage);
    if (url.length === 0) {
      this.showLinkToast('当前帖子地址无效');
      return;
    }
    void this.openSystemLink(url, 'ohos.want.action.viewData', true);
  }

  private async copyThreadUrl(): Promise<void> {
    const url: string = buildFourD4yThreadPublicUrl(this.route.threadId);
    if (url.length === 0) {
      this.showLinkToast('当前帖子地址无效');
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      const property: pasteboard.PasteDataProperty = data.getProperty();
      // Preserve an app-owned source marker for the future external-link
      // clipboard feature, so this deliberate in-app copy is never mistaken
      // for a link copied in another application.
      property.tag = 'HiPDA_OH_THREAD_URL';
      data.setProperty(property);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showLinkToast('帖子地址已复制到剪贴板');
    } catch (_error) {
      this.showLinkToast('复制帖子地址失败');
    }
  }

  private async shareThread(): Promise<void> {
    const title: string = this.resolvedTitle || this.route.threadTitle || '4D4Y 主题';
    const content: string = buildFourD4yThreadShareText(title, this.threadAuthorName, this.route.threadId);
    if (content.length === 0) {
      this.showLinkToast('当前帖子地址无效');
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showLinkToast('暂时无法打开系统分享');
      return;
    }
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.TEXT,
        content: content,
        title: title,
        description: '4D4Y 论坛主题'
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      await controller.show(hostContext as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (_error) {
      this.showLinkToast('系统分享暂时不可用');
    }
  }

  /** P-26 mirrors NG's copy projection instead of serializing the rendered component tree. */
  private getPostCopyText(post: ThreadPost): string {
    return buildFourD4yPostCopyText(post);
  }

  private canUsePostContentActions(post: ThreadPost): boolean {
    return !this.isPostHiddenByBlacklist(post);
  }

  private canFilterByPostAuthor(post: ThreadPost): boolean {
    return this.canUsePostContentActions(post) && post.authorUserId !== undefined &&
      normalizeFourD4yThreadActionId(post.authorUserId).length > 0;
  }

  private isPostTextSelectionMode(post: ThreadPost): boolean {
    return this.selectablePostId === post.id && this.getPostCopyText(post).length > 0;
  }

  private enterPostTextSelection(post: ThreadPost): void {
    if (this.canUsePostContentActions(post) && this.getPostCopyText(post).length > 0) {
      this.selectablePostId = post.id;
    }
  }

  /** NG turns the floor chip into an X which restores the normal rich post view. */
  private leavePostTextSelection(post: ThreadPost): void {
    if (this.selectablePostId === post.id) {
      this.selectablePostId = '';
    }
  }

  private async copyPostText(post: ThreadPost): Promise<void> {
    const content: string = this.getPostCopyText(post);
    if (content.length === 0) {
      this.showLinkToast('当前楼层没有可复制的文字');
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      const property: pasteboard.PasteDataProperty = data.getProperty();
      property.tag = 'HiPDA_OH_POST_TEXT';
      data.setProperty(property);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showLinkToast('文字已复制到剪贴板');
    } catch (_error) {
      this.showLinkToast('复制文字失败');
    }
  }

  private togglePostAuthorFilter(post: ThreadPost): void {
    if (this.isLoading || this.isLoadingMore || this.isThreadAuthorResolving) {
      return;
    }
    if (this.authorOnlyUserId.length > 0) {
      this.authorOnlyUserId = '';
      this.selectablePostId = '';
      this.loadPage(1);
      return;
    }
    if (!this.canFilterByPostAuthor(post) || post.authorUserId === undefined) {
      this.showLinkToast('当前楼层未提供可识别的作者账号');
      return;
    }
    this.authorOnlyUserId = normalizeFourD4yThreadActionId(post.authorUserId);
    this.selectablePostId = '';
    this.loadPage(1);
  }

  private async sharePost(post: ThreadPost): Promise<void> {
    const title: string = this.resolvedTitle || this.route.threadTitle || '4D4Y 主题';
    const content: string = buildFourD4yPostShareText(title, this.route.threadId, post);
    if (content.length === 0) {
      this.showLinkToast('当前楼层地址无效');
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showLinkToast('暂时无法打开系统分享');
      return;
    }
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.TEXT,
        content: content,
        title: post.floor === 1 ? '4D4Y 主题' : '4D4Y 回帖',
        description: '4D4Y 论坛楼层'
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      await controller.show(hostContext as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (_error) {
      this.showLinkToast('系统分享暂时不可用');
    }
  }

  @Builder
  private buildPost(post: ThreadPost) {
    // ArkUI treats both ResponseType variants as a mobile long-press menu.
    // Selection mode must therefore render an entirely unbound card so the
    // system text-selection gesture receives the long press.
    if (this.isPostTextSelectionMode(post)) {
      this.buildPostSelectionCard(post);
    } else {
      this.buildPostContextCard(post);
    }
  }

  @Builder
  private buildPostContextCard(post: ThreadPost) {
    Column({ space: 8 }) {
      this.buildPostCardBody(post);
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .padding({ left: 12, right: 12, top: 10, bottom: 11 })
    .bindContextMenu(this.buildPostContextMenu(post), ResponseType.LongPress, {
      aboutToAppear: () => { this.isPostContextMenuVisible = true; },
      onDisappear: () => { this.onPostContextMenuClosed(); }
    })
    // The card owns the NG-style page-jump double tap. Interactive descendants
    // explicitly monopolize their events, so profile/floor/link/image actions
    // never bubble into the reader-level gesture.
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          this.openPagePicker();
        })
    )
  }

  @Builder
  private buildPostSelectionCard(post: ThreadPost) {
    Column({ space: 8 }) {
      this.buildPostCardBody(post);
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .padding({ left: 12, right: 12, top: 10, bottom: 11 })
  }

  @Builder
  private buildPostCardBody(post: ThreadPost) {
    if (this.route.openedFromNotice === true && post.id === this.route.initialPostId && this.isAttentioned) {
      Row() {
        Text('关注主题的新回复')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        Button(this.isAttentionSubmitting ? '处理中…' : '取消关注此主题', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .height(32)
          .enabled(this.isLoggedIn && this.attentionOperationUrl.length > 0 &&
            !this.isAttentionOperationLoading && !this.isAttentionSubmitting &&
            !this.isFavoriteSubmitting && !this.isLoading)
          .onClick(() => {
            if (this.isAttentioned) this.submitAttentionOperation();
          })
          .monopolizeEvents(true)
      }
      .width('100%')
      .margin({ bottom: 6 })
    }
    Row() {
      if (!this.isPostHiddenByBlacklist(post)) {
        // Key by URL so a changed author cannot retain an earlier successful Image source.
        ForEach([buildFourD4yAvatarUrl(post.authorUserId)], (avatarUrl: string) => {
          Image(avatarUrl.length > 0 ? avatarUrl : $r('app.media.avatar_default'))
            .alt($r('app.media.avatar_default'))
            .width(36)
            .height(36)
            .objectFit(ImageFit.Cover)
            .borderRadius(4)
            .margin({ right: 8 })
            .onClick(() => {
              this.openUserProfile(post);
            })
            .monopolizeEvents(true)
        }, (avatarUrl: string) => avatarUrl)
      }
      if (this.isPostHiddenByBlacklist(post)) {
        Text('黑名单用户')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
      } else if (post.authorName.length > 0) {
        Text(post.authorName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .fontColor(this.canOpenUserProfile(post) ? $r('app.color.brand') : $r('app.color.text_primary'))
          .onClick(() => {
            this.openUserProfile(post);
          })
          .monopolizeEvents(true)
      }
      if (this.isPostHiddenByBlacklist(post) || post.authorName.length === 0) {
        Blank()
      }
      if (post.publishedAt !== undefined && post.publishedAt.length > 0) {
        Text(post.publishedAt)
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .margin({ right: 7 })
      }
      Text(this.isPostTextSelectionMode(post) ? 'X' : '#' + post.floor)
        .fontSize(13)
        .fontColor(this.isPostTextSelectionMode(post) ? $r('app.color.brand') : $r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.fill_subtle'))
        .borderRadius(12)
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .onClick(() => {
          this.leavePostTextSelection(post);
        })
        .monopolizeEvents(true)
    }
    .width('100%')

    if (!this.isPostHiddenByBlacklist(post)) {
      if (this.isPostTextSelectionMode(post)) {
        Text(this.getPostCopyText(post))
          .fontSize(16)
          .fontColor($r('app.color.text_body'))
          .lineHeight(this.getPostLineHeight(25))
          .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
          // textSelectable alone keeps the default CopyOptions.None. The SDK
          // requires LocalDevice to expose the native long-press copy/select
          // menu for this deliberately user-entered selection mode.
          .copyOption(CopyOptions.LocalDevice)
          .width('100%')
          .padding(8)
      } else {
        if (post.floor === 1 && this.poll !== undefined) {
          this.buildThreadPoll(this.poll);
        }
        if (post.statusText !== undefined && post.statusText.length > 0) {
          Text(post.statusText)
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 1, bottom: 1 })
        }
        ForEach(post.content, (content: PostContent, index: number) => {
          if (!this.isInlineSmallContent(post.content, index)) {
            this.buildPostContent(content, post.id, index, this.getInlineSmallSuffix(post.content, index));
          }
        }, (content: PostContent, index: number) => post.id + '-' + index)

        if (post.id === this.postDeletionPreflightPostId && this.postDeletionMessage.length > 0) {
          Text(this.postDeletionMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
      }
    }
  }

  @Builder
  private buildPostContextMenu(post: ThreadPost) {
    Menu() {
      if (this.canUsePostContentActions(post) && this.getPostCopyText(post).length > 0) {
        MenuItem({ content: '复制文字' })
          .onClick(() => {
            void this.copyPostText(post);
          })
      }
      if (this.canFilterByPostAuthor(post)) {
        MenuItem({ content: this.authorOnlyUserId.length > 0 ? '显示全部' : '只看该作者' })
          .enabled(!this.isLoading && !this.isLoadingMore && !this.isThreadAuthorResolving)
          .onClick(() => {
            this.togglePostAuthorFilter(post);
          })
      }
      if (this.canUsePostContentActions(post) &&
        buildFourD4yPostShareText(this.resolvedTitle || this.route.threadTitle || '4D4Y 主题',
          this.route.threadId, post).length > 0) {
        MenuItem({ content: '分享' })
          .onClick(() => {
            void this.sharePost(post);
          })
      }
      if (this.canUsePostContentActions(post) && this.getPostCopyText(post).length > 0) {
        MenuItem({ content: '文字选择' })
          .onClick(() => {
            this.enterPostTextSelection(post);
          })
      }
      MenuItem({ content: '回复' })
        .enabled(this.isLoggedIn && !this.isLoading)
        .onClick(() => {
          this.openReplyComposer(post);
        })
      MenuItem({ content: '引用' })
        .enabled(this.isLoggedIn && /^\d+$/.test(post.id))
        .onClick(() => {
          this.openQuoteComposer(post);
        })
      if (this.canRequestPostDeletion(post)) {
        MenuItem({ content: this.getPostDeletionButtonLabel(post) })
          .enabled(!this.isPostDeletionPreflightLoading && !this.isPostDeletionSubmitting)
          .onClick(() => {
            this.requestPostDeletionEligibility(post);
          })
      }
      if (this.canEditPost(post)) {
        MenuItem({ content: '编辑' })
          .enabled(!this.isPostDeletionPreflightLoading && !this.isPostDeletionSubmitting)
          .onClick(() => {
            this.openEditComposer(post);
          })
      }
    }
  }

  /**
   * The option controls are native, while the actual vote form remains in an
   * isolated ArkWeb document. Rendering this card never changes the server
   * form; a fresh copy is validated only after the user presses "投票".
   */
  @Builder
  private buildThreadPoll(poll: ThreadPoll) {
    Column({ space: 10 }) {
      Text(poll.infoText.length > 0 ? poll.infoText :
        (poll.isMultipleChoice ? '多选投票' : '单选投票'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      ForEach(poll.options, (option: ThreadPollOption) => {
        if (poll.isVoteFormAvailable) {
          Row({ space: 10 }) {
            if (poll.isMultipleChoice) {
              Checkbox({ name: option.id, group: this.getPollControlGroupName() })
                .select(this.selectedPollOptionIds.indexOf(option.id) >= 0)
                .enabled(this.canChangePollSelection(poll))
                .onChange((isSelected: boolean) => {
                  this.updatePollSelection(poll, option.id, isSelected);
                })
                .monopolizeEvents(true)
            } else {
              Radio({ value: option.id, group: this.getPollControlGroupName() })
                .checked(this.selectedPollOptionIds.indexOf(option.id) >= 0)
                .enabled(this.canChangePollSelection(poll))
                .onChange((isSelected: boolean) => {
                  this.updatePollSelection(poll, option.id, isSelected);
                })
                .monopolizeEvents(true)
            }
            Text(option.label)
              .fontSize(16)
              .fontColor($r('app.color.text_body'))
              .layoutWeight(1)
          }
          .width('100%')
        } else {
          // Match NG's result mode: options become non-interactive result
          // rows, and the colored segment encodes the parsed server percent.
          Column({ space: 5 }) {
            Row({ space: 10 }) {
              Text(option.label)
                .fontSize(16)
                .fontColor($r('app.color.text_body'))
                .layoutWeight(1)
              if (option.resultText.length > 0) {
                Text(option.resultText)
                  .fontSize(14)
                  .fontColor($r('app.color.text_detail'))
                  .fontWeight(FontWeight.Medium)
              }
            }
            .width('100%')

            if (this.getPollResultPercent(option.resultText) > 0) {
              // The outer row deliberately occupies the full option width.
              // Without it, the Column centers a narrow percentage bar.
              Row() {
                Row()
                  .width(this.getPollResultBarWidth(option.resultText))
                  .height(6)
                  .backgroundColor(this.getPollResultColor(option, poll))
                  .borderRadius(3)
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
            }
          }
          .width('100%')
        }
      }, (option: ThreadPollOption) => option.id.length > 0 ? option.id : option.label)

      if (poll.footerText.length > 0) {
        Text(poll.footerText)
          .fontSize(poll.isVoteFormAvailable ? 13 : 15)
          .fontColor(poll.isVoteFormAvailable ? $r('app.color.text_secondary') : $r('app.color.text_body'))
          .fontWeight(poll.isVoteFormAvailable ? FontWeight.Regular : FontWeight.Medium)
          .textAlign(poll.isVoteFormAvailable ? TextAlign.Start : TextAlign.Center)
          .width('100%')
      }

      if (poll.isVoteFormAvailable) {
        Button(this.getVoteButtonLabel())
          .fontSize(14)
          .height(36)
          .width('100%')
          .enabled(this.canBeginVote(poll))
          .onClick(() => {
            this.beginVoteOperation(poll);
          })
          .monopolizeEvents(true)
      }

      if (poll.isVoteFormAvailable || this.pollActionMessage.length > 0) {
        Text(this.getPollActionDescription(poll))
          .fontSize(12)
          .fontColor(this.pollActionMessage.length > 0 ? $r('app.color.danger_text') : $r('app.color.text_muted'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.canvas'))
    .border({ width: 1, color: $r('app.color.border_strong'), radius: 8 })
    .borderRadius(8)
  }

  private getPollControlGroupName(): string {
    return '4d4y-poll-' + this.route.threadId;
  }

  private canChangePollSelection(poll: ThreadPoll): boolean {
    return this.isLoggedIn && poll.isVoteFormAvailable && !this.isVotePreflightLoading &&
      !this.isVoteSubmitting;
  }

  private updatePollSelection(poll: ThreadPoll, optionId: string, isSelected: boolean): void {
    if (!this.canChangePollSelection(poll) || optionId.length === 0) {
      return;
    }
    const current: string[] = this.selectedPollOptionIds;
    const index: number = current.indexOf(optionId);
    if (!poll.isMultipleChoice) {
      this.selectedPollOptionIds = isSelected ? [optionId] : [];
      this.pollActionMessage = '';
      return;
    }
    if (isSelected && index < 0) {
      if (current.length >= poll.maxSelections) {
        // Reassign the existing bounded state so the controlled Checkbox is
        // restored immediately after a rejected extra tap.
        this.selectedPollOptionIds = current.slice();
        this.pollActionMessage = '该投票最多可选 ' + poll.maxSelections + ' 项。';
        return;
      }
      this.selectedPollOptionIds = current.concat([optionId]);
      this.pollActionMessage = '';
      return;
    }
    if (!isSelected && index >= 0) {
      this.selectedPollOptionIds = current.filter((item: string) => item !== optionId);
      this.pollActionMessage = '';
    }
  }

  private getVoteButtonLabel(): string {
    if (this.isVoteSubmitting) {
      return '正在确认投票结果…';
    }
    if (this.isVotePreflightLoading) {
      return '正在校验投票表单…';
    }
    return '投票';
  }

  private canBeginVote(poll: ThreadPoll): boolean {
    return this.canChangePollSelection(poll) && this.selectedPollOptionIds.length > 0;
  }

  private getPollResultPercent(resultText: string): number {
    const matched: RegExpExecArray | null = /^\s*(\d+(?:\.\d+)?)\s*%/.exec(resultText);
    if (matched === null) {
      return 0;
    }
    const value: number = Number(matched[1]);
    if (!Number.isFinite(value)) {
      return 0;
    }
    return Math.max(0, Math.min(100, value));
  }

  private getPollResultBarWidth(resultText: string): string {
    // Retain a sub-percent result as a visible hairline while keeping all
    // normal rows proportional to the server-rendered percentage.
    return Math.max(1, this.getPollResultPercent(resultText)) + '%';
  }

  private getPollResultColor(option: ThreadPollOption, poll: ThreadPoll): string {
    const index: number = poll.options.indexOf(option);
    const palette: string[] = ['#43A047', '#F9A825', '#5E35B1', '#F9A825', '#C2185B'];
    return palette[Math.max(0, index) % palette.length];
  }

  private getPollActionDescription(poll: ThreadPoll): string {
    if (this.pollActionMessage.length > 0) {
      return this.pollActionMessage;
    }
    if (poll.isVoteFormAvailable) {
      if (!this.isLoggedIn) {
        return '登录后可投票。';
      }
      return '选择后将重新校验当前投票表单，再向 4D4Y 提交。';
    }
    return '';
  }

  private canOpenUserProfile(post: ThreadPost): boolean {
    return !this.isPostHiddenByBlacklist(post) && post.authorName.length > 0 &&
      post.authorUserId !== undefined && /^\d{1,20}$/.test(post.authorUserId);
  }

  /** NG keeps the floor shell but stops parsing the body for a blocked author. */
  private isPostHiddenByBlacklist(post: ThreadPost): boolean {
    const authorName: string = normalizeFourD4yBlacklistUserName(post.authorName);
    return authorName.length > 0 && this.blacklistedUserNames.indexOf(authorName) >= 0;
  }

  private openUserProfile(post: ThreadPost): void {
    if (!this.canOpenUserProfile(post) || post.authorUserId === undefined) {
      return;
    }
    this.pathStack.pushPathByName('UserProfile', createUserProfileRouteParams(post.authorUserId, post.authorName));
  }

  private async restoreReaderSettings(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const settings: FourD4yUserSettings = await FourD4yUserSettingsStore.load(context);
      if (!this.isThreadPageAlive) {
        return;
      }
      this.imageLoadPolicy = settings.imageLoadPolicy;
      this.postLineSpacing = settings.postLineSpacing;
    } catch (_error) {
      if (!this.isThreadPageAlive) {
        return;
      }
      this.imageLoadPolicy = FourD4yImageLoadPolicy.Automatic;
      this.postLineSpacing = 1;
    }
  }

  private shouldLoadPostImage(content: PostContent): boolean {
    return this.imageLoadPolicy === FourD4yImageLoadPolicy.Automatic ||
      this.loadedPostImageUrls.indexOf(this.getContentUrl(content)) >= 0;
  }

  private loadPostImage(content: PostContent): void {
    const url: string = this.getContentUrl(content);
    if (url.length > 0 && this.loadedPostImageUrls.indexOf(url) < 0) {
      this.loadedPostImageUrls = [...this.loadedPostImageUrls, url];
    }
  }

  private shouldUseCompactPostImagePreview(content: PostContent): boolean {
    const url: string = this.getContentUrl(content);
    const size: FourD4yPostImageSize | undefined = this.postImageSizes.find(
      (item: FourD4yPostImageSize) => item.url === url);
    // Keep an unknown image compact for its first frame.  Its onComplete callback
    // immediately records the source ratio and ordinary pictures then re-render
    // at their natural full width.  A 3:1 threshold keeps article-style long
    // images from making the topic stream unwieldy without shrinking normal
    // portrait photos or phone screenshots.
    return size === undefined || size.height >= size.width * 3;
  }

  private getPostImagePreviewUrl(content: PostContent): string {
    return content.previewUrl === undefined || content.previewUrl.length === 0 ?
      this.getContentUrl(content) : content.previewUrl;
  }

  private getPostImagePreviewSize(content: PostContent): FourD4yPostImageSize | undefined {
    const url: string = this.getContentUrl(content);
    return this.postImageSizes.find((item: FourD4yPostImageSize) => item.url === url);
  }

  private recordPostImageSize(content: PostContent, result: ImageLoadResult): void {
    const url: string = this.getContentUrl(content);
    if (url.length === 0 || !Number.isFinite(result.width) || !Number.isFinite(result.height) ||
      result.width <= 0 || result.height <= 0) {
      return;
    }
    const current: FourD4yPostImageSize | undefined = this.postImageSizes.find(
      (item: FourD4yPostImageSize) => item.url === url);
    if (current !== undefined && current.width === result.width && current.height === result.height) {
      return;
    }
    const next: FourD4yPostImageSize[] = this.postImageSizes.filter(
      (item: FourD4yPostImageSize) => item.url !== url);
    next.push({ url: url, width: result.width, height: result.height });
    // An appended multi-page topic can expose many images.  This is page-local
    // rendering metadata, so keep a bounded recent set rather than retain it.
    this.postImageSizes = next.length > 200 ? next.slice(next.length - 200) : next;
  }

  private isInlineSmallContent(contents: PostContent[], index: number): boolean {
    return index > 0 && contents[index].isSmallText === true &&
      (contents[index].kind === 'text' || contents[index].kind === 'link') &&
      contents[index - 1].kind === 'text' && contents[index - 1].isSmallText !== true;
  }

  private getInlineSmallSuffix(contents: PostContent[], index: number): PostContent | undefined {
    return index + 1 < contents.length && this.isInlineSmallContent(contents, index + 1) ?
      contents[index + 1] : undefined;
  }

  @Builder
  private buildPostContent(content: PostContent, postId: string, contentIndex: number,
    smallSuffix: PostContent | undefined) {
    if (content.kind === 'emoji' && this.getContentUrl(content).length > 0) {
      Image(this.getContentUrl(content))
        .width(28)
        .height(28)
        .objectFit(ImageFit.Contain)
    } else if (content.kind === 'image' && this.getContentUrl(content).length > 0) {
      if (this.shouldLoadPostImage(content)) {
        Column({ space: 4 }) {
          if (this.shouldUseCompactPostImagePreview(content)) {
            Image(this.getPostImagePreviewUrl(content))
              .width('100%')
              .height(240)
              .objectFit(ImageFit.Contain)
              .backgroundColor($r('app.color.fill_subtle'))
              .borderRadius(8)
              .onComplete((result: ImageLoadResult) => {
                this.recordPostImageSize(content, result);
              })
          } else {
            // A width without a forced height lets ArkUI preserve the source
            // ratio.  This is the NG behavior for ordinary forum photos.
            Image(this.getPostImagePreviewUrl(content))
              .width('100%')
              .objectFit(ImageFit.Contain)
              .onComplete((result: ImageLoadResult) => {
                this.recordPostImageSize(content, result);
              })
          }
        }
        .width('100%')
        .onClick(() => {
          this.openPostImage(content, postId, contentIndex);
        })
        .monopolizeEvents(true)
      } else {
        Button('点击加载图片')
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.info_subtle'))
          .width('100%')
          .height(56)
          .borderRadius(8)
          .onClick(() => {
            this.loadPostImage(content);
          })
          .monopolizeEvents(true);
      }
    } else if (content.kind === 'quote') {
      Column({ space: 6 }) {
        if (this.hasQuoteHeader(content)) {
          Row() {
            if (content.quoteAuthor !== undefined && content.quoteAuthor.length > 0) {
              Text(content.quoteAuthor)
                .fontSize(14)
                .fontColor($r('app.color.brand'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.openQuotedPost(content);
                })
                .monopolizeEvents(true)
            }
            Blank()
            if (content.quoteFloor !== undefined && content.quoteFloor > 0) {
              Text(content.quoteFloor + '#')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.openQuotedPost(content);
                })
                .monopolizeEvents(true)
            } else if (content.quoteTime !== undefined && content.quoteTime.length > 0) {
              Text(content.quoteTime)
                .fontSize(11)
                .fontColor($r('app.color.text_muted'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
        }
        Text(content.value)
          .fontSize(15)
          .fontColor($r('app.color.text_detail'))
          .lineHeight(this.getPostLineHeight(23))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.quote_background'))
      .borderRadius(6)
    } else if (content.kind === 'link' && content.isSmallText === true) {
      Text(content.value)
        .fontSize(12)
        .fontColor($r('app.color.brand'))
        .decoration({ type: TextDecorationType.Underline })
        .lineHeight(this.getPostLineHeight(18))
        .width('100%')
        .onClick(() => { this.openContent(content); })
        .monopolizeEvents(true)
    } else if (content.kind === 'link' || content.kind === 'attachment' || content.kind === 'video') {
      Row({ space: 8 }) {
        if (content.kind !== 'attachment') {
          Text(this.getContentIcon(content))
            .fontSize(18)
        }
        Column({ space: 2 }) {
          Text(this.getContentLabel(content))
            .fontSize(15)
            .fontColor($r('app.color.brand'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.shouldShowContentUrl(content)) {
            Text(this.getContentUrl(content))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(10)
      .backgroundColor($r('app.color.info_subtle'))
      .borderRadius(8)
      .onClick(() => {
        this.openContent(content);
      })
      .monopolizeEvents(true)
    } else {
      Text() {
        Span(content.value)
          .fontSize(content.isSmallText === true ? 12 : 16)
          .fontColor($r('app.color.text_body'))
        if (smallSuffix !== undefined) {
          Span('  ' + smallSuffix.value)
            .fontSize(12)
            .fontColor(smallSuffix.kind === 'link' ? $r('app.color.brand') : $r('app.color.text_body'))
            .decoration({ type: smallSuffix.kind === 'link' ? TextDecorationType.Underline : TextDecorationType.None })
            .onClick(() => {
              if (smallSuffix !== undefined && smallSuffix.kind === 'link') this.openContent(smallSuffix);
            })
        }
      }
        .lineHeight(this.getPostLineHeight(content.isSmallText === true ? 18 : 25))
        .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
        .width('100%')
    }
  }

  private hasQuoteHeader(content: PostContent): boolean {
    return (content.quoteAuthor !== undefined && content.quoteAuthor.length > 0) ||
      (content.quoteFloor !== undefined && content.quoteFloor > 0) ||
      (content.quoteTime !== undefined && content.quoteTime.length > 0);
  }

  private openQuotedPost(content: PostContent): void {
    const floor: number = content.quoteFloor === undefined ? 0 : content.quoteFloor;
    if (floor < 1) {
      return;
    }
    const threadId: string = content.quoteThreadId === undefined || content.quoteThreadId.length === 0 ?
      this.route.threadId : content.quoteThreadId;
    const page: number = Math.floor((floor - 1) / 50) + 1;
    this.openThreadLink(threadId, page, floor, floor + '#');
  }

  private getPostLineHeight(baseLineHeight: number): number {
    return Math.round(baseLineHeight * this.postLineSpacing);
  }

  @Builder
  private buildPagePicker() {
    Column({ space: 10 }) {
      Text(this.resolvedTitle || this.route.threadTitle || '主题详情')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
      Divider()
      Text('第 ' + this.selectedPage + ' / ' + this.lastPage + ' 页')
        .fontSize(18)
        .fontColor($r('app.color.text_body'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Slider({
        value: this.selectedPage,
        min: 1,
        max: Math.max(this.lastPage, 1),
        step: 1
      })
        .width('100%')
        .onChange((value: number, mode: SliderChangeMode) => {
          const targetPage: number = Math.round(value);
          this.selectedPage = targetPage;
          // SliderChangeMode.End is emitted once for both a track click and
          // a completed drag. Loading only then mirrors NG's seek-bar release
          // behavior instead of issuing one forum request per drag frame.
          if (mode === SliderChangeMode.End && targetPage !== this.currentPage) {
            this.jumpToPage(targetPage, false);
          }
        })
      Row() {
        Text('«')
          .fontSize(30)
          .fontColor(!this.isLoading ? $r('app.color.brand') : $r('app.color.text_muted'))
          .textAlign(TextAlign.Center)
          .width(56)
          .height(56)
          .backgroundColor($r('app.color.page_jump_control'))
          .borderRadius(28)
          // First/last are viewport endpoints, not merely page changes. They
          // must remain available even when the current page is already 1.
          .enabled(!this.isLoading)
          .onClick(() => {
            this.jumpToThreadEndpoint(1, false);
          })
        Text('‹')
          .fontSize(34)
          .fontColor(this.selectedPage > 1 ? $r('app.color.brand') : $r('app.color.text_muted'))
          .textAlign(TextAlign.Center)
          .width(56)
          .height(56)
          .backgroundColor($r('app.color.page_jump_control'))
          .borderRadius(28)
          .enabled(this.selectedPage > 1)
          .margin({ left: 24 })
          .onClick(() => {
            this.jumpToPage(this.selectedPage - 1, false);
          })
        Blank()
        Text('›')
          .fontSize(34)
          .fontColor(this.selectedPage < this.lastPage ? $r('app.color.brand') : $r('app.color.text_muted'))
          .textAlign(TextAlign.Center)
          .width(56)
          .height(56)
          .backgroundColor($r('app.color.page_jump_control'))
          .borderRadius(28)
          .enabled(this.selectedPage < this.lastPage)
          .margin({ right: 24 })
          .onClick(() => {
            this.jumpToPage(this.selectedPage + 1, false);
          })
        Text('»')
          .fontSize(30)
          .fontColor(!this.isLoading ? $r('app.color.brand') : $r('app.color.text_muted'))
          .textAlign(TextAlign.Center)
          .width(56)
          .height(56)
          .backgroundColor($r('app.color.page_jump_control'))
          .borderRadius(28)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.jumpToThreadEndpoint(this.lastPage, true);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 16 })
  }

  @Builder
  private buildQuickReplyFab() {
    // This is a full-size, transparent overlay so its Stack alignment is
    // relative to the reader surface rather than to the icon's own bounds.
    // Keep the title bar free of a duplicate reply action: the FAB is the
    // single, NG-style entry for quick reply.
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image($r('app.media.toolbar_reply'))
        .width(52)
        .height(52)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.surface'))
        .padding(13)
        .backgroundColor($r('app.color.brand'))
        .borderRadius(26)
        .onClick(() => {
          this.openReplyComposer();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ right: 20, bottom: 20 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  /**
   * The reader-level surface deliberately remains a small text-only bar. Its
   * direct-send path owns no image state and its quote template stays inside
   * the current ArkWeb form. A long press promotes this in-memory draft to
   * the detailed composer, matching NG's quick-reply affordance.
   */
  @Builder
  private buildQuickReplyComposer() {
    // RESIZE makes this full-height layer end at the keyboard's top edge.
    // The inner bottom-aligned bar then follows that resized edge, matching
    // NG's quick-reply placement instead of anchoring below the title bar.
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 6 }) {
        if (this.replySubmissionErrorMessage.length > 0) {
          Text(this.replySubmissionErrorMessage)
            .fontSize(12)
            .fontColor($r('app.color.danger_text'))
            .width('100%')
        }
        if (this.isReplyPreflightLoading) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(16)
              .height(16)
            Text('正在核对回复表单…')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
        } else if (this.replyPreflightMessage.length > 0 && !this.isReplyFormReady) {
          Text(this.replyPreflightMessage)
            .fontSize(12)
            .fontColor($r('app.color.danger_text'))
            .width('100%')
            .onClick(() => {
              if (!this.isReplySubmitting) {
                this.prepareReplyForm();
                this.requestQuickReplyFocus();
              }
            })
        }
        Row({ space: 8 }) {
          Text('×')
            .fontSize(26)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(48)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.closeQuickReply(true);
            })
          ForumSmileyButton({ text: $replyDraft, selectionStart: $smileySelectionStart,
          selectionEnd: $smileySelectionEnd, controller: this.smileyTextController })
            .enabled(!this.isReplySubmitting)
          TextArea({ placeholder: this.getQuickReplyHint(), text: this.replyDraft, controller: this.smileyTextController })
          .onTextSelectionChange((start: number, end: number) => {
            if (start >= 0 && end >= 0) {
              this.smileySelectionStart = start;
              this.smileySelectionEnd = end;
            }
          })
            .id(this.quickReplyInputId)
            .defaultFocus(!this.isPostContextMenuVisible)
            .layoutWeight(1)
            .maxLines(6)
            .fontSize(17)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_muted'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 2, right: 2, top: 7, bottom: 7 })
            .onAppear(() => {
              this.requestQuickReplyFocus();
            })
            .onChange((value: string) => {
              this.replyDraft = value;
            })
          if (this.isReplySubmitting) {
            LoadingProgress()
              .width(48)
              .height(48)
              .padding(12)
          } else {
            Image($r('app.media.toolbar_send'))
              .width(48)
              .height(48)
              .objectFit(ImageFit.Contain)
              .draggable(false)
              .fillColor($r('app.color.brand'))
              .padding(8)
              .opacity(this.canSubmitReply() ? 1 : 0.3)
              .onClick(() => {
                if (this.quickReplySendLongPressed) {
                  this.quickReplySendLongPressed = false;
                  return;
                }
                this.submitReply();
              })
              .gesture(
                // ArkUI gives Image drag handling priority at >=500 ms. NG's
                // send icon is not draggable, so recognize this deliberate
                // promotion gesture slightly earlier and disable dragging.
                LongPressGesture({ repeat: false, duration: 400 })
                  .onAction(() => {
                    this.quickReplySendLongPressed = true;
                    this.openAdvancedReplyComposer();
                  })
              )
          }
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .border({ width: { top: 1 }, color: $r('app.color.border_strong') })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private getContentUrl(content: PostContent): string {
    return content.url === undefined ? '' : content.url;
  }

  private getContentIcon(content: PostContent): string {
    if (content.kind === 'attachment') {
      return '📎';
    }
    if (content.kind === 'video') {
      return '▶';
    }
    return '↗';
  }

  private getContentLabel(content: PostContent): string {
    if (content.kind === 'attachment') {
      return content.value;
    }
    if (content.kind === 'video') {
      return '使用默认浏览器打开视频';
    }
    return content.value;
  }

  private openContent(content: PostContent): void {
    const url: string = this.getContentUrl(content);
    const route = resolveForumLink(url, content.kind, content.value);
    if (route.kind === ForumLinkKind.InternalThread) {
      this.openThreadLink(route.threadId, route.page, route.floor, content.value);
      return;
    }
    if (route.kind === ForumLinkKind.Attachment) {
      void this.saveAttachment(route.url, content.value);
      return;
    }
    if (route.kind === ForumLinkKind.ExternalWeb) {
      this.openSystemLink(route.url, 'ohos.want.action.viewData', true);
      return;
    }
    if (route.kind === ForumLinkKind.Email) {
      this.openSystemLink(route.url, 'ohos.want.action.sendToData', false);
      return;
    }
    if (route.kind === ForumLinkKind.Phone) {
      this.openSystemLink(route.url, 'ohos.want.action.dial', false);
      return;
    }
    this.showLinkToast('暂不支持此链接类型');
  }

  /** P-20 deliberately gathers only images already parsed for this page. */
  private getVisibleCurrentPageImageItems(): ImageViewerItem[] {
    const result: ImageViewerItem[] = [];
    this.posts.forEach((post: ThreadPost) => {
      if (this.isPostHiddenByBlacklist(post)) {
        return;
      }
      post.content.forEach((content: PostContent, contentIndex: number) => {
        if (content.kind !== 'image') {
          return;
        }
        const url: string = this.getContentUrl(content);
        if (resolveForumLink(url, content.kind).kind === ForumLinkKind.ExternalWeb) {
          const previewSize: FourD4yPostImageSize | undefined = this.getPostImagePreviewSize(content);
          result.push({
            key: post.id + '-' + contentIndex,
            url: url,
            previewUrl: this.getPostImagePreviewUrl(content),
            previewWidth: previewSize === undefined ? undefined : previewSize.width,
            previewHeight: previewSize === undefined ? undefined : previewSize.height,
            floor: post.floor,
            authorName: post.authorName
          });
        }
      });
    });
    return result;
  }

  private openPostImage(content: PostContent, postId: string, contentIndex: number): void {
    const url: string = this.getContentUrl(content);
    if (resolveForumLink(url, content.kind).kind !== ForumLinkKind.ExternalWeb) {
      this.showLinkToast('暂不支持此图片地址');
      return;
    }
    const items: ImageViewerItem[] = this.getVisibleCurrentPageImageItems();
    const targetKey: string = postId + '-' + contentIndex;
    const initialIndex: number = items.findIndex((item: ImageViewerItem) => item.key === targetKey);
    const currentPost: ThreadPost | undefined = this.posts.find((post: ThreadPost) => post.id === postId);
    this.imageViewerRoute.openGallery(items.length > 0 ? items : [{
      key: targetKey,
      url: url,
      previewUrl: this.getPostImagePreviewUrl(content),
      previewWidth: this.getPostImagePreviewSize(content)?.width,
      previewHeight: this.getPostImagePreviewSize(content)?.height,
      floor: currentPost === undefined ? undefined : currentPost.floor,
      authorName: currentPost === undefined ? undefined : currentPost.authorName
    }],
      initialIndex >= 0 ? initialIndex : 0, this.getContentLabel(content), this.route.threadId,
      this.viewerUserId, this.route.forumId);
    this.pathStack.pushPathByName('ImageViewer', null);
  }

  private shouldShowContentUrl(content: PostContent): boolean {
    if (content.kind === 'attachment') {
      return false;
    }
    return resolveForumLink(this.getContentUrl(content), content.kind, content.value).kind !==
      ForumLinkKind.InternalThread;
  }

  private openThreadLink(threadId: string, page: number, floor: number, linkTitle: string): void {
    if (threadId === this.route.threadId) {
      this.pendingPostId = '';
      this.pendingFloor = floor;
      if (page !== this.currentPage) {
        this.lastPage = Math.max(this.lastPage, page);
        this.loadPage(page);
      } else {
        this.scrollToPendingFloor();
      }
      return;
    }
    const title: string = this.isFloorLinkLabel(linkTitle) ? '' : linkTitle;
    this.pathStack.pushPathByName('ThreadDetail',
      createThreadRouteParams(threadId, title, 0, page, floor));
  }

  private isFloorLinkLabel(value: string): boolean {
    return new RegExp('^\\s*\\d+\\s*#\\s*$').test(value);
  }

  private scrollToPendingFloor(): void {
    const targetIndex: number = this.consumePendingPostIndex();
    const sequence: number = this.webLoadSequence;
    if (targetIndex < 0) {
      return;
    }
    this.armPostLayoutAnchor(targetIndex);
    const revision: number = this.postLayoutAnchorRevision;
    setTimeout(() => {
      if (!this.isThreadPageAlive || sequence !== this.webLoadSequence ||
        revision !== this.postLayoutAnchorRevision) {
        return;
      }
      try {
        this.postListScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
      } catch (_error) {
        console.warn('Unable to scroll to the quoted forum floor.');
      }
    }, 0);
  }

  /**
   * The posts are applied while the loading branch is still visible, so the
   * List does not exist yet.  `scrollToIndex` at that point races the first
   * ArkUI layout.  Feed the verified target into List.initialIndex instead;
   * the value is consumed when the List is created after loading finishes.
   */
  private prepareInitialPostListIndex(): void {
    this.cancelPostLayoutAnchor();
    if (this.pendingFirstPostOfPage) {
      this.pendingFirstPostOfPage = false;
      this.pendingPostId = '';
      this.pendingFloor = 0;
      this.initialPostListIndex = 0;
      return;
    }
    if (this.pendingLastPostOfPage) {
      this.pendingLastPostOfPage = false;
      this.pendingPostId = '';
      this.pendingFloor = 0;
      this.initialPostListIndex = Math.max(0, this.posts.length - 1);
      this.armPostLayoutAnchor(this.initialPostListIndex);
      return;
    }
    const targetIndex: number = this.consumePendingPostIndex();
    this.initialPostListIndex = targetIndex >= 0 ? targetIndex : 0;
    this.armPostLayoutAnchor(targetIndex);
  }

  private cancelPostLayoutAnchor(): void {
    this.postLayoutAnchorIndex = -1;
    this.postLayoutAnchorRevision += 1;
    this.postLayoutAnchorQueued = false;
  }

  private armPostLayoutAnchor(index: number): void {
    this.cancelPostLayoutAnchor();
    if (index >= 0 && index < this.posts.length) {
      this.postLayoutAnchorIndex = index;
    }
  }

  private onPostLayoutSizeChanged(postId: string): void {
    const index: number = this.postLayoutAnchorIndex;
    if (!this.isThreadPageAlive || index < 0 || this.postLayoutAnchorQueued) {
      return;
    }
    const changedIndex: number = this.posts.findIndex((post: ThreadPost) => post.id === postId);
    if (changedIndex < 0 || changedIndex > index) {
      return;
    }
    const sequence: number = this.webLoadSequence;
    const revision: number = this.postLayoutAnchorRevision;
    this.postLayoutAnchorQueued = true;
    // InitialIndex positions the placeholder layout only. Image expansion above
    // an explicit destination must preserve that destination until user input.
    // Size callbacks run inside layout: defer once, never use a timed retry loop.
    setTimeout(() => {
      if (revision !== this.postLayoutAnchorRevision) {
        return;
      }
      this.postLayoutAnchorQueued = false;
      if (!this.isThreadPageAlive || sequence !== this.webLoadSequence ||
        index !== this.postLayoutAnchorIndex) {
        return;
      }
      try {
        this.postListScroller.scrollToIndex(index, false, ScrollAlign.START);
      } catch (_error) {
        // A detached list needs no correction. Later layout may try again.
      }
    }, 0);
  }

  private consumePendingPostIndex(): number {
    const postId: string = this.pendingPostId;
    const floor: number = this.pendingFloor;
    if (postId.length === 0 && floor <= 0) {
      return -1;
    }
    this.pendingPostId = '';
    this.pendingFloor = 0;
    let targetIndex: number = -1;
    if (postId.length > 0) {
      for (let index: number = 0; index < this.posts.length; index += 1) {
        if (this.posts[index].id === postId) {
          targetIndex = index;
          break;
        }
      }
    }
    // `viewpid` gives us an independently verified server floor. Keep PID as
    // the preferred identity, with the floor as a template-compatibility
    // fallback when the normal mobile page exposes another post-root id.
    if (targetIndex < 0 && floor > 0) {
      for (let index: number = 0; index < this.posts.length; index += 1) {
        if (this.posts[index].floor === floor) {
          targetIndex = index;
          break;
        }
      }
    }
    return targetIndex;
  }

  private async openSystemLink(url: string, action: string, browsable: boolean): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showLinkToast('暂时无法打开此链接');
      return;
    }
    const context: common.UIAbilityContext = hostContext as common.UIAbilityContext;
    const want: Want = {
      uri: url,
      action: action
    };
    if (browsable) {
      want.entities = ['entity.system.browsable'];
    }
    try {
      await context.startAbility(want);
    } catch (_error) {
      this.showLinkToast('系统未找到可处理此链接的应用');
    }
  }

  private showLinkToast(message: string): void {
    if (!this.isThreadPageAlive) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      console.warn('Unable to show link routing feedback.');
    }
  }

  /**
   * The system picker grants one writable public-file URI. ArkWeb then keeps
   * the authenticated forum request inside its own session and downloads to a
   * temporary sandbox path. The finished bytes are copied to that granted URI;
   * neither cookies nor raw response data enter application state.
   */
  private async saveAttachment(url: string, label: string): Promise<void> {
    // Keep diagnostics metadata-only: never log the signed attachment URL or
    // any Web session information.
    if (!isAllowedFourD4yAttachmentDownloadUrl(url)) {
      console.warn('4D4Y attachment rejected by the endpoint contract.');
      this.showLinkToast('暂不支持此附件地址');
      return;
    }
    if (this.isAttachmentPickerActive || this.isAttachmentDownloadActive || this.pendingAttachmentUrl.length > 0) {
      this.showLinkToast('已有附件正在处理，请稍候');
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined || !this.ensureAttachmentDownloadDelegate()) {
      this.showLinkToast('暂时无法初始化附件下载');
      return;
    }
    const context: common.UIAbilityContext = hostContext as common.UIAbilityContext;
    const displayName: string = createFourD4yAttachmentFileName(label);
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    this.isAttachmentPickerActive = true;
    try {
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [displayName];
      options.defaultFilePathUri = 'file://docs/storage/Users/currentUser/Download/';
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const destinationUris: string[] = await documentPicker.save(options);
      if (!this.isThreadPageAlive || sessionGeneration !== this.accountState.getSessionGeneration()) {
        return;
      }
      if (destinationUris.length !== 1 || destinationUris[0].length === 0) {
        this.showLinkToast('未选择附件保存位置');
        return;
      }
      const sequence: number = ++this.attachmentDownloadSequence;
      this.pendingAttachmentUrl = url;
      this.attachmentDestinationUri = destinationUris[0];
      this.attachmentDisplayName = displayName;
      this.attachmentTemporaryPath = context.cacheDir + '/hipda-oh-attachment-' + Date.now() + '-' +
        (++attachmentArtifactSequence) + '.download';
      this.startAttachmentDownloadWatchdog(sequence);
      try {
        this.threadWebController.startDownload(url);
      } catch (_error) {
        await this.failPendingAttachmentDownload(sequence, '附件下载未能启动，请稍后重试。');
      }
    } catch (_error) {
      console.warn('4D4Y attachment picker canceled or failed.');
      this.showLinkToast('已取消保存，或系统文件选择器暂不可用');
    } finally {
      this.isAttachmentPickerActive = false;
    }
  }


  private ensureAttachmentDownloadDelegate(): boolean {
    if (this.isAttachmentDownloadDelegateAttached) {
      return true;
    }
    try {
      this.attachmentDownloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
        this.onBeforeAttachmentDownload(item);
      });
      // ArkWeb emits update notifications even when the UI does not expose a
      // progress bar. Register the callback so the native download delegate
      // remains complete and finish/failure delivery is not dropped.
      this.attachmentDownloadDelegate.onDownloadUpdated((_item: webview.WebDownloadItem) => {
        // P-09 intentionally has no in-app queue or persistent progress model.
      });
      this.attachmentDownloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
        void this.onAttachmentDownloadFinished(item);
      });
      this.attachmentDownloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
        void this.onAttachmentDownloadFailed(item);
      });
      this.threadWebController.setDownloadDelegate(this.attachmentDownloadDelegate);
      this.isAttachmentDownloadDelegateAttached = true;
      return true;
    } catch (_error) {
      console.error('Unable to attach the ArkWeb download delegate.');
      return false;
    }
  }

  private onBeforeAttachmentDownload(item: webview.WebDownloadItem): void {
    const sequence: number = this.attachmentDownloadSequence;
    if (this.pendingAttachmentUrl.length === 0 || this.attachmentDestinationUri.length === 0 ||
      this.attachmentTemporaryPath.length === 0 || this.isAttachmentDownloadActive) {
      item.cancel();
      return;
    }
    // API 24 exposes the original request even when the file endpoint redirects.
    // A delayed callback from a timed-out request must not claim a later picker.
    if (item.getOriginalUrl() !== this.pendingAttachmentUrl) {
      item.cancel();
      return;
    }
    const mimeType: string = item.getMimeType().trim().toLowerCase();
    if (mimeType.startsWith('text/html')) {
      void this.failPendingAttachmentDownload(sequence, '附件地址返回了网页，请重新登录后再试。');
      item.cancel();
      return;
    }
    this.clearAttachmentDownloadStartWatchdog();
    this.attachmentDownloadGuid = item.getGuid();
    this.isAttachmentDownloadActive = true;
    this.pendingAttachmentUrl = '';
    try {
      item.start(this.attachmentTemporaryPath);
      this.showLinkToast('开始下载：' + this.attachmentDisplayName);
    } catch (_error) {
      void this.failActiveAttachmentDownload('附件下载未能写入临时文件。');
      item.cancel();
    }
  }

  private async onAttachmentDownloadFinished(item: webview.WebDownloadItem): Promise<void> {
    if (!this.isCurrentAttachmentDownload(item)) {
      return;
    }
    const temporaryPath: string = this.attachmentTemporaryPath;
    const destinationUri: string = this.attachmentDestinationUri;
    const displayName: string = this.attachmentDisplayName;
    // Claim the terminal callback before awaiting file I/O. Duplicate finish or
    // failure callbacks must not copy, truncate, or reset this operation twice.
    this.attachmentDownloadGuid = '';
    try {
      const destinationFile: fileIo.File = await fileIo.open(destinationUri,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.copyFile(temporaryPath, destinationFile.fd);
      } finally {
        await fileIo.close(destinationFile);
      }
      await this.removeFileQuietly(temporaryPath);
      this.resetAttachmentDownloadState();
      this.showLinkToast('附件已保存：' + displayName);
    } catch (_error) {
      await this.removeFileQuietly(temporaryPath);
      this.resetAttachmentDownloadState();
      this.showLinkToast('附件已下载，但写入所选位置失败。');
    }
  }

  private async onAttachmentDownloadFailed(item: webview.WebDownloadItem): Promise<void> {
    if (!this.isCurrentAttachmentDownload(item)) {
      return;
    }
    await this.failActiveAttachmentDownload('附件下载失败，请检查网络或登录状态。');
  }

  private isCurrentAttachmentDownload(item: webview.WebDownloadItem): boolean {
    return this.isAttachmentDownloadActive && this.attachmentDownloadGuid.length > 0 &&
      item.getGuid() === this.attachmentDownloadGuid;
  }

  private startAttachmentDownloadWatchdog(sequence: number): void {
    this.clearAttachmentDownloadStartWatchdog();
    this.attachmentDownloadStartTimeoutId = setTimeout(() => {
      void this.failPendingAttachmentDownload(sequence, '附件下载未能启动，请稍后重试。');
    }, 15000);
  }

  private clearAttachmentDownloadStartWatchdog(): void {
    if (this.attachmentDownloadStartTimeoutId >= 0) {
      clearTimeout(this.attachmentDownloadStartTimeoutId);
      this.attachmentDownloadStartTimeoutId = -1;
    }
  }

  private async failPendingAttachmentDownload(sequence: number, message: string): Promise<void> {
    if (sequence !== this.attachmentDownloadSequence || this.pendingAttachmentUrl.length === 0) {
      return;
    }
    this.resetAttachmentDownloadState();
    // A Picker URI is user-owned. It is not safe to infer that it was created
    // by this download or delete it when the transfer never started.
    this.showLinkToast(message);
  }

  private async failActiveAttachmentDownload(message: string): Promise<void> {
    const temporaryPath: string = this.attachmentTemporaryPath;
    this.resetAttachmentDownloadState();
    await this.removeFileQuietly(temporaryPath);
    this.showLinkToast(message);
  }

  private resetAttachmentDownloadState(): void {
    this.clearAttachmentDownloadStartWatchdog();
    this.pendingAttachmentUrl = '';
    this.attachmentDestinationUri = '';
    this.attachmentTemporaryPath = '';
    this.attachmentDisplayName = '';
    this.attachmentDownloadGuid = '';
    this.isAttachmentDownloadActive = false;
  }

  private async removeFileQuietly(path: string): Promise<void> {
    if (path.length === 0) {
      return;
    }
    try {
      await fileIo.unlink(path);
    } catch (_error) {
      console.warn('Unable to remove an attachment download artifact.');
    }
  }

  private openPagePicker(): void {
    if (this.isLoading || this.isReplyComposerVisible || this.isPagePickerVisible) {
      return;
    }
    this.selectedPage = this.currentPage;
    this.isPagePickerVisible = true;
  }

  private jumpToPage(page: number, dismissPicker: boolean = true): void {
    if (this.isLoading || page < 1 || page > this.lastPage) {
      return;
    }
    this.selectedPage = page;
    if (dismissPicker) {
      this.isPagePickerVisible = false;
    }
    this.loadPage(page);
  }

  /**
   * The double-tap picker treats « and » as "go to the first/last floor".
   * Reloading a current endpoint page is intentional: the List needs a fresh
   * initial index to move from an arbitrary floor on that same page.
   */
  private jumpToThreadEndpoint(page: number, lastPost: boolean): void {
    if (this.isLoading || this.isLoadingMore || page < 1 || page > this.lastPage) {
      return;
    }
    this.pendingFirstPostOfPage = !lastPost;
    this.pendingLastPostOfPage = lastPost;
    this.pendingPostId = '';
    this.pendingFloor = 0;
    this.selectedPage = page;
    this.isPagePickerVisible = false;
    this.loadPage(page);
  }

  private estimateLastPage(): number {
    // The mobile 4D4Y page has a fixed 50-post page size and only exposes a
    // next-page link. The list response provides the total replies instead.
    return estimateLastPageFromReplyCount(this.route.replyCount);
  }

  private loadNextThreadPage(): void {
    if (this.isLoading || this.isRefreshing || this.isLoadingMore || this.isAppendingThreadPage ||
      this.currentPage >= this.lastPage) {
      return;
    }
    this.loadPage(this.currentPage + 1, true);
  }

  /** Reload the visible server page while preserving its List position. */
  private refreshCurrentThreadPage(): void {
    // Refresh's two-way binding may already set isRefreshing before this
    // callback runs, so it is deliberately not part of this guard.
    if (this.isLoading || this.isLoadingMore || this.posts.length === 0) {
      return;
    }
    try {
      const offset: OffsetResult | undefined = this.postListScroller.offset();
      this.pendingRefreshScrollOffset = offset === undefined ? 0 : Math.max(0, offset.yOffset);
    } catch (_error) {
      this.pendingRefreshScrollOffset = 0;
    }
    this.loadPage(this.firstRenderedPage, false, true);
  }

  private loadPage(page: number, append: boolean = false, preserveVisibleContent: boolean = false): void {
    if (this.isLoading || this.isLoadingMore || page < 1 ||
      (append && (page !== this.currentPage + 1 || page > this.lastPage))) {
      return;
    }
    this.isAppendingThreadPage = append;
    this.cancelPostLayoutAnchor();
    if (append) {
      this.isLoadingMore = true;
      this.loadMoreError = '';
    } else if (preserveVisibleContent && this.posts.length > 0 && page === this.firstRenderedPage) {
      this.isRefreshing = true;
      this.loadError = '';
      this.loadMoreError = '';
    } else {
      this.isLoading = true;
      this.isRefreshing = false;
      this.pendingRefreshScrollOffset = -1;
      this.initialPostListIndex = 0;
      this.loadError = '';
      this.loadMoreError = '';
      this.posts = this.postRowVersions.track([]);
      this.postImageSizes = [];
      this.selectablePostId = '';
    }
    this.needsWebVerification = false;
    this.webLoadSequence += 1;
    this.startThreadLoadWatchdog(this.webLoadSequence);
    this.requestedPage = page;
    this.threadPageUrl = buildFourD4yThreadReaderUrl(this.route.threadId, page, this.webLoadSequence,
      this.authorOnlyUserId);
    if (this.threadPageUrl.length === 0) {
      this.failThreadLoad(this.webLoadSequence, '当前帖子地址无效。');
      return;
    }
    if (!this.isThreadWebControllerAttached) {
      return;
    }
    try {
      this.threadWebController.loadUrl(this.threadPageUrl);
    } catch (_error) {
      // The initial source is loaded after the Web component is attached.
    }
  }

  private openReplyComposer(post?: ThreadPost): void {
    if (!this.isLoggedIn || this.route.threadId.length === 0) {
      return;
    }
    if (post !== undefined && /^\d+$/.test(post.id)) {
      this.showQuickReply(QuickReplyMode.Reply, post);
      return;
    }
    this.showQuickReply(QuickReplyMode.Thread);
  }

  private openQuoteComposer(post: ThreadPost): void {
    if (!this.isLoggedIn || this.route.threadId.length === 0 || !/^\d+$/.test(post.id)) {
      return;
    }
    this.showQuickReply(QuickReplyMode.Quote, post);
  }

  private showQuickReply(mode: QuickReplyMode, post?: ThreadPost): void {
    if (!this.isLoggedIn || !/^\d+$/.test(this.route.threadId)) {
      return;
    }
    if (mode === QuickReplyMode.Quote && (post === undefined || !/^\d+$/.test(post.id))) {
      return;
    }
    this.quickReplyMode = mode;
    this.quickReplyTargetPostId = post === undefined ? '' : post.id;
    this.quickReplyTargetFloor = post === undefined ? 0 : post.floor;
    this.quickReplyTargetAuthorName = post === undefined ? '' : post.authorName;
    this.replyDraft = '';
    this.replyPreflightMessage = '';
    this.replySubmissionErrorMessage = '';
    this.quickReplySendLongPressed = false;
    this.isReplyComposerVisible = true;
    if (!this.isPostContextMenuVisible) {
      this.setQuickReplyKeyboardAvoidMode();
    }
    this.prepareReplyForm();
    this.requestQuickReplyFocus();
  }

  private closeQuickReply(discardDraft: boolean): void {
    // A canceled GET preflight must not dispatch a POST when it settles later.
    // An already dispatched POST remains tracked until its result is known.
    if (!this.isReplySubmitting) {
      this.replyPreflightSequence += 1;
      this.replySubmissionSequence += 1;
      this.clearReplyPreflightWatchdog();
      this.isReplyPreflightLoading = false;
      this.isReplyFormReady = false;
      this.replyWebOperation = ReplyWebOperation.Preflight;
      this.pendingReplyDraft = '';
    }
    this.isReplyComposerVisible = false;
    if (discardDraft) {
      this.replyDraft = '';
    }
    this.quickReplyMode = QuickReplyMode.Thread;
    this.quickReplyTargetPostId = '';
    this.quickReplyTargetFloor = 0;
    this.quickReplyTargetAuthorName = '';
    this.restoreQuickReplyKeyboardAvoidMode();
  }

  private openAdvancedReplyComposer(): void {
    if (!this.isReplyComposerVisible || this.isReplySubmitting || !/^\d+$/.test(this.route.threadId)) {
      return;
    }
    const initialDraft: string = this.replyDraft;
    const quickMode: QuickReplyMode = this.quickReplyMode;
    const postId: string = this.quickReplyTargetPostId;
    const floor: number = this.quickReplyTargetFloor;
    const authorName: string = this.quickReplyTargetAuthorName;
    this.closeQuickReply(true);
    if (quickMode === QuickReplyMode.Quote && /^\d+$/.test(postId)) {
      this.pathStack.pushPathByName('ForumComposer', createQuoteComposerRouteParams(
        this.route.threadId, postId, floor, authorName,
        this.resolvedTitle || this.route.threadTitle, this.route.forumId, initialDraft
      ), (popInfo: PopInfo) => {
        this.refreshAfterComposerReply(popInfo);
      });
      return;
    }
    this.pathStack.pushPathByName('ForumComposer',
      createReplyComposerRouteParams(this.route.threadId, this.resolvedTitle || this.route.threadTitle,
        this.route.forumId, initialDraft), (popInfo: PopInfo) => {
          this.refreshAfterComposerReply(popInfo);
        });
  }

  private shouldShowQuickReplyFab(): boolean {
    return this.isLoggedIn && !this.isLoading && !this.needsWebVerification &&
      !this.isReplyComposerVisible && /^\d+$/.test(this.route.threadId) && this.posts.length > 0;
  }

  private getQuickReplyHint(): string {
    if (this.quickReplyMode === QuickReplyMode.Quote && this.quickReplyTargetFloor > 0) {
      return '引用 #' + this.quickReplyTargetFloor + (this.quickReplyTargetAuthorName.length > 0 ?
        (' · ' + this.quickReplyTargetAuthorName) : '');
    }
    if (this.quickReplyMode === QuickReplyMode.Reply && this.quickReplyTargetFloor > 0) {
      return '回复 #' + this.quickReplyTargetFloor + (this.quickReplyTargetAuthorName.length > 0 ?
        (' · ' + this.quickReplyTargetAuthorName) : '');
    }
    return '快速回复';
  }

  private setQuickReplyKeyboardAvoidMode(): void {
    if (this.hasAdjustedQuickReplyKeyboardAvoidMode) {
      return;
    }
    try {
      const context = this.getUIContext();
      this.previousQuickReplyKeyboardAvoidMode = context.getKeyboardAvoidMode();
      context.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      this.hasAdjustedQuickReplyKeyboardAvoidMode = true;
    } catch (_error) {
      // The reader stays usable with the system default while its destination attaches.
    }
  }

  private restoreQuickReplyKeyboardAvoidMode(): void {
    if (!this.hasAdjustedQuickReplyKeyboardAvoidMode) {
      return;
    }
    try {
      this.getUIContext().setKeyboardAvoidMode(this.previousQuickReplyKeyboardAvoidMode);
    } catch (_error) {
      // The destination may already be closing; no extra keyboard operation is needed.
    }
    this.hasAdjustedQuickReplyKeyboardAvoidMode = false;
  }

  private onPostContextMenuClosed(): void {
    this.isPostContextMenuVisible = false;
    if (!this.isThreadPageAlive || !this.isReplyComposerVisible) {
      return;
    }
    // The menu owns a child window until its exit animation has completed.
    // Hand keyboard avoidance/focus back to the reader only after that point.
    this.setQuickReplyKeyboardAvoidMode();
    this.requestQuickReplyFocus();
  }

  private requestQuickReplyFocus(): void {
    const sequence: number = this.replyPreflightSequence;
    setTimeout(() => {
      if (!this.isThreadPageAlive || !this.isReplyComposerVisible || this.isPostContextMenuVisible ||
        sequence !== this.replyPreflightSequence) {
        return;
      }
      try {
        this.getUIContext().getFocusController().requestFocus(this.quickReplyInputId);
      } catch (_error) {
        // defaultFocus remains the fallback for an early frame during navigation.
      }
    }, 0);
  }

  /** The route carries only stable ids; the composer independently rechecks the live edit form. */
  private openEditComposer(post: ThreadPost): void {
    if (!this.canEditPost(post)) {
      return;
    }
    const expectedPostId: string = post.id;
    this.pathStack.pushPathByName('ForumComposer', createEditComposerRouteParams(
      this.route.threadId, expectedPostId, this.resolvedTitle || this.route.threadTitle, this.route.forumId
    ), (popInfo: PopInfo) => {
      if (!isForumComposerPostEditedResult(popInfo.result, this.route.threadId, expectedPostId)) {
        return;
      }
      this.loadPage(this.currentPage);
    });
  }

  /** The UI must never infer ownership from a display name. */
  private isPostOwnedByCurrentViewer(post: ThreadPost): boolean {
    return this.isLoggedIn && /^\d{1,20}$/.test(this.viewerUserId) &&
      post.authorUserId !== undefined && /^\d{1,20}$/.test(post.authorUserId) &&
      post.authorUserId === this.viewerUserId;
  }

  private canRequestPostDeletion(post: ThreadPost): boolean {
    return this.isPostOwnedByCurrentViewer(post) && /^\d{1,20}$/.test(post.id) &&
      /^\d{1,20}$/.test(this.route.threadId) && /^\d{1,20}$/.test(this.route.forumId) &&
      this.currentPage >= 1;
  }

  private canEditPost(post: ThreadPost): boolean {
    // NG allows editing by viewer/post identity. A notification, search or
    // favorite route may not yet know fid; the editor obtains a fresh form
    // for this exact tid/pid rather than inheriting deletion's fid contract.
    return this.isPostOwnedByCurrentViewer(post) && /^\d{1,20}$/.test(post.id) &&
      /^\d{1,20}$/.test(this.route.threadId);
  }

  private getPostDeletionButtonLabel(post: ThreadPost): string {
    if (this.isPostDeletionSubmitting && post.id === this.postDeletionPreflightPostId) {
      return '删除中…';
    }
    return this.isPostDeletionPreflightLoading && post.id === this.postDeletionPreflightPostId ?
      '校验中…' : '删除';
  }

  /**
   * P-16 phase one is deliberately read-only.  It discovers whether the live
   * 4D4Y edit form grants deletion for this exact uid/pid/tid context; no
   * native state is treated as server authority and no form is submitted.
   */
  private requestPostDeletionEligibility(post: ThreadPost): void {
    if (!this.canRequestPostDeletion(post) || this.isPostDeletionPreflightLoading ||
      this.isPostDeletionSubmitting || this.postDeletionConfirmationPending) {
      return;
    }
    const sequence: number = this.postDeletionPreflightSequence + 1;
    const url: string | null = buildFourD4yPostDeletionPreflightUrl(this.route.threadId, post.id,
      this.route.forumId, sequence);
    if (url === null) {
      this.showLinkToast('当前帖子缺少可校验的删除标识。');
      return;
    }
    this.postDeletionPreflightSequence = sequence;
    this.postDeletionPreflightPostId = post.id;
    this.postDeletionPreflightPage = 1;
    this.postDeletionPreflightUrl = url;
    this.postDeletionFormReady = false;
    this.postDeletionMessage = '正在校验服务器删除资格…';
    this.isPostDeletionPreflightLoading = true;
    this.startPostDeletionPreflightWatchdog(sequence);
    if (!this.isPostDeletionWebControllerAttached) {
      return;
    }
    try {
      this.postDeletionWebController.loadUrl(url);
    } catch (_error) {
      this.failPostDeletionPreflight('暂时无法初始化删除资格校验。');
    }
  }

  private isCurrentPostDeletionPreflightRequest(url: string): boolean {
    return this.isPostDeletionPreflightLoading && isCurrentFourD4yPostDeletionPreflightRequest(url,
      this.route.threadId, this.postDeletionPreflightPostId, this.route.forumId);
  }

  private async readPostDeletionPreflightFromWeb(): Promise<void> {
    const expectedSequence: number = this.postDeletionPreflightSequence;
    const expectedThreadId: string = this.route.threadId;
    const expectedPostId: string = this.postDeletionPreflightPostId;
    const expectedForumId: string = this.route.forumId;
    const expectedPage: number = this.postDeletionPreflightPage;
    if (!this.isPostDeletionPreflightLoading || expectedPostId.length === 0) {
      return;
    }
    try {
      const rawResult: string = await this.postDeletionWebController.runJavaScript(
        this.getPostDeletionPreflightExtractionScript(expectedThreadId, expectedPostId, expectedForumId,
          expectedPage, expectedSequence)
      );
      if (!this.isPostDeletionPreflightLoading || expectedSequence !== this.postDeletionPreflightSequence) {
        return;
      }
      const payload: FourD4yPostDeletionPreflightPayload | null =
        parseFourD4yPostDeletionPreflightPayload(rawResult);
      if (payload === null || !isExpectedFourD4yPostDeletionPreflight(payload, expectedThreadId,
        expectedPostId, expectedForumId, expectedPage, expectedSequence)) {
        this.failPostDeletionPreflight('删除表单已打开，但无法确认它属于当前帖子；未执行任何操作。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failPostDeletionPreflight('4D4Y 登录状态已失效，未执行删除。');
        return;
      }
      if (payload.hasChallenge) {
        this.failPostDeletionPreflight('4D4Y 要求先完成网页安全验证，未执行删除。');
        return;
      }
      if (!isReadyFourD4yPostDeletionForm(payload)) {
        this.failPostDeletionPreflight(payload.errorMessage.length > 0 ? payload.errorMessage :
          '服务器未提供可确认的删除控件，未执行任何操作。');
        return;
      }
      this.clearPostDeletionPreflightWatchdog();
      this.isPostDeletionPreflightLoading = false;
      this.postDeletionFormReady = true;
      this.postDeletionMessage = '服务器已确认可真实删除；请在确认框中决定。';
      this.requestPostDeletionConfirmation();
    } catch (_error) {
      if (expectedSequence === this.postDeletionPreflightSequence) {
        this.failPostDeletionPreflight('暂时无法读取删除表单，请稍后重试。');
      }
    }
  }

  private startPostDeletionPreflightWatchdog(sequence: number): void {
    this.clearPostDeletionPreflightWatchdog();
    this.postDeletionPreflightTimeoutId = setTimeout(() => {
      if (!this.isPostDeletionPreflightLoading || sequence !== this.postDeletionPreflightSequence) {
        return;
      }
      this.failPostDeletionPreflight('校验删除资格超时，未执行任何操作。');
      try {
        this.postDeletionWebController.stop();
      } catch (_error) {
        // The hidden page may have completed while this timeout was firing.
      }
    }, this.webLoadTimeoutMillis);
  }

  private clearPostDeletionPreflightWatchdog(): void {
    if (this.postDeletionPreflightTimeoutId >= 0) {
      clearTimeout(this.postDeletionPreflightTimeoutId);
      this.postDeletionPreflightTimeoutId = -1;
    }
  }

  private failPostDeletionPreflight(message: string): void {
    this.clearPostDeletionPreflightWatchdog();
    this.isPostDeletionPreflightLoading = false;
    this.postDeletionFormReady = false;
    this.postDeletionMessage = message;
    this.showLinkToast(message);
  }

  /** A destructive write is always a separate native confirmation. */
  private requestPostDeletionConfirmation(): void {
    if (!this.isThreadPageAlive || !this.postDeletionFormReady || this.postDeletionConfirmationPending ||
      this.isPostDeletionSubmitting || this.postDeletionPreflightPostId.length === 0) {
      return;
    }
    const confirmationSequence: number = this.postDeletionPreflightSequence;
    const confirmationPostId: string = this.postDeletionPreflightPostId;
    this.postDeletionConfirmationPending = true;
    this.getUIContext().getPromptAction().showDialog({
      message: '确认删除这条自己发表的内容吗？此操作不可恢复。仅在服务器已确认可真实删除时才会提交。',
      buttons: [
        { text: '取消', color: $r('app.color.text_body') },
        { text: '删除', color: $r('app.color.danger_text') }
      ]
    }).then((result) => {
      if (!this.isThreadPageAlive || confirmationSequence !== this.postDeletionPreflightSequence ||
        confirmationPostId !== this.postDeletionPreflightPostId) {
        return;
      }
      this.postDeletionConfirmationPending = false;
      if (result.index === 1) {
        this.beginPostDeletionSubmission();
        return;
      }
      this.postDeletionFormReady = false;
      this.postDeletionMessage = '已取消删除。';
    }).catch(() => {
      if (!this.isThreadPageAlive || confirmationSequence !== this.postDeletionPreflightSequence ||
        confirmationPostId !== this.postDeletionPreflightPostId) {
        return;
      }
      this.postDeletionConfirmationPending = false;
      this.postDeletionFormReady = false;
      this.postDeletionMessage = '已取消删除。';
    });
  }

  /**
   * The form still belongs to the hidden ArkWeb document, so its one-time
   * token and all other field values cannot enter ArkTS.  This method is only
   * reachable after the same fresh form exposed input#delete and the user
   * explicitly confirmed the native destructive-action dialog.
   */
  private async beginPostDeletionSubmission(): Promise<void> {
    if (!this.isThreadPageAlive) {
      return;
    }
    const threadId: string = this.route.threadId;
    const postId: string = this.postDeletionPreflightPostId;
    const targetPost: ThreadPost | undefined = this.posts.find((post: ThreadPost) => post.id === postId);
    if (!this.postDeletionFormReady || this.isPostDeletionSubmitting || !/^[0-9]{1,20}$/.test(threadId) ||
      !/^[0-9]{1,20}$/.test(postId) || targetPost === undefined) {
      this.postDeletionFormReady = false;
      this.postDeletionMessage = '删除资格已过期，请重新校验后再试。';
      return;
    }
    this.postDeletionFormReady = false;
    this.postDeletionSubmissionSequence += 1;
    const submissionSequence: number = this.postDeletionSubmissionSequence;
    this.postDeletionTargetWasFirstPost = targetPost.floor === 1;
    this.postDeletionVerificationAttempt = 0;
    this.isPostDeletionVerificationLoading = false;
    this.isPostDeletionSubmitting = true;
    this.postDeletionMessage = '正在提交删除请求，请勿重复操作…';
    this.startPostDeletionSubmissionWatchdog(submissionSequence);
    try {
      const rawResult: string = await this.postDeletionWebController.runJavaScript(
        this.getPostDeletionSubmissionScript(threadId, postId, submissionSequence)
      );
      if (!this.isPostDeletionSubmitting || submissionSequence !== this.postDeletionSubmissionSequence) {
        return;
      }
      const payload: FourD4yPostDeletionSubmissionStartPayload | null =
        parseFourD4yPostDeletionSubmissionStartPayload(rawResult);
      if (payload === null || !isExpectedFourD4yPostDeletionSubmissionStart(payload, threadId, postId,
        submissionSequence)) {
        this.failPostDeletionSubmission('删除请求未能确认启动；未将本地状态当作已删除。');
        return;
      }
      if (!payload.started) {
        this.failPostDeletionSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前删除表单已变化，未提交删除。');
        return;
      }
      // onPageEnd reads the POST's result. A timer-driven loadUrl here can
      // abort a slow POST and discards the forum redirect after topic deletion.
    } catch (_error) {
      // ArkWeb can begin the form navigation before returning JS's result.
      // Keep waiting for onPageEnd/the watchdog; never retry the write.
    }
  }

  private startPostDeletionSubmissionWatchdog(submissionSequence: number): void {
    this.clearPostDeletionSubmissionWatchdog();
    this.postDeletionSubmissionTimeoutId = setTimeout(() => {
      if (!this.isPostDeletionSubmitting || submissionSequence !== this.postDeletionSubmissionSequence) {
        return;
      }
      this.failPostDeletionSubmission('删除请求超时，无法确认结果；请先刷新主题核对。');
      try {
        this.postDeletionWebController.stop();
      } catch (_error) {
        // The isolated page may have completed while the timeout was firing.
      }
    }, this.webLoadTimeoutMillis);
  }

  private onPostDeletionResultPageEnd(): void {
    if (!this.isThreadPageAlive || !this.isPostDeletionSubmitting) {
      return;
    }
    this.isPostDeletionVerificationLoading = true;
    void this.readPostDeletionVerificationFromWeb();
  }

  private schedulePostDeletionVerification(submissionSequence: number, delayMillis: number): void {
    if (!this.isPostDeletionSubmitting || submissionSequence !== this.postDeletionSubmissionSequence) {
      return;
    }
    if (this.postDeletionVerificationPollTimeoutId >= 0) {
      clearTimeout(this.postDeletionVerificationPollTimeoutId);
    }
    this.postDeletionVerificationPollTimeoutId = setTimeout(() => {
      if (!this.isPostDeletionSubmitting || submissionSequence !== this.postDeletionSubmissionSequence) {
        return;
      }
      if (!this.isPostDeletionWebControllerAttached) {
        this.failPostDeletionSubmission('无法初始化服务器删除结果核验。');
        return;
      }
      this.isPostDeletionVerificationLoading = true;
      // Reinspect a possible delayed server redirect; do not navigate away
      // from the submission response and do not issue a second write.
      void this.readPostDeletionVerificationFromWeb();
    }, delayMillis);
  }

  private async readPostDeletionVerificationFromWeb(): Promise<void> {
    const submissionSequence: number = this.postDeletionSubmissionSequence;
    const threadId: string = this.route.threadId;
    const postId: string = this.postDeletionPreflightPostId;
    if (!this.isPostDeletionSubmitting || !this.isPostDeletionVerificationLoading ||
      submissionSequence < 1 || postId.length === 0) {
      return;
    }
    try {
      const rawResult: string = await this.postDeletionWebController.runJavaScript(
        this.getPostDeletionVerificationScript(threadId, postId, submissionSequence)
      );
      if (!this.isPostDeletionSubmitting || !this.isPostDeletionVerificationLoading ||
        submissionSequence !== this.postDeletionSubmissionSequence) {
        return;
      }
      const payload: FourD4yPostDeletionVerificationPayload | null =
        parseFourD4yPostDeletionVerificationPayload(rawResult);
      if (payload === null || !isExpectedFourD4yPostDeletionVerification(payload, threadId, postId,
        submissionSequence)) {
        this.failPostDeletionSubmission('服务器删除结果的页面结构无法确认，请手动核对。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failPostDeletionSubmission('4D4Y 登录状态已失效，无法确认删除结果。');
        return;
      }
      if (payload.hasChallenge) {
        this.failPostDeletionSubmission('4D4Y 要求先完成安全验证，无法确认删除结果。');
        return;
      }
      if (!isConfirmedFourD4yPostDeletion(payload, this.postDeletionTargetWasFirstPost)) {
        this.postDeletionVerificationAttempt += 1;
        if (this.postDeletionVerificationAttempt < 3) {
          this.isPostDeletionVerificationLoading = false;
          this.schedulePostDeletionVerification(submissionSequence, 1000);
          return;
        }
        this.failPostDeletionSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '服务器尚未确认删除成功；请手动刷新主题核对。');
        return;
      }
      this.completePostDeletion();
    } catch (_error) {
      if (this.isPostDeletionSubmitting && submissionSequence === this.postDeletionSubmissionSequence) {
        this.failPostDeletionSubmission('读取服务器删除结果失败，请手动核对。');
      }
    }
  }

  private completePostDeletion(): void {
    this.clearPostDeletionSubmissionWatchdog();
    this.isPostDeletionSubmitting = false;
    this.isPostDeletionVerificationLoading = false;
    this.postDeletionMessage = '服务器已确认删除。';
    this.showLinkToast(this.postDeletionMessage);
    if (this.postDeletionTargetWasFirstPost) {
      this.threadMutationState.notifyDeleted(this.route.threadId, this.route.forumId,
        this.accountState.getSessionGeneration());
      this.pathStack.pop();
      return;
    }
    this.loadPage(this.currentPage);
  }

  private failPostDeletionSubmission(message: string): void {
    this.clearPostDeletionSubmissionWatchdog();
    this.isPostDeletionSubmitting = false;
    this.isPostDeletionVerificationLoading = false;
    this.postDeletionFormReady = false;
    this.postDeletionMessage = message;
    this.showLinkToast(message);
  }

  private clearPostDeletionSubmissionWatchdog(): void {
    if (this.postDeletionSubmissionTimeoutId >= 0) {
      clearTimeout(this.postDeletionSubmissionTimeoutId);
      this.postDeletionSubmissionTimeoutId = -1;
    }
    if (this.postDeletionVerificationPollTimeoutId >= 0) {
      clearTimeout(this.postDeletionVerificationPollTimeoutId);
      this.postDeletionVerificationPollTimeoutId = -1;
    }
  }

  private refreshAfterComposerReply(popInfo: PopInfo): void {
    if (!isForumComposerReplyPublishedResult(popInfo.result, this.route.threadId)) {
      return;
    }
    const updatedReplyCount: number = this.route.replyCount + 1;
    const expectedLastPage: number = estimateLastPageFromReplyCount(updatedReplyCount);
    this.route = {
      threadId: this.route.threadId,
      threadTitle: this.route.threadTitle,
      forumId: this.route.forumId,
      replyCount: updatedReplyCount,
      initialPage: this.route.initialPage,
      initialFloor: this.route.initialFloor,
      initialPostId: this.route.initialPostId,
      initialFavoriteState: this.route.initialFavoriteState,
      initialFavoritePage: this.route.initialFavoritePage,
      initialAttentionState: this.route.initialAttentionState,
      initialAttentionPage: this.route.initialAttentionPage
    };
    this.lastPage = Math.max(this.lastPage, expectedLastPage);
    // A newly posted reply may not belong to the topic author. NG returns to
    // the complete topic after a successful post for the same reason.
    this.authorOnlyUserId = '';
    this.isThreadAuthorResolving = false;
    this.pendingPostId = '';
    this.pendingFloor = 0;
    this.pendingLastPostOfPage = true;
    this.loadPage(this.lastPage);
  }

  /**
   * Preflight is intentionally GET-only. It reads structural form metadata so
   * the later POST path can demand a fresh token instead of guessing fields
   * from a different Discuz deployment.
   */
  private prepareReplyForm(operation: ReplyWebOperation = ReplyWebOperation.Preflight): void {
    if (!this.isThreadPageAlive || !this.isReplyComposerVisible) {
      return;
    }
    this.replyPreflightSequence += 1;
    const sequence: number = this.replyPreflightSequence;
    this.replyWebOperation = operation;
    this.clearReplyPreflightWatchdog();
    this.isReplyPreflightLoading = true;
    this.isReplyFormReady = false;
    this.replyPreflightMessage = '';
    this.replyFormUrl = 'https://www.4d4y.com/forum/post.php?action=reply&tid=' + this.route.threadId;
    // Only a quote asks the live server form to generate a quote prefix. The
    // prefix remains in the ArkWeb DOM and is joined there at submission time.
    if (this.quickReplyMode === QuickReplyMode.Quote && /^\d+$/.test(this.quickReplyTargetPostId)) {
      this.replyFormUrl += '&repquote=' + this.quickReplyTargetPostId;
    }
    this.replyFormUrl += '&oh_reply_prepare=' + sequence;
    this.startReplyPreflightWatchdog(sequence);
    if (!this.isReplyWebControllerAttached) {
      return;
    }
    try {
      this.replyWebController.loadUrl(this.replyFormUrl);
    } catch (_error) {
      // The Web component can still be attaching on the first open.
    }
  }

  private isCurrentReplyPreflightRequest(url: string): boolean {
    return this.isThreadPageAlive && isCurrentFourD4yPostPreflightUrl(url, 'reply', this.route.threadId,
      '', 'oh_reply_prepare', this.replyPreflightSequence);
  }

  private handleCompletedReplyWebLoad(url: string): void {
    // The GET form can emit both completion callbacks. Identify it before
    // looking at isReplySubmitting, because the first callback may have just
    // changed that flag while the second callback still belongs to the GET.
    if (this.isCurrentReplyPreflightRequest(url)) {
      if (!this.isReplySubmitting) {
        this.readReplyPreflightFromWeb();
      }
      return;
    }
    if (this.isReplySubmitting) {
      this.readReplySubmissionResult(url);
    }
  }

  private async readReplyPreflightFromWeb(): Promise<void> {
    const expectedSequence: number = this.replyPreflightSequence;
    if (this.readingReplyPreflightSequence === expectedSequence) {
      return;
    }
    this.readingReplyPreflightSequence = expectedSequence;
    const expectedThreadId: string = this.route.threadId;
    try {
      const rawResult: string = await this.replyWebController.runJavaScript(
        this.getReplyPreflightExtractionScript(expectedThreadId, expectedSequence)
      );
      if (expectedSequence !== this.replyPreflightSequence) {
        return;
      }
      const payload: ReplyPreflightPayload | null = parseReplyPreflightPayload(rawResult);
      if (payload === null ||
        !isExpectedReplyPreflightPayload(payload, expectedThreadId, expectedSequence)) {
        this.failReplyPreflight('回复表单已打开，但无法确认其结构；请稍后重试。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.failReplyPreflight('4D4Y 登录状态已失效，请重新登录后再回复。');
        return;
      }
      if (payload.hasChallenge) {
        this.failReplyPreflight('4D4Y 要求先在网页中完成安全验证。');
        return;
      }
      if (!payload.formFound || payload.formMethod !== 'post' ||
        payload.messageFieldName !== 'message' || !payload.hasFormhashField ||
        !payload.hasPosttimeField || !payload.hasWysiwygField || !payload.hasReplySubmitAction) {
        this.failReplyPreflight('4D4Y 回复表单结构尚未通过校验，未启用发送。');
        return;
      }
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const settings: FourD4yUserSettings = await FourD4yUserSettingsStore.load(context);
      if (!this.isThreadPageAlive || !this.isReplyComposerVisible || !this.isReplyPreflightLoading ||
        expectedSequence !== this.replyPreflightSequence || expectedThreadId !== this.route.threadId) return;
      this.postTailSettings = settings;
      this.clearReplyPreflightWatchdog();
      this.isReplyPreflightLoading = false;
      if (this.replyWebOperation === ReplyWebOperation.Submit) {
        this.beginReplySubmission(expectedSequence);
        return;
      }
      this.isReplyFormReady = true;
      this.replyPreflightMessage = '回复表单已校验；可以发送。';
    } catch (_error) {
      if (expectedSequence === this.replyPreflightSequence) {
        this.failReplyPreflight('暂时无法读取回复表单，请稍后重试。');
      }
    }
  }

  /**
   * The write path always reloads the form first, so no old formhash or
   * posttime can be replayed from a previous composer session.
   */
  private submitReply(): void {
    const draft: string = this.replyDraft.trim();
    if (!this.canSubmitReply() || this.isReplySubmitting || !this.isReplyFormReady ||
      draft.length === 0) {
      return;
    }
    this.replySubmissionSequence += 1;
    this.replySubmissionErrorMessage = '';
    this.pendingReplyDraft = appendFourD4yPostTail(draft, this.postTailSettings);
    this.isReplyFormReady = false;
    this.replyPreflightMessage = '正在重新获取一次性回复表单…';
    this.prepareReplyForm(ReplyWebOperation.Submit);
  }

  private canSubmitReply(): boolean {
    return this.replyDraft.trim().length > 0 && this.isReplyFormReady &&
      !this.isReplyPreflightLoading && !this.isReplySubmitting;
  }

  private async beginReplySubmission(preflightSequence: number): Promise<void> {
    if (!this.isThreadPageAlive || !this.isReplyComposerVisible ||
      this.replyWebOperation !== ReplyWebOperation.Submit ||
      preflightSequence !== this.replyPreflightSequence) {
      return;
    }
    const submissionSequence: number = this.replySubmissionSequence;
    // Only the actual form.submit() phase is a submission. Keeping the fresh
    // GET preflight separate lets its onPageEnd callback validate the new form.
    this.isReplySubmitting = true;
    this.replyPreflightMessage = '正在提交回复，请勿重复操作…';
    this.startReplySubmissionWatchdog(submissionSequence);
    try {
      await this.replyWebController.runJavaScript(
        this.getReplySubmissionScript(this.pendingReplyDraft,
          this.quickReplyMode === QuickReplyMode.Quote && /^\d+$/.test(this.quickReplyTargetPostId))
      );
    } catch (_error) {
      // Navigation can interrupt runJavaScript after the browser has accepted
      // form.submit(). The terminal page callback/watchdog determines outcome.
    }
  }

  private startReplySubmissionWatchdog(submissionSequence: number): void {
    this.clearReplyPreflightWatchdog();
    this.replyPreflightTimeoutId = setTimeout(() => {
      if (!this.isReplySubmitting || submissionSequence !== this.replySubmissionSequence) {
        return;
      }
      this.failReplySubmission('发表回复超时，无法确认是否成功；请先到主题末页核对后再重试。');
      try {
        this.replyWebController.stop();
      } catch (_error) {
        console.warn('Unable to stop a timed out 4D4Y reply submission.');
      }
    }, this.webLoadTimeoutMillis);
  }

  private async readReplySubmissionResult(_url: string): Promise<void> {
    const expectedSubmissionSequence: number = this.replySubmissionSequence;
    const expectedThreadId: string = this.route.threadId;
    try {
      const rawResult: string = await this.replyWebController.runJavaScript(
        this.getReplySubmissionResultScript(expectedThreadId, expectedSubmissionSequence)
      );
      if (!this.isReplySubmitting || expectedSubmissionSequence !== this.replySubmissionSequence) {
        return;
      }
      const payload: ReplySubmissionPayload | null = parseReplySubmissionPayload(rawResult);
      if (payload === null ||
        !isExpectedReplySubmissionPayload(payload, expectedThreadId, expectedSubmissionSequence)) {
        this.failReplySubmission('发表结果无法确认；请先到主题末页核对后再重试。');
        return;
      }
      if (payload.succeeded) {
        this.clearReplyPreflightWatchdog();
        this.isReplySubmitting = false;
        this.replyWebOperation = ReplyWebOperation.Preflight;
        this.pendingReplyDraft = '';
        this.replyDraft = '';
        this.replyPreflightMessage = '回复已发表。';
        this.closeQuickReply(true);
        this.authorOnlyUserId = '';
        this.isThreadAuthorResolving = false;
        this.pendingPostId = '';
        this.pendingFloor = 0;
        this.pendingLastPostOfPage = true;
        this.lastPage = Math.max(this.lastPage, this.estimateLastPage());
        this.loadPage(this.lastPage);
        return;
      }
      if (payload.loginRequired) {
        this.failReplySubmission('4D4Y 登录状态已失效，回复未发表。');
        return;
      }
      if (payload.errorMessage.length > 0) {
        this.recoverRejectedReply(payload.errorMessage);
        return;
      }
      this.failReplySubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
        '4D4Y 未确认回复成功，内容没有被当作已发表处理。');
    } catch (_error) {
      if (expectedSubmissionSequence === this.replySubmissionSequence && this.isReplySubmitting) {
        this.failReplySubmission('读取发表结果失败；请先到主题末页核对后再重试。');
      }
    }
  }

  private failReplySubmission(message: string): void {
    this.clearReplyPreflightWatchdog();
    this.isReplySubmitting = false;
    this.replyWebOperation = ReplyWebOperation.Preflight;
    this.pendingReplyDraft = '';
    this.isReplyFormReady = false;
    this.replyPreflightMessage = message;
  }

  /** A definite server rejection unlocks editing, never an automatic repost. */
  private recoverRejectedReply(message: string): void {
    this.clearReplyPreflightWatchdog();
    this.isReplySubmitting = false;
    this.pendingReplyDraft = '';
    this.replySubmissionErrorMessage = message;
    this.prepareReplyForm(ReplyWebOperation.Preflight);
  }

  private getReplySubmissionScript(draft: string, preserveQuoteTemplate: boolean): string {
    const safeDraft: string = JSON.stringify(draft);
    const safePreserveQuoteTemplate: string = JSON.stringify(preserveQuoteTemplate);
    return [
      '(() => {',
      buildFourD4yPostFormBoundaryScript('reply', this.route.threadId, '', 'oh_reply_prepare', this.replyPreflightSequence),
      // NG and the live Discuz form both use the URL-level signal. A body-only
      // submit button value is not sufficient on every 4D4Y reply template.
      '  actionUrl.searchParams.set("replysubmit", "yes");',
      '  const keepQuote = ' + safePreserveQuoteTemplate + ';',
      '  const quotePrefix = keepQuote && typeof message.value === "string" ? message.value.trim() : "";',
      '  message.value = quotePrefix.length > 0 ? quotePrefix + "\\n\\n" + ' + safeDraft + ' : ' + safeDraft + ';',
      // Submit a clean native form so the legacy WYSIWYG/onclick handler cannot
      // replace the native draft or swallow navigation. Fresh security fields
      // still come exclusively from this just-loaded same-session form.
      '  const outgoing = document.createElement("form"); outgoing.method = "post"; outgoing.action = actionUrl.toString(); outgoing.style.display = "none";',
      '  const appendField = (name, value) => { const field = document.createElement("input"); field.type = "hidden"; field.name = name; field.value = value; outgoing.appendChild(field); };',
      '  const copiedNames = [];',
      '  Array.from(new FormData(form).entries()).forEach((entry) => { const name = entry[0]; const value = entry[1]; if (typeof value !== "string" || name === "message" || name === "replysubmit" || /^(?:attachnew|attachdel)(?:\\[|$)/i.test(name) || /^Filedata$/i.test(name)) return; appendField(name, value); copiedNames.push(name); });',
      '  appendField("message", message.value); appendField("replysubmit", "yes");',
      '  if (copiedNames.indexOf("wysiwyg") < 0) appendField("wysiwyg", "0");',
      '  if (copiedNames.indexOf("usesig") < 0) appendField("usesig", "1");',
      '  document.body.appendChild(outgoing); window.__hipdaPostSubmitted = true; HTMLFormElement.prototype.submit.call(outgoing); return "submitted";',
      '})()'
    ].join('\n');
  }

  private getReplySubmissionResultScript(threadId: string, submissionSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const url = new URL(location.href);',
      '  const loginRequired = !!document.querySelector("input[name=username], input[name=password]");',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      '  const errorMessage = alert ? (alert.innerText || alert.textContent || "").trim().slice(0, 240) : "";',
      '  const isThreadResult = url.origin === "https://www.4d4y.com" && url.searchParams.getAll("tid").length === 1 && (url.pathname === "/forum/viewthread.php" || url.pathname === "/forum/redirect.php");',
      '  const succeeded = isThreadResult && url.searchParams.get("tid") === ' + safeThreadId + ';',
      '  return JSON.stringify({ threadId: ' + safeThreadId + ', submissionSequence: ' +
        submissionSequence + ', succeeded: succeeded, loginRequired: loginRequired, errorMessage: errorMessage });',
      '})()'
    ].join('\n');
  }

  private startReplyPreflightWatchdog(sequence: number): void {
    this.replyPreflightTimeoutId = setTimeout(() => {
      if (sequence !== this.replyPreflightSequence) {
        return;
      }
      this.failReplyPreflight('打开回复表单超时，请稍后重试。');
      try {
        this.replyWebController.stop();
      } catch (_error) {
        console.warn('Unable to stop a timed out 4D4Y reply preflight.');
      }
    }, this.webLoadTimeoutMillis);
  }

  private clearReplyPreflightWatchdog(): void {
    if (this.replyPreflightTimeoutId >= 0) {
      clearTimeout(this.replyPreflightTimeoutId);
      this.replyPreflightTimeoutId = -1;
    }
  }

  private failReplyPreflight(message: string): void {
    this.clearReplyPreflightWatchdog();
    this.isReplyPreflightLoading = false;
    this.isReplyFormReady = false;
    this.replyWebOperation = ReplyWebOperation.Preflight;
    this.replyPreflightMessage = message;
  }

  private getReplyPreflightExtractionScript(threadId: string, sequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const text = (node) => node ? (node.innerText || node.textContent || "").trim() : "";',
      '  const loginForm = document.querySelector("form[action*=logging], input[name=username], input[name=password]");',
      '  const challenge = !!document.querySelector("iframe[src*=challenge], #challenge-form, .cf-turnstile, [data-sitekey]");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => {',
      '    const action = candidate.getAttribute("action") || "";',
      '    return action.indexOf("post.php") >= 0 && action.indexOf("action=reply") >= 0;',
      '  }) || forms.find((candidate) => candidate.querySelector("textarea[name=message]") !== null);',
      '  const actionPath = (() => {',
      '    if (!form) return "";',
      '    try { const url = new URL(form.action || location.href, location.href); return url.pathname + "?action=" + (url.searchParams.get("action") || ""); } catch (_) { return ""; }',
      '  })();',
      '  const message = form ? form.querySelector("textarea[name=message]") : null;',
      '  const token = form ? form.querySelector("input[name=formhash]") : null;',
      '  const posttime = form ? form.querySelector("input[name=posttime]") : null;',
      '  const wysiwyg = form ? form.querySelector("input[name=wysiwyg]") : null;',
      '  const hasReplySubmitAction = (() => {',
      '    if (!form) return false;',
      '    try { return new URL(form.action || location.href, location.href).searchParams.has("replysubmit"); } catch (_) { return false; }',
      '  })();',
      '  const submit = form ? form.querySelector("input[type=submit], button[type=submit], button[name*=submit]") : null;',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      '  return JSON.stringify({',
      '    threadId: ' + safeThreadId + ',',
      '    loadSequence: ' + sequence + ',',
      '    layout: form ? "reply-form" : "no-reply-form",',
      '    accessState: loginForm ? "loginRequired" : "available",',
      '    hasChallenge: challenge,',
      '    formFound: !!form,',
      '    formMethod: form ? (form.method || "get").toLowerCase() : "",',
      '    actionPath: actionPath,',
      '    messageFieldName: message ? (message.getAttribute("name") || "") : "",',
      '    hasFormhashField: !!token,',
      '    hasPosttimeField: !!posttime,',
      '    hasWysiwygField: !!wysiwyg,',
      '    hasReplySubmitAction: hasReplySubmitAction,',
      '    submitControlName: submit ? (submit.getAttribute("name") || text(submit).slice(0, 40)) : "",',
      '    errorMessage: text(alert).slice(0, 160)',
      '  });',
      '})()'
    ].join('\n');
  }

  /**
   * A native tap begins a fresh GET-only form check. The displayed document is
   * deliberately not reused: a prior formhash or stale option set is never
   * treated as valid for a later vote.
   */
  private beginVoteOperation(poll: ThreadPoll): void {
    const threadId: string = this.route.threadId;
    const selectedOptionIds: string[] = this.selectedPollOptionIds.slice();
    const optionIds: string[] = poll.options.map((option: ThreadPollOption) => option.id);
    if (!this.isLoggedIn || !poll.isVoteFormAvailable || this.isVotePreflightLoading || this.isVoteSubmitting ||
      !/^\d+$/.test(threadId) || selectedOptionIds.length < 1 || selectedOptionIds.length > poll.maxSelections ||
      selectedOptionIds.some((optionId: string) => optionIds.indexOf(optionId) < 0)) {
      this.pollActionMessage = '请先选择符合当前投票规则的选项。';
      return;
    }
    this.votePreflightSequence += 1;
    const formSequence: number = this.votePreflightSequence;
    this.clearVoteOperationWatchdog();
    this.isVotePreflightLoading = true;
    this.isVoteSubmitting = false;
    this.pollActionMessage = '正在重新校验当前投票表单…';
    this.voteFormUrl = FourD4ySession.forumRoot + 'viewthread.php?tid=' + threadId +
      '&page=1&oh_vote_preflight=' + formSequence;
    this.startVoteOperationWatchdog(formSequence);
    if (!this.isVoteWebControllerAttached) {
      return;
    }
    try {
      this.voteWebController.loadUrl(this.voteFormUrl);
    } catch (_error) {
      // The controller may still be attaching. onVoteControllerAttached will
      // start this exact fresh URL when it becomes available.
    }
  }

  private isCurrentVotePreflightRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_vote_preflight=' + this.votePreflightSequence + '(?:&|$)');
    return url.indexOf('/forum/viewthread.php') >= 0 && sequenceToken.test(url);
  }

  private async readVotePreflightFromWeb(): Promise<void> {
    const formSequence: number = this.votePreflightSequence;
    const threadId: string = this.route.threadId;
    try {
      const rawResult: string = await this.voteWebController.runJavaScript(
        this.getVotePreflightExtractionScript(threadId, formSequence)
      );
      if (!this.isVotePreflightLoading || formSequence !== this.votePreflightSequence ||
        threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yVotePreflightPayload | null = parseFourD4yVotePreflightPayload(rawResult);
      if (payload === null || !isExpectedFourD4yVotePreflightPayload(payload, threadId, formSequence)) {
        this.failVoteOperation('投票表单已打开，但无法确认其结构；未提交投票。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failVoteOperation('4D4Y 登录状态已失效，未提交投票。');
        return;
      }
      if (payload.hasChallenge) {
        this.failVoteOperation('4D4Y 要求先在网页中完成安全验证；未提交投票。');
        return;
      }
      if (!isReadyFourD4yVoteForm(payload, this.selectedPollOptionIds)) {
        this.failVoteOperation(payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前投票表单已变化或不再可用；未提交投票。');
        return;
      }
      this.isVotePreflightLoading = false;
      this.beginVoteSubmission(formSequence);
    } catch (_error) {
      if (formSequence === this.votePreflightSequence && this.isVotePreflightLoading) {
        this.failVoteOperation('暂时无法读取投票表单；未提交投票。');
      }
    }
  }

  /**
   * The hidden form owns its CSRF field. ArkTS supplies only the bounded
   * option IDs picked in the native UI and never reads token values.
   */
  private async beginVoteSubmission(formSequence: number): Promise<void> {
    if (formSequence !== this.votePreflightSequence) {
      return;
    }
    const threadId: string = this.route.threadId;
    this.voteSubmissionSequence += 1;
    const submissionSequence: number = this.voteSubmissionSequence;
    this.isVotePreflightLoading = false;
    this.isVoteSubmitting = true;
    this.voteVerificationAttempt = 0;
    this.pollActionMessage = '正在提交投票，请勿重复操作…';
    try {
      const rawResult: string = await this.voteWebController.runJavaScript(
        this.getVoteSubmissionScript(threadId, submissionSequence, this.selectedPollOptionIds)
      );
      if (!this.isVoteSubmitting || submissionSequence !== this.voteSubmissionSequence ||
        threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yVoteSubmissionStartPayload | null = parseFourD4yVoteSubmissionStartPayload(rawResult);
      if (payload !== null && isExpectedFourD4yVoteSubmissionStartPayload(payload, threadId, submissionSequence) &&
        !payload.started) {
        this.failVoteOperation(payload.errorMessage.length > 0 ? payload.errorMessage :
          '投票表单没有接受提交；未确认投票。');
        return;
      }
      // A form navigation may interrupt runJavaScript, while 4D4Y's Ajax path
      // may not navigate at all. Both cases are settled only by the server
      // rerender loaded below.
      this.scheduleVoteVerificationLoad(submissionSequence, 800);
    } catch (_error) {
      if (this.isVoteSubmitting && submissionSequence === this.voteSubmissionSequence &&
        threadId === this.route.threadId) {
        this.scheduleVoteVerificationLoad(submissionSequence, 800);
      }
    }
  }

  private startVoteOperationWatchdog(formSequence: number): void {
    this.clearVoteOperationWatchdog();
    this.voteOperationTimeoutId = setTimeout(() => {
      if (formSequence !== this.votePreflightSequence || (!this.isVotePreflightLoading && !this.isVoteSubmitting)) {
        return;
      }
      this.failVoteOperation('投票请求超时，未能确认结果；请先到网页核对后再重试。');
      try {
        this.voteWebController.stop();
      } catch (_error) {
        console.warn('Unable to stop a timed out 4D4Y vote operation.');
      }
    }, this.webLoadTimeoutMillis);
  }

  private scheduleVoteVerificationLoad(submissionSequence: number, delayMillis: number): void {
    if (!this.isVoteSubmitting || submissionSequence !== this.voteSubmissionSequence) {
      return;
    }
    if (this.voteVerificationPollTimeoutId >= 0) {
      clearTimeout(this.voteVerificationPollTimeoutId);
    }
    this.voteVerificationPollTimeoutId = setTimeout(() => {
      if (!this.isVoteSubmitting || submissionSequence !== this.voteSubmissionSequence) {
        return;
      }
      if (!this.isVoteWebControllerAttached) {
        this.scheduleVoteVerificationLoad(submissionSequence, 400);
        return;
      }
      const verificationUrl: string = FourD4ySession.forumRoot + 'viewthread.php?tid=' + this.route.threadId +
        '&page=1&oh_vote_verify=' + submissionSequence + '&oh_vote_verify_try=' + this.voteVerificationAttempt;
      try {
        this.voteWebController.loadUrl(verificationUrl);
      } catch (_error) {
        this.failVoteOperation('无法读取服务器投票结果；请稍后核对。');
      }
    }, delayMillis);
  }

  private isCurrentVoteVerificationRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_vote_verify=' + this.voteSubmissionSequence + '(?:&|$)');
    return url.indexOf('/forum/viewthread.php') >= 0 && sequenceToken.test(url);
  }

  private async readVoteVerificationFromWeb(): Promise<void> {
    const submissionSequence: number = this.voteSubmissionSequence;
    const threadId: string = this.route.threadId;
    if (!this.isVoteSubmitting || submissionSequence <= 0) {
      return;
    }
    try {
      const rawResult: string = await this.voteWebController.runJavaScript(
        this.getVoteVerificationScript(threadId, submissionSequence)
      );
      if (!this.isVoteSubmitting || submissionSequence !== this.voteSubmissionSequence ||
        threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yVoteVerificationPayload | null = parseFourD4yVoteVerificationPayload(rawResult);
      if (payload === null || !isExpectedFourD4yVoteVerificationPayload(payload, threadId, submissionSequence)) {
        this.failVoteOperation('服务器投票结果的页面结构无法确认；请稍后核对。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failVoteOperation('4D4Y 登录状态已失效，未确认投票结果。');
        return;
      }
      if (payload.hasChallenge) {
        this.failVoteOperation('4D4Y 要求先完成安全验证，未确认投票结果。');
        return;
      }
      if (!isConfirmedFourD4yVoteResult(payload)) {
        this.voteVerificationAttempt += 1;
        if (this.voteVerificationAttempt < 3) {
          this.scheduleVoteVerificationLoad(submissionSequence, 1200);
          return;
        }
        this.failVoteOperation(payload.errorMessage.length > 0 ? payload.errorMessage :
          '服务器仍未显示可确认的投票结果；请先到网页核对后再重试。');
        return;
      }
      this.completeVoteOperation();
    } catch (_error) {
      if (this.isVoteSubmitting && submissionSequence === this.voteSubmissionSequence) {
        this.failVoteOperation('读取服务器投票结果失败；请稍后核对。');
      }
    }
  }

  private completeVoteOperation(): void {
    this.clearVoteOperationWatchdog();
    this.isVotePreflightLoading = false;
    this.isVoteSubmitting = false;
    this.selectedPollOptionIds = [];
    this.pollActionMessage = '服务器已确认投票结果。';
    // Reread the visible page so the native card shows the server-rendered
    // tallies rather than assuming a local selection equals success.
    this.loadPage(1);
  }

  private failVoteOperation(message: string): void {
    this.clearVoteOperationWatchdog();
    this.isVotePreflightLoading = false;
    this.isVoteSubmitting = false;
    this.pollActionMessage = message;
  }

  private clearVoteOperationWatchdog(): void {
    if (this.voteOperationTimeoutId >= 0) {
      clearTimeout(this.voteOperationTimeoutId);
      this.voteOperationTimeoutId = -1;
    }
    if (this.voteVerificationPollTimeoutId >= 0) {
      clearTimeout(this.voteVerificationPollTimeoutId);
      this.voteVerificationPollTimeoutId = -1;
    }
  }

  private getVotePreflightExtractionScript(threadId: string, formSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      this.getVoteBoundaryScript(),
      '  const text = (node) => node ? (node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (accessState, hasChallenge, formFound, formMethod, actionPath, hasFormhashField, hasPollSubmitAction, maxSelections, isMultipleChoice, optionIds, errorMessage) => JSON.stringify({ threadId: threadId, formSequence: ' + formSequence + ', accessState: accessState, hasChallenge: hasChallenge, formFound: formFound, formMethod: formMethod, actionPath: actionPath, hasFormhashField: hasFormhashField, hasPollSubmitAction: hasPollSubmitAction, maxSelections: maxSelections, isMultipleChoice: isMultipleChoice, optionIds: optionIds, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href);',
      '    if (!isVotePage(pageUrl)) return finish("available", false, false, "", "", false, false, 1, false, [], "当前页面不是目标主题。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '    if (loginForm) return finish("loginRequired", false, false, "", "", false, false, 1, false, [], "登录状态已失效。");',
      '    const html = document.documentElement.innerHTML;',
      '    const challenge = html.indexOf("challenge-platform") >= 0 || html.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile, #challenge-form, [data-sitekey]");',
      '    const form = document.querySelector("form#poll");',
      '    const action = (() => { try { return form ? new URL(form.getAttribute("action") || location.href, location.href) : null; } catch (_) { return null; } })();',
      '    const actionPath = isVoteAction(action) ? "/forum/misc.php?action=votepoll&pollsubmit=yes" : "";',
      '    const options = form ? Array.from(form.querySelectorAll("td.selector input[name=\\\"pollanswers[]\\\"], input[name=\\\"pollanswers[]\\\"]")) : [];',
      '    const optionIds = []; const seen = new Set();',
      '    options.forEach((input) => { const value = (input.getAttribute("value") || "").trim(); if (/^\\d{1,20}$/.test(value) && !seen.has(value)) { seen.add(value); optionIds.push(value); } });',
      '    const info = text(form ? form.querySelector("div.pollinfo, p.polltimer") : null);',
      '    const maxMatched = /最多可选\\s*(\\d{1,2})\\s*项/.exec(info);',
      '    const maxSelections = maxMatched ? Math.max(1, Math.min(30, Number(maxMatched[1]))) : 1;',
      '    const isMultipleChoice = maxSelections > 1 || options.some((input) => (input.getAttribute("type") || "").toLowerCase() === "checkbox");',
      '    const submit = form ? form.querySelector("input[type=submit], button[type=submit], input[name*=pollsubmit], button[name*=pollsubmit]") : null;',
      '    const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '    return finish("available", challenge, !!form, form ? (form.method || "get").toLowerCase() : "", actionPath, !!(form && form.querySelector("input[name=formhash]")), isVoteSubmitControl(submit) && actionPath.length > 0, maxSelections, isMultipleChoice, optionIds, text(alert));',
      '  } catch (_) { return finish("available", false, false, "", "", false, false, 1, false, [], "读取投票表单失败。"); }',
      '})()'
    ].join('\n');
  }

  private getVoteSubmissionScript(threadId: string, submissionSequence: number, optionIds: string[]): string {
    const safeThreadId: string = JSON.stringify(threadId);
    const safeOptionIds: string = JSON.stringify(optionIds);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + '; const wanted = new Set(' + safeOptionIds + ');',
      this.getVoteBoundaryScript(),
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, submissionSequence: ' + submissionSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href); if (!isVotePage(pageUrl)) return finish(false, "当前页面不是目标主题。");',
      '    const form = document.querySelector("form#poll"); if (!form || (form.method || "get").toLowerCase() !== "post" || !form.querySelector("input[name=formhash]")) return finish(false, "投票表单已变化。");',
      '    const action = new URL(form.getAttribute("action") || location.href, location.href); if (!isVoteAction(action)) return finish(false, "投票地址已变化。");',
      '    const inputs = Array.from(form.querySelectorAll("td.selector input[name=\\\"pollanswers[]\\\"], input[name=\\\"pollanswers[]\\\"]"));',
      '    const available = new Set(inputs.map((input) => (input.getAttribute("value") || "").trim())); if (wanted.size < 1 || Array.from(wanted).some((value) => !available.has(value))) return finish(false, "投票选项已变化。");',
      '    const submit = form.querySelector("input[type=submit], button[type=submit], input[name*=pollsubmit], button[name*=pollsubmit]"); if (!isVoteSubmitControl(submit)) return finish(false, "投票提交控件已变化。");',
      '    // Discuz enables pollsubmit from option click handlers, not checked assignment.',
      '    inputs.filter((input) => input.checked && !wanted.has((input.getAttribute("value") || "").trim()) && input.type === "checkbox").forEach((input) => input.click());',
      '    inputs.filter((input) => wanted.has((input.getAttribute("value") || "").trim()) && !input.checked).forEach((input) => input.click());',
      '    const selected = inputs.filter((input) => input.checked); if (selected.length !== wanted.size) return finish(false, "投票选项校验失败。");',
      '    if (submit.disabled || !isVoteSubmitControl(submit)) return finish(false, "当前网页仍未允许提交投票。");',
      '    if (typeof form.requestSubmit === "function") { form.requestSubmit(submit); } else { form.submit(); } return finish(true, "");',
      '  } catch (_) { return finish(false, "投票表单未能启动提交。"); }',
      '})()'
    ].join('\n');
  }

  private getVoteVerificationScript(threadId: string, submissionSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      this.getVoteBoundaryScript(),
      '  const text = (node) => node ? (node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (accessState, hasChallenge, pollFound, voteFormAvailable, resultRowCount, errorMessage) => JSON.stringify({ threadId: threadId, submissionSequence: ' + submissionSequence + ', accessState: accessState, hasChallenge: hasChallenge, pollFound: pollFound, voteFormAvailable: voteFormAvailable, resultRowCount: resultRowCount, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href); if (!isVotePage(pageUrl)) return finish("available", false, false, false, 0, "当前页面不是目标主题。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]"); if (loginForm) return finish("loginRequired", false, false, false, 0, "登录状态已失效。");',
      '    const html = document.documentElement.innerHTML; const challenge = html.indexOf("challenge-platform") >= 0 || html.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile, #challenge-form, [data-sitekey]");',
      '    const form = document.querySelector("form#poll"); const action = (() => { try { return form ? new URL(form.getAttribute("action") || location.href, location.href) : null; } catch (_) { return null; } })();',
      '    const hasOptions = !!form && form.querySelectorAll("input[name=\\\"pollanswers[]\\\"]").length > 0;',
      '    const voteFormAvailable = hasOptions && (form.method || "get").toLowerCase() === "post" && !!form.querySelector("input[name=formhash]") && isVoteAction(action);',
      '    if (hasOptions && !voteFormAvailable) return finish("available", challenge, false, false, 0, "投票表单结构已变化，无法确认结果。");',
      '    const pollRoot = form || document.querySelector(".poll, .pollinfo, .pollchart"); const resultRowCount = pollRoot ? pollRoot.querySelectorAll("div.pollchart tr, .pollchart tr, tr").length : 0;',
      '    const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message"); return finish("available", challenge, !!pollRoot, voteFormAvailable, Math.min(30, resultRowCount), text(alert));',
      '  } catch (_) { return finish("available", false, false, false, 0, "读取服务器投票结果失败。"); }',
      '})()'
    ].join('\n');
  }

  /** Same destination contract for preflight, submit and server-result reread. */
  private getVoteBoundaryScript(): string {
    return [
      '  const isVoteOrigin = (url) => !!url && url.origin === "https://www.4d4y.com" && !url.username && !url.password;',
      '  const isVoteThread = (url) => url.searchParams.getAll("tid").length === 1 && url.searchParams.get("tid") === threadId;',
      '  const isVotePage = (url) => isVoteOrigin(url) && url.pathname === "/forum/viewthread.php" && isVoteThread(url);',
      '  const isVoteAction = (url) => isVoteOrigin(url) && url.pathname === "/forum/misc.php" && isVoteThread(url) && url.searchParams.getAll("action").length === 1 && url.searchParams.get("action") === "votepoll" && url.searchParams.getAll("pollsubmit").length === 1;',
      '  const isVoteSubmitControl = (submit) => { if (!submit) return false; const action = submit.getAttribute("formaction"); const method = submit.getAttribute("formmethod"); return (action === null || isVoteAction(new URL(action, location.href))) && (method === null || method.toLowerCase() === "post"); };'
    ].join('\n');
  }

  private async readThreadFromWeb(): Promise<void> {
    const expectedSequence: number = this.webLoadSequence;
    const isAppendingRequest: boolean = this.isAppendingThreadPage;
    if (this.isThreadLoadTerminal(expectedSequence)) {
      return;
    }
    const expectedThreadId: string = this.route.threadId;
    const expectedPage: number = this.requestedPage;
    let shouldFinish: boolean = false;
    let resolvedAuthorToActivate: string = '';
    try {
      const rawResult: string = await this.threadWebController.runJavaScript(
        this.getThreadExtractionScript()
      );
      if (this.isThreadLoadTerminal(expectedSequence)) {
        return;
      }
      const payload: ThreadWebPayload | null = parseThreadWebPayload(rawResult);
      if (payload === null) {
        if (expectedSequence === this.webLoadSequence) {
          this.failThreadLoad(expectedSequence, '4D4Y 页面已加载，但无法识别页面数据；请刷新后重试。');
        }
        return;
      }
      if (expectedSequence !== this.webLoadSequence ||
        !isExpectedThreadWebPayload(payload, expectedThreadId, expectedPage, expectedSequence)) {
        return;
      }
      shouldFinish = true;
      const readerOutcome: FourD4yReaderOutcome = getThreadReaderOutcome(payload);
      if (readerOutcome === FourD4yReaderOutcome.LoginRequired) {
        this.needsWebVerification = false;
        this.loadError = '4D4Y 登录状态已失效，请重新登录后刷新。';
        return;
      }
      if (readerOutcome === FourD4yReaderOutcome.VerificationRequired) {
        this.needsWebVerification = true;
        return;
      }
      if (readerOutcome === FourD4yReaderOutcome.UnsupportedLayout) {
        this.needsWebVerification = false;
        this.loadError = payload.errorMessage.length > 0 ? payload.errorMessage :
          '4D4Y 页面已加载，但页面结构暂未适配；请刷新或稍后再试。';
        return;
      }
      this.needsWebVerification = false;
      this.posts = this.postRowVersions.track(isAppendingRequest ?
        appendFourD4yThreadPosts(this.posts, payload.posts) : payload.posts);
      this.captureThreadAuthor(payload.posts);
      if (!isAppendingRequest || payload.currentPage === 1) {
        this.poll = payload.currentPage === 1 ? payload.poll : undefined;
      }
      if (this.poll !== undefined && !this.poll.isVoteFormAvailable) {
        // The forum itself now supplies the terminal "已投票" footer. Do not
        // leave a second native confirmation line below an already refreshed
        // result card.
        this.pollActionMessage = '';
      }
      this.currentPage = Math.max(payload.currentPage, 1);
      if (!isAppendingRequest) {
        this.firstRenderedPage = this.currentPage;
      }
      this.lastPage = this.authorOnlyUserId.length > 0 ?
        Math.max(this.currentPage, payload.lastPage) :
        Math.max(this.currentPage, payload.lastPage, this.estimateLastPage());
      if (this.authorOnlyUserId.length === 0) {
        const completeReplyCount: number | undefined = countObservedLastPageReplies(
          payload.posts, payload.currentPage, payload.lastPage);
        if (completeReplyCount !== undefined) {
          this.observedReplyCounts.observe(this.route.threadId, completeReplyCount);
        }
      }
      this.selectedPage = this.currentPage;
      if (payload.forumId !== undefined && /^\d{1,20}$/.test(payload.forumId)) {
        // Like NG, resolve the actual board from the trusted page breadcrumb.
        // Do not infer it from links embedded in a user's post or quote.
        this.route.forumId = payload.forumId;
      }
      if (payload.title.length > 0) {
        this.resolvedTitle = payload.title;
      }
      this.recordReadHistory(payload);
      if (payload.viewerUserId.length > 0) {
        this.viewerUserId = payload.viewerUserId;
        this.isLoggedIn = true;
        this.requestBlacklistSnapshotIfNeeded();
      } else {
        this.viewerUserId = '';
      }
      if (!isAppendingRequest && !this.isRefreshing) {
        this.prepareInitialPostListIndex();
      }
      this.loadMoreError = '';
      this.probeFavoriteOperation(expectedSequence);
      this.probeAttentionOperation(expectedSequence);
      if (this.isThreadAuthorResolving && payload.currentPage === 1) {
        this.isThreadAuthorResolving = false;
        resolvedAuthorToActivate = normalizeFourD4yThreadActionId(this.threadAuthorUserId);
        if (resolvedAuthorToActivate.length === 0) {
          this.showLinkToast('当前主题未提供可识别的楼主账号');
        }
      }
    } catch (_error) {
      if (expectedSequence !== this.webLoadSequence || this.isThreadLoadTerminal(expectedSequence)) {
        return;
      }
      shouldFinish = false;
      console.error('Failed to read HiPDA thread from ArkWeb.');
      this.failThreadLoad(expectedSequence, '暂时无法读取帖子，请检查网络后重试。');
    } finally {
      if (shouldFinish && expectedSequence === this.webLoadSequence) {
        this.finishThreadLoad(expectedSequence);
      }
    }
    if (resolvedAuthorToActivate.length > 0 && expectedSequence === this.webLoadSequence) {
      this.authorOnlyUserId = resolvedAuthorToActivate;
      setTimeout(() => {
        if (!this.isThreadPageAlive || expectedSequence !== this.webLoadSequence) {
          return;
        }
        this.loadPage(1);
      }, 0);
    }
  }

  /**
   * Read the exact full-site action advertised by the already loaded thread.
   * The ArkWeb bridge returns synchronous script values; the operation itself
   * is intentionally not probed with an injected async fetch.
   */
  private async probeFavoriteOperation(threadLoadSequence: number): Promise<void> {
    const threadId: string = this.route.threadId;
    if (!this.isThreadPageAlive || !this.isLoggedIn || !/^\d+$/.test(threadId) || this.isFavoriteSubmitting) {
      return;
    }
    const operationSequence: number = this.favoriteOperationSequence + 1;
    this.favoriteOperationSequence = operationSequence;
    this.favoriteOperationUrl = '';
    this.favoriteActionLabel = '';
    this.favoriteActionMessage = '正在确认服务器收藏状态…';
    this.isFavoriteOperationLoading = true;
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    try {
      await bindFourD4yCollectionCache(this.getUIContext().getHostContext() as common.Context,
        this.threadWebController, this.favoriteState.cache, 'favorites', () => this.isThreadPageAlive &&
          threadLoadSequence === this.webLoadSequence && operationSequence === this.favoriteOperationSequence &&
          sessionGeneration === this.accountState.getSessionGeneration());
      if (!this.isThreadPageAlive || threadLoadSequence !== this.webLoadSequence ||
        operationSequence !== this.favoriteOperationSequence || sessionGeneration !== this.accountState.getSessionGeneration()) return;
      this.isFavorite = this.favoriteState.isFavorite(threadId);
      const rawResult: string = await this.threadWebController.runJavaScript(
        this.getFavoriteOperationProbeScript(threadId, operationSequence)
      );
      if (!this.isThreadPageAlive || threadLoadSequence !== this.webLoadSequence || operationSequence !== this.favoriteOperationSequence ||
        sessionGeneration !== this.accountState.getSessionGeneration() || threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yFavoriteOperationPayload | null = parseFourD4yFavoriteOperationPayload(rawResult);
      if (payload === null || !isExpectedFourD4yFavoriteOperationPayload(payload, threadId, operationSequence)) {
        this.favoriteActionMessage = '收藏状态无法确认。';
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.favoriteActionMessage = '4D4Y 登录状态已失效，暂时不能收藏。';
        return;
      }
      if (payload.hasChallenge) {
        this.favoriteActionMessage = '请先完成 4D4Y 安全验证后再收藏。';
        return;
      }
      // A topic's add anchor is not proof of absence: 4D4Y renders it even for
      // existing favorites. Preserve the server-list mirror, as NG does.
      if (isAllowedFourD4yFavoriteOperationUrl(payload.actionUrl, threadId) ||
        payload.errorMessage.length === 0) {
        this.isFavorite = this.isFavorite || this.favoriteState.isFavorite(threadId) ||
          /(?:[?&])action=remove(?:&|$)/.test(payload.actionUrl);
        this.favoriteOperationUrl = buildFourD4yFavoriteOperationUrl(threadId, this.isFavorite);
        this.favoriteActionLabel = this.isFavorite ? '取消收藏' : '收藏';
        this.favoriteActionMessage = '';
        return;
      }
      if (payload.errorMessage.length > 0) {
        this.favoriteActionMessage = payload.errorMessage;
      } else if (payload.hasChallenge) {
        this.favoriteActionMessage = '请先完成 4D4Y 安全验证后再收藏。';
      } else {
        this.favoriteActionMessage = '当前主题未提供可确认的收藏操作。';
      }
    } catch (_error) {
      if (this.isThreadPageAlive && sessionGeneration === this.accountState.getSessionGeneration() &&
        operationSequence === this.favoriteOperationSequence && threadId === this.route.threadId) {
        this.favoriteActionMessage = '收藏状态无法确认。';
      }
    } finally {
      if (this.isThreadPageAlive && sessionGeneration === this.accountState.getSessionGeneration() &&
        operationSequence === this.favoriteOperationSequence && threadId === this.route.threadId) {
        this.isFavoriteOperationLoading = false;
      }
    }
  }

  private getFavoriteActionButtonLabel(): string {
    if (this.isFavoriteSubmitting) {
      return '处理中…';
    }
    if (this.isFavoriteOperationLoading) {
      return '收藏';
    }
    if (this.isFavorite) {
      return '取消收藏';
    }
    return '收藏';
  }

  /** A server mutation runs only after the user presses the native button. */
  private async submitFavoriteOperation(): Promise<void> {
    const threadId: string = this.route.threadId;
    const operationUrl: string = this.favoriteOperationUrl;
    const isRemoving: boolean = /(?:[?&])action=remove(?:&|$)/.test(operationUrl);
    if (!this.isThreadPageAlive || !this.isLoggedIn || this.isFavoriteSubmitting ||
      !isAllowedFourD4yFavoriteOperationUrl(operationUrl, threadId)) {
      return;
    }
    const submissionSequence: number = this.favoriteSubmissionSequence + 1;
    this.favoriteSubmissionSequence = submissionSequence;
    this.favoriteSubmissionWasRemoval = isRemoving;
    this.isFavoriteSubmitting = true;
    this.favoriteActionMessage = '';
    this.startFavoriteSubmissionWatchdog(submissionSequence);
    try {
      const rawResult: string = await this.threadWebController.runJavaScript(
        this.getFavoriteOperationSubmissionScript(threadId, operationUrl, submissionSequence, isRemoving)
      );
      if (submissionSequence !== this.favoriteSubmissionSequence || threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yFavoriteMutationStartPayload | null =
        parseFourD4yFavoriteMutationStartPayload(rawResult);
      if (payload === null || !isExpectedFourD4yFavoriteMutationStartPayload(payload, threadId, submissionSequence)) {
        this.failFavoriteSubmission('收藏操作没有得到页面端确认；请到“收藏”页刷新查看。');
        return;
      }
      if (!payload.started) {
        this.failFavoriteSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前页面未提供可执行的收藏操作。');
        return;
      }
      this.scheduleFavoriteSubmissionResultRead(submissionSequence);
    } catch (_error) {
      if (submissionSequence === this.favoriteSubmissionSequence && threadId === this.route.threadId) {
        this.failFavoriteSubmission('收藏操作没有启动；请检查网络后重试。');
      }
    }
  }

  private startFavoriteSubmissionWatchdog(submissionSequence: number): void {
    this.clearFavoriteSubmissionWatchdog();
    this.favoriteVerificationAttempt = 0;
    this.favoriteSubmissionTimeoutId = setTimeout(() => {
      if (this.isFavoriteSubmitting && submissionSequence === this.favoriteSubmissionSequence) {
        this.failFavoriteSubmission('收藏请求超时，结果未被确认；请到“收藏”页刷新核对。');
      }
    }, this.webLoadTimeoutMillis);
  }

  private scheduleFavoriteSubmissionResultRead(submissionSequence: number): void {
    if (!this.isFavoriteSubmitting || submissionSequence !== this.favoriteSubmissionSequence) {
      return;
    }
    this.favoriteVerificationExpectedState = !this.favoriteSubmissionWasRemoval;
    this.favoriteVerificationPage = 1;
    this.favoriteVerificationAttempt = 0;
    this.scheduleFavoriteVerificationLoad(submissionSequence, 800);
  }

  /**
   * Ajax completion does not cause a main-frame lifecycle event in ArkWeb.
   * Verify the operation through the server-rendered favorites form instead
   * of interpreting the transient #favorite_msg text.
   */
  private scheduleFavoriteVerificationLoad(submissionSequence: number, delayMillis: number): void {
    if (!this.isFavoriteSubmitting || submissionSequence !== this.favoriteSubmissionSequence) {
      return;
    }
    if (this.favoriteSubmissionPollTimeoutId >= 0) {
      clearTimeout(this.favoriteSubmissionPollTimeoutId);
    }
    this.favoriteSubmissionPollTimeoutId = setTimeout(() => {
      if (!this.isFavoriteSubmitting || submissionSequence !== this.favoriteSubmissionSequence) {
        return;
      }
      if (!this.isFavoriteVerificationWebControllerAttached) {
        this.scheduleFavoriteVerificationLoad(submissionSequence, 400);
        return;
      }
      const verificationUrl: string = FourD4ySession.forumRoot + 'my.php?item=favorites&type=thread&mobile=no&page=' +
        this.favoriteVerificationPage + '&oh_favorite_verify=' + submissionSequence +
        '&oh_verify_attempt=' + this.favoriteVerificationAttempt;
      try {
        this.favoriteVerificationWebController.loadUrl(verificationUrl);
      } catch (_error) {
        this.failFavoriteSubmission('无法读取服务器收藏列表；请稍后重试。');
      }
    }, delayMillis);
  }

  private async readFavoriteVerificationFromWeb(): Promise<void> {
    const threadId: string = this.route.threadId;
    const submissionSequence: number = this.favoriteSubmissionSequence;
    const verificationPage: number = this.favoriteVerificationPage;
    const verificationAttempt: number = this.favoriteVerificationAttempt;
    if (!this.isThreadPageAlive || !this.isFavoriteSubmitting || submissionSequence <= 0) {
      return;
    }
    try {
      const rawResult: string = await this.favoriteVerificationWebController.runJavaScript(
        this.getFavoriteVerificationScript(threadId, submissionSequence, verificationPage)
      );
      if (!this.isThreadPageAlive || !this.isFavoriteSubmitting || verificationAttempt !== this.favoriteVerificationAttempt ||
        submissionSequence !== this.favoriteSubmissionSequence ||
        threadId !== this.route.threadId || verificationPage !== this.favoriteVerificationPage) {
        return;
      }
      const payload: FourD4yFavoriteVerificationPayload | null = parseFourD4yFavoriteVerificationPayload(rawResult);
      if (payload === null || !isExpectedFourD4yFavoriteVerificationPayload(payload, threadId,
        submissionSequence, verificationPage)) {
        this.failFavoriteSubmission('服务器收藏列表结构无法确认；请稍后重试。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failFavoriteSubmission('4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (payload.hasChallenge && !payload.formFound) {
        this.failFavoriteSubmission('请先完成 4D4Y 安全验证后再收藏。');
        return;
      }
      if (!payload.formFound) {
        this.failFavoriteSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '服务器收藏列表未提供可确认的表单。');
        return;
      }
      const step: FourD4yCollectionVerificationStep = getFourD4yCollectionVerificationStep(
        verificationPage, payload.lastPage, payload.favoritePresent, this.favoriteVerificationExpectedState);
      if (step === 'nextPage') {
        this.favoriteVerificationPage += 1;
        this.scheduleFavoriteVerificationLoad(submissionSequence, 250);
        return;
      }
      if (step === 'limit') {
        this.failFavoriteSubmission('收藏列表较长，操作结果尚未完整核对；请在收藏列表中确认，勿重复提交。');
        return;
      }
      if (step === 'retry') {
        this.favoriteVerificationAttempt += 1;
        if (this.favoriteVerificationAttempt < 3) {
          this.favoriteVerificationPage = 1;
          this.scheduleFavoriteVerificationLoad(submissionSequence, 1200);
          return;
        }
        this.failFavoriteSubmission(this.favoriteVerificationExpectedState ?
          '服务器收藏列表尚未出现该主题，收藏结果未确认。' :
          '服务器收藏列表仍保留该主题，取消收藏结果未确认。');
        return;
      }
      this.completeFavoriteSubmission(this.favoriteVerificationExpectedState);
    } catch (_error) {
      if (this.isThreadPageAlive && this.isFavoriteSubmitting &&
        submissionSequence === this.favoriteSubmissionSequence && threadId === this.route.threadId &&
        verificationPage === this.favoriteVerificationPage && verificationAttempt === this.favoriteVerificationAttempt) {
        this.failFavoriteSubmission('读取服务器收藏列表失败；请稍后重试。');
      }
    }
  }

  private completeFavoriteSubmission(isFavorite: boolean): void {
    this.clearFavoriteSubmissionWatchdog();
    this.isFavoriteSubmitting = false;
    this.favoriteSubmissionWasRemoval = false;
    this.isFavorite = isFavorite;
    this.favoriteOperationUrl = buildFourD4yFavoriteOperationUrl(this.route.threadId, isFavorite);
    this.favoriteActionLabel = isFavorite ? '取消收藏' : '收藏';
    if (isFavorite) {
      this.favoriteState.markFavorite(this.route.threadId);
    } else {
      this.favoriteState.markNotFavorite(this.route.threadId);
    }
    this.favoriteState.notifyConfirmedThreadMutation(this.route.threadId, isFavorite);
    this.favoriteActionMessage = isFavorite ?
      '服务器已确认收藏；按钮已切换为“取消收藏”。' :
      '服务器已确认取消收藏；按钮已恢复为“收藏”。';
  }

  private failFavoriteSubmission(message: string): void {
    this.clearFavoriteSubmissionWatchdog();
    this.isFavoriteSubmitting = false;
    this.favoriteSubmissionWasRemoval = false;
    this.favoriteActionMessage = message;
  }

  private clearFavoriteSubmissionWatchdog(): void {
    if (this.favoriteSubmissionTimeoutId >= 0) {
      clearTimeout(this.favoriteSubmissionTimeoutId);
      this.favoriteSubmissionTimeoutId = -1;
    }
    if (this.favoriteSubmissionPollTimeoutId >= 0) {
      clearTimeout(this.favoriteSubmissionPollTimeoutId);
      this.favoriteSubmissionPollTimeoutId = -1;
    }
  }

  private getFavoriteOperationProbeScript(threadId: string, operationSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (accessState, hasChallenge, actionUrl, actionLabel, errorMessage) => JSON.stringify({ threadId: threadId, loadSequence: ' + operationSequence + ', accessState: accessState, hasChallenge: hasChallenge, actionUrl: actionUrl || "", actionLabel: actionLabel || "", errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href);',
      '    if (pageUrl.origin !== "https://www.4d4y.com" || pageUrl.pathname !== "/forum/viewthread.php" || pageUrl.searchParams.get("tid") !== threadId) return finish("available", false, "", "", "当前页面不是目标主题。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '    if (loginForm) return finish("loginRequired", false, "", "", "登录状态已失效。");',
      '    const challenge = !!document.querySelector(".cf-turnstile, #challenge-form, #cf-challenge-running") || /^(?:Just a moment|Attention Required)/i.test(document.title);',
      '    if (challenge) return finish("available", true, "", "", "");',
      '    for (const link of Array.from(document.querySelectorAll("a"))) {',
      '      const onclick = link.getAttribute("onclick") || "";',
      '      const matched = /ajaxget\\(\\s*[\\x27\\\"]([^\\x27\\\"]+)[\\x27\\\"]/.exec(onclick);',
      '      for (const rawUrl of [matched ? matched[1] : "", link.getAttribute("href") || ""]) {',
      '        try { const url = new URL(rawUrl.replace(/&amp;/g, "&"), location.href); const action = url.searchParams.get("action");',
      '          if (url.origin === pageUrl.origin && url.pathname === "/forum/my.php" && url.searchParams.get("item") === "favorites" && url.searchParams.get("tid") === threadId && (action === "add" || action === "remove")) return finish("available", false, url.href, text(link), "");',
      '        } catch (_) {}',
      '      }',
      '    }',
      '    const readableTopic = document.querySelectorAll("[id^=postmessage_]").length > 0;',
      '    const selfLink = document.querySelector("#umenu cite a[href*=\\\"space.php\\\"]");',
      '    let signedIn = false;',
      '    try { const selfUrl = new URL(selfLink ? selfLink.getAttribute("href") : "", location.href); signedIn = !!selfLink && selfUrl.origin === pageUrl.origin && selfUrl.pathname === "/forum/space.php" && /^\\d+$/.test(selfUrl.searchParams.get("uid") || ""); } catch (_) {}',
      '    return finish("available", false, "", "", readableTopic && signedIn ? "" : "当前主题未提供可确认的收藏操作。");',
      '  } catch (_) { return finish("available", false, "", "", "读取服务器收藏状态失败。"); }',
      '})()'
    ].join('\n');
  }

  private getFavoriteOperationSubmissionScript(threadId: string, operationUrl: string,
    submissionSequence: number, isRemoving: boolean): string {
    const safeThreadId: string = JSON.stringify(threadId);
    const safeOperationUrl: string = JSON.stringify(operationUrl);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      '  const actionUrl = ' + safeOperationUrl + ';',
      '  const isRemoving = ' + (isRemoving ? 'true' : 'false') + ';',
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + submissionSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href);',
      '    if (pageUrl.origin !== "https://www.4d4y.com" || pageUrl.pathname !== "/forum/viewthread.php" || pageUrl.searchParams.get("tid") !== threadId) return finish(false, "当前页面不是目标主题。");',
      '    if (document.querySelector(".cf-turnstile, #challenge-form, #cf-challenge-running") || /^(?:Just a moment|Attention Required)/i.test(document.title)) return finish(false, "请先完成 4D4Y 安全验证。");',
      '    const target = document.getElementById("favorite_msg") || document.documentElement;',
      '    if (!target) return finish(false, "当前主题页未提供收藏结果区域。");',
      '    let link = Array.from(document.querySelectorAll("a")).find((node) => {',
      '      const onclick = node.getAttribute("onclick") || "ajaxget(\\\"" + (node.getAttribute("href") || "") + "\\\", \\"favorite_msg\\")";',
      '      const matched = /ajaxget\\(\\s*[\\x27\\\"]([^\\x27\\\"]*my\\.php\\?item=favorites[^\\x27\\\"]*)[\\x27\\\"]/.exec(onclick);',
      '      if (!matched) return false;',
      '      try { return new URL(matched[1].replace(/&amp;/g, "&"), location.href).href === actionUrl; } catch (_) { return false; }',
      '    }) || document.createElement("a");',
      '    if (!link) return finish(false, "当前页面的收藏操作已变化，请刷新主题后重试。");',
      '    if (typeof window.ajaxget === "function") {',
      '      const favoriteUrl = new URL(actionUrl);',
      '      const fileName = favoriteUrl.pathname.substring(favoriteUrl.pathname.lastIndexOf("/") + 1);',
      '      if (fileName !== "my.php") return finish(false, "当前主题页的取消收藏地址无法确认。");',
      '      window.ajaxget(fileName + "?" + favoriteUrl.searchParams.toString(), "favorite_msg");',
      '      return finish(true, "");',
      '    }',
      '    link.setAttribute("href", actionUrl);',
      '    link.click();',
      '    return finish(true, "");',
      '  } catch (_) { return finish(false, "收藏操作未能在当前主题页启动。"); }',
      '})()'
    ].join('\n');
  }

  private getFavoriteVerificationScript(threadId: string, submissionSequence: number, page: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      buildFourD4yCollectionPaginationScript('favorites', page),
      buildFourD4yCollectionVerificationBoundaryScript('favorites'),
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (accessState, hasChallenge, formFound, favoritePresent, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + submissionSequence + ', page: ' + page + ', lastPage: lastPage, accessState: accessState, hasChallenge: hasChallenge, formFound: formFound, favoritePresent: favoritePresent, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const pageUrl = new URL(location.href);',
      '    if (!isCollectionPage(pageUrl, ' + page + ')) return finish("available", false, false, false, "当前页面不是预期的服务器收藏列表页。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '    if (loginForm) return finish("loginRequired", false, false, false, "登录状态已失效。");',
      '    const html = document.documentElement.innerHTML;',
      '    const challenge = html.indexOf("challenge-platform") >= 0 || html.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '    const forms = Array.from(document.forms || []);',
      '    const form = forms.find((candidate) => { try { return isCollectionUrl(new URL(candidate.getAttribute("action") || location.href, location.href)); } catch (_) { return false; } });',
      '    const checkbox = form ? form.querySelector("input[name=\\\"delete[]\\\"][value=\\\"" + threadId + "\\\"]") : null;',
      '    return finish("available", challenge, !!form, !!checkbox, text(document.querySelector(".alert_info, .alert_error, #messagetext, .message")));',
      '  } catch (_) { return finish("available", false, false, false, "读取服务器收藏列表失败。"); }',
      '})()'
    ].join('\n');
  }

  private isCurrentFavoriteVerificationRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_favorite_verify=' + this.favoriteSubmissionSequence + '(?:&|$)');
    const pageToken: RegExp = new RegExp('[?&]page=' + this.favoriteVerificationPage + '(?:&|$)');
    const attemptToken: RegExp = new RegExp('[?&]oh_verify_attempt=' + this.favoriteVerificationAttempt + '(?:&|$)');
    return url.indexOf('/forum/my.php') >= 0 && url.indexOf('item=favorites') >= 0 &&
      sequenceToken.test(url) && pageToken.test(url) && attemptToken.test(url);
  }

  private async probeAttentionOperation(threadLoadSequence: number): Promise<void> {
    const threadId: string = this.route.threadId;
    if (!this.isThreadPageAlive || !this.isLoggedIn || !/^\d+$/.test(threadId) || this.isAttentionSubmitting) {
      return;
    }
    const operationSequence: number = this.attentionOperationSequence + 1;
    this.attentionOperationSequence = operationSequence;
    this.attentionOperationUrl = '';
    this.attentionActionMessage = '';
    this.isAttentionOperationLoading = true;
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    try {
      await bindFourD4yCollectionCache(this.getUIContext().getHostContext() as common.Context,
        this.threadWebController, this.attentionState.cache, 'attention', () => this.isThreadPageAlive &&
          threadLoadSequence === this.webLoadSequence && operationSequence === this.attentionOperationSequence &&
          sessionGeneration === this.accountState.getSessionGeneration());
      if (!this.isThreadPageAlive || threadLoadSequence !== this.webLoadSequence ||
        operationSequence !== this.attentionOperationSequence || sessionGeneration !== this.accountState.getSessionGeneration()) return;
      this.isAttentioned = this.attentionState.isAttentioned(threadId);
      // Unlike favorites, the current topic template does not expose a stable
      // attention anchor. NG and MY 4D4Y both use this server contract directly.
      // It is reached only after the visible page itself was identity-checked.
      if (threadLoadSequence === this.webLoadSequence && operationSequence === this.attentionOperationSequence &&
        threadId === this.route.threadId) {
        this.attentionOperationUrl = buildFourD4yAttentionOperationUrl(threadId, false);
      }
    } catch (_error) {
      if (operationSequence === this.attentionOperationSequence && threadId === this.route.threadId) {
        this.attentionActionMessage = '关注状态无法确认。';
      }
    } finally {
      if (operationSequence === this.attentionOperationSequence && threadId === this.route.threadId) {
        this.isAttentionOperationLoading = false;
      }
    }
  }

  private getAttentionActionButtonLabel(): string {
    if (this.isAttentionSubmitting) {
      return '处理中…';
    }
    if (this.isAttentioned) {
      return '取消关注';
    }
    return '关注';
  }

  /** A server mutation runs only after the user presses the native button. */
  private async submitAttentionOperation(): Promise<void> {
    const threadId: string = this.route.threadId;
    const operationUrl: string = this.attentionOperationUrl;
    const isRemoving: boolean = this.isAttentioned;
    if (!this.isLoggedIn || this.isAttentionSubmitting || this.isFavoriteSubmitting ||
      !isAllowedFourD4yAttentionOperationUrl(operationUrl, threadId)) {
      return;
    }
    const submissionSequence: number = this.attentionSubmissionSequence + 1;
    this.attentionSubmissionSequence = submissionSequence;
    this.attentionSubmissionWasRemoval = isRemoving;
    this.isAttentionSubmitting = true;
    this.attentionActionMessage = '';
    this.startAttentionSubmissionWatchdog(submissionSequence);
    try {
      const rawResult: string = await this.threadWebController.runJavaScript(
        this.getAttentionOperationSubmissionScript(threadId, operationUrl, submissionSequence, isRemoving)
      );
      if (submissionSequence !== this.attentionSubmissionSequence || threadId !== this.route.threadId) {
        return;
      }
      const payload: FourD4yAttentionMutationStartPayload | null =
        parseFourD4yAttentionMutationStartPayload(rawResult);
      if (payload === null || !isExpectedFourD4yAttentionMutationStartPayload(payload, threadId, submissionSequence)) {
        this.failAttentionSubmission('关注操作没有得到页面端确认；请到“关注”页刷新查看。');
        return;
      }
      if (!payload.started) {
        this.failAttentionSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前页面未提供可执行的关注操作。');
        return;
      }
      this.scheduleAttentionSubmissionResultRead(submissionSequence);
    } catch (_error) {
      if (submissionSequence === this.attentionSubmissionSequence && threadId === this.route.threadId) {
        this.failAttentionSubmission('关注操作没有启动；请检查网络后重试。');
      }
    }
  }

  private startAttentionSubmissionWatchdog(submissionSequence: number): void {
    this.clearAttentionSubmissionWatchdog();
    this.attentionVerificationAttempt = 0;
    this.attentionSubmissionTimeoutId = setTimeout(() => {
      if (this.isAttentionSubmitting && submissionSequence === this.attentionSubmissionSequence) {
        this.failAttentionSubmission('关注请求超时，结果未被确认；请到“关注”页刷新核对。');
      }
    }, this.webLoadTimeoutMillis);
  }

  private scheduleAttentionSubmissionResultRead(submissionSequence: number): void {
    if (!this.isAttentionSubmitting || submissionSequence !== this.attentionSubmissionSequence) {
      return;
    }
    this.attentionVerificationExpectedState = !this.attentionSubmissionWasRemoval;
    this.attentionVerificationPage = 1;
    this.attentionVerificationAttempt = 0;
    this.scheduleAttentionVerificationLoad(submissionSequence, 800);
  }

  /** Verify against the server list rather than transient AJAX feedback text. */
  private scheduleAttentionVerificationLoad(submissionSequence: number, delayMillis: number): void {
    if (!this.isAttentionSubmitting || submissionSequence !== this.attentionSubmissionSequence) {
      return;
    }
    if (this.attentionSubmissionPollTimeoutId >= 0) {
      clearTimeout(this.attentionSubmissionPollTimeoutId);
    }
    this.attentionSubmissionPollTimeoutId = setTimeout(() => {
      if (!this.isAttentionSubmitting || submissionSequence !== this.attentionSubmissionSequence) {
        return;
      }
      if (!this.isAttentionVerificationWebControllerAttached) {
        this.scheduleAttentionVerificationLoad(submissionSequence, 400);
        return;
      }
      const verificationUrl: string = FourD4ySession.forumRoot + 'my.php?item=attention&type=thread&mobile=no&page=' +
        this.attentionVerificationPage + '&oh_attention_verify=' + submissionSequence +
        '&oh_verify_attempt=' + this.attentionVerificationAttempt;
      try {
        this.attentionVerificationWebController.loadUrl(verificationUrl);
      } catch (_error) {
        this.failAttentionSubmission('无法读取服务器关注列表；请稍后重试。');
      }
    }, delayMillis);
  }

  private async readAttentionVerificationFromWeb(): Promise<void> {
    const threadId: string = this.route.threadId;
    const submissionSequence: number = this.attentionSubmissionSequence;
    const verificationPage: number = this.attentionVerificationPage;
    const verificationAttempt: number = this.attentionVerificationAttempt;
    if (!this.isThreadPageAlive || !this.isAttentionSubmitting || submissionSequence <= 0) {
      return;
    }
    try {
      const rawResult: string = await this.attentionVerificationWebController.runJavaScript(
        this.getAttentionVerificationScript(threadId, submissionSequence, verificationPage)
      );
      if (!this.isThreadPageAlive || !this.isAttentionSubmitting || verificationAttempt !== this.attentionVerificationAttempt ||
        submissionSequence !== this.attentionSubmissionSequence ||
        threadId !== this.route.threadId || verificationPage !== this.attentionVerificationPage) {
        return;
      }
      const payload: FourD4yAttentionVerificationPayload | null = parseFourD4yAttentionVerificationPayload(rawResult);
      if (payload === null || !isExpectedFourD4yAttentionVerificationPayload(payload, threadId,
        submissionSequence, verificationPage)) {
        this.failAttentionSubmission('服务器关注列表结构无法确认；请稍后重试。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failAttentionSubmission('4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (payload.hasChallenge && !payload.formFound) {
        this.failAttentionSubmission('请先完成 4D4Y 安全验证后再关注。');
        return;
      }
      if (!payload.formFound) {
        this.failAttentionSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
          '服务器关注列表未提供可确认的表单。');
        return;
      }
      const step: FourD4yCollectionVerificationStep = getFourD4yCollectionVerificationStep(
        verificationPage, payload.lastPage, payload.attentionPresent, this.attentionVerificationExpectedState);
      if (step === 'nextPage') {
        this.attentionVerificationPage += 1;
        this.scheduleAttentionVerificationLoad(submissionSequence, 250);
        return;
      }
      if (step === 'limit') {
        this.failAttentionSubmission('关注列表较长，操作结果尚未完整核对；请在关注列表中确认，勿重复提交。');
        return;
      }
      if (step === 'retry') {
        this.attentionVerificationAttempt += 1;
        if (this.attentionVerificationAttempt < 3) {
          this.attentionVerificationPage = 1;
          this.scheduleAttentionVerificationLoad(submissionSequence, 1200);
          return;
        }
        this.failAttentionSubmission(this.attentionVerificationExpectedState ?
          '服务器关注列表尚未出现该主题，关注结果未确认。' :
          '服务器关注列表仍保留该主题，取消关注结果未确认。');
        return;
      }
      this.completeAttentionSubmission(this.attentionVerificationExpectedState);
    } catch (_error) {
      if (this.isThreadPageAlive && this.isAttentionSubmitting &&
        submissionSequence === this.attentionSubmissionSequence && threadId === this.route.threadId &&
        verificationPage === this.attentionVerificationPage && verificationAttempt === this.attentionVerificationAttempt) {
        this.failAttentionSubmission('读取服务器关注列表失败；请稍后重试。');
      }
    }
  }

  private completeAttentionSubmission(isAttentioned: boolean): void {
    this.clearAttentionSubmissionWatchdog();
    this.isAttentionSubmitting = false;
    this.attentionSubmissionWasRemoval = false;
    this.isAttentioned = isAttentioned;
    if (isAttentioned) {
      this.attentionState.markAttentioned(this.route.threadId);
    } else {
      this.attentionState.markNotAttentioned(this.route.threadId);
    }
    this.attentionState.notifyConfirmedThreadMutation(this.route.threadId, isAttentioned);
    this.attentionActionMessage = isAttentioned ?
      '服务器已确认关注；按钮已切换为“取消关注”。' :
      '服务器已确认取消关注；按钮已恢复为“关注”。';
  }

  private failAttentionSubmission(message: string): void {
    this.clearAttentionSubmissionWatchdog();
    this.isAttentionSubmitting = false;
    this.attentionSubmissionWasRemoval = false;
    this.attentionActionMessage = message;
  }

  private clearAttentionSubmissionWatchdog(): void {
    if (this.attentionSubmissionTimeoutId >= 0) {
      clearTimeout(this.attentionSubmissionTimeoutId);
      this.attentionSubmissionTimeoutId = -1;
    }
    if (this.attentionSubmissionPollTimeoutId >= 0) {
      clearTimeout(this.attentionSubmissionPollTimeoutId);
      this.attentionSubmissionPollTimeoutId = -1;
    }
  }

  private getAttentionOperationProbeScript(threadId: string, operationSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (accessState, hasChallenge, actionUrl, actionLabel, errorMessage) => JSON.stringify({ threadId: threadId, loadSequence: ' + operationSequence + ', accessState: accessState, hasChallenge: hasChallenge, actionUrl: actionUrl || "", actionLabel: actionLabel || "", errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try { const pageUrl = new URL(location.href); if (pageUrl.pathname.indexOf("/forum/viewthread.php") < 0 || pageUrl.searchParams.get("tid") !== threadId) return finish("available", false, "", "", "当前页面不是目标主题。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]"); if (loginForm) return finish("loginRequired", false, "", "", "登录状态已失效。");',
      '    const html = document.documentElement.innerHTML; const challenge = html.indexOf("challenge-platform") >= 0 || html.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '    const link = Array.from(document.querySelectorAll("a[onclick]")).find((node) => (node.getAttribute("onclick") || "").indexOf("my.php?item=attention") >= 0); if (!link) return finish("available", challenge, "", "", text(document.querySelector(".alert_info, .alert_error, #messagetext, .message")));',
      '    const onclick = link.getAttribute("onclick") || ""; const matched = /ajaxget\\(\\s*[\\x27\\\"]([^\\x27\\\"]*my\\.php\\?item=attention[^\\x27\\\"]*)[\\x27\\\"]/.exec(onclick); if (!matched) return finish("available", challenge, "", text(link), "当前页面的关注链接格式无法确认。");',
      '    return finish("available", challenge, new URL(matched[1].replace(/&amp;/g, "&"), location.href).href, text(link), "");',
      '  } catch (_) { return finish("available", false, "", "", "读取服务器关注状态失败。"); } })()'
    ].join('\n');
  }

  private getAttentionOperationSubmissionScript(threadId: string, operationUrl: string,
    submissionSequence: number, isRemoving: boolean): string {
    const safeThreadId: string = JSON.stringify(threadId);
    const safeOperationUrl: string = JSON.stringify(operationUrl);
    return [
      '(() => { const threadId = ' + safeThreadId + '; const actionUrl = ' + safeOperationUrl + '; const isRemoving = ' + (isRemoving ? 'true' : 'false') + ';',
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + submissionSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try { const pageUrl = new URL(location.href); if (pageUrl.pathname.indexOf("/forum/viewthread.php") < 0 || pageUrl.searchParams.get("tid") !== threadId) return finish(false, "当前页面不是目标主题。");',
      '    if (typeof window.ajaxget !== "function") return finish(false, "当前主题页未提供关注所需的服务器操作。"); const requestUrl = new URL(actionUrl); requestUrl.searchParams.set("action", isRemoving ? "remove" : "add"); const fileName = requestUrl.pathname.substring(requestUrl.pathname.lastIndexOf("/") + 1);',
      '    if (fileName !== "my.php" || requestUrl.searchParams.get("item") !== "attention" || requestUrl.searchParams.get("tid") !== threadId) return finish(false, "当前主题页的关注地址无法确认。"); window.ajaxget(fileName + "?" + requestUrl.searchParams.toString(), "favorite_msg"); return finish(true, "");',
      '  } catch (_) { return finish(false, "关注操作未能在当前主题页启动。"); } })()'
    ].join('\n');
  }

  private getAttentionVerificationScript(threadId: string, submissionSequence: number, page: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => { const threadId = ' + safeThreadId + '; const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      buildFourD4yCollectionPaginationScript('attention', page),
      buildFourD4yCollectionVerificationBoundaryScript('attention'),
      '  const finish = (accessState, hasChallenge, formFound, favoritePresent, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + submissionSequence + ', page: ' + page + ', lastPage: lastPage, accessState: accessState, hasChallenge: hasChallenge, formFound: formFound, favoritePresent: favoritePresent, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try { const pageUrl = new URL(location.href); if (!isCollectionPage(pageUrl, ' + page + ')) return finish("available", false, false, false, "当前页面不是预期的服务器关注列表页。");',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]"); if (loginForm) return finish("loginRequired", false, false, false, "登录状态已失效。");',
      '    const html = document.documentElement.innerHTML; const challenge = html.indexOf("challenge-platform") >= 0 || html.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '    const form = Array.from(document.forms || []).find((candidate) => { try { return isCollectionUrl(new URL(candidate.getAttribute("action") || location.href, location.href)); } catch (_) { return false; } });',
      '    const checkbox = form ? form.querySelector("input[name=\\\"delete[]\\\"][value=\\\"" + threadId + "\\\"]") : null; return finish("available", challenge, !!form, !!checkbox, text(document.querySelector(".alert_info, .alert_error, #messagetext, .message")));',
      '  } catch (_) { return finish("available", false, false, false, "读取服务器关注列表失败。"); } })()'
    ].join('\n');
  }

  private isCurrentAttentionVerificationRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_attention_verify=' + this.attentionSubmissionSequence + '(?:&|$)');
    const pageToken: RegExp = new RegExp('[?&]page=' + this.attentionVerificationPage + '(?:&|$)');
    const attemptToken: RegExp = new RegExp('[?&]oh_verify_attempt=' + this.attentionVerificationAttempt + '(?:&|$)');
    return url.indexOf('/forum/my.php') >= 0 && url.indexOf('item=attention') >= 0 &&
      sequenceToken.test(url) && pageToken.test(url) && attemptToken.test(url);
  }

  private isCurrentThreadRequest(url: string): boolean {
    return this.isThreadPageAlive && isCurrentFourD4yWebRequest(url, '/forum/viewthread.php', this.webLoadSequence);
  }

  private isThreadLoadTerminal(sequence: number = this.webLoadSequence): boolean {
    return this.terminalLoadSequence === sequence;
  }

  private startThreadLoadWatchdog(sequence: number): void {
    this.clearThreadLoadWatchdog();
    this.terminalLoadSequence = 0;
    this.webLoadTimeoutId = setTimeout(() => {
      if (sequence !== this.webLoadSequence || this.isThreadLoadTerminal(sequence)) {
        return;
      }
      this.failThreadLoad(sequence, '读取帖子超时，请重试。');
      try {
        this.threadWebController.stop();
      } catch (_error) {
        // The Web controller can already be detached when the timeout fires.
      }
    }, this.webLoadTimeoutMillis);
  }

  private clearThreadLoadWatchdog(): void {
    if (this.webLoadTimeoutId >= 0) {
      clearTimeout(this.webLoadTimeoutId);
      this.webLoadTimeoutId = -1;
    }
  }

  private finishThreadLoad(sequence: number): void {
    if (sequence !== this.webLoadSequence) {
      return;
    }
    const shouldRestoreRefreshPosition: boolean = this.isRefreshing;
    const refreshError: string = this.loadError;
    this.clearThreadLoadWatchdog();
    this.terminalLoadSequence = sequence;
    this.isLoading = false;
    this.isRefreshing = false;
    this.isLoadingMore = false;
    this.isAppendingThreadPage = false;
    if (shouldRestoreRefreshPosition) {
      // A pull refresh keeps the old List mounted. Report a transient read
      // failure without replacing that readable page with a full error view.
      this.loadError = '';
      if (refreshError.length > 0) {
        this.showLinkToast(refreshError);
      }
      this.restoreThreadRefreshPosition();
    }
  }

  private restoreThreadRefreshPosition(): void {
    const offset: number = this.pendingRefreshScrollOffset;
    const sequence: number = this.webLoadSequence;
    this.pendingRefreshScrollOffset = -1;
    if (offset < 0) {
      return;
    }
    // The refreshed List applies its new items in the next ArkUI layout pass.
    // Deferring once lets Scroller clamp the old offset to the new content.
    setTimeout(() => {
      if (!this.isThreadPageAlive || sequence !== this.webLoadSequence) {
        return;
      }
      try {
        this.postListScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
      } catch (_error) {
        console.warn('Unable to restore the thread refresh scroll position.');
      }
    }, 0);
  }

  private failThreadLoad(sequence: number, message: string): void {
    if (sequence !== this.webLoadSequence) {
      return;
    }
    const wasAppending: boolean = this.isAppendingThreadPage;
    const wasRefreshing: boolean = this.isRefreshing;
    this.finishThreadLoad(sequence);
    this.isThreadAuthorResolving = false;
    if (wasAppending && this.posts.length > 0) {
      this.loadMoreError = message;
    } else if (wasRefreshing && this.posts.length > 0) {
      this.showLinkToast(message);
    } else {
      this.loadError = message;
    }
  }

  /** Persist only confirmed reader position, never the ArkWeb document or session. */
  private recordReadHistory(payload: ThreadWebPayload): void {
    const firstPost: ThreadPost | undefined = payload.posts.length > 0 ? payload.posts[0] : undefined;
    const title: string = payload.title.length > 0 ? payload.title : this.route.threadTitle;
    if (firstPost === undefined || firstPost.floor < 1 || title.trim().length === 0) {
      return;
    }
    const entry: FourD4yReadHistoryEntry = {
      threadId: this.route.threadId,
      title: title,
      forumId: this.route.forumId,
      lastReadPage: this.currentPage,
      lastReadFloor: firstPost.floor,
      visitedAt: Date.now()
    };
    this.readHistoryState.record(this.getUIContext().getHostContext() as common.Context, entry).catch(() => {
      // Reading remains usable; a storage failure must not erase older history
      // or create an unhandled promise. A later confirmed page retries normally.
    });
  }

  private subscribeToBlacklistState(): void {
    if (this.blacklistStateListenerId > 0) {
      return;
    }
    this.blacklistStateListenerId = this.blacklistState.subscribe(() => {
      this.syncBlacklistedUsersFromState();
    });
    this.syncBlacklistedUsersFromState();
  }

  private unsubscribeFromBlacklistState(): void {
    if (this.blacklistStateListenerId > 0) {
      this.blacklistState.unsubscribe(this.blacklistStateListenerId);
      this.blacklistStateListenerId = -1;
    }
  }

  private syncBlacklistedUsersFromState(): void {
    this.blacklistedUserNames = this.blacklistState.getUserNames();
  }

  /**
   * NG refreshes a server-backed blacklist cache rather than asking the forum
   * to omit posts. This first-read sync gives a fresh app session that same
   * behaviour without persisting an independent local blacklist.
   */
  private requestBlacklistSnapshotIfNeeded(): void {
    if (!this.isLoggedIn || this.blacklistState.hasSnapshot() || this.isBlacklistSnapshotLoading()) {
      return;
    }
    const expectedSequence: number = this.blacklistSnapshotLoadSequence + 1;
    const requestUrl: string | null = buildFourD4yBlacklistUrl(expectedSequence);
    if (requestUrl === null) {
      return;
    }
    this.blacklistSnapshotLoadSequence = expectedSequence;
    this.blacklistSnapshotTerminalSequence = 0;
    this.blacklistSnapshotUrl = requestUrl;
    this.startBlacklistSnapshotWatchdog(expectedSequence);
    if (!this.isBlacklistSnapshotWebControllerAttached) {
      return;
    }
    try {
      this.blacklistSnapshotWebController.loadUrl(requestUrl);
    } catch (_error) {
      this.finishBlacklistSnapshotLoad(expectedSequence);
    }
  }

  private onBlacklistSnapshotControllerAttached(): void {
    this.isBlacklistSnapshotWebControllerAttached = true;
    try {
      this.blacklistSnapshotWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.blacklistSnapshotUrl.length > 0 && this.isBlacklistSnapshotLoading()) {
        this.blacklistSnapshotWebController.loadUrl(this.blacklistSnapshotUrl);
      }
    } catch (_error) {
      this.finishBlacklistSnapshotLoad(this.blacklistSnapshotLoadSequence);
    }
  }

  private async readBlacklistSnapshotFromWeb(): Promise<void> {
    const expectedSequence: number = this.blacklistSnapshotLoadSequence;
    if (!this.isBlacklistSnapshotLoading()) {
      return;
    }
    try {
      const rawResult: string = await this.blacklistSnapshotWebController.runJavaScript(
        this.getBlacklistSnapshotExtractionScript(expectedSequence)
      );
      if (expectedSequence !== this.blacklistSnapshotLoadSequence ||
        !this.isBlacklistSnapshotLoading(expectedSequence)) {
        return;
      }
      const payload: FourD4yBlacklistPagePayload | null = parseFourD4yBlacklistPagePayload(rawResult);
      if (payload === null || !isExpectedFourD4yBlacklistPagePayload(payload, expectedSequence)) {
        return;
      }
      const outcome: FourD4yBlacklistReaderOutcome = getFourD4yBlacklistReaderOutcome(payload);
      if (outcome === FourD4yBlacklistReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.blacklistState.clearServerSnapshot();
        return;
      }
      if (outcome === FourD4yBlacklistReaderOutcome.Content) {
        this.blacklistState.observeServerUserNames(payload.entries.map((entry) => entry.userName));
      }
    } catch (_error) {
      // A failed read never invents or changes blacklist membership.
    } finally {
      if (expectedSequence === this.blacklistSnapshotLoadSequence) {
        this.finishBlacklistSnapshotLoad(expectedSequence);
      }
    }
  }

  private isCurrentBlacklistSnapshotRequest(url: string): boolean {
    return isCurrentFourD4yBlacklistRequest(url, this.blacklistSnapshotLoadSequence);
  }

  private isBlacklistSnapshotLoading(sequence: number = this.blacklistSnapshotLoadSequence): boolean {
    return sequence === this.blacklistSnapshotLoadSequence &&
      this.blacklistSnapshotTerminalSequence !== sequence;
  }

  private startBlacklistSnapshotWatchdog(sequence: number): void {
    this.clearBlacklistSnapshotWatchdog();
    this.blacklistSnapshotTimeoutId = setTimeout(() => {
      if (this.isBlacklistSnapshotLoading(sequence)) {
        this.finishBlacklistSnapshotLoad(sequence);
        try {
          this.blacklistSnapshotWebController.stop();
        } catch (_error) {
          // The page may have finished while the timeout was firing.
        }
      }
    }, this.blacklistSnapshotTimeoutMillis);
  }

  private clearBlacklistSnapshotWatchdog(): void {
    if (this.blacklistSnapshotTimeoutId >= 0) {
      clearTimeout(this.blacklistSnapshotTimeoutId);
      this.blacklistSnapshotTimeoutId = -1;
    }
  }

  private finishBlacklistSnapshotLoad(sequence: number): void {
    if (sequence !== this.blacklistSnapshotLoadSequence) {
      return;
    }
    this.blacklistSnapshotTerminalSequence = sequence;
    this.clearBlacklistSnapshotWatchdog();
  }

  private getBlacklistSnapshotExtractionScript(loadSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const root = document.querySelector("div.blacklist");',
      '  const mutationInput = document.querySelector("input[name=formhash]");',
      '  const menuHasToken = Array.from(document.querySelectorAll("#umenu a[href]")).some((link) => { try { return !!new URL(link.getAttribute("href") || "", location.href).searchParams.get("formhash"); } catch (_) { return false; } });',
      '  const entries = []; const seen = new Set();',
      '  const rows = root ? Array.from(root.querySelectorAll("ul.commonlist li, li")) : [];',
      '  rows.forEach((row) => {',
      '    const profile = row.querySelector("a[href*=\\\"space.php\\\"]");',
      '    const remove = row.querySelector("a.remove[href]");',
      '    const userName = text(profile);',
      '    if (!remove || !userName || userName.length > 160 || /[\\u0000-\\u001F\\u007F]/.test(userName) || seen.has(userName)) return;',
      '    seen.add(userName); entries.push({ userName: userName });',
      '  });',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({ loadSequence: ' + loadSequence + ', accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge, blacklistLayoutFound: !!root, hasMutationToken: !!mutationInput || menuHasToken, hasRemovalControl: entries.length > 0, errorMessage: text(alert).slice(0, 180), entries: entries });',
      '})()'
    ].join('\n');
  }

  private onThreadControllerAttached(): void {
    this.isThreadWebControllerAttached = true;
    try {
      // Install the exact same identity as LoginPage before this controller
      // sends its first request.  A default mobile request can invalidate the
      // server-side interpretation of a full-site session.
      this.threadWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      this.ensureAttachmentDownloadDelegate();
      if (this.threadPageUrl.indexOf('/forum/viewthread.php') >= 0) {
        this.threadWebController.loadUrl(this.threadPageUrl);
      }
    } catch (_error) {
      this.failThreadLoad(this.webLoadSequence, 'Unable to initialize thread session.');
    }
  }

  private onReplyControllerAttached(): void {
    this.isReplyWebControllerAttached = true;
    try {
      this.replyWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.replyFormUrl.indexOf('/forum/post.php?action=reply') >= 0) {
        this.replyWebController.loadUrl(this.replyFormUrl);
      }
    } catch (_error) {
      if (this.isReplyPreflightLoading) {
        this.failReplyPreflight('Unable to initialize reply session.');
      }
    }
  }

  private onPostDeletionControllerAttached(): void {
    this.isPostDeletionWebControllerAttached = true;
    try {
      this.postDeletionWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.postDeletionPreflightUrl.indexOf('/forum/post.php?action=edit') >= 0 &&
        this.isPostDeletionPreflightLoading) {
        this.postDeletionWebController.loadUrl(this.postDeletionPreflightUrl);
      }
    } catch (_error) {
      if (this.isPostDeletionPreflightLoading) {
        this.failPostDeletionPreflight('暂时无法初始化删除资格校验。');
      }
    }
  }

  /**
   * Return only booleans and route identifiers already known to the app.
   * In particular, no formhash, posttime, content, cookie, or raw HTML can
   * cross this ArkWeb boundary.
   */
  private getPostDeletionPreflightExtractionScript(threadId: string, postId: string, forumId: string,
    page: number, loadSequence: number): string {
    return [
      '(() => {',
      '  const expectedThreadId = ' + JSON.stringify(threadId) + ';',
      '  const expectedPostId = ' + JSON.stringify(postId) + ';',
      '  const asUrl = (value) => { try { return new URL(value || location.href, location.href); } catch (_) { return new URL(location.href); } };',
      '  const text = (node) => node ? (node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = !!document.querySelector("iframe[src*=challenge], #challenge-form, .cf-turnstile, [data-sitekey]");',
      '  const forms = Array.from(document.forms || []);',
      // Match NG's live 4D4Y contract exactly. The server checkbox carries
      // both name="delete" and id="delete"; concatenating those attributes
      // produced "delete delete" and falsely reported that it was absent.
      '  const deleteInput = document.querySelector("input#delete");',
      '  const form = (deleteInput && deleteInput.form) || forms.find((candidate) => {',
      '    const action = asUrl(candidate.getAttribute("action") || location.href);',
      '    return action.pathname.indexOf("post.php") >= 0 && action.searchParams.get("action") === "edit";',
      '  }) || forms.find((candidate) => (candidate.getAttribute("id") || "") === "postform") || null;',
      '  const actionUrl = form ? asUrl(form.getAttribute("action") || location.href) : asUrl(location.href);',
      '  const actionKind = actionUrl.searchParams.get("action") || asUrl(location.href).searchParams.get("action") || "";',
      '  const matchesValue = (name, expected) => {',
      '    if (!form) return false;',
      '    if (actionUrl.origin !== "https://www.4d4y.com" || actionUrl.pathname !== "/forum/post.php") return false;',
      '    const inAction = actionUrl.searchParams.get(name) === expected;',
      '    const inField = Array.from(form.querySelectorAll("input[name]")).some((input) => (input.getAttribute("name") || "") === name && input.value === expected);',
      '    return inAction || inField;',
      '  };',
      '  const hasDeleteControl = !!(deleteInput && form && (deleteInput.form === form || form.contains(deleteInput)));',
      '  const submit = form ? form.querySelector("input[name=editsubmit], button[name=editsubmit], input[type=submit], button[type=submit]") : null;',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({',
      '    threadId: expectedThreadId, postId: expectedPostId, forumId: ' + JSON.stringify(forumId) + ', page: ' + page + ', loadSequence: ' + loadSequence + ',',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, formMethod: form ? (form.method || "get").toLowerCase() : "", actionKind: actionKind,',
      '    hasMatchingPostId: matchesValue("pid", expectedPostId), hasMatchingThreadId: matchesValue("tid", expectedThreadId),',
      '    hasFormhashField: !!(form && form.querySelector("input[name=formhash]")), hasEditSubmitAction: !!submit, hasDeleteControl: hasDeleteControl,',
      '    errorMessage: text(alert).slice(0, 180)',
      '  });',
      '})()'
    ].join('\n');
  }

  private getPostDeletionSubmissionScript(threadId: string, postId: string,
    submissionSequence: number): string {
    return [
      '(() => {',
      '  const threadId = ' + JSON.stringify(threadId) + ';',
      '  const postId = ' + JSON.stringify(postId) + ';',
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, postId: postId, submissionSequence: ' + submissionSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const asUrl = (value) => new URL(value || location.href, location.href);',
      '    const forms = Array.from(document.forms || []);',
      '    const deleteInput = document.querySelector("input#delete");',
      '    const form = (deleteInput && deleteInput.form) || forms.find((candidate) => { const action = asUrl(candidate.getAttribute("action") || location.href); return action.pathname.indexOf("post.php") >= 0 && action.searchParams.get("action") === "edit"; }) || forms.find((candidate) => (candidate.getAttribute("id") || "") === "postform") || null;',
      '    if (!form || (form.method || "get").toLowerCase() !== "post" || !form.querySelector("input[name=formhash]")) return finish(false, "删除表单已变化。");',
      '    const action = asUrl(form.getAttribute("action") || location.href);',
      '    if (action.origin !== "https://www.4d4y.com" || action.pathname !== "/forum/post.php") return finish(false, "删除表单地址不属于 4D4Y。");',
      '    const matchesValue = (name, expected) => action.searchParams.get(name) === expected || Array.from(form.querySelectorAll("input[name]")).some((input) => (input.getAttribute("name") || "") === name && input.value === expected);',
      '    if (action.searchParams.get("action") !== "edit" || !matchesValue("pid", postId) || !matchesValue("tid", threadId)) return finish(false, "删除表单不属于当前帖子。");',
      '    const submit = form.querySelector("input[name=editsubmit], button[name=editsubmit], input[type=submit], button[type=submit]");',
      '    if (!deleteInput || (deleteInput.form !== form && !form.contains(deleteInput)) || !submit || deleteInput.disabled) return finish(false, "服务器未提供可确认的真实删除操作。");',
      '    deleteInput.checked = true;',
      '    if (!deleteInput.checked) return finish(false, "删除选项无法启用。");',
      '    if (typeof form.requestSubmit === "function") { form.requestSubmit(submit); } else { form.submit(); }',
      '    return finish(true, "");',
      '  } catch (_) { return finish(false, "删除表单未能启动提交。"); }',
      '})()'
    ].join('\n');
  }

  private getPostDeletionVerificationScript(threadId: string, postId: string,
    submissionSequence: number): string {
    return [
      '(() => {',
      '  const threadId = ' + JSON.stringify(threadId) + ';',
      '  const postId = ' + JSON.stringify(postId) + ';',
      '  const finish = (accessState, hasChallenge, isTargetThreadPage, isForumPage, postStillPresent, errorMessage) => JSON.stringify({ threadId: threadId, postId: postId, submissionSequence: ' + submissionSequence + ', accessState: accessState, hasChallenge: hasChallenge, isTargetThreadPage: isTargetThreadPage, isForumPage: isForumPage, postStillPresent: postStillPresent, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  try {',
      '    const url = new URL(location.href);',
      '    const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '    const challenge = !!document.querySelector(".cf-turnstile, #challenge-form, #cf-challenge-running, [data-sitekey]") || /^(?:Just a moment|Attention Required)/i.test(document.title);',
      '    const isTargetThreadPage = url.origin === "https://www.4d4y.com" && url.pathname === "/forum/viewthread.php" && url.searchParams.get("tid") === threadId && !!document.querySelector("[id^=postmessage_]");',
      '    const isForumPage = url.origin === "https://www.4d4y.com" && url.pathname === "/forum/forumdisplay.php" && url.searchParams.get("fid") === ' + JSON.stringify(this.route.forumId) + ';',
      '    const postStillPresent = !!document.getElementById("post_" + postId) || !!document.getElementById("pid" + postId) || !!document.getElementById("postmessage_" + postId);',
      '    const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '    const errorMessage = alert ? (alert.innerText || alert.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '    return finish(loginForm ? "loginRequired" : "available", challenge, isTargetThreadPage, isForumPage, postStillPresent, errorMessage);',
      '  } catch (_) { return finish("available", false, false, false, true, "读取删除结果失败。"); }',
      '})()'
    ].join('\n');
  }

  private onVoteControllerAttached(): void {
    this.isVoteWebControllerAttached = true;
    try {
      this.voteWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.voteFormUrl.indexOf('/forum/viewthread.php') >= 0) {
        this.voteWebController.loadUrl(this.voteFormUrl);
      }
    } catch (_error) {
      if (this.isVotePreflightLoading || this.isVoteSubmitting) {
        this.failVoteOperation('无法初始化 4D4Y 投票会话。');
      }
    }
  }

  private onFavoriteVerificationControllerAttached(): void {
    this.isFavoriteVerificationWebControllerAttached = true;
    try {
      this.favoriteVerificationWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
    } catch (_error) {
      if (this.isFavoriteSubmitting) {
        this.failFavoriteSubmission('无法初始化服务器收藏列表会话。');
      }
    }
  }

  private onAttentionVerificationControllerAttached(): void {
    this.isAttentionVerificationWebControllerAttached = true;
    try {
      this.attentionVerificationWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
    } catch (_error) {
      if (this.isAttentionSubmitting) {
        this.failAttentionSubmission('无法初始化服务器关注列表会话。');
      }
    }
  }

  private getThreadExtractionScript(): string {
    return [
      '(() => {',
      '  const toText = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const normalizeUrl = (value) => {',
      '    const raw = (value || "").trim();',
      '    if (!raw || raw.indexOf("javascript:") === 0 || raw.indexOf("data:") === 0 || raw.indexOf("#") === 0) return "";',
      '    try { return new URL(raw, location.href).href; } catch (_) { return ""; }',
      '  };',
      '  const isVideoUrl = (url) => /bilibili\\.com|b23\\.tv|youku\\.com|v\\.qq\\.com|ixigua\\.com|douyin\\.com|kuaishou\\.com|acfun\\.cn/i.test(url);',
      '  const isDecoration = (url) => /\\/images\\/(common|default|attachicons)\\//i.test(url) || url.indexOf("data:image/") === 0;',
      '  const isEmoji = (url) => url.indexOf("/forum/images/smilies/") >= 0;',
      '  const isQuoteSourceLink = (url) => /(?:^|\\/)(?:viewthread|redirect)\\.php(?:[?#]|$)/i.test(url);',
      '  const isForumImageAttachmentUrl = (url) => /\\/forum\\/(?:attachment\\.php|forum\\.php)(?:[?#]|$)/i.test(url) && /(?:[?&]aid=|[?&]mod=attachment(?:&|$))/i.test(url);',
      '  const isDirectImageUrl = (url) => /\\.(?:avif|bmp|gif|jpe?g|png|webp)(?:[?#]|$)/i.test(url);',
      '  // Discuz / 4D4Y keeps two distinct image addresses: `zoomfile` (or the',
      '  // zoom handler) is the original, while `file` / `src` is the in-post',
      '  // preview.  This is the same two-address contract NG retains. Read',
      '  // attributes only; never execute page-provided JavaScript.',
      '  const getZoomHandlerUrl = (value) => {',
      '    const source = (value || "").trim();',
      '    if (!/\\bzoom\\s*\\(/i.test(source)) return "";',
      '    const attachmentMatch = /(?:attachment\\.php|forum\\.php\\?mod=attachment)[^\\\'"\\s,)<>]*/i.exec(source);',
      '    if (attachmentMatch && attachmentMatch[0]) return normalizeUrl(attachmentMatch[0]);',
      '    // Old Discuz templates can pass an absolute or protocol-relative',
      '    // image-CDN URL as the second zoom() argument. It is an explicit',
      '    // original-image address, unlike a filename-derived guess.',
      '    const directImageMatch = /((?:https?:)?\\/\\/[^\\\'"\\s,)<>]+?\\.(?:avif|bmp|gif|jpe?g|png|webp)(?:[?#][^\\\'"\\s,)<>]*)?)/i.exec(source);',
      '    return directImageMatch && directImageMatch[1] ? normalizeUrl(directImageMatch[1]) : "";',
      '  };',
      '  const getImageUrls = (node, enclosingLink) => {',
      '    const zoomFileUrl = normalizeUrl(node.getAttribute("zoomfile") || "");',
      '    const onclick = (node.getAttribute("onclick") || "").trim();',
      '    let zoomUrl = "";',
      '    if (/^zoom/i.test(onclick)) {',
      '      const attachmentMatch = /(?:attachment\\.php|forum\\.php\\?mod=attachment)[^\\\'\"\\s,)<>]*/i.exec(onclick);',
      '      if (attachmentMatch && attachmentMatch[0]) {',
      '        zoomUrl = normalizeUrl(attachmentMatch[0]);',
      '      }',
      '    }',
      '    zoomUrl = zoomUrl || getZoomHandlerUrl(onclick);',
      '    const fileUrl = normalizeUrl(node.getAttribute("file") || "");',
      '    const srcUrl = normalizeUrl(node.getAttribute("src") || "");',
      '    const link = enclosingLink || (node.closest ? node.closest("a") : null);',
      '    const wrappedHref = link ? (link.getAttribute("href") || "") : "";',
      '    const wrappedUrl = normalizeUrl(wrappedHref);',
      '    const linkZoomFileUrl = normalizeUrl(link ? (link.getAttribute("zoomfile") || "") : "");',
      '    const linkOnclick = link ? (link.getAttribute("onclick") || "") : "";',
      '    const linkZoomUrl = getZoomHandlerUrl(linkOnclick) || getZoomHandlerUrl(wrappedHref);',
      '    const anchorImageUrl = isForumImageAttachmentUrl(wrappedUrl) || isDirectImageUrl(wrappedUrl) ? wrappedUrl : "";',
      '    const previewUrl = fileUrl || srcUrl;',
      '    const fullUrl = zoomFileUrl || zoomUrl || linkZoomFileUrl || linkZoomUrl || anchorImageUrl || fileUrl || srcUrl;',
      '    return { url: fullUrl, previewUrl: previewUrl };',
      '  };',
      '  const getQuoteTarget = (node) => {',
      '    const link = Array.from(node.querySelectorAll("a[href]")).find((candidate) => isQuoteSourceLink(candidate.getAttribute("href") || ""));',
      '    if (!link) return { threadId: "", postId: "", floor: 0, author: "" };',
      '    let url = null; try { url = new URL((link.getAttribute("href") || "").replace(/&amp;/g, "&"), location.href); } catch (_) {}',
      '    const label = toText(node);',
      '    const replyMatch = /^\\s*\u56de\u590d\\s*(\\d+)\\s*#\\s*(.*)$/i.exec(label);',
      '    return {',
      '      threadId: url ? (url.searchParams.get("ptid") || url.searchParams.get("tid") || "") : "",',
      '      postId: url ? (url.searchParams.get("pid") || "") : "",',
      '      floor: replyMatch ? (Number.parseInt(replyMatch[1], 10) || 0) : 0,',
      '      author: replyMatch ? (replyMatch[2] || "").trim() : ""',
      '    };',
      '  };',
      '  const getQuoteData = (node) => {',
      '    const target = getQuoteTarget(node);',
      '    const copy = node.cloneNode(true);',
      '    const attribution = copy.querySelector("font[size=\\\"2\\\"], .quoteauthor, .quote_author");',
      '    const attributionText = toText(attribution);',
      '    const attributionMatch = /^(.*?)\\s*\u53d1\u8868\\s*\u4e8e\\s*(.*)$/.exec(attributionText);',
      '    if (attribution) attribution.remove();',
      '    Array.from(copy.querySelectorAll("[style*=\\\"display\\\"][style*=\\\"none\\\"]")).forEach((hidden) => hidden.remove());',
      '    Array.from(copy.querySelectorAll("a[href]")).forEach((link) => {',
      '      const href = link.getAttribute("href") || "";',
      '      if (isQuoteSourceLink(href)) link.remove();',
      '    });',
      '    let value = toText(copy);',
      '    value = value.replace(/^\\s*\u56de\u590d\\s+/, "").trim();',
      '    return {',
      '      value: value,',
      '      author: attributionMatch ? attributionMatch[1].trim() : target.author,',
      '      time: attributionMatch ? attributionMatch[2].trim() : "",',
      '      threadId: target.threadId, postId: target.postId, floor: target.floor',
      '    };',
      '  };',
      '  const isInlineImageAttachment = (node) => {',
      '    if (node.classList && node.classList.contains("attachimg")) return true;',
      '    const menuId = node.id || "";',
      '    if (menuId.indexOf("aimg_") !== 0 || !menuId.endsWith("_menu")) return false;',
      '    const image = document.getElementById(menuId.substring(0, menuId.length - "_menu".length));',
      '    return !!image && image.tagName && image.tagName.toLowerCase() === "img";',
      '  };',
      '  const getAttachmentLabel = (container, link, url) => {',
      '    const name = link.getAttribute("title") || toText(link) || url;',
      '    const sizeMatch = /\\(\\s*\\d+(?:\\.\\d+)?\\s*(?:bytes?|[kmgt]?i?b)\\s*\\)/i.exec(toText(container));',
      '    return sizeMatch && name.indexOf(sizeMatch[0]) < 0 ? name + " " + sizeMatch[0] : name;',
      '  };',
      '  const extractContent = (body, postContainer) => {',
      '    const values = [];',
      '    const push = (kind, value, url, previewUrl, quoteData, smallText) => {',
      '      // NG appends adjacent text fragments; a DOM-node boundary is not',
      '      // a line break. Trim only after the complete text run is read, so',
      '      // real <br> and spaces around inline formatting survive.',
      '      const text = kind === "text" ? (value || "") : (value || "").trim();',
      '      if (kind === "text" && !text) return;',
      '      if (url && values.some((item) => item.kind === kind && item.url === url && (item.isSmallText === true) === (smallText === true))) return;',
      '      const last = values.length > 0 ? values[values.length - 1] : null;',
      '      if (kind === "text" && last && last.kind === "text" && (last.isSmallText === true) === (smallText === true)) { last.value += text; return; }',
      '      const item = { kind: kind, value: text || url || "", url: url };',
      '      if (!url) delete item.url;',
      '      if (smallText === true && (kind === "text" || kind === "link")) item.isSmallText = true;',
      '      if (previewUrl && previewUrl !== url) item.previewUrl = previewUrl;',
      '      if (quoteData) {',
      '        if (quoteData.author) item.quoteAuthor = quoteData.author;',
      '        if (/^\\d{1,20}$/.test(quoteData.threadId || "")) item.quoteThreadId = quoteData.threadId;',
      '        if (/^\\d{1,20}$/.test(quoteData.postId || "")) item.quotePostId = quoteData.postId;',
      '        if (Number.isFinite(quoteData.floor) && quoteData.floor > 0) item.quoteFloor = quoteData.floor;',
      '        if (quoteData.time) item.quoteTime = quoteData.time;',
      '      }',
      '      values.push(item);',
      '    };',
      '    const blockBreak = () => {',
      '      const last = values.length > 0 ? values[values.length - 1] : null;',
      '      if (last && last.kind === "text" && !/\\n[ \\t\\r\\f]*$/.test(last.value)) push("text", "\\n");',
      '    };',
      '    const walk = (node, preserveWhitespace, smallText) => {',
      '      if (node.nodeType === 3) { const raw = node.nodeValue || ""; push("text", preserveWhitespace ? raw : raw.replace(/[ \\t\\r\\n\\f]+/g, " "), "", "", null, smallText); return; }',
      '      if (node.nodeType !== 1) return;',
      '      const tag = node.tagName.toLowerCase();',
      '      smallText = smallText === true || tag === "small" || (tag === "font" && (node.getAttribute("size") || "").trim() === "1");',
      '      if (tag === "script" || tag === "style") return;',
      '      if (tag === "br") { push("text", "\\n", "", "", null, smallText); return; }',
      '      if (tag === "i" && node.classList && node.classList.contains("pstatus")) return;',
      '      // The poll is rendered as a separate native card. Do not let its',
      '      // form controls and option labels leak into the post body.',
      '      if (tag === "form" && (node.id || "") === "poll") return;',
      '      if (node.classList && (node.classList.contains("t_attach") || node.classList.contains("t_attachlist"))) {',
      '        // The mobile page puts the filename/menu for an inline image in',
      '        // the same attachment container.  It is rendered separately below',
      '        // from its image node, so do not expose this duplicate download link.',
      '        if (isInlineImageAttachment(node) || node.querySelector(".attachimg")) return;',
      '        const attachmentLink = node.querySelector("a[href*=\\\"attachment.php\\\"]");',
      '        if (attachmentLink) {',
      '          const attachmentUrl = normalizeUrl(attachmentLink.getAttribute("href") || "");',
      '          const attachmentName = getAttachmentLabel(node, attachmentLink, attachmentUrl);',
      '          if (attachmentUrl) push("attachment", attachmentName, attachmentUrl);',
      '        }',
      '        return;',
      '      }',
      '      if (node.classList && node.classList.contains("quote")) {',
      '        const quoteData = getQuoteData(node);',
      '        if (quoteData.value || quoteData.postId) push("quote", quoteData.value, "", "", quoteData);',
      '        return;',
      '      }',
      '      if (tag === "strong") {',
      '        const quoteTarget = getQuoteTarget(node);',
      '        if (quoteTarget.postId && quoteTarget.floor > 0 && /^\\s*\u56de\u590d\\s*\\d+\\s*#/.test(toText(node))) {',
      '          push("quote", "", "", "", quoteTarget);',
      '          return;',
      '        }',
      '      }',
      '      if (tag === "img") {',
      '        const imageUrls = getImageUrls(node);',
      '        if (imageUrls.url && !isDecoration(imageUrls.url)) push(isEmoji(imageUrls.url) ? "emoji" : "image", isEmoji(imageUrls.url) ? "表情" : "图片", imageUrls.url, imageUrls.previewUrl);',
      '        return;',
      '      }',
      '      if (tag === "a") {',
      '        const linkedImages = Array.from(node.querySelectorAll("img"));',
      '        linkedImages.forEach((image) => {',
      '          const imageUrls = getImageUrls(image, node);',
      '          if (imageUrls.url && !isDecoration(imageUrls.url)) push(isEmoji(imageUrls.url) ? "emoji" : "image", isEmoji(imageUrls.url) ? "表情" : "图片", imageUrls.url, imageUrls.previewUrl);',
      '        });',
      '        if (linkedImages.length > 0 && !toText(node)) return;',
      '        const url = normalizeUrl(node.getAttribute("href") || "");',
      '        if (url) {',
      '          const isAttachment = url.indexOf("attachment.php?") >= 0;',
      '          const kind = isAttachment ? "attachment" : (isVideoUrl(url) ? "video" : "link");',
      '          const label = isAttachment ? (node.getAttribute("title") || toText(node) || url) : (toText(node) || url);',
      '          const smallFont = node.querySelector("font[size=\\"1\\"], small");',
      '          const isSmallLink = smallText || (smallFont && toText(smallFont) === toText(node));',
      '          push(kind, label, url, "", null, isSmallLink === true || !!isSmallLink);',
      '        }',
      '        return;',
      '      }',
      '      if (tag === "iframe" || tag === "video" || tag === "embed") {',
      '        const url = normalizeUrl(node.getAttribute("src") || "");',
      '        if (url) push(isVideoUrl(url) ? "video" : "link", isVideoUrl(url) ? "视频引用" : url, url);',
      '        return;',
      '      }',
      '      const isBlock = node !== body && /^(?:p|div|li|blockquote|pre|tr|h[1-6])$/.test(tag);',
      '      if (isBlock) blockBreak();',
      '      Array.from(node.childNodes).forEach((child) => walk(child, preserveWhitespace || tag === "pre", smallText));',
      '      if (isBlock) blockBreak();',
      '    };',
      '    if (body) walk(body);',
      '    // 4D4Y may associate uploaded pictures with a post without placing an',
      '    // [attachimg] marker in its text.  NG explicitly reads these post-level',
      '    // attachimg nodes after parsing the message.  Do the same while keeping',
      '    // ordinary files on the filename-only attachment path above.',
      '    if (postContainer) {',
      '      const attachedImages = Array.from(postContainer.querySelectorAll("dl.attachimg img, .postattachlist .attachimg img, .t_attachlist.attachimg img, .t_attach.attachimg img, img[id^=\\"aimg_\\"]"));',
      '      attachedImages.forEach((image) => {',
      '        const enclosingLink = image.closest ? image.closest("a") : null;',
      '        const imageUrls = getImageUrls(image, enclosingLink);',
      '        if (imageUrls.url && !isDecoration(imageUrls.url) && !isEmoji(imageUrls.url)) push("image", "图片", imageUrls.url, imageUrls.previewUrl);',
      '      });',
      '    }',
      '    values.forEach((item) => { if (item.kind === "text") item.value = item.value.trim(); });',
      '    return values.filter((item) => item.kind !== "text" || item.value.length > 0);',
      '  };',
      '  const params = new URLSearchParams(location.search);',
      '  let forumId = "";',
      '  const forumLinks = Array.from(document.querySelectorAll("#nav a[href]"));',
      '  for (const link of forumLinks) {',
      '    if (link.closest("[id^=post_], [id^=pid], [id^=postmessage_], .quote, .signatures")) continue;',
      '    try {',
      '      const target = new URL((link.getAttribute("href") || "").replace(/&amp;/g, "&"), location.href);',
      '      const fid = target.searchParams.get("fid") || "";',
      '      if (target.origin === "https://www.4d4y.com" && !target.username && !target.password && target.pathname === "/forum/forumdisplay.php" && target.searchParams.getAll("fid").length === 1 && /^\\d{1,20}$/.test(fid)) { forumId = fid; break; }',
      '    } catch (_) {}',
      '  }',
      '  const currentUserLink = document.querySelector("#umenu > cite > a[href], #umenu cite a[href]");',
      '  const currentUserHref = currentUserLink ? (currentUserLink.getAttribute("href") || "") : "";',
      '  const currentUserMatch = /(?:[?&]uid=|uid-)([0-9]+)/.exec(currentUserHref);',
      '  const pageScriptText = Array.from(document.scripts || []).map((script) => script.textContent || "").join("\\n");',
      '  const scriptUserMatch = /(?:^|[;\\s])discuz_uid\\s*=\\s*[\"\\\']?([0-9]+)/i.exec(pageScriptText);',
      '  const getUserId = (node) => {',
      '    if (!node) return "";',
      '    const href = node.getAttribute("href") || "";',
      '    const match = /(?:[?&]uid=|uid-)(\\d{1,20})(?:&|$)/i.exec(href);',
      '    return match ? match[1] : "";',
      '  };',
      '  const idNodes = Array.from(document.querySelectorAll("[id]"));',
      '  const legacyPostNodes = idNodes.filter((node) => /^post_\\d+$/.test(node.id || ""));',
      '  const pidNodes = idNodes.filter((node) => (node.id || "").indexOf("pid") === 0);',
      // Current 4D4Y pages normally expose a post_ or pid root. Some valid
      // legacy-compatible pages expose only the per-floor postmessage_ body.
      // It is already the bounded body marker below, so use it only as the
      // final fallback rather than widening the root selector.
      '  const postMessageNodes = idNodes.filter((node) => /^postmessage_\\d+$/.test(node.id || ""));',
      '  const postNodes = legacyPostNodes.length > 0 ? legacyPostNodes : (pidNodes.length > 0 ? pidNodes : postMessageNodes);',
      '  const layout = legacyPostNodes.length > 0 ? "legacy-post" : (pidNodes.length > 0 ? "mobile-pid" : (postMessageNodes.length > 0 ? "postmessage-fallback" : "unrecognized"));',
      '  const requestedPage = Math.max(1, Number.parseInt(params.get("page") || "1", 10) || 1);',
      '  const pageText = toText(document.body);',
      '  const serverMessageNode = document.querySelector("div.alert_error, div.alert_info, #messagetext, .box.message, .messagebox, .showmessage, p.message, [class*=message][class*=box]");',
      '  const knownServerMessage = pageText.split(/[。！？]/).find((part) => /(指定的主题不存在|主题不存在|已被删除|正在审核|临时回收站|回收站|您无权|无权访问)/.test(part)) || "";',
      '  const errorMessage = (toText(serverMessageNode) || knownServerMessage.trim()).slice(0, 240);',
      '  const loginForm = document.querySelector("#loginform, form[name=login]");',
      '  const accessState = loginForm && /(\\u672a\\u767b\\u5f55|\\u65e0\\u6743)/.test(pageText) ? "loginRequired" : "available";',
      '  const poll = (() => {',
      '    const form = document.querySelector("form#poll");',
      '    if (!form) return undefined;',
      '    const infoNode = form.querySelector("div.pollinfo");',
      '    const timerNode = form.querySelector("p.polltimer");',
      '    const infoText = [toText(infoNode), toText(timerNode)].filter((value) => value.length > 0).join(" ").slice(0, 240);',
      '    const options = [];',
      '    const optionIds = new Set();',
      '    const rows = Array.from(form.querySelectorAll("div.pollchart tr"));',
      '    rows.forEach((row) => {',
      '      const labelNode = row.querySelector("td.polloption label, label");',
      '      if (labelNode) {',
      '        const label = toText(labelNode).slice(0, 320);',
      '        const input = row.querySelector("td.selector input, input[name=\\\"pollanswers[]\\\"]");',
      '        const id = input ? (input.getAttribute("value") || "").trim() : "";',
      '        if (label && !options.some((option) => option.label === label) && (!id || (/^\\d{1,20}$/.test(id) && !optionIds.has(id)))) {',
      '          if (id) optionIds.add(id);',
      '          options.push({ id: id, label: label, resultText: "" });',
      '        }',
      '        return;',
      '      }',
      '      const previous = options.length > 0 ? options[options.length - 1] : undefined;',
      '      const rateText = toText(row.querySelector("td:last-child em, td:last-child .pollpercent, td:last-child")).slice(0, 160);',
      '      if (previous && rateText && /(?:\\d\\s*%|\\d\\s*\\u7968|\\(.*%\\))/.test(rateText) && rateText !== previous.label) previous.resultText = rateText;',
      '    });',
      '    const maximumMatch = /\\u6700\\u591a\\u53ef\\u9009\\s*(\\d{1,2})\\s*\\u9879/.exec(infoText);',
      '    const maxSelections = maximumMatch ? Math.max(1, Number.parseInt(maximumMatch[1], 10) || 1) : 1;',
      '    const optionInputs = Array.from(form.querySelectorAll("td.selector input, input[name=\\\"pollanswers[]\\\"]"));',
      '    const isMultipleChoice = optionInputs.some((input) => (input.getAttribute("type") || "").toLowerCase() === "checkbox") || maxSelections > 1;',
      '    let isVoteFormAvailable = false;',
      '    try {',
      '      const action = new URL(form.getAttribute("action") || location.href, location.href);',
      '      const actionMatches = action.origin === location.origin && /\\/forum\\/misc\\.php$/.test(action.pathname) && action.searchParams.get("action") === "votepoll" && action.searchParams.get("tid") === params.get("tid") && action.searchParams.has("pollsubmit");',
      '      const hasFormhash = !!form.querySelector("input[name=\\\"formhash\\\"]");',
      '      isVoteFormAvailable = (form.method || "get").toLowerCase() === "post" && actionMatches && hasFormhash && options.length >= 2 && optionIds.size === options.length;',
      '    } catch (_) {}',
      '    let footerText = "";',
      '    const lastRow = rows.length > 0 ? rows[rows.length - 1] : undefined;',
      '    if (lastRow && !lastRow.querySelector("label")) {',
      '      const footerCopy = lastRow.cloneNode(true);',
      '      Array.from(footerCopy.querySelectorAll("button, input, script, style")).forEach((node) => node.remove());',
      '      const candidate = toText(footerCopy);',
      '      if (candidate && !/(?:\\d\\s*%|\\d\\s*\\u7968|\\(.*%\\))/.test(candidate)) footerText = candidate.slice(0, 240);',
      '    }',
      '    return options.length >= 2 ? { infoText: infoText, footerText: footerText, maxSelections: maxSelections, isMultipleChoice: isMultipleChoice, isVoteFormAvailable: isVoteFormAvailable, options: options } : undefined;',
      '  })();',
      '  const posts = postNodes.map((post, index) => {',
      '    const postId = (post.id || "").replace(/^(post_|pid|postmessage_)/, "");',
      '    const authorMarker = document.getElementById("authorposton" + postId);',
      '    const replyAuthorNode = post.querySelector(".replytop a[href*=\\"space.php\\"], .replytop a[href*=\\"uid=\\"], .replytop [data-username], .replytop [data-user-name], .replytop [data-author]");',
      '    const replyAuthorImage = replyAuthorNode ? replyAuthorNode.querySelector("img") : null;',
      '    const replyAuthorName = toText(replyAuthorNode) || (replyAuthorNode ? (replyAuthorNode.getAttribute("data-username") || replyAuthorNode.getAttribute("data-user-name") || replyAuthorNode.getAttribute("data-author") || replyAuthorNode.getAttribute("title") || "") : "") || (replyAuthorImage ? (replyAuthorImage.getAttribute("alt") || "") : "");',
      '    // In the full template, #post_<pid> is the per-floor root used by',
      '    // NG for attachment parsing.  Do not climb to .detail here: on 4D4Y',
      '    // that wrapper can contain later floors and would attribute their',
      '    // images to the first post.  The mobile pid nodes still need their',
      '    // surrounding detail container for the existing mobile layout.',
      '    const postContainer = legacyPostNodes.length > 0 ? post : (post.closest(".detail, .post, table") || post.parentElement || post);',
      '    const authorLine = postContainer.querySelector(".sub");',
      '    const authorLineText = toText(authorLine);',
      '    const authorLineMatch = /^(.*?)\\s*\\u53d1\\u8868\\u4e8e/.exec(authorLineText);',
      '    const authorNode = postContainer.querySelector(".sub a[href*=\\"space.php\\"], td.postauthor cite a, .postauthor cite a, a[href*=\\"space.php\\"], a[href*=\\"uid=\\"], [data-username], [data-user-name], [data-author]") || (authorMarker && authorMarker.parentElement ? authorMarker.parentElement.querySelector("a[href*=\\"space.php\\"], a[href*=\\"uid=\\"], a[class*=\\"author\\"], a[class*=\\"user\\"]") : null);',
      '    const authorImage = authorNode ? authorNode.querySelector("img") : null;',
      '    const rawAuthorName = replyAuthorName || (authorLineMatch ? authorLineMatch[1].trim() : "") || toText(authorNode) || (authorNode ? (authorNode.getAttribute("data-username") || authorNode.getAttribute("data-user-name") || authorNode.getAttribute("data-author") || authorNode.getAttribute("title") || "") : "") || (authorImage ? (authorImage.getAttribute("alt") || "") : "");',
      '    const authorName = /^(发表回复|回复|引用)$/.test(rawAuthorName) ? "" : rawAuthorName;',
      '    const authorUserId = getUserId(replyAuthorNode) || getUserId(authorNode);',
      '    const floorSelector = "td.postcontent .postinfo strong a em, td.postauthor .postinfo strong em, .postinfo strong a em, .postinfo strong em, a[id^=postnum] em";',
      '    const localFloorNode = post.querySelector(floorSelector);',
      '    const floorNode = localFloorNode || postContainer.querySelector(floorSelector);',
      '    const bodyNode = layout === "postmessage-fallback" ? post : (post.querySelector(".replycon") || post.querySelector("[id^=\\"postmessage_\\"]") || post.querySelector("td.t_msgfont") || post.querySelector(".locked") || post);',
      '    const statusNode = bodyNode ? bodyNode.querySelector("i.pstatus") : null;',
      '    const floorMatch = /\\d+/.exec(toText(floorNode));',
      '    return {',
      '      id: postId || ("post-" + index),',
      '      threadId: params.get("tid") || "",',
      '      floor: floorMatch ? Number.parseInt(floorMatch[0], 10) : ((requestedPage - 1) * 50) + index + 1,',
      '      hasExplicitFloor: !!localFloorNode && !!floorMatch,',
      '      authorName: authorName,',
      // Missing/deleted/anonymous profile links carry no identity. Preserve
      // the readable floor, but omit the optional UID (and identity actions).
      // An empty string would violate the native reader's numeric-ID contract.
      '      authorUserId: authorUserId || undefined,',
      '      publishedAt: toText(post.querySelector(".replytop time, .replytop em, .authorinfo em") || authorMarker),',
      '      statusText: toText(statusNode).slice(0, 240),',
      '      content: extractContent(bodyNode, postContainer)',
      '    };',
      '  }).filter((post) => post.threadId.length > 0);',
      '  const postsById = new Map(posts.filter((post) => /^\\d{1,20}$/.test(post.id)).map((post) => [post.id, post]));',
      '  const quotePreviewText = (post) => post.content.filter((item) => item.kind === "text" || item.kind === "quote").map((item) => item.value || "").filter((value) => value.length > 0).join(" ").replace(/\\s+/g, " ").trim();',
      '  posts.forEach((post) => post.content.forEach((item) => {',
      '    if (item.kind !== "quote" || !item.quotePostId) return;',
      '    const sourcePost = postsById.get(item.quotePostId);',
      '    if (!sourcePost) return;',
      '    item.quoteAuthor = sourcePost.authorName || item.quoteAuthor || "";',
      '    item.quoteThreadId = sourcePost.threadId || item.quoteThreadId || "";',
      '    item.quoteFloor = sourcePost.floor;',
      '    const preview = quotePreviewText(sourcePost);',
      '    if (preview) item.value = preview;',
      '  }));',
      '  let lastPage = Math.max(1, Number.parseInt(params.get("page") || "1", 10) || 1);',
      '  const readPageNumber = (value) => {',
      '    const raw = (value || "").replace(/&amp;/g, "&");',
      '    try {',
      '      const target = new URL(raw, location.href);',
      '      if (target.origin !== "https://www.4d4y.com" || target.pathname !== "/forum/viewthread.php" || target.searchParams.get("tid") !== params.get("tid")) return 0;',
      '      if ((target.searchParams.get("authorid") || "") !== (params.get("authorid") || "")) return 0;',
      '      const page = target.searchParams.get("page") || "";',
      '      return /^\\d{1,6}$/.test(page) ? Number.parseInt(page, 10) : 0;',
      '    } catch (_) { return 0; }',
      '  };',
      '  Array.from(document.querySelectorAll("a[href]")).forEach((link) => {',
      '    if (link.closest("[id^=postmessage_], [id^=post_], [id^=pid], .quote, .signatures")) return;',
      '    lastPage = Math.max(lastPage, readPageNumber(link.getAttribute("href") || ""));',
      '  });',
      '  const currentMatch = /\\d+/.exec(toText(document.querySelector(".pages strong")));',
      '  return JSON.stringify({',
      '    threadId: params.get("tid") || "",',
      '    forumId: forumId,',
      '    viewerUserId: currentUserMatch ? currentUserMatch[1] : (scriptUserMatch ? scriptUserMatch[1] : ""),',
      '    title: toText(document.querySelector("#threadtitle h1")) || toText(document.querySelector("h1")) || (document.title || "").replace(/\\s+-\\s+.*$/, "").trim(),',
      '    currentPage: currentMatch ? Number.parseInt(currentMatch[0], 10) : requestedPage,',
      '    lastPage: lastPage,',
      '    loadSequence: Number.parseInt(params.get("oh_load") || "0", 10) || 0,',
      '    layout: layout,',
      '    postNodeCount: postNodes.length,',
      '    accessState: accessState,',
      '    hasChallenge: document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0,',
      '    errorMessage: postNodes.length === 0 ? errorMessage : "",',
      '    poll: poll,',
      '    posts: posts',
      '  });',
      '})()'
    ].join('\n');
  }
}
