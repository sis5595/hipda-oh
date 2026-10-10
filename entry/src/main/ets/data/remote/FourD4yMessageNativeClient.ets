import http from '@ohos.net.http';
import util from '@ohos.util';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FourD4yMessagePagePayload, FourD4yMessagePromptPayload,
  isAllowedFourD4yMessagePageUrl } from '../../domain/notice/FourD4yMessageContracts';
import { FourD4yPrivateConversationPayload,
  isAllowedFourD4yPrivateConversationUrl } from
  '../../domain/notice/FourD4yPrivateConversationContracts';
import { appendFourD4ySessionId } from './FourD4yRequestCookieBridge';
import { FourD4ySession } from './FourD4ySession';
import { FourD4yNativeRedirectBoundary } from './FourD4yNativeRedirectBoundary';
import { parseFourD4yNativeMessagePage, parseFourD4yNativeMessagePrompt,
  parseFourD4yUnreadPrivateMessageCount } from
  './FourD4yMessageNativeParser';
import { parseFourD4yPrivateConversationPage } from './FourD4yPrivateConversationNativeParser';
import { classifyFourD4yHttpFailure, classifyFourD4yNetworkFailure,
  FourD4yNativeRequestFailure } from './FourD4yNativeRequestFailure';

const FOUR_D4Y_MESSAGE_LOG_DOMAIN: number = 0x0000;
const FOUR_D4Y_MESSAGE_LOG_TAG: string = 'FourD4yMessage';

export type FourD4yNativeMessageStatus = 'success' | 'cookie-missing' | 'server-login-required' |
  'request-failed' | 'unsupported-response';

export interface FourD4yNativeMessagePageResult {
  status: FourD4yNativeMessageStatus;
  payload: FourD4yMessagePagePayload | null;
  failure: FourD4yNativeRequestFailure | null;
}

export interface FourD4yNativeMessagePromptResult {
  status: FourD4yNativeMessageStatus;
  payload: FourD4yMessagePromptPayload | null;
  failure: FourD4yNativeRequestFailure | null;
}

export interface FourD4yNativePrivateConversationResult {
  status: FourD4yNativeMessageStatus;
  payload: FourD4yPrivateConversationPayload | null;
  failure: FourD4yNativeRequestFailure | null;
}

interface FourD4yNativeMessageAttempt<T> {
  result: T;
  acceptedCookieCount: number;
}

/**
 * Read-only native transport for message lists, prompt counters and the
 * normal PM conversation GET view. No send, delete or clear endpoint is
 * accepted here. The forum itself may mark an unread message as read when its
 * conversation page is opened, exactly as it does for NG and MY 4D4Y.
 */
export class FourD4yMessageNativeClient {
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('gbk');
  private readonly promptUrl: string = 'https://www.4d4y.com/forum/pm.php?filter=newpm';

