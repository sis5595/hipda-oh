import { describe, expect, it } from '@ohos/hypium';
import { estimateLastPageFromReplyCount, ForumLinkKind, ForumWebPayload, FourD4yPageAccessState, FourD4yReaderOutcome, getForumReaderOutcome, getThreadReaderOutcome, is4D4yInlineImageAttachment, is4D4yLegacyPostId, is4D4yPinnedMobileTitleStyle, isAllowedExtractedContentUrl, isCurrentFourD4yWebRequest, isExpectedForumNewThreadPreflightPayload, isExpectedForumWebPayload, isExpectedReplyPreflightPayload, isExpectedReplySubmissionPayload, isExpectedThreadWebPayload, isReadyForumNewThreadForm, parseForumNewThreadPreflightPayload, parseForumWebPayload, parseReplyPreflightPayload, parseReplySubmissionPayload, parseThreadWebPayload, resolveForumLink, select4D4yPostAuthor } from '../../../main/ets/domain/reader/FourD4yReaderContracts';
import { findFourD4yReaderScenario, FOUR_D4Y_READER_SCENARIOS, getPendingFourD4yReaderScenarios } from '../../../main/ets/domain/reader/FourD4yReaderScenarios';
import { areFourD4yReaderFixturesValueFree, findFourD4yReaderFixture,
  FOUR_D4Y_READER_FIXTURES } from '../../../main/ets/domain/reader/FourD4yReaderFixtures';
import { FourD4yComposerChoice, FourD4yImageUploadPhase, ForumComposerMode, isExpectedFourD4yComposerPreflight, isExpectedFourD4yComposerSubmission, isReadyFourD4yComposerForm, parseFourD4yComposerPreflightPayload, parseFourD4yComposerSubmissionPayload, parseFourD4yImageUploadStatusPayload } from '../../../main/ets/domain/composer/FourD4yComposerContracts';
import { createNewThreadComposerRouteParams, createQuoteComposerRouteParams } from '../../../main/ets/presentation/composer/ForumComposerRouteState';
import { createUserProfileRouteParams } from '../../../main/ets/presentation/profile/UserProfileRouteState';
import { FourD4ySession } from '../../../main/ets/data/remote/FourD4ySession';
import { ThreadWebPayload } from '../../../main/ets/domain/reader/FourD4yReaderContracts';
import { FOUR_D4Y_FORUM_GROUPS, FOUR_D4Y_QUICK_FORUM_IDS, getFourD4yForums } from '../../../main/ets/domain/catalog/FourD4yForumCatalog';
import { FourD4yFavoriteReaderOutcome, getFourD4yFavoriteReaderOutcome,
  isAllowedFourD4yFavoriteOperationUrl,
  isExpectedFourD4yFavoriteMutationStartPayload, isExpectedFourD4yFavoritePagePayload,
  isExpectedFourD4yFavoriteVerificationPayload,
  parseFourD4yFavoriteMutationStartPayload,
  parseFourD4yFavoritePagePayload, parseFourD4yFavoriteVerificationPayload } from '../../../main/ets/domain/favorite/FourD4yFavoriteContracts';
import { FourD4yFavoriteState } from '../../../main/ets/domain/favorite/FourD4yFavoriteState';
import { FourD4yAttentionReaderOutcome, getFourD4yAttentionReaderOutcome,
  buildFourD4yAttentionOperationUrl, isAllowedFourD4yAttentionOperationUrl, isExpectedFourD4yAttentionPagePayload,
  isExpectedFourD4yAttentionVerificationPayload, parseFourD4yAttentionPagePayload,
  parseFourD4yAttentionVerificationPayload } from '../../../main/ets/domain/attention/FourD4yAttentionContracts';
import { FourD4yAttentionState } from '../../../main/ets/domain/attention/FourD4yAttentionState';
import { FourD4ySearchMode, FourD4ySearchReaderOutcome, getFourD4ySearchReaderOutcome,
  isAllowedFourD4ySearchPageUrl, isExpectedFourD4ySearchFormPayload,
  isExpectedFourD4ySearchPagePayload, isFourD4ySearchModeSupported,
  parseFourD4ySearchFormPayload, parseFourD4ySearchPagePayload } from '../../../main/ets/domain/search/FourD4ySearchContracts';
