import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4ySearchPostTargetPayload, isAllowedFourD4ySearchPostTargetUrl } from
  '../../domain/search/FourD4ySearchContracts';

/** Reads the one same-origin meta-refresh used by the current 4D4Y find-post response. */
export function extractFourD4ySearchPostRefreshUrl(html: string): string {
  const pattern: RegExp = /<meta\b[^>]*>/gi;
  let match: RegExpExecArray | null = pattern.exec(html);
  let inspected: number = 0;
  while (match !== null && inspected < 30) {
    inspected += 1;
    const httpEquiv: string = readAttribute(match[0], 'http-equiv').toLowerCase();
    const content: string = readAttribute(match[0], 'content');
    if (httpEquiv === 'refresh' && content.length > 0) {
      const urlMatch: RegExpMatchArray | null = content.match(/(?:^|;)\s*url\s*=\s*([\s\S]+)$/i);
      if (urlMatch !== null) {
        const normalized: string = normalizeFourD4yPostTargetUrl(stripOuterQuotes(urlMatch[1].trim()));
        return isAllowedFourD4ySearchPostTargetUrl(normalized) ? normalized : '';
      }
    }
    match = pattern.exec(html);
  }
  return '';
}

/** Pure parser for the final page returned by the forum's find-post chain. */
export function parseFourD4ySearchPostTargetPage(html: string, pageUrl: string,
  requestedThreadId: string, requestedPostId: string, resolveSequence: number): FourD4ySearchPostTargetPayload | null {
  if (html.length === 0 || !isAllowedFourD4ySearchPostTargetUrl(pageUrl) ||
    (requestedThreadId.length > 0 && !isDigitsOnly(requestedThreadId)) ||
    !isDigitsOnly(requestedPostId) || resolveSequence < 1) {
    return null;
  }
  const postIds: string[] = extractPostIds(html);
  const postIndex: number = postIds.indexOf(requestedPostId);
  const postFound: boolean = postIndex >= 0;
  const floor: number = postFound ? extractPostFloor(html, requestedPostId) : 0;
  const page: number = floor > 0 ? Math.ceil(floor / 50) : extractCurrentPage(html, pageUrl);
  const returnedThreadId: string = extractThreadId(pageUrl) || extractThreadIdFromHtml(html);
  const threadId: string = returnedThreadId.length > 0 ? returnedThreadId :
    (postFound ? requestedThreadId : '');
  return {
    resolveSequence: resolveSequence,
    requestedPostId: requestedPostId,
    threadId: threadId,
    page: page,
    floor: floor,
    title: extractTitle(html),
    postFound: postFound,
    accessState: isLoginPage(html) && !postFound ? FourD4yPageAccessState.LoginRequired :
      FourD4yPageAccessState.Available,
    hasChallenge: /challenge-platform|cf-chl-|cf-turnstile/i.test(html),
    errorMessage: extractPageMessage(html)
  };
}

