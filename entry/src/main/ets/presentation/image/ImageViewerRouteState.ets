/**
 * Transient navigation state for a forum image.  It intentionally retains
 * only the already-rendered image URLs and a display label; no response bytes,
 * cookies, form fields, or post body are copied into this route.
 *
 */
export interface ImageViewerItem {
  key: string;
  /** Full image target, used only after the user enters the gallery. */
  url: string;
  /** Directly-renderable in-topic preview while the full attachment loads. */
  previewUrl?: string;
  /** Pixel dimensions already observed for the preview in the topic stream. */
  previewWidth?: number;
  previewHeight?: number;
  /** Optional, already-rendered context for the unobtrusive gallery footer. */
  floor?: number;
  authorName?: string;
}

export class ImageViewerRouteState {
  items: ImageViewerItem[] = [];
  initialIndex: number = 0;
  title: string = '';
  /** Value-only reader context for one active gallery; never a cookie or form value. */
  threadId: string = '';
  viewerUserId: string = '';
  forumId: string = '';

  open(url: string, title: string): void {
    this.openGallery([{ key: 'single', url: url }], 0, title);
  }

  /** Snapshots only the currently visible topic-page image addresses. */
  openGallery(items: ImageViewerItem[], initialIndex: number, title: string, threadId: string = '',
    viewerUserId: string = '', forumId: string = ''): void {
    const snapshot: ImageViewerItem[] = [];
    items.forEach((item: ImageViewerItem) => {
      if (item !== undefined && item.key.length > 0 && isSupportedImageUrl(item.url)) {
        const copy: ImageViewerItem = {
          key: item.key,
          url: item.url,
          previewUrl: isSupportedImageUrl(item.previewUrl === undefined ? '' : item.previewUrl) ?
            item.previewUrl : undefined,
          previewWidth: isPositiveDimension(item.previewWidth) ? item.previewWidth : undefined,
          previewHeight: isPositiveDimension(item.previewHeight) ? item.previewHeight : undefined,
          floor: item.floor,
          authorName: item.authorName
        };
        snapshot.push(copy);
      }
    });
    this.items = snapshot;
    this.initialIndex = snapshot.length === 0 ? 0 : Math.min(Math.max(Math.trunc(initialIndex), 0), snapshot.length - 1);
    this.title = title.slice(0, 160);
    this.threadId = isNumericId(threadId) ? threadId : '';
    this.viewerUserId = isNumericId(viewerUserId) ? viewerUserId : '';
    this.forumId = isNumericId(forumId) ? forumId : '';
  }
}

function isSupportedImageUrl(url: string): boolean {
  return typeof url === 'string' && /^https?:\/\/[^\s<>]{1,2048}$/i.test(url);
}

function isNumericId(value: string): boolean {
  return typeof value === 'string' && /^\d{1,20}$/.test(value);
}

function isPositiveDimension(value: number | undefined): boolean {
  return value !== undefined && Number.isFinite(value) && value > 0 && value <= 100000;
}
