import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4yPrivateConversationMessage, FourD4yPrivateConversationPayload,
  FourD4yPrivateMessageSegment,
  isAllowedFourD4yPrivateConversationUrl,
  readFourD4yPrivateConversationParticipantId } from
  '../../domain/notice/FourD4yPrivateConversationContracts';

/**
 * Parser for the GET-only PM conversation page.  NG selects `li.s_clear`
 * below `ul.pm_list`; MY 4D4Y retains the same layout in its HAP bundle.
 * Values only leave this parser: source HTML and cookies are never retained.
 */
export function parseFourD4yPrivateConversationPage(html: string, requestUrl: string,
  loadSequence: number): FourD4yPrivateConversationPayload | null {
  const participantUserId: string = readFourD4yPrivateConversationParticipantId(requestUrl);
  if (html.length === 0 || participantUserId.length === 0 ||
    !isAllowedFourD4yPrivateConversationUrl(requestUrl) || loadSequence < 1) {
    return null;
  }
  const viewerUserId: string = extractViewerUserId(html);
  const messages: FourD4yPrivateConversationMessage[] = parseConversationMessages(html, viewerUserId);
  return {
    loadSequence: loadSequence,
    participantUserId: participantUserId,
    viewerUserId: viewerUserId,
    accessState: messages.length === 0 && isLoginPage(html) ?
      FourD4yPageAccessState.LoginRequired : FourD4yPageAccessState.Available,
    hasChallenge: /challenge-platform|cf-chl-|cf-turnstile/i.test(html),
    conversationLayoutFound: /<ul\b[^>]*\bclass=["'][^"']*\bpm_list\b[^"']*["']/i.test(html) ||
      /<li\b[^>]*\bclass=["'][^"']*\bs_clear\b[^"']*["']/i.test(html) || hasEmptyConversation(html),
    errorMessage: extractPageMessage(html),
    messages: messages
  };
}

function parseConversationMessages(html: string, viewerUserId: string): FourD4yPrivateConversationMessage[] {
  const messages: FourD4yPrivateConversationMessage[] = [];
  const identifiers: Set<string> = new Set<string>();
  const rowPattern: RegExp = /<li\b([^>]*)>([\s\S]*?)<\/li>/gi;
  let rowMatch: RegExpExecArray | null = rowPattern.exec(html);
  let rowNumber: number = 0;
  while (rowMatch !== null && messages.length < 200) {
    if (/\bclass=["'][^"']*\bs_clear\b[^"']*["']/i.test(rowMatch[1]) &&
      /<p\b[^>]*\bclass=["'][^"']*\bcite\b[^"']*["']/i.test(rowMatch[2]) &&
      /<div\b[^>]*\bclass=["'][^"']*\bsummary\b[^"']*["']/i.test(rowMatch[2])) {
      rowNumber += 1;
      const message: FourD4yPrivateConversationMessage | null = parseConversationMessage(
        rowMatch[0], viewerUserId, rowNumber);
      if (message !== null && !identifiers.has(message.messageId)) {
        identifiers.add(message.messageId);
        messages.push(message);
      }
    }
    rowMatch = rowPattern.exec(html);
  }
  return messages;
}

function parseConversationMessage(rowHtml: string, viewerUserId: string,
  rowNumber: number): FourD4yPrivateConversationMessage | null {
  const citeMatch: RegExpMatchArray | null = rowHtml.match(
    /<p\b[^>]*\bclass=["'][^"']*\bcite\b[^"']*["'][^>]*>([\s\S]*?)<\/p>/i);
  const summaryMatch: RegExpMatchArray | null = rowHtml.match(
    /<div\b[^>]*\bclass=["'][^"']*\bsummary\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
  if (citeMatch === null || summaryMatch === null) {
    return null;
  }
  const sender: FourD4yPrivateConversationSender = extractSender(citeMatch[1], rowHtml);
  const serverId: string = extractMessageId(rowHtml);
  const content: FourD4yPrivateMessageContent = parsePrivateMessageContent(summaryMatch[1]);
  return {
    messageId: serverId.length > 0 ? 'pm:' + serverId : 'row:' + rowNumber,
    senderUserId: sender.userId,
    senderName: sender.name.length > 0 ? sender.name : '未知用户',
    body: content.body.length > 0 ? content.body : '（无文字内容）',
    segments: content.segments.length > 0 ? content.segments : undefined,
    occurredAt: extractTime(citeMatch[1]),
    isMine: sender.userId.length > 0 && sender.userId === viewerUserId,
    isUnread: /(?:notice_)?newpm\.gif|\bclass=["'][^"']*\bnew\b[^"']*["']|font-weight\s*:\s*bold/i.test(rowHtml)
  };
}

interface FourD4yPrivateMessageContent {
  body: string;
  segments: FourD4yPrivateMessageSegment[];
}

/**
 * NG keeps `div.summary` HTML and resolves forum smilie images inline. Keep
 * the same semantic order, but only retain text plus tightly allow-listed
 * 4D4Y smilie URLs; arbitrary PM HTML never reaches the native component.
 */
function parsePrivateMessageContent(summaryHtml: string): FourD4yPrivateMessageContent {
  const segments: FourD4yPrivateMessageSegment[] = [];
  const bodyParts: string[] = [];
  const imagePattern: RegExp = /<img\b([^>]*)>/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = imagePattern.exec(summaryHtml);
  while (match !== null && segments.length < 200) {
    appendPrivateMessageText(summaryHtml.slice(cursor, match.index), segments, bodyParts);
    const source: string = extractHtmlAttribute(match[1], 'src');
    const emojiUrl: string = normalizeFourD4ySmilieUrl(source);
    if (emojiUrl.length > 0) {
      const alt: string = toPlainText(extractHtmlAttribute(match[1], 'alt') ||
        extractHtmlAttribute(match[1], 'title'));
      const fallback: string = alt.length > 0 ? alt : getFourD4ySmilieFallback(emojiUrl);
      segments.push({ kind: 'emoji', value: fallback, url: emojiUrl });
      bodyParts.push(fallback);
    }
    cursor = match.index + match[0].length;
    match = imagePattern.exec(summaryHtml);
  }
  appendPrivateMessageText(summaryHtml.slice(cursor), segments, bodyParts);
  return {
    body: bodyParts.join('').replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim().slice(0, 5000),
    segments: segments
  };
}

function appendPrivateMessageText(html: string, segments: FourD4yPrivateMessageSegment[], bodyParts: string[]): void {
  if (html.length === 0 || segments.length >= 200) {
    return;
  }
  const text: string = toPlainText(html);
  if (text.length > 0) {
    segments.push({ kind: 'text', value: text });
    bodyParts.push(text);
  }
}

function extractHtmlAttribute(attributes: string, name: string): string {
  const pattern: RegExp = new RegExp('\\b' + name + '=["\\\']([^"\\\']*)["\\\']', 'i');
  const match: RegExpMatchArray | null = attributes.match(pattern);
  return match === null ? '' : decodeHtml(match[1]).trim();
}

function normalizeFourD4ySmilieUrl(source: string): string {
  if (source.length === 0 || source.length > 500) {
    return '';
  }
  let path: string = source.replace(/&amp;/gi, '&').replace(/\\/g, '/').trim();
  if (/^https?:\/\//i.test(path)) {
    const absolute: RegExpMatchArray | null = path.match(
      /^https:\/\/(?:www\.)?4d4y\.com(\/forum\/images\/smilies\/[A-Za-z0-9_./%-]+)(?:[?#].*)?$/i);
    return absolute === null ? '' : 'https://www.4d4y.com' + absolute[1];
  }
  path = path.replace(/^\.\//, '').replace(/^\//, '');
  if (path.indexOf('forum/images/smilies/') === 0) {
    return 'https://www.4d4y.com/' + path;
  }
  if (path.indexOf('images/smilies/') === 0) {
    return 'https://www.4d4y.com/forum/' + path;
  }
  return '';
}

function getFourD4ySmilieFallback(url: string): string {
  const pathMatch: RegExpMatchArray | null = url.match(/\/images\/smilies\/([^?#]+?)(?:\.[A-Za-z0-9]+)$/i);
  if (pathMatch === null) {
    return '[表情]';
  }
  const key: string = pathMatch[1].replace(/\//g, '_').toLowerCase();
  const defaultNames: string[] = ['smile', 'sweat', 'huffy', 'cry', 'titter', 'handshake', 'victory', 'curse',
    'dizzy', 'shutup', 'funk', 'loveliness', 'sad', 'biggrin', 'cool', 'mad', 'shocked', 'tongue', 'lol', 'shy',
    'sleepy'];
  const defaultValues: string[] = [':)', ':sweat:', ':huffy:', ':cry:', ':titter:', ':handshake:', ':victory:',
    ':curse:', ':dizzy:', ':shutup:', ':funk:', ':loveliness:', ':(', ':D', ':cool:', ':mad:', ':o', ':P',
    ':lol:', ':shy:', ':sleepy:'];
  for (let index: number = 0; index < defaultNames.length; index += 1) {
    if (key === 'default_' + defaultNames[index]) {
      return defaultValues[index];
    }
  }
  const monkey: RegExpMatchArray | null = key.match(/^coolmonkey_(\d{1,2})$/);
  if (monkey !== null) {
    const number: number = Number(monkey[1]);
    return number >= 1 && number <= 16 ? '{:2_' + (40 + number) + ':}' : '[表情]';
  }
  const grape: RegExpMatchArray | null = key.match(/^grapeman_(\d{1,2})$/);
  if (grape !== null) {
    const number: number = Number(grape[1]);
    return number >= 1 && number <= 24 ? '{:3_' + (56 + number) + ':}' : '[表情]';
  }
  return '[表情]';
}

interface FourD4yPrivateConversationSender {
  userId: string;
  name: string;
}

function extractSender(citeHtml: string, rowHtml: string): FourD4yPrivateConversationSender {
  const citeAnchor: RegExpMatchArray | null = citeHtml.match(/<a\b([^>]*)>([\s\S]*?)<\/a>/i);
  if (citeAnchor !== null) {
    const uid: string = extractUserId(extractHref(citeAnchor[1]));
    const name: string = toPlainText(citeAnchor[2]).slice(0, 120);
    if (name.length > 0) {
      return { userId: uid, name: name };
    }
  }
  const avatarAnchor: RegExpMatchArray | null = rowHtml.match(
    /<a\b([^>]*)\bclass=["'][^"']*\bavatar\b[^"']*["'][^>]*>/i);
  const senderName: string = toPlainText(citeHtml.replace(/<img\b[^>]*>/gi, ' ')).slice(0, 120);
  return {
    userId: avatarAnchor === null ? '' : extractUserId(extractHref(avatarAnchor[1])),
    name: senderName.replace(/\b\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}:\d{2}\b/, '').trim()
  };
}

function extractMessageId(value: string): string {
  const match: RegExpMatchArray | null = value.match(/\bid=["'](?:pm|pmlist)_(\d+)["']/i);
  return match === null ? '' : match[1];
}

function extractTime(citeHtml: string): string {
  const withoutCite: string = citeHtml.replace(/<cite\b[^>]*>[\s\S]*?<\/cite>/gi, ' ')
    .replace(/<img\b[^>]*>/gi, ' ');
  const value: string = toPlainText(withoutCite).slice(0, 100);
  if (value.length > 0) {
    return value;
  }
  const rawMatch: RegExpMatchArray | null = citeHtml.match(/\b\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}:\d{2}\b/);
  return rawMatch === null ? '' : rawMatch[0];
}

function extractHref(attributes: string): string {
  const match: RegExpMatchArray | null = attributes.match(/\bhref=["']([^"']+)["']/i);
  return match === null ? '' : decodeHtml(match[1]);
}

function extractUserId(value: string): string {
  const match: RegExpMatchArray | null = value.match(/[?&]uid=(\d+)(?:&|$)/i);
  return match === null ? '' : match[1];
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
  return /<form\b[^>]*(?:\bid=["']login(?:form)?["']|\baction=["'][^"']*logging\.php[^"']*action=login)[^>]*>[\s\S]*?<input\b[^>]*\bname=["']username["']/i.test(html);
}

function hasEmptyConversation(html: string): boolean {
  return /(?:暂无|没有)(?:相关)?(?:消息|短消息|记录)|no\s+(?:messages|records)/i.test(toPlainText(html));
}

function extractPageMessage(html: string): string {
  const match: RegExpMatchArray | null = html.match(
    /<(?:div|p)\b[^>]*\bclass=["'][^"']*(?:alert|message|notice)[^"']*["'][^>]*>([\s\S]*?)<\/(?:div|p)>/i);
  return match === null ? '' : toPlainText(match[1]).slice(0, 240);
}

function toPlainText(value: string): string {
  return decodeHtml(value.replace(/<script\b[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[\s\S]*?<\/style>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' '))
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
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
