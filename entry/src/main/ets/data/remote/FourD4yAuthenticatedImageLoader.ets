import { image } from '@kit.ImageKit';
import http from '@ohos.net.http';
import { FourD4ySession } from './FourD4ySession';

export type FourD4yAuthenticatedImageLoadStatus =
  'success' | 'unsupported-url' | 'session-missing' | 'request-failed' | 'decode-failed';

export interface FourD4yAuthenticatedImageLoadResult {
  status: FourD4yAuthenticatedImageLoadStatus;
  pixelMap: image.PixelMap | undefined;
}

/** Original attachment bytes for an explicit reader action such as save/share. */
export interface FourD4yAuthenticatedImageBinaryResult {
  status: FourD4yAuthenticatedImageLoadStatus;
  bytes: ArrayBuffer | undefined;
}

/**
 * Loads a full-size 4D4Y attachment image through the already-authenticated
 * forum session. ArkUI's Image(URL) has a separate network stack and does not
 * send ArkWeb's forum cookies, so it cannot reliably read attachment.php.
 *
 * The response is decoded directly from memory for the active viewer only:
 * no cookies or image bytes are logged, persisted, or added to a shared cache.
 */
export class FourD4yAuthenticatedImageLoader {
  private static readonly maxImageBytes: number = 32 * 1024 * 1024;

  static isAuthenticatedAttachmentUrl(url: string): boolean {
    // The browser may end up on either the canonical www host or the bare
    // host. Both are the same first-party forum origin. Keep the endpoint
    // narrow: cookies must never be attached to a generic image URL.
    return /^https?:\/\/(?:(?:www\.)?4d4y\.com|img\d{2}\.4d4y\.com)\/forum\/attachment\.php\?(?=[^\s#]*\baid=\d{1,20}(?:[&#]|$))[^\s#]{1,2048}$/i.test(url);
  }

  private static getSecureAttachmentUrl(url: string): string {
    // The forum is served over HTTPS. Upgrade a legacy HTTP attribute before
    // sending the authenticated request so a session cookie is never sent over
    // clear text. The host/path was already restricted above.
    return url.replace(/^http:\/\//i, 'https://');
  }

  async load(url: string, threadId: string, viewerUserId: string,
    forumId: string): Promise<FourD4yAuthenticatedImageLoadResult> {
    const binary: FourD4yAuthenticatedImageBinaryResult = await this.download(url, threadId, viewerUserId, forumId);
    if (binary.bytes === undefined) {
      return this.result(binary.status);
    }

    let imageSource: image.ImageSource | undefined = undefined;
    try {
      imageSource = image.createImageSource(binary.bytes);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();
      return { status: 'success', pixelMap: pixelMap };
    } catch (_error) {
      return this.result('decode-failed');
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (_error) {
          // The decoded PixelMap remains usable. Release failure is not user-visible.
        }
      }
    }
  }

  /**
   * Reads an original attachment through the already authenticated forum
   * session. The returned buffer is transient and is never logged or cached
   * by this transport; the caller owns any user-initiated export file.
   */
  async download(url: string, threadId: string, viewerUserId: string,
    forumId: string): Promise<FourD4yAuthenticatedImageBinaryResult> {
    if (!FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(url) ||
      !/^\d{1,20}$/.test(threadId)) {
      return this.binaryResult('unsupported-url');
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!FourD4ySession.hasAuthenticationCookie(cookieHeader)) {
      return this.binaryResult('session-missing');
    }
    // NG's image transport uses the authenticated cookie jar as its actual
    // prerequisite. A mobile page may omit the viewer UID even though the
    // session remains valid, so UID-derived values are an optional supplement
    // rather than a reason to downgrade to an unauthenticated direct image.
    if (/^\d{1,20}$/.test(viewerUserId)) {
      cookieHeader = FourD4ySession.createFullSiteCookieHeader(cookieHeader, viewerUserId, forumId);
    }

    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(
        FourD4yAuthenticatedImageLoader.getSecureAttachmentUrl(url), {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 30000,
        header: {
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cookie': cookieHeader,
          'Referer': FourD4ySession.forumRoot + 'viewthread.php?tid=' + threadId,
          'User-Agent': FourD4ySession.fullSiteUserAgent
        }
      });
      if (response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > FourD4yAuthenticatedImageLoader.maxImageBytes) {
        return this.binaryResult('request-failed');
      }
      return { status: 'success', bytes: response.result };
    } catch (_error) {
      return this.binaryResult('request-failed');
    } finally {
      request.destroy();
    }
  }

  private result(status: FourD4yAuthenticatedImageLoadStatus): FourD4yAuthenticatedImageLoadResult {
    return { status: status, pixelMap: undefined };
  }

  private binaryResult(status: FourD4yAuthenticatedImageLoadStatus): FourD4yAuthenticatedImageBinaryResult {
    return { status: status, bytes: undefined };
  }
}