import { addFourD4ySearchHistoryEntry, parseFourD4ySearchHistory } from '../../../main/ets/domain/search/FourD4ySearchHistory';
import { addFourD4yReadHistoryEntry, FourD4yReadHistoryEntry, parseFourD4yReadHistory,
  serializeFourD4yReadHistory } from '../../../main/ets/domain/history/FourD4yReadHistory';
import { buildFourD4ySearchRequestUrl, encodeFourD4yGbkQueryComponent } from '../../../main/ets/domain/search/FourD4ySearchRequest';
import { parseFourD4yNativeSearchPage } from '../../../main/ets/data/remote/FourD4ySearchNativeParser';
import { FourD4yMessageMode, FourD4yMessageReaderOutcome, buildFourD4yMessagePageUrl,
  getFourD4yMessageReaderOutcome, isAllowedFourD4yMessagePageUrl,
  isExpectedFourD4yMessagePagePayload, isExpectedFourD4yMessagePromptPayload } from
  '../../../main/ets/domain/notice/FourD4yMessageContracts';
import { parseFourD4yNativeMessagePage, parseFourD4yNativeMessagePrompt } from
  '../../../main/ets/data/remote/FourD4yMessageNativeParser';
import { FourD4yPrivateConversationReaderOutcome, buildFourD4yPrivateConversationUrl,
  getFourD4yPrivateConversationReaderOutcome, isAllowedFourD4yPrivateConversationUrl,
  isExpectedFourD4yPrivateConversationPayload } from
  '../../../main/ets/domain/notice/FourD4yPrivateConversationContracts';
import { parseFourD4yPrivateConversationPage } from
  '../../../main/ets/data/remote/FourD4yPrivateConversationNativeParser';
import { buildFourD4yPrivateMessagePreflightUrl, isExpectedFourD4yPrivateMessagePreflight,
  isExpectedFourD4yPrivateMessageSubmission, isReadyFourD4yPrivateMessageForm,
  parseFourD4yPrivateMessagePreflightPayload,
  parseFourD4yPrivateMessageSubmissionPayload } from
  '../../../main/ets/domain/notice/FourD4yPrivateMessageComposerContracts';
import { buildFourD4yUserProfileUrl, FourD4yUserProfileFact, FourD4yUserProfilePayload,
  FourD4yUserProfileReaderOutcome,
  getFourD4yUserProfileReaderOutcome, isCurrentFourD4yUserProfileRequest,
  isExpectedFourD4yUserProfilePayload, parseFourD4yUserProfilePayload } from
  '../../../main/ets/domain/profile/FourD4yUserProfileContracts';
import { buildFourD4yBlacklistUrl, FourD4yBlacklistMutationResultPayload,
  FourD4yBlacklistMutationStartPayload,
  FourD4yBlacklistPagePayload, FourD4yBlacklistReaderOutcome, getFourD4yBlacklistReaderOutcome,
  isCurrentFourD4yBlacklistRequest, isExpectedFourD4yBlacklistMutationResultPayload,
  isExpectedFourD4yBlacklistMutationStartPayload,
  isExpectedFourD4yBlacklistPagePayload, isValidFourD4yBlacklistUserName,
  parseFourD4yBlacklistMutationResultPayload, parseFourD4yBlacklistMutationStartPayload,
  parseFourD4yBlacklistPagePayload } from
  '../../../main/ets/domain/blacklist/FourD4yBlacklistContracts';
import { FourD4yBlacklistState } from '../../../main/ets/domain/blacklist/FourD4yBlacklistState';
import { createBlacklistRouteParams } from '../../../main/ets/presentation/blacklist/BlacklistRouteState';
import { isConfirmedFourD4yVoteResult, isExpectedFourD4yVotePreflightPayload,
  isExpectedFourD4yVoteSubmissionStartPayload, isExpectedFourD4yVoteVerificationPayload,
  isReadyFourD4yVoteForm, parseFourD4yVotePreflightPayload,
  parseFourD4yVoteSubmissionStartPayload, parseFourD4yVoteVerificationPayload } from
  '../../../main/ets/domain/poll/FourD4yPollContracts';