function extractPostIds(html: string): string[] {
  const ids: string[] = [];
  const seen: Set<string> = new Set<string>();
  const pattern: RegExp = /\bid=["'](?:post_|pid)(\d+)["']/gi;
  let match: RegExpExecArray | null = pattern.exec(html);
  while (match !== null && ids.length < 100) {
    if (!seen.has(match[1])) {
      seen.add(match[1]);
      ids.push(match[1]);
    }
    match = pattern.exec(html);
  }
  return ids;
}

/**
 * Reads Discuz's server-computed floor instead of deriving it from DOM order.
 * A `viewpid` response contains just one post, so its index is never a floor.
 * MY 4D4Y handles the same four named early floors explicitly.
 */
function extractPostFloor(html: string, postId: string): number {
  const escapedPostId: string = postId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const anchorMatch: RegExpMatchArray | null = html.match(new RegExp(
    '<a\\b[^>]*\\bid=["\\\']postnum' + escapedPostId + '["\\\'][^>]*>([\\s\\S]*?)<\\/a>', 'i'));
  if (anchorMatch === null) {
    return 0;
  }
  const visibleLabel: string = toPlainText(anchorMatch[1]);
  const numericMatch: RegExpMatchArray | null = visibleLabel.match(/(?:^|\D)(\d+)(?:\D|$)/);
  if (numericMatch !== null) {
    const floor: number = Number.parseInt(numericMatch[1], 10);
    return Number.isFinite(floor) && floor > 0 ? floor : 0;
  }
  if (visibleLabel.indexOf('楼主') >= 0) {
    return 1;
  }
  if (visibleLabel.indexOf('沙发') >= 0) {
    return 2;
  }
  if (visibleLabel.indexOf('板凳') >= 0) {
    return 3;
  }
  if (visibleLabel.indexOf('地板') >= 0) {
    return 4;
  }
  return 0;
}

function extractCurrentPage(html: string, pageUrl: string): number {
  const urlPage: string = getQueryValue(pageUrl, 'page');
  if (isDigitsOnly(urlPage)) {
    return Math.max(1, Number.parseInt(urlPage, 10));
  }
  const pages: RegExpMatchArray | null = html.match(
    /<div\b[^>]*\bclass=["'][^"']*\bpages\b[^"']*["'][^>]*>[\s\S]*?<strong\b[^>]*>\s*(\d+)\s*<\/strong>/i);
  if (pages === null) {
    return 1;
  }
  const value: number = Number.parseInt(pages[1], 10);
  return Number.isFinite(value) ? Math.max(1, value) : 1;
}

function extractThreadId(url: string): string {
  const value: string = getQueryValue(url, 'tid') || getQueryValue(url, 'ptid');
  return isDigitsOnly(value) ? value : '';
}

function extractThreadIdFromHtml(html: string): string {
  const patterns: RegExp[] = [
    /\btid\s*=\s*parseInt\(\s*["'](\d+)["']/i,
    /<input\b[^>]*\bname=["']tid["'][^>]*\bvalue=["'](\d+)["']/i,
    /<input\b[^>]*\bvalue=["'](\d+)["'][^>]*\bname=["']tid["']/i,
    /viewthread\.php\?[^"'\s>]*\btid=(\d+)(?:&|&amp;|$)/i
  ];
  for (let index: number = 0; index < patterns.length; index += 1) {
    const match: RegExpMatchArray | null = html.match(patterns[index]);
    if (match !== null) {
      return match[1];
    }
  }
  return '';
}

function extractTitle(html: string): string {
  const heading: RegExpMatchArray | null = html.match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i);
  if (heading !== null) {
    return toPlainText(heading[1]).slice(0, 240);
  }
  const title: RegExpMatchArray | null = html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i);
  if (title === null) {
    return '';
  }
  return toPlainText(title[1]).replace(/\s+-\s+.*$/, '').trim().slice(0, 240);
}

function extractPageMessage(html: string): string {
  const match: RegExpMatchArray | null = html.match(
    /<(?:div|p)\b[^>]*\bclass=["'][^"']*\b(?:alert_info|alert_error|message|notice)\b[^"']*["'][^>]*>([\s\S]*?)<\/(?:div|p)>/i);
  return match === null ? '' : toPlainText(match[1]).slice(0, 180);
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
    const attributes: string = formMatch[1];
    const body: string = formMatch[2];
    const identifiesLogin: boolean = /\b(?:id|name)=["']login(?:form)?["']/i.test(attributes) ||
      /\baction=["'][^"']*logging\.php[^"']*action=login/i.test(attributes);
    if (identifiesLogin && /<input\b[^>]*\bname=["']username["']/i.test(body) &&
      /<input\b[^>]*\bname=["']password["']/i.test(body)) {
      return true;
    }
    formMatch = formPattern.exec(html);
  }
  return false;
}

function normalizeFourD4yPostTargetUrl(rawUrl: string): string {
  const decoded: string = decodeHtml(rawUrl).trim();
  if (/^https:\/\/www\.4d4y\.com\/forum\/(?:redirect|viewthread)\.php\?/i.test(decoded)) {
    return decoded;
  }
  if (/^\/forum\/(?:redirect|viewthread)\.php\?/i.test(decoded)) {
    return 'https://www.4d4y.com' + decoded;
  }
  if (/^(?:redirect|viewthread)\.php\?/i.test(decoded)) {
    return 'https://www.4d4y.com/forum/' + decoded;
  }
  if (/^\.\/(?:redirect|viewthread)\.php\?/i.test(decoded)) {
    return 'https://www.4d4y.com/forum/' + decoded.slice(2);
  }
  return '';
}

function readAttribute(tag: string, name: string): string {
  const quoted: RegExp = new RegExp('\\b' + name + '\\s*=\\s*(["\\\'])([\\s\\S]*?)\\1', 'i');
  const quotedMatch: RegExpMatchArray | null = tag.match(quoted);
  if (quotedMatch !== null) {
    return decodeHtml(quotedMatch[2]).trim();
  }
  const unquoted: RegExp = new RegExp('\\b' + name + '\\s*=\\s*([^\\s>]+)', 'i');
  const unquotedMatch: RegExpMatchArray | null = tag.match(unquoted);
  return unquotedMatch === null ? '' : decodeHtml(unquotedMatch[1]).trim();
}

function stripOuterQuotes(value: string): string {
  if (value.length >= 2 && ((value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'")))) {
    return value.slice(1, -1).trim();
  }
  return value;
}

function getQueryValue(url: string, name: string): string {
  const escapedName: string = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match: RegExpMatchArray | null = decodeHtml(url).match(
    new RegExp('[?&]' + escapedName + '=([^&#]*)', 'i'));
  return match === null ? '' : match[1];
}

function toPlainText(value: string): string {
  return decodeHtml(value.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function decodeHtml(value: string): string {
  return value.replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&nbsp;/gi, ' ');
}

function isDigitsOnly(value: string): boolean {
  return /^\d+$/.test(value);
}
