export const FOUR_D4Y_DEFAULT_POST_TAIL_TEXT: string = 'HiPDA·OH';
export const FOUR_D4Y_DEFAULT_POST_TAIL_URL: string = 'https://github.com/sis5595/hipda-oh';
export const FOUR_D4Y_MAX_POST_TAIL_TEXT: number = 40;
export const FOUR_D4Y_MAX_POST_TAIL_URL: number = 1024;

export interface FourD4yPostTailSettings {
  addPostTail: boolean;
  postTailText: string;
  postTailUrl: string;
}

export function normalizeFourD4yPostTailText(value: Object): string {
  if (typeof value !== 'string') return FOUR_D4Y_DEFAULT_POST_TAIL_TEXT;
  return value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, FOUR_D4Y_MAX_POST_TAIL_TEXT)
    .replace(/[\ud800-\udbff]$/, '');
}

/** Only ordinary web URLs can be rendered into a BBCode link; no URI commands or credentials. */
export function normalizeFourD4yPostTailUrl(value: Object): string {
  if (typeof value !== 'string') return FOUR_D4Y_DEFAULT_POST_TAIL_URL;
  let url: string = value.trim();
  if (url.length === 0) return '';
  if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
  if (url.length > FOUR_D4Y_MAX_POST_TAIL_URL ||
    !/^https?:\/\/[a-z0-9.-]+(?::\d{1,5})?(?:[/?#][^\s\[\]"'<>\u0000-\u001f\u007f]*)?$/i.test(url)) return '';
  return url;
}

/** NG's compact [size=1] suffix, appended once to new posts/replies, never to edits or private messages. */
export function appendFourD4yPostTail(message: string, settings: FourD4yPostTailSettings | undefined,
  isEditing: boolean = false): string {
  if (settings === undefined || !settings.addPostTail || isEditing || message.trim().length === 0) return message;
  const text: string = normalizeFourD4yPostTailText(settings.postTailText);
  if (text.length === 0) return message;
  // Tail text is plain text, not an additional BBCode program.
  const escapedText: string = text.replace(/\[/g, '&#91;').replace(/\]/g, '&#93;');
  const url: string = normalizeFourD4yPostTailUrl(settings.postTailUrl);
  const sizeText: string = '[size=1]' + escapedText + '[/size]';
  const tail: string = url.length > 0 ? '[url=' + url + ']' + sizeText + '[/url]' : sizeText;
  return message.trimEnd().endsWith(tail) ? message : message + '  ' + tail;
}
