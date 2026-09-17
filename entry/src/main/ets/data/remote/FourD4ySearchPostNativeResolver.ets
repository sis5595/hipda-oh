import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4ySearchPostTargetPayload, buildFourD4ySearchPostViewUrl,
  isAllowedFourD4ySearchPostTargetUrl } from '../../domain/search/FourD4ySearchContracts';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';
import { FourD4ySession } from './FourD4ySession';
import { parseFourD4ySearchPostTargetPage } from './FourD4ySearchPostTargetParser';

export type FourD4ySearchPostResolveStatus = 'success' | 'cookie-missing' | 'user-context-missing' |
  'server-login-required' | 'request-failed' | 'unsupported-response' | 'post-unavailable';

export interface FourD4ySearchPostResolveResult {
  status: FourD4ySearchPostResolveStatus;
  payload: FourD4ySearchPostTargetPayload | null;
}

interface FourD4ySearchPostHttpPage {
  status: 'success' | 'request-failed';
  html: string;
  finalUrl: string;
}

/**
 * Resolves a pid through Discuz's read-only single-post `viewpid` response.
 * Current MY 4D4Y uses this endpoint as `getPostHtml`; its `postnum<pid>`
 * marker contains the actual server floor. This avoids treating the one node
 * returned by a mobile `rpid` page as floor 1 and avoids mistaking a missing
 * mobile DOM marker for a permission error. Response cookies cross only the
 * forum session boundary.
 */
export class FourD4ySearchPostNativeResolver {
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('gbk');

  async resolve(threadId: string, postId: string, resolveSequence: number,
    viewerUserId: string, referer: string = FourD4ySession.forumRoot + 'search.php'):
    Promise<FourD4ySearchPostResolveResult> {
    const initialUrl: string | null = buildFourD4ySearchPostViewUrl(threadId, postId);
    if (initialUrl === null || resolveSequence < 1) {
      return this.result('unsupported-response', null);
    }
    if (!/^\d+$/.test(viewerUserId)) {
      return this.result('user-context-missing', null);
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.result('cookie-missing', null);
    }
    cookieHeader = FourD4ySession.createFullSiteCookieHeader(cookieHeader, viewerUserId, '');
    if (cookieHeader.length === 0) {
      return this.result('user-context-missing', null);
    }
    const boundedReferer: string = /^https:\/\/www\.4d4y\.com\/forum\/(?:search|my|notice|pm)\.php(?:\?|$)/i.test(referer) ?
      referer : FourD4ySession.forumRoot;
    const pageResult: FourD4ySearchPostHttpPage = await this.loadPage(initialUrl, cookieHeader, boundedReferer);
    if (pageResult.status !== 'success') {
      return this.result('request-failed', null);
    }
    const payload: FourD4ySearchPostTargetPayload | null = parseFourD4ySearchPostTargetPage(
      pageResult.html, pageResult.finalUrl, threadId, postId, resolveSequence);
    if (payload === null) {
      return this.result('unsupported-response', null);
    }
    if (payload.accessState === 'loginRequired') {
      return this.result('server-login-required', payload);
    }
    if (!payload.postFound || !/^\d+$/.test(payload.threadId)) {
      return this.result('post-unavailable', payload);
    }
    if (payload.floor < 1) {
      return this.result('unsupported-response', payload);
    }
    return this.result('success', payload);
  }

  private async loadPage(url: string, cookieHeader: string, referer: string): Promise<FourD4ySearchPostHttpPage> {
    if (!isAllowedFourD4ySearchPostTargetUrl(url)) {
      return { status: 'request-failed', html: '', finalUrl: '' };
    }
    const requestUrlWithSession: string = appendFourD4ySessionId(url, cookieHeader);
    const fragmentIndex: number = requestUrlWithSession.indexOf('#');
    const requestUrl: string = fragmentIndex < 0 ? requestUrlWithSession :
      requestUrlWithSession.slice(0, fragmentIndex);
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(requestUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 20000,
        maxRedirects: 1,
        header: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Cookie': cookieHeader,
          'Expires': '0',
          'Pragma': 'no-cache',
          'User-Agent': FourD4ySession.fullSiteUserAgent,
          'Referer': referer
        }
      });
      await FourD4ySession.acceptNativeResponseCookies(requestUrl, response.header);
      if (response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer)) {
        return { status: 'request-failed', html: '', finalUrl: '' };
      }
      return {
        status: 'success',
        html: this.decoder.decodeToString(new Uint8Array(response.result)),
        finalUrl: url
      };
    } catch (_error) {
      return { status: 'request-failed', html: '', finalUrl: '' };
    } finally {
      request.destroy();
    }
  }

  private result(status: FourD4ySearchPostResolveStatus,
    payload: FourD4ySearchPostTargetPayload | null): FourD4ySearchPostResolveResult {
    return { status: status, payload: payload };
  }
}
