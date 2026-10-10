import http from '@ohos.net.http';
import { url } from '@kit.ArkTS';

/** Per-request boundary; HTML and authenticated image hosts have separate policies. */
export class FourD4yNativeRedirectBoundary implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.REDIRECTION;
  private currentUrl: string;
  private blocked: boolean = false;
  private redirectCount: number = 0;
  private readonly allowForumImageHosts: boolean;
  private readonly allowRedirects: boolean;

  constructor(initialUrl: string, allowForumImageHosts: boolean = false, allowRedirects: boolean = true) {
    this.currentUrl = initialUrl;
    this.allowForumImageHosts = allowForumImageHosts;
    this.allowRedirects = allowRedirects;
  }

  attach(request: http.HttpRequest): void {
    if (!this.isAllowed(this.currentUrl)) {
      throw new Error('4d4y-native-origin-rejected');
    }
    try {
      const chain: http.HttpInterceptorChain = new http.HttpInterceptorChain();
      if (chain.addChain([this]) && chain.apply(request)) {
        return;
      }
    } catch (_error) {
      // Do not expose a platform error containing request context. The caller
      // treats an unavailable guard as a failed read, never an unguarded retry.
    }
    this.blocked = true;
    throw new Error('4d4y-native-boundary-unavailable');
  }

  async interceptorHandle(request: http.HttpRequestContext,
    _response: http.HttpResponse): Promise<http.ChainContinue> {
    this.redirectCount += 1;
    try {
      if (!this.allowRedirects || this.blocked || this.redirectCount > 8 || /[\s\\]/.test(request.url)) {
        this.blocked = true;
        return false;
      }
      const target: string = new url.URL(request.url, this.currentUrl).href;
      if (!this.isAllowed(target)) {
        this.blocked = true;
        return false;
      }
      // The API supplies the next target, not the previous response URL.
      // Resolve relative targets explicitly; retain headers/body unchanged.
      request.url = target;
      this.currentUrl = target;
      return true;
    } catch (_error) {
      this.blocked = true;
      return false;
    }
  }

  isResponseAllowed(): boolean {
    return !this.blocked;
  }

  getResponseUrl(): string {
    return this.blocked ? '' : this.currentUrl;
  }

  private isAllowed(value: string): boolean {
    if (value.length === 0 || value.length > 8192 || /[\s\\]/.test(value)) {
      return false;
    }
    try {
      const parsed: url.URL = new url.URL(value);
      const allowedHost: boolean = this.allowForumImageHosts ?
        /^(?:(?:www\.)?4d4y\.com|img\d{2}\.4d4y\.com)$/.test(parsed.hostname) :
        parsed.hostname === 'www.4d4y.com';
      return parsed.protocol === 'https:' && allowedHost &&
        (parsed.port === '' || parsed.port === '443') && parsed.username === '' && parsed.password === '' &&
        (this.allowForumImageHosts || parsed.pathname.startsWith('/forum/'));
    } catch (_error) {
      return false;
    }
  }
}
