import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4yBlacklistEntry, FourD4yBlacklistMutationKind, FourD4yBlacklistMutationResultPayload,
  FourD4yBlacklistMutationStartPayload,
  FourD4yBlacklistPagePayload, FourD4yBlacklistReaderOutcome, buildFourD4yBlacklistUrl,
  getFourD4yBlacklistReaderOutcome, isCurrentFourD4yBlacklistRequest,
  isExpectedFourD4yBlacklistMutationResultPayload, isExpectedFourD4yBlacklistMutationStartPayload,
  isExpectedFourD4yBlacklistPagePayload,
  isValidFourD4yBlacklistUserName, normalizeFourD4yBlacklistUserName,
  parseFourD4yBlacklistMutationResultPayload, parseFourD4yBlacklistMutationStartPayload,
  parseFourD4yBlacklistPagePayload } from
  '../../domain/blacklist/FourD4yBlacklistContracts';
import { BlacklistRouteParams } from './BlacklistRouteState';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';

/**
 * Native manager for the forum's own PM blacklist. Membership is read from,
 * and mutations are checked against, the live 4D4Y page. The resulting
 * server snapshot also drives the reader's local presentation policy; CSRF
 * values never leave the ArkWeb DOM.
 */
@Component
export struct BlacklistPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('blacklistState') blacklistState: FourD4yBlacklistState;
  @State entries: FourD4yBlacklistEntry[] = [];
  @State draftUserName: string = '';
  @State isLoading: boolean = false;
  @State isMutating: boolean = false;
  @State statusMessage: string = '';
  @State hasMutationToken: boolean = false;
  @State hasRemovalControl: boolean = false;
  /** The existing ArkWeb session is surfaced only for a server challenge. */
  @State needsWebVerification: boolean = false;

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private isWebControllerAttached: boolean = false;
  private blacklistUrl: string = '';
  private loadSequence: number = 0;
  private terminalLoadSequence: number = 0;
  private loadTimeoutId: number = -1;
  private operationSequence: number = 0;
  private mutationKind: FourD4yBlacklistMutationKind = FourD4yBlacklistMutationKind.Add;
  private mutatingUserName: string = '';
  private mutationResponseSequence: number = -1;
  private mutationResponseMessage: string = '';
  private verificationAttempt: number = 0;
  private mutationTimeoutId: number = -1;
  private verificationTimeoutId: number = -1;
  private readonly timeoutMillis: number = 30000;
  private promptForSuggestedUser: boolean = false;

  aboutToDisappear(): void {
    this.loadSequence += 1;
    this.clearLoadWatchdog();
    this.clearMutationWatchdog();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Web({ src: '', controller: this.webController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onWebControllerAttached();
          })
          .onPageBegin((event) => {
            if (this.isCurrentBlacklistRequest(event.url) && !this.isLoadTerminal()) {
              this.isLoading = true;
              if (!this.isMutating) {
                this.statusMessage = '';
              }
            }
          })
          .onPageEnd((event) => {
            if (this.isCurrentBlacklistRequest(event.url) && !this.isLoadTerminal()) {
              this.readBlacklistFromWeb();
            } else if (this.isCurrentMutationResponse(event.url)) {
              this.readMutationResultFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentBlacklistRequest(requestUrl)) {
              if (this.isMutating) {
                this.failMutation(this.operationSequence, '操作后的服务器黑名单刷新失败，请稍后重试。');
              } else {
                this.failLoad(this.loadSequence, '暂时无法读取服务器黑名单，请检查网络后重试。');
              }
            } else if (event.request.isMainFrame() && this.isCurrentMutationResponse(requestUrl)) {
              this.failMutation(this.operationSequence, '黑名单操作页面加载失败，请检查网络后重试。');
            }
          })
          .width('100%')
          .height('100%')

        if (this.needsWebVerification) {
          this.buildVerificationHeader();
        } else {
          Column() {
            this.buildContent();
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.surface'))
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('黑名单')
    .menus(this.buildTitleActions)
    .onReady((context: NavDestinationContext) => {
      this.initializeRoute(context.pathInfo.param as BlacklistRouteParams);
    })
  }

  @Builder
  private buildTitleActions() {
    Image($r('app.media.toolbar_refresh'))
      .width(42)
      .height(42)
      .objectFit(ImageFit.Contain)
      .fillColor($r('app.color.text_detail'))
      .padding(9)
        .opacity(!this.isLoading && !this.isMutating ? 1 : 0.35)
        .onClick(() => {
          if (!this.isLoading && !this.isMutating) {
            this.beginLoad();
          }
        })
  }

  /**
   * A server challenge belongs to the same ArkWeb session that initiated the
   * operation. Showing that single Web component lets the user finish it
   * without copying credentials, cookies, or formhash into ArkTS.
   */
  @Builder
  private buildVerificationHeader() {
    Row({ space: 12 }) {
      Text('请在下方完成 4D4Y 的安全验证')
        .fontSize(14)
        .fontColor($r('app.color.text_body'))
        .layoutWeight(1)
      Button('完成后刷新')
        .fontSize(13)
        .onClick(() => {
          this.needsWebVerification = false;
          this.statusMessage = '';
          this.beginLoad();
        })
      Button('返回黑名单')
        .fontSize(13)
        .onClick(() => {
          this.needsWebVerification = false;
          this.statusMessage = '请完成 4D4Y 安全验证后再操作黑名单。';
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.warning_background'))
  }

  @Builder
  private buildContent() {
    Column({ space: 0 }) {
      this.buildAddControl();
      Divider().color($r('app.color.border_subtle'));
      if (this.isLoading) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32);
          Text(this.isMutating ? '正在等待服务器确认…' : '正在读取服务器黑名单…')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'));
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.statusMessage.length > 0 && this.entries.length === 0) {
        Column({ space: 12 }) {
          Text(this.statusMessage)
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center);
          Button(this.isLoggedIn ? '重试' : '去登录')
            .onClick(() => {
              if (this.isLoggedIn) {
                this.beginLoad();
              } else {
                this.pathStack.pushPathByName('Login', null);
              }
            });
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .padding(28)
        .width('100%')
      } else if (this.entries.length === 0) {
        Column({ space: 10 }) {
          Text('服务器黑名单为空')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_body'));
          Text('加入黑名单后，4D4Y 会按服务器规则处理该用户。')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center);
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .padding(28)
        .width('100%')
      } else {
        Column() {
          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(13)
              .fontColor($r('app.color.success_text'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 });
          }
          List({ space: 0 }) {
            ForEach(this.entries, (entry: FourD4yBlacklistEntry) => {
              ListItem() {
                this.buildEntry(entry);
              }
            }, (entry: FourD4yBlacklistEntry) => entry.userName)
          }
          .layoutWeight(1)
          .width('100%')
          .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 });
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private buildAddControl() {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入用户名', text: this.draftUserName })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor($r('app.color.fill_subtle'))
          .borderRadius(6)
          .onChange((value: string) => {
            this.draftUserName = normalizeFourD4yBlacklistUserName(value);
          });
        Button(this.isMutating && this.mutationKind === FourD4yBlacklistMutationKind.Add ? '处理中…' : '添加')
          .fontSize(14)
          .height(40)
          .enabled(!this.isLoading && !this.isMutating && this.hasMutationToken &&
            isValidFourD4yBlacklistUserName(this.draftUserName))
          .onClick(() => {
            this.requestAdd();
          });
      }
      .width('100%');
      Text(this.hasMutationToken ? '主题阅读按服务器名单隐藏内容；不会创建独立的本地黑名单。' :
        '正在等待 4D4Y 提供可验证的黑名单表单。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%');
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
  }

  @Builder
  private buildEntry(entry: FourD4yBlacklistEntry) {
    Row({ space: 12 }) {
      Text(entry.userName)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);
      Button(this.isMutating && this.mutationKind === FourD4yBlacklistMutationKind.Remove &&
        this.mutatingUserName === entry.userName ? '处理中…' : '移除')
        .type(ButtonType.Normal)
        .fontSize(13)
        .fontColor($r('app.color.danger_text'))
        .backgroundColor(Color.Transparent)
        .height(32)
        .enabled(!this.isLoading && !this.isMutating && this.hasMutationToken && this.hasRemovalControl)
        .onClick(() => {
          this.requestRemoval(entry.userName);
        });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
  }

  private initializeRoute(route: BlacklistRouteParams): void {
    this.entries = [];
    this.draftUserName = route === undefined || route === null ? '' :
      normalizeFourD4yBlacklistUserName(route.suggestedUserName);
    this.promptForSuggestedUser = route !== undefined && route !== null && route.promptForSuggestedUser;
    this.statusMessage = '';
    this.hasMutationToken = false;
    this.hasRemovalControl = false;
    this.needsWebVerification = false;
    this.beginLoad();
  }

  private async beginLoad(): Promise<void> {
    this.isLoggedIn = await FourD4ySession.isLoggedIn();
    if (!this.isLoggedIn) {
      this.entries = [];
      this.blacklistState.clearServerSnapshot();
      this.isLoading = false;
      this.statusMessage = '请先登录 4D4Y 后管理服务器黑名单。';
      return;
    }
    this.loadBlacklist(false);
  }

  private loadBlacklist(allowDuringMutation: boolean): void {
    if (this.isLoading || (this.isMutating && !allowDuringMutation)) {
      return;
    }
    const expectedSequence: number = this.loadSequence + 1;
    const requestUrl: string | null = buildFourD4yBlacklistUrl(expectedSequence);
    this.loadSequence = expectedSequence;
    this.terminalLoadSequence = 0;
    this.blacklistUrl = requestUrl === null ? '' : requestUrl;
    this.isLoading = true;
    if (!this.isMutating) {
      this.statusMessage = '';
    }
    this.startLoadWatchdog(expectedSequence);
    if (requestUrl === null) {
      this.failLoad(expectedSequence, '当前黑名单请求无效。');
      return;
    }
    if (!this.isWebControllerAttached) {
      return;
    }
    try {
      this.webController.loadUrl(requestUrl);
    } catch (_error) {
      this.failLoad(expectedSequence, '暂时无法打开服务器黑名单。');
    }
  }

  private onWebControllerAttached(): void {
    this.isWebControllerAttached = true;
    try {
      this.webController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.blacklistUrl.length > 0 && this.isLoading) {
        this.webController.loadUrl(this.blacklistUrl);
      }
    } catch (_error) {
      if (this.isLoading) {
        this.failLoad(this.loadSequence, '暂时无法初始化服务器黑名单会话。');
      }
    }
  }

  private async readBlacklistFromWeb(): Promise<void> {
    const expectedSequence: number = this.loadSequence;
    if (this.isLoadTerminal(expectedSequence)) {
      return;
    }
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getBlacklistExtractionScript(expectedSequence)
      );
      if (expectedSequence !== this.loadSequence || this.isLoadTerminal(expectedSequence)) {
        return;
      }
      const payload: FourD4yBlacklistPagePayload | null = parseFourD4yBlacklistPagePayload(rawResult);
      if (payload === null || !isExpectedFourD4yBlacklistPagePayload(payload, expectedSequence)) {
        this.failLoad(expectedSequence, '4D4Y 黑名单页已打开，但页面结构无法确认。');
        return;
      }
      const outcome: FourD4yBlacklistReaderOutcome = getFourD4yBlacklistReaderOutcome(payload);
      if (outcome === FourD4yBlacklistReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.entries = [];
        this.blacklistState.clearServerSnapshot();
        this.failLoad(expectedSequence, '4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (outcome === FourD4yBlacklistReaderOutcome.VerificationRequired) {
        this.needsWebVerification = true;
        this.finishLoad(expectedSequence);
        return;
      }
      if (outcome !== FourD4yBlacklistReaderOutcome.Content) {
        this.failLoad(expectedSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '4D4Y 黑名单页结构暂未适配，请刷新或稍后重试。');
        return;
      }
      this.entries = payload.entries;
      this.blacklistState.observeServerUserNames(payload.entries.map((entry: FourD4yBlacklistEntry) =>
        entry.userName));
      this.hasMutationToken = payload.hasMutationToken;
      this.hasRemovalControl = payload.hasRemovalControl;
      if (this.isMutating) {
        const expectedPresent: boolean = this.mutationKind === FourD4yBlacklistMutationKind.Add;
        const present: boolean = this.entries.some((entry: FourD4yBlacklistEntry) =>
          entry.userName === this.mutatingUserName);
        this.finishLoad(expectedSequence);
        if (present === expectedPresent) {
          this.completeMutation(this.operationSequence);
          return;
        }
        if (this.verificationAttempt < 3) {
          this.scheduleVerification(this.operationSequence, 1200);
          return;
        }
        this.failMutation(this.operationSequence, expectedPresent ?
          this.getUnconfirmedMutationMessage('服务器黑名单尚未出现该用户，添加未被确认。') :
          this.getUnconfirmedMutationMessage('服务器黑名单仍保留该用户，移除未被确认。'));
        return;
      }
      this.finishLoad(expectedSequence);
      if (this.promptForSuggestedUser && isValidFourD4yBlacklistUserName(this.draftUserName)) {
        this.promptForSuggestedUser = false;
        if (this.entries.some((entry: FourD4yBlacklistEntry) => entry.userName === this.draftUserName)) {
          this.requestRemoval(this.draftUserName);
        } else {
          this.requestAdd();
        }
      }
    } catch (_error) {
      if (expectedSequence === this.loadSequence && !this.isLoadTerminal(expectedSequence)) {
        this.failLoad(expectedSequence, '暂时无法读取服务器黑名单，请检查网络后重试。');
      }
    }
  }

  private requestAdd(): void {
    const userName: string = normalizeFourD4yBlacklistUserName(this.draftUserName);
    if (!this.canStartMutation(userName) || this.entries.some((entry: FourD4yBlacklistEntry) =>
      entry.userName === userName)) {
      this.statusMessage = this.entries.some((entry: FourD4yBlacklistEntry) => entry.userName === userName) ?
        '该用户已在服务器黑名单中。' : this.statusMessage;
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      message: '将“' + userName + '”加入 4D4Y 服务器黑名单？',
      buttons: [{ text: '取消', color: $r('app.color.text_body') }, { text: '加入黑名单', color: $r('app.color.danger_text') }]
    }).then((result) => {
      if (result.index === 1) {
        this.startMutation(FourD4yBlacklistMutationKind.Add, userName);
      }
    }).catch(() => {});
  }

  private requestRemoval(userName: string): void {
    if (!this.canStartMutation(userName) || !this.entries.some((entry: FourD4yBlacklistEntry) =>
      entry.userName === userName)) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      message: '将“' + userName + '”从 4D4Y 服务器黑名单移除？',
      buttons: [{ text: '取消', color: $r('app.color.text_body') }, { text: '移除', color: $r('app.color.danger_text') }]
    }).then((result) => {
      if (result.index === 1) {
        this.startMutation(FourD4yBlacklistMutationKind.Remove, userName);
      }
    }).catch(() => {});
  }

  private canStartMutation(userName: string): boolean {
    return !this.isLoading && !this.isMutating && this.isLoggedIn && this.hasMutationToken &&
      isValidFourD4yBlacklistUserName(userName);
  }

  private async startMutation(kind: FourD4yBlacklistMutationKind, userName: string): Promise<void> {
    if (!this.canStartMutation(userName) || (kind === FourD4yBlacklistMutationKind.Remove &&
      (!this.hasRemovalControl || !this.entries.some((entry: FourD4yBlacklistEntry) => entry.userName === userName)))) {
      return;
    }
    const operationSequence: number = this.operationSequence + 1;
    this.operationSequence = operationSequence;
    this.mutationKind = kind;
    this.mutatingUserName = userName;
    this.mutationResponseSequence = -1;
    this.mutationResponseMessage = '';
    this.isMutating = true;
    this.statusMessage = kind === FourD4yBlacklistMutationKind.Add ? '正在加入服务器黑名单…' :
      '正在从服务器黑名单移除…';
    this.startMutationWatchdog(operationSequence);
    // A normal server response arrives through onPageEnd. Keep this only as a
    // fallback for WebView navigation that suppresses that callback.
    this.scheduleVerification(operationSequence, 2500);
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getMutationStartScript(kind, userName, operationSequence)
      );
      if (operationSequence !== this.operationSequence || !this.isMutating) {
        return;
      }
      const payload: FourD4yBlacklistMutationStartPayload | null =
        parseFourD4yBlacklistMutationStartPayload(rawResult);
      // ArkWeb can resolve a native form navigation with an empty script
      // result. Keep the operation alive in that case: the fresh server list
      // below is the only success criterion. A nonempty mismatched result is
      // still rejected as a stale or invalid acknowledgement.
      if (payload === null) {
        this.statusMessage = '正在等待服务器确认黑名单操作…';
        return;
      }
      if (!isExpectedFourD4yBlacklistMutationStartPayload(payload, userName,
        operationSequence)) {
        this.failMutation(operationSequence, '黑名单操作未得到有效的页面端确认；请刷新服务器列表核对。');
        return;
      }
      if (!payload.started) {
        this.failMutation(operationSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前黑名单页未提供可确认的操作表单。');
      }
    } catch (_error) {
      // Native form navigation can interrupt the promise. The refreshed list
      // remains the sole success criterion.
      if (operationSequence === this.operationSequence && this.isMutating) {
        this.statusMessage = '正在等待服务器确认黑名单操作…';
      }
    }
  }

  private scheduleVerification(operationSequence: number, delayMillis: number): void {
    if (!this.isMutating || operationSequence !== this.operationSequence) {
      return;
    }
    if (this.verificationTimeoutId >= 0) {
      clearTimeout(this.verificationTimeoutId);
    }
    this.verificationTimeoutId = setTimeout(() => {
      if (!this.isMutating || operationSequence !== this.operationSequence) {
        return;
      }
      this.verificationAttempt += 1;
      this.statusMessage = '正在刷新服务器黑名单…';
      this.loadBlacklist(true);
    }, delayMillis);
  }

  private isCurrentMutationResponse(url: string): boolean {
    if (!this.isMutating || typeof url !== 'string' ||
      url.indexOf('https://www.4d4y.com/forum/pm.php?') !== 0) {
      return false;
    }
    const action: string = this.mutationKind === FourD4yBlacklistMutationKind.Add ? 'addblack' : 'delblack';
    return new RegExp('(?:[?&])action=' + action + '(?:&|$)').test(url);
  }

  private async readMutationResultFromWeb(): Promise<void> {
    const expectedOperationSequence: number = this.operationSequence;
    if (!this.isMutating || this.mutationResponseSequence === expectedOperationSequence) {
      return;
    }
    this.mutationResponseSequence = expectedOperationSequence;
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getMutationResultScript(expectedOperationSequence)
      );
      if (!this.isMutating || expectedOperationSequence !== this.operationSequence) {
        return;
      }
      const payload: FourD4yBlacklistMutationResultPayload | null =
        parseFourD4yBlacklistMutationResultPayload(rawResult);
      if (payload === null || !isExpectedFourD4yBlacklistMutationResultPayload(payload,
        expectedOperationSequence)) {
        this.failMutation(expectedOperationSequence, '黑名单操作结果页面无法确认；请刷新服务器列表核对。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failMutation(expectedOperationSequence, '4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (payload.hasChallenge) {
        this.showSecurityVerification(expectedOperationSequence);
        return;
      }
      if (payload.errorMessage.length > 0) {
        this.failMutation(expectedOperationSequence, payload.errorMessage);
        return;
      }
      this.mutationResponseMessage = payload.message;
      this.statusMessage = payload.message.length > 0 ?
        '论坛返回：' + payload.message + '；正在读取服务器黑名单确认…' :
        '操作响应已返回，正在读取服务器黑名单确认…';
      this.scheduleVerification(expectedOperationSequence, 600);
    } catch (_error) {
      // The fallback read scheduled at mutation start remains available.
      this.mutationResponseSequence = -1;
    }
  }

  private startMutationWatchdog(operationSequence: number): void {
    this.clearMutationWatchdog();
    this.verificationAttempt = 0;
    this.mutationTimeoutId = setTimeout(() => {
      if (this.isMutating && operationSequence === this.operationSequence) {
        this.failMutation(operationSequence, '黑名单操作超时，服务器结果未确认；请刷新列表核对。');
      }
    }, this.timeoutMillis);
  }

  private completeMutation(operationSequence: number): void {
    if (operationSequence !== this.operationSequence) {
      return;
    }
    const userName: string = this.mutatingUserName;
    const kind: FourD4yBlacklistMutationKind = this.mutationKind;
    this.clearMutationWatchdog();
    this.isMutating = false;
    this.mutatingUserName = '';
    this.mutationResponseSequence = -1;
    this.mutationResponseMessage = '';
    if (kind === FourD4yBlacklistMutationKind.Add) {
      this.draftUserName = '';
      this.statusMessage = '已将“' + userName + '”加入服务器黑名单。';
    } else {
      this.statusMessage = '已将“' + userName + '”从服务器黑名单移除。';
    }
  }

  private failMutation(operationSequence: number, message: string): void {
    if (operationSequence !== this.operationSequence) {
      return;
    }
    this.clearMutationWatchdog();
    this.isMutating = false;
    this.mutatingUserName = '';
    this.mutationResponseSequence = -1;
    this.mutationResponseMessage = '';
    this.statusMessage = message;
  }

  private showSecurityVerification(operationSequence: number): void {
    if (operationSequence !== this.operationSequence) {
      return;
    }
    this.clearMutationWatchdog();
    this.isMutating = false;
    this.isLoading = false;
    this.mutatingUserName = '';
    this.mutationResponseSequence = -1;
    this.mutationResponseMessage = '';
    this.statusMessage = '';
    this.needsWebVerification = true;
  }

  private getUnconfirmedMutationMessage(message: string): string {
    return this.mutationResponseMessage.length > 0 ? message + ' 论坛返回：' + this.mutationResponseMessage : message;
  }

  private isCurrentBlacklistRequest(url: string): boolean {
    return isCurrentFourD4yBlacklistRequest(url, this.loadSequence);
  }

  private isLoadTerminal(sequence: number = this.loadSequence): boolean {
    return sequence === this.terminalLoadSequence;
  }

  private startLoadWatchdog(sequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (sequence === this.loadSequence && !this.isLoadTerminal(sequence)) {
        this.failLoad(sequence, '读取服务器黑名单超时，请重试。');
        try {
          this.webController.stop();
        } catch (_error) {
          // The page may finish while the timeout is firing.
        }
      }
    }, this.timeoutMillis);
  }

  private clearLoadWatchdog(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  private clearMutationWatchdog(): void {
    if (this.mutationTimeoutId >= 0) {
      clearTimeout(this.mutationTimeoutId);
      this.mutationTimeoutId = -1;
    }
    if (this.verificationTimeoutId >= 0) {
      clearTimeout(this.verificationTimeoutId);
      this.verificationTimeoutId = -1;
    }
  }

  private finishLoad(sequence: number): void {
    if (sequence !== this.loadSequence) {
      return;
    }
    this.clearLoadWatchdog();
    this.terminalLoadSequence = sequence;
    this.isLoading = false;
  }

  private failLoad(sequence: number, message: string): void {
    if (sequence !== this.loadSequence) {
      return;
    }
    this.finishLoad(sequence);
    this.statusMessage = message;
  }

  private getBlacklistExtractionScript(loadSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const root = document.querySelector("div.blacklist");',
      '  const mutationInput = document.querySelector("input[name=formhash]");',
      '  const menuHasToken = Array.from(document.querySelectorAll("#umenu a[href]")).some((link) => { try { return !!new URL(link.getAttribute("href") || "", location.href).searchParams.get("formhash"); } catch (_) { return false; } });',
      '  const entries = []; const seen = new Set();',
      '  const rows = root ? Array.from(root.querySelectorAll("ul.commonlist li, li")) : [];',
      '  rows.forEach((row) => {',
      '    const profile = row.querySelector("a[href*=\\\"space.php\\\"]");',
      '    const remove = row.querySelector("a.remove[href]");',
      '    const userName = text(profile);',
      '    if (!remove || !userName || userName.length > 160 || /[\\u0000-\\u001F\\u007F]/.test(userName) || seen.has(userName)) return;',
      '    seen.add(userName); entries.push({ userName: userName });',
      '  });',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({ loadSequence: ' + loadSequence + ', accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge, blacklistLayoutFound: !!root, hasMutationToken: !!mutationInput || menuHasToken, hasRemovalControl: entries.length > 0, errorMessage: text(alert).slice(0, 180), entries: entries });',
      '})()'
    ].join('\n');
  }

  private getMutationStartScript(kind: FourD4yBlacklistMutationKind, userName: string,
    operationSequence: number): string {
    const safeUserName: string = JSON.stringify(userName);
    const action: string = kind === FourD4yBlacklistMutationKind.Add ? 'addblack' : 'delblack';
    const method: string = kind === FourD4yBlacklistMutationKind.Add ? 'get' : 'post';
    return [
      '(() => {',
      '  const userName = ' + safeUserName + ';',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const finish = (started, errorMessage) => JSON.stringify({ userName: userName, operationSequence: ' + operationSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]"); if (loginForm) return finish(false, "登录状态已失效。");',
      '  const root = document.querySelector("div.blacklist"); if (!root) return finish(false, "当前页面未提供服务器黑名单列表。");',
      '  const directToken = document.querySelector("input[name=formhash]");',
      '  let formhash = directToken ? (directToken.value || "") : "";',
      '  if (!formhash) { Array.from(document.querySelectorAll("#umenu a[href]")).some((link) => { try { const candidate = new URL(link.getAttribute("href") || "", location.href).searchParams.get("formhash") || ""; if (candidate) { formhash = candidate; return true; } } catch (_) {} return false; }); }',
      '  if (!formhash) return finish(false, "当前黑名单页未提供可确认的安全表单。");',
      '  if (' + JSON.stringify(kind === FourD4yBlacklistMutationKind.Remove) + ') {',
      '    const target = Array.from(root.querySelectorAll("ul.commonlist li, li")).some((row) => { const profile = row.querySelector("a[href*=\\\"space.php\\\"]"); const remove = row.querySelector("a.remove[href]"); return !!remove && text(profile) === userName; });',
      '    if (!target) return finish(false, "该用户不在当前服务器黑名单中。");',
      '  }',
      // A GET form replaces the action URL's query string with its own form
      // fields. Keep addblack as a hidden field; delblack remains POST with
      // the route in its URL, matching the server's rendered remove control.
      '  const actionUrl = new URL(' + JSON.stringify(kind === FourD4yBlacklistMutationKind.Add ? 'pm.php' : 'pm.php?action=delblack') + ', location.href);',
      '  if (actionUrl.origin !== location.origin || actionUrl.pathname !== "/forum/pm.php" || (' + JSON.stringify(kind === FourD4yBlacklistMutationKind.Remove) + ' && actionUrl.searchParams.get("action") !== "delblack")) return finish(false, "当前页面未提供有效的黑名单操作地址。");',
      '  const form = document.createElement("form"); form.method = "' + method + '"; form.action = actionUrl.toString(); form.style.display = "none";',
      '  const append = (name, value) => { const input = document.createElement("input"); input.type = "hidden"; input.name = name; input.value = value; form.appendChild(input); };',
      '  if (' + JSON.stringify(kind === FourD4yBlacklistMutationKind.Add) + ') append("action", "addblack");',
      '  append("formhash", formhash); append("user", userName); document.body.appendChild(form);',
      '  try { form.submit(); return finish(true, ""); } catch (_) { form.remove(); return finish(false, "黑名单表单未能在当前页面启动。"); }',
      '})()'
    ].join('\n');
  }

  private getMutationResultScript(operationSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const messageNode = document.querySelector("#messagetext, .box.message, .messagebox, .showmessage, p.message, .alert_info, .alert_error");',
      '  const explicitError = document.querySelector("div.alert_error, .alert_error, .error_message, #messagetext .alert_error");',
      '  const pageText = text(document.body);',
      '  const knownError = pageText.split(/[。！？]/).find((part) => /(抱歉|错误|无权|非法|失败|不存在|请先登录|登录后)/.test(part)) || "";',
      '  const message = text(messageNode).slice(0, 180);',
      '  return JSON.stringify({ operationSequence: ' + operationSequence + ', accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge, message: message, errorMessage: (text(explicitError) || knownError.trim()).slice(0, 180) });',
      '})()'
    ].join('\n');
  }
}
