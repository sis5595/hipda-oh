import { ImageViewerItem, ImageViewerRouteState } from './ImageViewerRouteState';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import fs from '@ohos.file.fs';
import { FourD4yAuthenticatedImageLoader } from '../../data/remote/FourD4yAuthenticatedImageLoader';
import { FourD4yImageExport, FourD4yPreparedImageExport } from '../../data/remote/FourD4yImageExport';

interface ImageExportSelection {
  cacheDir: string;
  key: string;
  url: string;
  threadId: string;
  viewerUserId: string;
  forumId: string;
}

/**
 * Native image reader for forum body images.
 *
 * The base image deliberately has a width but no forced height. ArkUI keeps
 * its source aspect ratio, so a phone screenshot begins at its top edge and
 * can be read continuously downwards without the browser viewer centering a
 * scaled-to-screen miniature. Scroll's built-in free scrolling and zoom are
 * available on the project's HarmonyOS 6 / API 24 target.
 */
@Component
export struct ImageViewerPage {
  @Consume('imageViewerRoute') imageRoute: ImageViewerRouteState;
  @State activeImageIndex: number = 0;
  @State imageLoadStates: string[] = [];
  @State imageZoomScales: number[] = [];
  /** One full-size attachment is retained only for the active gallery page. */
  @State activeFullImage: image.PixelMap | undefined = undefined;
  @State activeFullImageKey: string = '';
  @State activeAnimationPath: string = '';
  @State imageActionState: string = '';
  private readonly fullImageLoader: FourD4yAuthenticatedImageLoader = new FourD4yAuthenticatedImageLoader();
  private readonly imageExport: FourD4yImageExport = new FourD4yImageExport();
  private fullImageLoadSequence: number = 0;
  private preparedImageKey: string = '';
  private preparedImagePath: string = '';
  private preparedImageExtension: string = '';
  private isViewerActive: boolean = false;

  aboutToAppear(): void {
    this.isViewerActive = true;
    const count: number = this.imageRoute.items.length;
    this.activeImageIndex = count === 0 ? 0 : Math.min(Math.max(this.imageRoute.initialIndex, 0), count - 1);
    const states: string[] = [];
    const zoomScales: number[] = [];
    for (let index: number = 0; index < count; index += 1) {
      states.push('loading');
      zoomScales.push(1);
    }
    this.imageLoadStates = states;
    this.imageZoomScales = zoomScales;
    this.releaseActiveFullImage();
    this.loadActiveFullImage();
  }

