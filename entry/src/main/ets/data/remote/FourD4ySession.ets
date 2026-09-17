import { webview } from '@kit.ArkWeb';
import { extractFourD4ySetCookieHeaders } from './FourD4yResponseCookieBridge';

/**
 * The one 4D4Y authentication boundary for ArkWeb and native forum requests.
 * Credentials are entered only into the ordinary ArkWeb login form. Cookie
 * values never reach the UI or logs. ArkWeb remains the active cookie owner;
 * P-10 may additionally pass a bounded 4D4Y-only snapshot to Asset Store.
 */
export class FourD4ySession {
  static readonly forumRoot: string = 'https://www.4d4y.com/forum/';
  static readonly fullSiteUserAgent: string =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

  static async getCookieHeader(): Promise<string> {
    try {
      return await webview.WebCookieManager.fetchCookie(FourD4ySession.forumRoot, false);
    } catch (_error) {
      return '';
    }
  }

  static async isLoggedIn(): Promise<boolean> {
    const cookieHeader: string = await FourD4ySession.getCookieHeader();
    return FourD4ySession.hasAuthenticationCookie(cookieHeader);
  }

  static hasAuthenticationCookie(cookieHeader: string): boolean {
    return /(?:^|;\s*)cdb_auth=/i.test(cookieHeader);
  }

  /**
   * Captures only valid `cdb_*` pairs from the fixed forum origin. The
   * returned value is a short-lived secret string for Asset Store only; never
   * place it in Preferences, component state, UI, or diagnostics.
   */
  static createAccountSessionSecret(cookieHeader: string): string | null {
    const pairs: FourD4ySessionCookiePair[] = FourD4ySession.getSessionCookiePairs(cookieHeader);
    if (pairs.findIndex((pair: FourD4ySessionCookiePair) => pair.name === 'cdb_auth') < 0) {
      return null;
    }
    const secret: string = pairs.map((pair: FourD4ySessionCookiePair) => pair.name + '=' + pair.value).join('\n');
    // Asset Store accepts a SECRET up to 1024 bytes. Length enforcement is
    // performed at the byte-encoding boundary in AccountSessionStore; keep a
    // larger in-memory value here only long enough to report a safe failure.
    return secret.length > 0 ? secret : null;
  }

  static async captureAccountSessionSecret(): Promise<string | null> {
    return FourD4ySession.createAccountSessionSecret(await FourD4ySession.getCookieHeader());
  }

  /**
   * Replaces only the forum session-cookie names. Normal ArkWeb has one
   * cookie profile for this app, so named-account isolation is implemented by
   * atomically restoring a verified snapshot before a server verification.
   * External-site cookies are intentionally untouched.
   */
  static async restoreAccountSessionSecret(sessionSecret: string): Promise<boolean> {
    const desiredPairs: FourD4ySessionCookiePair[] = FourD4ySession.parseAccountSessionSecret(sessionSecret);
    if (desiredPairs.length === 0 || desiredPairs.findIndex((pair: FourD4ySessionCookiePair) =>
      pair.name === 'cdb_auth') < 0) {
      return false;
    }
    const currentHeader: string = await FourD4ySession.getCookieHeader();
    const previousSecret: string | null = FourD4ySession.createAccountSessionSecret(currentHeader);
    try {
      const currentPairs: FourD4ySessionCookiePair[] = FourD4ySession.getSessionCookiePairs(currentHeader);
      if (!await FourD4ySession.clearForumSessionCookieNames(
        FourD4ySession.mergeCookieNames(currentPairs, desiredPairs)) ||
        !await FourD4ySession.writeForumSessionCookiePairs(desiredPairs)) {
        throw new Error('4d4y-cookie-restore-failed');
      }
      return true;
    } catch (_error) {
      // Keep the caller's previous usable session whenever restoration fails.
      if (previousSecret !== null) {
        const previousPairs: FourD4ySessionCookiePair[] = FourD4ySession.parseAccountSessionSecret(previousSecret);
        try {
          if (await FourD4ySession.clearForumSessionCookieNames(
            FourD4ySession.mergeCookieNames(desiredPairs, previousPairs))) {
            await FourD4ySession.writeForumSessionCookiePairs(previousPairs);
          }
        } catch (_rollbackError) {
          // The caller receives failure and presents the normal login path.
        }
      }
      return false;
    }
  }