  async loadPage(url: string, loadSequence: number): Promise<FourD4yNativeMessagePageResult> {
    if (!isAllowedFourD4yMessagePageUrl(url) || loadSequence < 1) {
      return this.pageResult('unsupported-response', null);
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.pageResult('cookie-missing', null);
    }
    const firstAttempt: FourD4yNativeMessageAttempt<FourD4yNativeMessagePageResult> =
      await this.loadPageOnce(url, loadSequence, cookieHeader);
    if (firstAttempt.result.status !== 'server-login-required' || firstAttempt.acceptedCookieCount === 0) {
      return firstAttempt.result;
    }
    cookieHeader = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return firstAttempt.result;
    }
    return (await this.loadPageOnce(url, loadSequence, cookieHeader)).result;
  }

  async loadPrompt(loadSequence: number): Promise<FourD4yNativeMessagePromptResult> {
    if (loadSequence < 1) {
      return this.promptResult('unsupported-response', null);
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.promptResult('cookie-missing', null);
    }
    const firstAttempt: FourD4yNativeMessageAttempt<FourD4yNativeMessagePromptResult> =
      await this.loadPromptOnce(loadSequence, cookieHeader);
    if (firstAttempt.result.status !== 'server-login-required' || firstAttempt.acceptedCookieCount === 0) {
      return firstAttempt.result;
    }
    cookieHeader = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return firstAttempt.result;
    }
    return (await this.loadPromptOnce(loadSequence, cookieHeader)).result;
  }

  async loadPrivateConversation(url: string,
    loadSequence: number): Promise<FourD4yNativePrivateConversationResult> {
    if (!isAllowedFourD4yPrivateConversationUrl(url) || loadSequence < 1) {
      return this.conversationResult('unsupported-response', null);
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.conversationResult('cookie-missing', null);
    }
    const firstAttempt: FourD4yNativeMessageAttempt<FourD4yNativePrivateConversationResult> =
      await this.loadPrivateConversationOnce(url, loadSequence, cookieHeader);
    if (firstAttempt.result.status !== 'server-login-required' || firstAttempt.acceptedCookieCount === 0) {
      return firstAttempt.result;
    }
    cookieHeader = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return firstAttempt.result;
    }
    return (await this.loadPrivateConversationOnce(url, loadSequence, cookieHeader)).result;
  }

  private async loadPageOnce(url: string, loadSequence: number,
    cookieHeader: string): Promise<FourD4yNativeMessageAttempt<FourD4yNativeMessagePageResult>> {
    const response: FourD4yNativeHtmlResponse = await this.requestHtml(url, cookieHeader, FourD4ySession.forumRoot);
    if (response.status !== 'success') {
      return this.pageAttempt('request-failed', null, 0, response.failure);
    }
    const payload: FourD4yMessagePagePayload | null = parseFourD4yNativeMessagePage(
      response.html, url, loadSequence);
    if (payload === null) {
      return this.pageAttempt('unsupported-response', null, response.acceptedCookieCount);
    }
    return this.pageAttempt(payload.accessState === 'loginRequired' ? 'server-login-required' : 'success',
      payload, response.acceptedCookieCount);
  }

  private async loadPromptOnce(loadSequence: number,
    cookieHeader: string): Promise<FourD4yNativeMessageAttempt<FourD4yNativeMessagePromptResult>> {
    const response: FourD4yNativeHtmlResponse = await this.requestHtml(this.promptUrl, cookieHeader,
      FourD4ySession.forumRoot);
    if (response.status !== 'success') {
      return this.promptAttempt('request-failed', null, 0, response.failure);
    }
    const payload: FourD4yMessagePromptPayload | null = parseFourD4yNativeMessagePrompt(response.html, loadSequence);
    if (payload === null) {
      return this.promptAttempt('unsupported-response', null, response.acceptedCookieCount);
    }
    if (payload.accessState !== 'loginRequired') {
      const unreadCount: number | null = parseFourD4yUnreadPrivateMessageCount(response.html);
      if (unreadCount === null) return this.promptAttempt('unsupported-response', null, response.acceptedCookieCount);
      payload.privateMessageCount = unreadCount;
    }
    return this.promptAttempt(payload.accessState === 'loginRequired' ? 'server-login-required' : 'success',
      payload, response.acceptedCookieCount);
  }

  private async loadPrivateConversationOnce(url: string, loadSequence: number,
    cookieHeader: string): Promise<FourD4yNativeMessageAttempt<FourD4yNativePrivateConversationResult>> {
    const response: FourD4yNativeHtmlResponse = await this.requestHtml(url, cookieHeader, FourD4ySession.forumRoot);
    if (response.status !== 'success') {
      return this.conversationAttempt('request-failed', null, 0, response.failure);
    }
    const payload: FourD4yPrivateConversationPayload | null = parseFourD4yPrivateConversationPage(
      response.html, url, loadSequence);
    if (payload === null) {
      return this.conversationAttempt('unsupported-response', null, response.acceptedCookieCount);
    }
    return this.conversationAttempt(payload.accessState === 'loginRequired' ? 'server-login-required' : 'success',
      payload, response.acceptedCookieCount);
  }

  private async requestHtml(url: string, cookieHeader: string, referer: string): Promise<FourD4yNativeHtmlResponse> {
    const requestUrl: string = appendFourD4ySessionId(url, cookieHeader);
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
      if (!boundary.isResponseAllowed() || response.responseCode !== http.ResponseCode.OK ||
        !(response.result instanceof ArrayBuffer)) {
        const failure: FourD4yNativeRequestFailure = classifyFourD4yHttpFailure(
          response.responseCode, response.result instanceof ArrayBuffer);
        hilog.warn(FOUR_D4Y_MESSAGE_LOG_DOMAIN, FOUR_D4Y_MESSAGE_LOG_TAG,
          'Native message request failed: HTTP=%{public}d failure=%{public}s',
          response.responseCode, failure.kind);
        return { status: 'request-failed', html: '', acceptedCookieCount: 0, failure: failure };
      }
      const acceptedCookieCount: number = await FourD4ySession.acceptNativeResponseCookies(
        requestUrl, response.header, cookieHeader);
      if (acceptedCookieCount < 0) {
        return { status: 'request-failed', html: '', acceptedCookieCount: 0, failure: null };
      }
      return {
        status: 'success',
        html: this.decoder.decodeToString(new Uint8Array(response.result)),
        acceptedCookieCount: acceptedCookieCount,
        failure: null
      };
    } catch (error) {
      const failure: FourD4yNativeRequestFailure = classifyFourD4yNetworkFailure(
        (error as BusinessError).code);
      hilog.warn(FOUR_D4Y_MESSAGE_LOG_DOMAIN, FOUR_D4Y_MESSAGE_LOG_TAG,
        'Native message request failed: error=%{public}d failure=%{public}s',
        failure.networkErrorCode, failure.kind);
      return { status: 'request-failed', html: '', acceptedCookieCount: 0, failure: failure };
    } finally {
      request.destroy();
    }
  }

  private pageAttempt(status: FourD4yNativeMessageStatus, payload: FourD4yMessagePagePayload | null,
    acceptedCookieCount: number, failure: FourD4yNativeRequestFailure | null = null):
    FourD4yNativeMessageAttempt<FourD4yNativeMessagePageResult> {
    return { result: this.pageResult(status, payload, failure), acceptedCookieCount: acceptedCookieCount };
  }

  private promptAttempt(status: FourD4yNativeMessageStatus, payload: FourD4yMessagePromptPayload | null,
    acceptedCookieCount: number, failure: FourD4yNativeRequestFailure | null = null):
    FourD4yNativeMessageAttempt<FourD4yNativeMessagePromptResult> {
    return { result: this.promptResult(status, payload, failure), acceptedCookieCount: acceptedCookieCount };
  }

  private conversationAttempt(status: FourD4yNativeMessageStatus,
    payload: FourD4yPrivateConversationPayload | null,
    acceptedCookieCount: number, failure: FourD4yNativeRequestFailure | null = null):
    FourD4yNativeMessageAttempt<FourD4yNativePrivateConversationResult> {
    return { result: this.conversationResult(status, payload, failure), acceptedCookieCount: acceptedCookieCount };
  }

  private pageResult(status: FourD4yNativeMessageStatus,
    payload: FourD4yMessagePagePayload | null,
    failure: FourD4yNativeRequestFailure | null = null): FourD4yNativeMessagePageResult {
    return { status: status, payload: payload, failure: failure };
  }

  private promptResult(status: FourD4yNativeMessageStatus,
    payload: FourD4yMessagePromptPayload | null,
    failure: FourD4yNativeRequestFailure | null = null): FourD4yNativeMessagePromptResult {
    return { status: status, payload: payload, failure: failure };
  }

  private conversationResult(status: FourD4yNativeMessageStatus,
    payload: FourD4yPrivateConversationPayload | null,
    failure: FourD4yNativeRequestFailure | null = null): FourD4yNativePrivateConversationResult {
    return { status: status, payload: payload, failure: failure };
  }
}

interface FourD4yNativeHtmlResponse {
  status: 'success' | 'request-failed';
  html: string;
  acceptedCookieCount: number;
  failure: FourD4yNativeRequestFailure | null;
}
