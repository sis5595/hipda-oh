import { ForumComposerMode, ForumComposerTarget } from '../../domain/composer/FourD4yComposerContracts';
import { ForumThreadType } from '../../domain/reader/FourD4yReaderContracts';

export { ForumComposerMode } from '../../domain/composer/FourD4yComposerContracts';

/**
 * Navigation-owned identity for every forum write surface.  Keeping this
 * state out of a singleton prevents a quote/new-thread form from inheriting
 * a previous destination's tid, pid, or fid.
 */
export interface ForumComposerRouteParams extends ForumComposerTarget {
  quotedFloor: number;
  quotedAuthorName: string;
  /** In-memory text handed off from the quick reply surface; never persisted. */
  initialDraft: string;
  threadTitle: string;
  forumName: string;
  /** Real-time board category mapping captured from the current forum page. */
  forumThreadTypes: ForumThreadType[];
}

/**
 * A successful reply is returned to the already-open thread destination.
 * This deliberately carries no post content or server token: its only job is
 * to let the caller refresh the topic after the server has confirmed success.
 */
export interface ForumComposerReplyPublishedResult {
  kind: 'replyPublished';
  threadId: string;
}

/** A confirmed edit tells the originating topic page which post to reread. */
export interface ForumComposerPostEditedResult {
  kind: 'postEdited';
  threadId: string;
  postId: string;
}

export function createForumComposerReplyPublishedResult(threadId: string): ForumComposerReplyPublishedResult {
  return {
    kind: 'replyPublished',
    threadId: threadId
  };
}

export function isForumComposerReplyPublishedResult(value: Object, expectedThreadId: string): boolean {
  const result: ForumComposerReplyPublishedResult = value as ForumComposerReplyPublishedResult;
  return result.kind === 'replyPublished' && result.threadId === expectedThreadId;
}

export function createForumComposerPostEditedResult(threadId: string, postId: string): ForumComposerPostEditedResult {
  return {
    kind: 'postEdited',
    threadId: threadId,
    postId: postId
  };
}

export function isForumComposerPostEditedResult(value: Object, expectedThreadId: string,
  expectedPostId: string): boolean {
  const result: ForumComposerPostEditedResult = value as ForumComposerPostEditedResult;
  return result.kind === 'postEdited' && result.threadId === expectedThreadId && result.postId === expectedPostId;
}

export function createReplyComposerRouteParams(threadId: string, threadTitle: string,
  forumId: string = '', initialDraft: string = ''): ForumComposerRouteParams {
  return {
    mode: ForumComposerMode.Reply,
    forumId: /^\d+$/.test(forumId) ? forumId : '',
    threadId: threadId,
    postId: '',
    quotedFloor: 0,
    quotedAuthorName: '',
    initialDraft: initialDraft,
    threadTitle: threadTitle,
    forumName: '',
    forumThreadTypes: []
  };
}

export function createQuoteComposerRouteParams(threadId: string, postId: string, quotedFloor: number,
  quotedAuthorName: string, threadTitle: string, forumId: string = '', initialDraft: string = ''): ForumComposerRouteParams {
  return {
    mode: ForumComposerMode.Quote,
    forumId: /^\d+$/.test(forumId) ? forumId : '',
    threadId: threadId,
    postId: postId,
    quotedFloor: Number.isFinite(quotedFloor) ? Math.max(0, Math.floor(quotedFloor)) : 0,
    quotedAuthorName: quotedAuthorName,
    initialDraft: initialDraft,
    threadTitle: threadTitle,
    forumName: '',
    forumThreadTypes: []
  };
}

export function createNewThreadComposerRouteParams(forumId: string, forumName: string,
  forumThreadTypes: ForumThreadType[] = []): ForumComposerRouteParams {
  const copiedThreadTypes: ForumThreadType[] = forumThreadTypes.map((threadType: ForumThreadType) => {
    const copiedThreadType: ForumThreadType = {
      value: threadType.value,
      label: threadType.label
    };
    return copiedThreadType;
  });
  return {
    mode: ForumComposerMode.NewThread,
    forumId: forumId,
    threadId: '',
    postId: '',
    quotedFloor: 0,
    quotedAuthorName: '',
    initialDraft: '',
    threadTitle: '',
    forumName: forumName,
    forumThreadTypes: copiedThreadTypes
  };
}

/**
 * No text or tokens travel with the route. The editor obtains its own fresh
 * same-session edit form after navigation and validates this tid/pid again.
 */
export function createEditComposerRouteParams(threadId: string, postId: string, threadTitle: string,
  forumId: string = ''): ForumComposerRouteParams {
  return {
    mode: ForumComposerMode.Edit,
    forumId: /^\d+$/.test(forumId) ? forumId : '',
    threadId: threadId,
    postId: postId,
    quotedFloor: 0,
    quotedAuthorName: '',
    initialDraft: '',
    threadTitle: threadTitle,
    forumName: '',
    forumThreadTypes: []
  };
}
