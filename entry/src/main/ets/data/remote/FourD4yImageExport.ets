import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { FourD4yAuthenticatedImageBinaryResult, FourD4yAuthenticatedImageLoader } from './FourD4yAuthenticatedImageLoader';

export interface FourD4yPreparedImageExport {
  filePath: string;
  extension: string;
}

/**
 * Creates one transient, app-owned copy of a forum image after an explicit
 * user action. The copy can then be handed to the system album or share panel.
 * It intentionally never persists a cookie, URL, or image bytes itself.
 */
export class FourD4yImageExport {
  private static readonly maxImageBytes: number = 32 * 1024 * 1024;
  private static exportSequence: number = 0;
  private readonly authenticatedLoader: FourD4yAuthenticatedImageLoader = new FourD4yAuthenticatedImageLoader();

  async prepare(cacheDir: string, url: string, threadId: string, viewerUserId: string,
    forumId: string): Promise<FourD4yPreparedImageExport | undefined> {
    if (!this.isHttpImageUrl(url) || cacheDir.length === 0) {
      return undefined;
    }
    const bytes: ArrayBuffer | undefined = FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(url) ?
      await this.downloadAuthenticatedImage(url, threadId, viewerUserId, forumId) : await this.downloadPublicImage(url);
    if (bytes === undefined) {
      return undefined;
    }
    const extension: string = this.inferImageExtension(url, bytes);
    const filePath: string = cacheDir + '/hipdaoh-image-export-' + Date.now() + '-' + (++FourD4yImageExport.exportSequence) +
      '.' + extension;
    if (!this.writeAll(filePath, bytes)) {
      return undefined;
    }
    return { filePath: filePath, extension: extension };
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

  private writeAll(path: string, bytes: ArrayBuffer): boolean {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const written: number = fs.writeSync(file.fd, bytes);
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

  private inferImageExtension(url: string, bytes: ArrayBuffer): string {
    const data: Uint8Array = new Uint8Array(bytes);
    if (data.length >= 3 && data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF) return 'jpg';
    if (data.length >= 8 && data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47) return 'png';
    if (data.length >= 6 && data[0] === 0x47 && data[1] === 0x49 && data[2] === 0x46) return 'gif';
    if (data.length >= 12 && data[0] === 0x52 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x46 &&
      data[8] === 0x57 && data[9] === 0x45 && data[10] === 0x42 && data[11] === 0x50) return 'webp';
    if (data.length >= 2 && data[0] === 0x42 && data[1] === 0x4D) return 'bmp';
    if (data.length >= 12 && data[4] === 0x66 && data[5] === 0x74 && data[6] === 0x79 && data[7] === 0x70 &&
      data[8] === 0x61 && data[9] === 0x76 && data[10] === 0x69 && data[11] === 0x66) return 'avif';
    const urlMatch: RegExpExecArray | null = /\.([a-zA-Z0-9]{1,5})(?:[?#]|$)/.exec(url);
    const extension: string = urlMatch === null ? '' : urlMatch[1].toLowerCase();
    if (extension === 'jpeg') return 'jpg';
    return /^(?:avif|bmp|gif|jpg|png|webp)$/.test(extension) ? extension : 'jpg';
  }

  private isHttpImageUrl(url: string): boolean {
    return /^https?:\/\/[^\s<>]{1,2048}$/i.test(url);
  }
}