import { createFourD4yAttachmentFileName, isAllowedFourD4yAttachmentDownloadUrl } from
  '../../../main/ets/domain/attachment/FourD4yAttachmentContracts';

export default function abilityTest() {
  describe('FourD4yReaderContracts', () => {
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
        'https://www.4d4y.com/forum/my.php?item=favorites&tid=3422395', '3422395'
      )).assertEqual(true);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://www.4d4y.com/forum/my.php?item=favorites&tid=3422395', '3422394'
      )).assertEqual(false);
      expect(isAllowedFourD4yFavoriteOperationUrl(
        'https://example.com/forum/my.php?item=favorites&tid=3422395', '3422395'
      )).assertEqual(false);
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

    it('reads the three exact unread counters from the signed-in prompt', 0, () => {
      const prompt = parseFourD4yNativeMessagePrompt(
        '<div id="myprompt"><a id="prompt_pm">New Message (2)</a><a id="prompt_threads">Notice (3)</a>' +
        '<a id="prompt_systempm">System Notice (4)</a></div>', 33);
      expect(prompt === null).assertEqual(false);
      if (prompt !== null) {
        expect(isExpectedFourD4yMessagePromptPayload(prompt, 33)).assertEqual(true);
        expect(prompt.privateMessageCount).assertEqual(2);
        expect(prompt.threadNoticeCount).assertEqual(3);
        expect(prompt.systemNoticeCount).assertEqual(4);
      }
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
        'https://www.4d4y.com/forum/notice.php?filter=threads&page=1', 34);
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
        '<div class="summary">reply</div></li></ul>', conversationUrl as string, 35);
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yPrivateConversationPayload(payload, '123', 35)).assertEqual(true);
      expect(getFourD4yPrivateConversationReaderOutcome(payload))
        .assertEqual(FourD4yPrivateConversationReaderOutcome.Content);
      expect(payload.messages.length).assertEqual(2);
      expect(payload.messages[0].messageId).assertEqual('pm:501');
      expect(payload.messages[0].body).assertEqual('hello\nworld');
      expect(payload.messages[0].isUnread).assertEqual(true);
      expect(payload.messages[1].isMine).assertEqual(true);
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
        '"summary":"","forumName":"Discovery","authorName":"tester","replyCount":8,"lastReplyAt":"today"}]}');
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

    it('accepts a bounded value-only current-topic poll projection', 0, () => {
      const rawResult: string = '{"threadId":"3462417","viewerUserId":"12345","title":"poll","currentPage":1,"lastPage":1,"loadSequence":23,"layout":"legacy-post","postNodeCount":1,"accessState":"available","hasChallenge":false,"errorMessage":"","poll":{"infoText":"multiple choice, up to five options, results after voting","footerText":"","maxSelections":5,"isMultipleChoice":true,"isVoteFormAvailable":true,"options":[{"id":"1","label":"option one","resultText":""},{"id":"2","label":"option two","resultText":""}]},"posts":[{"id":"1","threadId":"3462417","floor":1,"authorName":"author","content":[]}]}';
      const payload = parseThreadWebPayload(rawResult);
      expect(payload === null).assertEqual(false);
      if (payload === null || payload.poll === undefined) {
        return;
      }
      expect(payload.poll.maxSelections).assertEqual(5);
      expect(payload.poll.isVoteFormAvailable).assertEqual(true);
    });

    it('rejects malformed poll option identities and unbounded selection limits', 0, () => {
      const rawResult: string = '{"threadId":"3462417","viewerUserId":"","title":"poll","currentPage":1,"lastPage":1,"loadSequence":23,"layout":"legacy-post","postNodeCount":1,"accessState":"available","hasChallenge":false,"errorMessage":"","poll":{"infoText":"poll","footerText":"","maxSelections":31,"isMultipleChoice":true,"isVoteFormAvailable":true,"options":[{"id":"unexpected-value","label":"option one","resultText":""},{"id":"2","label":"option two","resultText":""}]},"posts":[]}';
      expect(parseThreadWebPayload(rawResult) === null).assertEqual(true);
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
        fid: '6', page: 1, nextPage: 2, loadSequence: 12, layout: 'mobile-listcon',
        threadLinkCount: 2, forumRowCount: 2, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, threadTypes: [
          { value: '1', label: '手机' },
          { value: '19', label: '站务' }
        ], threads: []
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
    });

    it('rejects malformed forum extraction results', 0, () => {
      expect(parseForumWebPayload('{"fid":"6"}') === null).assertEqual(true);
      expect(parseForumWebPayload('not json') === null).assertEqual(true);
    });

    it('parses a thread result and rejects a stale page identity', 0, () => {
      const rawResult: string = JSON.stringify({
        threadId: '2602293', viewerUserId: '', title: 'test thread', currentPage: 10, lastPage: 10,
        loadSequence: 18, layout: 'mobile-pid', postNodeCount: 10,
        accessState: FourD4yPageAccessState.Available, hasChallenge: false, errorMessage: '',
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
        hasSubmitAction: true, subjectFieldName: '', messageFieldName: 'message',
        hasFormhashField: true, hasPosttimeField: true, hasWysiwygField: true, hasImageUploadHash: false,
        unusedImageAttachmentIds: ['6139860'],
        categoryFieldName: '', categoryValue: '', categoryOptions: [], tagsFieldName: '',
        initialMessage: '[quote]quoted[/quote]', errorMessage: ''
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
        hasSubmitAction: true, subjectFieldName: 'subject', messageFieldName: 'message',
        hasFormhashField: true, hasPosttimeField: true, hasWysiwygField: true, hasImageUploadHash: false,
        unusedImageAttachmentIds: [],
        categoryFieldName: 'typeid', categoryValue: '7', categoryOptions: categoryOptions,
        tagsFieldName: 'tags', initialMessage: '', errorMessage: ''
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

    it('does not accept a composer result for another mode or submission attempt', 0, () => {
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

      const rawPage: FourD4yBlacklistPagePayload = {
        loadSequence: 12, accessState: FourD4yPageAccessState.Available, hasChallenge: false,
        blacklistLayoutFound: true, hasMutationToken: true, hasRemovalControl: true,
        errorMessage: '', entries: [{ userName: '测试用户' }]
      };
      const payload = parseFourD4yBlacklistPagePayload(JSON.stringify(rawPage));
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yBlacklistPagePayload(payload, 12)).assertEqual(true);
      expect(getFourD4yBlacklistReaderOutcome(payload)).assertEqual(FourD4yBlacklistReaderOutcome.Content);
      payload.entries[0].userName = 'bad\nname';
      expect(parseFourD4yBlacklistPagePayload(JSON.stringify(payload)) === null).assertEqual(true);

      const rawMutation: FourD4yBlacklistMutationStartPayload = {
        userName: '测试用户', operationSequence: 4, started: true, errorMessage: ''
      };
      const mutation = parseFourD4yBlacklistMutationStartPayload(JSON.stringify(rawMutation));
      expect(mutation === null).assertEqual(false);
      if (mutation === null) {
        return;
      }
      expect(isExpectedFourD4yBlacklistMutationStartPayload(mutation, '测试用户', 4)).assertEqual(true);
      expect(isExpectedFourD4yBlacklistMutationStartPayload(mutation, '测试用户', 5)).assertEqual(false);
      const rawResult: FourD4yBlacklistMutationResultPayload = {
        operationSequence: 4, accessState: FourD4yPageAccessState.Available,
        hasChallenge: false, message: '服务器提示', errorMessage: '服务器拒绝'
      };
      const result = parseFourD4yBlacklistMutationResultPayload(JSON.stringify(rawResult));
      expect(result === null).assertEqual(false);
      if (result === null) {
        return;
      }
      expect(isExpectedFourD4yBlacklistMutationResultPayload(result, 4)).assertEqual(true);
      expect(isExpectedFourD4yBlacklistMutationResultPayload(result, 5)).assertEqual(false);
    });

    it('projects only a confirmed server blacklist into reader presentation state', 0, () => {
      const state: FourD4yBlacklistState = new FourD4yBlacklistState();
      let notificationCount: number = 0;
      const listenerId: number = state.subscribe(() => {
        notificationCount += 1;
      });
      expect(state.hasSnapshot()).assertEqual(false);
      expect(state.isBlacklisted('sample-user')).assertEqual(false);
      state.observeServerUserNames([' sample-user ', 'other-user', 'sample-user']);
      expect(state.hasSnapshot()).assertEqual(true);
      expect(state.isBlacklisted('sample-user')).assertEqual(true);
      expect(state.isBlacklisted(' other-user ')).assertEqual(true);
      expect(state.getUserNames().length).assertEqual(2);
      state.observeServerUserNames(['other-user']);
      expect(state.isBlacklisted('sample-user')).assertEqual(false);
      expect(state.isBlacklisted('other-user')).assertEqual(true);
      state.clearServerSnapshot();
      expect(state.hasSnapshot()).assertEqual(false);
      expect(state.isBlacklisted('other-user')).assertEqual(false);
      expect(notificationCount).assertEqual(3);
      state.unsubscribe(listenerId);
    });

    it('requires a fresh bounded poll form before a native choice can be submitted', 0, () => {
      const payload = parseFourD4yVotePreflightPayload(
        '{"threadId":"3462417","formSequence":7,"accessState":"available","hasChallenge":false,"formFound":true,"formMethod":"post","actionPath":"/forum/misc.php?action=votepoll&pollsubmit=yes","hasFormhashField":true,"hasPollSubmitAction":true,"maxSelections":5,"isMultipleChoice":true,"optionIds":["101","102","103","104","105"],"errorMessage":""}'
      );
      expect(payload === null).assertEqual(false);
      if (payload === null) {
        return;
      }
      expect(isExpectedFourD4yVotePreflightPayload(payload, '3462417', 7)).assertEqual(true);
      expect(isExpectedFourD4yVotePreflightPayload(payload, '3462417', 8)).assertEqual(false);
      expect(isReadyFourD4yVoteForm(payload, ['101', '104'])).assertEqual(true);
      expect(isReadyFourD4yVoteForm(payload, ['101', '101'])).assertEqual(false);
      expect(isReadyFourD4yVoteForm(payload, ['999'])).assertEqual(false);
      expect(isReadyFourD4yVoteForm(payload, ['101', '102', '103', '104', '105', '106'])).assertEqual(false);
      expect(parseFourD4yVotePreflightPayload(
        '{"threadId":"3462417","formSequence":7,"accessState":"available","hasChallenge":false,"formFound":true,"formMethod":"post","actionPath":"/forum/misc.php?action=votepoll&pollsubmit=yes","hasFormhashField":true,"hasPollSubmitAction":true,"maxSelections":5,"isMultipleChoice":true,"optionIds":["101","101"],"errorMessage":""}'
      ) === null).assertEqual(true);
    });

    it('accepts only a correlated server-rendered poll result as success', 0, () => {
      const start = parseFourD4yVoteSubmissionStartPayload(
        '{"threadId":"3462417","submissionSequence":9,"started":true,"errorMessage":""}'
      );
      expect(start === null).assertEqual(false);
      if (start === null) {
        return;
      }
      expect(isExpectedFourD4yVoteSubmissionStartPayload(start, '3462417', 9)).assertEqual(true);
      expect(isExpectedFourD4yVoteSubmissionStartPayload(start, '3462417', 8)).assertEqual(false);

      const result = parseFourD4yVoteVerificationPayload(
        '{"threadId":"3462417","submissionSequence":9,"accessState":"available","hasChallenge":false,"pollFound":true,"voteFormAvailable":false,"resultRowCount":5,"errorMessage":""}'
      );
      expect(result === null).assertEqual(false);
      if (result === null) {
        return;
      }
      expect(isExpectedFourD4yVoteVerificationPayload(result, '3462417', 9)).assertEqual(true);
      expect(isConfirmedFourD4yVoteResult(result)).assertEqual(true);
      result.voteFormAvailable = true;
      expect(isConfirmedFourD4yVoteResult(result)).assertEqual(false);
      expect(parseFourD4yVoteVerificationPayload(
        '{"threadId":"3462417","submissionSequence":9,"accessState":"available","hasChallenge":false,"pollFound":true,"voteFormAvailable":false,"resultRowCount":31,"errorMessage":""}'
      ) === null).assertEqual(true);
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
