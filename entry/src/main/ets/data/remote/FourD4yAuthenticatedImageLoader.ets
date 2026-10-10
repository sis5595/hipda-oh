import { image } from '@kit.ImageKit';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { FourD4ySession } from './FourD4ySession';
import { FourD4yNativeRedirectBoundary } from './FourD4yNativeRedirectBoundary';
import { planFourD4yImageDecode, FourD4yImageDecodeSize } from '../../domain/reader/FourD4yImageDecodePolicy';

export type FourD4yAuthenticatedImageLoadStatus =
  'success' | 'unsupported-url' | 'session-missing' | 'request-failed' | 'decode-failed';

export interface FourD4yAuthenticatedImageLoadResult {
  status: FourD4yAuthenticatedImageLoadStatus;
  pixelMap: image.PixelMap | undefined;
  scaledPreview?: boolean;
  animatedPath?: string;
  staticPreview?: boolean;
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
 * Originals are decoded only for the active viewer. Public images use the
 * same memory budget, with no forum headers. Small public animations use
 * transient validated-byte files to preserve animation; they are never shared
 * or logged and are deleted on release or cleaned after a process restart.
 */
export class FourD4yAuthenticatedImageLoader {
  private static readonly maxImageBytes: number = 32 * 1024 * 1024;
  private static loadTail: Promise<void> = Promise.resolve();
  private activeRequest: http.HttpRequest | undefined = undefined;
  private static animationSequence: number = 0;
  private static readonly animationProcessStarted: number = Date.now();
  private static animationCleanup: Promise<void> | undefined = undefined;
  private readonly ownedAnimations: Set<string> = new Set<string>();

  releaseAnimation(path: string): void {
    if (!this.ownedAnimations.delete(path)) return;
    fs.unlink(path).catch(() => {});
  }

  private static async cleanupOldAnimations(cacheDir: string): Promise<void> {
    if (cacheDir.length <= 1 || !cacheDir.startsWith('/') || cacheDir.includes('\\') ||
      cacheDir.split('/').some((part: string) => part === '.' || part === '..')) return;
    try {
      const names: string[] = await fs.listFile(cacheDir, { recursion: false });
      let removed: number = 0;
      for (const name of names) {
        const match: RegExpExecArray | null = /^hipdaoh-image-animation-(\d{13})-([1-9]\d{0,9})\.(gif|webp)$/.exec(name);
        if (match === null || Number(match[1]) >= FourD4yAuthenticatedImageLoader.animationProcessStarted) continue;
        if (removed++ >= 64) break;
        // These files are never shared/exported. A previous process cannot
        // still be rendering them; unlink only exact app-created basenames.
        try { await fs.unlink(cacheDir + '/' + name); } catch (_error) {}
      }
    } catch (_error) {}
  }

  cancelActiveDownload(): void {
    const request: http.HttpRequest | undefined = this.activeRequest;
    this.activeRequest = undefined;
    if (request !== undefined) {
      try {
        request.destroy();
      } catch (_error) {
        // The request may have completed before the gallery moved on.
      }
    }
  }

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
    forumId: string, isCurrent: () => boolean = () => true,
    cacheDir: string = ''): Promise<FourD4yAuthenticatedImageLoadResult> {
    // Queue before downloading, not after: an uncancellable native decode may
    // take time, and fast swipes must not queue many 32 MB buffers behind it.
    // Obsolete entries carry only URLs and skip all work when their turn comes.
    const result: Promise<FourD4yAuthenticatedImageLoadResult> =
      FourD4yAuthenticatedImageLoader.loadTail.then(() =>
        this.loadCurrentImage(url, threadId, viewerUserId, forumId, isCurrent, cacheDir));
    FourD4yAuthenticatedImageLoader.loadTail = result.then(() => {}, () => {});
    return result;
  }

