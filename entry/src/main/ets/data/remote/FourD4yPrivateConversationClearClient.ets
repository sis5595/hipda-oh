import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4ySession } from './FourD4ySession';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';
import { FourD4yNativeRedirectBoundary } from './FourD4yNativeRedirectBoundary';
import { extractFourD4yPrivateConversationClearUrl, isConfirmedFourD4yEmptyPrivateConversation,
  parseFourD4yPrivateConversationPage } from
  './FourD4yPrivateConversationNativeParser';
import { buildFourD4yPrivateConversationUrl, FourD4yPrivateConversationReaderOutcome,
  getFourD4yPrivateConversationReaderOutcome } from '../../domain/notice/FourD4yPrivateConversationContracts';

export type FourD4yPrivateConversationClearResult = 'confirmed' | 'unconfirmed' | 'not-started' | 'cancelled';

/** Explicit destructive transport. Read-only PM clients never accept this endpoint. */
export class FourD4yPrivateConversationClearClient {
  private busy: boolean = false;
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('gbk');

  async clear(participantUserId: string, viewerUserId: string,
    isCurrent: () => boolean): Promise<FourD4yPrivateConversationClearResult> {
    const viewUrl: string | null = buildFourD4yPrivateConversationUrl(participantUserId);
    if (this.busy || viewUrl === null || !/^[1-9]\d{0,15}$/.test(viewerUserId) ||
      viewerUserId === participantUserId || !isCurrent()) return 'not-started';
    this.busy = true;
    try {
      const cookie: string = await FourD4ySession.getCookieHeader();
      if (!isCurrent() || !FourD4ySession.hasAuthenticationCookie(cookie)) return 'not-started';
      // Fresh preflight under the exact same captured authentication as the write.
      const html: string | null = await this.request(viewUrl, cookie, true);
      if (!isCurrent()) return 'cancelled';
      if (html === null) return 'not-started';
      const payload = parseFourD4yPrivateConversationPage(html, viewUrl, 1);
      const clearUrl: string = extractFourD4yPrivateConversationClearUrl(html, participantUserId);
      if (payload === null || payload.viewerUserId !== viewerUserId || clearUrl.length === 0 ||
        getFourD4yPrivateConversationReaderOutcome(payload) !== FourD4yPrivateConversationReaderOutcome.Content) {
        return 'not-started';
      }
      const snapshot: string | null = FourD4ySession.createAccountSessionSecret(cookie);
      if (snapshot === null || !await FourD4ySession.isCurrentAccountSessionSecret(snapshot) || !isCurrent()) {
        return 'cancelled';
      }
      // One GET only. No retry and no redirect that could repeat or change the mutation.
      await this.request(clearUrl, cookie, false);
      if (!isCurrent()) return 'cancelled';
      if (!await FourD4ySession.isCurrentAccountSessionSecret(snapshot) || !isCurrent()) return 'cancelled';
      // A lost success response is uncertain, not permission to send the delete again.
      const after: string | null = await this.request(viewUrl, cookie, true);
      if (!isCurrent()) return 'cancelled';
      if (after === null) return 'unconfirmed';
      const verified = parseFourD4yPrivateConversationPage(after, viewUrl, 2);
      return verified !== null && verified.viewerUserId === viewerUserId &&
        getFourD4yPrivateConversationReaderOutcome(verified) === FourD4yPrivateConversationReaderOutcome.Empty &&
        isConfirmedFourD4yEmptyPrivateConversation(after) ?
        'confirmed' : 'unconfirmed';
    } catch (_error) {
      return isCurrent() ? 'unconfirmed' : 'cancelled';
    } finally {
      this.busy = false;
    }
  }

  private async request(target: string, cookie: string, allowRedirects: boolean): Promise<string | null> {
    const request = http.createHttp();
    const requestUrl: string = appendFourD4ySessionId(target, cookie);
    try {
      const boundary = new FourD4yNativeRedirectBoundary(requestUrl, false, allowRedirects);
      boundary.attach(request);
      const response = await request.request(requestUrl, {
        method: http.RequestMethod.GET, expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false, maxLimit: 4 * 1024 * 1024, connectTimeout: 20000, readTimeout: 20000,
        header: { 'Cookie': cookie, 'User-Agent': FourD4ySession.fullSiteUserAgent,
          'Referer': FourD4ySession.forumRoot, 'Cache-Control': 'no-cache, no-store' }
      });
      if (!boundary.isResponseAllowed() || boundary.getResponseUrl() !== requestUrl ||
        response.responseCode !== http.ResponseCode.OK ||
        !(response.result instanceof ArrayBuffer) ||
        await FourD4ySession.acceptNativeResponseCookies(requestUrl, response.header, cookie) < 0) return null;
      return this.decoder.decodeToString(new Uint8Array(response.result));
    } catch (_error) {
      return null;
    } finally {
      request.destroy();
    }
  }
}
