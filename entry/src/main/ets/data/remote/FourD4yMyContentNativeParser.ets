import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { extractFourD4yViewerUserId } from './FourD4yViewerIdentityParser';
import { FourD4yMyContentItem, FourD4yMyContentMode, FourD4yMyContentPagePayload,
  isAllowedFourD4yMyContentUrl, readFourD4yMyContentMode } from '../../domain/mine/FourD4yMyContentContracts';

/**
 * Pure parser for the legacy `table.datatable` contract still used by 4D4Y.
 * NG and current MY 4D4Y independently use this structure: one row per
 * thread, and a title row followed by a reply-snippet row for my posts.
 */
export function parseFourD4yNativeMyContentPage(html: string, requestUrl: string,
  loadSequence: number): FourD4yMyContentPagePayload | null {
  const mode: FourD4yMyContentMode | null = readFourD4yMyContentMode(requestUrl);
  if (html.length === 0 || mode === null || !isAllowedFourD4yMyContentUrl(requestUrl) || loadSequence < 1) {
    return null;
  }
  const tableMatch: RegExpMatchArray | null = html.match(
    /<table\b[^>]*\bclass=["'][^"']*\bdatatable\b[^"']*["'][^>]*>([\s\S]*?)<\/table>/i);
  const items: FourD4yMyContentItem[] = tableMatch === null ? [] :
    parseMyContentRows(tableMatch[1], mode);
  // As in NG's LoginHelper, a signed-in #umenu wins over stray login inputs.
  // A valid result row also proves that this response is not the login form.
  const accessState: FourD4yPageAccessState = items.length === 0 && isLoginPage(html) ?
    FourD4yPageAccessState.LoginRequired : FourD4yPageAccessState.Available;
  const page: number = readPageFromUrl(requestUrl);
  return {
    loadSequence: loadSequence,
    mode: mode,
    page: page,
    lastPage: parseLastPage(html, page),
    viewerUserId: extractFourD4yViewerUserId(html),
    accessState: accessState,
    hasChallenge: /challenge-platform|cf-chl-|cf-turnstile/i.test(html),
    resultLayoutFound: tableMatch !== null || hasEmptyListMessage(html),
    errorMessage: extractPageMessage(html),
    items: items
  };
}

function parseMyContentRows(tableHtml: string, mode: FourD4yMyContentMode): FourD4yMyContentItem[] {
  const rows: string[] = [];
  const rowPattern: RegExp = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowMatch: RegExpExecArray | null = rowPattern.exec(tableHtml);
  while (rowMatch !== null && rows.length < 202) {
    rows.push(rowMatch[1]);
    rowMatch = rowPattern.exec(tableHtml);
  }
  const items: FourD4yMyContentItem[] = [];
  const seenTargets: Set<string> = new Set<string>();
  for (let index: number = 0; index < rows.length && items.length < 100; index += 1) {
    const item: FourD4yMyContentItem | null = parseTitleRow(rows[index], mode);
    if (item === null) {
      continue;
    }
    if (mode === FourD4yMyContentMode.Replies && index + 1 < rows.length &&
      parseTitleRow(rows[index + 1], mode) === null) {
      item.summary = toPlainText(rows[index + 1]).slice(0, 500);
      index += 1;
    }
    const target: string = item.postId.length > 0 ? 'post:' + item.postId : 'thread:' + item.threadId;
    if (!seenTargets.has(target)) {
      seenTargets.add(target);
      items.push(item);
    }
  }
  return items;
}

function parseTitleRow(rowHtml: string, mode: FourD4yMyContentMode): FourD4yMyContentItem | null {
  const subjectMatch: RegExpMatchArray | null = rowHtml.match(/<th\b[^>]*>([\s\S]*?)<\/th>/i);
  if (subjectMatch === null) {
    return null;
  }
  // A my-reply row can contain both an ordinary viewthread title link and
  // the precise redirect(ptid,pid) target. Current MY 4D4Y deliberately
  // gives the redirect target priority; taking the first anchor loses pid
  // and incorrectly opens floor 1.
  if (mode === FourD4yMyContentMode.Replies) {
    const preciseReply: FourD4yMyContentItem | null = parseReplyTitleAnchor(rowHtml, subjectMatch[1], true);
    if (preciseReply !== null) {
      return preciseReply;
    }
    return parseReplyTitleAnchor(rowHtml, subjectMatch[1], false);
  }
  const anchorPattern: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let anchorMatch: RegExpExecArray | null = anchorPattern.exec(subjectMatch[1]);
  while (anchorMatch !== null) {
    const hrefMatch: RegExpMatchArray | null = anchorMatch[1].match(/\bhref=["']([^"']+)["']/i);
    const href: string = hrefMatch === null ? '' : decodeHtml(hrefMatch[1]);
    const title: string = toPlainText(anchorMatch[2]).slice(0, 240);
    const threadId: string = extractThreadId(href);
    if (title.length > 0 && /(?:viewthread\.php\?|thread-)/i.test(href) && threadId.length > 0) {
      return {
        threadId: threadId,
        postId: '',
        forumId: extractForumId(rowHtml),
        title: title,
        summary: '',
        forumName: extractCellText(rowHtml, 'forum'),
        lastReplyAt: extractCellText(rowHtml, 'lastpost')
      };
    }
    anchorMatch = anchorPattern.exec(subjectMatch[1]);
  }
  return null;
}

function parseReplyTitleAnchor(rowHtml: string, subjectHtml: string,
  requirePrecisePost: boolean): FourD4yMyContentItem | null {
  const displayTitle: string = extractReplyDisplayTitle(subjectHtml);
  const anchorPattern: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let anchorMatch: RegExpExecArray | null = anchorPattern.exec(subjectHtml);
  while (anchorMatch !== null) {
    const hrefMatch: RegExpMatchArray | null = anchorMatch[1].match(/\bhref=["']([^"']+)["']/i);
    const href: string = hrefMatch === null ? '' : decodeHtml(hrefMatch[1]);
    const threadId: string = extractThreadId(href);
    const postId: string = extractPostId(href);
    const anchorTitle: string = toPlainText(anchorMatch[2]).slice(0, 240);
    const precise: boolean = /redirect\.php\?/i.test(href) && threadId.length > 0 && postId.length > 0;
    const fallback: boolean = /viewthread\.php\?/i.test(href) && threadId.length > 0;
    if ((displayTitle.length > 0 || anchorTitle.length > 0) && (requirePrecisePost ? precise : fallback)) {
      return {
        threadId: threadId,
        postId: precise ? postId : '',
        forumId: extractForumId(rowHtml),
        title: displayTitle.length > 0 ? displayTitle : anchorTitle,
        summary: '',
        forumName: extractCellText(rowHtml, 'forum'),
        lastReplyAt: extractCellText(rowHtml, 'lastpost')
      };
    }
    anchorMatch = anchorPattern.exec(subjectHtml);
  }
  return null;
}

function extractReplyDisplayTitle(subjectHtml: string): string {
  const anchorPattern: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let anchorMatch: RegExpExecArray | null = anchorPattern.exec(subjectHtml);
  while (anchorMatch !== null) {
    const hrefMatch: RegExpMatchArray | null = anchorMatch[1].match(/\bhref=["']([^"']+)["']/i);
    const href: string = hrefMatch === null ? '' : decodeHtml(hrefMatch[1]);
    const title: string = toPlainText(anchorMatch[2]).slice(0, 240);
    if (/viewthread\.php\?/i.test(href) && title.length > 0) {
      return title;
    }
    anchorMatch = anchorPattern.exec(subjectHtml);
  }
  return toPlainText(subjectHtml).slice(0, 240);
}

function extractThreadId(href: string): string {
  const queryMatch: RegExpMatchArray | null = href.match(/[?&](?:tid|ptid)=(\d+)(?:&|$)/i);
  if (queryMatch !== null) {
    return queryMatch[1];
  }
  const legacyMatch: RegExpMatchArray | null = href.match(/thread-(\d+)(?:-|\.|$)/i);
  return legacyMatch === null ? '' : legacyMatch[1];
}

function extractPostId(href: string): string {
  const match: RegExpMatchArray | null = href.match(/[?&]pid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
}

function extractForumId(rowHtml: string): string {
  const match: RegExpMatchArray | null = rowHtml.match(/forumdisplay\.php\?[^"'\s>]*\bfid=(\d+)/i);
  return match === null ? '' : match[1];
}

function extractCellText(rowHtml: string, className: string): string {
  const pattern: RegExp = new RegExp(
    '<td\\b[^>]*\\bclass=["\'](?:[^"\']*\\s)?' + className + '(?:\\s[^"\']*)?["\'][^>]*>([\\s\\S]*?)<\\/td>', 'i');
  const match: RegExpMatchArray | null = rowHtml.match(pattern);
  return match === null ? '' : toPlainText(match[1]).slice(0, 160);
}

function parseLastPage(html: string, currentPage: number): number {
  const pages: string[] = [];
  const pagesPattern: RegExp = /<div\b[^>]*\bclass=["'](?:[^"']*\s)?pages(?:\s[^"']*)?["'][^>]*>([\s\S]*?)<\/div>/gi;
  let pagesMatch: RegExpExecArray | null = pagesPattern.exec(html);
  while (pagesMatch !== null && pages.length < 4) {
    pages.push(pagesMatch[1]);
    pagesMatch = pagesPattern.exec(html);
  }
  let lastPage: number = currentPage;
  const labelPattern: RegExp = /<(?:a|strong)\b[^>]*>([\s\S]*?)<\/(?:a|strong)>/gi;
  const paginationHtml: string = pages.join('\n');
  let labelMatch: RegExpExecArray | null = labelPattern.exec(paginationHtml);
  while (labelMatch !== null) {
    const label: string = toPlainText(labelMatch[1]);
    const totalMatch: RegExpMatchArray | null = label.match(/^(\d+)\s*\/\s*(\d+)$/);
    if (totalMatch !== null) {
      lastPage = Math.max(lastPage, Number.parseInt(totalMatch[2], 10));
    } else if (/^\d+$/.test(label)) {
      lastPage = Math.max(lastPage, Number.parseInt(label, 10));
    }
    labelMatch = labelPattern.exec(paginationHtml);
  }
  return lastPage;
}

function readPageFromUrl(url: string): number {
  const match: RegExpMatchArray | null = url.match(/[?&]page=(\d+)(?:&|$)/i);
  if (match === null) {
    return 1;
  }
  const page: number = Number.parseInt(match[1], 10);
  return Number.isFinite(page) && page > 0 ? page : 1;
}

function isLoginPage(html: string): boolean {
  const userMenuMatch: RegExpMatchArray | null = html.match(
    /<(?:div|span)\b[^>]*\bid=["']umenu["'][^>]*>([\s\S]*?)<\/(?:div|span)>/i);
  if (userMenuMatch !== null && /space\.php/i.test(userMenuMatch[1])) {
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
  return /(?:暂无|没有)(?:相关)?(?:主题|帖子|回复|记录)|no\s+(?:threads|posts|records)/i.test(toPlainText(html));
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
