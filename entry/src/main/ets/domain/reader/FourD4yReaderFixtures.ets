import { ForumWebPayload, FourD4yPageAccessState, FourD4yReaderOutcome, ThreadWebPayload } from './FourD4yReaderContracts';

export enum FourD4yReaderFixtureOrigin {
  ObservedSanitized = 'observedSanitized',
  SyntheticNegative = 'syntheticNegative'
}

/**
 * A bounded projection of a page after the ArkWeb extraction script has run.
 *
 * These are deliberately not saved HTML fixtures. They contain neither forum
 * content nor login/session/form values: identifiers, text and URLs are
 * synthetic while the page shape is derived from a real, read-only observation.
 * DOM selectors stay covered by the corresponding Mate 60 smoke check.
 */
export interface FourD4yReaderFixture {
  scenarioId: string;
  surface: 'forum' | 'thread';
  origin: FourD4yReaderFixtureOrigin;
  rawResult: string;
  expectedOutcome: FourD4yReaderOutcome;
}

const available: FourD4yPageAccessState = FourD4yPageAccessState.Available;
const loginRequired: FourD4yPageAccessState = FourD4yPageAccessState.LoginRequired;

function forumFixture(scenarioId: string, origin: FourD4yReaderFixtureOrigin,
  expectedOutcome: FourD4yReaderOutcome, payload: ForumWebPayload): FourD4yReaderFixture {
  return {
    scenarioId: scenarioId,
    surface: 'forum',
    origin: origin,
    rawResult: JSON.stringify(payload),
    expectedOutcome: expectedOutcome
  };
}

function threadFixture(scenarioId: string, origin: FourD4yReaderFixtureOrigin,
  expectedOutcome: FourD4yReaderOutcome, payload: ThreadWebPayload): FourD4yReaderFixture {
  return {
    scenarioId: scenarioId,
    surface: 'thread',
    origin: origin,
    rawResult: JSON.stringify(payload),
    expectedOutcome: expectedOutcome
  };
}

/**
 * Coverage is one-to-one with FourD4yReaderScenarios. New scenarios must add
 * one bounded fixture before they can be marked verified.
 */