  private async loadCurrentImage(url: string, threadId: string, viewerUserId: string,
    forumId: string, isCurrent: () => boolean, cacheDir: string): Promise<FourD4yAuthenticatedImageLoadResult> {
    if (!isCurrent()) {
      return this.result('request-failed');
    }
    const authenticated: boolean = FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(url);
    const binary: FourD4yAuthenticatedImageBinaryResult = authenticated ?
      await this.download(url, threadId, viewerUserId, forumId, isCurrent) :
      await this.downloadPublic(url, isCurrent);
    if (binary.bytes === undefined || !isCurrent()) {
      return this.result(binary.bytes === undefined ? binary.status : 'request-failed');
    }
    const bytes: ArrayBuffer = binary.bytes;
    // The decode policy, not queueing, decides whether a huge image needs a preview.
    return this.decodeCurrentImage(bytes, isCurrent, authenticated ? undefined : cacheDir);
  }

  private async decodeCurrentImage(bytes: ArrayBuffer,
    isCurrent: () => boolean, publicCacheDir?: string): Promise<FourD4yAuthenticatedImageLoadResult> {
    if (!isCurrent()) {
      return this.result('request-failed');
    }
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      imageSource = image.createImageSource(bytes);
      const info: image.ImageInfo = await imageSource.getImageInfo();
      if (!isCurrent()) return this.result('request-failed');
      const plan: FourD4yImageDecodeSize | undefined = planFourD4yImageDecode(info.size.width, info.size.height);
      if (plan === undefined) return this.result('decode-failed');
      let staticPreview: boolean = false;
      if (publicCacheDir !== undefined) {
        const frames: number = await imageSource.getFrameCount();
        if (!isCurrent()) return this.result('request-failed');
        if (!Number.isSafeInteger(frames) || frames < 1) return this.result('decode-failed');
        if (frames > 1) {
          // Preserve ordinary animations using the validated bytes, not a
          // second network fetch that could return different/unbounded data.
          if (!plan.scaledPreview && frames * info.size.width * info.size.height <= 32 * 1024 * 1024 &&
            bytes.byteLength <= 4 * 1024 * 1024 &&
            (info.mimeType === 'image/gif' || info.mimeType === 'image/webp')) {
            return this.prepareAnimation(bytes, info.mimeType === 'image/gif' ? 'gif' : 'webp',
              publicCacheDir, isCurrent);
          }
          staticPreview = true;
        }
      }
      // Ask the decoder for the smaller output, never decode full-size first
      // then scale it. A failed preview must not retry an unbounded full decode.
      const pixelMap: image.PixelMap = plan.scaledPreview ? await imageSource.createPixelMap({
        desiredSize: { width: plan.width, height: plan.height },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredDynamicRange: image.DecodingDynamicRange.SDR
      }) : await imageSource.createPixelMap();
      if (!isCurrent()) {
        await pixelMap.release();
        return this.result('request-failed');
      }
      return { status: 'success', pixelMap: pixelMap, scaledPreview: plan.scaledPreview,
        staticPreview: staticPreview };
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

  private async prepareAnimation(bytes: ArrayBuffer, extension: string, cacheDir: string,
    isCurrent: () => boolean): Promise<FourD4yAuthenticatedImageLoadResult> {
    if (cacheDir.length === 0 || !isCurrent()) return this.result('request-failed');
    if (FourD4yAuthenticatedImageLoader.animationCleanup === undefined) {
      FourD4yAuthenticatedImageLoader.animationCleanup = FourD4yAuthenticatedImageLoader.cleanupOldAnimations(cacheDir);
    }
    await FourD4yAuthenticatedImageLoader.animationCleanup;
    if (!isCurrent()) return this.result('request-failed');
    const path: string = cacheDir + '/hipdaoh-image-animation-' + Date.now() + '-' +
      (++FourD4yAuthenticatedImageLoader.animationSequence) + '.' + extension;
    let file: fs.File | undefined = undefined;
    this.ownedAnimations.add(path);
    try {
      file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const written: number = await fs.write(file.fd, bytes);
      await fs.close(file);
      file = undefined;
      if (written !== bytes.byteLength || !isCurrent()) throw new Error('animation-canceled');
      return { status: 'success', pixelMap: undefined, animatedPath: path };
    } catch (_error) {
      if (file !== undefined) {
        try { await fs.close(file); } catch (_closeError) {}
      }
      this.releaseAnimation(path);
      return this.result('request-failed');
    }
  }

  private async downloadPublic(url: string,
    isCurrent: () => boolean): Promise<FourD4yAuthenticatedImageBinaryResult> {
    if (!/^https?:\/\/[^\s<>]{1,2048}$/i.test(url) || !isCurrent()) {
      return this.binaryResult('unsupported-url');
    }
    const request: http.HttpRequest = http.createHttp();
    this.activeRequest = request;
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 30000,
        maxLimit: FourD4yAuthenticatedImageLoader.maxImageBytes,
        // Never attach forum cookies, referer or user-specific headers here.
        header: { 'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8' }
      });
      if (!isCurrent() || response.responseCode !== http.ResponseCode.OK ||
        !(response.result instanceof ArrayBuffer) || response.result.byteLength === 0 ||
        response.result.byteLength > FourD4yAuthenticatedImageLoader.maxImageBytes) {
        return this.binaryResult('request-failed');
      }
      return { status: 'success', bytes: response.result };
    } catch (_error) {
      return this.binaryResult('request-failed');
    } finally {
      if (this.activeRequest === request) this.activeRequest = undefined;
      try { request.destroy(); } catch (_error) {}
    }
  }

  /**
   * Reads an original attachment through the already authenticated forum
   * session. The returned buffer is transient and is never logged or cached
   * by this transport; the caller owns any user-initiated export file.
   */
  async download(url: string, threadId: string, viewerUserId: string,
    forumId: string, isCurrent: () => boolean = () => true): Promise<FourD4yAuthenticatedImageBinaryResult> {
    if (!FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(url) ||
      !/^\d{1,20}$/.test(threadId)) {
      return this.binaryResult('unsupported-url');
    }
    let cookieHeader: string = await FourD4ySession.getCookieHeader();
    if (!isCurrent()) {
      return this.binaryResult('request-failed');
    }
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
    this.activeRequest = request;
    try {
      const boundary: FourD4yNativeRedirectBoundary = new FourD4yNativeRedirectBoundary(
        FourD4yAuthenticatedImageLoader.getSecureAttachmentUrl(url), true);
      boundary.attach(request);
      const response: http.HttpResponse = await request.request(
        FourD4yAuthenticatedImageLoader.getSecureAttachmentUrl(url), {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 30000,
        maxLimit: FourD4yAuthenticatedImageLoader.maxImageBytes,
        header: {
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cookie': cookieHeader,
          'Referer': FourD4ySession.forumRoot + 'viewthread.php?tid=' + threadId,
          'User-Agent': FourD4ySession.fullSiteUserAgent
        }
      });
      if (!boundary.isResponseAllowed() || response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > FourD4yAuthenticatedImageLoader.maxImageBytes) {
        return this.binaryResult('request-failed');
      }
      if (!isCurrent() || !await FourD4ySession.isCurrentAccountSessionSecret(cookieHeader) || !isCurrent()) {
        return this.binaryResult('request-failed');
      }
      return { status: 'success', bytes: response.result };
    } catch (_error) {
      return this.binaryResult('request-failed');
    } finally {
      if (this.activeRequest === request) {
        this.activeRequest = undefined;
      }
      try {
        request.destroy();
      } catch (_error) {
        // Cancellation may have destroyed it already.
      }
    }
  }

  private result(status: FourD4yAuthenticatedImageLoadStatus): FourD4yAuthenticatedImageLoadResult {
    return { status: status, pixelMap: undefined };
  }

  private binaryResult(status: FourD4yAuthenticatedImageLoadStatus): FourD4yAuthenticatedImageBinaryResult {
    return { status: status, bytes: undefined };
  }
}
