import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { FourD4yMessageNativeClient, FourD4yNativePrivateConversationResult } from
  '../../data/remote/FourD4yMessageNativeClient';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yPrivateConversationMessage, FourD4yPrivateConversationPayload,
  FourD4yPrivateConversationReaderOutcome, FourD4yPrivateMessageSegment,
  buildFourD4yPrivateConversationUrl,
  buildFourD4yPrivateMessageCopyText,
  getFourD4yPrivateConversationReaderOutcome,
  isExpectedFourD4yPrivateConversationPayload } from
  '../../domain/notice/FourD4yPrivateConversationContracts';
import { PrivateMessageRouteParams } from './PrivateMessageRouteState';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4yPrivateMessagePreflightPayload, FourD4yPrivateMessageSubmissionPayload,
  buildFourD4yPrivateMessagePreflightUrl, isExpectedFourD4yPrivateMessagePreflight,
  isExpectedFourD4yPrivateMessageSubmission, isReadyFourD4yPrivateMessageForm,
  parseFourD4yPrivateMessagePreflightPayload,
  parseFourD4yPrivateMessageSubmissionPayload } from
  '../../domain/notice/FourD4yPrivateMessageComposerContracts';

enum PrivateMessageWebOperation {
  Preflight = 'preflight',
  Submit = 'submit'
}

/**
 * Native, read-only conversation view. Reading follows the forum's ordinary
 * PM GET flow; no client-side send, delete or clear action exists here.
 */
