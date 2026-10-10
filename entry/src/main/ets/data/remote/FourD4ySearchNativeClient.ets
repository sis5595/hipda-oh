import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4ySearchPagePayload, isAllowedFourD4ySearchPageUrl } from '../../domain/search/FourD4ySearchContracts';
import { FourD4ySession } from './FourD4ySession';
import { FourD4yNativeRedirectBoundary } from './FourD4yNativeRedirectBoundary';
import { parseFourD4yNativeSearchPage } from './FourD4ySearchNativeParser';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';

export type FourD4yNativeSearchStatus = 'success' | 'cookie-missing' | 'user-context-missing' |
  'server-login-required' | 'request-failed' | 'unsupported-response';

export interface FourD4yNativeSearchResult {
  status: FourD4yNativeSearchStatus;
  payload: FourD4ySearchPagePayload | null;
}

/**
 * Read-only 4D4Y search transport.
 *
 * ArkWeb owns login and cookie persistence. This client copies the active
 * cookie only into one outgoing request, never logs it, and never writes it
 * to disk. It is intentionally not a fallback for the active mobile reader.
 */
export class FourD4ySearchNativeClient {
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('gbk');

  async load(url: string, loadSequence: number, viewerUserId: string): Promise<FourD4yNativeSearchResult> {
    if (!isAllowedFourD4ySearchPageUrl(url)) {
      return this.result('unsupported-response', null);
    }
    if (!/^\d+$/.test(viewerUserId)) {
      return this.result('user-context-missing', null);
    }
    // Search follows both NG and MY 4D4Y by sending the cookie store as-is.
    // cdb_uid/cdb_visitedfid synthesis belongs only to attachment endpoints;
    // injecting it here changes the authenticated search session contract.
    const cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.result('cookie-missing', null);
    }
    const firstAttempt: FourD4yNativeSearchAttempt = await this.loadOnce(
      appendFourD4ySessionId(url, cookieHeader), loadSequence, cookieHeader);
    if (firstAttempt.result.status !== 'server-login-required' || firstAttempt.acceptedCookieCount === 0) {
      return firstAttempt.result;
    }
    // NG's CookieJar and MY 4D4Y's response interceptor both make a newly
    // returned session cookie available to the next request. Mirror that
    // bounded behavior once; never enter an authentication retry loop.
    const refreshedCookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(refreshedCookieHeader)) {
      return firstAttempt.result;
    }
    return (await this.loadOnce(appendFourD4ySessionId(url, refreshedCookieHeader),
      loadSequence, refreshedCookieHeader)).result;
  }

  private async loadOnce(requestUrl: string, loadSequence: number,
    cookieHeader: string): Promise<FourD4yNativeSearchAttempt> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const boundary: FourD4yNativeRedirectBoundary = new FourD4yNativeRedirectBoundary(requestUrl);
      boundary.attach(request);
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 20000,
        header: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Cookie': cookieHeader,
          'Expires': '0',
          'Pragma': 'no-cache',
          // Keep native search in the same server-side profile as the ArkWeb
          // page that established and just verified this login.
          'User-Agent': FourD4ySession.fullSiteUserAgent,
          'Referer': FourD4ySession.forumRoot + 'search.php'
        }
      });
      if (!boundary.isResponseAllowed() || response.responseCode !== http.ResponseCode.OK ||
        !(response.result instanceof ArrayBuffer)) {
        return this.attempt('request-failed', null, 0);
      }
      const acceptedCookieCount: number = await FourD4ySession.acceptNativeResponseCookies(
        requestUrl, response.header, cookieHeader);
      if (acceptedCookieCount < 0) {
        return this.attempt('request-failed', null, 0);
      }
      const pageHtml: string = this.decoder.decodeToString(new Uint8Array(response.result));
      const payload: FourD4ySearchPagePayload | null = parseFourD4yNativeSearchPage(pageHtml, requestUrl, loadSequence);
      if (payload === null) {
        return this.attempt('unsupported-response', null, acceptedCookieCount);
      }
      return this.attempt(payload.accessState === 'loginRequired' ? 'server-login-required' : 'success',
        payload, acceptedCookieCount);
    } catch (_error) {
      return this.attempt('request-failed', null, 0);
    } finally {
      request.destroy();
    }
  }

  private attempt(status: FourD4yNativeSearchStatus, payload: FourD4ySearchPagePayload | null,
    acceptedCookieCount: number): FourD4yNativeSearchAttempt {
    return { result: this.result(status, payload), acceptedCookieCount: acceptedCookieCount };
  }

  private result(status: FourD4yNativeSearchStatus, payload: FourD4ySearchPagePayload | null): FourD4yNativeSearchResult {
    return { status: status, payload: payload };
  }
}

interface FourD4yNativeSearchAttempt {
  result: FourD4yNativeSearchResult;
  acceptedCookieCount: number;
}
