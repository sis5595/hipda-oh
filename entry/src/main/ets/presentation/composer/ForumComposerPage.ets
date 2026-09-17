import { webview } from '@kit.ArkWeb';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import util from '@ohos.util';
import { FourD4yComposerChoice, FourD4yComposerImageAttachment, FourD4yComposerPreflightPayload, FourD4yComposerSubmissionPayload,
  FourD4yImageUploadPhase, FourD4yImageUploadStatusPayload, ForumComposerMode,
  extractFourD4yInlineImageAttachmentIds, getFourD4yComposerTitle, isExpectedFourD4yComposerPreflight,
  isExpectedFourD4yComposerSubmission, isReadyFourD4yComposerForm,
  parseFourD4yComposerPreflightPayload, parseFourD4yComposerSubmissionPayload,
  parseFourD4yImageUploadStatusPayload } from '../../domain/composer/FourD4yComposerContracts';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { createForumComposerPostEditedResult, createForumComposerReplyPublishedResult,
  ForumComposerRouteParams } from './ForumComposerRouteState';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { FourD4ySession } from '../../data/remote/FourD4ySession';

enum ComposerWebOperation {
  Preflight = 'preflight',
  Submit = 'submit'
}

interface NativeImageUploadFile {
  fileName: string;
  mimeType: string;
  bytes: ArrayBuffer;
}

interface NativeImageUploadPayload {
  boundary: string;
  bytes: ArrayBuffer;
}

interface NativeImageUploadTextField {
  name: string;
  value: string;
}

/** A current-composer image and its local, picker-granted preview URI. */
interface UploadedImageDraft {
  attachmentId: string;
  previewUri: string;
}

/** An image already rendered by the live edit form, with a safe preview URL. */
interface ExistingImageDraft {
  attachmentId: string;
  previewUri: string;
}

interface DetailedImageUploadContract {
  userId: string;
  uploadHash: string;
}

/**
 * Native editor backed by the live 4D4Y post form.  The Web component owns
 * cookies, CSRF fields, and the final browser submission;
 * ArkTS sees only a value-free structural contract and user-authored text.
 */
