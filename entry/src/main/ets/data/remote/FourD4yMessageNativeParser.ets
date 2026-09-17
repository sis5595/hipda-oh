import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4yMessageItem, FourD4yMessageKind, FourD4yMessageMode, FourD4yMessagePagePayload,
  FourD4yMessagePromptPayload, isAllowedFourD4yMessagePageUrl,
  readFourD4yMessageMode } from '../../domain/notice/FourD4yMessageContracts';

/**
 * Pure parser for the legacy message pages.  The contracts below are the
 * common subset independently exercised by NG and current MY 4D4Y:
 * `pm.php?filter=privatepm`, `ul.feed li#notice_*`, and `#myprompt`.
 */
export function parseFourD4yNativeMessagePage(html: string, requestUrl: string,
  loadSequence: number): FourD4yMessagePagePayload | null {
  const mode: FourD4yMessageMode | null = readFourD4yMessageMode(requestUrl);
  if (html.length === 0 || mode === null || !isAllowedFourD4yMessagePageUrl(requestUrl) || loadSequence < 1) {
    return null;
  }
  const items: FourD4yMessageItem[] = mode === FourD4yMessageMode.PrivateMessages ?
    parsePrivateMessages(html) : parseNotices(html, mode);
  const accessState: FourD4yPageAccessState = items.length === 0 && isLoginPage(html) ?
    FourD4yPageAccessState.LoginRequired : FourD4yPageAccessState.Available;
  const page: number = readPageFromUrl(requestUrl);
  return {
    loadSequence: loadSequence,
    mode: mode,
    page: page,
    lastPage: parseLastPage(html, page),
    viewerUserId: extractViewerUserId(html),
    accessState: accessState,
    hasChallenge: /challenge-platform|cf-chl-|cf-turnstile/i.test(html),
    resultLayoutFound: hasMessageLayout(html, mode),
    errorMessage: extractPageMessage(html),
    items: items
  };
}

