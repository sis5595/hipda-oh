/**
 * MY 4D4Y mirrors its `sid` cookie into the query string before every RCP
 * request. Keep this transformation bounded to the same-origin read-only
 * search/find-post/account-list routes and never expose the value outside
 * the request.
 */
export function appendFourD4ySessionId(url: string, cookieHeader: string): string {
  if (!/^https:\/\/www\.4d4y\.com\/forum\/(?:search|redirect|viewthread|my)\.php\?[^\s#]+(?:#\S*)?$/i.test(url) ||
    /[?&]sid=[^&]*/i.test(url)) {
    return url;
  }
  const cookieParts: string[] = cookieHeader.split(';');
  for (let index: number = 0; index < cookieParts.length; index += 1) {
    const part: string = cookieParts[index].trim();
    const separator: number = part.indexOf('=');
    if (separator <= 0 || part.slice(0, separator).trim().toLowerCase() !== 'sid') {
      continue;
    }
    const sessionId: string = part.slice(separator + 1).trim();
    if (sessionId.length === 0 || sessionId.length > 256 || !/^[A-Za-z0-9._~-]+$/.test(sessionId)) {
      return url;
    }
    const fragmentIndex: number = url.indexOf('#');
    if (fragmentIndex < 0) {
      return url + '&sid=' + encodeURIComponent(sessionId);
    }
    return url.slice(0, fragmentIndex) + '&sid=' + encodeURIComponent(sessionId) + url.slice(fragmentIndex);
  }
  return url;
}
