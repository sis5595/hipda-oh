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
  @State imageActionState: string = '';
  private readonly fullImageLoader: FourD4yAuthenticatedImageLoader = new FourD4yAuthenticatedImageLoader();
  private readonly imageExport: FourD4yImageExport = new FourD4yImageExport();
  private fullImageLoadSequence: number = 0;
  private preparedImageKey: string = '';
  private preparedImagePath: string = '';
  private preparedImageExtension: string = '';

  aboutToAppear(): void {
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
    this.fullImageLoadSequence += 1;
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
      if (this.getImageLoadState(index) === 'loading') {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(28)
            .height(28)
          Text('正在加载原图…')
            .fontSize(14)
            .fontColor('#B3FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

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
          Image(this.getImageRenderSource(item, index))
            .width('100%')
            .objectFit(ImageFit.Contain)
            .onComplete(() => {
              this.updateImageLoadState(index, this.isActiveFullImage(item, index) ||
                !this.needsAuthenticatedFullImage(item) ? 'ready' : 'preview');
            })
            .onError(() => {
              this.updateImageLoadState(index, this.needsAuthenticatedFullImage(item) &&
                item.previewUrl !== undefined && item.previewUrl.length > 0 ? 'preview-failed' : 'failed');
            })
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
    }
    .width('100%')
    .height('100%')
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

  private needsAuthenticatedFullImage(item: ImageViewerItem): boolean {
    return FourD4yAuthenticatedImageLoader.isAuthenticatedAttachmentUrl(item.url) &&
      /^\d{1,20}$/.test(this.imageRoute.threadId);
  }

  private isActiveFullImage(item: ImageViewerItem, index: number): boolean {
    return index === this.activeImageIndex && this.activeFullImage !== undefined &&
      this.activeFullImageKey === item.key;
  }

  private getImageRenderSource(item: ImageViewerItem, index: number): string | image.PixelMap {
    if (this.isActiveFullImage(item, index) && this.activeFullImage !== undefined) {
      return this.activeFullImage;
    }
    if (this.needsAuthenticatedFullImage(item) && item.previewUrl !== undefined && item.previewUrl.length > 0) {
      return item.previewUrl;
    }
    return item.url;
  }

  private loadActiveFullImage(): void {
    this.fullImageLoadSequence += 1;
    const sequence: number = this.fullImageLoadSequence;
    const item: ImageViewerItem | undefined = this.imageRoute.items[this.activeImageIndex];
    this.releaseActiveFullImage();
    if (item === undefined || !this.needsAuthenticatedFullImage(item)) {
      return;
    }
    this.updateImageLoadState(this.activeImageIndex, 'loading');
    this.loadAuthenticatedFullImage(item, this.activeImageIndex, sequence);
  }

  private async loadAuthenticatedFullImage(item: ImageViewerItem, index: number, sequence: number): Promise<void> {
    const result = await this.fullImageLoader.load(item.url, this.imageRoute.threadId,
      this.imageRoute.viewerUserId, this.imageRoute.forumId);
    if (sequence !== this.fullImageLoadSequence || index !== this.activeImageIndex ||
      this.imageRoute.items[index] === undefined || this.imageRoute.items[index].key !== item.key) {
      if (result.pixelMap !== undefined) {
        this.releasePixelMap(result.pixelMap);
      }
      return;
    }
    if (result.pixelMap === undefined) {
      // A preview still gives the reader a usable picture if the protected
      // original expires or the network drops. Do not replace it with a blank
      // error screen merely because the upgrade failed.
      this.updateImageLoadState(index, item.previewUrl === undefined || item.previewUrl.length === 0 ?
        'failed' : 'preview-failed');
      return;
    }
    this.activeFullImage = result.pixelMap;
    this.activeFullImageKey = item.key;
    this.updateImageLoadState(index, 'ready');
  }

  private releaseActiveFullImage(): void {
    const current: image.PixelMap | undefined = this.activeFullImage;
    this.activeFullImage = undefined;
    this.activeFullImageKey = '';
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

  private async prepareCurrentImageExport(): Promise<FourD4yPreparedImageExport | undefined> {
    const item: ImageViewerItem | undefined = this.getActiveImageItem();
    const hostContext = this.getUIContext().getHostContext();
    if (item === undefined || hostContext === undefined) {
      return undefined;
    }
    if (this.preparedImageKey === item.key && this.preparedImagePath.length > 0) {
      try {
        if (fs.accessSync(this.preparedImagePath)) {
          return { filePath: this.preparedImagePath, extension: this.preparedImageExtension };
        }
      } catch (_error) {
        // The cache can be cleared by the system at any time. Download again.
      }
    }
    const prepared: FourD4yPreparedImageExport | undefined = await this.imageExport.prepare(hostContext.cacheDir,
      item.url, this.imageRoute.threadId, this.imageRoute.viewerUserId, this.imageRoute.forumId);
    if (prepared !== undefined) {
      this.preparedImageKey = item.key;
      this.preparedImagePath = prepared.filePath;
      this.preparedImageExtension = prepared.extension;
    }
    return prepared;
  }

  private async saveCurrentImageWithTemporaryGrant(): Promise<void> {
    if (this.imageActionState.length > 0) {
      return;
    }
    const item: ImageViewerItem | undefined = this.getActiveImageItem();
    const hostContext = this.getUIContext().getHostContext();
    if (item === undefined || hostContext === undefined) {
      this.showImageActionToast('暂时无法保存图片');
      return;
    }
    this.imageActionState = 'saving';
    let destination: fs.File | undefined = undefined;
    try {
      const context: common.UIAbilityContext = hostContext as common.UIAbilityContext;
      // The asset and descriptor are created while SaveButton's short-lived
      // grant is active. Writing to this opened descriptor may finish after
      // the initial grant window, as documented for the secure save flow.
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const assetUri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE,
        this.getImageExtensionHint(item.url));
      destination = fs.openSync(assetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const prepared: FourD4yPreparedImageExport | undefined = await this.prepareCurrentImageExport();
      if (prepared === undefined) {
        this.showImageActionToast('原图下载失败，请稍后重试');
        return;
      }
      if (!this.copyPreparedImageToOpenAsset(prepared.filePath, destination)) {
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
      this.imageActionState = '';
    }
  }

  private async shareCurrentImage(): Promise<void> {
    if (this.imageActionState.length > 0) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showImageActionToast('暂时无法打开系统分享');
      return;
    }
    this.imageActionState = 'sharing';
    try {
      const prepared: FourD4yPreparedImageExport | undefined = await this.prepareCurrentImageExport();
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
      this.imageActionState = '';
    }
  }

  private copyPreparedImageToOpenAsset(sourcePath: string, destination: fs.File): boolean {
    let source: fs.File | undefined = undefined;
    try {
      source = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(source.fd).size;
      if (!Number.isSafeInteger(size) || size <= 0 || size > 32 * 1024 * 1024) {
        return false;
      }
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      if (fs.readSync(source.fd, bytes) !== size) {
        return false;
      }
      return fs.writeSync(destination.fd, bytes) === size;
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

  private getImageExtensionHint(url: string): string {
    const match: RegExpExecArray | null = /\.([a-zA-Z0-9]{1,5})(?:[?#]|$)/.exec(url);
    const extension: string = match === null ? '' : match[1].toLowerCase();
    if (extension === 'jpeg') return 'jpg';
    return /^(?:avif|bmp|gif|jpg|png|webp)$/.test(extension) ? extension : 'jpg';
  }

  private showImageActionToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // Do not allow feedback delivery to affect the save/share action.
    }
  }
}