  aboutToDisappear(): void {
    this.isViewerActive = false;
    this.fullImageLoadSequence += 1;
    this.fullImageLoader.cancelActiveDownload();
    this.releaseActiveFullImage();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (this.imageRoute.items.length === 0) {
          Column({ space: 12 }) {
            Text('暂无可显示图片')
              .fontSize(17)
              .fontColor(Color.White)
            Text('请返回帖子后重新打开图片。')
              .fontSize(14)
              .fontColor('#B3FFFFFF')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Swiper() {
            ForEach(this.imageRoute.items, (item: ImageViewerItem, index: number) => {
              this.buildImagePage(item, index);
            }, (item: ImageViewerItem) => item.key)
          }
          .index(this.activeImageIndex)
          .indicator(false)
          .loop(false)
          .cachedCount(1)
          .disableSwipe(this.getActiveImageZoomScale() > 1.01)
          .onChange((index: number) => {
            this.activeImageIndex = index;
            this.loadActiveFullImage();
          })
          .width('100%')
          .height('100%')

          this.buildGalleryFooter()
          this.buildGalleryActionBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
    }
    // Gallery uses a black immersive canvas like NG. System back remains the
    // explicit exit path; no synthetic navigation chrome is added.
    .hideTitleBar(true)
  }

  @Builder
  private buildGalleryFooter() {
    Column({ space: 4 }) {
      if (this.imageRoute.items.length > 1) {
        Text((this.activeImageIndex + 1) + ' / ' + this.imageRoute.items.length)
          .fontSize(14)
          .fontColor(Color.White);
      }
      if (this.getGalleryContextText().length > 0) {
        Text(this.getGalleryContextText())
          .fontSize(13)
          .fontColor('#E6FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .padding({ left: 10, right: 12, top: 6, bottom: 6 })
    .backgroundColor('#66000000')
    .borderRadius(8)
    .margin({ left: 12, bottom: 18 });
  }

  /** Save/share stay on the black image canvas, matching NG's reader actions. */
  @Builder
  private buildGalleryActionBar() {
    Row({ space: 8 }) {
      // WRITE_IMAGEVIDEO is a restricted ACL permission. The system SaveButton
      // gives this one user-initiated export a short, privacy-preserving grant
      // without declaring that restricted permission in the application.
      SaveButton({ icon: SaveIconStyle.LINES, text: SaveDescription.SAVE_TO_GALLERY,
        buttonType: ButtonType.Capsule })
        .enabled(this.imageActionState.length === 0)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            void this.saveCurrentImageWithTemporaryGrant();
          } else if (result !== SaveButtonOnClickResult.CANCELED_BY_USER) {
            this.showImageActionToast('系统未授予本次图片保存权限');
          }
        })
      Button(this.imageActionState === 'sharing' ? '准备中…' : '分享')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor('#66000000')
        .borderRadius(18)
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .enabled(this.imageActionState.length === 0)
        .onClick(() => {
          void this.shareCurrentImage();
        })
    }
    // Give the action row the full canvas width, then place its contents at
    // the far right.  A content-sized Row is otherwise laid out from the
    // Stack's left edge and can cover the image sequence in the footer.
    .width('100%')
    .justifyContent(FlexAlign.End)
    .align(Alignment.Bottom)
    .padding({ right: 12 })
    .margin({ bottom: 18 });
  }

  private getGalleryContextText(): string {
    const item: ImageViewerItem | undefined = this.imageRoute.items[this.activeImageIndex];
    if (item !== undefined && ((item.floor !== undefined && item.floor > 0) ||
      (item.authorName !== undefined && item.authorName.length > 0))) {
      const floorText: string = item.floor === undefined || item.floor <= 0 ? '' : '#' + item.floor + ' ';
      return floorText + (item.authorName === undefined ? '' : item.authorName);
    }
    return this.imageRoute.title;
  }

  @Builder
  private buildImagePage(item: ImageViewerItem, index: number) {
    Stack({ alignContent: Alignment.Top }) {
      if (this.getImageLoadState(index) === 'failed') {
        Column({ space: 12 }) {
          Text('图片加载失败')
            .fontSize(17)
            .fontColor(Color.White)
          Text('可左右切换查看其他图片，或返回帖子后重试。')
            .fontSize(14)
            .fontColor('#B3FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          // Width without a fixed height preserves aspect ratio. Long images
          // therefore begin at the top and read continuously downward.
          this.buildRenderedImage(item, index)
        }
        // ArkUI's built-in zoom is available only to a free Scroll. At its
        // baseline width there is no horizontal image overflow, so the outer
        // gallery receives a normal horizontal flip. Once enlarged, the
        // outer Swiper is disabled and this Scroll owns free panning.
        .scrollable(ScrollDirection.FREE)
        .minZoomScale(1)
        .maxZoomScale(4)
        .zoomScale(this.getImageZoomScale(index))
        .enableBouncesZoom(true)
        .onDidZoom((scale: number) => {
          this.updateImageZoomScale(index, scale);
        })
        .gesture(
          TapGesture({ count: 2 })
            .onAction(() => {
              this.toggleImageZoomScale(index);
            })
        )
        // A free Scroll normally recognizes a horizontal pan before its
        // parent Swiper can see it. At the base scale the image has no
        // horizontal area to inspect, so reject only that horizontal built-in
        // pan and let the gallery turn the page. Pinch, double-tap, vertical
        // long-image reading, and all panning after zoom stay with Scroll.
        .onGestureRecognizerJudgeBegin((event: BaseGestureEvent, current: GestureRecognizer,
          _recognizers: Array<GestureRecognizer>): GestureJudgeResult => {
          if (!current.isBuiltIn() || current.getType() !== GestureControl.GestureType.PAN_GESTURE ||
            this.getImageZoomScale(index) > 1.01) {
            return GestureJudgeResult.CONTINUE;
          }
          const panEvent: PanGestureEvent = event as PanGestureEvent;
          return Math.abs(panEvent.offsetX) > Math.abs(panEvent.offsetY) ?
            GestureJudgeResult.REJECT : GestureJudgeResult.CONTINUE;
        })
        .width('100%')
        .height('100%')
      }

      // Draw after the image so an opaque preview cannot hide loading/error
      // feedback. Never describe a downloaded thumbnail as the full original.
      if (this.getImageLoadState(index) === 'loading' ||
        this.getImageLoadState(index) === 'preview-failed' || this.getImageLoadState(index) === 'scaled-preview' ||
        this.getImageLoadState(index) === 'static-preview') {
        Text(this.getImageLoadState(index) === 'loading' ? '正在加载原图…' :
          (this.getImageLoadState(index) === 'static-preview' ? '受内存限制，显示动图静态预览；保存/分享仍为原图' :
            (this.getImageLoadState(index) === 'scaled-preview' ?
              '受内存限制，显示缩放预览；保存/分享仍为原图' : '原图加载失败，当前仅为预览图；可返回后重试')))
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
          .padding(10)
          .borderRadius(8)
          .margin({ top: 12, left: 12, right: 12 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildRenderedImage(item: ImageViewerItem, index: number) {
    // Read state inside the Image update function. A by-value @Builder source
    // parameter freezes the initial thumbnail even when decoding completes.
    if (index === this.activeImageIndex && (this.activeFullImage !== undefined ||
      this.activeAnimationPath.length > 0)) {
      Image(this.getImageRenderSource(item, index))
        .width('100%')
        .objectFit(ImageFit.Contain)
        .onComplete(this.createRenderedImageCallback(item, index, this.getImageRenderSource(item, index), true))
        .onError(this.createRenderedImageCallback(item, index, this.getImageRenderSource(item, index), false))
    } else if (this.hasAttachmentPreview(item)) {
      Image(item.previewUrl as string)
        .width('100%')
        .objectFit(ImageFit.Contain)
    } else {
      // An empty Image source can retain its last native texture. Remove the
      // original Image node instead of leaving it in the Swiper neighbour.
      Blank().width('100%').height(1)
    }
  }

  private createRenderedImageCallback(item: ImageViewerItem, index: number,
    source: string | image.PixelMap, succeeded: boolean): () => void {
    // Capture this render's source, not the source at callback delivery time.
    return () => this.onRenderedImageResult(item, index, source, succeeded);
  }

  private onRenderedImageResult(item: ImageViewerItem, index: number,
    source: string | image.PixelMap, succeeded: boolean): void {
    if (!this.isViewerActive || this.imageRoute.items[index] === undefined ||
      this.imageRoute.items[index].key !== item.key || this.getImageRenderSource(item, index) !== source) {
      return;
    }
    // Preview rendering and original downloading are separate operations.
    // Only the authenticated loader may finish the latter; late thumbnail
    // callbacks must not clear its loading/error state or a newer PixelMap.
    if (this.needsManagedFullImage(item) && !this.isActiveFullImage(item, index)) {
      return;
    }
    this.updateImageLoadState(index, succeeded ?
      (this.getImageLoadState(index) === 'scaled-preview' || this.getImageLoadState(index) === 'static-preview' ?
        this.getImageLoadState(index) : 'ready') : 'failed');
  }

  private getImageLoadState(index: number): string {
    return index >= 0 && index < this.imageLoadStates.length ? this.imageLoadStates[index] : 'loading';
  }

  private updateImageLoadState(index: number, state: string): void {
    if (index < 0 || index >= this.imageLoadStates.length || this.imageLoadStates[index] === state) {
      return;
    }
    const next: string[] = [...this.imageLoadStates];
    next[index] = state;
    this.imageLoadStates = next;
  }

  private needsManagedFullImage(item: ImageViewerItem): boolean {
    return /^https?:\/\//i.test(item.url);
  }

  private hasAttachmentPreview(item: ImageViewerItem): boolean {
    // A public image's "preview" is commonly the same original URL. Loading
    // it directly would silently bypass the bounded public-image pipeline.
    return FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(item.url) &&
      item.previewUrl !== undefined && item.previewUrl.length > 0 && item.previewUrl !== item.url;
  }

  private isActiveFullImage(item: ImageViewerItem, index: number): boolean {
    return index === this.activeImageIndex && (this.activeFullImage !== undefined ||
      (this.activeAnimationPath !== undefined && this.activeAnimationPath.length > 0)) &&
      this.activeFullImageKey === item.key;
  }

  private getImageRenderSource(item: ImageViewerItem, index: number): string | image.PixelMap {
    if (this.isActiveFullImage(item, index) && this.activeAnimationPath.length > 0) {
      return 'file://' + this.activeAnimationPath;
    }
    if (this.isActiveFullImage(item, index) && this.activeFullImage !== undefined) {
      return this.activeFullImage;
    }
    if (this.hasAttachmentPreview(item)) {
      return item.previewUrl as string;
    }
    // Do not let Image(URL) race the bounded download/decode path, including
    // off-screen Swiper neighbours. Only the active original is decoded.
    return this.needsManagedFullImage(item) ? '' : item.url;
  }

  private loadActiveFullImage(): void {
    this.fullImageLoadSequence += 1;
    this.fullImageLoader.cancelActiveDownload();
    const sequence: number = this.fullImageLoadSequence;
    const item: ImageViewerItem | undefined = this.imageRoute.items[this.activeImageIndex];
    this.releaseActiveFullImage();
    if (item === undefined || !this.needsManagedFullImage(item)) {
      return;
    }
    this.updateImageLoadState(this.activeImageIndex, 'loading');
    this.loadManagedFullImage(item, this.activeImageIndex, sequence);
  }

  private async loadManagedFullImage(item: ImageViewerItem, index: number, sequence: number): Promise<void> {
    const cacheDir: string = (this.getUIContext().getHostContext() as common.Context).cacheDir;
    const result = await this.fullImageLoader.load(item.url, this.imageRoute.threadId,
      this.imageRoute.viewerUserId, this.imageRoute.forumId, () => this.isViewerActive &&
        sequence === this.fullImageLoadSequence && index === this.activeImageIndex &&
        this.imageRoute.items[index] !== undefined && this.imageRoute.items[index].key === item.key, cacheDir);
    if (sequence !== this.fullImageLoadSequence || index !== this.activeImageIndex ||
      this.imageRoute.items[index] === undefined || this.imageRoute.items[index].key !== item.key) {
      if (result.pixelMap !== undefined) {
        this.releasePixelMap(result.pixelMap);
      }
      if (result.animatedPath !== undefined) this.fullImageLoader.releaseAnimation(result.animatedPath);
      return;
    }
    if (result.pixelMap === undefined && result.animatedPath === undefined) {
      // A preview still gives the reader a usable picture if the protected
      // original expires or the network drops. Do not replace it with a blank
      // error screen merely because the upgrade failed.
      this.updateImageLoadState(index, this.hasAttachmentPreview(item) ? 'preview-failed' : 'failed');
      return;
    }
    this.activeFullImage = result.pixelMap;
    this.activeAnimationPath = result.animatedPath === undefined ? '' : result.animatedPath;
    this.activeFullImageKey = item.key;
    this.updateImageLoadState(index, result.staticPreview === true ? 'static-preview' :
      (result.scaledPreview === true ? 'scaled-preview' : 'ready'));
  }

  private releaseActiveFullImage(): void {
    const current: image.PixelMap | undefined = this.activeFullImage;
    this.activeFullImage = undefined;
    this.activeFullImageKey = '';
    const animationPath: string = this.activeAnimationPath;
    this.activeAnimationPath = '';
    if (animationPath !== undefined && animationPath.length > 0) {
      this.fullImageLoader.releaseAnimation(animationPath);
    }
    if (current !== undefined) {
      this.releasePixelMap(current);
    }
  }

  private releasePixelMap(pixelMap: image.PixelMap): void {
    pixelMap.release().catch(() => {
      // A PixelMap may already have been reclaimed as the gallery closes.
    });
  }

  private getImageZoomScale(index: number): number {
    return index >= 0 && index < this.imageZoomScales.length ? this.imageZoomScales[index] : 1;
  }

  private getActiveImageZoomScale(): number {
    return this.getImageZoomScale(this.activeImageIndex);
  }

  private updateImageZoomScale(index: number, scale: number): void {
    if (index < 0 || index >= this.imageZoomScales.length || !Number.isFinite(scale)) {
      return;
    }
    const normalizedScale: number = Math.min(Math.max(scale, 1), 4);
    if (Math.abs(this.imageZoomScales[index] - normalizedScale) < 0.005) {
      return;
    }
    const next: number[] = [...this.imageZoomScales];
    next[index] = normalizedScale;
    this.imageZoomScales = next;
  }

  private toggleImageZoomScale(index: number): void {
    this.updateImageZoomScale(index, this.getImageZoomScale(index) > 1.01 ? 1 : 2);
  }

  private getActiveImageItem(): ImageViewerItem | undefined {
    return this.activeImageIndex >= 0 && this.activeImageIndex < this.imageRoute.items.length ?
      this.imageRoute.items[this.activeImageIndex] : undefined;
  }

  private captureImageExportSelection(): ImageExportSelection | undefined {
    const item: ImageViewerItem | undefined = this.getActiveImageItem();
    const hostContext = this.getUIContext().getHostContext();
    if (!this.isViewerActive || item === undefined || hostContext === undefined) {
      return undefined;
    }
    return {
      cacheDir: hostContext.cacheDir,
      key: item.key + '|' + item.url + '|' + this.imageRoute.threadId + '|' + this.imageRoute.viewerUserId,
      url: item.url,
      threadId: this.imageRoute.threadId,
      viewerUserId: this.imageRoute.viewerUserId,
      forumId: this.imageRoute.forumId
    };
  }

  private async prepareImageExport(selection: ImageExportSelection): Promise<FourD4yPreparedImageExport | undefined> {
    if (this.preparedImageKey === selection.key && this.preparedImagePath.length > 0) {
      try {
        if (fs.accessSync(this.preparedImagePath)) {
          return { filePath: this.preparedImagePath, extension: this.preparedImageExtension };
        }
      } catch (_error) {
        // The cache can be cleared by the system at any time. Download again.
      }
    }
    const prepared: FourD4yPreparedImageExport | undefined = await this.imageExport.prepare(selection.cacheDir,
      selection.url, selection.threadId, selection.viewerUserId, selection.forumId);
    if (prepared !== undefined && this.isViewerActive) {
      this.preparedImageKey = selection.key;
      this.preparedImagePath = prepared.filePath;
      this.preparedImageExtension = prepared.extension;
    }
    return prepared;
  }

  private async saveCurrentImageWithTemporaryGrant(): Promise<void> {
    if (this.imageActionState.length > 0) {
      return;
    }
    const selection: ImageExportSelection | undefined = this.captureImageExportSelection();
    const hostContext = this.getUIContext().getHostContext();
    if (selection === undefined || hostContext === undefined) {
      this.showImageActionToast('暂时无法保存图片');
      return;
    }
    this.imageActionState = 'saving';
    const grantStartedAt: number = Date.now();
    let destination: fs.File | undefined = undefined;
    let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
    try {
      const context: common.UIAbilityContext = hostContext as common.UIAbilityContext;
      const prepared: FourD4yPreparedImageExport | undefined = await this.prepareImageExport(selection);
      if (!this.isViewerActive) {
        return;
      }
      if (prepared === undefined) {
        this.showImageActionToast('原图下载失败，请稍后重试');
        return;
      }
      // API 20+ grants one media-library call within one minute. Validate
      // the bytes before creating an asset, so PHP image URLs do not force
      // PNG/GIF content into a guessed JPEG and failed downloads leave no
      // empty album entry. A slow download remains cached for a fresh click.
      const elapsed: number = Date.now() - grantStartedAt;
      if (elapsed < 0 || elapsed >= 55000) {
        this.showImageActionToast('原图已准备好，请再次点击保存');
        return;
      }
      helper = photoAccessHelper.getPhotoAccessHelper(context);
      const assetUri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, prepared.extension);
      destination = fs.openSync(assetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      if (!await this.copyPreparedImageToOpenAsset(prepared.filePath, destination)) {
        this.showImageActionToast('保存图片失败，请稍后重试');
        return;
      }
      this.showImageActionToast('图片已保存到相册');
    } catch (_error) {
      this.showImageActionToast('保存图片失败，请稍后重试');
    } finally {
      if (destination !== undefined) {
        try {
          fs.closeSync(destination);
        } catch (_error) {
          // The provider owns the media asset after its descriptor is closed.
        }
      }
      if (helper !== undefined) {
        try {
          await helper.release();
        } catch (_error) {
          // Releasing the helper must not change an already completed save.
        }
      }
      if (this.isViewerActive) {
        this.imageActionState = '';
      }
    }
  }

  private async shareCurrentImage(): Promise<void> {
    if (this.imageActionState.length > 0) {
      return;
    }
    const selection: ImageExportSelection | undefined = this.captureImageExportSelection();
    const hostContext = this.getUIContext().getHostContext();
    if (selection === undefined || hostContext === undefined) {
      this.showImageActionToast('暂时无法打开系统分享');
      return;
    }
    this.imageActionState = 'sharing';
    try {
      const prepared: FourD4yPreparedImageExport | undefined = await this.prepareImageExport(selection);
      if (!this.isViewerActive) {
        return;
      }
      if (prepared === undefined) {
        this.showImageActionToast('原图下载失败，请稍后重试');
        return;
      }
      const utdType: string = utd.getUniformDataTypeByFilenameExtension('.' + prepared.extension,
        utd.UniformDataType.IMAGE);
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utdType,
        uri: fileUri.getUriFromPath(prepared.filePath),
        title: '4D4Y 图片',
        description: '4D4Y 论坛图片'
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      await controller.show(hostContext as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (_error) {
      this.showImageActionToast('系统分享暂时不可用');
    } finally {
      if (this.isViewerActive) {
        this.imageActionState = '';
      }
    }
  }

  private async copyPreparedImageToOpenAsset(sourcePath: string, destination: fs.File): Promise<boolean> {
    let source: fs.File | undefined = undefined;
    try {
      source = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(source.fd).size;
      if (!Number.isSafeInteger(size) || size <= 0 || size > 32 * 1024 * 1024) {
        return false;
      }
      // Copy between already-open descriptors asynchronously. Do not allocate
      // another full image-sized JS buffer or perform the bulk I/O on the UI
      // thread. The caller retains the album descriptor until this settles.
      await fs.copyFile(source.fd, destination.fd);
      return true;
    } catch (_error) {
      return false;
    } finally {
      if (source !== undefined) {
        try {
          fs.closeSync(source);
        } catch (_error) {
          // No reader state is tied to a transient export descriptor.
        }
      }
    }
  }

  private showImageActionToast(message: string): void {
    if (!this.isViewerActive) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // Do not allow feedback delivery to affect the save/share action.
    }
  }
}