export const FOUR_D4Y_READER_FIXTURES: FourD4yReaderFixture[] = [
  forumFixture('forum-logged-in-mobile-list', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      fid: '2', page: 1, nextPage: 2, loadSequence: 101, layout: 'mobile-listcon',
      threadLinkCount: 2, forumRowCount: 2, accessState: available, hasChallenge: false,
      threadTypes: [{ value: '9', label: '分类甲' }],
      threads: [{ id: '900001', title: '样本主题甲', authorName: '作者甲', replyCount: 0, viewCount: 12,
        threadType: '', hasImage: false, createdAt: '', isPinned: false },
        { id: '900002', title: '样本主题乙', authorName: '作者乙', replyCount: 51, viewCount: 623,
          threadType: '分类甲', hasImage: true, createdAt: '2026-08-23', isPinned: false }]
    }),
  forumFixture('forum-login-required', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.LoginRequired, {
      fid: '56', page: 1, nextPage: 0, loadSequence: 102, layout: 'unrecognized',
      threadLinkCount: 0, forumRowCount: 0, accessState: loginRequired, hasChallenge: true,
      threadTypes: [], threads: []
    }),
  forumFixture('forum-pinned-row', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      fid: '2', page: 1, nextPage: 0, loadSequence: 103, layout: 'mobile-listcon',
      threadLinkCount: 1, forumRowCount: 1, accessState: available, hasChallenge: false,
      threadTypes: [],
      threads: [{ id: '900003', title: '置顶样本', authorName: '作者丙', replyCount: 3, viewCount: 88,
        threadType: '', hasImage: false, createdAt: '2026-08-22', isPinned: true }]
    }),
  forumFixture('forum-verification-only', FourD4yReaderFixtureOrigin.SyntheticNegative,
    FourD4yReaderOutcome.VerificationRequired, {
      fid: '2', page: 1, nextPage: 0, loadSequence: 104, layout: 'unrecognized',
      threadLinkCount: 0, forumRowCount: 0, accessState: available, hasChallenge: true,
      threadTypes: [], threads: []
    }),
  threadFixture('thread-no-reply', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900101', viewerUserId: '10001', title: '单层主题样本', currentPage: 1, lastPage: 1,
      loadSequence: 201, layout: 'mobile-pid', postNodeCount: 1, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910001', threadId: '900101', floor: 1, authorName: '作者甲',
        content: [{ kind: 'text', value: '脱敏正文' }] }]
    }),
  threadFixture('thread-multi-page', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900102', viewerUserId: '10001', title: '多页主题样本', currentPage: 2, lastPage: 3,
      loadSequence: 202, layout: 'legacy-post', postNodeCount: 50, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910051', threadId: '900102', floor: 51, authorName: '作者乙',
        content: [{ kind: 'text', value: '第二页首楼' }] }]
    }),
  threadFixture('thread-postmessage-fallback', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900107', viewerUserId: '10001', title: '正文根回退样本', currentPage: 1, lastPage: 4,
      loadSequence: 207, layout: 'postmessage-fallback', postNodeCount: 1, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910501', threadId: '900107', floor: 1, authorName: '作者甲',
        content: [{ kind: 'text', value: '由正文根读取的脱敏内容' }] }]
    }),
  threadFixture('thread-blocked-post', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900103', viewerUserId: '10001', title: '屏蔽楼层样本', currentPage: 1, lastPage: 1,
      loadSequence: 203, layout: 'legacy-post', postNodeCount: 2, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910101', threadId: '900103', floor: 1, authorName: '作者甲',
        content: [{ kind: 'text', value: '可见正文' }] },
        { id: '910102', threadId: '900103', floor: 2, authorName: '作者乙',
          content: [{ kind: 'text', value: '该内容已被屏蔽' }] }]
    }),
  threadFixture('thread-quote-floor-link', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900104', viewerUserId: '10001', title: '引用楼层样本', currentPage: 1, lastPage: 1,
      loadSequence: 204, layout: 'mobile-pid', postNodeCount: 2, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910201', threadId: '900104', floor: 8, authorName: '作者甲',
        content: [{ kind: 'text', value: '原楼层' }] },
        { id: '910202', threadId: '900104', floor: 9, authorName: '作者乙', content: [
          { kind: 'quote', value: '带可见楼层的引用' },
          { kind: 'quote', value: '无楼层标记的静态引用' },
          { kind: 'text', value: '回复文字' }
        ] }]
    }),
  threadFixture('thread-inline-image-and-attachment', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900105', viewerUserId: '10001', title: '媒体主题样本', currentPage: 1, lastPage: 1,
      loadSequence: 205, layout: 'legacy-post', postNodeCount: 1, accessState: available,
      hasChallenge: false, errorMessage: '',
      posts: [{ id: '910301', threadId: '900105', floor: 1, authorName: '作者甲', content: [
        { kind: 'emoji', value: '表情', url: 'https://www.4d4y.com/forum/images/smilies/sample.gif' },
        { kind: 'image', value: '图片', url: 'https://static.invalid/image.jpg' },
        { kind: 'attachment', value: 'sample.apk', url: 'https://www.4d4y.com/forum/attachment.php?aid=900' },
        { kind: 'link', value: '外部链接', url: 'https://example.invalid/page' },
        { kind: 'video', value: '视频引用', url: 'https://www.bilibili.com/video/BVsample' }
      ] }]
    }),
  threadFixture('thread-open-public-multi-poll', FourD4yReaderFixtureOrigin.ObservedSanitized,
    FourD4yReaderOutcome.Content, {
      threadId: '900106', viewerUserId: '10001', title: '公开多选投票样本', currentPage: 1, lastPage: 1,
      loadSequence: 206, layout: 'mobile-pid', postNodeCount: 1, accessState: available,
      hasChallenge: false, errorMessage: '',
      poll: { infoText: '最多可选 2 项', footerText: '', maxSelections: 2, isMultipleChoice: true,
        isVoteFormAvailable: true, options: [{ id: '1', label: '选项甲', resultText: '' },
          { id: '2', label: '选项乙', resultText: '' }] },
      posts: [{ id: '910401', threadId: '900106', floor: 1, authorName: '作者甲',
        content: [{ kind: 'text', value: '投票正文' }] }]
    })
];

export function findFourD4yReaderFixture(scenarioId: string): FourD4yReaderFixture | null {
  for (let index: number = 0; index < FOUR_D4Y_READER_FIXTURES.length; index += 1) {
    const fixture: FourD4yReaderFixture = FOUR_D4Y_READER_FIXTURES[index];
    if (fixture.scenarioId === scenarioId) {
      return fixture;
    }
  }
  return null;
}

/** Reject accidental additions of browser state, form fields, or HTML snapshots. */
export function areFourD4yReaderFixturesValueFree(): boolean {
  const prohibited: RegExp = /(?:cdb_|cookie|formhash|posttime|password|username|<\/?(?:html|body|form)\b)/i;
  for (let index: number = 0; index < FOUR_D4Y_READER_FIXTURES.length; index += 1) {
    const fixture: FourD4yReaderFixture = FOUR_D4Y_READER_FIXTURES[index];
    if (fixture.rawResult.length > 12000 || prohibited.test(fixture.rawResult)) {
      return false;
    }
  }
  return true;
}
