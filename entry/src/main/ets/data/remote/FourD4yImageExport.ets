import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { image } from '@kit.ImageKit';
import { FourD4yAuthenticatedImageBinaryResult, FourD4yAuthenticatedImageLoader } from './FourD4yAuthenticatedImageLoader';

export interface FourD4yPreparedImageExport {
  filePath: string;
  extension: string;
}

/**
 * Creates one transient, app-owned copy of a forum image after an explicit
 * user action. The copy can then be handed to the system album or share panel.
 * Only explicitly requested image bytes are written to app cache; cookies
 * and source URLs are never persisted with the export.
 */
export class FourD4yImageExport {
  private static readonly maxImageBytes: number = 32 * 1024 * 1024;
  private static readonly exportRetentionMillis: number = 7 * 24 * 60 * 60 * 1000;
  private static readonly processStartedAt: number = Date.now();
  private static cleanupTask: Promise<void> | undefined = undefined;
  private static exportSequence: number = 0;
  private readonly authenticatedLoader: FourD4yAuthenticatedImageLoader = new FourD4yAuthenticatedImageLoader();

  async prepare(cacheDir: string, url: string, threadId: string, viewerUserId: string,
    forumId: string): Promise<FourD4yPreparedImageExport | undefined> {
    if (!this.isHttpImageUrl(url) || cacheDir.length === 0) {
      return undefined;
    }
    if (FourD4yImageExport.cleanupTask === undefined) {
      FourD4yImageExport.cleanupTask = FourD4yImageExport.cleanupExpiredExports(cacheDir);
    }
    await FourD4yImageExport.cleanupTask;
    const bytes: ArrayBuffer | undefined = FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(url) ?
      await this.downloadAuthenticatedImage(url, threadId, viewerUserId, forumId) : await this.downloadPublicImage(url);
    if (bytes === undefined) {
      return undefined;
    }
    const extension: string = await this.readImageExtension(bytes);
    if (extension.length === 0) {
      return undefined;
    }
    const filePath: string = cacheDir + '/hipdaoh-image-export-' + Date.now() + '-' + (++FourD4yImageExport.exportSequence) +
      '.' + extension;
    if (!await this.writeAll(filePath, bytes)) {
      return undefined;
    }
    return { filePath: filePath, extension: extension };
  }

  /**
   * Opportunistic cleanup, once on the first explicit export in this process.
   * Never remove current-process files or delete at viewer/share-sheet exit:
   * the receiving app can still be reading the granted URI. The seven-day
   * grace period is our cache policy, not a promise about recipient lifetimes.
   */
  private static async cleanupExpiredExports(cacheDir: string): Promise<void> {
    if (cacheDir.length <= 1 || !cacheDir.startsWith('/') || cacheDir.indexOf('\\') >= 0 ||
      cacheDir.split('/').some((part: string) => part === '..' || part === '.')) {
      return;
    }
    try {
      const now: number = Date.now();
      const names: string[] = await fs.listFile(cacheDir, { recursion: false });
      let inspected: number = 0;
      for (const name of names) {
        // Exact basename only: no traversal, directories, uploads, ArkWeb
        // caches, Picker destinations or gallery assets are in this scope.
        const match: RegExpExecArray | null =
          /^hipdaoh-image-export-(\d{13})-([1-9]\d{0,9})\.(jpg|png|gif|webp|bmp|avif|heif|heic)$/.exec(name);
        if (match === null) {
          continue;
        }
        const createdAt: number = Number(match[1]);
        if (createdAt >= FourD4yImageExport.processStartedAt ||
          now - createdAt < FourD4yImageExport.exportRetentionMillis) {
          continue;
        }
        if (inspected >= 64) {
          break;
        }
        inspected += 1;
        const filePath: string = cacheDir + '/' + name;
        try {
          const stat: fs.Stat = await fs.stat(filePath);
          // Core File Kit mtime is seconds, unlike Date.now(). Also retain
          // unexpectedly recent/future files even when the name looks old.
          const modifiedAt: number = stat.mtime * 1000;
          if (stat.isFile() && Number.isFinite(modifiedAt) && modifiedAt > 0 &&
            now - modifiedAt >= FourD4yImageExport.exportRetentionMillis) {
            await fs.unlink(filePath);
          }
        } catch (_cleanupError) {
          // Missing/busy files must not block this user-initiated export.
        }
      }
    } catch (_cleanupError) {
      // Cache housekeeping is best effort; export remains independently usable.
    }
  }

  private async downloadAuthenticatedImage(url: string, threadId: string, viewerUserId: string,
    forumId: string): Promise<ArrayBuffer | undefined> {
    const result: FourD4yAuthenticatedImageBinaryResult = await this.authenticatedLoader.download(url, threadId,
      viewerUserId, forumId);
    return result.bytes;
  }

  private async downloadPublicImage(url: string): Promise<ArrayBuffer | undefined> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 20000,
        readTimeout: 30000,
        maxLimit: FourD4yImageExport.maxImageBytes,
        // No forum cookie or user-specific header is attached to non-forum
        // image hosts. This request exists only because the user pressed
        // Save or Share in the image viewer.
        header: {
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'
        }
      });
      if (response.responseCode !== http.ResponseCode.OK || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > FourD4yImageExport.maxImageBytes) {
        return undefined;
      }
      return response.result;
    } catch (_error) {
      return undefined;
    } finally {
      request.destroy();
    }
  }

  private async writeAll(path: string, bytes: ArrayBuffer): Promise<boolean> {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      // Even a valid compressed image can be 32 MB. Do not block the UI
      // thread on bulk disk I/O, or expose its URI before the write settles.
      const written: number = await fs.write(file.fd, bytes);
      if (written !== bytes.byteLength) {
        throw new Error('image-export-short-write');
      }
      return true;
    } catch (_error) {
      try {
        if (fs.accessSync(path)) {
          fs.unlinkSync(path);
        }
      } catch (_cleanupError) {
        // A partially-written app-cache file is left for system cache cleanup.
      }
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_error) {
          // Closing an app-cache export cannot change the reader state.
        }
      }
    }
  }

  private async readImageExtension(bytes: ArrayBuffer): Promise<string> {
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(bytes);
      // Inspect encoded metadata without allocating a full-resolution PixelMap.
      // HTTP 200 and a .jpg URL can equally describe a forum login/error page.
      const info: image.ImageInfo = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) {
        return '';
      }
      switch (info.mimeType.toLowerCase()) {
        case 'image/jpeg': return 'jpg';
        case 'image/png': return 'png';
        case 'image/gif': return 'gif';
        case 'image/webp': return 'webp';
        case 'image/bmp': return 'bmp';
        case 'image/avif': return 'avif';
        case 'image/heif': return 'heif';
        case 'image/heic': return 'heic';
        default: return '';
      }
    } catch (_error) {
      return '';
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_error) {
          // Metadata validation must not leak the native ImageSource.
        }
      }
    }
  }

  private isHttpImageUrl(url: string): boolean {
    return /^https?:\/\/[^\s<>]{1,2048}$/i.test(url);
  }
}
