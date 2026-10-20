import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4ySearchPostTargetPayload, buildFourD4ySearchPostViewUrl,
  buildFourD4ySearchPostTargetUrl, isAllowedFourD4ySearchPostTargetUrl } from '../../domain/search/FourD4ySearchContracts';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';
import { FourD4ySession } from './FourD4ySession';
import { FourD4yNativeRedirectBoundary } from './FourD4yNativeRedirectBoundary';
import { extractFourD4ySearchPostRefreshUrl, parseFourD4ySearchPostTargetPage } from './FourD4ySearchPostTargetParser';

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
    viewerUserId: string, referer: string = FourD4ySession.forumRoot + 'search.php',
    openNotice: boolean = false):
    Promise<FourD4ySearchPostResolveResult> {
    let initialUrl: string | null = threadId.length > 0 ? buildFourD4ySearchPostViewUrl(threadId, postId) :
      buildFourD4ySearchPostTargetUrl('', postId);
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
    if (threadId.length === 0) {
      // Full-text rows may expose only PID. Discover the owning topic once,
      // then use the same exact viewpid verification as My Replies. A redirect
      // destination is a hint, never proof of post existence or floor number.
      const discovery: FourD4ySearchPostHttpPage = await this.loadPage(initialUrl, cookieHeader, boundedReferer);
      if (discovery.status !== 'success') {
        return this.result('request-failed', null);
      }
      const discovered: FourD4ySearchPostTargetPayload | null = parseFourD4ySearchPostTargetPage(
        discovery.html, discovery.finalUrl, '', postId, resolveSequence);
      if (discovered !== null && discovered.accessState === 'loginRequired') {
        return this.result('server-login-required', discovered);
      }
      const refreshUrl: string = extractFourD4ySearchPostRefreshUrl(discovery.html);
      const refreshTopic: RegExpMatchArray | null = refreshUrl.match(
        /^https:\/\/www\.4d4y\.com\/forum\/viewthread\.php\?[^#]*\btid=(\d+)(?:[&#]|$)/i);
      const destinationTopic: RegExpMatchArray | null = discovery.finalUrl.match(
        /^https:\/\/www\.4d4y\.com\/forum\/viewthread\.php\?[^#]*\btid=(\d+)(?:[&#]|$)/i);
      // gotopost may return the owning topic's first post rather than the
      // requested post. Only a guarded destination/meta-refresh is a hint;
      // the second request must still prove PID and server floor together.
      const discoveredThreadId: string = destinationTopic !== null ? destinationTopic[1] :
        refreshTopic !== null ? refreshTopic[1] :
        (discovered !== null && discovered.postFound ? discovered.threadId : '');
      initialUrl = buildFourD4ySearchPostViewUrl(discoveredThreadId, postId);
      if (initialUrl === null) {
        return this.result(discovered !== null && discovered.errorMessage.length > 0 ?
          'post-unavailable' : 'unsupported-response', discovered);
      }
      if (!await FourD4ySession.isCurrentAccountSessionSecret(cookieHeader)) {
        return this.result('request-failed', null);
      }
      threadId = discoveredThreadId;
    }
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
    if (openNotice) {
      // NG opens findpost for reminders. Discuz also resets the followed
      // topic's pending replies there; viewpid alone only resolves a floor.
      // Verify the exact PID first, and keep this side effect out of searches.
      const noticeUrl: string | null = buildFourD4ySearchPostTargetUrl(threadId, postId);
      if (noticeUrl === null || !await FourD4ySession.isCurrentAccountSessionSecret(cookieHeader)) {
        return this.result('request-failed', null);
      }
      const opened: FourD4ySearchPostHttpPage = await this.loadPage(noticeUrl, cookieHeader, boundedReferer);
      if (opened.status !== 'success' || !await FourD4ySession.isCurrentAccountSessionSecret(cookieHeader)) {
        return this.result('request-failed', null);
      }
      const openedPayload: FourD4ySearchPostTargetPayload | null = parseFourD4ySearchPostTargetPage(
        opened.html, opened.finalUrl, threadId, postId, resolveSequence);
      if (openedPayload !== null && openedPayload.accessState === 'loginRequired') {
        return this.result('server-login-required', openedPayload);
      }
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
      const boundary: FourD4yNativeRedirectBoundary = new FourD4yNativeRedirectBoundary(requestUrl);
      boundary.attach(request);
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
      if (!boundary.isResponseAllowed()) {
        return { status: 'request-failed', html: '', finalUrl: '' };
      }
      const acceptedCookieCount: number = await FourD4ySession.acceptNativeResponseCookies(
        requestUrl, response.header, cookieHeader);
      if (acceptedCookieCount < 0) {
        return { status: 'request-failed', html: '', finalUrl: '' };
      }
      if (response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer)) {
        return { status: 'request-failed', html: '', finalUrl: '' };
      }
      return {
        status: 'success',
        html: this.decoder.decodeToString(new Uint8Array(response.result)),
        finalUrl: boundary.getResponseUrl()
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