/** Parses only the server-owned counters inside the authenticated prompt menu. */
export function parseFourD4yNativeMessagePrompt(html: string,
  loadSequence: number): FourD4yMessagePromptPayload | null {
  if (html.length === 0 || loadSequence < 1) {
    return null;
  }
  const promptFound: boolean = /\bid=["']myprompt["']/i.test(html);
  const accessState: FourD4yPageAccessState = !promptFound && isLoginPage(html) ?
    FourD4yPageAccessState.LoginRequired : FourD4yPageAccessState.Available;
  return {
    loadSequence: loadSequence,
    privateMessageCount: readPromptCount(html, 'prompt_pm',
      '(?:私人消息|短消息|New Message)\\s*\\((\\d+)\\)'),
    threadNoticeCount: readPromptCount(html, 'prompt_threads',
      '(?:帖子消息|提醒|Notice)\\s*\\((\\d+)\\)'),
    systemNoticeCount: readPromptCount(html, 'prompt_systempm',
      '(?:系统消息|系统通知|System (?:Notice|Message))\\s*\\((\\d+)\\)'),
    // NG treats friend reminders as information reminders too. The current
    // 4D4Y templates vary this label, so constrain by the server-owned id and
    // capture its first explicit count rather than guessing text content.
    friendNoticeCount: readPromptCount(html, 'prompt_friend', '\\((\\d+)\\)'),
    accessState: accessState,
    hasChallenge: /challenge-platform|cf-chl-|cf-turnstile/i.test(html),
    promptFound: promptFound
  };
}

function parsePrivateMessages(html: string): FourD4yMessageItem[] {
  const items: FourD4yMessageItem[] = [];
  const seenIds: Set<string> = new Set<string>();
  // NG's active parser and MY 4D4Y's message-detail parser both retain this
  // current forum layout. It has no pm.php?action=view link per row: pmid is
  // carried by li#pm_<id>, while sender/time live in p.cite.
  const mobileListPattern: RegExp = /<ul\b[^>]*\bclass=["'][^"']*\bpm_list\b[^"']*["'][^>]*>[\s\S]*?<\/ul>/gi;
  let mobileListMatch: RegExpExecArray | null = mobileListPattern.exec(html);
  while (mobileListMatch !== null && items.length < 100) {
    const itemPattern: RegExp = /<li\b[^>]*>[\s\S]*?<\/li>/gi;
    let itemMatch: RegExpExecArray | null = itemPattern.exec(mobileListMatch[0]);
    while (itemMatch !== null && items.length < 100) {
      const pmId: string = extractElementId(itemMatch[0], 'pm');
      addUniqueItem(items, seenIds, parsePrivateMessageRow(itemMatch[0], pmId));
      itemMatch = itemPattern.exec(mobileListMatch[0]);
    }
    mobileListMatch = mobileListPattern.exec(html);
  }
  const tablePattern: RegExp = /<table\b[^>]*>([\s\S]*?)<\/table>/gi;
  let tableMatch: RegExpExecArray | null = tablePattern.exec(html);
  while (tableMatch !== null && items.length < 100) {
    const rowPattern: RegExp = /<tr\b[^>]*>[\s\S]*?<\/tr>/gi;
    let rowMatch: RegExpExecArray | null = rowPattern.exec(tableMatch[0]);
    while (rowMatch !== null && items.length < 100) {
      addUniqueItem(items, seenIds, parsePrivateMessageRow(rowMatch[0]));
      rowMatch = rowPattern.exec(tableMatch[0]);
    }
    tableMatch = tablePattern.exec(html);
  }
  // Some 4D4Y templates use the newer pmlist dl layout instead of table rows.
  const listPattern: RegExp = /<dl\b[^>]*\bid=["']pmlist_(\d+)["'][^>]*>[\s\S]*?<\/dl>/gi;
  let listMatch: RegExpExecArray | null = listPattern.exec(html);
  while (listMatch !== null && items.length < 100) {
    addUniqueItem(items, seenIds, parsePrivateMessageRow(listMatch[0], listMatch[1]));
    listMatch = listPattern.exec(html);
  }
  return items;
}

function parsePrivateMessageRow(rowHtml: string, knownId: string = ''): FourD4yMessageItem | null {
  // Keep the whole href query together. The legacy template puts action=view
  // before pmid, while the newer pmlist template can reverse that order.
  if (knownId.length === 0 && !/\bpm\.php\?[^"'\s>]*(?:action=view|pmid=\d+)/i.test(rowHtml)) {
    return null;
  }
  const pmId: string = knownId || extractParameterId(rowHtml, 'pmid') || extractElementId(rowHtml, 'pm');
  if (pmId.length === 0) {
    return null;
  }
  const sender: FourD4yMessageSender = extractMessageSender(rowHtml);
  const summary: string = extractPrivateSummary(rowHtml);
  return {
    itemId: 'pm:' + pmId,
    kind: FourD4yMessageKind.PrivateMessage,
    senderUserId: sender.userId,
    senderName: sender.name,
    title: sender.name.length > 0 ? sender.name : '系统消息',
    summary: summary.length > 0 ? summary : '短消息',
    occurredAt: extractTime(rowHtml),
    threadId: '',
    postId: '',
    isUnread: isUnread(rowHtml)
  };
}

function parseNotices(html: string, mode: FourD4yMessageMode): FourD4yMessageItem[] {
  const items: FourD4yMessageItem[] = [];
  const seenIds: Set<string> = new Set<string>();
  const feedPattern: RegExp = /<ul\b[^>]*\bclass=["'][^"']*\bfeed\b[^"']*["'][^>]*>[\s\S]*?<\/ul>/gi;
  let feedMatch: RegExpExecArray | null = feedPattern.exec(html);
  while (feedMatch !== null && items.length < 100) {
    const itemPattern: RegExp = /<li\b[^>]*>[\s\S]*?<\/li>/gi;
    let itemMatch: RegExpExecArray | null = itemPattern.exec(feedMatch[0]);
    while (itemMatch !== null && items.length < 100) {
      addUniqueItem(items, seenIds, parseNoticeItem(itemMatch[0], mode));
      itemMatch = itemPattern.exec(feedMatch[0]);
    }
    feedMatch = feedPattern.exec(html);
  }
  // Older system-notice pages use standalone notice dl elements.
  const noticePattern: RegExp = /<dl\b[^>]*\bid=["']notice_(\d+)["'][^>]*>[\s\S]*?<\/dl>/gi;
  let noticeMatch: RegExpExecArray | null = noticePattern.exec(html);
  while (noticeMatch !== null && items.length < 100) {
    addUniqueItem(items, seenIds, parseNoticeItem(noticeMatch[0], mode, noticeMatch[1]));
    noticeMatch = noticePattern.exec(html);
  }
  return items;
}

function parseNoticeItem(itemHtml: string, mode: FourD4yMessageMode,
  knownId: string = ''): FourD4yMessageItem | null {
  const target: FourD4yMessageTarget = extractThreadTarget(itemHtml);
  // Standard ul.feed rows are allowed to omit notice_<id>. NG accepts those
  // rows by their content. For a thread reminder the server PID is stable and
  // is therefore a safe deduplication key; do not fabricate a key otherwise.
  const noticeId: string = knownId || extractElementId(itemHtml, 'notice') || target.postId;
  if (noticeId.length === 0) {
    return null;
  }
  const kind: FourD4yMessageKind = readNoticeKind(itemHtml, mode);
  const sender: FourD4yMessageSender = extractMessageSender(itemHtml);
  const summary: string = extractNoticeSummary(itemHtml);
  const title: string = target.title.length > 0 ? target.title : buildNoticeTitle(kind, sender.name, summary);
  return {
    itemId: 'notice:' + noticeId,
    kind: kind,
    senderUserId: sender.userId,
    senderName: sender.name,
    title: title,
    summary: summary,
    occurredAt: extractTime(itemHtml),
    threadId: target.threadId,
    postId: target.postId,
    isUnread: isUnread(itemHtml)
  };
}

function addUniqueItem(items: FourD4yMessageItem[], seenIds: Set<string>,
  item: FourD4yMessageItem | null): void {
  if (item !== null && !seenIds.has(item.itemId)) {
    seenIds.add(item.itemId);
    items.push(item);
  }
}

interface FourD4yMessageSender {
  userId: string;
  name: string;
}

interface FourD4yMessageTarget {
  threadId: string;
  postId: string;
  title: string;
}

function extractMessageSender(value: string): FourD4yMessageSender {
  const pattern: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let match: RegExpExecArray | null = pattern.exec(value);
  while (match !== null) {
    const href: string = extractHref(match[1]);
    const uid: string = extractUserId(href);
    const name: string = toPlainText(match[2]).slice(0, 120);
    if (uid.length > 0 && name.length > 0) {
      return { userId: uid, name: name };
    }
    match = pattern.exec(value);
  }
  return { userId: '', name: '' };
}

function extractThreadTarget(value: string): FourD4yMessageTarget {
  const anchors: FourD4yMessageAnchor[] = extractAnchors(value);
  let threadId: string = '';
  let postId: string = '';
  let title: string = '';
  for (let index: number = 0; index < anchors.length; index += 1) {
    const anchor: FourD4yMessageAnchor = anchors[index];
    const currentThreadId: string = extractThreadId(anchor.href);
    const currentPostId: string = extractPostId(anchor.href);
    if (currentThreadId.length > 0 && threadId.length === 0) {
      threadId = currentThreadId;
    }
    if (currentPostId.length > 0 && postId.length === 0) {
      postId = currentPostId;
    }
    if (currentThreadId.length > 0 && title.length === 0 &&
      /(?:viewthread\.php|thread-|redirect\.php)/i.test(anchor.href) &&
      anchor.text.length > 0 && !/^(?:查看|view)$/i.test(anchor.text)) {
      title = anchor.text;
    }
  }
  if (threadId.length === 0) {
    threadId = extractThreadId(value);
  }
  if (postId.length === 0) {
    postId = extractPostId(value);
  }
  return { threadId: threadId, postId: postId, title: title };
}

interface FourD4yMessageAnchor {
  href: string;
  text: string;
}

function extractAnchors(value: string): FourD4yMessageAnchor[] {
  const anchors: FourD4yMessageAnchor[] = [];
  const pattern: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let match: RegExpExecArray | null = pattern.exec(value);
  while (match !== null && anchors.length < 40) {
    anchors.push({ href: extractHref(match[1]), text: toPlainText(match[2]).slice(0, 240) });
    match = pattern.exec(value);
  }
  return anchors;
}

function extractHref(attributes: string): string {
  const match: RegExpMatchArray | null = attributes.match(/\bhref=["']([^"']+)["']/i);
  return match === null ? '' : decodeHtml(match[1]);
}

function extractThreadId(value: string): string {
  const queryMatch: RegExpMatchArray | null = value.match(/[?&](?:tid|ptid)=(\d+)(?:&|$)/i);
  if (queryMatch !== null) {
    return queryMatch[1];
  }
  const legacyMatch: RegExpMatchArray | null = value.match(/thread-(\d+)(?:-|\.|$)/i);
  return legacyMatch === null ? '' : legacyMatch[1];
}

function extractPostId(value: string): string {
  const match: RegExpMatchArray | null = value.match(/[?&]pid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
}

function extractUserId(value: string): string {
  const match: RegExpMatchArray | null = value.match(/[?&]uid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
}

function extractParameterId(value: string, name: string): string {
  const match: RegExpMatchArray | null = value.match(
    new RegExp("(?:[?&]|&amp;)" + name + "=(\\d+)(?=(?:&|&amp;|[\"'\\s>]|$))", 'i'));
  return match === null ? '' : match[1];
}

function extractElementId(value: string, prefix: string): string {
  const match: RegExpMatchArray | null = value.match(new RegExp('\\bid=["\']' + prefix + '_(\\d+)["\']', 'i'));
  return match === null ? '' : match[1];
}

function extractPrivateSummary(value: string): string {
  const pmAnchor: RegExpMatchArray | null = value.match(
    /<a\b[^>]*\bhref=["'][^"']*pm\.php\?[^"']*\baction=view[^"']*["'][^>]*>([\s\S]*?)<\/a>/i);
  if (pmAnchor !== null) {
    return toPlainText(pmAnchor[1]).slice(0, 500);
  }
  return extractSummary(value);
}

function extractNoticeSummary(value: string): string {
  let summary: string = extractSummary(value);
  if (summary.length > 0) {
    return summary;
  }
  const content: RegExpMatchArray | null = value.match(
    /<(?:dd|div)\b[^>]*\bclass=["'][^"']*(?:ntc_body|content)[^"']*["'][^>]*>([\s\S]*?)<\/(?:dd|div)>/i);
  if (content !== null) {
    summary = toPlainText(content[1]).slice(0, 500);
  }
  return summary;
}

function extractSummary(value: string): string {
  const match: RegExpMatchArray | null = value.match(
    /<(?:dl|div)\b[^>]*\bclass=["'][^"']*\bsummary\b[^"']*["'][^>]*>([\s\S]*?)<\/(?:dl|div)>/i);
  if (match === null) {
    return '';
  }
  return toPlainText(match[1].replace(/<div\b[^>]*\bclass=["'][^"']*\bquote\b[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, ' '))
    .slice(0, 500);
}

function extractTime(value: string): string {
  const candidates: RegExp[] = [
    /<td\b[^>]*\bclass=["'][^"']*\btime\b[^"']*["'][^>]*>([\s\S]*?)<\/td>/i,
    /<span\b[^>]*\bclass=["'][^"']*\bxg1\b[^"']*["'][^>]*>([\s\S]*?)<\/span>/i,
    /<em\b[^>]*>([\s\S]*?)<\/em>/i
  ];
  for (let index: number = 0; index < candidates.length; index += 1) {
    const match: RegExpMatchArray | null = value.match(candidates[index]);
    if (match !== null) {
      const result: string = toPlainText(match[1]).slice(0, 80);
      if (result.length > 0) {
        return result;
      }
    }
  }
  const rawMatch: RegExpMatchArray | null = value.match(/\b\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}:\d{2}\b/);
  return rawMatch === null ? '' : rawMatch[0];
}

function readNoticeKind(value: string, mode: FourD4yMessageMode): FourD4yMessageKind {
  if (/\bf_thread\b/i.test(value)) {
    return FourD4yMessageKind.Thread;
  }
  if (/\bf_quote\b/i.test(value)) {
    return FourD4yMessageKind.Quote;
  }
  if (/\bf_reply\b/i.test(value)) {
    return FourD4yMessageKind.Reply;
  }
  if (mode === FourD4yMessageMode.SystemNotices || /\bf_manage\b|\bf_system\b/i.test(value)) {
    return FourD4yMessageKind.System;
  }
  return FourD4yMessageKind.Other;
}

function buildNoticeTitle(kind: FourD4yMessageKind, senderName: string, summary: string): string {
  if (summary.length > 0) {
    return summary.slice(0, 240);
  }
  if (kind === FourD4yMessageKind.Thread) {
    return senderName.length > 0 ? senderName + ' 回复了您关注的主题' : '主题提醒';
  }
  if (kind === FourD4yMessageKind.Quote) {
    return senderName.length > 0 ? senderName + ' 引用了您的回复' : '引用提醒';
  }
  if (kind === FourD4yMessageKind.Reply) {
    return senderName.length > 0 ? senderName + ' 回复了您的帖子' : '回复提醒';
  }
  return '系统通知';
}

function isUnread(value: string): boolean {
  return /(?:notice_)?newpm\.gif|\bclass=["'][^"']*\bnew\b[^"']*["']|font-weight\s*:\s*bold/i.test(value);
}

function hasMessageLayout(html: string, mode: FourD4yMessageMode): boolean {
  if (mode === FourD4yMessageMode.PrivateMessages) {
    return /<table\b[^>]*>|\bclass=["'][^"']*\bpm_list\b[^"']*["']|\bid=["']pmlist_\d+["']/i.test(html) ||
      hasEmptyListMessage(html);
  }
  return /<ul\b[^>]*\bclass=["'][^"']*\bfeed\b[^"']*["']|\bid=["']notice_\d+["']/i.test(html) ||
    hasEmptyListMessage(html);
}

function parseLastPage(html: string, currentPage: number): number {
  let lastPage: number = currentPage;
  const titlePattern: RegExp = /\btitle=["'][^"']*(?:共\s*)?(\d+)\s*(?:页|pages?)[^"']*["']/gi;
  let titleMatch: RegExpExecArray | null = titlePattern.exec(html);
  while (titleMatch !== null) {
    lastPage = Math.max(lastPage, Number.parseInt(titleMatch[1], 10));
    titleMatch = titlePattern.exec(html);
  }
  const pagesPattern: RegExp = /<div\b[^>]*\bclass=["'][^"']*\bpages\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi;
  let pagesMatch: RegExpExecArray | null = pagesPattern.exec(html);
  while (pagesMatch !== null) {
    const labels: RegExp = /<(?:a|strong)\b[^>]*>([\s\S]*?)<\/(?:a|strong)>/gi;
    let labelMatch: RegExpExecArray | null = labels.exec(pagesMatch[1]);
    while (labelMatch !== null) {
      const label: string = toPlainText(labelMatch[1]);
      const totalMatch: RegExpMatchArray | null = label.match(/^(\d+)\s*\/\s*(\d+)$/);
      if (totalMatch !== null) {
        lastPage = Math.max(lastPage, Number.parseInt(totalMatch[2], 10));
      } else if (/^\d+$/.test(label)) {
        lastPage = Math.max(lastPage, Number.parseInt(label, 10));
      }
      labelMatch = labels.exec(pagesMatch[1]);
    }
    pagesMatch = pagesPattern.exec(html);
  }
  return lastPage;
}

function readPromptCount(html: string, id: string, label: string): number {
  const pattern: RegExp = new RegExp('\\bid=["\']' + id + '["\'][^>]*>[\\s\\S]*?' + label, 'i');
  const match: RegExpMatchArray | null = html.match(pattern);
  if (match === null) {
    return 0;
  }
  const count: number = Number.parseInt(match[1], 10);
  return Number.isFinite(count) && count >= 0 ? count : 0;
}

function readPageFromUrl(url: string): number {
  const match: RegExpMatchArray | null = url.match(/[?&]page=(\d+)(?:&|$)/i);
  return match === null ? 1 : Math.max(1, Number.parseInt(match[1], 10));
}

function extractViewerUserId(html: string): string {
  const patterns: RegExp[] = [
    /discuz_uid\s*=\s*["']?(\d+)["']?/i,
    /\buid\s*=\s*(\d+)/i,
    /space\.php\?uid=(\d+)/i,
    /home\.php\?mod=space&(?:amp;)?uid=(\d+)/i
  ];
  for (let index: number = 0; index < patterns.length; index += 1) {
    const match: RegExpMatchArray | null = html.match(patterns[index]);
    if (match !== null) {
      return match[1];
    }
  }
  return '';
}

function isLoginPage(html: string): boolean {
  const userMenuMatch: RegExpMatchArray | null = html.match(
    /<(?:div|span)\b[^>]*\bid=["']umenu["'][^>]*>([\s\S]*?)<\/(?:div|span)>/i);
  if (userMenuMatch !== null && /(?:space\.php|mod=space)/i.test(userMenuMatch[1])) {
    return false;
  }
  const formPattern: RegExp = /<form\b([^>]*)>([\s\S]*?)<\/form>/gi;
  let formMatch: RegExpExecArray | null = formPattern.exec(html);
  while (formMatch !== null) {
    const identifiesLogin: boolean = /\b(?:id|name)=["']login(?:form)?["']/i.test(formMatch[1]) ||
      /\baction=["'][^"']*logging\.php[^"']*action=login/i.test(formMatch[1]);
    if (identifiesLogin && /<input\b[^>]*\bname=["']username["']/i.test(formMatch[2]) &&
      /<input\b[^>]*\bname=["']password["']/i.test(formMatch[2])) {
      return true;
    }
    formMatch = formPattern.exec(html);
  }
  return false;
}

function hasEmptyListMessage(html: string): boolean {
  return /(?:暂无|没有)(?:相关)?(?:消息|通知|短消息|记录)|no\s+(?:messages|notices|records)/i.test(toPlainText(html));
}

function extractPageMessage(html: string): string {
  const match: RegExpMatchArray | null = html.match(
    /<(?:div|p)\b[^>]*\bclass=["'][^"']*(?:alert|message|notice)[^"']*["'][^>]*>([\s\S]*?)<\/(?:div|p)>/i);
  return match === null ? '' : toPlainText(match[1]).slice(0, 240);
}

function toPlainText(value: string): string {
  return decodeHtml(value.replace(/<script\b[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();
}

function decodeHtml(value: string): string {
  return value.replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_match: string, digits: string) => {
      const codePoint: number = Number.parseInt(digits, 10);
      return Number.isFinite(codePoint) && codePoint > 0 && codePoint <= 65535 ? String.fromCharCode(codePoint) : '';
    });
}
