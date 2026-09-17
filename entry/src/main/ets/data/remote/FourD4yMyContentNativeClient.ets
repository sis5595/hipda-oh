import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4yMyContentPagePayload, isAllowedFourD4yMyContentUrl } from
  '../../domain/mine/FourD4yMyContentContracts';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';
import { FourD4ySession } from './FourD4ySession';
import { parseFourD4yNativeMyContentPage } from './FourD4yMyContentNativeParser';

export type FourD4yNativeMyContentStatus = 'success' | 'cookie-missing' | 'server-login-required' |
  'request-failed' | 'unsupported-response';

export interface FourD4yNativeMyContentResult {
  status: FourD4yNativeMyContentStatus;
  payload: FourD4yMyContentPagePayload | null;
}

interface FourD4yNativeMyContentAttempt {
  result: FourD4yNativeMyContentResult;
  acceptedCookieCount: number;
}

/** Read-only native transport for the authenticated my.php lists. */
export class FourD4yMyContentNativeClient {
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('gbk');

  async load(url: string, loadSequence: number): Promise<FourD4yNativeMyContentResult> {
    if (!isAllowedFourD4yMyContentUrl(url) || loadSequence < 1) {
      return this.result('unsupported-response', null);
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.result('cookie-missing', null);
    }
    const firstAttempt: FourD4yNativeMyContentAttempt = await this.loadOnce(url, loadSequence, cookieHeader);
    if (firstAttempt.result.status !== 'server-login-required' || firstAttempt.acceptedCookieCount === 0) {
      return firstAttempt.result;
    }
    // Mirror NG/MY cookie-jar behavior once when the server rotates a cookie.
    cookieHeader = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return firstAttempt.result;
    }
    return (await this.loadOnce(url, loadSequence, cookieHeader)).result;
  }

  private async loadOnce(url: string, loadSequence: number,
    cookieHeader: string): Promise<FourD4yNativeMyContentAttempt> {
    const requestUrl: string = appendFourD4ySessionId(url, cookieHeader);
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 20000,
        header: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Cookie': cookieHeader,
          'Expires': '0',
          'Pragma': 'no-cache',
          'User-Agent': FourD4ySession.fullSiteUserAgent,
          'Referer': FourD4ySession.forumRoot
        }
      });
      if (response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer)) {
        return this.attempt('request-failed', null, 0);
      }
      const acceptedCookieCount: number = await FourD4ySession.acceptNativeResponseCookies(
        requestUrl, response.header);
      const html: string = this.decoder.decodeToString(new Uint8Array(response.result));
      const payload: FourD4yMyContentPagePayload | null = parseFourD4yNativeMyContentPage(
        html, url, loadSequence);
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

  private attempt(status: FourD4yNativeMyContentStatus, payload: FourD4yMyContentPagePayload | null,
    acceptedCookieCount: number): FourD4yNativeMyContentAttempt {
    return { result: this.result(status, payload), acceptedCookieCount: acceptedCookieCount };
  }

  private result(status: FourD4yNativeMyContentStatus,
    payload: FourD4yMyContentPagePayload | null): FourD4yNativeMyContentResult {
    return { status: status, payload: payload };
  }
}