  /**
   * 4D4Y expects these request-scoped values on full-site endpoints. They are
   * derived from the current signed-in page, added only to the outgoing
   * header, and never written back to ArkWeb's persistent cookie store.
   */
  static createFullSiteCookieHeader(cookieHeader: string, viewerUserId: string, forumId: string): string {
    if (!/^\d+$/.test(viewerUserId)) {
      return '';
    }
    let result: string = cookieHeader;
    if (!/(?:^|;\s*)cdb_uid=/i.test(result)) {
      result = 'cdb_uid=' + viewerUserId + '; ' + result;
    }
    if (/^\d+$/.test(forumId) && !/(?:^|;\s*)cdb_visitedfid=/i.test(result)) {
      result = 'cdb_visitedfid=' + forumId + '; ' + result;
    }
    return result;
  }

  static async getFullSiteCookieHeader(viewerUserId: string, forumId: string): Promise<string> {
    const cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (cookieHeader.length === 0) {
      return '';
    }
    return FourD4ySession.createFullSiteCookieHeader(cookieHeader, viewerUserId, forumId);
  }

  /**
   * Makes an already verified ArkWeb login durable before the user leaves the
   * login page.  ArkWeb otherwise flushes cookies on its own schedule; the
   * value stays entirely inside the Web cookie store.
   */
  static async persistVerifiedAuthentication(): Promise<void> {
    try {
      await webview.WebCookieManager.saveCookieAsync();
    } catch (_error) {
      // A disk flush failure must not invalidate an in-memory authenticated
      // session. The caller has already verified it against the live page.
    }
  }

  /**
   * Completes the native-HTTP -> ArkWeb half of the session bridge.  Only
   * cookies returned by the fixed 4D4Y forum origin are accepted. Values are
   * never exposed to the UI or logs.
   */
  static async acceptNativeResponseCookies(url: string, responseHeaders: Object): Promise<number> {
    if (!/^https:\/\/www\.4d4y\.com\/forum\//i.test(url)) {
      return 0;
    }
    const cookies: string[] = extractFourD4ySetCookieHeaders(responseHeaders);
    let acceptedCount: number = 0;
    for (let index: number = 0; index < cookies.length; index += 1) {
      try {
        await webview.WebCookieManager.configCookie(url, cookies[index], false, true);
        acceptedCount += 1;
      } catch (_error) {
        // A malformed or out-of-scope response cookie must not break the
        // read-only search request. Other independently valid cookies remain.
      }
    }
    if (acceptedCount > 0) {
      try {
        await webview.WebCookieManager.saveCookieAsync();
      } catch (_error) {
        // The in-memory cookie is already usable. A failed disk flush is not
        // evidence that the authenticated server response itself failed.
      }
    }
    return acceptedCount;
  }

  static async clearPersistentAuthentication(): Promise<void> {
    try {
      const currentPairs: FourD4ySessionCookiePair[] =
        FourD4ySession.getSessionCookiePairs(await FourD4ySession.getCookieHeader());
      if (currentPairs.findIndex((pair: FourD4ySessionCookiePair) => pair.name === 'cdb_auth') < 0) {
        currentPairs.push({ name: 'cdb_auth', value: '' });
      }
      if (!await FourD4ySession.clearForumSessionCookieNames(currentPairs.map(
        (pair: FourD4ySessionCookiePair) => pair.name))) {
        throw new Error('4d4y-cookie-clear-failed');
      }
    } catch (_error) {
      throw new Error('4d4y-cookie-clear-failed');
    }
  }

