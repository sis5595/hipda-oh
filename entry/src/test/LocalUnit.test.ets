import { describe, expect, it } from '@ohos/hypium';
import { estimateLastPageFromReplyCount, ForumLinkKind, ForumWebPayload, FourD4yPageAccessState, FourD4yReaderOutcome, getForumReaderOutcome, getThreadReaderOutcome, is4D4yInlineImageAttachment, is4D4yLegacyPostId, is4D4yPinnedMobileTitleStyle, isAllowedExtractedContentUrl, isCurrentFourD4yWebRequest, isExpectedForumNewThreadPreflightPayload, isExpectedForumWebPayload, isExpectedReplyPreflightPayload, isExpectedReplySubmissionPayload, isExpectedThreadWebPayload, isReadyForumNewThreadForm, parseForumNewThreadPreflightPayload, parseForumWebPayload, parseReplyPreflightPayload, parseReplySubmissionPayload, parseThreadWebPayload, resolveForumLink, select4D4yPostAuthor } from '../main/ets/domain/reader/FourD4yReaderContracts';
import { findFourD4yReaderScenario, FOUR_D4Y_READER_SCENARIOS, getPendingFourD4yReaderScenarios } from '../main/ets/domain/reader/FourD4yReaderScenarios';
import { areFourD4yReaderFixturesValueFree, findFourD4yReaderFixture,
  FOUR_D4Y_READER_FIXTURES } from '../main/ets/domain/reader/FourD4yReaderFixtures';
import { extractFourD4yInlineImageAttachmentIds, FourD4yComposerChoice, FourD4yImageUploadPhase, ForumComposerMode, isExpectedFourD4yComposerPreflight, isExpectedFourD4yComposerSubmission, isReadyFourD4yComposerForm, parseFourD4yComposerPreflightPayload, parseFourD4yComposerSubmissionPayload, parseFourD4yImageUploadStatusPayload } from '../main/ets/domain/composer/FourD4yComposerContracts';
import { createEditComposerRouteParams, createNewThreadComposerRouteParams, createQuoteComposerRouteParams } from '../main/ets/presentation/composer/ForumComposerRouteState';
import { createUserProfileRouteParams } from '../main/ets/presentation/profile/UserProfileRouteState';
import { FourD4ySession } from '../main/ets/data/remote/FourD4ySession';
import { ThreadWebPayload } from '../main/ets/domain/reader/FourD4yReaderContracts';
import { FOUR_D4Y_FORUM_GROUPS, FOUR_D4Y_QUICK_FORUM_IDS, getFourD4yForums } from '../main/ets/domain/catalog/FourD4yForumCatalog';
import { normalizeFourD4yLastForumId, resolveFourD4yHomeForumId } from
  '../main/ets/domain/navigation/FourD4yHomeForumState';
import { isQualifiedFourD4yRightSwipe } from
  '../main/ets/domain/navigation/FourD4yHorizontalGesture';
import { appendFourD4yThreadPosts, buildFourD4yPostCopyText, buildFourD4yPostPublicUrl,
  buildFourD4yPostShareText, buildFourD4yThreadPublicUrl, buildFourD4yThreadReaderUrl,
  buildFourD4yThreadShareText } from '../main/ets/domain/thread/FourD4yThreadActions';
import { formatFourD4yThreadCount, formatFourD4yThreadCreatedDate } from
  '../main/ets/domain/thread/FourD4yThreadDate';
import { FOUR_D4Y_MAX_QUICK_FORUMS, FourD4yImageLoadPolicy, FourD4yThemeMode,
  moveFourD4yQuickForumId, parseFourD4yUserSettings,
  serializeFourD4yUserSettings } from '../main/ets/domain/settings/FourD4yUserSettings';
import { buildFourD4yFavoriteAddUrl, FourD4yFavoriteReaderOutcome, getFourD4yFavoriteReaderOutcome,
  isAllowedFourD4yFavoriteOperationUrl,
  isExpectedFourD4yFavoriteMutationStartPayload, isExpectedFourD4yFavoritePagePayload,
  isExpectedFourD4yFavoriteVerificationPayload,
  parseFourD4yFavoriteMutationStartPayload,
  parseFourD4yFavoritePagePayload, parseFourD4yFavoriteVerificationPayload } from '../main/ets/domain/favorite/FourD4yFavoriteContracts';
import { FourD4yFavoriteState } from '../main/ets/domain/favorite/FourD4yFavoriteState';
import { FourD4yAttentionReaderOutcome, getFourD4yAttentionReaderOutcome,
  buildFourD4yAttentionOperationUrl, isAllowedFourD4yAttentionOperationUrl, isExpectedFourD4yAttentionPagePayload,
  isExpectedFourD4yAttentionVerificationPayload, parseFourD4yAttentionPagePayload,
  parseFourD4yAttentionVerificationPayload } from '../main/ets/domain/attention/FourD4yAttentionContracts';
import { FourD4yAttentionState } from '../main/ets/domain/attention/FourD4yAttentionState';
import { FourD4ySearchMode, FourD4ySearchReaderOutcome, FourD4ySearchThread, getFourD4ySearchReaderOutcome,
  buildFourD4ySearchPostTargetUrl, buildFourD4ySearchPostViewUrl, isAllowedFourD4ySearchPageUrl,
  isExpectedFourD4ySearchFormPayload, isExpectedFourD4ySearchPagePayload,
  isExpectedFourD4ySearchPostTargetPayload, isFourD4ySearchModeSupported, isMeaningfulFourD4yFullTextResult,
  parseFourD4ySearchFormPayload, parseFourD4ySearchPagePayload,
  parseFourD4ySearchPostTargetPayload } from '../main/ets/domain/search/FourD4ySearchContracts';
import { addFourD4ySearchHistoryEntry, parseFourD4ySearchHistory } from '../main/ets/domain/search/FourD4ySearchHistory';
import { addFourD4yReadHistoryEntry, FourD4yReadHistoryEntry, parseFourD4yReadHistory,
  serializeFourD4yReadHistory } from '../main/ets/domain/history/FourD4yReadHistory';
import { buildFourD4ySearchRequestUrl, encodeFourD4yGbkQueryComponent } from '../main/ets/domain/search/FourD4ySearchRequest';
import { parseFourD4yNativeSearchPage } from '../main/ets/data/remote/FourD4ySearchNativeParser';
import { extractFourD4ySearchPostRefreshUrl, parseFourD4ySearchPostTargetPage } from
  '../main/ets/data/remote/FourD4ySearchPostTargetParser';
import { extractFourD4ySetCookieHeaders, splitCombinedSetCookieHeader } from
  '../main/ets/data/remote/FourD4yResponseCookieBridge';
import { appendFourD4ySessionId } from '../main/ets/data/remote/FourD4yRequestCookieBridge';
import { FourD4yMyContentMode, FourD4yMyContentReaderOutcome, buildFourD4yMyContentUrl,
  getFourD4yMyContentReaderOutcome, isAllowedFourD4yMyContentUrl,
  isExpectedFourD4yMyContentPagePayload } from '../main/ets/domain/mine/FourD4yMyContentContracts';
import { parseFourD4yNativeMyContentPage } from '../main/ets/data/remote/FourD4yMyContentNativeParser';
import { FourD4yMessageKind, FourD4yMessageMode, FourD4yMessageReaderOutcome, buildFourD4yMessagePageUrl,
  getFourD4yMessageReaderOutcome, isAllowedFourD4yMessagePageUrl,
  isExpectedFourD4yMessagePagePayload, isExpectedFourD4yMessagePromptPayload } from
  '../main/ets/domain/notice/FourD4yMessageContracts';
import { parseFourD4yNativeMessagePage, parseFourD4yNativeMessagePrompt } from
  '../main/ets/data/remote/FourD4yMessageNativeParser';
import { FourD4yUnreadState } from '../main/ets/domain/notice/FourD4yUnreadState';
import { FourD4yPrivateConversationMessage, FourD4yPrivateConversationReaderOutcome,
  buildFourD4yPrivateConversationUrl, buildFourD4yPrivateMessageCopyText,
  getFourD4yPrivateConversationReaderOutcome, isAllowedFourD4yPrivateConversationUrl,
  isExpectedFourD4yPrivateConversationPayload } from
  '../main/ets/domain/notice/FourD4yPrivateConversationContracts';
import { buildFourD4yPrivateMessageSearchExcerpt, findFourD4yPrivateMessageSearchHits,
  normalizeFourD4yPrivateMessageSearchQuery } from '../main/ets/domain/notice/FourD4yPrivateMessageSearch';
import { parseFourD4yPrivateConversationPage } from
  '../main/ets/data/remote/FourD4yPrivateConversationNativeParser';
import { buildFourD4yPrivateMessagePreflightUrl, isExpectedFourD4yPrivateMessagePreflight,
  isExpectedFourD4yPrivateMessageSubmission, isReadyFourD4yPrivateMessageForm,
  parseFourD4yPrivateMessagePreflightPayload,
  parseFourD4yPrivateMessageSubmissionPayload } from
  '../main/ets/domain/notice/FourD4yPrivateMessageComposerContracts';
import { buildFourD4yUserProfileUrl, FourD4yUserProfileFact, FourD4yUserProfilePayload,
  FourD4yUserProfileReaderOutcome,
  getFourD4yUserProfileReaderOutcome, isCurrentFourD4yUserProfileRequest,
  isExpectedFourD4yUserProfilePayload, parseFourD4yUserProfilePayload } from
  '../main/ets/domain/profile/FourD4yUserProfileContracts';
import { buildFourD4yBlacklistUrl, FourD4yBlacklistEntry, FourD4yBlacklistPagePayload,
  FourD4yBlacklistReaderOutcome, getFourD4yBlacklistReaderOutcome,
  isCurrentFourD4yBlacklistRequest, isExpectedFourD4yBlacklistMutationStartPayload,
  isExpectedFourD4yBlacklistPagePayload, isValidFourD4yBlacklistUserName,
  parseFourD4yBlacklistMutationResultPayload, parseFourD4yBlacklistMutationStartPayload,
  parseFourD4yBlacklistPagePayload } from
  '../main/ets/domain/blacklist/FourD4yBlacklistContracts';
import { createBlacklistRouteParams } from '../main/ets/presentation/blacklist/BlacklistRouteState';
import { createFourD4yAttachmentFileName, isAllowedFourD4yAttachmentDownloadUrl } from
  '../main/ets/domain/attachment/FourD4yAttachmentContracts';
import { buildFourD4yPostDeletionPreflightUrl, isConfirmedFourD4yPostDeletion,
  isCurrentFourD4yPostDeletionPreflightRequest,
  isExpectedFourD4yPostDeletionPreflight, isReadyFourD4yPostDeletionForm,
  isExpectedFourD4yPostDeletionSubmissionStart, isExpectedFourD4yPostDeletionVerification,
  parseFourD4yPostDeletionPreflightPayload, parseFourD4yPostDeletionSubmissionStartPayload,
  parseFourD4yPostDeletionVerificationPayload } from
  '../main/ets/domain/post/FourD4yPostDeletionContracts';
import { classifyFourD4yHttpFailure, classifyFourD4yNetworkFailure,
  describeFourD4yNativeRequestFailure, FourD4yNativeRequestFailureKind } from
  '../main/ets/data/remote/FourD4yNativeRequestFailure';
import { createDefaultFourD4yAccountRegistry, FourD4yAccountIdentity, FourD4yAccountRegistry,
  parseFourD4yAccountIdentity, parseFourD4yAccountRegistry, serializeFourD4yAccountRegistry,
  upsertFourD4yAccountProfile } from '../main/ets/domain/account/FourD4yAccountContracts';
import { ImageViewerRouteState } from '../main/ets/presentation/image/ImageViewerRouteState';
import { appendUniqueFourD4yForumThreads } from '../main/ets/domain/reader/FourD4yForumPagination';
import { ThreadPost, ThreadSummary } from '../main/ets/domain/model/ForumModels';

interface SearchTestResponseHeaders {
  'Content-Type': string;
  'Set-Cookie': string[];
}

