import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4ySearchPagePayload, FourD4ySearchThread, isAllowedFourD4ySearchPageUrl } from '../../domain/search/FourD4ySearchContracts';

/**
 * Pure, bounded parser for the legacy desktop search response.
 *
 * Search remains a separate native-HTTP path because the live 4D4Y endpoint
 * does not return usable results when navigated by ArkWeb. This parser does
 * not retain HTML or expose any authentication value to the UI.
 */
export function parseFourD4yNativeSearchPage(html: string, requestUrl: string,
  loadSequence: number): FourD4ySearchPagePayload | null {
  if (html.length === 0 || !isAllowedFourD4ySearchPageUrl(requestUrl) || loadSequence < 1) {
    return null;
  }
  const hasChallenge: boolean = /challenge-platform|cf-chl-|cf-turnstile/i.test(html);
  const threads: FourD4ySearchThread[] = parseSearchRows(html);
  // A verified result row or NG's logged-in #umenu marker takes precedence
  // over a stray/hidden login input elsewhere in the desktop template.
  const accessState: FourD4yPageAccessState = threads.length === 0 && isLoginPage(html) ?
    FourD4yPageAccessState.LoginRequired : FourD4yPageAccessState.Available;
  const pageInfo: FourD4yNativeSearchPageInfo = parseSearchPages(html, requestUrl);
  const resultLayoutFound: boolean = threads.length > 0 || /<form\b[^>]*\baction=["'][^"']*search\.php/i.test(html) ||
    /class=["'][^"']*(?:alert|message|notice)[^"']*["']/i.test(html);
  return {
    loadSequence: loadSequence,
    page: pageInfo.page,
    lastPage: pageInfo.lastPage,
    accessState: accessState,
    hasChallenge: hasChallenge,
    resultLayoutFound: resultLayoutFound,
    previousPageUrl: pageInfo.previousPageUrl,
    nextPageUrl: pageInfo.nextPageUrl,
    errorMessage: extractSearchMessage(html),
    threads: threads
  };
}

interface FourD4yNativeSearchPageInfo {
  page: number;
  lastPage: number;
  previousPageUrl: string;
  nextPageUrl: string;
}

interface FourD4yNativeSearchLink {
  url: string;
  page: number;
  label: string;
}

interface FourD4yNativeSearchTitleLink {
  threadId: string;
  postId: string;
  title: string;
}

function parseSearchRows(html: string): FourD4ySearchThread[] {
  const threads: FourD4ySearchThread[] = [];
  const seenTargets: Set<string> = new Set<string>();
  // NG parses title results from every tbody with `th.subject a`, rather than
  // relying on a normal-thread DOM id.  4D4Y search pages do not consistently
  // emit that id, so inspect every bounded tbody and require a verified thread
  // link before producing a row.
  const tbodyPattern: RegExp = /<tbody\b([^>]*)>([\s\S]*?)<\/tbody>/gi;
  let tbodyMatch: RegExpExecArray | null = tbodyPattern.exec(html);
  while (tbodyMatch !== null && threads.length < 100) {
    const hintedThreadId: string = extractThreadIdFromTbodyAttributes(tbodyMatch[1]);
    addSearchRow(threads, seenTargets, tbodyMatch[2], hintedThreadId);
    tbodyMatch = tbodyPattern.exec(html);
  }

  // Full-text results are rendered as rows inside table.datatable, with the
  // title in div.sp_title.  This is the structural contract used by both NG
  // and MY 4D4Y; the strict title-link check below avoids treating unrelated
  // table rows as forum threads.
  const datatablePattern: RegExp = /<table\b[^>]*\bclass=["'][^"']*\bdatatable\b[^"']*["'][^>]*>([\s\S]*?)<\/table>/gi;
  let datatableMatch: RegExpExecArray | null = datatablePattern.exec(html);
  while (datatableMatch !== null && threads.length < 100) {
    const rowPattern: RegExp = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
    let rowMatch: RegExpExecArray | null = rowPattern.exec(datatableMatch[1]);
    while (rowMatch !== null && threads.length < 100) {
      addSearchRow(threads, seenTargets, rowMatch[1], '');
      rowMatch = rowPattern.exec(datatableMatch[1]);
    }
    datatableMatch = datatablePattern.exec(html);
  }
  return threads;
}

function addSearchRow(threads: FourD4ySearchThread[], seenTargets: Set<string>, rowHtml: string,
  hintedThreadId: string): void {
  const titleLink: FourD4yNativeSearchTitleLink | null = extractThreadTitleLink(rowHtml, hintedThreadId);
  if (titleLink === null) {
    return;
  }
  const targetKey: string = titleLink.postId.length > 0 ? 'post:' + titleLink.postId :
    'thread:' + titleLink.threadId;
  if (seenTargets.has(targetKey)) {
    return;
  }
  seenTargets.add(targetKey);
  threads.push({
    threadId: titleLink.threadId,
    postId: titleLink.postId,
    forumId: extractForumId(rowHtml),
    title: titleLink.title,
    summary: extractCellText(rowHtml, 'sp_content').slice(0, 500),
    forumName: extractCellText(rowHtml, 'forum') || extractFullTextSpanLink(rowHtml, 0),
    authorName: extractAuthorName(rowHtml),
    replyCount: extractReplyCount(rowHtml),
    lastReplyAt: extractCellText(rowHtml, 'lastpost') || extractAuthorTime(rowHtml) ||
      extractFullTextSpanText(rowHtml, 4)
  });
}

function extractThreadTitleLink(rowHtml: string, hintedThreadId: string): FourD4yNativeSearchTitleLink | null {
  const containers: RegExp[] = [
    /<th\b[^>]*\bclass=["'][^"']*\bsubject\b[^"']*["'][^>]*>([\s\S]*?)<\/th>/i,
    /<div\b[^>]*\bclass=["'][^"']*\bsp_title\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
    /<span\b[^>]*\bid=["']thread_\d+["'][^>]*>([\s\S]*?)<\/span>/i
  ];
  for (let index: number = 0; index < containers.length; index += 1) {
    const containerMatch: RegExpMatchArray | null = rowHtml.match(containers[index]);
    if (containerMatch === null) {
      continue;
    }
    const anchor: RegExpMatchArray | null = containerMatch[1].match(/<a\b([^>]*)>([\s\S]*?)<\/a>/i);
    if (anchor === null) {
      continue;
    }
    const threadId: string = extractThreadIdFromHref(anchor[1]) || hintedThreadId;
    const postId: string = extractPostIdFromHref(anchor[1]);
    const title: string = toPlainText(anchor[2]).slice(0, 240);
    if ((threadId.length > 0 || postId.length > 0) && title.length > 0) {
      return { threadId: threadId, postId: postId, title: title };
    }
  }
  return null;
}

function extractPostIdFromHref(attributes: string): string {
  const hrefMatch: RegExpMatchArray | null = attributes.match(/\bhref=["']([^"']+)["']/i);
  if (hrefMatch === null) {
    return '';
  }
  const match: RegExpMatchArray | null = decodeHtml(hrefMatch[1]).match(/[?&]pid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
}

function extractThreadIdFromTbodyAttributes(attributes: string): string {
  const match: RegExpMatchArray | null = attributes.match(/\bid=["'](?:normal|stick)thread_(\d+)["']/i);
  return match === null ? '' : match[1];
}

function extractThreadIdFromHref(attributes: string): string {
  const hrefMatch: RegExpMatchArray | null = attributes.match(/\bhref=["']([^"']+)["']/i);
  if (hrefMatch === null) {
    return '';
  }
  const href: string = decodeHtml(hrefMatch[1]);
  const queryMatch: RegExpMatchArray | null = href.match(/[?&](?:tid|ptid)=(\d+)(?:&|$)/i);
  if (queryMatch !== null) {
    return queryMatch[1];
  }
  const legacyMatch: RegExpMatchArray | null = href.match(/thread-(\d+)-/i);
  return legacyMatch === null ? '' : legacyMatch[1];
}

function extractAuthorName(rowHtml: string): string {
  const authorCell: RegExpMatchArray | null = rowHtml.match(
    /<td\b[^>]*\bclass=["'][^"']*\bauthor\b[^"']*["'][^>]*>([\s\S]*?)<\/td>/i);
  if (authorCell !== null) {
    const cite: RegExpMatchArray | null = authorCell[1].match(/<cite\b[^>]*>([\s\S]*?)<\/cite>/i);
    return cite === null ? toPlainText(authorCell[1]).slice(0, 140) : toPlainText(cite[1]).slice(0, 140);
  }
  const details: RegExpMatchArray | null = rowHtml.match(
    /<div\b[^>]*\bclass=["'][^"']*\bsp_theard\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
  if (details === null) {
    return '';
  }
  const spans: string[] = extractSpanContents(details[1]);
  return spans.length > 1 ? extractFirstAnchorText(spans[1]) : '';
}

function extractFullTextSpanLink(rowHtml: string, index: number): string {
  const spans: string[] = extractFullTextDetailSpans(rowHtml);
  return index >= 0 && index < spans.length ? extractFirstAnchorText(spans[index]) : '';
}

function extractFullTextSpanText(rowHtml: string, index: number): string {
  const spans: string[] = extractFullTextDetailSpans(rowHtml);
  return index >= 0 && index < spans.length ? toPlainText(spans[index]).slice(0, 140) : '';
}

function extractFullTextDetailSpans(rowHtml: string): string[] {
  const details: RegExpMatchArray | null = rowHtml.match(
    /<div\b[^>]*\bclass=["'][^"']*\bsp_theard\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
  return details === null ? [] : extractSpanContents(details[1]);
}

function extractAuthorTime(rowHtml: string): string {
  const authorCell: RegExpMatchArray | null = rowHtml.match(
    /<td\b[^>]*\bclass=["'][^"']*\bauthor\b[^"']*["'][^>]*>([\s\S]*?)<\/td>/i);
  if (authorCell === null) {
    return '';
  }
  const time: RegExpMatchArray | null = authorCell[1].match(/<em\b[^>]*>([\s\S]*?)<\/em>/i);
  return time === null ? '' : toPlainText(time[1]).slice(0, 140);
}

function extractSpanContents(value: string): string[] {
  const spans: string[] = [];
  const pattern: RegExp = /<span\b[^>]*>([\s\S]*?)<\/span>/gi;
  let match: RegExpExecArray | null = pattern.exec(value);
  while (match !== null && spans.length < 8) {
    spans.push(match[1]);
    match = pattern.exec(value);
  }
  return spans;
}

function extractFirstAnchorText(value: string): string {
  const anchor: RegExpMatchArray | null = value.match(/<a\b[^>]*>([\s\S]*?)<\/a>/i);
  return anchor === null ? '' : toPlainText(anchor[1]).slice(0, 140);
}

function extractForumId(rowHtml: string): string {
  const match: RegExpMatchArray | null = rowHtml.match(/forumdisplay\.php\?[^"'\s>]*\bfid=(\d+)/i);
  return match === null ? '' : match[1];
}

function extractCellText(rowHtml: string, className: string): string {
  const cellPattern: RegExp = new RegExp(
    '<(?:td|div)\\b[^>]*\\bclass=["\'](?:[^"\']*\\s)?' + className + '(?:\\s[^"\']*)?["\'][^>]*>([\\s\\S]*?)<\\/(?:td|div)>', 'i');
  const match: RegExpMatchArray | null = rowHtml.match(cellPattern);
  return match === null ? '' : toPlainText(match[1]).slice(0, 140);
}

function extractReplyCount(rowHtml: string): number {
  const cellText: string = extractCellText(rowHtml, 'nums') || extractFullTextSpanText(rowHtml, 3);
  const match: RegExpMatchArray | null = cellText.match(/\d+/);
  if (match === null) {
    return 0;
  }
  const value: number = Number.parseInt(match[0], 10);
  return Number.isFinite(value) && value >= 0 ? value : 0;
}

function parseSearchPages(html: string, requestUrl: string): FourD4yNativeSearchPageInfo {
  const currentFromUrl: number = readPageFromUrl(requestUrl);
  const paginationHtml: string = extractSearchPaginationHtml(html);
  const links: FourD4yNativeSearchLink[] = extractSearchLinks(paginationHtml);
  let lastPage: number = currentFromUrl;
  let previousPageUrl: string = '';
  let nextPageUrl: string = '';
  for (let index: number = 0; index < links.length; index += 1) {
    const link: FourD4yNativeSearchLink = links[index];
    lastPage = Math.max(lastPage, link.page);
    if (link.page === currentFromUrl - 1 && previousPageUrl.length === 0) {
      previousPageUrl = link.url;
    }
    if (link.page === currentFromUrl + 1 && nextPageUrl.length === 0) {
      nextPageUrl = link.url;
    }
    if (/上一页|prev|‹|«/i.test(link.label)) {
      previousPageUrl = link.url;
    }
    if (/下一页|next|›|»/i.test(link.label)) {
      nextPageUrl = link.url;
    }
  }
  const pageLabels: string[] = extractSearchPageLabels(paginationHtml);
  for (let index: number = 0; index < pageLabels.length; index += 1) {
    const label: string = pageLabels[index];
    const totalMatch: RegExpMatchArray | null = label.match(/^(\d+)\s*\/\s*(\d+)$/);
    if (totalMatch !== null) {
      lastPage = Math.max(lastPage, Number.parseInt(totalMatch[2], 10));
      continue;
    }
    if (/^\d+$/.test(label)) {
      lastPage = Math.max(lastPage, Number.parseInt(label, 10));
    }
  }
  return {
    page: currentFromUrl,
    lastPage: Math.max(currentFromUrl, lastPage),
    previousPageUrl: previousPageUrl,
    nextPageUrl: nextPageUrl
  };
}

function extractSearchPaginationHtml(html: string): string {
  // The NG parser reads only `div.pages_btns div.pages`.  Restricting this
  // scope prevents an unrelated search.php link in the page body from being
  // misidentified as the final search page.
  const pagesPattern: RegExp = /<div\b[^>]*\bclass=["'](?:[^"']*\s)?pages(?:\s[^"']*)?["'][^>]*>([\s\S]*?)<\/div>/gi;
  const sections: string[] = [];
  let match: RegExpExecArray | null = pagesPattern.exec(html);
  while (match !== null && sections.length < 4) {
    sections.push(match[1]);
    match = pagesPattern.exec(html);
  }
  return sections.join('\n');
}

function extractSearchLinks(paginationHtml: string): FourD4yNativeSearchLink[] {
  const links: FourD4yNativeSearchLink[] = [];
  const anchorPattern: RegExp = /<a\b[^>]*\bhref=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let match: RegExpExecArray | null = anchorPattern.exec(paginationHtml);
  while (match !== null && links.length < 80) {
    const url: string = normalizeSearchUrl(match[1]);
    if (url.length > 0) {
      const page: number = readPageFromUrl(url);
      links.push({ url: url, page: page, label: toPlainText(match[2]).slice(0, 40) });
    }
    match = anchorPattern.exec(paginationHtml);
  }
  return links;
}

function extractSearchPageLabels(paginationHtml: string): string[] {
  const labels: string[] = [];
  const labelPattern: RegExp = /<(?:a|strong)\b[^>]*>([\s\S]*?)<\/(?:a|strong)>/gi;
  let match: RegExpExecArray | null = labelPattern.exec(paginationHtml);
  while (match !== null && labels.length < 80) {
    const label: string = toPlainText(match[1]).slice(0, 40);
    if (label.length > 0) {
      labels.push(label);
    }
    match = labelPattern.exec(paginationHtml);
  }
  return labels;
}

function normalizeSearchUrl(rawUrl: string): string {
  const decoded: string = decodeHtml(rawUrl).trim();
  if (/^https:\/\/www\.4d4y\.com\/forum\/search\.php\?[^\s#]+$/i.test(decoded)) {
    return decoded;
  }
  if (/^\/forum\/search\.php\?[^\s#]+$/i.test(decoded)) {
    return 'https://www.4d4y.com' + decoded;
  }
  if (/^search\.php\?[^\s#]+$/i.test(decoded)) {
    return 'https://www.4d4y.com/forum/' + decoded;
  }
  return '';
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
  // This is the exact semantic marker used by NG's LoginHelper: a #umenu
  // belonging to the signed-in page and containing the profile link.
  if (userMenuMatch !== null && /space\.php/i.test(userMenuMatch[1])) {
    return false;
  }
  const formPattern: RegExp = /<form\b([^>]*)>([\s\S]*?)<\/form>/gi;
  let formMatch: RegExpExecArray | null = formPattern.exec(html);
  while (formMatch !== null) {
    const attributes: string = formMatch[1];
    const body: string = formMatch[2];
    const identifiesLogin: boolean = /\b(?:id|name)=["']login(?:form)?["']/i.test(attributes) ||
      /\baction=["'][^"']*logging\.php[^"']*action=login/i.test(attributes);
    const hasUsername: boolean = /<input\b[^>]*\bname=["']username["']/i.test(body);
    const hasPassword: boolean = /<input\b[^>]*\bname=["']password["']/i.test(body);
    if (identifiesLogin && hasUsername && hasPassword) {
      return true;
    }
    formMatch = formPattern.exec(html);
  }
  return false;
}

function extractSearchMessage(html: string): string {
  const match: RegExpMatchArray | null = html.match(
    /<(?:div|p)\b[^>]*\bclass=["'][^"']*(?:alert|message|notice)[^"']*["'][^>]*>([\s\S]*?)<\/(?:div|p)>/i);
  return match === null ? '' : toPlainText(match[1]).slice(0, 180);
}

function toPlainText(value: string): string {
  return decodeHtml(value.replace(/<[^>]+>/g, ''))
    .replace(/\s+/g, ' ')
    .trim();
}

function decodeHtml(value: string): string {
  return value.replace(/&(?:nbsp|amp|lt|gt|quot|#(\d+)|#x([\da-f]+));/gi,
    (entity: string, decimal: string, hexadecimal: string): string => {
      const decimalText: string = typeof decimal === 'string' ? decimal : '';
      const hexadecimalText: string = typeof hexadecimal === 'string' ? hexadecimal : '';
      if (decimalText.length > 0) {
        return String.fromCharCode(Number.parseInt(decimalText, 10));
      }
      if (hexadecimalText.length > 0) {
        return String.fromCharCode(Number.parseInt(hexadecimalText, 16));
      }
      if (entity.toLowerCase() === '&nbsp;') {
        return ' ';
      }
      if (entity.toLowerCase() === '&amp;') {
        return '&';
      }
      if (entity.toLowerCase() === '&lt;') {
        return '<';
      }
      if (entity.toLowerCase() === '&gt;') {
        return '>';
      }
      return '"';
    });
}
