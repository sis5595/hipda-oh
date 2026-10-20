import { util } from '@kit.ArkTS';
import { FourD4ySearchFormPayload, FourD4ySearchMode, isFourD4ySearchModeSupported } from './FourD4ySearchContracts';

/**
 * Encodes a search argument with the legacy forum's declared GBK charset.
 *
 * 4D4Y's legacy `search.php` contract uses GBK query components. An ArkWeb
 * form submit uses the document's default URL encoding on this device, which
 * makes Chinese search terms fail to match. The platform's TextEncoder is the
 * supported, bounded conversion point; no character map is kept by this app.
 */
export function encodeFourD4yGbkQueryComponent(value: string): string | null {
  if (value.length === 0) {
    return '';
  }
  // ASCII is byte-identical in GBK. Keeping this invariant path independent
  // of the platform codec also makes the forum's usual Latin test keywords
  // deterministic in the host-side contract tests.
  if (/^[\x00-\x7F]+$/.test(value)) {
    return encodeQueryBytes(value.split('').map((character: string) => character.charCodeAt(0)));
  }
  try {
    const encoder: util.TextEncoder = new util.TextEncoder('gbk');
    const bytes: Uint8Array = encoder.encodeInto(value);
    if (bytes.length === 0) {
      return null;
    }
    return encodeQueryBytes(Array.from(bytes));
  } catch (_error) {
    return null;
  }
}

function encodeQueryBytes(bytes: number[]): string {
  let encoded: string = '';
  for (let index: number = 0; index < bytes.length; index += 1) {
    const byte: number = bytes[index];
    if ((byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) ||
      (byte >= 0x30 && byte <= 0x39) || byte === 0x2D || byte === 0x2E ||
      byte === 0x5F || byte === 0x7E) {
      encoded += String.fromCharCode(byte);
    } else if (byte === 0x20) {
      encoded += '+';
    } else {
      encoded += '%' + byte.toString(16).toUpperCase().padStart(2, '0');
    }
  }
  return encoded;
}

/** NG's profile search is an exact UID request, independent of form controls. */
export function buildFourD4yAuthorIdSearchRequestUrl(forumRoot: string, userId: string,
  forumId: string): string | null {
  if (forumRoot !== 'https://www.4d4y.com/forum/' || !/^[1-9]\d{0,19}$/.test(userId) ||
    (forumId !== 'all' && !/^[1-9]\d*$/.test(forumId))) {
    return null;
  }
  return forumRoot + 'search.php?srchfid=' + forumId + '&srchfrom=0&searchsubmit=yes&srchuid=' + userId;
}

/**
 * Builds the read-only contract used by the current HarmonyOS MY 4D4Y
 * client. NG's older contract remains useful as parser evidence, but its
 * title request omits `mod=forum` and no longer matches the current native
 * session path consistently. Pagination after page one remains entirely
 * server-generated.
 */
export function buildFourD4ySearchRequestUrl(forumRoot: string, form: FourD4ySearchFormPayload,
  mode: FourD4ySearchMode, keyword: string, forumId: string): string | null {
  const normalizedKeyword: string = keyword.trim();
  if (!/^https:\/\/www\.4d4y\.com\/forum\/$/.test(forumRoot) ||
    !isFourD4ySearchModeSupported(form, mode, normalizedKeyword) ||
    (forumId !== 'all' && !/^\d+$/.test(forumId))) {
    return null;
  }
  // NG and the current server form both allow srchuname/srchuid to be
  // combined with srchfid. MY 4D4Y exposes only the all-forums subset in its
  // UI, but that omission is not a server limitation.
  const requestedForumId: string = forumId === 'all' ? 'all' : forumId;
  const queryParts: string[] = [];
  if (mode === FourD4ySearchMode.Author) {
    if (/^\d+$/.test(normalizedKeyword) && form.hasAuthorIdField) {
      return buildFourD4yAuthorIdSearchRequestUrl(forumRoot, normalizedKeyword, requestedForumId);
    }
  }

  const encodedValue: string | null = encodeFourD4yGbkQueryComponent(normalizedKeyword);
  if (encodedValue === null) {
    return null;
  }
  if (mode === FourD4ySearchMode.FullText) {
    queryParts.push('srchtype=fulltext', 'srchtxt=' + encodedValue, 'searchsubmit=true', 'st=on',
      'srchuname=', 'srchfilter=all', 'srchfrom=0', 'before=', 'orderby=lastpost', 'ascdesc=desc',
      'srchfid%5B0%5D=' + requestedForumId, 'page=1');
    return forumRoot + 'search.php?' + queryParts.join('&');
  }
  queryParts.push('mod=forum', 'searchsubmit=yes');
  if (mode === FourD4ySearchMode.Author) {
    queryParts.push('srchuname=' + encodedValue);
  } else {
    queryParts.push('srchtxt=' + encodedValue);
  }
  queryParts.push('srchtype=title', 'orderby=lastpost', 'ascdesc=desc');
  if (requestedForumId !== 'all') {
    queryParts.push('srchfid%5B0%5D=' + requestedForumId);
  }
  queryParts.push('page=1');
  return forumRoot + 'search.php?' + queryParts.join('&');
}