@Component
export struct ForumComposerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @State route: ForumComposerRouteParams = {
    mode: ForumComposerMode.Reply,
    forumId: '',
    threadId: '',
    postId: '',
    quotedFloor: 0,
    quotedAuthorName: '',
    initialDraft: '',
    threadTitle: '',
    forumName: '',
    forumThreadTypes: []
  };
  @State subjectDraft: string = '';
  /** Present only when the live same-post edit form exposes a subject field. */
  @State subjectFieldName: string = '';
  /** A reply edit page can expose an empty subject input; only a real title is editable. */
  @State hasEditableSubject: boolean = false;
  @State messageDraft: string = '';
  /** Presentation-only preview of the live quote template; never submitted on its own. */
  @State quotePreviewText: string = '';
  @State isPreflightLoading: boolean = false;
  @State isSubmitting: boolean = false;
  @State isFormReady: boolean = false;
  @State isImageUploadAvailable: boolean = false;
  @State isImageUploading: boolean = false;
  /** Existing images from this post's live edit draft, never the unused-upload tray. */
  @State existingImageDrafts: ExistingImageDraft[] = [];
  /** Deletions remain local until this one edit submission succeeds. */
  @State removedExistingImageAttachmentIds: string[] = [];
  @State removedNewImageAttachmentIds: string[] = [];
  @State uploadedImageAttachmentIds: string[] = [];
  @State uploadedImageDrafts: UploadedImageDraft[] = [];
  @State selectedImagePreviewUri: string = '';
  @State formMessage: string = '';
  /** A confirmed server rejection survives asynchronous form revalidation. */
  @State submissionErrorMessage: string = '';
  @State categoryOptions: FourD4yComposerChoice[] = [];
  @State categoryValue: string = '';
  @State tagsDraft: string = '';

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private readonly imageUploadProbeController: webview.WebviewController = new webview.WebviewController();
  // The visible control is a second, same-session ArkWeb document. Its file
  // input must receive the user's real tap before ArkWeb may open a picker.
  private readonly imageUploadController: webview.WebviewController = new webview.WebviewController();
  private readonly formTimeoutMillis: number = 30000;
  private formSequence: number = 0;
  private submissionSequence: number = 0;
  private formTimeoutId: number = -1;
  private isWebControllerAttached: boolean = false;
  private isComposerRouteReady: boolean = false;
  private webOperation: ComposerWebOperation = ComposerWebOperation.Preflight;
  private pendingSubject: string = '';
  private pendingMessage: string = '';
  private pendingImageAttachmentIds: string[] = [];
  private pendingRemovedExistingImageAttachmentIds: string[] = [];
  private pendingRemovedNewImageAttachmentIds: string[] = [];
  private pendingDiscardImageAttachmentIds: string[] = [];
  private isUnusedImageDecisionPending: boolean = false;
  private pendingCategoryValue: string = '';
  private pendingTags: string = '';
  // Read only from the current signed-in form. It is never persisted.
  private viewerUserId: string = '';
  private composerUrl: string = '';
  private readingPreflightSequence: number = -1;
  private readingSubmissionSequence: number = -1;
  private imageUploadProbeTimeoutId: number = -1;
  private imageUploadProbeRetryTimeoutId: number = -1;
  private imageUploadProbeSequence: number = -1;
  private imageUploadProbeUrl: string = '';
  private isImageUploadProbeLoading: boolean = false;
  private isImageUploadProbeReadPending: boolean = false;
  private imageUploadProbeReadAttempts: number = 0;
  private readonly imageUploadProbeReadAttemptLimit: number = 3;
  private readonly imageUploadProbeReadRetryMillis: number = 450;
  private nativeImageUploadProbeSequence: number = -1;
  private isNativeImageUploadProbeLoading: boolean = false;
  private readonly forumUserAgent: string =
    FourD4ySession.fullSiteUserAgent;
  private readonly nativeImageUploadLimitBytes: number = 20 * 1024 * 1024;
  // 4D4Y accepts its images one request at a time. Nine keeps one picker
  // selection practical without creating an unbounded upload batch.
  private readonly nativeImageUploadSelectionLimit: number = 9;
  private isImageUploadProbeControllerAttached: boolean = false;
  private hasImageUploadProbeLoadStarted: boolean = false;
  @State isImageUploadSurfaceReady: boolean = false;
  private isImageUploadSurfaceControllerAttached: boolean = false;
  private isImageUploadSurfaceLoading: boolean = false;
  private hasImageUploadSurfaceLoadStarted: boolean = false;
  private imageUploadSurfaceUrl: string = '';
  private imageUploadSurfaceSequence: number = -1;
  private imageUploadSequence: number = 0;
  private pendingImageUploadSequence: number = -1;
  private imageUploadStatusTimeoutId: number = -1;
  private imageUploadStatusDeadlineMillis: number = 0;
  private readonly imageUploadStatusPollMillis: number = 500;
  private readonly imageUploadStatusTimeoutMillis: number = 60000;
  private categoryFieldName: string = '';
  private tagsFieldName: string = '';
  private hasUserSelectedCategory: boolean = false;
  private hasLoadedEditExistingImages: boolean = false;
  /** The server-provided quote prefix remains in memory so the user never edits it accidentally. */
  private quoteMessagePrefix: string = '';
  private hasLoadedQuoteTemplate: boolean = false;
  private readonly composerInputId: string = 'hipda-oh-composer-input';
  private previousKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private hasAdjustedKeyboardAvoidMode: boolean = false;

  aboutToAppear(): void {
    try {
      const context = this.getUIContext();
      this.previousKeyboardAvoidMode = context.getKeyboardAvoidMode();
      context.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      this.hasAdjustedKeyboardAvoidMode = true;
    } catch (_error) {
      // Keep the platform default if this destination is not yet attached.
    }
  }

  aboutToDisappear(): void {
    this.clearFormWatchdog();
    this.clearImageUploadHashProbe();
    this.clearImageUploadStatusPolling();
    if (this.hasAdjustedKeyboardAvoidMode) {
      try {
        this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
      } catch (_error) {
        // The destination is already being destroyed; no further action is needed.
      }
      this.hasAdjustedKeyboardAvoidMode = false;
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // This isolated ArkWeb document is intentionally invisible. It holds
        // the current 4D4Y form and its one-time hidden fields; it never
        // replaces the native editor the user is reading.
        // Keep src empty and start each request through the controller once
        // its session is attached. This preserves the same ArkWeb session the
        // reader uses; 4D4Y's standard editor is requested with mobile=no.
        Web({ src: '', controller: this.webController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onComposerControllerAttached();
          })
          .onPageEnd((event) => {
            this.handleCompletedWebLoad(event.url);
          })
          // API 20+: unlike onPageEnd, this remains a single completion
          // callback when the main frame redirects before it fully completes.
          .onLoadFinished((event) => {
            this.handleCompletedWebLoad(event.url);
          })
          .onErrorReceive((event) => {
            if (!event.request.isMainFrame()) {
              return;
            }
            if (this.isSubmitting) {
              this.failSubmission('发表时网络出错，请先到论坛核对结果后再重试。');
            } else if (this.isCurrentPreflightRequest(event.request.getRequestUrl())) {
              this.failPreflight('暂时无法打开 4D4Y 发帖表单，请检查网络后重试。');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        // A separate one-pixel ArkWeb page performs the current 4D4Y
        // upload-capability preflight. It shares the app Web session but
        // never replaces the composer form or exposes a token to ArkTS.
        Web({ src: '', controller: this.imageUploadProbeController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onShowFileSelector((event) => {
            this.handleImageFileSelection(event.result);
            return true;
          })
          .onControllerAttached(() => {
            this.onImageUploadProbeControllerAttached();
          })
          // ArkWeb documents recommend page-end for runJavaScript. Keep the
          // completion hook below as a redirect fallback, but never let an
          // early DOM snapshot decide the upload capability by itself.
          .onPageEnd((event) => {
            if (this.isCurrentImageUploadProbeRequest(event.url)) {
              this.readImageUploadHashProbe(this.imageUploadProbeSequence);
            }
          })
          .onLoadFinished((event) => {
            if (this.isCurrentImageUploadProbeRequest(event.url)) {
              this.readImageUploadHashProbe(this.imageUploadProbeSequence);
            }
          })
          .onErrorReceive((event) => {
            if (event.request.isMainFrame() &&
              this.isCurrentImageUploadProbeRequest(event.request.getRequestUrl())) {
              this.handleImageUploadHashProbeResult(this.imageUploadProbeSequence, 'load-failed');
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        if (this.isAdvancedReplyMode()) {
          this.buildAdvancedReplyEditor();
        } else {
          Column() {
            Scroll() {
            Column({ space: 10 }) {
              if (this.route.mode === ForumComposerMode.NewThread) {
                this.buildDestinationSummary();
              }
              this.buildFormState();

              if (this.shouldShowTopicMetadata()) {
                this.buildNewThreadMetadata();
              }
              if (this.shouldShowSubjectInput()) {
                TextInput({ placeholder: '标题', text: this.subjectDraft })
                  .fontSize(17)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_muted'))
                  .backgroundColor($r('app.color.surface_subtle'))
                  .border({ width: 1, color: $r('app.color.border_strong'), radius: 6 })
                  .width('100%')
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => {
                    this.subjectDraft = value;
                  })
              }

            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 10 })
            }
            .layoutWeight(1)
            .width('100%')
            this.buildComposerInputBar();
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
        }

        if (this.selectedImagePreviewUri.length > 0) {
          this.buildSelectedImagePreview();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
    }
    .title(this.getComposerTitle())
    .menus(this.buildTitleActions)
    .onReady((context: NavDestinationContext) => {
      const route: ForumComposerRouteParams = context.pathInfo.param as ForumComposerRouteParams;
      this.route = route;
      this.subjectDraft = '';
      this.messageDraft = route.initialDraft;
      this.quotePreviewText = '';
      this.quoteMessagePrefix = '';
      this.hasLoadedQuoteTemplate = false;
      this.hasLoadedEditExistingImages = false;
      this.existingImageDrafts = [];
      this.removedExistingImageAttachmentIds = [];
      this.removedNewImageAttachmentIds = [];
      this.uploadedImageAttachmentIds = [];
      this.uploadedImageDrafts = [];
      this.isComposerRouteReady = true;
      this.prepareFormWhenReady();
    })
  }

  private onComposerControllerAttached(): void {
    try {
      this.webController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      this.isWebControllerAttached = true;
      this.prepareFormWhenReady();
    } catch (_error) {
      this.failPreflight('Unable to initialize composer session.');
    }
  }

  private onImageUploadProbeControllerAttached(): void {
    try {
      this.imageUploadProbeController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      this.isImageUploadProbeControllerAttached = true;
      this.loadImageUploadProbeWhenReady();
    } catch (_error) {
      if (this.isImageUploadProbeLoading) {
        this.handleImageUploadHashProbeResult(this.imageUploadProbeSequence, 'load-start-failed');
      }
    }
  }

  private prepareFormWhenReady(): void {
    if (this.isWebControllerAttached && this.isComposerRouteReady) {
      this.prepareForm();
    }
  }

  @Builder
  private buildDestinationSummary() {
    Column({ space: 5 }) {
      if (this.route.mode === ForumComposerMode.NewThread) {
        Text('发表到 ' + (this.route.forumName || ('板块 ' + this.route.forumId)))
          .fontSize(14)
          .fontColor($r('app.color.brand'))
      } else {
        Text(this.route.threadTitle || ('主题 ' + this.route.threadId))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.route.mode === ForumComposerMode.Quote) {
        Text('引用 #' + this.route.quotedFloor + (this.route.quotedAuthorName.length > 0 ? (' · ' + this.route.quotedAuthorName) : ''))
          .fontSize(13)
          .fontColor($r('app.color.brand'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private buildTitleActions() {
    // NG keeps the actual send action beside the editor rather than in the
    // navigation bar. Do not add decorative top-bar actions without a real
    // native counterpart.
    Row() {}
  }

  private isAdvancedReplyMode(): boolean {
    return this.route.mode === ForumComposerMode.Reply || this.route.mode === ForumComposerMode.Quote;
  }

  private getComposerTitle(): string {
    if (this.route.mode === ForumComposerMode.Quote) {
      return '引用 #' + this.route.quotedFloor + (this.route.quotedAuthorName.length > 0 ?
        (' · ' + this.route.quotedAuthorName) : '');
    }
    if (this.route.mode === ForumComposerMode.Reply) {
      return '高级回复';
    }
    return getFourD4yComposerTitle(this.route);
  }

  /** NG keeps the server-generated quote above the editor, never inside it. */
  @Builder
  private buildQuotePreview() {
    Column({ space: 4 }) {
      Text('引用内容')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text(this.quotePreviewText.length > 0 ? this.quotePreviewText : '正在读取引用内容…')
        .fontSize(14)
        .fontColor($r('app.color.text_body'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .backgroundColor($r('app.color.surface_subtle'))
    .border({ width: 1, color: $r('app.color.border_strong'), radius: 7 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  }

  /**
   * The detailed reply page intentionally gives the editable message every
   * remaining pixel after its compact metadata/quote header. This is separate
   * from new-thread and edit layouts, which retain their existing fields.
   */
  @Builder
  private buildAdvancedReplyEditor() {
    Column({ space: 10 }) {
      Column({ space: 8 }) {
        this.buildFormState();
        if (this.route.mode === ForumComposerMode.Quote) {
          this.buildQuotePreview();
        }
        if (this.supportsImageUpload() && this.isImageUploadAvailable) {
          this.buildImageUploadControls();
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, top: 10 })

      TextArea({ placeholder: '写下回复', text: this.messageDraft })
        .id(this.composerInputId)
        .defaultFocus(true)
        .layoutWeight(1)
        .fontSize(18)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_muted'))
        .backgroundColor($r('app.color.surface_subtle'))
        .border({ width: 1, color: $r('app.color.border_strong'), radius: 8 })
        .width('100%')
        .padding(12)
        .margin({ left: 16, right: 16 })
        .onAppear(() => {
          this.requestComposerInputFocus();
        })
        .onChange((value: string) => {
          this.messageDraft = value;
        })

      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('我')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
        }
        .width(38)
        .height(38)
        .backgroundColor($r('app.color.fill_selected'))
        .borderRadius(19)

        Blank().layoutWeight(1)

        if (this.isSubmitting) {
          LoadingProgress()
            .width(48)
            .height(48)
            .padding(10)
        } else {
          Image($r('app.media.toolbar_send'))
            .width(48)
            .height(48)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.brand'))
            .padding(8)
            .opacity(this.canSubmit() ? 1 : 0.3)
            .onClick(() => {
              this.submit();
            })
        }
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      .padding({ left: 16, right: 10, top: 6, bottom: 10 })
      .border({ width: { top: 1 }, color: $r('app.color.border_strong') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
    .align(Alignment.Top)
  }

  private requestComposerInputFocus(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus(this.composerInputId);
      } catch (_error) {
        // defaultFocus is retained as the frame-zero fallback.
      }
    }, 0);
  }

  /**
   * NG-style bottom editor: the reading area stays visually quiet and the
   * current user's composing surface remains immediately above the keyboard.
   * The neutral “我” marker intentionally does not pretend to be a fetched
   * avatar; P-24 will supply the shared icon/avatar treatment.
   */
  @Builder
  private buildComposerInputBar() {
    Column({ space: 8 }) {
      if (this.route.mode === ForumComposerMode.Edit &&
        (this.existingImageDrafts.length > 0 || this.removedExistingImageAttachmentIds.length > 0)) {
        this.buildExistingImageControls();
      }
      if (this.supportsImageUpload() && this.isImageUploadAvailable) {
        this.buildImageUploadControls();
      }
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('我')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
        }
        .width(38)
        .height(38)
        .backgroundColor($r('app.color.fill_selected'))
        .borderRadius(19)

        TextArea({ placeholder: this.route.mode === ForumComposerMode.Quote ? '编辑引用内容或写下回复' : '写下内容', text: this.messageDraft })
          .layoutWeight(1)
          .height(52)
          .fontSize(18)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_muted'))
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0, top: 4, bottom: 4 })
          .onChange((value: string) => {
            this.messageDraft = value;
          })

        if (this.isSubmitting) {
          LoadingProgress()
            .width(42)
            .height(42)
            .padding(10)
        } else {
          Image($r('app.media.toolbar_send'))
            .width(48)
            .height(48)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.brand'))
            .padding(8)
            .opacity(this.canSubmit() ? 1 : 0.3)
            .onClick(() => {
              if (this.canSubmit()) {
                this.submit();
              }
            })
        }
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      Divider()
        .color($r('app.color.border_strong'))
        .margin({ left: 48, right: 52 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .padding({ left: 14, right: 8, top: 8, bottom: 10 })
  }

  /**
   * Existing images retain only a safe URL already rendered by the live edit
   * form.  Keep them in a vertical list so a long multi-image post remains
   * usable on a phone; deletion is staged locally until submit.
   */
  @Builder
  private buildExistingImageControls() {
    Column({ space: 7 }) {
      if (this.getVisibleExistingImageDrafts().length > 0) {
        Row({ space: 8 }) {
          Text('原帖图片')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_body'))
          Text(this.getVisibleExistingImageDrafts().length + ' 张')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text('移除将在发送后生效')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        Column({ space: 8 }) {
          ForEach(this.getVisibleExistingImageDrafts(), (draft: ExistingImageDraft) => {
            Row({ space: 10 }) {
              if (draft.previewUri.length > 0) {
                Image(draft.previewUri)
                  .objectFit(ImageFit.Cover)
                  .width(82)
                  .height(62)
                  .border({ width: 1, color: $r('app.color.border_strong'), radius: 7 })
                  .onClick(() => {
                    this.selectedImagePreviewUri = draft.previewUri;
                  })
              } else {
                Column() {
                  Text('原帖图片')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .justifyContent(FlexAlign.Center)
                .width(82)
                .height(62)
                .backgroundColor($r('app.color.fill_subtle'))
                .border({ width: 1, color: $r('app.color.border_strong'), radius: 7 })
              }
              Text('图片 #' + draft.attachmentId)
                .fontSize(12)
                .fontColor($r('app.color.text_body'))
                .maxLines(1)
                .layoutWeight(1)
              Button('移除')
                .type(ButtonType.Normal)
                .fontSize(12)
                .fontColor($r('app.color.danger_text'))
                .backgroundColor(Color.Transparent)
                .enabled(!this.isImageUploading && !this.isSubmitting)
                .onClick(() => {
                  this.markExistingImageForRemoval(draft.attachmentId);
                })
            }
            .alignItems(VerticalAlign.Center)
            .width('100%')
            .padding({ left: 8, right: 4, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.surface_subtle'))
            .border({ width: 1, color: $r('app.color.border_strong'), radius: 7 })
          }, (draft: ExistingImageDraft) => draft.attachmentId)
        }
        .width('100%')
      }
      if (this.removedExistingImageAttachmentIds.length > 0) {
        Row({ space: 8 }) {
          Text('已标记移除 ' + this.removedExistingImageAttachmentIds.length + ' 张原帖图片')
            .fontSize(12)
            .fontColor($r('app.color.danger_text'))
            .layoutWeight(1)
          Button('全部撤销')
            .type(ButtonType.Normal)
            .fontSize(12)
            .fontColor($r('app.color.brand'))
            .backgroundColor(Color.Transparent)
            .enabled(!this.isImageUploading && !this.isSubmitting)
            .onClick(() => {
              this.restoreAllExistingImages();
            })
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private buildFormState() {
    if (!this.isLoggedIn) {
      Text('4D4Y 登录状态已失效，请返回后重新登录。')
        .fontSize(14)
        .fontColor($r('app.color.danger_text'))
        .width('100%')
    } else {
      if (this.submissionErrorMessage.length > 0) {
        Text(this.submissionErrorMessage)
          .fontSize(14)
          .fontColor($r('app.color.danger_text'))
          .width('100%')
      }
      if (this.isPreflightLoading) {
        Row({ space: 10 }) {
          LoadingProgress()
            .width(20)
            .height(20)
          Text('正在核对 4D4Y 发帖表单…')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      } else if (this.formMessage.length > 0 && !this.isFormReady) {
        Text(this.formMessage)
          .fontSize(14)
          .fontColor($r('app.color.danger_text'))
          .width('100%')
      }
    }
  }

  @Builder
  private buildImageUploadControls() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Button(this.isImageUploading ? '正在上传…' : '添加图片')
          .type(ButtonType.Normal)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.fill_selected'))
          .width(116)
          .height(36)
          .enabled(this.canSelectImageForUpload())
          .onClick(() => {
            this.startNativeImageUpload();
          })
        if (this.uploadedImageDrafts.length > 0) {
          Text('已添加 ' + this.uploadedImageDrafts.length + ' 张')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
        } else {
          Blank().layoutWeight(1)
        }
      }
      .width('100%')
      if (this.uploadedImageDrafts.length > 0) {
        Text('点击缩略图可放大预览；移除仅影响本次待发送内容。')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.uploadedImageDrafts, (draft: UploadedImageDraft) => {
              Column({ space: 6 }) {
                if (draft.previewUri.length > 0) {
                  Image(draft.previewUri)
                    .objectFit(ImageFit.Cover)
                    .width(112)
                    .height(84)
                    .border({ width: 1, color: $r('app.color.border_strong'), radius: 8 })
                    .onClick(() => {
                      this.selectedImagePreviewUri = draft.previewUri;
                    })
                } else {
                  Column() {
                    Text('已上传图片')
                      .fontSize(13)
                      .fontColor($r('app.color.text_detail'))
                  }
                  .justifyContent(FlexAlign.Center)
                  .width(112)
                  .height(84)
                  .backgroundColor($r('app.color.fill_subtle'))
                  .border({ width: 1, color: $r('app.color.border_strong'), radius: 8 })
                }
                Row({ space: 6 }) {
                  Text('#' + draft.attachmentId)
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .layoutWeight(1)
                  Button('移除')
                    .type(ButtonType.Normal)
                    .fontSize(12)
                    .fontColor($r('app.color.danger_text'))
                    .backgroundColor(Color.Transparent)
                    .enabled(!this.isImageUploading && !this.isSubmitting)
                    .onClick(() => {
                      this.removeUploadedImage(draft.attachmentId);
                    })
                }
                .width(112)
              }
              .width(112)
            }, (draft: UploadedImageDraft) => draft.attachmentId)
          }
          .padding({ top: 2, bottom: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(124)
      }
      Text('仅支持 JPG、PNG、GIF、BMP；每次最多选择 9 张，每张最大 20 MB。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private buildSelectedImagePreview() {
    Column({ space: 14 }) {
      Image(this.selectedImagePreviewUri)
        .objectFit(ImageFit.Contain)
        .width('100%')
        .layoutWeight(1)
      Button('关闭预览')
        .fontSize(15)
        .width(140)
        .onClick(() => {
          this.selectedImagePreviewUri = '';
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 40, bottom: 40 })
    .backgroundColor($r('app.color.upload_blocker_scrim'))
  }

  @Builder
  private buildNewThreadMetadata() {
    if (this.categoryOptions.length > 0) {
      Column({ space: 8 }) {
        Text('分类')
          .fontSize(14)
          .fontColor($r('app.color.text_detail'))
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.categoryOptions, (option: FourD4yComposerChoice) => {
              Button(option.label)
                .fontSize(13)
                .fontColor(this.categoryValue === option.value ? $r('app.color.on_brand') : $r('app.color.text_body'))
                .backgroundColor(this.categoryValue === option.value ? $r('app.color.brand') : $r('app.color.fill_subtle'))
                .borderRadius(16)
                .onClick(() => {
                  this.categoryValue = option.value;
                  this.hasUserSelectedCategory = true;
                })
            }, (option: FourD4yComposerChoice) => option.value)
          }
          .padding({ top: 2, bottom: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    if (this.tagsFieldName.length > 0) {
      TextInput({ placeholder: '标签（用逗号或空格隔开）', text: this.tagsDraft })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_muted'))
        .backgroundColor($r('app.color.surface_subtle'))
        .border({ width: 1, color: $r('app.color.border_strong'), radius: 6 })
        .width('100%')
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.tagsDraft = value;
        })
    }
  }

  private prepareForm(operation: ComposerWebOperation = ComposerWebOperation.Preflight): void {
    if (!this.hasValidRouteIdentity()) {
      this.failPreflight('发帖目标不完整，已阻止打开表单。');
      return;
    }
    this.formSequence += 1;
    this.webOperation = operation;
    this.pendingDiscardImageAttachmentIds = [];
    this.isUnusedImageDecisionPending = false;
    this.clearFormWatchdog();
    this.isPreflightLoading = true;
    this.isFormReady = false;
    this.isImageUploadAvailable = false;
    this.isImageUploadSurfaceReady = false;
    this.isImageUploadSurfaceLoading = false;
    this.hasImageUploadSurfaceLoadStarted = false;
    this.imageUploadSurfaceUrl = '';
    this.imageUploadSurfaceSequence = -1;
    this.formMessage = '';
    this.viewerUserId = '';
    this.clearImageUploadHashProbe();
    this.nativeImageUploadProbeSequence = -1;
    this.isNativeImageUploadProbeLoading = false;
    this.categoryOptions = [];
    this.subjectFieldName = '';
    this.hasEditableSubject = false;
    this.categoryFieldName = '';
    this.tagsFieldName = '';
    this.readingPreflightSequence = -1;
    this.composerUrl = this.getPreflightUrl(this.formSequence);
    this.startPreflightWatchdog(this.formSequence);
    try {
      this.webController.loadUrl(this.composerUrl);
    } catch (_error) {
      // First load can race with Web controller attachment; onPageEnd will complete it.
    }
  }

  private hasValidRouteIdentity(): boolean {
    if (this.route.mode === ForumComposerMode.NewThread) {
      return /^\d+$/.test(this.route.forumId);
    }
    if (!/^\d+$/.test(this.route.threadId)) {
      return false;
    }
    return (this.route.mode !== ForumComposerMode.Quote && this.route.mode !== ForumComposerMode.Edit) ||
      /^\d+$/.test(this.route.postId);
  }

  private shouldShowSubjectInput(): boolean {
    return this.route.mode === ForumComposerMode.NewThread ||
      (this.route.mode === ForumComposerMode.Edit && this.hasEditableSubject);
  }

  private shouldShowTopicMetadata(): boolean {
    return this.route.mode === ForumComposerMode.NewThread || this.shouldShowSubjectInput();
  }

  private getPreflightUrl(sequence: number): string {
    const base: string = 'https://www.4d4y.com/forum/post.php?';
    if (this.route.mode === ForumComposerMode.NewThread) {
      return base + 'action=newthread&fid=' + this.route.forumId + '&mobile=no&oh_compose=' + sequence;
    }
    if (this.route.mode === ForumComposerMode.Edit) {
      return base + 'action=edit&fid=' + this.route.forumId + '&tid=' + this.route.threadId +
        '&pid=' + this.route.postId + '&page=1&mobile=no&oh_compose=' + sequence;
    }
    let url: string = base + 'action=reply&tid=' + this.route.threadId;
    if (/^\d+$/.test(this.route.forumId)) {
      url += '&fid=' + this.route.forumId;
    }
    if (this.route.mode === ForumComposerMode.Quote) {
      url += '&repquote=' + this.route.postId;
    }
    return url + '&mobile=no&oh_compose=' + sequence;
  }

  private isCurrentPreflightRequest(url: string): boolean {
    return url.indexOf('/forum/post.php') >= 0 &&
      url.indexOf('oh_compose=' + this.formSequence) >= 0;
  }

  private handleCompletedWebLoad(url: string): void {
    // onPageEnd and onLoadFinished have no guaranteed order. Never let the
    // second completion callback for the GET preflight masquerade as the POST
    // result merely because the first callback has already started submit().
    if (this.isCurrentPreflightRequest(url)) {
      if (!this.isSubmitting) {
        this.readPreflightFromWeb();
      }
      return;
    }
    if (this.isSubmitting) {
      this.readSubmissionResult();
    }
  }

  private async readPreflightFromWeb(): Promise<void> {
    const expectedSequence: number = this.formSequence;
    if (this.readingPreflightSequence === expectedSequence) {
      return;
    }
    this.readingPreflightSequence = expectedSequence;
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getPreflightExtractionScript(expectedSequence)
      );
      if (expectedSequence !== this.formSequence) {
        return;
      }
      const payload: FourD4yComposerPreflightPayload | null =
        parseFourD4yComposerPreflightPayload(rawResult);
      if (payload === null || !isExpectedFourD4yComposerPreflight(payload, this.route, expectedSequence)) {
        this.failPreflight('发帖表单已打开，但无法确认它属于当前操作。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.failPreflight('4D4Y 登录状态已失效，请返回后重新登录。');
        return;
      }
      if (!isReadyFourD4yComposerForm(payload, this.route)) {
        if (payload.errorMessage.length > 0) {
          this.failPreflight(payload.errorMessage);
        } else if (payload.hasChallenge) {
          // Cloudflare's passive bootstrap script is present on some ordinary
          // forum pages. Treat it as an interactive verification only when the
          // server did not also provide a valid form or an explicit denial.
          this.failPreflight('4D4Y 要求先在网页中完成安全验证。');
        } else {
          this.failPreflight('当前 4D4Y 表单结构尚未通过校验，未启用发送。');
        }
        return;
      }
      this.clearFormWatchdog();
      this.isPreflightLoading = false;
      this.isFormReady = this.webOperation !== ComposerWebOperation.Submit;
      // The 4D4Y new-topic form can expose only an empty typeid=0 placeholder.
      // In that case, retain the live board-level mapping captured immediately
      // before navigation instead of fabricating a static category list.
      this.categoryOptions = payload.categoryOptions.length > 0 ? payload.categoryOptions :
      this.getRouteThreadTypeChoices();
      this.viewerUserId = payload.viewerUserId;
      this.subjectFieldName = payload.subjectFieldName;
      this.hasEditableSubject = this.route.mode === ForumComposerMode.Edit &&
        payload.subjectFieldName === 'subject' && payload.initialSubject.trim().length > 0;
      this.categoryFieldName = payload.categoryFieldName;
      this.tagsFieldName = payload.tagsFieldName;
      if (!this.hasUserSelectedCategory || !this.hasCategoryOption(this.categoryValue)) {
        this.categoryValue = payload.categoryValue;
      }
      if (this.route.mode === ForumComposerMode.Quote &&
        (!this.hasLoadedQuoteTemplate || this.webOperation === ComposerWebOperation.Submit)) {
        this.quoteMessagePrefix = payload.initialMessage.trim();
        this.quotePreviewText = this.extractQuotePreviewText(this.quoteMessagePrefix);
        this.hasLoadedQuoteTemplate = true;
        if (this.quoteMessagePrefix.length === 0) {
          this.failPreflight('4D4Y 未提供可确认的引用内容，已阻止发表。');
          return;
        }
      } else if (this.route.mode === ForumComposerMode.Edit && this.messageDraft.length === 0 &&
        payload.initialMessage.length > 0) {
        this.messageDraft = payload.initialMessage;
      }
      if (this.route.mode === ForumComposerMode.Edit && !this.hasLoadedEditExistingImages) {
        this.existingImageDrafts = this.mergeExistingImageDrafts(
          extractFourD4yInlineImageAttachmentIds(payload.initialMessage), payload.editImageAttachments);
        this.removedExistingImageAttachmentIds = [];
        this.hasLoadedEditExistingImages = true;
      }
      if (this.route.mode === ForumComposerMode.Edit && this.subjectDraft.length === 0 &&
        payload.initialSubject.length > 0) {
        this.subjectDraft = payload.initialSubject;
      }
      if (this.webOperation === ComposerWebOperation.Submit) {
        this.pendingDiscardImageAttachmentIds = this.route.mode === ForumComposerMode.Edit ? [] :
          payload.unusedImageAttachmentIds.filter((attachmentId: string) =>
            this.pendingImageAttachmentIds.indexOf(attachmentId) < 0);
        if (this.pendingDiscardImageAttachmentIds.length > 0) {
          this.requestUnusedImageDiscardConfirmation(expectedSequence);
          return;
        }
        this.beginSubmission(expectedSequence);
        return;
      }
      // Always inspect the canonical desktop reply page before enabling the
      // visible upload control. The mobile composer occasionally exposes a
      // hash without the matching upload contract used by 4D4Y clients.
      this.isImageUploadAvailable = false;
      if (this.supportsImageUpload()) {
        this.formMessage = '4D4Y 表单已校验；正在核对图片上传能力。';
        this.startImageUploadHashProbe(expectedSequence);
      } else {
        this.formMessage = '4D4Y 表单已校验；可以发送。';
      }
    } catch (_error) {
      if (expectedSequence === this.formSequence) {
        this.failPreflight('暂时无法读取 4D4Y 发帖表单，请稍后重试。');
      }
    }
  }

  private supportsImageUpload(): boolean {
    const isSupportedMode: boolean = this.route.mode === ForumComposerMode.Reply ||
      this.route.mode === ForumComposerMode.Quote || this.route.mode === ForumComposerMode.Edit;
    return isSupportedMode && /^\d+$/.test(this.route.forumId) && /^\d+$/.test(this.route.threadId) &&
      (this.route.mode !== ForumComposerMode.Edit || /^\d+$/.test(this.route.postId));
  }

  private canSelectImageForUpload(): boolean {
    return this.supportsImageUpload() && this.isLoggedIn && this.isFormReady &&
      this.isImageUploadAvailable && !this.isImageUploading && !this.isSubmitting;
  }

  /** Uses the system picker directly; no Web file input is involved. */
  private startNativeImageUpload(): void {
    if (!this.canSelectImageForUpload()) {
      return;
    }
    this.imageUploadSequence += 1;
    this.pendingImageUploadSequence = this.imageUploadSequence;
    this.isImageUploading = true;
    this.formMessage = '正在打开系统图库…';
    void this.selectImageForNativeUpload(this.pendingImageUploadSequence);
  }

  private async selectImageForNativeUpload(sequence: number): Promise<void> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = this.nativeImageUploadSelectionLimit;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const selected: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
        return;
      }
      if (selected.photoUris.length === 0) {
        this.cancelImageUpload(sequence);
        return;
      }
      const selectedUris: string[] = this.getNewNativeImageUploadUris(selected.photoUris);
      if (selectedUris.length === 0) {
        this.cancelImageUpload(sequence);
        this.formMessage = '未添加新的图片。';
        return;
      }
      let uploadedCount: number = 0;
      let failedCount: number = 0;
      for (let index: number = 0; index < selectedUris.length; index += 1) {
        if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
          return;
        }
        const previewUri: string = selectedUris[index];
        this.formMessage = '正在读取图片（' + (index + 1) + '/' + selectedUris.length + '）…';
        const image: NativeImageUploadFile | null = this.readNativeImageUploadFile(previewUri);
        if (image === null) {
          failedCount += 1;
          continue;
        }
        this.formMessage = '正在上传图片（' + (index + 1) + '/' + selectedUris.length + '）…';
        const attachmentId: string = await this.uploadNativeImage(image);
        if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
          return;
        }
        if (!/^\d+$/.test(attachmentId)) {
          failedCount += 1;
          continue;
        }
        this.addUploadedImage(attachmentId, previewUri);
        uploadedCount += 1;
      }
      this.completeNativeImageUploadBatch(sequence, uploadedCount, failedCount, selectedUris.length);
    } catch (_error) {
      if (sequence === this.pendingImageUploadSequence && this.isImageUploading) {
        this.failImageUpload(sequence, '无法读取或上传所选图片。');
      }
    }
  }

  private getNewNativeImageUploadUris(photoUris: string[]): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < photoUris.length && result.length < this.nativeImageUploadSelectionLimit;
      index += 1) {
      const uri: string = photoUris[index];
      const isAlreadyAdded: boolean = this.uploadedImageDrafts.some(
        (draft: UploadedImageDraft) => draft.previewUri === uri);
      if (uri.length > 0 && !isAlreadyAdded && result.indexOf(uri) < 0) {
        result.push(uri);
      }
    }
    return result;
  }

  private readNativeImageUploadFile(uri: string): NativeImageUploadFile | null {
    let sourceFile: fs.File | null = null;
    try {
      sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(sourceFile.fd).size;
      if (!Number.isSafeInteger(size) || size <= 0 || size > this.nativeImageUploadLimitBytes) {
        throw new Error('image-size-invalid');
      }
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      const readLength: number = fs.readSync(sourceFile.fd, bytes);
      if (readLength !== size) {
        throw new Error('image-read-incomplete');
      }
      const mimeType: string = this.getNativeImageMimeType(bytes);
      if (mimeType.length === 0) {
        throw new Error('image-type-unsupported');
      }
      const fileName: string = 'hipda-image.' + this.getNativeImageExtension(mimeType);
      return {
        fileName,
        mimeType,
        bytes
      };
    } catch (_error) {
      return null;
    } finally {
      if (sourceFile !== null) {
        try {
          fs.closeSync(sourceFile);
        } catch (_error) {
          // The picker-granted descriptor is never retained after validation.
        }
      }
    }
  }

  private getNativeImageMimeType(bytes: ArrayBuffer): string {
    const values: Uint8Array = new Uint8Array(bytes);
    if (values.length >= 3 && values[0] === 0xFF && values[1] === 0xD8 && values[2] === 0xFF) {
      return 'image/jpeg';
    }
    if (values.length >= 8 && values[0] === 0x89 && values[1] === 0x50 && values[2] === 0x4E &&
      values[3] === 0x47 && values[4] === 0x0D && values[5] === 0x0A && values[6] === 0x1A && values[7] === 0x0A) {
      return 'image/png';
    }
    if (values.length >= 6 && values[0] === 0x47 && values[1] === 0x49 && values[2] === 0x46 &&
      values[3] === 0x38 && (values[4] === 0x37 || values[4] === 0x39) && values[5] === 0x61) {
      return 'image/gif';
    }
    if (values.length >= 2 && values[0] === 0x42 && values[1] === 0x4D) {
      return 'image/bmp';
    }
    return '';
  }

  private getNativeImageExtension(mimeType: string): string {
    if (mimeType === 'image/png') {
      return 'png';
    }
    if (mimeType === 'image/gif') {
      return 'gif';
    }
    if (mimeType === 'image/bmp') {
      return 'bmp';
    }
    return 'jpg';
  }

  private async uploadNativeImage(image: NativeImageUploadFile): Promise<string> {
    try {
      const contract: DetailedImageUploadContract | null = await this.getDetailedImageUploadContract();
      if (contract === null) {
        return '';
      }
      const request: http.HttpRequest = http.createHttp();
      try {
        const uploadUrl: string = 'https://www.4d4y.com/forum/misc.php?action=swfupload&operation=upload&simple=1&type=image';
        const payload: NativeImageUploadPayload = this.buildNativeImageUploadPayload(contract, image);
        const cookieHeader: string = await this.getNativeImageUploadCookieHeader(contract.userId);
        if (cookieHeader.length === 0) {
          return '';
        }
        const response: http.HttpResponse = await request.request(
          uploadUrl, {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'multipart/form-data; boundary=' + payload.boundary,
              'Cookie': cookieHeader,
              'Origin': 'https://www.4d4y.com',
              'User-Agent': this.forumUserAgent,
              'Referer': this.getNativeDetailedComposerUrl()
            },
            extraData: payload.bytes,
            connectTimeout: 20000,
            readTimeout: 60000
          });
        const result: string = typeof response.result === 'string' ? response.result.trim() : '';
        const match: RegExpMatchArray | null = result.match(/^DISCUZUPLOAD\|0\|(\d+)\|/);
        return match === null ? '' : match[1];
      } finally {
        request.destroy();
      }
    } catch (_error) {
      return '';
    }
  }

  private buildNativeImageUploadPayload(contract: DetailedImageUploadContract,
    image: NativeImageUploadFile): NativeImageUploadPayload {
    const boundary: string = '----HipdaOHBoundary' + Date.now().toString() +
      this.imageUploadSequence.toString();
    const encoder: util.TextEncoder = new util.TextEncoder();
    const chunks: Uint8Array[] = [];
    const fields: NativeImageUploadTextField[] = [
      { name: 'uid', value: contract.userId },
      { name: 'hash', value: contract.uploadHash },
      { name: 'action', value: 'swfupload' },
      { name: 'operation', value: 'upload' },
      { name: 'simple', value: '1' },
      { name: 'type', value: 'image' }
    ];
    for (let index: number = 0; index < fields.length; index += 1) {
      const field: NativeImageUploadTextField = fields[index];
      chunks.push(encoder.encodeInto('--' + boundary + '\r\n' +
        'Content-Disposition: form-data; name="' + field.name + '"\r\n\r\n' + field.value + '\r\n'));
    }
    chunks.push(encoder.encodeInto('--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="Filedata"; filename="' + image.fileName + '"\r\n' +
      'Content-Type: ' + image.mimeType + '\r\n\r\n'));
    chunks.push(new Uint8Array(image.bytes));
    chunks.push(encoder.encodeInto('\r\n--' + boundary + '--\r\n'));

    let totalLength: number = 0;
    for (let index: number = 0; index < chunks.length; index += 1) {
      totalLength += chunks[index].length;
    }
    const bytes: Uint8Array = new Uint8Array(totalLength);
    let offset: number = 0;
    for (let index: number = 0; index < chunks.length; index += 1) {
      bytes.set(chunks[index], offset);
      offset += chunks[index].length;
    }
    const payloadBytes: ArrayBuffer = bytes.buffer as ArrayBuffer;
    const payload: NativeImageUploadPayload = { boundary: boundary, bytes: payloadBytes };
    return payload;
  }

  private async getDetailedImageUploadContract(): Promise<DetailedImageUploadContract | null> {
    const cookieHeader: string = await this.getNativeImageUploadCookieHeader(this.viewerUserId);
    if (cookieHeader.length === 0) {
      return null;
    }
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(this.getNativeDetailedComposerUrl(), {
        method: http.RequestMethod.GET,
        header: {
          'Cookie': cookieHeader,
          'User-Agent': this.forumUserAgent,
          'Referer': 'https://www.4d4y.com/forum/viewthread.php?tid=' + this.route.threadId
        },
        connectTimeout: 20000,
        readTimeout: 20000
      });
      const page: string = typeof response.result === 'string' ? response.result : '';
      const contract: DetailedImageUploadContract | null = this.extractDetailedImageUploadContract(page);
      return contract;
    } catch (_error) {
      return null;
    } finally {
      request.destroy();
    }
  }

  private extractDetailedImageUploadContract(page: string): DetailedImageUploadContract | null {
    const userId: string = this.extractDetailedReplyUserId(page);
    if (userId.length === 0) {
      return null;
    }
    const inputTagPattern: RegExp = /<input\b[^>]*>/ig;
    let inputTagMatch: RegExpExecArray | null = inputTagPattern.exec(page);
    while (inputTagMatch !== null) {
      const tag: string = inputTagMatch[0];
      const nameMatch: RegExpMatchArray | null = tag.match(/\bname\s*=\s*['"]?([^'"\s>]+)/i);
      const valueMatch: RegExpMatchArray | null = tag.match(/\bvalue\s*=\s*['"]([^'"]*)['"]/i);
      if (nameMatch !== null && valueMatch !== null && nameMatch[1] === 'hash' && valueMatch[1].length > 0) {
        return { userId, uploadHash: valueMatch[1] };
      }
      inputTagMatch = inputTagPattern.exec(page);
    }
    return null;
  }

  private extractDetailedReplyUserId(page: string): string {
    // This mirrors the current 4D4Y browser upload flow: it reads the uid
    // from the logged-in user's #umenu space link, not a legacy JS variable.
    const menuIndex: number = page.search(/id\s*=\s*["']umenu["']/i);
    if (menuIndex >= 0) {
      const menuHtml: string = page.substring(menuIndex, Math.min(page.length, menuIndex + 2400));
      const menuUserMatch: RegExpMatchArray | null = menuHtml.match(/[?&]uid=(\d+)/i);
      if (menuUserMatch !== null) {
        return menuUserMatch[1];
      }
    }
    const legacyUserMatch: RegExpMatchArray | null = page.match(/discuz_uid\s*=\s*['"]?(\d+)/i);
    return legacyUserMatch === null ? '' : legacyUserMatch[1];
  }

  private completeNativeImageUploadBatch(sequence: number, uploadedCount: number, failedCount: number,
    totalCount: number): void {
    if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
      return;
    }
    this.isImageUploading = false;
    this.pendingImageUploadSequence = -1;
    if (uploadedCount === totalCount) {
      this.formMessage = '已上传 ' + uploadedCount + ' 张图片并插入正文；发送前仍可移除。';
    } else if (uploadedCount > 0) {
      this.formMessage = '已上传 ' + uploadedCount + '/' + totalCount + ' 张图片；失败 ' + failedCount + ' 张，可重新选择失败图片。';
    } else {
      this.formMessage = '所选图片未上传成功；请检查格式、大小或网络后重试。';
    }
  }

  private handleImageFileSelection(result: FileSelectorResult): void {
    if (!this.canSelectImageForUpload()) {
      result.handleFileList([]);
      return;
    }
    this.clearImageUploadStatusPolling();
    this.imageUploadSequence += 1;
    this.pendingImageUploadSequence = this.imageUploadSequence;
    this.isImageUploading = true;
    this.formMessage = '正在打开系统图库…';
    this.selectImageForWebUpload(result, this.pendingImageUploadSequence);
  }

  private async selectImageForWebUpload(result: FileSelectorResult, sequence: number): Promise<void> {
    if (sequence <= 0 || !this.isImageUploading) {
      return;
    }
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const selected: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (sequence !== this.pendingImageUploadSequence) {
        return;
      }
      if (selected.photoUris.length === 0) {
        result.handleFileList([]);
        this.cancelImageUpload(sequence);
        return;
      }
      await this.imageUploadController.runJavaScript(this.getImageUploadSelectionScript(sequence));
      if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
        result.handleFileList([]);
        return;
      }
      result.handleFileList([selected.photoUris[0]]);
      this.formMessage = '正在上传图片…';
      this.startImageUploadStatusPolling(sequence);
    } catch (_error) {
      console.error('4D4Y system photo picker failed before upload.');
      this.failImageUpload(sequence, '无法读取所选图片。');
    }
  }

  private startImageUploadStatusPolling(sequence: number): void {
    if (sequence !== this.pendingImageUploadSequence) {
      return;
    }
    this.imageUploadStatusDeadlineMillis = Date.now() + this.imageUploadStatusTimeoutMillis;
    this.scheduleImageUploadStatusPoll(sequence);
  }

  private scheduleImageUploadStatusPoll(sequence: number): void {
    if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
      return;
    }
    if (Date.now() >= this.imageUploadStatusDeadlineMillis) {
      this.failImageUpload(sequence, '图片上传超时，请先到论坛确认后再重试。');
      return;
    }
    if (this.imageUploadStatusTimeoutId >= 0) {
      clearTimeout(this.imageUploadStatusTimeoutId);
    }
    this.imageUploadStatusTimeoutId = setTimeout(() => {
      this.readImageUploadStatus(sequence);
    }, this.imageUploadStatusPollMillis);
  }

  private async readImageUploadStatus(sequence: number): Promise<void> {
    if (sequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
      return;
    }
    try {
      const rawResult: string = await this.imageUploadController.runJavaScript(
        this.getImageUploadStatusScript(sequence)
      );
      const payload: FourD4yImageUploadStatusPayload | null =
        parseFourD4yImageUploadStatusPayload(rawResult);
      if (payload === null || payload.uploadSequence !== sequence) {
        this.failImageUpload(sequence, '图片上传状态无法确认。');
        return;
      }
      this.handleImageUploadStatus(payload);
    } catch (_error) {
      this.failImageUpload(sequence, '无法读取图片上传状态。');
    }
  }

  private handleImageUploadStatus(payload: FourD4yImageUploadStatusPayload): void {
    if (payload.uploadSequence !== this.pendingImageUploadSequence || !this.isImageUploading) {
      return;
    }
    if (payload.phase === FourD4yImageUploadPhase.Selecting ||
      payload.phase === FourD4yImageUploadPhase.Uploading) {
      this.formMessage = payload.phase === FourD4yImageUploadPhase.Selecting ?
        '正在等待选择图片…' : '正在上传图片…';
      this.scheduleImageUploadStatusPoll(payload.uploadSequence);
      return;
    }
    if (payload.phase === FourD4yImageUploadPhase.Succeeded && payload.attachmentIds.length === 1) {
      const attachmentId: string = payload.attachmentIds[0];
      this.addUploadedImage(attachmentId, '');
      this.clearImageUploadStatusPolling();
      this.isImageUploading = false;
      this.pendingImageUploadSequence = -1;
      this.formMessage = '图片已上传并插入正文；发送时将一并关联到帖子。';
      this.resetImageUploadSurface();
      return;
    }
    if (payload.phase === FourD4yImageUploadPhase.Cancelled) {
      this.cancelImageUpload(payload.uploadSequence);
      return;
    }
    this.failImageUpload(payload.uploadSequence, '论坛未确认图片上传成功。');
  }

  private cancelImageUpload(sequence: number): void {
    if (sequence !== this.pendingImageUploadSequence) {
      return;
    }
    this.clearImageUploadStatusPolling();
    this.isImageUploading = false;
    this.pendingImageUploadSequence = -1;
    this.formMessage = '已取消选择图片。';
    this.resetImageUploadSurface();
  }

  private failImageUpload(sequence: number, message: string): void {
    if (sequence !== this.pendingImageUploadSequence) {
      return;
    }
    this.clearImageUploadStatusPolling();
    this.isImageUploading = false;
    this.pendingImageUploadSequence = -1;
    this.formMessage = message;
    this.resetImageUploadSurface();
  }

  private clearImageUploadStatusPolling(): void {
    if (this.imageUploadStatusTimeoutId >= 0) {
      clearTimeout(this.imageUploadStatusTimeoutId);
      this.imageUploadStatusTimeoutId = -1;
    }
    this.imageUploadStatusDeadlineMillis = 0;
  }

  private addUploadedImage(attachmentId: string, previewUri: string): void {
    if (this.uploadedImageAttachmentIds.indexOf(attachmentId) < 0) {
      this.uploadedImageAttachmentIds = this.uploadedImageAttachmentIds.concat([attachmentId]);
      this.messageDraft += '\n[attachimg]' + attachmentId + '[/attachimg]\n';
    }
    this.removedNewImageAttachmentIds = this.removedNewImageAttachmentIds.filter(
      (id: string) => id !== attachmentId);
    const existingDraft: UploadedImageDraft | undefined = this.uploadedImageDrafts.find(
      (draft: UploadedImageDraft) => draft.attachmentId === attachmentId);
    if (existingDraft === undefined) {
      this.uploadedImageDrafts = this.uploadedImageDrafts.concat([{ attachmentId, previewUri }]);
    }
  }

  private removeUploadedImage(attachmentId: string): void {
    if (this.uploadedImageAttachmentIds.indexOf(attachmentId) < 0 || this.isImageUploading || this.isSubmitting) {
      return;
    }
    this.uploadedImageAttachmentIds = this.uploadedImageAttachmentIds.filter(
      (id: string) => id !== attachmentId);
    const removedDraft: UploadedImageDraft | undefined = this.uploadedImageDrafts.find(
      (draft: UploadedImageDraft) => draft.attachmentId === attachmentId);
    this.uploadedImageDrafts = this.uploadedImageDrafts.filter(
      (draft: UploadedImageDraft) => draft.attachmentId !== attachmentId);
    if (removedDraft !== undefined && removedDraft.previewUri === this.selectedImagePreviewUri) {
      this.selectedImagePreviewUri = '';
    }
    this.removeInlineImageMarker(attachmentId);
    if (this.route.mode === ForumComposerMode.Edit &&
      this.removedNewImageAttachmentIds.indexOf(attachmentId) < 0) {
      this.removedNewImageAttachmentIds = this.removedNewImageAttachmentIds.concat([attachmentId]);
    }
    this.formMessage = '已移除图片；不会随本次回复提交。';
  }

  private getVisibleExistingImageDrafts(): ExistingImageDraft[] {
    return this.existingImageDrafts.filter((draft: ExistingImageDraft) =>
      this.removedExistingImageAttachmentIds.indexOf(draft.attachmentId) < 0);
  }

  private mergeExistingImageDrafts(messageAttachmentIds: string[],
    formAttachments: FourD4yComposerImageAttachment[]): ExistingImageDraft[] {
    const result: ExistingImageDraft[] = [];
    const addDraft = (attachmentId: string, previewUri: string): void => {
      if (!/^\d+$/.test(attachmentId)) {
        return;
      }
      const existingIndex: number = result.findIndex((draft: ExistingImageDraft) =>
        draft.attachmentId === attachmentId);
      if (existingIndex < 0) {
        result.push({ attachmentId: attachmentId, previewUri: previewUri });
      } else if (result[existingIndex].previewUri.length === 0 && previewUri.length > 0) {
        result[existingIndex] = { attachmentId: attachmentId, previewUri: previewUri };
      }
    };
    messageAttachmentIds.forEach((attachmentId: string) => addDraft(attachmentId, ''));
    formAttachments.forEach((attachment: FourD4yComposerImageAttachment) =>
      addDraft(attachment.attachmentId, attachment.previewUrl));
    return result;
  }

  private markExistingImageForRemoval(attachmentId: string): void {
    if (this.route.mode !== ForumComposerMode.Edit || this.isImageUploading || this.isSubmitting ||
      this.existingImageDrafts.findIndex((draft: ExistingImageDraft) =>
        draft.attachmentId === attachmentId) < 0 ||
      this.removedExistingImageAttachmentIds.indexOf(attachmentId) >= 0) {
      return;
    }
    this.removedExistingImageAttachmentIds = this.removedExistingImageAttachmentIds.concat([attachmentId]);
    this.removeInlineImageMarker(attachmentId);
    this.formMessage = '已标记移除原帖图片；发送编辑后才会生效。';
  }

  private restoreAllExistingImages(): void {
    if (this.route.mode !== ForumComposerMode.Edit || this.isImageUploading || this.isSubmitting ||
      this.removedExistingImageAttachmentIds.length === 0) {
      return;
    }
    const restoredAttachmentIds: string[] = this.removedExistingImageAttachmentIds.slice();
    this.removedExistingImageAttachmentIds = [];
    restoredAttachmentIds.forEach((attachmentId: string) => {
      const marker: string = '[attachimg]' + attachmentId + '[/attachimg]';
      if (this.messageDraft.indexOf(marker) < 0) {
        this.messageDraft = this.messageDraft.trim() + '\n' + marker + '\n';
      }
    });
    this.formMessage = '已撤销原帖图片移除；尚未发送任何修改。';
  }

  private removeInlineImageMarker(attachmentId: string): void {
    if (!/^\d+$/.test(attachmentId)) {
      return;
    }
    const marker: RegExp = new RegExp('\\s*\\[attachimg\\]' + attachmentId + '\\[\\/attachimg\\]\\s*', 'ig');
    this.messageDraft = this.messageDraft.replace(marker, '\n').trim();
  }

  private canSubmit(): boolean {
    if (!this.isLoggedIn || !this.isFormReady || this.isPreflightLoading || this.isImageUploading || this.isSubmitting ||
      this.messageDraft.trim().length === 0) {
      return false;
    }
    if (this.route.mode === ForumComposerMode.Quote && this.quoteMessagePrefix.trim().length === 0) {
      return false;
    }
    return !this.shouldShowSubjectInput() || this.subjectDraft.trim().length > 0;
  }

  /**
   * A quote prefix is supplied by the live 4D4Y form. The preview is only a
   * compact visual projection: it is not editable and is never used as the
   * submission source. The original prefix is rejoined below unchanged.
   */
  private extractQuotePreviewText(template: string): string {
    const matchedQuote: RegExpMatchArray | null = template.match(/\[quote(?:=[^\]]*)?\]([\s\S]*?)\[\/quote\]/i);
    const quoteBody: string = matchedQuote === null ? template : matchedQuote[1];
    return quoteBody
      .replace(/\[(?:\/)?(?:b|i|u|s|color|size|font|align|url|img|attachimg|attach)[^\]]*\]/ig, ' ')
      .replace(/\r\n/g, '\n')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
      .slice(0, 480);
  }

  private getOutgoingMessage(): string {
    const body: string = this.messageDraft.trim();
    if (this.route.mode !== ForumComposerMode.Quote) {
      return body;
    }
    const quotePrefix: string = this.quoteMessagePrefix.trim();
    return quotePrefix.length > 0 ? quotePrefix + '\n\n' + body : body;
  }

  private submit(): void {
    if (!this.canSubmit()) {
      return;
    }
    if (this.isCategoryRequired() && !this.hasSelectedCategory()) {
      this.submissionErrorMessage = 'Buy & Sell 发主题必须先选择分类。';
      this.formMessage = '请选择交易分类后再发送。';
      return;
    }
    this.submissionErrorMessage = '';
    this.submissionSequence += 1;
    this.pendingSubject = this.subjectDraft.trim();
    this.pendingMessage = this.getOutgoingMessage();
    this.pendingImageAttachmentIds = this.uploadedImageAttachmentIds.slice();
    this.pendingRemovedExistingImageAttachmentIds = this.route.mode === ForumComposerMode.Edit ?
      this.removedExistingImageAttachmentIds.slice() : [];
    this.pendingRemovedNewImageAttachmentIds = this.route.mode === ForumComposerMode.Edit ?
      this.removedNewImageAttachmentIds.slice() : [];
    this.pendingCategoryValue = this.categoryValue;
    this.pendingTags = this.tagsDraft.trim();
    this.isFormReady = false;
    this.formMessage = '正在重新获取一次性 4D4Y 表单…';
    this.prepareForm(ComposerWebOperation.Submit);
  }

  private requestUnusedImageDiscardConfirmation(preflightSequence: number): void {
    if (this.webOperation !== ComposerWebOperation.Submit || preflightSequence !== this.formSequence ||
      this.pendingDiscardImageAttachmentIds.length === 0) {
      return;
    }
    this.isUnusedImageDecisionPending = true;
    const count: number = this.pendingDiscardImageAttachmentIds.length;
    this.formMessage = `发现 ${count} 张此前上传但未插入本次正文的图片。请确认是否丢弃它们后发送。`;
    this.getUIContext().getPromptAction().showDialog({
      message: `4D4Y 仍保留 ${count} 张未使用图片；若继续发送而不处理，它们可能被一并关联到本回复。`,
      buttons: [
        { text: '取消发送', color: $r('app.color.text_body') },
        { text: '丢弃并发送', color: $r('app.color.danger_text') }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.isUnusedImageDecisionPending = false;
        this.beginSubmission(preflightSequence);
        return;
      }
      this.cancelUnusedImageDiscardConfirmation();
    }).catch(() => {
      this.cancelUnusedImageDiscardConfirmation();
    });
  }

  private cancelUnusedImageDiscardConfirmation(): void {
    if (!this.isUnusedImageDecisionPending) {
      return;
    }
    this.isUnusedImageDecisionPending = false;
    this.isFormReady = true;
    this.formMessage = '已取消发送；未使用图片尚未清理，也不会被自动发表。';
  }

  private async beginSubmission(preflightSequence: number): Promise<void> {
    if (this.webOperation !== ComposerWebOperation.Submit || preflightSequence !== this.formSequence ||
      this.isUnusedImageDecisionPending) {
      return;
    }
    this.isSubmitting = true;
    this.formMessage = '正在提交，请勿重复操作…';
    this.startSubmissionWatchdog(this.submissionSequence);
    this.submitLoadedForm();
  }

  private async submitLoadedForm(): Promise<void> {
    if (!this.isSubmitting) {
      return;
    }
    try {
      await this.webController.runJavaScript(this.getSubmissionScript(this.pendingSubject, this.pendingMessage,
        this.pendingCategoryValue, this.pendingTags, this.pendingImageAttachmentIds,
        this.pendingDiscardImageAttachmentIds, this.pendingRemovedExistingImageAttachmentIds,
        this.pendingRemovedNewImageAttachmentIds));
    } catch (_error) {
      // The navigation following requestSubmit() can interrupt this promise.
      // Only the terminal page parser decides whether it was successful.
    }
  }

  private async readSubmissionResult(): Promise<void> {
    const expectedSubmissionSequence: number = this.submissionSequence;
    if (this.readingSubmissionSequence === expectedSubmissionSequence) {
      return;
    }
    this.readingSubmissionSequence = expectedSubmissionSequence;
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getSubmissionResultScript(expectedSubmissionSequence)
      );
      if (!this.isSubmitting || expectedSubmissionSequence !== this.submissionSequence) {
        return;
      }
      const payload: FourD4yComposerSubmissionPayload | null =
        parseFourD4yComposerSubmissionPayload(rawResult);
      if (payload === null || !isExpectedFourD4yComposerSubmission(payload, this.route,
        expectedSubmissionSequence)) {
        this.failSubmission('发表结果无法确认；请先到论坛核对后再重试。');
        return;
      }
      if (!payload.succeeded) {
        if (payload.loginRequired) {
          this.failSubmission('4D4Y 登录状态已失效，内容未被当作已发表处理。');
        } else {
          this.recoverFromRejectedSubmission(payload.errorMessage.length > 0 ? payload.errorMessage :
            '4D4Y 未确认发表成功，内容没有被当作已发表处理。');
        }
        return;
      }
      this.clearFormWatchdog();
      this.isSubmitting = false;
      this.isFormReady = false;
      this.formMessage = '已发表。';
      if (this.route.mode === ForumComposerMode.NewThread && payload.createdThreadId.length > 0) {
        this.pathStack.pushPathByName('ThreadDetail',
          createThreadRouteParams(payload.createdThreadId, this.pendingSubject, 0, 1, 0, this.route.forumId));
        return;
      }
      if (this.route.mode === ForumComposerMode.Reply || this.route.mode === ForumComposerMode.Quote) {
        this.pathStack.pop(createForumComposerReplyPublishedResult(this.route.threadId));
        return;
      }
      if (this.route.mode === ForumComposerMode.Edit) {
        this.pathStack.pop(createForumComposerPostEditedResult(this.route.threadId, this.route.postId));
      }
    } catch (_error) {
      if (this.isSubmitting && expectedSubmissionSequence === this.submissionSequence) {
        this.failSubmission('读取发表结果失败；请先到论坛核对后再重试。');
      }
    }
  }

  private hasCategoryOption(value: string): boolean {
    return this.categoryOptions.some((option: FourD4yComposerChoice) => option.value === value);
  }

  private getRouteThreadTypeChoices(): FourD4yComposerChoice[] {
    const choices: FourD4yComposerChoice[] = [];
    this.route.forumThreadTypes.forEach((threadType) => {
      if (/^\d+$/.test(threadType.value) && threadType.value !== '0' &&
        threadType.label.length > 0 && threadType.label.length <= 80 &&
        choices.every((choice: FourD4yComposerChoice) => choice.value !== threadType.value)) {
        choices.push({ value: threadType.value, label: threadType.label });
      }
    });
    return choices;
  }

  private hasSelectedCategory(): boolean {
    return this.categoryValue !== '0' && this.hasCategoryOption(this.categoryValue);
  }

  private isCategoryRequired(): boolean {
    // NG also blocks a Buy & Sell topic at send time when typeid remains 0.
    // Keep that forum rule even if a future template change prevents the
    // board menu from being parsed, rather than silently sending uncategorized.
    return this.route.mode === ForumComposerMode.NewThread && this.route.forumId === '6';
  }

  private startPreflightWatchdog(sequence: number): void {
    this.formTimeoutId = setTimeout(() => {
      if (sequence !== this.formSequence || this.isSubmitting) {
        return;
      }
      this.failPreflight('打开 4D4Y 发帖表单超时，请稍后重试。');
      try {
        this.webController.stop();
      } catch (_error) {
        console.warn('Unable to stop a timed out 4D4Y composer preflight.');
      }
    }, this.formTimeoutMillis);
  }

  private startSubmissionWatchdog(sequence: number): void {
    this.clearFormWatchdog();
    this.formTimeoutId = setTimeout(() => {
      if (!this.isSubmitting || sequence !== this.submissionSequence) {
        return;
      }
      this.failSubmission('发表超时，无法确认是否成功；请先到论坛核对后再重试。');
      try {
        this.webController.stop();
      } catch (_error) {
        console.warn('Unable to stop a timed out 4D4Y composer submission.');
      }
    }, this.formTimeoutMillis);
  }

  /**
   * Image upload uses the live detailed composer form.  A reply reaches the
   * same route NG uses after a quick-reply long press; an edit instead stays
   * on its exact post form so that 4D4Y validates the current pid.
   */
  private startImageUploadHashProbe(sequence: number): void {
    if (!this.supportsImageUpload()) {
      return;
    }
    this.clearImageUploadHashProbe();
    this.imageUploadProbeSequence = sequence;
    this.isImageUploadProbeLoading = true;
    this.isImageUploadProbeReadPending = false;
    this.imageUploadProbeReadAttempts = 0;
    this.hasImageUploadProbeLoadStarted = false;
    this.imageUploadProbeUrl = this.getNativeDetailedComposerUrl() +
      '&mobile=no&oh_image_probe=' + sequence;
    this.imageUploadProbeTimeoutId = setTimeout(() => {
      this.handleImageUploadHashProbeResult(sequence, 'load-timeout');
    }, 20000);
    this.loadImageUploadProbeWhenReady();
  }

  private async readImageUploadHashProbe(sequence: number): Promise<void> {
    if (this.imageUploadProbeSequence !== sequence || sequence !== this.formSequence ||
      this.isSubmitting || !this.isImageUploadProbeLoading || this.isImageUploadProbeReadPending ||
      this.imageUploadProbeRetryTimeoutId >= 0) {
      return;
    }
    this.isImageUploadProbeReadPending = true;
    this.imageUploadProbeReadAttempts += 1;
    try {
      const rawStatus: string = await this.imageUploadProbeController.runJavaScript(
        this.getImageUploadHashProbeReadScript()
      );
      const status: string = this.normalizeImageUploadHashProbeStatus(rawStatus);
      this.isImageUploadProbeReadPending = false;
      if (status === 'missing' && this.imageUploadProbeReadAttempts < this.imageUploadProbeReadAttemptLimit &&
        this.imageUploadProbeSequence === sequence && this.isImageUploadProbeLoading) {
        this.imageUploadProbeRetryTimeoutId = setTimeout(() => {
          this.imageUploadProbeRetryTimeoutId = -1;
          this.readImageUploadHashProbe(sequence);
        }, this.imageUploadProbeReadRetryMillis);
        return;
      }
      this.handleImageUploadHashProbeResult(sequence, status);
    } catch (_error) {
      this.isImageUploadProbeReadPending = false;
      this.handleImageUploadHashProbeResult(sequence, 'unavailable');
    }
  }

  private loadImageUploadProbeWhenReady(): void {
    if (!this.isImageUploadProbeControllerAttached || !this.isImageUploadProbeLoading ||
      this.hasImageUploadProbeLoadStarted || this.imageUploadProbeUrl.length === 0) {
      return;
    }
    this.hasImageUploadProbeLoadStarted = true;
    try {
      this.imageUploadProbeController.loadUrl(this.imageUploadProbeUrl);
    } catch (_error) {
      this.handleImageUploadHashProbeResult(this.imageUploadProbeSequence, 'load-start-failed');
    }
  }

  private isCurrentImageUploadProbeRequest(url: string): boolean {
    if (!this.isImageUploadProbeLoading || !this.supportsImageUpload()) {
      return false;
    }
    return url.indexOf('/forum/post.php') >= 0 &&
      url.indexOf('action=' + this.getImageUploadComposerAction()) >= 0 &&
      url.indexOf('fid=' + this.route.forumId) >= 0 && url.indexOf('tid=' + this.route.threadId) >= 0 &&
      url.indexOf('oh_image_probe=' + this.imageUploadProbeSequence) >= 0 &&
      (this.route.mode !== ForumComposerMode.Edit || url.indexOf('pid=' + this.route.postId) >= 0);
  }

  private handleImageUploadHashProbeResult(sequence: number, status: string): void {
    if (this.imageUploadProbeSequence !== sequence || sequence !== this.formSequence ||
      this.isSubmitting) {
      return;
    }
    this.clearImageUploadHashProbe();
    // The native picker/upload path is the only supported upload path in
    // this app. Even if ArkWeb exposes a hash, verify the native request
    // against the same ordinary login instead of opening another Web surface.
    this.isImageUploadAvailable = false;
    if (status === 'available' || status === 'missing') {
      this.startNativeImageUploadContractProbe(sequence);
      return;
    }
    if (status === 'login-required') {
      this.formMessage = '4D4Y 图片上传预检未继承登录状态，已阻止上传。';
      return;
    }
    if (status === 'composer-form-missing') {
      this.formMessage = '4D4Y 图片上传预检未获得当前编辑表单，已阻止上传。';
      return;
    }
    this.formMessage = '4D4Y 表单已校验；暂时无法确认图片上传参数。';
  }

  /**
   * ArkWeb's composer form can be authenticated while omitting the image upload
   * fields. This GET verifies the same ordinary ArkWeb session can open the
   * native upload contract. Neither HTML nor cookie values are retained.
   */
  private startNativeImageUploadContractProbe(sequence: number): void {
    if (sequence !== this.formSequence || this.isSubmitting || this.isNativeImageUploadProbeLoading) {
      return;
    }
    this.nativeImageUploadProbeSequence = sequence;
    this.isNativeImageUploadProbeLoading = true;
    this.formMessage = '正在核对当前登录的图片上传能力…';
    void this.readNativeImageUploadContract(sequence);
  }

  private async readNativeImageUploadContract(sequence: number): Promise<void> {
    let cookieHeader: string = '';
    const request: http.HttpRequest = http.createHttp();
    try {
      if (!/^\d+$/.test(this.viewerUserId)) {
        this.finishNativeImageUploadContractProbe(sequence, 'user-context-missing');
        return;
      }
      cookieHeader = await this.getNativeImageUploadCookieHeader(this.viewerUserId);
      if (sequence !== this.formSequence || !this.isNativeImageUploadProbeLoading ||
        sequence !== this.nativeImageUploadProbeSequence) {
        return;
      }
      if (cookieHeader.length === 0) {
        this.finishNativeImageUploadContractProbe(sequence, 'cookie-missing');
        return;
      }
      const response: http.HttpResponse = await request.request(this.getNativeDetailedComposerUrl(), {
        method: http.RequestMethod.GET,
        header: {
          'Cookie': cookieHeader,
          'User-Agent': this.forumUserAgent,
          'Referer': 'https://www.4d4y.com/forum/viewthread.php?tid=' + this.route.threadId
        },
        connectTimeout: 20000,
        readTimeout: 20000
      });
      const page: string = typeof response.result === 'string' ? response.result : '';
      this.finishNativeImageUploadContractProbe(sequence, this.classifyNativeDetailedComposerPage(page));
    } catch (_error) {
      this.finishNativeImageUploadContractProbe(sequence, 'request-failed');
    } finally {
      cookieHeader = '';
      request.destroy();
    }
  }

  private getNativeDetailedComposerUrl(): string {
    const action: string = this.getImageUploadComposerAction();
    let url: string = 'https://www.4d4y.com/forum/post.php?action=' + action + '&fid=' + this.route.forumId +
      '&tid=' + this.route.threadId;
    if (this.route.mode === ForumComposerMode.Edit) {
      url += '&pid=' + this.route.postId + '&page=1';
    }
    return url;
  }

  private getImageUploadComposerAction(): string {
    return this.route.mode === ForumComposerMode.Edit ? 'edit' : 'reply';
  }

  private async getNativeImageUploadCookieHeader(userId: string): Promise<string> {
    if (!/^\d+$/.test(userId) || !/^\d+$/.test(this.route.forumId)) {
      return '';
    }
    // ArkWeb owns the persistent cookie jar. This copy lives only for one
    // native HTTP request, whose network stack cannot share ArkWeb cookies.
    return await FourD4ySession.getFullSiteCookieHeader(userId, this.route.forumId);
  }

  private classifyNativeDetailedComposerPage(page: string): string {
    if (/input[^>]+name=["'](?:username|password)["']/i.test(page)) {
      return 'login-required';
    }
    const hasHash: boolean = /input[^>]+name=["']hash["']/i.test(page);
    const hasUserId: boolean = /discuz_uid\s*=\s*['"]?\d+/i.test(page);
    return hasHash && hasUserId ? 'available' : 'missing';
  }

  private finishNativeImageUploadContractProbe(sequence: number, status: string): void {
    if (sequence !== this.formSequence || sequence !== this.nativeImageUploadProbeSequence) {
      return;
    }
    this.nativeImageUploadProbeSequence = -1;
    this.isNativeImageUploadProbeLoading = false;
    if (status === 'available') {
      this.isImageUploadAvailable = true;
      this.formMessage = '已确认当前登录具备图片上传能力；可以添加一张图片。';
    } else if (status === 'login-required' || status === 'cookie-missing') {
      this.formMessage = '当前登录未获图片上传权限；请从首页重新登录后再试。';
    } else if (status === 'user-context-missing') {
      this.formMessage = '当前登录未提供用户上下文；请返回主题后重新打开回复。';
    } else {
      this.formMessage = '暂时无法确认详细回复的图片上传能力，已停止上传。';
    }
  }

  private onImageUploadSurfaceControllerAttached(): void {
    this.isImageUploadSurfaceControllerAttached = true;
    this.startImageUploadSurfaceWhenReady();
  }

  private startImageUploadSurfaceWhenReady(): void {
    if (!this.isImageUploadAvailable || !this.isImageUploadSurfaceControllerAttached ||
      this.hasImageUploadSurfaceLoadStarted || this.imageUploadSurfaceUrl.length === 0) {
      return;
    }
    this.isImageUploadSurfaceReady = false;
    this.isImageUploadSurfaceLoading = true;
    this.hasImageUploadSurfaceLoadStarted = true;
    try {
      this.imageUploadController.loadUrl(this.imageUploadSurfaceUrl);
    } catch (_error) {
      this.failImageUploadSurface('图片上传控件无法打开，请稍后重试。');
    }
  }

  private isCurrentImageUploadSurfaceRequest(url: string): boolean {
    if (!this.isImageUploadSurfaceLoading || this.imageUploadSurfaceUrl.length === 0) {
      return false;
    }
    return url.indexOf('/forum/post.php') >= 0 &&
      url.indexOf('action=' + this.getImageUploadComposerAction()) >= 0 &&
      url.indexOf('fid=' + this.route.forumId) >= 0 && url.indexOf('tid=' + this.route.threadId) >= 0 &&
      url.indexOf('oh_image_probe=' + this.imageUploadSurfaceSequence) >= 0 &&
      (this.route.mode !== ForumComposerMode.Edit || url.indexOf('pid=' + this.route.postId) >= 0);
  }

  private async prepareImageUploadSurface(): Promise<void> {
    if (!this.isImageUploadSurfaceLoading || this.isImageUploadSurfaceReady) {
      return;
    }
    try {
      const rawStatus: string = await this.imageUploadController.runJavaScript(
        this.getImageUploadSurfaceScript());
      const status: string = this.normalizeImageUploadHashProbeStatus(rawStatus);
      if (status !== 'ready') {
        this.failImageUploadSurface('4D4Y 图片上传参数已失效，请返回后重新进入回复。');
        return;
      }
      this.isImageUploadSurfaceLoading = false;
      this.isImageUploadSurfaceReady = true;
      this.formMessage = '4D4Y 表单已校验；可添加一张图片。';
    } catch (_error) {
      this.failImageUploadSurface('图片上传控件初始化失败，请稍后重试。');
    }
  }

  private resetImageUploadSurface(): void {
    if (!this.isImageUploadSurfaceReady) {
      return;
    }
    try {
      this.imageUploadController.runJavaScript(this.getImageUploadSurfaceResetScript());
    } catch (_error) {
      console.warn('Unable to reset the 4D4Y image-upload surface.');
    }
  }

  private failImageUploadSurface(message: string): void {
    this.isImageUploadSurfaceLoading = false;
    this.isImageUploadSurfaceReady = false;
    this.imageUploadSurfaceSequence = -1;
    this.formMessage = message;
  }

  private normalizeImageUploadHashProbeStatus(rawStatus: string): string {
    const status: string = rawStatus.trim();
    if (status.length >= 2 && status.startsWith('"') && status.endsWith('"')) {
      return status.substring(1, status.length - 1);
    }
    return status;
  }

  private clearImageUploadHashProbe(): void {
    if (this.imageUploadProbeTimeoutId >= 0) {
      clearTimeout(this.imageUploadProbeTimeoutId);
      this.imageUploadProbeTimeoutId = -1;
    }
    if (this.imageUploadProbeRetryTimeoutId >= 0) {
      clearTimeout(this.imageUploadProbeRetryTimeoutId);
      this.imageUploadProbeRetryTimeoutId = -1;
    }
    this.imageUploadProbeSequence = -1;
    this.isImageUploadProbeLoading = false;
    this.isImageUploadProbeReadPending = false;
    this.imageUploadProbeReadAttempts = 0;
    this.hasImageUploadProbeLoadStarted = false;
    this.imageUploadProbeUrl = '';
  }

  private clearFormWatchdog(): void {
    if (this.formTimeoutId >= 0) {
      clearTimeout(this.formTimeoutId);
      this.formTimeoutId = -1;
    }
  }

  private failPreflight(message: string): void {
    this.clearFormWatchdog();
    this.isPreflightLoading = false;
    this.isFormReady = false;
    this.webOperation = ComposerWebOperation.Preflight;
    this.formMessage = message;
  }

  private failSubmission(message: string): void {
    this.clearFormWatchdog();
    this.isSubmitting = false;
    this.isFormReady = false;
    this.webOperation = ComposerWebOperation.Preflight;
    this.formMessage = message;
  }

  /**
   * A parsed server rejection is different from a network/parse failure: the
   * request has a definite unsuccessful result, so the user may edit the
   * preserved draft and submit again. Reload the form for a fresh one-time
   * token instead of re-enabling the already-submitted document.
   */
  private recoverFromRejectedSubmission(message: string): void {
    this.clearFormWatchdog();
    this.isSubmitting = false;
    this.isFormReady = false;
    this.submissionErrorMessage = message;
    this.prepareForm(ComposerWebOperation.Preflight);
    this.formMessage = '正在重新获取可发送表单；草稿和已添加图片已保留。';
  }

  private getPreflightExtractionScript(sequence: number): string {
    const mode: string = JSON.stringify(this.route.mode);
    const forumId: string = JSON.stringify(this.route.forumId);
    const threadId: string = JSON.stringify(this.route.threadId);
    const postId: string = JSON.stringify(this.route.postId);
    const expectedAction: string = this.route.mode === ForumComposerMode.NewThread ? 'newthread' :
      (this.route.mode === ForumComposerMode.Edit ? 'edit' : 'reply');
    const expectedSubmit: string = this.route.mode === ForumComposerMode.NewThread ? 'topicsubmit' :
      (this.route.mode === ForumComposerMode.Edit ? 'editsubmit' : 'replysubmit');
    return [
      '(() => {',
      '  const toText = (node) => node ? (node.innerText || node.textContent || "").trim() : "";',
      '  const asUrl = (value) => { try { return new URL(value || location.href, location.href); } catch (_) { return new URL(location.href); } };',
      '  const expectedAction = ' + JSON.stringify(expectedAction) + ';',
      '  const expectedSubmit = ' + JSON.stringify(expectedSubmit) + ';',
      '  const loginForm = document.querySelector("form[action*=logging], input[name=username], input[name=password]");',
      '  const challenge = !!document.querySelector("iframe[src*=challenge], #challenge-form, .cf-turnstile, [data-sitekey]");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => {',
      '    const action = asUrl(candidate.getAttribute("action") || location.href);',
      '    return action.pathname.indexOf("post.php") >= 0 && action.searchParams.get("action") === expectedAction;',
      '  }) || forms.find((candidate) => candidate.querySelector("textarea[name=message]") !== null);',
      '  const actionUrl = form ? asUrl(form.getAttribute("action") || location.href) : asUrl(location.href);',
      '  const actionKind = actionUrl.searchParams.get("action") || asUrl(location.href).searchParams.get("action") || "";',
      '  const hasExpectedValue = (name, expected) => { if (!expected) return true; if (actionUrl.searchParams.get(name) === expected) return true; return !!(form && Array.from(form.querySelectorAll("input[name]")).some((input) => (input.getAttribute("name") || "") === name && input.value === expected)); };',
      '  const message = form ? form.querySelector("textarea[name=message]") : null;',
      '  const subject = form ? form.querySelector("input[name=subject]") : null;',
      '  const selects = form ? Array.from(form.querySelectorAll("select[name]")) : [];',
      // Discuz 7.2's new-topic template and server both call the visible topic
      // category select "typeid".  4D4Y's mobile layout can separate that
      // select from its Chinese label, so use the verified field contract
      // before the display-text fallback.  Do not treat arbitrary selects as
      // categories when a forum has no thread types (for example La Femme).
      '  const category = selects.find((node) => { const hint = (node.getAttribute("name") || "") + " " + (node.getAttribute("id") || "") + " " + (node.getAttribute("class") || ""); return /(^|[^a-z])typeid($|[^a-z])/i.test(hint); }) || selects.find((node) => { const scope = node.closest("tr, li, dl, div") || node.parentElement; return /分类/.test(toText(scope)); }) || (selects.length === 1 ? selects[0] : null);',
      '  const inputs = Array.from(document.querySelectorAll("input[name]"));',
      '  const tags = inputs.find((node) => {',
      '    const scope = node.closest("tr, li, dl, div") || node.parentElement;',
      '    const hint = (node.getAttribute("name") || "") + " " + (node.getAttribute("id") || "") + " " + (node.getAttribute("placeholder") || "");',
      '    return /标签/.test(toText(scope)) || /(^|[^a-z])tags?([^a-z]|$)/i.test(hint);',
      '  }) || null;',
      '  const hasSubmitAction = form ? (actionUrl.searchParams.has(expectedSubmit) || !!form.querySelector("input[name=" + expectedSubmit + "], button[name=" + expectedSubmit + "]")) : false;',
      '  const currentUserLink = document.querySelector("#umenu > cite > a[href], #umenu cite a[href]");',
      '  const currentUserHref = currentUserLink ? (currentUserLink.getAttribute("href") || "") : "";',
      '  const currentUserMatch = /(?:[?&]uid=|uid-)([0-9]+)/.exec(currentUserHref);',
      '  const pageScriptText = Array.from(document.scripts || []).map((script) => script.textContent || "").join("\\n");',
      '  const scriptUserMatch = /(?:^|[;\\s])discuz_uid\\s*=\\s*[\"\\\']?([0-9]+)/i.exec(pageScriptText);',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      // 4D4Y keeps unposted images in these server-rendered trays. The
      // selectors are the verified ones used by NG's pre-post inspection.
      '  const unusedImageAttachmentIds = [];',
      '  const addUnusedImageAttachmentId = (value) => { if (/^\\d+$/.test(value) && unusedImageAttachmentIds.indexOf(value) < 0) unusedImageAttachmentIds.push(value); };',
      '  Array.from(document.querySelectorAll("div#unusedimgattachlist table.imglist img")).forEach((image) => { const source = image.getAttribute("src") || ""; const id = image.getAttribute("id") || ""; const matched = /_([0-9]+)$/.exec(id); if (source.indexOf("attachments/") >= 0 && matched) addUnusedImageAttachmentId(matched[1]); });',
      '  Array.from(document.querySelectorAll("div.upfilelist img[id^=\\"image_\\"]")).forEach((image) => { const matched = /^image_([0-9]+)$/.exec(image.getAttribute("id") || ""); if (matched) addUnusedImageAttachmentId(matched[1]); });',
      '  Array.from(document.querySelectorAll("div.upfilelist span a")).forEach((link) => { const onclick = link.getAttribute("onclick") || ""; const matched = /^insertAttachimgTag\\(\\x27([0-9]+)\\x27\\)/.exec(onclick); if (matched) addUnusedImageAttachmentId(matched[1]); });',
      // An edit's own upfilelist is distinct from the account-wide unused
      // tray above.  This is the structural list NG uses to manage images
      // already associated with the post; values are IDs only.
      '  const editImageAttachmentIds = [];',
      '  const addEditImageAttachmentId = (value) => { if (/^\\d+$/.test(value) && editImageAttachmentIds.indexOf(value) < 0) editImageAttachmentIds.push(value); };',
      '  const editImageAttachments = [];',
      '  const toSafePreviewUrl = (value) => { try { const url = asUrl(value); return /^https?:$/.test(url.protocol) ? url.toString() : ""; } catch (_) { return ""; } };',
      '  const addEditImageAttachment = (value, previewUrl) => {',
      '    if (!/^\\d+$/.test(value)) return;',
      '    addEditImageAttachmentId(value);',
      '    const safePreviewUrl = toSafePreviewUrl(previewUrl);',
      '    const existing = editImageAttachments.find((item) => item.attachmentId === value);',
      '    if (!existing) editImageAttachments.push({ attachmentId: value, previewUrl: safePreviewUrl });',
      '    else if (!existing.previewUrl && safePreviewUrl) existing.previewUrl = safePreviewUrl;',
      '  };',
      '  if (expectedAction === "edit") {',
      '    Array.from(document.querySelectorAll("div.upfilelist img[id^=\\"image_\\"]")).forEach((image) => { const matched = /^image_([0-9]+)$/.exec(image.getAttribute("id") || ""); if (matched) addEditImageAttachment(matched[1], image.getAttribute("file") || image.getAttribute("src") || ""); });',
      '    Array.from(document.querySelectorAll("div.upfilelist span a")).forEach((link) => { const onclick = link.getAttribute("onclick") || ""; const matched = /^insertAttachimgTag\\(\\x27([0-9]+)\\x27\\)/.exec(onclick); if (matched) addEditImageAttachment(matched[1], ""); });',
      '  }',
      '  return JSON.stringify({',
      '    mode: ' + mode + ', forumId: ' + forumId + ', threadId: ' + threadId + ', postId: ' + postId + ',',
      '    viewerUserId: currentUserMatch ? currentUserMatch[1] : (scriptUserMatch ? scriptUserMatch[1] : ""),',
      '    loadSequence: ' + sequence + ', layout: form ? (expectedAction + "-form") : "no-composer-form",',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, formMethod: form ? (form.method || "get").toLowerCase() : "",',
      '    actionKind: actionKind, hasSubmitAction: hasSubmitAction,',
      '    hasMatchingPostId: hasExpectedValue("pid", ' + postId + '), hasMatchingThreadId: hasExpectedValue("tid", ' + threadId + '),',
      '    subjectFieldName: subject ? (subject.getAttribute("name") || "") : "",',
      '    messageFieldName: message ? (message.getAttribute("name") || "") : "",',
      '    hasFormhashField: !!(form && form.querySelector("input[name=formhash]")),',
      '    hasPosttimeField: !!(form && form.querySelector("input[name=posttime]")),',
      '    hasWysiwygField: !!(form && form.querySelector("input[name=wysiwyg]")),',
      '    hasImageUploadHash: !!document.querySelector("input[name=hash]"),',
      '    unusedImageAttachmentIds: unusedImageAttachmentIds,',
      '    editImageAttachmentIds: editImageAttachmentIds,',
      '    editImageAttachments: editImageAttachments,',
      '    categoryFieldName: category ? (category.getAttribute("name") || "") : "",',
      '    categoryValue: category ? (category.value || "") : "",',
      '    categoryOptions: category ? Array.from(category.options || []).slice(0, 50).map((option) => ({ value: option.value || "", label: toText(option).slice(0, 80) })).filter((option) => option.label.length > 0) : [],',
      '    tagsFieldName: tags ? (tags.getAttribute("name") || "") : "",',
      '    initialSubject: subject ? (subject.value || toText(subject)) : "",',
      '    initialMessage: message ? (message.value || toText(message)) : "",',
      '    errorMessage: toText(alert).slice(0, 180)',
      '  });',
      '})()'
    ].join('\n');
  }

  private getImageUploadHashProbeReadScript(): string {
    const expectedAction: string = this.getImageUploadComposerAction();
    return [
      '(() => {',
      '  const expectedAction = ' + JSON.stringify(expectedAction) + ';',
      '  const loginForm = !!document.querySelector("input[name=username], input[name=password]");',
      '  if (loginForm) { return "login-required"; }',
      '  const composerForm = Array.from(document.forms || []).some((form) => {',
      '    const action = form.getAttribute("action") || "";',
      '    return action.indexOf("post.php") >= 0 && action.indexOf("action=" + expectedAction) >= 0;',
      '  }) || !!document.querySelector("textarea[name=message]");',
      '  if (!composerForm) { return "composer-form-missing"; }',
      '  const hasHash = !!document.querySelector("input[name=hash]");',
      '  const currentUserLink = document.querySelector("#umenu > cite > a[href], #umenu cite a[href]");',
      '  const href = currentUserLink ? (currentUserLink.getAttribute("href") || "") : "";',
      '  const hasUserId = /(?:[?&]uid=|uid-)[0-9]+/.test(href);',
      '  return hasHash && hasUserId ? "available" : (hasHash ? "uid-missing" : "missing");',
      '})()'
    ].join('\n');
  }

  private getImageUploadSurfaceScript(): string {
    const statusAttribute: string = 'data-hipda-image-upload-status';
    return [
      '(() => {',
      '  const root = document.documentElement;',
      '  const statusAttribute = ' + JSON.stringify(statusAttribute) + ';',
      '  const hashField = document.querySelector("input[name=hash]");',
      '  const currentUserLink = document.querySelector("#umenu > cite > a[href], #umenu cite a[href]");',
      '  const href = currentUserLink ? (currentUserLink.getAttribute("href") || "") : "";',
      '  const uidMatch = href.match(/(?:[?&]uid=|uid-)([0-9]+)/);',
      '  const hash = hashField ? (hashField.value || "") : "";',
      '  if (!hash || !uidMatch || !document.body) { return "contract-missing"; }',
      '  const previous = document.getElementById("hipda-oh-image-upload-surface");',
      '  if (previous) { previous.remove(); }',
      '  const surface = document.createElement("label");',
      '  surface.id = "hipda-oh-image-upload-surface";',
      '  surface.style.cssText = "position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;box-sizing:border-box;border:1px solid #175cd3;border-radius:8px;background:#175cd3;color:#fff;font:500 14px sans-serif;overflow:hidden;";',
      '  const caption = document.createElement("span");',
      '  caption.id = "hipda-oh-image-upload-caption"; caption.textContent = "添加图片";',
      '  const picker = document.createElement("input");',
      '  picker.id = "hipda-oh-image-file-input"; picker.type = "file"; picker.multiple = false;',
      '  picker.accept = "image/jpeg,image/png,image/gif,image/bmp";',
      '  picker.style.cssText = "position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:pointer;";',
      '  picker.addEventListener("change", async () => {',
      '    const file = picker.files && picker.files.length > 0 ? picker.files[0] : null;',
      '    let previousStatus = null; try { previousStatus = JSON.parse(root.getAttribute(statusAttribute) || ""); } catch (_) {}',
      '    const uploadSequence = previousStatus && Number.isInteger(previousStatus.uploadSequence) ? previousStatus.uploadSequence : -1;',
      '    const publish = (phase, attachmentIds, errorCode) => {',
      '      root.setAttribute(statusAttribute, JSON.stringify({ uploadSequence: uploadSequence, phase: phase, attachmentIds: attachmentIds, errorCode: errorCode }));',
      '    };',
      '    if (uploadSequence <= 0) { return; }',
      '    picker.disabled = true; caption.textContent = "正在上传…";',
      '    if (!file) { publish("cancelled", [], ""); return; }',
      '    const lowerName = (file.name || "").toLowerCase();',
      '    const extension = lowerName.indexOf(".") >= 0 ? lowerName.substring(lowerName.lastIndexOf(".") + 1) : "";',
      '    const mimeByExtension = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif", bmp: "image/bmp" };',
      '    const fileType = file.type || mimeByExtension[extension] || "";',
      '    if (!/^(jpg|jpeg|png|gif|bmp)$/.test(extension) || !/^image\/(jpeg|png|gif|bmp)$/.test(fileType)) {',
      '      publish("failed", [], "unsupported-image"); return;',
      '    }',
      '    publish("uploading", [], "");',
      '    try {',
      '      const formData = new FormData();',
      '      formData.append("uid", uidMatch[1]); formData.append("hash", hash);',
      '      formData.append("Filename", file.name); formData.append("filetype", fileType);',
      '      formData.append("Filedata", file, file.name);',
      '      const response = await fetch("https://www.4d4y.com/forum/misc.php?action=swfupload&operation=upload&simple=1&type=image", {',
      '        method: "POST", body: formData, credentials: "same-origin"',
      '      });',
      '      const responseText = await response.text();',
      '      const matched = /^DISCUZUPLOAD\|0\|([0-9]+)\|/.exec(responseText.trim());',
      '      if (response.ok && matched) { publish("succeeded", [matched[1]], ""); }',
      '      else { publish("failed", [], "upload-rejected"); }',
      '    } catch (_) { publish("failed", [], "upload-network-failed"); }',
      '  });',
      '  surface.appendChild(caption); surface.appendChild(picker); document.body.appendChild(surface);',
      '  return "ready";',
      '})()'
    ].join('\n');
  }

  private getImageUploadSelectionScript(sequence: number): string {
    const statusAttribute: string = 'data-hipda-image-upload-status';
    return [
      '(() => {',
      '  document.documentElement.setAttribute(' + JSON.stringify(statusAttribute) +
        ', JSON.stringify({ uploadSequence: ' + sequence + ', phase: "selecting", attachmentIds: [], errorCode: "" }));',
      '  return "ready";',
      '})()'
    ].join('\n');
  }

  private getImageUploadSurfaceResetScript(): string {
    return [
      '(() => {',
      '  const picker = document.getElementById("hipda-oh-image-file-input");',
      '  const caption = document.getElementById("hipda-oh-image-upload-caption");',
      '  if (picker) { picker.disabled = false; picker.value = ""; }',
      '  if (caption) { caption.textContent = "添加图片"; }',
      '  return "ready";',
      '})()'
    ].join('\n');
  }

  private getImageUploadStatusScript(sequence: number): string {
    const statusAttribute: string = 'data-hipda-image-upload-status';
    return [
      '(() => {',
      '  const raw = document.documentElement.getAttribute(' + JSON.stringify(statusAttribute) + ');',
      '  if (raw) { return raw; }',
      '  return JSON.stringify({ uploadSequence: ' + sequence + ', phase: "failed", attachmentIds: [], errorCode: "missing-status" });',
      '})()'
    ].join('\n');
  }

  private getSubmissionScript(subject: string, message: string, categoryValue: string, tags: string,
    uploadedImageAttachmentIds: string[], discardedImageAttachmentIds: string[],
    removedExistingImageAttachmentIds: string[], removedNewImageAttachmentIds: string[]): string {
    const safeSubject: string = JSON.stringify(subject);
    const safeMessage: string = JSON.stringify(message);
    const safeCategoryFieldName: string = JSON.stringify(this.categoryFieldName);
    const safeCategoryValue: string = JSON.stringify(categoryValue);
    const safeTagsFieldName: string = JSON.stringify(this.tagsFieldName);
    const safeTags: string = JSON.stringify(tags);
    const safeUploadedImageAttachmentIds: string = JSON.stringify(uploadedImageAttachmentIds);
    const safeDiscardedImageAttachmentIds: string = JSON.stringify(discardedImageAttachmentIds);
    const safeRemovedExistingImageAttachmentIds: string = JSON.stringify(removedExistingImageAttachmentIds);
    const safeRemovedNewImageAttachmentIds: string = JSON.stringify(removedNewImageAttachmentIds);
    const expectedAction: string = this.route.mode === ForumComposerMode.NewThread ? 'newthread' :
      (this.route.mode === ForumComposerMode.Edit ? 'edit' : 'reply');
    return [
      '(() => {',
      '  const expectedAction = ' + JSON.stringify(expectedAction) + ';',
      '  const uploadedImageAttachmentIds = ' + safeUploadedImageAttachmentIds + ';',
      '  const discardedImageAttachmentIds = ' + safeDiscardedImageAttachmentIds + ';',
      '  const removedExistingImageAttachmentIds = ' + safeRemovedExistingImageAttachmentIds + ';',
      '  const removedNewImageAttachmentIds = ' + safeRemovedNewImageAttachmentIds + ';',
      '  const asUrl = (value) => { try { return new URL(value || location.href, location.href); } catch (_) { return new URL(location.href); } };',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => { const action = asUrl(candidate.getAttribute("action") || location.href); return action.pathname.indexOf("post.php") >= 0 && action.searchParams.get("action") === expectedAction; }) || forms.find((candidate) => candidate.querySelector("textarea[name=message]") !== null);',
      '  const message = form ? form.querySelector("textarea[name=message]") : null;',
      '  if (!form || !message) { throw new Error("composer-form-not-ready"); }',
      '  const actionUrl = asUrl(form.getAttribute("action") || location.href);',
      '  message.value = ' + safeMessage + ';',
      '  const subject = form.querySelector("input[name=subject]");',
      '  if (subject) subject.value = ' + safeSubject + ';',
      '  const category = Array.from(form.querySelectorAll("select[name]")).find((node) => (node.getAttribute("name") || "") === ' + safeCategoryFieldName + ');',
      '  const hasSelectedCategory = /^\\d+$/.test(' + safeCategoryValue + ') && ' + safeCategoryValue + ' !== "0";',
      '  const hasLiveCategoryOption = !!(category && Array.from(category.options || []).some((option) => option.value === ' + safeCategoryValue + '));',
      '  if (hasLiveCategoryOption && category) category.value = ' + safeCategoryValue + ';',
      '  const tags = Array.from(document.querySelectorAll("input[name]")).find((node) => (node.getAttribute("name") || "") === ' + safeTagsFieldName + ');',
      '  if (tags) tags.value = ' + safeTags + ';',
      // Edits retain the live form instead of rebuilding it.  The user has
      // explicitly staged any old-image deletion in the native editor; add
      // only those numeric IDs to the server's established delete field.
      '  if (expectedAction === "edit") {',
      '    const hasExpectedValue = (name, expected) => actionUrl.searchParams.get(name) === expected || Array.from(form.querySelectorAll("input[name]")).some((input) => (input.getAttribute("name") || "") === name && input.value === expected);',
      '    const submit = form.querySelector("input[name=editsubmit], button[name=editsubmit], input[type=submit], button[type=submit]");',
      '    if (!actionUrl || !hasExpectedValue("tid", ' + JSON.stringify(this.route.threadId) + ') || !hasExpectedValue("pid", ' + JSON.stringify(this.route.postId) + ') || !form.querySelector("input[name=formhash]") || !submit) throw new Error("edit-form-contract-changed");',
      '    const appendEditField = (name, value) => { const field = document.createElement("input"); field.type = "hidden"; field.name = name; field.value = value; form.appendChild(field); };',
      '    const ensureEditAttachmentField = (name, attachmentId) => {',
      '      if (!/^\\d+$/.test(attachmentId)) return;',
      '      const existing = Array.from(form.querySelectorAll("input[name]")).find((input) => (input.getAttribute("name") || "") === name && input.value === attachmentId);',
      '      if (existing) { const type = (existing.getAttribute("type") || "").toLowerCase(); if (type === "checkbox" || type === "radio") existing.checked = true; return; }',
      '      appendEditField(name, attachmentId);',
      '    };',
      // New uploads use the same `attachnew[][description]` association
      // contract already used for reply publishing.  Dedupe deletion IDs so
      // a user cannot emit two remove fields for one attachment.
      '    uploadedImageAttachmentIds.forEach((attachmentId) => ensureEditAttachmentField("attachnew[][description]", attachmentId));',
      '    const deletedImageAttachmentIds = [];',
      '    removedExistingImageAttachmentIds.concat(removedNewImageAttachmentIds).forEach((attachmentId) => { if (/^\\d+$/.test(attachmentId) && deletedImageAttachmentIds.indexOf(attachmentId) < 0) deletedImageAttachmentIds.push(attachmentId); });',
      '    deletedImageAttachmentIds.forEach((attachmentId) => ensureEditAttachmentField("attachdel[]", attachmentId));',
      // The legacy 4D4Y editor synchronizes its visual iframe into `message`
      // from the submit button's click handler. `requestSubmit()` would run
      // that handler after the native draft is written, replacing the draft
      // with the iframe's stale content. NG posts the edited payload directly;
      // use the same safe principle here while preserving this live form.
      '    const hasEditSubmitSignal = actionUrl.searchParams.has("editsubmit") || !!form.querySelector("input[type=hidden][name=editsubmit]");',
      '    if (!hasEditSubmitSignal) { const signal = document.createElement("input"); signal.type = "hidden"; signal.name = "editsubmit"; signal.value = "yes"; form.appendChild(signal); }',
      '    form.submit();',
      '    return "submitted";',
      '  }',
      // A refreshed 4D4Y form can carry the account's older unused uploads.
      // Build a clean native form from its fresh security fields rather than
      // requestSubmit() on that original form. This follows NG's useful
      // protocol principle while keeping the Harmony implementation native.
      '  const submitSignal = expectedAction === "newthread" ? "topicsubmit" : "replysubmit";',
      // NG and Discuz's own forms put the submission signal in the URL. Keep
      // the matching body field as well, but do not rely on it alone.
      '  actionUrl.searchParams.set(submitSignal, "yes");',
      '  const outgoing = document.createElement("form");',
      '  outgoing.method = (form.getAttribute("method") || "post").toLowerCase();',
      '  outgoing.action = actionUrl.toString(); outgoing.style.display = "none";',
      '  const appendField = (name, value) => { const field = document.createElement("input"); field.type = "hidden"; field.name = name; field.value = value; outgoing.appendChild(field); };',
      '  const isManagedAttachmentField = (name) => /^(?:attachnew|attachdel)(?:\\[|$)/i.test(name) || /^Filedata$/i.test(name);',
      '  const copiedNames = [];',
      // The selected 4D4Y category can come from the board's thread-type menu
      // even when this form only contains its typeid=0 placeholder. In that
      // case replace, rather than duplicate, the stale FormData value.
      '  Array.from(new FormData(form).entries()).forEach((entry) => { const name = entry[0]; const value = entry[1]; if (isManagedAttachmentField(name) || typeof value !== "string" || (hasSelectedCategory && name === ' + safeCategoryFieldName + ')) return; appendField(name, value); copiedNames.push(name); });',
      '  if (hasSelectedCategory && ' + safeCategoryFieldName + '.length > 0) appendField(' + safeCategoryFieldName + ', ' + safeCategoryValue + ');',
      // 4D4Y's established client contract is `attachnew[][description]`
      // with the uploaded attachment ID as its value.
      '  uploadedImageAttachmentIds.forEach((attachmentId) => { if (/^\\d+$/.test(attachmentId)) appendField("attachnew[][description]", attachmentId); });',
      '  discardedImageAttachmentIds.forEach((attachmentId) => { if (/^\\d+$/.test(attachmentId)) appendField("attachdel[]", attachmentId); });',
      '  const submit = form.querySelector("input[type=submit], button[type=submit], button[name*=submit]");',
      '  const submitName = submit ? (submit.getAttribute("name") || "") : "";',
      '  if (submitName && !actionUrl.searchParams.has(submitName) && copiedNames.indexOf(submitName) < 0) appendField(submitName, submit.value || "yes");',
      '  document.body.appendChild(outgoing); outgoing.submit();',
      '})()'
    ].join('\n');
  }

  private getSubmissionResultScript(submissionSequence: number): string {
    const mode: string = JSON.stringify(this.route.mode);
    const threadId: string = JSON.stringify(this.route.threadId);
    return [
      '(() => {',
      '  const url = new URL(location.href);',
      '  const mode = ' + mode + ';',
      '  const threadId = ' + threadId + ';',
      '  const createdThreadId = url.searchParams.get("tid") || "";',
      '  const loginRequired = !!document.querySelector("input[name=username], input[name=password]");',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      '  const errorMessage = alert ? (alert.innerText || alert.textContent || "").trim().slice(0, 240) : "";',
      '  const isThread = url.pathname.indexOf("viewthread.php") >= 0 || url.pathname.indexOf("redirect.php") >= 0;',
      '  const succeeded = mode === "newThread" ? (isThread && /^\\d+$/.test(createdThreadId)) : (isThread && createdThreadId === threadId);',
      '  return JSON.stringify({ mode: mode, threadId: threadId, submissionSequence: ' + submissionSequence + ', succeeded: succeeded, createdThreadId: mode === "newThread" ? createdThreadId : "", loginRequired: loginRequired, errorMessage: errorMessage });',
      '})()'
    ].join('\n');
  }

}
