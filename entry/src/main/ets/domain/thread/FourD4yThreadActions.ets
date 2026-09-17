import { ThreadPost } from '../model/ForumModels';

const FOUR_D4Y_THREAD_ROOT: string = 'https://www.4d4y.com/forum/viewthread.php?tid=';

export function normalizeFourD4yThreadActionId(value: string): string {
  return /^\d{1,20}$/.test(value) ? value : '';
}

/** Canonical user-facing topic URL. Page 1 intentionally has no page query. */
export function buildFourD4yThreadPublicUrl(threadId: string, page: number = 1): string {
  const normalizedThreadId: string = normalizeFourD4yThreadActionId(threadId);
  if (normalizedThreadId.length === 0) {
    return '';
  }
  const normalizedPage: number = Number.isInteger(page) && page > 1 ? page : 1;
  return FOUR_D4Y_THREAD_ROOT + normalizedThreadId +
    (normalizedPage > 1 ? '&page=' + normalizedPage : '');
}

/** Internal reader URL, including only validated numeric request identity. */
export function buildFourD4yThreadReaderUrl(threadId: string, page: number, loadSequence: number,
  authorUserId: string = ''): string {
  const normalizedThreadId: string = normalizeFourD4yThreadActionId(threadId);
  if (normalizedThreadId.length === 0 || !Number.isInteger(page) || page < 1 ||
    !Number.isInteger(loadSequence) || loadSequence < 1) {
    return '';
  }
  const normalizedAuthorUserId: string = normalizeFourD4yThreadActionId(authorUserId);
  return FOUR_D4Y_THREAD_ROOT + normalizedThreadId + '&page=' + page +
    (normalizedAuthorUserId.length > 0 ? '&authorid=' + normalizedAuthorUserId : '') +
    '&oh_load=' + loadSequence;
}

/** Matches NG's useful share payload without copying any post body. */
export function buildFourD4yThreadShareText(title: string, authorName: string, threadId: string): string {
  const url: string = buildFourD4yThreadPublicUrl(threadId);
  if (url.length === 0) {
    return '';
  }
  const normalizedTitle: string = title.trim().length > 0 ? title.trim().slice(0, 320) : '4D4Y 主题';
  const normalizedAuthorName: string = authorName.trim().slice(0, 120);
  const lines: string[] = ['主题：' + normalizedTitle];
  if (normalizedAuthorName.length > 0) {
    lines.push('作者：' + normalizedAuthorName);
  }
  lines.push(url);
  return lines.join('\n');
}

/**
 * A floor-level copy projection follows NG rather than the visual ArkUI tree:
 * text, quoted text, and image addresses remain useful when pasted elsewhere;
 * decorative emoji, external links, videos, and downloadable attachments do
 * not become accidental copy payload.
 */
export function buildFourD4yPostCopyText(post: ThreadPost): string {
  const parts: string[] = [];
  post.content.forEach((content) => {
    if (content.kind === 'text') {
      parts.push(content.value);
      return;
    }
    if (content.kind === 'quote') {
      parts.push('『' + content.value + '』');
      return;
    }
    if (content.kind === 'image' && content.url !== undefined && content.url.length > 0) {
      parts.push('[图片:' + content.url + ']');
    }
  });
  return parts.join('').trim();
}

/** A reply uses Discuz's stable redirect endpoint so the shared link targets that floor. */
export function buildFourD4yPostPublicUrl(threadId: string, postId: string, floor: number): string {
  const normalizedThreadId: string = normalizeFourD4yThreadActionId(threadId);
  if (normalizedThreadId.length === 0 || !Number.isInteger(floor) || floor < 1) {
    return '';
  }
  if (floor === 1) {
    return buildFourD4yThreadPublicUrl(normalizedThreadId);
  }
  const normalizedPostId: string = normalizeFourD4yThreadActionId(postId);
  if (normalizedPostId.length === 0) {
    return '';
  }
  return 'https://www.4d4y.com/forum/redirect.php?goto=findpost&pid=' + normalizedPostId +
    '&ptid=' + normalizedThreadId;
}

/** Matches NG's floor sharing semantics, including the quoted/copyable body projection. */
export function buildFourD4yPostShareText(title: string, threadId: string, post: ThreadPost): string {
  const url: string = buildFourD4yPostPublicUrl(threadId, post.id, post.floor);
  if (url.length === 0) {
    return '';
  }
  const normalizedTitle: string = title.trim().length > 0 ? title.trim().slice(0, 320) : '4D4Y 主题';
  const normalizedAuthorName: string = post.authorName.trim().slice(0, 120);
  const lines: string[] = [
    (post.floor === 1 ? '主题 ：' : '回帖 ：') + normalizedTitle,
    post.floor + '#  作者 ：' + normalizedAuthorName,
    url
  ];
  const copyText: string = buildFourD4yPostCopyText(post);
  return lines.join('\n') + '\n\n' + copyText;
}

/** Appends a server page without repeating a boundary post after template redirects. */
export function appendFourD4yThreadPosts(currentPosts: ThreadPost[], nextPosts: ThreadPost[]): ThreadPost[] {
  const mergedPosts: ThreadPost[] = [...currentPosts];
  const knownPostIds: Set<string> = new Set(currentPosts.map((post: ThreadPost) => post.id));
  nextPosts.forEach((post: ThreadPost) => {
    if (!knownPostIds.has(post.id)) {
      knownPostIds.add(post.id);
      mergedPosts.push(post);
    }
  });
  return mergedPosts;
}