  private static parseAccountSessionSecret(sessionSecret: string): FourD4ySessionCookiePair[] {
    if (sessionSecret.length === 0 || sessionSecret.length > 1024) {
      return [];
    }
    const result: FourD4ySessionCookiePair[] = [];
    const lines: string[] = sessionSecret.split('\n');
    lines.forEach((line: string) => {
      const pair: FourD4ySessionCookiePair | null = FourD4ySession.parseCookiePair(line);
      if (pair !== null && result.findIndex((item: FourD4ySessionCookiePair) => item.name === pair.name) < 0) {
        result.push(pair);
      }
    });
    return result;
  }

  private static getSessionCookiePairs(cookieHeader: string): FourD4ySessionCookiePair[] {
    if (cookieHeader.length === 0 || cookieHeader.length > 4096) {
      return [];
    }
    const result: FourD4ySessionCookiePair[] = [];
    cookieHeader.split(';').forEach((part: string) => {
      const pair: FourD4ySessionCookiePair | null = FourD4ySession.parseCookiePair(part.trim());
      if (pair !== null && /^cdb_[a-z0-9_]{1,64}$/i.test(pair.name) &&
        result.findIndex((item: FourD4ySessionCookiePair) => item.name === pair.name) < 0) {
        result.push(pair);
      }
    });
    return result;
  }

  private static parseCookiePair(value: string): FourD4ySessionCookiePair | null {
    const match: RegExpMatchArray | null = value.match(/^([a-z0-9_]{1,64})=([^;\r\n]{1,700})$/i);
    if (match === null) {
      return null;
    }
    return { name: match[1], value: match[2] };
  }

  private static mergeCookieNames(first: FourD4ySessionCookiePair[], second: FourD4ySessionCookiePair[]): string[] {
    const names: string[] = [];
    first.concat(second).forEach((pair: FourD4ySessionCookiePair) => {
      if (names.indexOf(pair.name) < 0) {
        names.push(pair.name);
      }
    });
    return names;
  }

  private static async clearForumSessionCookieNames(names: string[]): Promise<boolean> {
    const validNames: string[] = names.filter((name: string, index: number) =>
      /^cdb_[a-z0-9_]{1,64}$/i.test(name) && names.indexOf(name) === index);
    try {
      for (let index: number = 0; index < validNames.length; index += 1) {
        const name: string = validNames[index];
        // A cookie can be host-only or domain-scoped, and 4D4Y's legacy
        // endpoints may set it at / or /forum. Deletion needs the same
        // domain/path tuple as creation; clear all four bounded variants.
        await webview.WebCookieManager.configCookie(FourD4ySession.forumRoot,
          name + '=; Max-Age=0; Path=/; Secure; HttpOnly', false, true);
        await webview.WebCookieManager.configCookie(FourD4ySession.forumRoot,
          name + '=; Max-Age=0; Path=/; Domain=.4d4y.com; Secure; HttpOnly', false, true);
        await webview.WebCookieManager.configCookie(FourD4ySession.forumRoot,
          name + '=; Max-Age=0; Path=/forum; Secure; HttpOnly', false, true);
        await webview.WebCookieManager.configCookie(FourD4ySession.forumRoot,
          name + '=; Max-Age=0; Path=/forum; Domain=.4d4y.com; Secure; HttpOnly', false, true);
      }
      await webview.WebCookieManager.saveCookieAsync();
      return true;
    } catch (_error) {
      return false;
    }
  }

  private static async writeForumSessionCookiePairs(pairs: FourD4ySessionCookiePair[]): Promise<boolean> {
    try {
      for (let index: number = 0; index < pairs.length; index += 1) {
        const pair: FourD4ySessionCookiePair = pairs[index];
        await webview.WebCookieManager.configCookie(FourD4ySession.forumRoot,
          pair.name + '=' + pair.value + '; Path=/; Domain=.4d4y.com; Secure; HttpOnly', false, true);
      }
      await webview.WebCookieManager.saveCookieAsync();
      return true;
    } catch (_error) {
      return false;
    }
  }
}

interface FourD4ySessionCookiePair {
  name: string;
  value: string;
}