@Component
export struct PrivateMessageDetailPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @State route: PrivateMessageRouteParams = { participantUserId: '', participantName: '' };
  @State messages: FourD4yPrivateConversationMessage[] = [];
  @State isLoading: boolean = false;
  /** A background confirmation must never replace an already visible conversation with a loading page. */
  @State isRefreshing: boolean = false;
  @State statusMessage: string = '';
  @State privateMessageDraft: string = '';
  @State isPrivateMessageFormLoading: boolean = false;
  @State isPrivateMessageFormReady: boolean = false;
  @State isPrivateMessageSending: boolean = false;
  @State privateMessageFormMessage: string = '';
  @State privateMessageErrorMessage: string = '';
  @State privateMessageCooldownSeconds: number = 0;

  private readonly nativeClient: FourD4yMessageNativeClient = new FourD4yMessageNativeClient();
  private readonly privateMessageWebController: webview.WebviewController = new webview.WebviewController();
  private loadSequence: number = 0;
  private terminalLoadSequence: number = 0;
  private loadTimeoutId: number = -1;
  private readConfirmationTimeoutId: number = -1;
  private hasScheduledReadConfirmation: boolean = false;
  private preservesVisibleContent: boolean = false;
  private privateMessageFormSequence: number = 0;
  private privateMessageSubmissionSequence: number = 0;
  private privateMessageFormTimeoutId: number = -1;
  private privateMessageCooldownTimeoutId: number = -1;
  private privateMessageConversationRefreshTimeoutId: number = -1;
  private isPrivateMessageWebControllerAttached: boolean = false;
  private isPrivateMessageRouteReady: boolean = false;
  private privateMessageWebOperation: PrivateMessageWebOperation = PrivateMessageWebOperation.Preflight;
  private privateMessageFormUrl: string = '';
  private pendingPrivateMessage: string = '';
  private readingPrivateMessageFormSequence: number = -1;
  private readingPrivateMessageSubmissionSequence: number = -1;
  private readonly timeoutMillis: number = 30000;
  private readonly privateMessageCooldownMillis: number = 15000;

  aboutToDisappear(): void {
    this.loadSequence += 1;
    this.isLoading = false;
    this.isRefreshing = false;
    this.preservesVisibleContent = false;
    this.clearLoadWatchdog();
    this.clearReadConfirmation();
    this.clearPrivateMessageFormWatchdog();
    this.clearPrivateMessageCooldown();
    this.clearPrivateMessageConversationRefresh();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // The browser document owns the fresh PM form and all secret fields.
        // It never replaces the native conversation the user is reading.
        Web({ src: '', controller: this.privateMessageWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onPrivateMessageWebControllerAttached();
          })
          .onPageEnd((event) => {
            this.handleCompletedPrivateMessageWebLoad(event.url);
          })
          .onLoadFinished((event) => {
            this.handleCompletedPrivateMessageWebLoad(event.url);
          })
          .onErrorReceive((event) => {
            if (event.request.isMainFrame()) {
              this.handlePrivateMessageWebError(event.request.getRequestUrl());
            }
          })
          .width(1)
          .height(1)
          .opacity(0)
      Column() {
        this.buildToolbar();
        Divider().color($r('app.color.border'));
        this.buildContent();
        Divider().color($r('app.color.border'));
        this.buildPrivateMessageComposer();
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
      }
      .width('100%')
      .height('100%')
    }
    .title(this.route.participantName || '私信')
    .menus(this.buildTitleActions)
    .onReady((context: NavDestinationContext) => {
      const route: PrivateMessageRouteParams = context.pathInfo.param as PrivateMessageRouteParams;
      this.route = route;
      this.hasScheduledReadConfirmation = false;
      this.clearReadConfirmation();
      this.isPrivateMessageRouteReady = true;
      this.loadConversation();
      this.preparePrivateMessageFormWhenReady();
    })
  }

  @Builder
  private buildToolbar() {
    Text('打开未读私信会按论坛规则标记已读')
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
    .width('100%')
    .padding({ left: 16, right: 16, top: 7, bottom: 7 })
    .backgroundColor($r('app.color.surface_subtle'))
  }

  @Builder
  private buildTitleActions() {
    Image($r('app.media.toolbar_refresh'))
      .width(42)
      .height(42)
      .objectFit(ImageFit.Contain)
      .fillColor($r('app.color.text_detail'))
      .padding(9)
      .opacity(!this.isLoading && !this.isRefreshing ? 1 : 0.35)
      .onClick(() => {
        if (!this.isLoading && !this.isRefreshing) {
          this.loadConversation(this.messages.length > 0);
        }
      })
  }

  @Builder
  private buildPrivateMessageComposer() {
    Column({ space: 8 }) {
      if (this.privateMessageErrorMessage.length > 0) {
        Text(this.privateMessageErrorMessage)
          .fontSize(13)
          .fontColor($r('app.color.danger_text'))
          .width('100%')
      } else if (this.privateMessageFormMessage.length > 0 && !this.isPrivateMessageFormReady) {
        Text(this.privateMessageFormMessage)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      Row({ space: 8 }) {
        TextArea({ placeholder: '回复私信', text: this.privateMessageDraft })
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_muted'))
          .backgroundColor($r('app.color.surface_subtle'))
          .border({ width: 1, color: $r('app.color.border_strong'), radius: 8 })
          .height(64)
          .layoutWeight(1)
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .enabled(!this.isPrivateMessageSending)
          .onChange((value: string) => {
            this.privateMessageDraft = value;
            if (this.privateMessageErrorMessage.length > 0) {
              this.privateMessageErrorMessage = '';
            }
          })
        Image($r('app.media.toolbar_send'))
          .width(46)
          .height(46)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.brand'))
          .padding(10)
          .opacity(this.canSubmitPrivateMessage() ? 1 : 0.3)
          .onClick(() => {
            if (this.canSubmitPrivateMessage()) {
              this.submitPrivateMessage();
            }
          })
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      if (this.privateMessageCooldownSeconds > 0) {
        Text('还需等待 ' + this.privateMessageCooldownSeconds + ' 秒')
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 10 })
  }

  @Builder
  private buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在读取私信会话…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.messages.length > 0) {
      Column({ space: 0 }) {
        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 20, right: 20, top: 8, bottom: 4 })
            .width('100%')
        }
        List({ space: 6 }) {
          ForEach(this.messages, (message: FourD4yPrivateConversationMessage) => {
            ListItem() {
              this.buildMessage(message);
            }
          }, (message: FourD4yPrivateConversationMessage) => message.messageId)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      Column({ space: 12 }) {
        Text(this.statusMessage.length > 0 ? this.statusMessage : '暂无与该用户的私信记录')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button(this.isLoggedIn ? '重试' : '去登录')
          .onClick(() => {
            if (this.isLoggedIn) {
              this.loadConversation();
            } else {
              this.pathStack.pushPathByName('Login', null);
            }
          })
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    }
  }

  @Builder
  private buildMessage(message: FourD4yPrivateConversationMessage) {
    Column({ space: 5 }) {
      Row({ space: 8 }) {
        Text(message.isMine ? '我' : message.senderName)
          .fontSize(12)
          .fontColor(message.isMine ? $r('app.color.brand') : $r('app.color.text_detail'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (message.isUnread) {
          Text('未读')
            .fontSize(11)
            .fontColor($r('app.color.danger_text'))
            .backgroundColor($r('app.color.danger_background'))
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        Blank()
        Text(message.occurredAt)
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
      }
      .width('100%')
      this.buildMessageBody(message);
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(message.isMine ? $r('app.color.mine_surface') : $r('app.color.canvas'))
    .borderRadius(8)
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .width('100%')
    .bindContextMenu(this.buildMessageContextMenu(message), ResponseType.LongPress)
  }

  @Builder
  private buildMessageBody(message: FourD4yPrivateConversationMessage) {
    if (message.segments !== undefined && message.segments.length > 0) {
      Text() {
        ForEach(message.segments, (segment: FourD4yPrivateMessageSegment, index: number) => {
          if (segment.kind === 'emoji' && segment.url !== undefined) {
            ImageSpan(segment.url)
              .width(23)
              .height(23)
              .objectFit(ImageFit.Contain)
              .verticalAlign(ImageSpanAlignment.CENTER)
          } else {
            Span(segment.value)
          }
        }, (segment: FourD4yPrivateMessageSegment, index: number) => message.messageId + '-segment-' + index)
      }
      .fontSize(16)
      .fontColor($r('app.color.text_primary'))
      .lineHeight(23)
      .width('100%')
    } else {
      Text(message.body)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(23)
        .width('100%')
    }
  }

  @Builder
  private buildMessageContextMenu(message: FourD4yPrivateConversationMessage) {
    Menu() {
      MenuItem({ content: '复制内容' })
        .enabled(buildFourD4yPrivateMessageCopyText(message).length > 0)
        .onClick(() => {
          void this.copyPrivateMessage(message);
        })
    }
  }

  private async copyPrivateMessage(message: FourD4yPrivateConversationMessage): Promise<void> {
    const content: string = buildFourD4yPrivateMessageCopyText(message);
    if (content.length === 0) {
      this.showPrivateMessageToast('私信内容为空');
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      const property: pasteboard.PasteDataProperty = data.getProperty();
      property.tag = 'HiPDA_OH_PRIVATE_MESSAGE_TEXT';
      data.setProperty(property);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showPrivateMessageToast('内容已复制');
    } catch (_error) {
      this.showPrivateMessageToast('复制内容失败');
    }
  }

  private showPrivateMessageToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      console.warn('Unable to show private-message feedback.');
    }
  }

  private onPrivateMessageWebControllerAttached(): void {
    try {
      this.privateMessageWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      this.isPrivateMessageWebControllerAttached = true;
      this.preparePrivateMessageFormWhenReady();
    } catch (_error) {
      this.failPrivateMessagePreflight('无法初始化 4D4Y 私信表单。');
    }
  }

  private preparePrivateMessageFormWhenReady(): void {
    if (this.isPrivateMessageWebControllerAttached && this.isPrivateMessageRouteReady) {
      this.preparePrivateMessageForm();
    }
  }

  private preparePrivateMessageForm(operation: PrivateMessageWebOperation =
    PrivateMessageWebOperation.Preflight): void {
    const participantUserId: string = this.route.participantUserId;
    if (!/^\d+$/.test(participantUserId)) {
      this.failPrivateMessagePreflight('这条私信缺少可确认的用户标识，不能发送。');
      return;
    }
    const nextSequence: number = this.privateMessageFormSequence + 1;
    const formUrl: string | null = buildFourD4yPrivateMessagePreflightUrl(participantUserId, nextSequence);
    if (formUrl === null) {
      this.failPrivateMessagePreflight('私信发送目标无效，已阻止打开表单。');
      return;
    }
    this.privateMessageFormSequence = nextSequence;
    this.privateMessageWebOperation = operation;
    this.readingPrivateMessageFormSequence = -1;
    this.clearPrivateMessageFormWatchdog();
    this.isPrivateMessageFormLoading = true;
    this.isPrivateMessageFormReady = false;
    this.privateMessageFormUrl = formUrl;
    this.privateMessageFormMessage = operation === PrivateMessageWebOperation.Submit ?
      '正在重新获取一次 4D4Y 私信表单…' : '正在核对 4D4Y 私信表单…';
    this.startPrivateMessageFormWatchdog(nextSequence);
    try {
      this.privateMessageWebController.loadUrl(formUrl);
    } catch (_error) {
      // The first load can race with ArkWeb attachment; its lifecycle callback
      // remains the only place that accepts a form result.
    }
  }

  private isCurrentPrivateMessagePreflightRequest(url: string): boolean {
    return url.indexOf('/forum/pm.php') >= 0 &&
      url.indexOf('oh_pm_compose=' + this.privateMessageFormSequence) >= 0;
  }

  private handleCompletedPrivateMessageWebLoad(url: string): void {
    if (this.isPrivateMessageSending) {
      this.readPrivateMessageSubmissionResult();
      return;
    }
    if (this.isCurrentPrivateMessagePreflightRequest(url)) {
      this.readPrivateMessagePreflightFromWeb();
    }
  }

  private handlePrivateMessageWebError(url: string): void {
    if (this.isPrivateMessageSending) {
      this.failPrivateMessageSubmission('私信发送时网络出错；请先到论坛核对结果后再重试。');
    } else if (this.isCurrentPrivateMessagePreflightRequest(url)) {
      this.failPrivateMessagePreflight('暂时无法打开 4D4Y 私信表单，请检查网络后重试。');
    }
  }

  private async readPrivateMessagePreflightFromWeb(): Promise<void> {
    const expectedSequence: number = this.privateMessageFormSequence;
    const participantUserId: string = this.route.participantUserId;
    if (this.readingPrivateMessageFormSequence === expectedSequence) {
      return;
    }
    this.readingPrivateMessageFormSequence = expectedSequence;
    try {
      const rawResult: string = await this.privateMessageWebController.runJavaScript(
        this.getPrivateMessagePreflightExtractionScript(expectedSequence, participantUserId)
      );
      if (!this.isPrivateMessageFormLoading || expectedSequence !== this.privateMessageFormSequence ||
        this.route.participantUserId !== participantUserId) {
        return;
      }
      const payload: FourD4yPrivateMessagePreflightPayload | null =
        parseFourD4yPrivateMessagePreflightPayload(rawResult);
      if (payload === null || !isExpectedFourD4yPrivateMessagePreflight(payload, participantUserId,
        expectedSequence)) {
        this.failPrivateMessagePreflight('私信表单已打开，但无法确认它属于当前会话。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failPrivateMessagePreflight('4D4Y 登录状态已失效，请重新登录后再发送私信。');
        return;
      }
      if (!isReadyFourD4yPrivateMessageForm(payload, participantUserId)) {
        this.failPrivateMessagePreflight(payload.errorMessage.length > 0 ? payload.errorMessage :
          (payload.hasChallenge ? '请先在登录页完成 4D4Y 安全验证后再发送私信。' :
            '当前 4D4Y 私信表单结构尚未通过校验，未启用发送。'));
        return;
      }
      this.clearPrivateMessageFormWatchdog();
      this.isPrivateMessageFormLoading = false;
      this.isLoggedIn = true;
      if (this.privateMessageWebOperation === PrivateMessageWebOperation.Submit) {
        this.beginPrivateMessageSubmission(expectedSequence, participantUserId);
        return;
      }
      this.isPrivateMessageFormReady = true;
      this.privateMessageFormMessage = '私信表单已校验。';
    } catch (_error) {
      if (this.isPrivateMessageFormLoading && expectedSequence === this.privateMessageFormSequence) {
        this.failPrivateMessagePreflight('读取 4D4Y 私信表单失败，请稍后重试。');
      }
    }
  }

  private submitPrivateMessage(): void {
    if (!this.canSubmitPrivateMessage()) {
      return;
    }
    this.privateMessageErrorMessage = '';
    this.pendingPrivateMessage = this.privateMessageDraft.trim();
    this.privateMessageSubmissionSequence += 1;
    this.isPrivateMessageFormReady = false;
    this.preparePrivateMessageForm(PrivateMessageWebOperation.Submit);
  }

  private canSubmitPrivateMessage(): boolean {
    return this.isLoggedIn && this.isPrivateMessageFormReady && !this.isPrivateMessageFormLoading &&
      !this.isPrivateMessageSending && this.privateMessageCooldownSeconds === 0 &&
      this.privateMessageDraft.trim().length > 0;
  }

  private beginPrivateMessageSubmission(preflightSequence: number, participantUserId: string): void {
    if (this.privateMessageWebOperation !== PrivateMessageWebOperation.Submit ||
      preflightSequence !== this.privateMessageFormSequence || this.pendingPrivateMessage.length === 0) {
      return;
    }
    this.isPrivateMessageSending = true;
    this.privateMessageFormMessage = '正在发送，请勿重复操作…';
    this.startPrivateMessageSubmissionWatchdog(this.privateMessageSubmissionSequence);
    this.submitLoadedPrivateMessageForm(participantUserId);
  }

  private async submitLoadedPrivateMessageForm(participantUserId: string): Promise<void> {
    if (!this.isPrivateMessageSending) {
      return;
    }
    try {
      await this.privateMessageWebController.runJavaScript(
        this.getPrivateMessageSubmissionScript(participantUserId, this.pendingPrivateMessage)
      );
    } catch (_error) {
      // Navigation after HTMLFormElement.submit() can interrupt this promise.
      // A parsed terminal page, rather than this callback, decides success.
    }
  }

  private async readPrivateMessageSubmissionResult(): Promise<void> {
    const expectedSubmissionSequence: number = this.privateMessageSubmissionSequence;
    const participantUserId: string = this.route.participantUserId;
    if (this.readingPrivateMessageSubmissionSequence === expectedSubmissionSequence) {
      return;
    }
    this.readingPrivateMessageSubmissionSequence = expectedSubmissionSequence;
    try {
      const rawResult: string = await this.privateMessageWebController.runJavaScript(
        this.getPrivateMessageSubmissionResultScript(participantUserId, expectedSubmissionSequence)
      );
      if (!this.isPrivateMessageSending || expectedSubmissionSequence !== this.privateMessageSubmissionSequence ||
        this.route.participantUserId !== participantUserId) {
        return;
      }
      const payload: FourD4yPrivateMessageSubmissionPayload | null =
        parseFourD4yPrivateMessageSubmissionPayload(rawResult);
      if (payload === null || !isExpectedFourD4yPrivateMessageSubmission(payload, participantUserId,
        expectedSubmissionSequence)) {
        this.failPrivateMessageSubmission('私信发送结果无法确认；请先到论坛核对后再重试。');
        return;
      }
      if (!payload.succeeded) {
        if (payload.loginRequired) {
          this.isLoggedIn = false;
          this.failPrivateMessageSubmission('4D4Y 登录状态已失效，内容未被当作已发送处理。');
        } else {
          this.recoverFromRejectedPrivateMessage(payload.errorMessage.length > 0 ? payload.errorMessage :
            '4D4Y 未确认私信发送成功，草稿已保留。');
        }
        return;
      }
      this.completePrivateMessageSubmission();
    } catch (_error) {
      if (this.isPrivateMessageSending && expectedSubmissionSequence === this.privateMessageSubmissionSequence) {
        this.failPrivateMessageSubmission('读取私信发送结果失败；请先到论坛核对后再重试。');
      }
    }
  }

  private completePrivateMessageSubmission(): void {
    this.clearPrivateMessageFormWatchdog();
    this.isPrivateMessageSending = false;
    this.isPrivateMessageFormReady = false;
    this.privateMessageWebOperation = PrivateMessageWebOperation.Preflight;
    this.privateMessageDraft = '';
    this.pendingPrivateMessage = '';
    this.privateMessageErrorMessage = '';
    this.privateMessageFormMessage = '私信已发送，正在同步会话。';
    this.startPrivateMessageCooldown();
    this.scheduleConversationRefreshAfterPrivateMessageSend();
  }

  private recoverFromRejectedPrivateMessage(message: string): void {
    this.clearPrivateMessageFormWatchdog();
    this.isPrivateMessageSending = false;
    this.isPrivateMessageFormReady = false;
    this.privateMessageWebOperation = PrivateMessageWebOperation.Preflight;
    this.privateMessageErrorMessage = message;
    this.preparePrivateMessageForm(PrivateMessageWebOperation.Preflight);
  }

  private failPrivateMessagePreflight(message: string): void {
    this.clearPrivateMessageFormWatchdog();
    this.isPrivateMessageFormLoading = false;
    this.isPrivateMessageFormReady = false;
    this.privateMessageWebOperation = PrivateMessageWebOperation.Preflight;
    this.privateMessageFormMessage = message;
  }

  private failPrivateMessageSubmission(message: string): void {
    this.clearPrivateMessageFormWatchdog();
    this.isPrivateMessageSending = false;
    this.isPrivateMessageFormReady = false;
    this.privateMessageWebOperation = PrivateMessageWebOperation.Preflight;
    this.privateMessageErrorMessage = message;
    this.privateMessageFormMessage = '';
  }

  private startPrivateMessageFormWatchdog(sequence: number): void {
    this.clearPrivateMessageFormWatchdog();
    this.privateMessageFormTimeoutId = setTimeout(() => {
      if (this.isPrivateMessageFormLoading && sequence === this.privateMessageFormSequence) {
        this.failPrivateMessagePreflight('打开 4D4Y 私信表单超时，请稍后重试。');
        try {
          this.privateMessageWebController.stop();
        } catch (_error) {
          // The timeout state has already been made safe for the native UI.
        }
      }
    }, this.timeoutMillis);
  }

  private startPrivateMessageSubmissionWatchdog(sequence: number): void {
    this.clearPrivateMessageFormWatchdog();
    this.privateMessageFormTimeoutId = setTimeout(() => {
      if (this.isPrivateMessageSending && sequence === this.privateMessageSubmissionSequence) {
        this.failPrivateMessageSubmission('私信发送超时，无法确认是否成功；请先到论坛核对后再重试。');
        try {
          this.privateMessageWebController.stop();
        } catch (_error) {
          // The uncertain result remains deliberately non-retryable by state.
        }
      }
    }, this.timeoutMillis);
  }

  private clearPrivateMessageFormWatchdog(): void {
    if (this.privateMessageFormTimeoutId >= 0) {
      clearTimeout(this.privateMessageFormTimeoutId);
      this.privateMessageFormTimeoutId = -1;
    }
  }

  private startPrivateMessageCooldown(): void {
    this.clearPrivateMessageCooldown();
    const deadlineMillis: number = Date.now() + this.privateMessageCooldownMillis;
    const tick = () => {
      const remainingMillis: number = Math.max(0, deadlineMillis - Date.now());
      this.privateMessageCooldownSeconds = Math.ceil(remainingMillis / 1000);
      if (remainingMillis <= 0) {
        this.privateMessageCooldownTimeoutId = -1;
        if (this.isPrivateMessageRouteReady && !this.isPrivateMessageSending &&
          !this.isPrivateMessageFormLoading) {
          this.preparePrivateMessageForm(PrivateMessageWebOperation.Preflight);
        }
        return;
      }
      this.privateMessageCooldownTimeoutId = setTimeout(tick, Math.min(1000, remainingMillis));
    };
    tick();
  }

  private clearPrivateMessageCooldown(): void {
    if (this.privateMessageCooldownTimeoutId >= 0) {
      clearTimeout(this.privateMessageCooldownTimeoutId);
      this.privateMessageCooldownTimeoutId = -1;
    }
    this.privateMessageCooldownSeconds = 0;
  }

  private scheduleConversationRefreshAfterPrivateMessageSend(): void {
    this.clearPrivateMessageConversationRefresh();
    const participantUserId: string = this.route.participantUserId;
    this.privateMessageConversationRefreshTimeoutId = setTimeout(() => {
      this.privateMessageConversationRefreshTimeoutId = -1;
      if (this.isPrivateMessageRouteReady && this.route.participantUserId === participantUserId &&
        !this.isRequestPending()) {
        this.loadConversation(true);
      }
    }, 900);
  }

  private clearPrivateMessageConversationRefresh(): void {
    if (this.privateMessageConversationRefreshTimeoutId >= 0) {
      clearTimeout(this.privateMessageConversationRefreshTimeoutId);
      this.privateMessageConversationRefreshTimeoutId = -1;
    }
  }

  private getPrivateMessagePreflightExtractionScript(sequence: number, participantUserId: string): string {
    const safeParticipantUserId: string = JSON.stringify(participantUserId);
    return [
      '(() => {',
      '  const participantUserId = ' + safeParticipantUserId + ';',
      '  const asUrl = (value) => { try { return new URL(value || location.href, location.href); } catch (_) { return new URL(location.href); } };',
      '  const loginForm = !!document.querySelector("form[action*=logging], input[name=username], input[name=password]");',
      '  const challenge = !!document.querySelector("iframe[src*=challenge], #challenge-form, .cf-turnstile, [data-sitekey]");',
      '  const pageUrl = asUrl(location.href);',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => {',
      '    const action = asUrl(candidate.getAttribute("action") || location.href);',
      '    const uid = action.searchParams.get("uid") || pageUrl.searchParams.get("uid") || "";',
      '    const kind = action.searchParams.get("action") || pageUrl.searchParams.get("action") || "";',
      '    return action.origin === "https://www.4d4y.com" && action.pathname === "/forum/pm.php" && kind === "send" && uid === participantUserId;',
      '  }) || forms.find((candidate) => candidate.querySelector("textarea[name=message]") !== null) || null;',
      '  const action = form ? asUrl(form.getAttribute("action") || location.href) : pageUrl;',
      '  const actionParticipantUserId = action.searchParams.get("uid") || pageUrl.searchParams.get("uid") || "";',
      '  const actionKind = action.searchParams.get("action") || pageUrl.searchParams.get("action") || "";',
      '  const message = form ? form.querySelector("textarea[name=message]") : null;',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      '  const text = (node) => node ? (node.innerText || node.textContent || "").trim() : "";',
      '  return JSON.stringify({',
      '    participantUserId: participantUserId, loadSequence: ' + sequence + ',',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, formMethod: form ? (form.method || "get").toLowerCase() : "",',
      '    actionKind: actionKind, actionParticipantUserId: actionParticipantUserId,',
      '    messageFieldName: message ? (message.getAttribute("name") || "") : "",',
      '    hasFormhashField: !!(form && form.querySelector("input[name=formhash]")),',
      '    hasLastDateRangeField: !!(form && form.querySelector("input[name=lastdaterange]")),',
      '    errorMessage: text(alert).slice(0, 180)',
      '  });',
      '})()'
    ].join('\n');
  }

  private getPrivateMessageSubmissionScript(participantUserId: string, message: string): string {
    const safeParticipantUserId: string = JSON.stringify(participantUserId);
    const safeMessage: string = JSON.stringify(message);
    return [
      '(() => {',
      '  const participantUserId = ' + safeParticipantUserId + ';',
      '  const messageValue = ' + safeMessage + ';',
      '  const asUrl = (value) => { try { return new URL(value || location.href, location.href); } catch (_) { return new URL(location.href); } };',
      '  const pageUrl = asUrl(location.href);',
      '  const form = Array.from(document.forms || []).find((candidate) => {',
      '    const action = asUrl(candidate.getAttribute("action") || location.href);',
      '    const uid = action.searchParams.get("uid") || pageUrl.searchParams.get("uid") || "";',
      '    const kind = action.searchParams.get("action") || pageUrl.searchParams.get("action") || "";',
      '    return action.origin === "https://www.4d4y.com" && action.pathname === "/forum/pm.php" && kind === "send" && uid === participantUserId && candidate.querySelector("textarea[name=message]") !== null;',
      '  }) || null;',
      '  const message = form ? form.querySelector("textarea[name=message]") : null;',
      '  const formhash = form ? form.querySelector("input[name=formhash]") : null;',
      '  if (!form || !message || !formhash) throw new Error("pm-form-not-ready");',
      '  const action = asUrl(form.getAttribute("action") || location.href);',
      '  if (action.origin !== "https://www.4d4y.com" || action.pathname !== "/forum/pm.php") throw new Error("pm-action-not-allowed");',
      '  action.searchParams.set("action", "send"); action.searchParams.set("uid", participantUserId);',
      '  form.action = action.toString(); message.value = messageValue;',
      '  const ensure = (name, value) => { let field = form.querySelector("[name=\\\"" + name + "\\\"]"); if (!field) { field = document.createElement("input"); field.type = "hidden"; field.name = name; form.appendChild(field); } field.value = value; };',
      '  if (!form.querySelector("input[name=lastdaterange]")) ensure("lastdaterange", String(Date.now()));',
      '  ensure("handlekey", "pmreply"); ensure("pmsubmit", "yes"); ensure("infloat", "yes"); ensure("inajax", "1");',
      '  form.submit();',
      '})()'
    ].join('\n');
  }

  private getPrivateMessageSubmissionResultScript(participantUserId: string,
    submissionSequence: number): string {
    const safeParticipantUserId: string = JSON.stringify(participantUserId);
    return [
      '(() => {',
      '  const loginRequired = !!document.querySelector("form[action*=logging], input[name=username], input[name=password]");',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext");',
      '  const text = (node) => node ? (node.innerText || node.textContent || "").trim() : "";',
      '  const html = document.documentElement ? (document.documentElement.innerHTML || "") : "";',
      '  const succeeded = !loginRequired && (!!document.querySelector(".summary") || /class=["\\\']summary["\\\']/.test(html));',
      '  return JSON.stringify({ participantUserId: ' + safeParticipantUserId + ', submissionSequence: ' +
        submissionSequence + ', succeeded: succeeded, loginRequired: loginRequired, errorMessage: text(alert).slice(0, 240) });',
      '})()'
    ].join('\n');
  }

  private async loadConversation(keepVisible: boolean = false): Promise<void> {
    if (this.isLoading || this.isRefreshing) {
      return;
    }
    const participantUserId: string = this.route.participantUserId;
    const requestUrl: string | null = buildFourD4yPrivateConversationUrl(participantUserId);
    if (requestUrl === null) {
      this.statusMessage = '这条私信缺少可确认的用户标识。';
      return;
    }
    const expectedLoadSequence: number = this.loadSequence + 1;
    this.loadSequence = expectedLoadSequence;
    this.terminalLoadSequence = 0;
    this.preservesVisibleContent = keepVisible && this.messages.length > 0;
    this.isLoading = !this.preservesVisibleContent;
    this.isRefreshing = this.preservesVisibleContent;
    if (!this.preservesVisibleContent) {
      this.statusMessage = '';
    }
    this.startLoadWatchdog(expectedLoadSequence);
    try {
      const result: FourD4yNativePrivateConversationResult = await this.nativeClient.loadPrivateConversation(
        requestUrl, expectedLoadSequence);
      if (!this.isRequestPending() || this.loadSequence !== expectedLoadSequence ||
        this.terminalLoadSequence === expectedLoadSequence || this.route.participantUserId !== participantUserId) {
        return;
      }
      if (result.status === 'cookie-missing') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '请先登录 4D4Y 后查看私信。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failLoad(expectedLoadSequence, '暂时无法读取私信会话，请检查网络后重试。');
        return;
      }
      const payload: FourD4yPrivateConversationPayload | null = result.payload;
      if (result.status === 'unsupported-response' || payload === null ||
        !isExpectedFourD4yPrivateConversationPayload(payload, participantUserId, expectedLoadSequence)) {
        this.failLoad(expectedLoadSequence, '4D4Y 私信页已返回，但页面结构暂未适配。');
        return;
      }
      const outcome: FourD4yPrivateConversationReaderOutcome = getFourD4yPrivateConversationReaderOutcome(payload);
      if (outcome === FourD4yPrivateConversationReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (outcome === FourD4yPrivateConversationReaderOutcome.VerificationRequired) {
        this.failLoad(expectedLoadSequence, '请先在登录页完成 4D4Y 安全验证后再查看私信。');
        return;
      }
      if (outcome === FourD4yPrivateConversationReaderOutcome.UnsupportedLayout) {
        this.failLoad(expectedLoadSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前 4D4Y 私信会话结构暂未适配。');
        return;
      }
      this.clearLoadWatchdog();
      this.terminalLoadSequence = expectedLoadSequence;
      this.isLoading = false;
      this.isRefreshing = false;
      this.preservesVisibleContent = false;
      this.isLoggedIn = true;
      this.messages = payload.messages;
      this.statusMessage = outcome === FourD4yPrivateConversationReaderOutcome.Empty ? '暂无与该用户的私信记录。' : '';
      this.scheduleReadConfirmationIfNeeded(payload, participantUserId);
    } catch (_error) {
      if (this.isRequestPending() && this.loadSequence === expectedLoadSequence) {
        this.failLoad(expectedLoadSequence, '暂时无法读取私信会话，请稍后重试。');
      }
    }
  }

  private startLoadWatchdog(loadSequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (this.isRequestPending() && this.loadSequence === loadSequence) {
        this.failLoad(loadSequence, '读取私信会话超时，请重试。');
      }
    }, this.timeoutMillis);
  }

  private clearLoadWatchdog(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  private isRequestPending(): boolean {
    return this.isLoading || this.isRefreshing;
  }

  /**
   * Discuz returns the conversation that caused its own GET-side read mark.
   * The first body can therefore still contain newpm.gif. Re-read once after
   * it settles, rather than requiring a manual refresh or polling forever.
   */
  private scheduleReadConfirmationIfNeeded(payload: FourD4yPrivateConversationPayload,
    participantUserId: string): void {
    if (this.hasScheduledReadConfirmation || !payload.messages.some(
      (message: FourD4yPrivateConversationMessage) => message.isUnread)) {
      return;
    }
    this.hasScheduledReadConfirmation = true;
    this.clearReadConfirmation();
    this.readConfirmationTimeoutId = setTimeout(() => {
      this.readConfirmationTimeoutId = -1;
      if (!this.isRequestPending() && this.route.participantUserId === participantUserId) {
        this.loadConversation(true);
      }
    }, 700);
  }

  private clearReadConfirmation(): void {
    if (this.readConfirmationTimeoutId >= 0) {
      clearTimeout(this.readConfirmationTimeoutId);
      this.readConfirmationTimeoutId = -1;
    }
  }

  private failLoad(loadSequence: number, message: string): void {
    if (this.loadSequence !== loadSequence) {
      return;
    }
    this.clearLoadWatchdog();
    this.terminalLoadSequence = loadSequence;
    const preservesVisibleContent: boolean = this.preservesVisibleContent;
    this.isLoading = false;
    this.isRefreshing = false;
    this.preservesVisibleContent = false;
    if (!preservesVisibleContent) {
      this.messages = [];
      this.statusMessage = message;
    }
  }
}