export default function localUnitTest() {
  describe('FourD4yReaderContracts', () => {
    it('accepts deliberate full-width right swipes but rejects short or vertical drags', 0, () => {
      expect(isQualifiedFourD4yRightSwipe(96, 18)).assertEqual(true);
      expect(isQualifiedFourD4yRightSwipe(71, 0)).assertEqual(false);
      expect(isQualifiedFourD4yRightSwipe(96, 80)).assertEqual(false);
      expect(isQualifiedFourD4yRightSwipe(-120, 0)).assertEqual(false);
    });

    it('formats original topic dates by local calendar day', 0, () => {
      const nowMillis: number = new Date(2026, 8, 9, 12, 0, 0).getTime();
      expect(formatFourD4yThreadCreatedDate('2026-9-9 00:01', nowMillis)).assertEqual('今天');
      expect(formatFourD4yThreadCreatedDate('2026-9-8 23:59', nowMillis)).assertEqual('昨天');
      expect(formatFourD4yThreadCreatedDate('2026-9-7 08:30', nowMillis)).assertEqual('2026-09-07');
      expect(formatFourD4yThreadCreatedDate('作者 今天 09:00', nowMillis)).assertEqual('今天');
      expect(formatFourD4yThreadCreatedDate('2026-2-30', nowMillis)).assertEqual('');
    });

    it('formats large thread counters with the same threshold as NG', 0, () => {
      expect(formatFourD4yThreadCount(10075)).assertEqual('10075');
      expect(formatFourD4yThreadCount(100000)).assertEqual('10万');
      expect(formatFourD4yThreadCount(101000)).assertEqual('10.1万');
      expect(formatFourD4yThreadCount(-1)).assertEqual('0');
    });

    it('restores the last visited board even when it is not a quick board', 0, () => {
      expect(resolveFourD4yHomeForumId('2', ['51'], ['51', '2', '6'])).assertEqual('2');
    });

    it('falls back from an invalid last board to the first valid quick board and catalog board', 0, () => {
      expect(resolveFourD4yHomeForumId('', ['bad', '6', '51'], ['51', '2', '6'])).assertEqual('6');
      expect(resolveFourD4yHomeForumId('999', ['bad'], ['51', '2'])).assertEqual('51');
      expect(normalizeFourD4yLastForumId('not-a-board', ['51', '2'])).assertEqual('');
    });

    it('builds canonical public thread links without leaking internal load markers', 0, () => {
      expect(buildFourD4yThreadPublicUrl('3462417')).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=3462417');
      expect(buildFourD4yThreadPublicUrl('3462417', 3)).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=3462417&page=3');
      expect(buildFourD4yThreadPublicUrl('bad', 3)).assertEqual('');
    });

    it('adds the validated author filter only to the internal reader request', 0, () => {
      expect(buildFourD4yThreadReaderUrl('3462417', 2, 8, '700001')).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=3462417&page=2&authorid=700001&oh_load=8');
      expect(buildFourD4yThreadReaderUrl('3462417', 2, 8, 'bad')).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=3462417&page=2&oh_load=8');
    });

    it('shares topic metadata and the canonical URL without any post body', 0, () => {
      expect(buildFourD4yThreadShareText('测试主题', '楼主', '3462417')).assertEqual(
        '主题：测试主题\n作者：楼主\nhttps://www.4d4y.com/forum/viewthread.php?tid=3462417');
    });

    it('builds NG-style floor copy and sharing text without decorative or download-only content', 0, () => {
      const post: ThreadPost = {
        id: '9123',
        threadId: '3462417',
        floor: 2,
        authorName: '回复者',
        content: [
          { kind: 'text', value: '正文' },
          { kind: 'emoji', value: '[表情]' },
          { kind: 'quote', value: '引用内容' },
          { kind: 'image', value: '图片', url: 'https://img.example.test/photo.jpg' },
          { kind: 'attachment', value: 'sample.rar', url: 'https://www.4d4y.com/forum/attachment.php?aid=1' },
          { kind: 'link', value: '外链', url: 'https://example.test/' }
        ]
      };
      expect(buildFourD4yPostCopyText(post)).assertEqual(
        '正文『引用内容』[图片:https://img.example.test/photo.jpg]');
      expect(buildFourD4yPostPublicUrl('3462417', '9123', 1)).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=3462417');
      expect(buildFourD4yPostPublicUrl('3462417', '9123', 2)).assertEqual(
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&pid=9123&ptid=3462417');
      expect(buildFourD4yPostShareText('测试主题', '3462417', post)).assertEqual(
        '回帖 ：测试主题\n2#  作者 ：回复者\n' +
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&pid=9123&ptid=3462417\n\n' +
        '正文『引用内容』[图片:https://img.example.test/photo.jpg]');
    });

    it('appends a thread page without repeating a redirected boundary post', 0, () => {
      const firstPage: ThreadPost[] = [
        { id: '10', threadId: '1', floor: 1, authorName: 'a', content: [] },
        { id: '11', threadId: '1', floor: 2, authorName: 'b', content: [] }
      ];
      const nextPage: ThreadPost[] = [
        { id: '11', threadId: '1', floor: 2, authorName: 'b', content: [] },
        { id: '12', threadId: '1', floor: 3, authorName: 'c', content: [] }
      ];
      const merged: ThreadPost[] = appendFourD4yThreadPosts(firstPage, nextPage);
      expect(merged.length).assertEqual(3);
      expect(merged[0].id).assertEqual('10');
      expect(merged[2].id).assertEqual('12');
    });

    it('appends a board page without repeating a boundary topic', 0, () => {
      const firstPage: ThreadSummary[] = [{ id: '1', forumId: '7', title: 'first', authorName: 'a', replyCount: 0, isPinned: true },
        { id: '2', forumId: '7', title: 'second', authorName: 'b', replyCount: 1, isPinned: false }];
      const nextPage: ThreadSummary[] = [{ id: '2', forumId: '7', title: 'second changed', authorName: 'b', replyCount: 1, isPinned: false },
        { id: '3', forumId: '7', title: 'third', authorName: 'c', replyCount: 2, isPinned: false }];
      const merged = appendUniqueFourD4yForumThreads(firstPage, nextPage);
      expect(merged.length).assertEqual(3);
      expect(merged[0].id).assertEqual('1');
      expect(merged[1].title).assertEqual('second');
      expect(merged[2].id).assertEqual('3');
    });

    it('keeps authenticated attachment downloads on the 4D4Y attachment endpoint', 0, () => {
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://www.4d4y.com/forum/attachment.php?aid=900')).assertEqual(true);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://4d4y.com/forum/attachment.php?aid=900')).assertEqual(true);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://www.4d4y.com/forum/attachment.php?aid=opaque_AID-token%2F1&k=signature')).assertEqual(true);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'http://www.4d4y.com/forum/attachment.php?aid=900')).assertEqual(false);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://www.4d4y.com/forum/viewthread.php?tid=900')).assertEqual(false);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://example.com/attachment.php?aid=900')).assertEqual(false);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://www.4d4y.com/forum/attachment.php?action=download')).assertEqual(false);
      expect(isAllowedFourD4yAttachmentDownloadUrl(
        'https://www.4d4y.com/forum/attachment.php?aid=&k=signature')).assertEqual(false);
    });

    it('removes a visible size and path characters from attachment save names', 0, () => {
      expect(createFourD4yAttachmentFileName('sample.apk (492.17 KB)')).assertEqual('sample.apk');
      expect(createFourD4yAttachmentFileName('../folder\\sample.rar')).assertEqual('_folder_sample.rar');
      expect(createFourD4yAttachmentFileName('  ...  ')).assertEqual('4d4y-attachment');
    });

    it('filters only the URL forms rejected by the current extractor', 0, () => {
      expect(isAllowedExtractedContentUrl('https://www.4d4y.com/forum/attachment.php?aid=1')).assertEqual(true);
      expect(isAllowedExtractedContentUrl('attachment.php?aid=1')).assertEqual(true);
      expect(isAllowedExtractedContentUrl('javascript:alert(1)')).assertEqual(false);
      expect(isAllowedExtractedContentUrl(' data:text/html,blocked')).assertEqual(false);
      expect(isAllowedExtractedContentUrl('#reply-12')).assertEqual(false);
      expect(isAllowedExtractedContentUrl('   ')).assertEqual(false);
    });

    it('adds only request-scoped 4D4Y full-site context to an authenticated cookie header', 0, () => {
      const header = FourD4ySession.createFullSiteCookieHeader('cdb_auth=opaque; theme=light', '12345', '51');
      expect(header.indexOf('cdb_uid=12345') >= 0).assertEqual(true);
      expect(header.indexOf('cdb_visitedfid=51') >= 0).assertEqual(true);
      expect(header.indexOf('cdb_auth=opaque') >= 0).assertEqual(true);
      expect(FourD4ySession.createFullSiteCookieHeader('cdb_auth=opaque', 'not-a-user', '51')).assertEqual('');
    });

    it('rejects stale ArkWeb lifecycle URLs before they can update the reader', 0, () => {
      const forumUrl = 'https://www.4d4y.com/forum/forumdisplay.php?fid=2&page=1&oh_load=18';
      expect(isCurrentFourD4yWebRequest(forumUrl, '/forum/forumdisplay.php', 18)).assertEqual(true);
      expect(isCurrentFourD4yWebRequest(forumUrl, '/forum/forumdisplay.php', 17)).assertEqual(false);
      expect(isCurrentFourD4yWebRequest(forumUrl, '/forum/viewthread.php', 18)).assertEqual(false);
    });

    it('keeps the verified full forum catalog separate from quick access', 0, () => {
      const forums = getFourD4yForums();
      expect(FOUR_D4Y_FORUM_GROUPS.length).assertEqual(3);
      expect(forums.length).assertEqual(19);
      expect(FOUR_D4Y_QUICK_FORUM_IDS.length).assertEqual(7);
      expect(forums.filter((forum) => forum.id === '51').length).assertEqual(1);
      expect(forums.filter((forum) => forum.id === '56').length).assertEqual(1);
      expect(forums.filter((forum) => forum.id === '63').length).assertEqual(1);
      expect(FOUR_D4Y_QUICK_FORUM_IDS.indexOf('56') < 0).assertEqual(true);
    });

    it('bounds display-only settings to known forum IDs and supported choices', 0, () => {
      const settings = parseFourD4yUserSettings(JSON.stringify({
        themeMode: 'dark', fontScale: 1.19, postLineSpacing: 1.27, imageLoadPolicy: 'tap',
        showPinnedThreads: false, postTimeSortForumIds: ['51', '51', 'not-a-forum', '2'],
        quickForumIds: ['51', '51', 'not-a-forum', '2', '6', '7', '9', '60', '50', '62', '56', '12', '40', '22']
      }));
      expect(settings.themeMode).assertEqual(FourD4yThemeMode.Dark);
      expect(settings.fontScale).assertEqual(1.15);
      expect(settings.postLineSpacing).assertEqual(1.24);
      expect(settings.imageLoadPolicy).assertEqual(FourD4yImageLoadPolicy.TapToLoad);
      expect(settings.showPinnedThreads).assertEqual(false);
      expect(settings.postTimeSortForumIds.length).assertEqual(2);
      expect(settings.postTimeSortForumIds[0]).assertEqual('51');
      expect(settings.postTimeSortForumIds[1]).assertEqual('2');
      expect(settings.quickForumIds.length).assertEqual(FOUR_D4Y_MAX_QUICK_FORUMS);
      expect(settings.quickForumIds[0]).assertEqual('51');
      expect(settings.quickForumIds.indexOf('not-a-forum') < 0).assertEqual(true);
      const moved = moveFourD4yQuickForumId(['51', '2', '6'], '2', -1);
      expect(moved[0]).assertEqual('2');
      expect(moved[1]).assertEqual('51');
      const serialized = serializeFourD4yUserSettings(settings);
      expect(parseFourD4yUserSettings(serialized).quickForumIds.length).assertEqual(FOUR_D4Y_MAX_QUICK_FORUMS);
    });

    it('keeps existing settings compatible by defaulting the post line spacing', 0, () => {
      const settings = parseFourD4yUserSettings(JSON.stringify({
        themeMode: 'light', fontScale: 1, imageLoadPolicy: 'automatic', quickForumIds: ['51']
      }));
      expect(settings.postLineSpacing).assertEqual(1);
      expect(settings.showPinnedThreads).assertEqual(true);
      expect(settings.postTimeSortForumIds.length).assertEqual(0);
    });

    it('enables a new topic only after a matching value-free form preflight', 0, () => {
      const payload = parseForumNewThreadPreflightPayload(JSON.stringify({
        forumId: '40', probeSequence: 5, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, formFound: true, formMethod: 'post', hasSubjectField: true,
        hasMessageField: true, hasFormhashField: true, hasPosttimeField: true,
        hasWysiwygField: true, hasSubmitAction: true, errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedForumNewThreadPreflightPayload(payload, '40', 5)).assertEqual(true);
      expect(isExpectedForumNewThreadPreflightPayload(payload, '40', 4)).assertEqual(false);
      expect(isReadyForumNewThreadForm(payload)).assertEqual(true);
      // 4D4Y may include Cloudflare's passive bootstrap script with a fully
      // usable form, so the marker alone must not disable posting.
      payload.hasChallenge = true;
      expect(isReadyForumNewThreadForm(payload)).assertEqual(true);
      payload.hasPosttimeField = false;
      expect(isReadyForumNewThreadForm(payload)).assertEqual(false);
    });

    it('accepts only a matching server-favorites page and same-thread action', 0, () => {
      const favoritePayloadJson: string = '{"page":2,"lastPage":3,"loadSequence":9,"accessState":"available",' +
        '"hasChallenge":true,"formFound":true,"hasDeletionControl":true,"errorMessage":"",' +
        '"threads":[{"threadId":"3422395","forumId":"2","title":"收藏样本",' +
        '"forumName":"Discovery","replyCount":12,"lastReplyAt":"2026-08-23 10:00"}]}';
      const payload = parseFourD4yFavoritePagePayload(favoritePayloadJson);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yFavoritePagePayload(payload, 2, 9)).assertEqual(true);
      expect(isExpectedFourD4yFavoritePagePayload(payload, 1, 9)).assertEqual(false);
      expect(getFourD4yFavoriteReaderOutcome(payload)).assertEqual(FourD4yFavoriteReaderOutcome.Content);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&action=add&tid=3422395', '3422395'
      )).assertEqual(true);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&action=remove&tid=3422395', '3422394'
      )).assertEqual(false);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://example.com/forum/my.php?item=favorites&action=add&tid=3422395', '3422395'
      )).assertEqual(false);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&tid=3422395', '3422395'
      )).assertEqual(false);
      expect(buildFourD4yFavoriteAddUrl('3422395')).assertEqual(
        'https://www.4d4y.com/forum/my.php?item=favorites&action=add&inajax=1&ajaxtarget=favorite_msg&tid=3422395'
      );
      expect(buildFourD4yFavoriteAddUrl('not-a-thread')).assertEqual('');
    });

    it('requires a correlated favorite mutation start acknowledgement', 0, () => {
      const start = parseFourD4yFavoriteMutationStartPayload(JSON.stringify({
        threadId: '3422395', operationSequence: 14, started: true, errorMessage: ''
      }));
      expect(start === null).assertEqual(false);
      if (start === null) {
        return;
      }
      expect(isExpectedFourD4yFavoriteMutationStartPayload(start, '3422395', 14)).assertEqual(true);
      expect(isExpectedFourD4yFavoriteMutationStartPayload(start, '3422395', 15)).assertEqual(false);
    });

    it('accepts only a correlated server-list favorite verification', 0, () => {
      const verified = parseFourD4yFavoriteVerificationPayload(JSON.stringify({
        threadId: '3422395', operationSequence: 15, page: 2,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        formFound: true, favoritePresent: true, errorMessage: ''
      }));
      expect(verified === null).assertEqual(false);
      if (verified === null) {
        return;
      }
      expect(isExpectedFourD4yFavoriteVerificationPayload(verified, '3422395', 15, 2)).assertEqual(true);
      expect(isExpectedFourD4yFavoriteVerificationPayload(verified, '3422395', 15, 1)).assertEqual(false);
      expect(parseFourD4yFavoriteVerificationPayload(JSON.stringify({
        threadId: '3422395', operationSequence: 15, page: 2,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        formFound: true, errorMessage: ''
      })) === null).assertEqual(true);
    });

    it('retains only server-confirmed favorite IDs across detail routes', 0, () => {
      const state = new FourD4yFavoriteState();
      state.observeServerFavorites(['3422395', '3422396', 'invalid']);
      expect(state.isFavorite('3422395')).assertEqual(true);
      expect(state.isFavorite('3422396')).assertEqual(true);
      expect(state.isFavorite('invalid')).assertEqual(false);
      state.markNotFavorite('3422395');
      expect(state.isFavorite('3422395')).assertEqual(false);
    });

    it('notifies a list only after the matching favorite mutation is confirmed', 0, () => {
      const state = new FourD4yFavoriteState();
      let notificationCount: number = 0;
      let notifiedState: boolean = true;
      state.subscribeToThreadMutation('3422395', (isFavorite: boolean) => {
        notificationCount += 1;
        notifiedState = isFavorite;
      });
      state.notifyConfirmedThreadMutation('3422396', false);
      expect(notificationCount).assertEqual(0);
      state.notifyConfirmedThreadMutation('3422395', false);
      expect(notificationCount).assertEqual(1);
      expect(notifiedState).assertEqual(false);
      state.notifyConfirmedThreadMutation('3422395', true);
      expect(notificationCount).assertEqual(1);
    });

    it('keeps attention contract separate from favorites and correlates its server list', 0, () => {
      const payload = parseFourD4yAttentionPagePayload('{"page":3,"lastPage":4,"loadSequence":8,' +
        '"accessState":"available","hasChallenge":false,"formFound":true,"hasDeletionControl":true,' +
        '"errorMessage":"","threads":[{"threadId":"3422395","forumId":"2","title":"关注样本",' +
        '"forumName":"Discovery","replyCount":12,"lastReplyAt":"2026-08-25 10:00"}]}');
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yAttentionPagePayload(payload, 3, 8)).assertEqual(true);
      expect(getFourD4yAttentionReaderOutcome(payload)).assertEqual(FourD4yAttentionReaderOutcome.Content);
      expect(isAllowedFourD4yAttentionOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=attention&tid=3422395', '3422395'
      )).assertEqual(true);
      expect(isAllowedFourD4yAttentionOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&tid=3422395', '3422395'
      )).assertEqual(false);
      expect(buildFourD4yAttentionOperationUrl('3422395')).assertEqual(
        'https://www.4d4y.com/forum/my.php?item=attention&action=add&inajax=1&ajaxtarget=favorite_msg&tid=3422395'
      );
      expect(buildFourD4yAttentionOperationUrl('3422395', true)).assertEqual(
        'https://www.4d4y.com/forum/my.php?item=attention&action=remove&inajax=1&ajaxtarget=favorite_msg&tid=3422395'
      );
      const verified = parseFourD4yAttentionVerificationPayload('{"threadId":"3422395",' +
        '"operationSequence":9,"page":3,"accessState":"available","hasChallenge":false,' +
        '"formFound":true,"favoritePresent":true,"errorMessage":""}');
      expect(verified === null).assertEqual(false);
      if (verified !== null) {
        expect(verified.attentionPresent).assertEqual(true);
        expect(isExpectedFourD4yAttentionVerificationPayload(verified, '3422395', 9, 3)).assertEqual(true);
      }
    });

    it('retains only server-confirmed attention IDs and notifies once', 0, () => {
      const state = new FourD4yAttentionState();
      state.observeServerAttentions(['3422395', 'bad-id']);
      expect(state.isAttentioned('3422395')).assertEqual(true);
      expect(state.isAttentioned('bad-id')).assertEqual(false);
      let notificationCount: number = 0;
      state.subscribeToThreadMutation('3422395', (isAttentioned: boolean) => {
        if (!isAttentioned) {
          notificationCount += 1;
        }
      });
      state.notifyConfirmedThreadMutation('3422395', false);
      state.notifyConfirmedThreadMutation('3422395', false);
      expect(notificationCount).assertEqual(1);
      state.markNotAttentioned('3422395');
      expect(state.isAttentioned('3422395')).assertEqual(false);
    });

    it('enables only search modes advertised by the current server form', 0, () => {
      const form = parseFourD4ySearchFormPayload(JSON.stringify({
        probeSequence: 4, viewerUserId: '12345', accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        formFound: true, formMethod: 'get', actionPath: '/forum/search.php', hasKeywordField: true,
        // Current 4D4Y advertises title in the HTML form but keeps full-text
        // available through the direct contract used by NG and MY 4D4Y.
        searchTypes: ['title'], hasAuthorNameField: true, hasAuthorIdField: true,
        hasForumFilter: true, forumFieldName: 'srchfid[0]', hasSubmitControl: true, errorMessage: ''
      }));
      expect(form === null).assertEqual(false);
      if (form === null) {
        return;
      }
      expect(isExpectedFourD4ySearchFormPayload(form, 4)).assertEqual(true);
      expect(isExpectedFourD4ySearchFormPayload(form, 5)).assertEqual(false);
      expect(isFourD4ySearchModeSupported(form, FourD4ySearchMode.Title, '鸿蒙')).assertEqual(true);
      expect(isFourD4ySearchModeSupported(form, FourD4ySearchMode.FullText, '鸿蒙')).assertEqual(true);
      expect(isFourD4ySearchModeSupported(form, FourD4ySearchMode.Author, '12345')).assertEqual(true);
      const fullTextUrl = buildFourD4ySearchRequestUrl('https://www.4d4y.com/forum/', form,
        FourD4ySearchMode.FullText, '4d4y', 'all');
      expect(fullTextUrl).assertEqual('https://www.4d4y.com/forum/search.php?srchtype=fulltext&srchtxt=4d4y&' +
        'searchsubmit=true&st=on&srchuname=&srchfilter=all&srchfrom=0&before=&orderby=lastpost&' +
        'ascdesc=desc&srchfid%5B0%5D=all&page=1');
      const authorNameUrl = buildFourD4ySearchRequestUrl('https://www.4d4y.com/forum/', form,
        FourD4ySearchMode.Author, 'Curnane', '51');
      expect(authorNameUrl).assertEqual('https://www.4d4y.com/forum/search.php?mod=forum&searchsubmit=yes&' +
        'srchuname=Curnane&srchtype=title&orderby=lastpost&ascdesc=desc&srchfid%5B0%5D=51&page=1');
      const authorUidUrl = buildFourD4ySearchRequestUrl('https://www.4d4y.com/forum/', form,
        FourD4ySearchMode.Author, '12345', '51');
      expect(authorUidUrl).assertEqual('https://www.4d4y.com/forum/search.php?mod=forum&searchsubmit=yes&' +
        'srchuid=12345&srchtype=title&orderby=lastpost&ascdesc=desc&srchfid%5B0%5D=51&page=1');
      // The host-side hvigor test runtime does not provide the device GBK
      // codec. Device regression verifies the actual `%D6%D0%CE%C4` bytes;
      // here, keep this test valid on both host and HarmonyOS runtimes.
      const gbkKeyword = encodeFourD4yGbkQueryComponent('中文');
      if (gbkKeyword !== null) {
        expect(gbkKeyword).assertEqual('%D6%D0%CE%C4');
        const titleUrl = buildFourD4ySearchRequestUrl('https://www.4d4y.com/forum/', form,
          FourD4ySearchMode.Title, '中文', '2');
        expect(titleUrl === null).assertEqual(false);
        if (titleUrl !== null) {
          expect(titleUrl.indexOf('srchtxt=%D6%D0%CE%C4') >= 0).assertEqual(true);
          expect(titleUrl.indexOf('mod=forum') >= 0).assertEqual(true);
          expect(titleUrl.indexOf('searchsubmit=yes') >= 0).assertEqual(true);
          expect(titleUrl.indexOf('srchfid%5B0%5D=2') >= 0).assertEqual(true);
          expect(titleUrl.indexOf('page=1') >= 0).assertEqual(true);
        }
      }
      form.searchTypes = [];
      expect(isFourD4ySearchModeSupported(form, FourD4ySearchMode.Title, '鸿蒙')).assertEqual(false);
    });

    it('accepts only correlated same-origin search result pages', 0, () => {
      const payload = parseFourD4ySearchPagePayload('{"loadSequence":6,"page":1,"lastPage":3,' +
        '"accessState":"available","hasChallenge":false,"resultLayoutFound":true,' +
        '"previousPageUrl":"","nextPageUrl":"https://www.4d4y.com/forum/search.php?searchid=123&page=2",' +
        '"errorMessage":"","threads":[{"threadId":"3422395","postId":"","forumId":"2","title":"搜索样本",' +
        '"summary":"",' +
        '"forumName":"Discovery","authorName":"tester","replyCount":8,"lastReplyAt":"today"}]}');
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4ySearchPagePayload(payload, 6)).assertEqual(true);
      expect(isExpectedFourD4ySearchPagePayload(payload, 5)).assertEqual(false);
      expect(getFourD4ySearchReaderOutcome(payload)).assertEqual(FourD4ySearchReaderOutcome.Content);
      expect(isAllowedFourD4ySearchPageUrl(payload.nextPageUrl)).assertEqual(true);
      expect(isAllowedFourD4ySearchPageUrl('https://example.com/forum/search.php?searchid=123')).assertEqual(false);
      expect(isAllowedFourD4ySearchPageUrl('https://www.4d4y.com/forum/search.php?searchid=123#x')).assertEqual(false);
      payload.threads = [];
      expect(getFourD4ySearchReaderOutcome(payload)).assertEqual(FourD4ySearchReaderOutcome.Empty);
    });

    it('parses the native GBK-decoded search layout without retaining response HTML', 0, () => {
      const html = '<form action="search.php"></form><tbody id="normalthread_99"><tr>' +
        '<td class="forum"><a href="forumdisplay.php?fid=2">Discovery</a></td>' +
        '<td class="author"><cite><a>tester</a></cite></td>' +
        '<td><span id="thread_99"><a>4D4Y &amp; test</a></span></td>' +
        '<td class="nums"><strong>12</strong></td><td class="lastpost">today</td>' +
        '</tr></tbody><div class="pages">' +
        '<a href="search.php?mod=forum&amp;page=2">下一页</a>' +
        '<a href="search.php?mod=forum&amp;page=13">13</a></div>';
      const payload = parseFourD4yNativeSearchPage(html,
        'https://www.4d4y.com/forum/search.php?mod=forum&page=1', 7);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.threads.length).assertEqual(1);
      expect(payload.threads[0].threadId).assertEqual('99');
      expect(payload.threads[0].forumId).assertEqual('2');
      expect(payload.threads[0].forumName).assertEqual('Discovery');
      expect(payload.threads[0].authorName).assertEqual('tester');
      expect(payload.threads[0].replyCount).assertEqual(12);
      expect(payload.page).assertEqual(1);
      expect(payload.lastPage).assertEqual(13);
      expect(payload.nextPageUrl.endsWith('page=2')).assertEqual(true);
    });

    it('parses NG-compatible title rows even when the server omits a thread tbody id', 0, () => {
      const html = '<form action="search.php"></form><tbody><tr>' +
        '<th class="subject"><a href="viewthread.php?tid=101&amp;extra=page%3D1">4d4y title</a></th>' +
        '<td class="forum"><a href="forumdisplay.php?fid=2">Discovery</a></td>' +
        '<td class="author"><cite><a href="space.php?uid=8">tester</a></cite><em>today</em></td>' +
        '</tr></tbody>';
      const payload = parseFourD4yNativeSearchPage(html,
        'https://www.4d4y.com/forum/search.php?srchtxt=4d4y', 8);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.threads.length).assertEqual(1);
      expect(payload.threads[0].threadId).assertEqual('101');
      expect(payload.threads[0].title).assertEqual('4d4y title');
      expect(payload.threads[0].authorName).assertEqual('tester');
      expect(payload.threads[0].lastReplyAt).assertEqual('today');
    });

    it('uses only the NG pagination container when calculating a search last page', 0, () => {
      const html = '<form action="search.php"></form><tbody><tr>' +
        '<th class="subject"><a href="viewthread.php?tid=103">page scope</a></th></tr></tbody>' +
        '<a href="search.php?mod=forum&amp;page=30595">unrelated result link</a>' +
        '<div class="pages_btns"><div class="pages">' +
        '<strong>1/13</strong><a href="search.php?searchid=3&amp;page=2">next</a>' +
        '</div></div>';
      const payload = parseFourD4yNativeSearchPage(html,
        'https://www.4d4y.com/forum/search.php?searchid=3', 10);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.lastPage).assertEqual(13);
      expect(payload.nextPageUrl.endsWith('page=2')).assertEqual(true);
    });

    it('preserves pid-only full-text hits, summaries, metadata, and repeated topics', 0, () => {
      const html = '<form action="search.php"></form><table class="datatable"><tr>' +
        '<td><div class="sp_title"><a href="gotopost.php?pid=88">4d4y content</a></div>' +
        '<div class="sp_content">first matched &amp; text</div>' +
        '<div class="sp_theard"><span><a href="forumdisplay.php?fid=3">Buy &amp; Sell</a></span>' +
        '<span><a href="space.php?uid=9">author</a></span><span>查看: 8</span><span>回复: 2</span>' +
        '<span>最后发表: 2026-08-23 12:00</span></div></td></tr><tr>' +
        '<td><div class="sp_title"><a href="gotopost.php?pid=89&amp;ptid=102">second hit</a></div>' +
        '<div class="sp_content">second text</div><div class="sp_theard">' +
        '<span><a href="forumdisplay.php?fid=3">Buy &amp; Sell</a></span>' +
        '<span><a href="space.php?uid=9">author</a></span><span>查看: 8</span><span>回复: 2</span>' +
        '<span>最后发表: 2026-08-23 12:00</span></div></td></tr></table>';
      const payload = parseFourD4yNativeSearchPage(html,
        'https://www.4d4y.com/forum/search.php?srchtype=fulltext&srchtxt=4d4y', 9);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.threads.length).assertEqual(2);
      expect(payload.threads[0].threadId).assertEqual('');
      expect(payload.threads[0].postId).assertEqual('88');
      expect(payload.threads[0].title).assertEqual('4d4y content');
      expect(payload.threads[0].summary).assertEqual('first matched & text');
      expect(payload.threads[0].forumName).assertEqual('Buy & Sell');
      expect(payload.threads[0].authorName).assertEqual('author');
      expect(payload.threads[0].replyCount).assertEqual(2);
      expect(payload.threads[1].threadId).assertEqual('102');
      expect(payload.threads[1].postId).assertEqual('89');
    });

    it('accepts only a correlated pid-to-native-thread resolution', 0, () => {
      const payload = parseFourD4ySearchPostTargetPayload(JSON.stringify({
        resolveSequence: 3, requestedPostId: '88', threadId: '102', page: 2, floor: 61,
        title: 'thread title', postFound: true, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload !== null) {
        expect(isExpectedFourD4ySearchPostTargetPayload(payload, '88', 3)).assertEqual(true);
        expect(isExpectedFourD4ySearchPostTargetPayload(payload, '89', 3)).assertEqual(false);
      }
      expect(buildFourD4ySearchPostTargetUrl('102', '88')).assertEqual(
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&ptid=102&pid=88');
      expect(buildFourD4ySearchPostTargetUrl('', '88')).assertEqual(
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&ptid=&pid=88');
      expect(buildFourD4ySearchPostViewUrl('102', '88')).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=102&viewpid=88&inajax=1&mobile=no');
      expect(buildFourD4ySearchPostViewUrl('', '88') === null).assertEqual(true);
      expect(buildFourD4ySearchPostTargetUrl('../102', '88') === null).assertEqual(true);
    });

    it('filters only full-text hits whose visible keyword is confined to references or links', 0, () => {
      const linkOnly: FourD4ySearchThread = {
        threadId: '102', postId: '88', forumId: '2', title: 'ordinary title',
        summary: '[size=1][color=#999][url=https://www.4d4y.com/forum/viewthread.php?tid=1]4d4y~[/url][/color][/size]',
        forumName: 'Discovery', authorName: 'author', replyCount: 2, lastReplyAt: ''
      };
      expect(isMeaningfulFourD4yFullTextResult(linkOnly, '4d4y')).assertEqual(false);
      const bodyAndLink: FourD4ySearchThread = {
        threadId: '102', postId: '89', forumId: '2', title: 'ordinary title',
        summary: '迁移到 4d4y 后可用 [url=https://www.4d4y.com]4d4y~[/url]',
        forumName: 'Discovery', authorName: 'author', replyCount: 2, lastReplyAt: ''
      };
      expect(isMeaningfulFourD4yFullTextResult(bodyAndLink, '4D4Y')).assertEqual(true);
      const omittedExcerpt: FourD4ySearchThread = {
        threadId: '102', postId: '90', forumId: '2', title: 'ordinary title', summary: '服务器未展示命中片段',
        forumName: 'Discovery', authorName: 'author', replyCount: 2, lastReplyAt: ''
      };
      expect(isMeaningfulFourD4yFullTextResult(omittedExcerpt, '4d4y')).assertEqual(true);
    });

    it('follows only the current MY 4D4Y same-origin find-post refresh and resolves its floor', 0, () => {
      const refreshHtml = '<meta content="0; URL=viewthread.php?tid=102&amp;page=2#pid88" http-equiv="refresh">';
      expect(extractFourD4ySearchPostRefreshUrl(refreshHtml)).assertEqual(
        'https://www.4d4y.com/forum/viewthread.php?tid=102&page=2#pid88');
      expect(extractFourD4ySearchPostRefreshUrl(
        '<meta http-equiv="refresh" content="0;url=https://example.com/thread">')).assertEqual('');
      const pageHtml = '<html><head><title>thread title - 4D4Y</title></head><body>' +
        '<table id="pid88"><a id="postnum88"><em>61</em>#</a><div id="postmessage_88">target</div></table>' +
        '<script>tid = parseInt(\'102\')</script></body></html>';
      const payload = parseFourD4ySearchPostTargetPage(pageHtml,
        'https://www.4d4y.com/forum/viewthread.php?tid=102&viewpid=88&inajax=1&mobile=no',
        '102', '88', 4);
      expect(payload === null).assertEqual(false);
      if (payload !== null) {
        expect(payload.threadId).assertEqual('102');
        expect(payload.page).assertEqual(2);
        expect(payload.floor).assertEqual(61);
        expect(payload.postFound).assertEqual(true);
      }
      const namedFloorHtml = '<table id="pid89"><a id="postnum89">沙发</a></table>';
      const namedFloor = parseFourD4ySearchPostTargetPage(namedFloorHtml,
        'https://www.4d4y.com/forum/viewthread.php?tid=102&viewpid=89&inajax=1&mobile=no',
        '102', '89', 5);
      expect(namedFloor === null).assertEqual(false);
      if (namedFloor !== null) {
        expect(namedFloor.floor).assertEqual(2);
        expect(namedFloor.page).assertEqual(1);
      }
    });

    it('does not treat a verified result page with stray login inputs as logged out', 0, () => {
      const html = '<form id="loginform" action="logging.php?action=login">' +
        '<input name="username"><input name="password"></form><tbody><tr>' +
        '<th class="subject"><a href="viewthread.php?tid=104">4d4y result</a></th></tr></tbody>';
      const payload = parseFourD4yNativeSearchPage(html,
        'https://www.4d4y.com/forum/search.php?srchtxt=4d4y', 11);
      expect(payload === null).assertEqual(false);
      if (payload !== null) {
        expect(payload.accessState).assertEqual(FourD4yPageAccessState.Available);
        expect(payload.threads.length).assertEqual(1);
      }
    });

    it('requires a confirmed login form before classifying a search response as logged out', 0, () => {
      const unrelated = '<form action="search.php"><input name="username"></form>';
      const unrelatedPayload = parseFourD4yNativeSearchPage(unrelated,
        'https://www.4d4y.com/forum/search.php?srchtxt=4d4y', 12);
      expect(unrelatedPayload === null).assertEqual(false);
      if (unrelatedPayload !== null) {
        expect(unrelatedPayload.accessState).assertEqual(FourD4yPageAccessState.Available);
      }
      const login = '<form id="loginform" action="logging.php?action=login">' +
        '<input name="username"><input name="password"></form>';
      const loginPayload = parseFourD4yNativeSearchPage(login,
        'https://www.4d4y.com/forum/search.php?srchtxt=4d4y', 13);
      expect(loginPayload === null).assertEqual(false);
      if (loginPayload !== null) {
        expect(loginPayload.accessState).assertEqual(FourD4yPageAccessState.LoginRequired);
      }
    });

    it('splits combined Set-Cookie values without breaking an Expires date', 0, () => {
      const values: string[] = splitCombinedSetCookieHeader(
        'sid=one; Expires=Sun, 23 Aug 2026 12:00:00 GMT; Path=/, cdb_auth=two; HttpOnly; Path=/forum');
      expect(values.length).assertEqual(2);
      expect(values[0].startsWith('sid=one;')).assertEqual(true);
      expect(values[1].startsWith('cdb_auth=two;')).assertEqual(true);
      const responseHeaders: SearchTestResponseHeaders = {
        'Content-Type': 'text/html',
        'Set-Cookie': ['sid=one; Path=/', 'cdb_auth=two; HttpOnly; Path=/forum']
      };
      const extracted: string[] = extractFourD4ySetCookieHeaders(responseHeaders);
      expect(extracted.length).assertEqual(2);
    });

    it('mirrors only the bounded MY 4D4Y sid cookie into a search URL', 0, () => {
      const url: string = 'https://www.4d4y.com/forum/search.php?mod=forum&page=1';
      const withSid: string = appendFourD4ySessionId(url, 'cdb_auth=opaque; sid=test_123; other=x');
      expect(withSid).assertEqual(url + '&sid=test_123');
      expect(appendFourD4ySessionId(withSid, 'sid=another')).assertEqual(withSid);
      expect(appendFourD4ySessionId('https://example.com/search.php?a=1', 'sid=test_123'))
        .assertEqual('https://example.com/search.php?a=1');
    });

    it('allows only the NG and MY 4D4Y read-only account-list routes', 0, () => {
      const threadsUrl: string | null = buildFourD4yMyContentUrl(FourD4yMyContentMode.Threads, 2);
      const repliesUrl: string | null = buildFourD4yMyContentUrl(FourD4yMyContentMode.Replies, 3);
      expect(threadsUrl).assertEqual('https://www.4d4y.com/forum/my.php?item=threads&page=2');
      expect(repliesUrl).assertEqual('https://www.4d4y.com/forum/my.php?item=posts&page=3');
      expect(threadsUrl !== null && isAllowedFourD4yMyContentUrl(threadsUrl)).assertEqual(true);
      expect(isAllowedFourD4yMyContentUrl(
        'https://www.4d4y.com/forum/my.php?item=posts&page=1&_t=1787460000&sid=test_123')).assertEqual(true);
      expect(isAllowedFourD4yMyContentUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&page=1')).assertEqual(false);
      expect(isAllowedFourD4yMyContentUrl(
        'https://www.4d4y.com/forum/my.php?item=threads&page=1&action=delete')).assertEqual(false);
      expect(buildFourD4yMyContentUrl(FourD4yMyContentMode.Threads, 0) === null).assertEqual(true);
    });

    it('parses my threads with the current datatable and bounded pagination contract', 0, () => {
      const html: string = '<script>var discuz_uid = \'5595\';</script><table class="datatable">' +
        '<tr><th>主题</th><td>版块</td></tr><tr>' +
        '<th class="subject"><a href="viewthread.php?tid=101&amp;extra=page%3D1">我的主题 &amp; 测试</a></th>' +
        '<td class="forum"><a href="forumdisplay.php?fid=2">Discovery</a></td>' +
        '<td class="lastpost"><a>2026-08-23 12:00</a></td></tr></table>' +
        '<a href="my.php?item=threads&amp;page=999">正文外链接</a>' +
        '<div class="pages_btns"><div class="pages"><strong>2/4</strong>' +
        '<a href="my.php?item=threads&amp;page=3">下一页</a></div></div>';
      const payload = parseFourD4yNativeMyContentPage(html,
        'https://www.4d4y.com/forum/my.php?item=threads&page=2', 20);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yMyContentPagePayload(
        payload, FourD4yMyContentMode.Threads, 2, 20)).assertEqual(true);
      expect(payload.viewerUserId).assertEqual('5595');
      expect(payload.items.length).assertEqual(1);
      expect(payload.items[0].threadId).assertEqual('101');
      expect(payload.items[0].postId).assertEqual('');
      expect(payload.items[0].title).assertEqual('我的主题 & 测试');
      expect(payload.items[0].forumId).assertEqual('2');
      expect(payload.items[0].forumName).assertEqual('Discovery');
      expect(payload.items[0].lastReplyAt).assertEqual('2026-08-23 12:00');
      expect(payload.lastPage).assertEqual(4);
      expect(getFourD4yMyContentReaderOutcome(payload)).assertEqual(FourD4yMyContentReaderOutcome.Content);
    });

    it('pairs each my-reply title row only with its own following snippet', 0, () => {
      const html: string = '<div id="umenu"><a href="space.php?uid=5595">me</a></div>' +
        '<table class="datatable"><tr><th>主题</th></tr><tr>' +
        '<th><a href="viewthread.php?tid=202">第一条回复</a>' +
        '<a href="redirect.php?goto=findpost&amp;ptid=202&amp;pid=303">直达</a></th>' +
        '<td class="forum"><a href="forumdisplay.php?fid=51">La Femme</a></td>' +
        '<td class="lastpost">2026-08-23 13:00</td></tr>' +
        '<tr><th>这是 <b>第一条</b> 回复摘要</th></tr><tr>' +
        '<th><a href="redirect.php?goto=findpost&amp;ptid=204&amp;pid=305">第二条回复</a></th>' +
        '<td class="forum"><a href="forumdisplay.php?fid=2">Discovery</a></td></tr>' +
        '<tr><th>第二条摘要</th></tr></table>';
      const payload = parseFourD4yNativeMyContentPage(html,
        'https://www.4d4y.com/forum/my.php?item=posts&page=1', 21);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.items.length).assertEqual(2);
      expect(payload.items[0].threadId).assertEqual('202');
      expect(payload.items[0].postId).assertEqual('303');
      expect(payload.items[0].title).assertEqual('第一条回复');
      expect(payload.items[0].summary).assertEqual('这是 第一条 回复摘要');
      expect(payload.items[1].threadId).assertEqual('204');
      expect(payload.items[1].postId).assertEqual('305');
      expect(payload.items[1].summary).assertEqual('第二条摘要');
      expect(payload.viewerUserId).assertEqual('5595');
    });

    it('distinguishes an empty account list from a confirmed login page', 0, () => {
      const empty = parseFourD4yNativeMyContentPage(
        '<div id="umenu"><a href="space.php?uid=5595">me</a></div><table class="datatable"><tr><th>主题</th></tr></table>',
        'https://www.4d4y.com/forum/my.php?item=threads&page=1', 22);
      expect(empty === null).assertEqual(false);
      if (empty !== null) {
        expect(getFourD4yMyContentReaderOutcome(empty)).assertEqual(FourD4yMyContentReaderOutcome.Empty);
      }
      const login = parseFourD4yNativeMyContentPage(
        '<form id="loginform" action="logging.php?action=login"><input name="username">' +
        '<input name="password"></form>',
        'https://www.4d4y.com/forum/my.php?item=posts&page=1', 23);
      expect(login === null).assertEqual(false);
      if (login !== null) {
        expect(getFourD4yMyContentReaderOutcome(login))
          .assertEqual(FourD4yMyContentReaderOutcome.LoginRequired);
      }
    });

    it('mirrors sid into my.php but still rejects out-of-scope account actions', 0, () => {
      const url: string = 'https://www.4d4y.com/forum/my.php?item=posts&page=1';
      expect(appendFourD4ySessionId(url, 'cdb_auth=opaque; sid=my_sid')).assertEqual(url + '&sid=my_sid');
      expect(appendFourD4ySessionId(
        'https://www.4d4y.com/forum/memcp.php?action=profile', 'sid=my_sid'))
        .assertEqual('https://www.4d4y.com/forum/memcp.php?action=profile');
    });

    it('permits only the three read-only message listing endpoints', 0, () => {
      const privateUrl: string | null = buildFourD4yMessagePageUrl(FourD4yMessageMode.PrivateMessages, 2);
      const noticeUrl: string | null = buildFourD4yMessagePageUrl(FourD4yMessageMode.ThreadNotices, 3);
      const systemUrl: string | null = buildFourD4yMessagePageUrl(FourD4yMessageMode.SystemNotices, 4);
      expect(privateUrl).assertEqual('https://www.4d4y.com/forum/pm.php?filter=privatepm&page=2');
      expect(noticeUrl).assertEqual('https://www.4d4y.com/forum/notice.php?filter=threads&page=3');
      expect(systemUrl).assertEqual('https://www.4d4y.com/forum/notice.php?filter=systempm&page=4');
      expect(isAllowedFourD4yMessagePageUrl(privateUrl as string)).assertEqual(true);
      expect(isAllowedFourD4yMessagePageUrl(noticeUrl as string)).assertEqual(true);
      expect(isAllowedFourD4yMessagePageUrl(systemUrl as string)).assertEqual(true);
      expect(isAllowedFourD4yMessagePageUrl(
        'https://www.4d4y.com/forum/pm.php?action=view&pmid=123')).assertEqual(false);
      expect(isAllowedFourD4yMessagePageUrl(
        'https://www.4d4y.com/forum/notice.php?filter=threads&page=1&action=delete')).assertEqual(false);
    });

    it('parses value-only private-message and exact reply-notice targets', 0, () => {
      const privatePayload = parseFourD4yNativeMessagePage(
        '<div id="umenu"><a href="space.php?uid=5595">me</a></div><table><tr>' +
        '<td><a href="pm.php?action=view&pmid=76">hello from pm</a></td>' +
        '<td><a href="space.php?uid=123">Alice</a></td><td class="time">2026-08-24 09:01</td>' +
        '<td><img src="newpm.gif"></td></tr></table>',
        'https://www.4d4y.com/forum/pm.php?filter=privatepm&page=1', 31);
      expect(privatePayload === null).assertEqual(false);
      if (privatePayload !== null) {
        expect(isExpectedFourD4yMessagePagePayload(privatePayload,
          FourD4yMessageMode.PrivateMessages, 1, 31)).assertEqual(true);
        expect(privatePayload.items.length).assertEqual(1);
        expect(privatePayload.items[0].itemId).assertEqual('pm:76');
        expect(privatePayload.items[0].senderName).assertEqual('Alice');
        expect(privatePayload.items[0].isUnread).assertEqual(true);
      }
      const noticePayload = parseFourD4yNativeMessagePage(
        '<div id="umenu"><a href="space.php?uid=5595">me</a></div><ul class="feed"><li id="notice_77" class="new">' +
        '<div class="f_reply"><a href="space.php?uid=123">Bob</a> replied <a href="viewthread.php?tid=88">Topic title</a>' +
        '<a href="redirect.php?goto=findpost&ptid=88&pid=99">view</a><dl class="summary">reply preview</dl>' +
        '<em>2026-08-24 10:02</em></div></li></ul>',
        'https://www.4d4y.com/forum/notice.php?filter=threads&page=1', 32);
      expect(noticePayload === null).assertEqual(false);
      if (noticePayload !== null) {
        expect(getFourD4yMessageReaderOutcome(noticePayload)).assertEqual(FourD4yMessageReaderOutcome.Content);
        expect(noticePayload.items.length).assertEqual(1);
        expect(noticePayload.items[0].itemId).assertEqual('notice:77');
        expect(noticePayload.items[0].threadId).assertEqual('88');
        expect(noticePayload.items[0].postId).assertEqual('99');
        expect(noticePayload.items[0].title).assertEqual('Topic title');
      }
    });

    it('reads all prompt counters needed for the NG-style reminder aggregate', 0, () => {
      const prompt = parseFourD4yNativeMessagePrompt(
        '<div id="myprompt"><a id="prompt_pm">New Message (2)</a><a id="prompt_threads">Notice (3)</a>' +
        '<a id="prompt_systempm">System Notice (4)</a><a id="prompt_friend">Friend (5)</a></div>', 33);
      expect(prompt === null).assertEqual(false);
      if (prompt !== null) {
        expect(isExpectedFourD4yMessagePromptPayload(prompt, 33)).assertEqual(true);
        expect(prompt.privateMessageCount).assertEqual(2);
        expect(prompt.threadNoticeCount).assertEqual(3);
        expect(prompt.systemNoticeCount).assertEqual(4);
        expect(prompt.friendNoticeCount).assertEqual(5);
      }
    });

    it('keeps only validated server unread counters and gives private messages priority', 0, () => {
      const unread: FourD4yUnreadState = new FourD4yUnreadState();
      let notificationCount: number = 0;
      const listenerId: number = unread.subscribe(() => {
        notificationCount += 1;
      });
      unread.observeServerCounts(2, 3, 4, 5);
      expect(unread.hasSnapshot()).assertEqual(true);
      expect(unread.getPrivateMessageCount()).assertEqual(2);
      expect(unread.getInformationReminderCount()).assertEqual(12);
      expect(notificationCount).assertEqual(1);
      unread.observeServerCounts(2, 3, 4, 5);
      expect(notificationCount).assertEqual(1);
      unread.clear();
      expect(unread.hasSnapshot()).assertEqual(false);
      expect(unread.getPrivateMessageCount()).assertEqual(0);
      expect(unread.getInformationReminderCount()).assertEqual(0);
      expect(notificationCount).assertEqual(2);
      unread.unsubscribe(listenerId);
    });

    it('accepts the live pm_list and feed layouts without optional notice ids', 0, () => {
      const privatePayload = parseFourD4yNativeMessagePage(
        '<ul class="pm_list"><li id="pm_501" class="new"><p class="cite"><cite>' +
        '<a href="space.php?uid=123">Alice</a></cite> 2026-08-24 23:00 <img src="newpm.gif"></p>' +
        '<div class="summary">private preview</div></li></ul>',
        'https://www.4d4y.com/forum/pm.php?filter=privatepm&page=1', 34);
      expect(privatePayload === null).assertEqual(false);
      if (privatePayload !== null) {
        expect(privatePayload.items.length).assertEqual(1);
        expect(privatePayload.items[0].itemId).assertEqual('pm:501');
        expect(privatePayload.items[0].senderName).assertEqual('Alice');
        expect(privatePayload.items[0].summary).assertEqual('private preview');
      }
      const noticePayload = parseFourD4yNativeMessagePage(
        '<ul class="feed"><li class="s_clear"><div class="f_reply">' +
        '<a href="space.php?uid=123">Bob</a> replied <a href="redirect.php?goto=findpost&ptid=88&pid=99">Topic title</a>' +
        '<em>2026-08-24 23:01</em></div></li></ul>',
        'https://www.4d4y.com/forum/notice.php?filter=threads&page=1', 35);
      expect(noticePayload === null).assertEqual(false);
      if (noticePayload !== null) {
        expect(noticePayload.items.length).assertEqual(1);
        expect(noticePayload.items[0].itemId).assertEqual('notice:99');
        expect(noticePayload.items[0].threadId).assertEqual('88');
        expect(noticePayload.items[0].postId).assertEqual('99');
      }
    });

    it('opens only the NG and MY 4D4Y private-conversation route and parses its rows', 0, () => {
      const conversationUrl: string | null = buildFourD4yPrivateConversationUrl('123');
      expect(conversationUrl).assertEqual('https://www.4d4y.com/forum/pm.php?daterange=5&uid=123');
      expect(isAllowedFourD4yPrivateConversationUrl(conversationUrl as string)).assertEqual(true);
      expect(isAllowedFourD4yPrivateConversationUrl(
        'https://www.4d4y.com/forum/pm.php?action=send&uid=123')).assertEqual(false);
      expect(isAllowedFourD4yPrivateConversationUrl(
        'https://www.4d4y.com/forum/pm.php?daterange=1&uid=123')).assertEqual(false);
      const payload = parseFourD4yPrivateConversationPage(
        '<div id="umenu"><cite><a class="noborder" href="space.php?uid=5595">Me</a></cite></div>' +
        '<ul class="pm_list"><li id="pm_501" class="s_clear new"><a class="avatar" href="space.php?uid=123">' +
        '<img src="avatar.png"></a><p class="cite"><cite><a href="space.php?uid=123">Alice</a></cite> ' +
        '2026-08-24 23:00 <img src="newpm.gif"></p><div class="summary">hello<br>world</div></li>' +
        '<li id="pm_502" class="s_clear"><a class="avatar" href="space.php?uid=5595"><img src="me.png"></a>' +
        '<p class="cite"><cite><a href="space.php?uid=5595">Me</a></cite> 2026-08-24 23:01</p>' +
        '<div class="summary">reply</div></li>' +
        '<li id="pm_503" class="s_clear"><a class="avatar" href="space.php?uid=123"><img src="me.png"></a>' +
        '<p class="cite"><cite><a href="space.php?uid=123">Alice</a></cite> 2026-08-24 23:02</p>' +
        '<div class="summary"><img src="images/smilies/default/handshake.gif" alt=""></div></li></ul>',
        conversationUrl as string, 35);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yPrivateConversationPayload(payload, '123', 35)).assertEqual(true);
      expect(getFourD4yPrivateConversationReaderOutcome(payload))
        .assertEqual(FourD4yPrivateConversationReaderOutcome.Content);
      expect(payload.messages.length).assertEqual(3);
      expect(payload.messages[0].messageId).assertEqual('pm:501');
      expect(payload.messages[0].body).assertEqual('hello\nworld');
      expect(payload.messages[0].isUnread).assertEqual(true);
      expect(payload.messages[1].isMine).assertEqual(true);
      expect(buildFourD4yPrivateMessageCopyText(payload.messages[0])).assertEqual('hello\nworld');
      expect(buildFourD4yPrivateMessageCopyText(payload.messages[0]).indexOf('Alice')).assertEqual(-1);
      expect(payload.messages[2].body).assertEqual(':handshake:');
      expect(payload.messages[2].segments === undefined).assertEqual(false);
      if (payload.messages[2].segments !== undefined) {
        expect(payload.messages[2].segments.length).assertEqual(1);
        expect(payload.messages[2].segments[0].kind).assertEqual('emoji');
        expect(payload.messages[2].segments[0].url)
          .assertEqual('https://www.4d4y.com/forum/images/smilies/default/handshake.gif');
      }
    });

    it('requires the live NG and MY-style private-message form contract before a send', 0, () => {
      const formUrl = buildFourD4yPrivateMessagePreflightUrl('123', 36);
      expect(formUrl).assertEqual('https://www.4d4y.com/forum/pm.php?daterange=1&uid=123&oh_pm_compose=36');
      expect(buildFourD4yPrivateMessagePreflightUrl('invalid', 36) === null).assertEqual(true);
      const preflight = parseFourD4yPrivateMessagePreflightPayload(JSON.stringify({
        participantUserId: '123', loadSequence: 36, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, formFound: true, formMethod: 'post', actionKind: 'send',
        actionParticipantUserId: '123', messageFieldName: 'message', hasFormhashField: true,
        hasLastDateRangeField: true, errorMessage: ''
      }));
      expect(preflight === null).assertEqual(false);
      if (preflight === null) {
        return;
      }
      expect(isExpectedFourD4yPrivateMessagePreflight(preflight, '123', 36)).assertEqual(true);
      expect(isExpectedFourD4yPrivateMessagePreflight(preflight, '123', 35)).assertEqual(false);
      expect(isReadyFourD4yPrivateMessageForm(preflight, '123')).assertEqual(true);
      preflight.actionParticipantUserId = '124';
      expect(isReadyFourD4yPrivateMessageForm(preflight, '123')).assertEqual(false);
      const result = parseFourD4yPrivateMessageSubmissionPayload(JSON.stringify({
        participantUserId: '123', submissionSequence: 7, succeeded: true, loginRequired: false, errorMessage: ''
      }));
      expect(result === null).assertEqual(false);
      if (result !== null) {
        expect(isExpectedFourD4yPrivateMessageSubmission(result, '123', 7)).assertEqual(true);
        expect(isExpectedFourD4yPrivateMessageSubmission(result, '123', 8)).assertEqual(false);
      }
    });


    it('keeps local search history small, unique, and free of protocol values', 0, () => {
      const parsed = parseFourD4ySearchHistory('[{"keyword":"鸿蒙","mode":"title","forumId":"2"},' +
        '{"keyword":"鸿蒙","mode":"title","forumId":"2"},' +
        '{"keyword":"","mode":"author","forumId":"all"},' +
        '{"keyword":"tester","mode":"author","forumId":"all"}]');
      expect(parsed.length).assertEqual(2);
      const history = addFourD4ySearchHistoryEntry(parsed,
        { keyword: '鸿蒙', mode: FourD4ySearchMode.FullText, forumId: 'all' });
      expect(history.length).assertEqual(3);
      expect(history[0].mode).assertEqual(FourD4ySearchMode.FullText);
      expect(history[0].forumId).assertEqual('all');
    });

    it('estimates the 50-post mobile-page boundary from replies', 0, () => {
      expect(estimateLastPageFromReplyCount(0)).assertEqual(1);
      expect(estimateLastPageFromReplyCount(49)).assertEqual(1);
      expect(estimateLastPageFromReplyCount(50)).assertEqual(2);
      expect(estimateLastPageFromReplyCount(460)).assertEqual(10);
      expect(estimateLastPageFromReplyCount(-1)).assertEqual(1);
    });

    it('routes 4D4Y thread links to the native reader at their requested page', 0, () => {
      const route = resolveForumLink('https://www.4d4y.com/forum/viewthread.php?tid=2602293&page=10', 'link');
      expect(route.kind).assertEqual(ForumLinkKind.InternalThread);
      expect(route.threadId).assertEqual('2602293');
      expect(route.page).assertEqual(10);
    });

    it('routes a quoted-floor redirect to the matching native page and floor', 0, () => {
      const route = resolveForumLink(
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&ptid=3404320&pid=73218769',
        'link', '8#');
      expect(route.kind).assertEqual(ForumLinkKind.InternalThread);
      expect(route.threadId).assertEqual('3404320');
      expect(route.page).assertEqual(1);
      expect(route.floor).assertEqual(8);
    });

    it('does not invent a quote-floor target when the forum omits its floor label', 0, () => {
      const route = resolveForumLink(
        'https://www.4d4y.com/forum/redirect.php?goto=findpost&ptid=3404320&pid=73218769',
        'link', '引用内容');
      expect(route.kind).assertEqual(ForumLinkKind.InternalThread);
      expect(route.page).assertEqual(1);
      expect(route.floor).assertEqual(0);
    });

    it('preserves the mobile reply author before an original-post header', 0, () => {
      expect(select4D4yPostAuthor('hlalh313', 'zhuyi 发表于 2019-01-01', '')).assertEqual('hlalh313');
      expect(select4D4yPostAuthor('', 'zhuyi 发表于 2019-01-01', '')).assertEqual('zhuyi');
      expect(select4D4yPostAuthor('回复', 'zhuyi 发表于 2019-01-01', 'fallback')).assertEqual('zhuyi');
      expect(select4D4yPostAuthor('', '', 'noshare')).assertEqual('noshare');
    });

    it('hides only attachment menus proven to belong to inline images', 0, () => {
      expect(is4D4yInlineImageAttachment('t_attachlist attachimg', '', '')).assertEqual(true);
      expect(is4D4yInlineImageAttachment('t_attach', 'aimg_5993198_menu', 'aimg_5993198')).assertEqual(true);
      expect(is4D4yInlineImageAttachment('t_attach', 'aimg_5993198_menu', 'aimg_5993199')).assertEqual(false);
      expect(is4D4yInlineImageAttachment('t_attach', '', '')).assertEqual(false);
    });

    it('keeps legacy post nodes separate from 4D4Y rating and compose helpers', 0, () => {
      expect(is4D4yLegacyPostId('post_5627932')).assertEqual(true);
      expect(is4D4yLegacyPostId('post_rate_div_5627932')).assertEqual(false);
      expect(is4D4yLegacyPostId('post_new')).assertEqual(false);
    });

    it('recognizes the observed 4D4Y mobile pinned-title style only', 0, () => {
      expect(is4D4yPinnedMobileTitleStyle('font-weight: bold;color: #EE1B2E')).assertEqual(true);
      expect(is4D4yPinnedMobileTitleStyle('color:#ee1b2e; font-weight:bold')).assertEqual(true);
      expect(is4D4yPinnedMobileTitleStyle('font-weight:bold')).assertEqual(false);
      expect(is4D4yPinnedMobileTitleStyle('color:#EE1B2E')).assertEqual(false);
    });

    it('keeps NG-style external dispatch boundaries explicit', 0, () => {
      expect(resolveForumLink('https://www.4d4y.com/forum/attachment.php?aid=1', 'attachment').kind)
        .assertEqual(ForumLinkKind.Attachment);
      expect(resolveForumLink('https://www.bilibili.com/video/BV1xx', 'video').kind)
        .assertEqual(ForumLinkKind.ExternalWeb);
      expect(resolveForumLink('mailto:test@example.com', 'link').kind).assertEqual(ForumLinkKind.Email);
      expect(resolveForumLink('tel:10086', 'link').kind).assertEqual(ForumLinkKind.Phone);
      expect(resolveForumLink('weixin://dl/chat', 'link').kind).assertEqual(ForumLinkKind.Unsupported);
    });

    it('keeps a 4D4Y login page ahead of its coexisting Cloudflare marker', 0, () => {
      const rawResult: string = JSON.stringify({
        fid: '2', page: 1, nextPage: 0, loadSequence: 14, layout: 'unrecognized', threadLinkCount: 0,
        forumRowCount: 0, accessState: FourD4yPageAccessState.LoginRequired, hasChallenge: true,
        threadTypes: [], threads: []
      });
      const payload = parseForumWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(getForumReaderOutcome(payload)).assertEqual(FourD4yReaderOutcome.LoginRequired);
    });

    it('keeps content-bearing thread pages out of verification and layout-error branches', 0, () => {
      const rawResult: string = '{"threadId":"2602293","viewerUserId":"12345","title":"single post","currentPage":1,"lastPage":1,"loadSequence":20,"layout":"mobile-pid","postNodeCount":1,"accessState":"available","hasChallenge":false,"errorMessage":"","posts":[{"id":"53528033","threadId":"2602293","floor":1,"authorName":"author","content":[{"kind":"text","value":"body"}]}]}';
      const payload = parseThreadWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(getThreadReaderOutcome(payload)).assertEqual(FourD4yReaderOutcome.Content);
    });

    it('preserves structured reply and quote metadata without flattening it into body text', 0, () => {
      const rawResult: string = '{"threadId":"3460000","viewerUserId":"12345","title":"quote contract","currentPage":1,"lastPage":1,"loadSequence":22,"layout":"legacy-post","postNodeCount":1,"accessState":"available","hasChallenge":false,"errorMessage":"","posts":[{"id":"900032","threadId":"3460000","floor":32,"authorName":"reply-author","publishedAt":"今天 16:52","statusText":"本帖最后由 reply-author 于 今天 16:53 编辑","content":[{"kind":"quote","value":"quoted body","quoteAuthor":"source-author","quoteThreadId":"3460000","quotePostId":"900030","quoteFloor":30},{"kind":"text","value":"own body"}]}]}';
      const payload = parseThreadWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.posts[0].content[0].value).assertEqual('quoted body');
      expect(payload.posts[0].content[0].quoteAuthor).assertEqual('source-author');
      expect(payload.posts[0].content[0].quoteFloor).assertEqual(30);
      expect(payload.posts[0].statusText).assertEqual('本帖最后由 reply-author 于 今天 16:53 编辑');
    });

    it('rejects malformed structured quote navigation data', 0, () => {
      const rawResult: string = '{"threadId":"3460000","viewerUserId":"12345","title":"bad quote","currentPage":1,"lastPage":1,"loadSequence":23,"layout":"legacy-post","postNodeCount":1,"accessState":"available","hasChallenge":false,"errorMessage":"","posts":[{"id":"900033","threadId":"3460000","floor":33,"authorName":"author","content":[{"kind":"quote","value":"quoted body","quoteFloor":0}]}]}';
      expect(parseThreadWebPayload(rawResult) === null).assertEqual(true);
    });

    it('preserves a server denial message on a thread page with no posts', 0, () => {
      const rawResult: string = JSON.stringify({
        threadId: '2602294', viewerUserId: '12345', title: 'unavailable thread', currentPage: 1,
        lastPage: 1, loadSequence: 21, layout: 'unrecognized', postNodeCount: 0,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        errorMessage: '指定的主题不存在或已被删除、审核或移入回收站。', posts: []
      });
      const payload = parseThreadWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(getThreadReaderOutcome(payload)).assertEqual(FourD4yReaderOutcome.UnsupportedLayout);
      expect(payload.errorMessage.indexOf('回收站') >= 0).assertEqual(true);
    });

    it('keeps every 4D4Y scenario visible, including uncaptured ones', 0, () => {
      expect(FOUR_D4Y_READER_SCENARIOS.length > 0).assertEqual(true);
      const loginScenario = findFourD4yReaderScenario('forum-login-required');
      expect(loginScenario === null).assertEqual(false);
      if (loginScenario === null) {
        return;
      }
      expect(loginScenario.expectedOutcome).assertEqual(FourD4yReaderOutcome.LoginRequired);
      const fallbackScenario = findFourD4yReaderScenario('thread-postmessage-fallback');
      expect(fallbackScenario === null).assertEqual(false);
      if (fallbackScenario === null) {
        return;
      }
      expect(fallbackScenario.expectedOutcome).assertEqual(FourD4yReaderOutcome.Content);
      expect(getPendingFourD4yReaderScenarios().length).assertEqual(1);
    });

    it('covers every reader scenario with a bounded, value-free ArkWeb result fixture', 0, () => {
      expect(FOUR_D4Y_READER_FIXTURES.length).assertEqual(FOUR_D4Y_READER_SCENARIOS.length);
      expect(areFourD4yReaderFixturesValueFree()).assertEqual(true);
      FOUR_D4Y_READER_SCENARIOS.forEach((scenario) => {
        const fixture = findFourD4yReaderFixture(scenario.id);
        expect(fixture === null).assertEqual(false);
        if (fixture === null) {
          return;
        }
        expect(fixture.surface).assertEqual(scenario.surface);
        expect(fixture.expectedOutcome).assertEqual(scenario.expectedOutcome);
        if (fixture.surface === 'forum') {
          const payload = parseForumWebPayload(fixture.rawResult);
          expect(payload === null).assertEqual(false);
          if (payload !== null) {
            expect(getForumReaderOutcome(payload)).assertEqual(fixture.expectedOutcome);
          }
          return;
        }
        const payload = parseThreadWebPayload(fixture.rawResult);
        expect(payload === null).assertEqual(false);
        if (payload !== null) {
          expect(getThreadReaderOutcome(payload)).assertEqual(fixture.expectedOutcome);
        }
      });
      const mediaFixture = findFourD4yReaderFixture('thread-inline-image-and-attachment');
      expect(mediaFixture === null).assertEqual(false);
      if (mediaFixture !== null) {
        const mediaPayload = parseThreadWebPayload(mediaFixture.rawResult);
        expect(mediaPayload === null).assertEqual(false);
        if (mediaPayload !== null) {
          expect(mediaPayload.posts[0].content.length).assertEqual(5);
          expect(mediaPayload.posts[0].content[2].kind).assertEqual('attachment');
          expect(mediaPayload.posts[0].content[4].kind).assertEqual('video');
        }
      }
    });

    it('parses a double-encoded forum extraction result and checks its identity', 0, () => {
      const forumPayload: ForumWebPayload = {
        fid: '6',
        page: 1,
        nextPage: 2,
        loadSequence: 12,
        layout: 'mobile-listcon',
        threadLinkCount: 2,
        forumRowCount: 2,
        accessState: FourD4yPageAccessState.Available,
        hasChallenge: false,
        threadTypes: [
          { value: '1', label: '手机' },
          { value: '8', label: '其他好玩的' },
          // Observed in the live board menu and retained by MY4D4Y's
          // fid=6 category map; it must not be dropped as a navigation link.
          { value: '19', label: '站务' }
        ],
        threads: [{
          id: '2602293',
          title: 'test thread',
          authorName: 'user',
          replyCount: 460,
          viewCount: 2048,
          threadType: '手机',
          hasImage: true,
          createdAt: '2026-08-24',
          isPinned: false
        }]
      };
      const rawResult: string = JSON.stringify(JSON.stringify(forumPayload));
      const payload = parseForumWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedForumWebPayload(payload, '6', 1, 12)).assertEqual(true);
      expect(isExpectedForumWebPayload(payload, '6', 1, 11)).assertEqual(false);
      expect(isExpectedForumWebPayload(payload, '2', 1, 12)).assertEqual(false);
      expect(payload.nextPage).assertEqual(2);
      expect(payload.threadTypes[1].value).assertEqual('8');
      expect(payload.threadTypes[2].value).assertEqual('19');
    });

    it('rejects malformed forum extraction results', 0, () => {
      expect(parseForumWebPayload('{"fid":"6"}') === null).assertEqual(true);
      expect(parseForumWebPayload('not json') === null).assertEqual(true);
    });

    it('parses a thread result and rejects a stale page identity', 0, () => {
      const rawResult: string = JSON.stringify({
        threadId: '2602293', viewerUserId: '',
        title: 'test thread',
        currentPage: 10,
        lastPage: 10,
        loadSequence: 18,
        layout: 'mobile-pid',
        postNodeCount: 10,
        accessState: FourD4yPageAccessState.Available,
        hasChallenge: false,
        errorMessage: '',
        posts: []
      });
      const payload = parseThreadWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedThreadWebPayload(payload, '2602293', 10, 18)).assertEqual(true);
      expect(isExpectedThreadWebPayload(payload, '2602293', 1, 18)).assertEqual(false);
      expect(isExpectedThreadWebPayload(payload, '2602293', 10, 17)).assertEqual(false);
    });

    it('keeps reply preflight value-free and rejects a stale reply-form result', 0, () => {
      const rawResult: string = JSON.stringify({
        threadId: '2602293', loadSequence: 21, layout: 'reply-form',
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        formFound: true, formMethod: 'post', actionPath: '/forum/post.php?action=reply',
        messageFieldName: 'message', hasFormhashField: true, hasPosttimeField: true,
        hasWysiwygField: true, hasReplySubmitAction: true,
        submitControlName: 'replysubmit', errorMessage: ''
      });
      const payload = parseReplyPreflightPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedReplyPreflightPayload(payload, '2602293', 21)).assertEqual(true);
      expect(isExpectedReplyPreflightPayload(payload, '2602293', 20)).assertEqual(false);
      expect(parseReplyPreflightPayload('{"threadId":"2602293"}') === null).assertEqual(true);
    });

    it('accepts only a matching terminal reply-submission result', 0, () => {
      const payload = parseReplySubmissionPayload(JSON.stringify({
        threadId: '2602293', submissionSequence: 4, succeeded: true,
        loginRequired: false, errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedReplySubmissionPayload(payload, '2602293', 4)).assertEqual(true);
      expect(isExpectedReplySubmissionPayload(payload, '2602293', 3)).assertEqual(false);
      expect(parseReplySubmissionPayload('{"threadId":"2602293"}') === null).assertEqual(true);
    });

    it('requires an observed reply contract before enabling a quote submission', 0, () => {
      const route = createQuoteComposerRouteParams('2602293', '53528033', 8, 'author', 'topic');
      const payload = parseFourD4yComposerPreflightPayload(JSON.stringify({
        mode: ForumComposerMode.Quote, forumId: '', threadId: '2602293', postId: '53528033', viewerUserId: '12345',
        loadSequence: 28, layout: 'reply-form', accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, formFound: true, formMethod: 'post', actionKind: 'reply',
        hasSubmitAction: true, hasMatchingPostId: true, hasMatchingThreadId: true,
        subjectFieldName: '', messageFieldName: 'message',
        hasFormhashField: true, hasPosttimeField: true, hasWysiwygField: true, hasImageUploadHash: false,
        unusedImageAttachmentIds: ['6139860'],
        categoryFieldName: '', categoryValue: '', categoryOptions: [], tagsFieldName: '',
        initialSubject: '', initialMessage: '[quote]quoted[/quote]', errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yComposerPreflight(payload, route, 28)).assertEqual(true);
      expect(isReadyFourD4yComposerForm(payload, route)).assertEqual(true);
      expect(payload.unusedImageAttachmentIds[0]).assertEqual('6139860');
      expect(isExpectedFourD4yComposerPreflight(payload, route, 27)).assertEqual(false);
      payload.viewerUserId = 'not-a-user-id';
      expect(parseFourD4yComposerPreflightPayload(JSON.stringify(payload)) === null).assertEqual(true);
    });

    it('requires a subject and newthread action for a new topic form', 0, () => {
      const route = createNewThreadComposerRouteParams('2', 'Discovery', [{ value: '9', label: '聚会' }]);
      const categoryOptions: FourD4yComposerChoice[] = [
        { value: '0', label: '未分类' }, { value: '7', label: '应用' }
      ];
      const payload = parseFourD4yComposerPreflightPayload(JSON.stringify({
        mode: ForumComposerMode.NewThread, forumId: '2', threadId: '', postId: '', viewerUserId: '12345',
        loadSequence: 29, layout: 'new-thread-form', accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, formFound: true, formMethod: 'post', actionKind: 'newthread',
        hasSubmitAction: true, hasMatchingPostId: true, hasMatchingThreadId: true,
        subjectFieldName: 'subject', messageFieldName: 'message',
        hasFormhashField: true, hasPosttimeField: true, hasWysiwygField: true, hasImageUploadHash: false,
        unusedImageAttachmentIds: [],
        categoryFieldName: 'typeid', categoryValue: '7', categoryOptions: categoryOptions,
        tagsFieldName: 'tags',
        initialSubject: '', initialMessage: '', errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isReadyFourD4yComposerForm(payload, route)).assertEqual(true);
      expect(route.forumThreadTypes[0].value).assertEqual('9');
      payload.subjectFieldName = '';
      expect(isReadyFourD4yComposerForm(payload, route)).assertEqual(false);
    });

    it('requires exact tid and pid before enabling an edit submission', 0, () => {
      const route = createEditComposerRouteParams('2602293', '53528033', 'topic', '2');
      const categoryOptions: FourD4yComposerChoice[] = [{ value: '0', label: 'uncategorized' }];
      const payload = parseFourD4yComposerPreflightPayload(JSON.stringify({
        mode: ForumComposerMode.Edit, forumId: '2', threadId: '2602293', postId: '53528033', viewerUserId: '12345',
        loadSequence: 30, layout: 'edit-form', accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, formFound: true, formMethod: 'post', actionKind: 'edit',
        hasSubmitAction: true, hasMatchingPostId: true, hasMatchingThreadId: true,
        subjectFieldName: 'subject', messageFieldName: 'message',
        hasFormhashField: true, hasPosttimeField: true, hasWysiwygField: true, hasImageUploadHash: false,
        unusedImageAttachmentIds: [], categoryFieldName: 'typeid', categoryValue: '0',
        categoryOptions: categoryOptions, tagsFieldName: 'tags',
        initialSubject: 'topic', initialMessage: 'body', errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yComposerPreflight(payload, route, 30)).assertEqual(true);
      expect(isReadyFourD4yComposerForm(payload, route)).assertEqual(true);
      payload.hasMatchingPostId = false;
      expect(isReadyFourD4yComposerForm(payload, route)).assertEqual(false);
    });

    it('extracts unique inline image IDs from an edit draft only', 0, () => {
      const attachmentIds: string[] = extractFourD4yInlineImageAttachmentIds(
        'before [attachimg]6139860[/attachimg] after [attachimg]42[/attachimg] [attachimg]6139860[/attachimg]'
      );
      expect(attachmentIds.length).assertEqual(2);
      expect(attachmentIds[0]).assertEqual('6139860');
      expect(attachmentIds[1]).assertEqual('42');
      expect(extractFourD4yInlineImageAttachmentIds('[attachimg]not-an-id[/attachimg]').length).assertEqual(0);
    });

    it('does not accept a reply result for another mode or submission attempt', 0, () => {
      const route = createQuoteComposerRouteParams('2602293', '53528033', 8, 'author', 'topic');
      const payload = parseFourD4yComposerSubmissionPayload(JSON.stringify({
        mode: ForumComposerMode.Quote, threadId: '2602293', submissionSequence: 7,
        succeeded: true, createdThreadId: '', loginRequired: false, errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yComposerSubmission(payload, route, 7)).assertEqual(true);
      expect(isExpectedFourD4yComposerSubmission(payload, route, 8)).assertEqual(false);
      payload.mode = ForumComposerMode.Reply;
      expect(isExpectedFourD4yComposerSubmission(payload, route, 7)).assertEqual(false);
    });

    it('accepts only a value-free successful image-upload result', 0, () => {
      const payload = parseFourD4yImageUploadStatusPayload(JSON.stringify({
        uploadSequence: 5, phase: FourD4yImageUploadPhase.Succeeded,
        attachmentIds: ['123456'], errorCode: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(payload.uploadSequence).assertEqual(5);
      expect(payload.phase).assertEqual(FourD4yImageUploadPhase.Succeeded);
      expect(payload.attachmentIds[0]).assertEqual('123456');
      expect(parseFourD4yImageUploadStatusPayload(JSON.stringify({
        uploadSequence: 5, phase: FourD4yImageUploadPhase.Succeeded,
        attachmentIds: ['not-an-id'], errorCode: ''
      })) === null).assertEqual(true);
      expect(parseFourD4yImageUploadStatusPayload(JSON.stringify({
        uploadSequence: 5, phase: FourD4yImageUploadPhase.Succeeded,
        attachmentIds: ['123456', '789012'], errorCode: ''
      })) === null).assertEqual(true);
    });

    it('rejects incomplete thread extraction results', 0, () => {
      expect(parseThreadWebPayload('{"threadId":"2602293"}') === null).assertEqual(true);
    });

    it('accepts only a numeric signed-in user context from a thread page', 0, () => {
      const base: ThreadWebPayload = {
        threadId: '2602293', viewerUserId: '12345', title: 'test thread', currentPage: 1, lastPage: 1,
        loadSequence: 1, layout: 'mobile-pid', postNodeCount: 1,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false, errorMessage: '', posts: []
      };
      expect(parseThreadWebPayload(JSON.stringify(base)) === null).assertEqual(false);
      base.viewerUserId = 'not-a-user-id';
      expect(parseThreadWebPayload(JSON.stringify(base)) === null).assertEqual(true);
    });

    it('keeps post-deletion eligibility tied to one fresh edit form', 0, () => {
      const url: string | null = buildFourD4yPostDeletionPreflightUrl('2602293', '53528033', '51', 9);
      expect(url).assertEqual('https://www.4d4y.com/forum/post.php?action=edit&fid=51&tid=2602293&pid=53528033&page=1');
      expect(buildFourD4yPostDeletionPreflightUrl('bad', '53528033', '51', 9) === null).assertEqual(true);
      expect(isCurrentFourD4yPostDeletionPreflightRequest(url || '', '2602293', '53528033', '51')).assertEqual(true);
      expect(isCurrentFourD4yPostDeletionPreflightRequest(url || '', '2602293', '53528034', '51')).assertEqual(false);

      const payload = parseFourD4yPostDeletionPreflightPayload(JSON.stringify({
        threadId: '2602293', postId: '53528033', forumId: '51', page: 2, loadSequence: 9,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        formFound: true, formMethod: 'post', actionKind: 'edit',
        hasMatchingPostId: true, hasMatchingThreadId: true, hasFormhashField: true,
        hasEditSubmitAction: true, hasDeleteControl: true, errorMessage: ''
      }));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yPostDeletionPreflight(payload, '2602293', '53528033', '51', 2, 9)).assertEqual(true);
      expect(isExpectedFourD4yPostDeletionPreflight(payload, '2602293', '53528033', '51', 2, 8)).assertEqual(false);
      expect(isReadyFourD4yPostDeletionForm(payload)).assertEqual(true);
      payload.hasDeleteControl = false;
      expect(isReadyFourD4yPostDeletionForm(payload)).assertEqual(false);
      expect(parseFourD4yPostDeletionPreflightPayload('{"threadId":"2602293"}') === null).assertEqual(true);

      const started = parseFourD4yPostDeletionSubmissionStartPayload(JSON.stringify({
        threadId: '2602293', postId: '53528033', submissionSequence: 10,
        started: true, errorMessage: ''
      }));
      expect(started === null).assertEqual(false);
      if (started === null) {
        return;
      }
      expect(isExpectedFourD4yPostDeletionSubmissionStart(started, '2602293', '53528033', 10)).assertEqual(true);
      expect(isExpectedFourD4yPostDeletionSubmissionStart(started, '2602293', '53528033', 9)).assertEqual(false);

      const verification = parseFourD4yPostDeletionVerificationPayload(JSON.stringify({
        threadId: '2602293', postId: '53528033', submissionSequence: 10,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        isTargetThreadPage: true, isForumPage: false, postStillPresent: false, errorMessage: ''
      }));
      expect(verification === null).assertEqual(false);
      if (verification === null) {
        return;
      }
      expect(isExpectedFourD4yPostDeletionVerification(verification, '2602293', '53528033', 10)).assertEqual(true);
      expect(isConfirmedFourD4yPostDeletion(verification, false)).assertEqual(true);
      verification.isTargetThreadPage = false;
      verification.isForumPage = true;
      expect(isConfirmedFourD4yPostDeletion(verification, false)).assertEqual(false);
      expect(isConfirmedFourD4yPostDeletion(verification, true)).assertEqual(true);
    });

    it('keeps user-profile reads bound to one UID and one ArkWeb request', 0, () => {
      const route = createUserProfileRouteParams('456', '测试用户');
      expect(route.userId).assertEqual('456');
      expect(route.userName).assertEqual('测试用户');
      expect(createUserProfileRouteParams('bad', '测试用户').userId).assertEqual('');
      const url: string | null = buildFourD4yUserProfileUrl('456', 9);
      expect(url).assertEqual('https://www.4d4y.com/forum/space.php?uid=456&oh_profile=9');
      expect(buildFourD4yUserProfileUrl('bad', 9) === null).assertEqual(true);
      expect(isCurrentFourD4yUserProfileRequest(url || '', '456', 9)).assertEqual(true);
      expect(isCurrentFourD4yUserProfileRequest(url || '', '456', 8)).assertEqual(false);
      expect(isCurrentFourD4yUserProfileRequest(url || '', '457', 9)).assertEqual(false);

      const facts: FourD4yUserProfileFact[] = [{ label: '注册时间', value: '2006-01-01' }];
      const rawProfile: FourD4yUserProfilePayload = {
        requestedUserId: '456', loadSequence: 9, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, profileLayoutFound: true, userId: '456', userName: '测试用户',
        isOnline: true, facts: facts, errorMessage: ''
      };
      const payload = parseFourD4yUserProfilePayload(JSON.stringify(rawProfile));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yUserProfilePayload(payload, '456', 9)).assertEqual(true);
      expect(isExpectedFourD4yUserProfilePayload(payload, '456', 8)).assertEqual(false);
      expect(getFourD4yUserProfileReaderOutcome(payload)).assertEqual(FourD4yUserProfileReaderOutcome.Content);
      payload.userId = '457';
      expect(isExpectedFourD4yUserProfilePayload(payload, '456', 9)).assertEqual(false);
      expect(parseFourD4yUserProfilePayload('{"requestedUserId":"456"}') === null).assertEqual(true);
    });

    it('keeps the server blacklist identity and mutation acknowledgement value-free', 0, () => {
      const route = createBlacklistRouteParams('  测试用户  ');
      expect(route.suggestedUserName).assertEqual('测试用户');
      expect(isValidFourD4yBlacklistUserName('测试用户')).assertEqual(true);
      expect(isValidFourD4yBlacklistUserName('bad\nname')).assertEqual(false);
      const url: string | null = buildFourD4yBlacklistUrl(12);
      expect(url).assertEqual('https://www.4d4y.com/forum/pm.php?action=viewblack&oh_blacklist_load=12');
      expect(buildFourD4yBlacklistUrl(0) === null).assertEqual(true);
      expect(isCurrentFourD4yBlacklistRequest(url || '', 12)).assertEqual(true);
      expect(isCurrentFourD4yBlacklistRequest(url || '', 11)).assertEqual(false);
      expect(isCurrentFourD4yBlacklistRequest('https://www.4d4y.com/forum/pm.php?action=delblack&oh_blacklist_load=12', 12)).assertEqual(false);
      const entries: FourD4yBlacklistEntry[] = [{ userName: '测试用户' }];
      const rawPage: FourD4yBlacklistPagePayload = {
        loadSequence: 12, accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        blacklistLayoutFound: true, hasMutationToken: true, hasRemovalControl: true,
        errorMessage: '', entries: entries
      };
      const payload = parseFourD4yBlacklistPagePayload(JSON.stringify(rawPage));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yBlacklistPagePayload(payload, 12)).assertEqual(true);
      expect(getFourD4yBlacklistReaderOutcome(payload)).assertEqual(FourD4yBlacklistReaderOutcome.Content);
      const mutation = parseFourD4yBlacklistMutationStartPayload(JSON.stringify({
        userName: '测试用户', operationSequence: 4, started: true, errorMessage: ''
      }));
      expect(mutation === null).assertEqual(false);
      if (mutation === null) {
        return;
      }
      expect(isExpectedFourD4yBlacklistMutationStartPayload(mutation, '测试用户', 4)).assertEqual(true);
      const result = parseFourD4yBlacklistMutationResultPayload(JSON.stringify({
        operationSequence: 4, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, message: '服务器提示', errorMessage: '服务器拒绝'
      }));
      expect(result === null).assertEqual(false);
    });

    it('matches private-message body text in memory without retaining a conversation index', 0, () => {
      const messages: FourD4yPrivateConversationMessage[] = [
        { messageId: 'pm:1', senderUserId: '100', senderName: '用户甲', body: '第一条 Alpha 正文',
          occurredAt: '昨天', isMine: false, isUnread: false },
        { messageId: 'pm:2', senderUserId: '5595', senderName: '我', body: '这里有换行\n和 4D4Y 关键字',
          occurredAt: '今天', isMine: true, isUnread: false }
      ];
      expect(normalizeFourD4yPrivateMessageSearchQuery('  4d4y  ')).assertEqual('4d4y');
      const hits = findFourD4yPrivateMessageSearchHits('4D4Y', '100', '用户甲', messages);
      expect(hits.length).assertEqual(1);
      expect(hits[0].participantUserId).assertEqual('100');
      expect(hits[0].isMine).assertEqual(true);
      expect(hits[0].excerpt.indexOf('4D4Y') >= 0).assertEqual(true);
      expect(findFourD4yPrivateMessageSearchHits('正文', 'bad', '用户甲', messages).length).assertEqual(0);
      expect(buildFourD4yPrivateMessageSearchExcerpt('abcdef', 2, 2)).assertEqual('abcdef');
    });

    it('classifies PM-search request failures without retaining request data', 0, () => {
      const throttled = classifyFourD4yHttpFailure(429, true);
      expect(throttled.kind).assertEqual(FourD4yNativeRequestFailureKind.HttpStatus);
      expect(throttled.httpStatusCode).assertEqual(429);
      expect(throttled.networkErrorCode).assertEqual(0);
      expect(describeFourD4yNativeRequestFailure(throttled).indexOf('HTTP 429') >= 0).assertEqual(true);

      const timeout = classifyFourD4yNetworkFailure(2300028);
      expect(timeout.kind).assertEqual(FourD4yNativeRequestFailureKind.Timeout);
      expect(timeout.httpStatusCode).assertEqual(0);
      expect(timeout.networkErrorCode).assertEqual(2300028);
      expect(describeFourD4yNativeRequestFailure(timeout).indexOf('超时') >= 0).assertEqual(true);

      const responseBody = classifyFourD4yHttpFailure(200, false);
      expect(responseBody.kind).assertEqual(FourD4yNativeRequestFailureKind.ResponseBody);
      expect(describeFourD4yNativeRequestFailure(responseBody).indexOf('内容') >= 0).assertEqual(true);
    });

    it('keeps the multi-account registry value-free and bounds its session projection', 0, () => {
      const identity = parseFourD4yAccountIdentity(JSON.stringify(JSON.stringify({
        userId: '5595', displayName: '<测试用户>\n'
      })));
      expect(identity === null).assertEqual(false);
      if (identity === null) {
        return;
      }
      expect(identity.displayName).assertEqual('测试用户');
      const registry: FourD4yAccountRegistry | null = upsertFourD4yAccountProfile(
        createDefaultFourD4yAccountRegistry(), identity as FourD4yAccountIdentity, 1700000000000);
      expect(registry === null).assertEqual(false);
      if (registry === null) {
        return;
      }
      expect(registry.profiles.length).assertEqual(1);
      expect(registry.activeProfileId).assertEqual(registry.profiles[0].id);
      const serialized: string = serializeFourD4yAccountRegistry(registry);
      expect(serialized.indexOf('cdb_auth') < 0).assertEqual(true);
      expect(serialized.indexOf('password') < 0).assertEqual(true);
      expect(parseFourD4yAccountRegistry(serialized).profiles[0].userId).assertEqual('5595');
      const sessionSecret: string | null = FourD4ySession.createAccountSessionSecret(
        'cdb_auth=placeholder; cdb_uid=5595; unrelated=value');
      expect(sessionSecret === null).assertEqual(false);
      if (sessionSecret !== null) {
        expect(sessionSecret.indexOf('unrelated') < 0).assertEqual(true);
        expect(sessionSecret.indexOf('cdb_auth=') === 0).assertEqual(true);
      }
      expect(FourD4ySession.createAccountSessionSecret('cdb_uid=5595') === null).assertEqual(true);
    });

    it('keeps the image gallery bounded to supported visible image addresses', 0, () => {
      const route: ImageViewerRouteState = new ImageViewerRouteState();
      route.openGallery([
        { key: 'post-a-0', url: 'https://img02.4d4y.com/forum/a.jpg' },
        { key: 'post-a-1', url: 'javascript:alert(1)' },
        { key: '', url: 'https://img02.4d4y.com/forum/b.jpg' },
        { key: 'post-b-0', url: 'http://img02.4d4y.com/forum/c.jpg' }
      ], 9, '图片预览');
      expect(route.items.length).assertEqual(2);
      expect(route.items[0].key).assertEqual('post-a-0');
      expect(route.items[1].key).assertEqual('post-b-0');
      expect(route.initialIndex).assertEqual(1);
      route.openGallery([], 0, '空');
      expect(route.items.length).assertEqual(0);
      expect(route.initialIndex).assertEqual(0);
    });

    it('keeps local reading progress bounded, deduplicated, and free of web state', 0, () => {
      const first: FourD4yReadHistoryEntry = {
        threadId: '900001', title: '主题甲', forumId: '2', lastReadPage: 1, lastReadFloor: 1,
        visitedAt: 1700000000000
      };
      const updated: FourD4yReadHistoryEntry = {
        threadId: '900001', title: '主题甲', forumId: '2', lastReadPage: 2, lastReadFloor: 51,
        visitedAt: 1700000001000
      };
      const second: FourD4yReadHistoryEntry = {
        threadId: '900002', title: '主题乙', forumId: '', lastReadPage: 1, lastReadFloor: 1,
        visitedAt: 1700000002000
      };
      const entries = addFourD4yReadHistoryEntry(addFourD4yReadHistoryEntry([first], second), updated);
      expect(entries.length).assertEqual(2);
      expect(entries[0].threadId).assertEqual('900001');
      expect(entries[0].lastReadFloor).assertEqual(51);
      const serialized: string = serializeFourD4yReadHistory(entries);
      expect(serialized.indexOf('cookie') < 0).assertEqual(true);
      expect(serialized.indexOf('formhash') < 0).assertEqual(true);
      expect(serialized.indexOf('http') < 0).assertEqual(true);
      expect(parseFourD4yReadHistory(serialized).length).assertEqual(2);
      expect(parseFourD4yReadHistory('[{"threadId":"900003","title":"<html>","forumId":"2","lastReadPage":1,"lastReadFloor":1,"visitedAt":1700000000000}]').length).assertEqual(0);
    });

  });
}
