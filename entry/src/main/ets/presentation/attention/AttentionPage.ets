import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { bindFourD4yCollectionCache } from '../common/FourD4yCollectionCacheBinding';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yAttentionMutationStartPayload, FourD4yAttentionPagePayload,
  FourD4yAttentionReaderOutcome, FourD4yAttentionThread, getFourD4yAttentionReaderOutcome,
  isExpectedFourD4yAttentionMutationStartPayload, isExpectedFourD4yAttentionPagePayload,
  parseFourD4yAttentionMutationStartPayload, parseFourD4yAttentionPagePayload } from
  '../../domain/attention/FourD4yAttentionContracts';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FourD4yAttentionState } from '../../domain/attention/FourD4yAttentionState';
import { FourD4yCollectionSnapshotSource } from '../../domain/favorite/FourD4yCollectionCache';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { buildFourD4yCollectionPaginationScript } from '../../domain/favorite/FourD4yCollectionPagination';

/**
 * Native view of the server-owned topic attention list. CSRF values remain
 * within the hidden ArkWeb document; ArkTS receives only parsed list fields.
 */
@Component
export struct AttentionPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('attentionState') attentionState: FourD4yAttentionState;
  @Consume('accountState') accountState: FourD4yAccountState;
  @State attentions: FourD4yAttentionThread[] = [];
  @State currentPage: number = 1;
  @State lastPage: number = 1;
  @State isLoading: boolean = false;
  @State isRemovingAttention: boolean = false;
  @State statusMessage: string = '';

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private isWebControllerAttached: boolean = false;
  private attentionPageUrl: string = '';
  private loadSequence: number = 0;
  private requestedPage: number = 1;
  private terminalLoadSequence: number = 0;
  private loadTimeoutId: number = -1;
  private removeOperationSequence: number = 0;
  private removingThreadId: string = '';
  private removalVerificationPage: number = 1;
  private removalTimeoutId: number = -1;
  private removalRefreshTimeoutId: number = -1;
  private removalRefreshAttempt: number = 0;
  private openedAttentionMutationListenerId: number = -1;
  private readonly loadTimeoutMillis: number = 30000;
  private isPageAlive: boolean = false;
  private requestSessionGeneration: number = 0;
  private readonly collectionSnapshotSource: FourD4yCollectionSnapshotSource = new FourD4yCollectionSnapshotSource();

  aboutToAppear(): void {
    this.isPageAlive = true;
    this.beginLoad();
  }

  aboutToDisappear(): void {
    this.attentionState.cache.releaseSnapshot(this.collectionSnapshotSource);
    this.isPageAlive = false;
    this.loadSequence++;
    this.removeOperationSequence++;
    this.clearLoadWatchdog();
    this.clearRemovalWatchdog();
    this.clearOpenedAttentionMutationListener();
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
            if (this.isCurrentAttentionRequest(event.url) && !this.isLoadTerminal()) {
              this.isLoading = true;
              if (!this.isRemovingAttention) {
                this.statusMessage = '';
              }
            }
          })
          .onPageEnd((event) => {
            if (this.isCurrentAttentionRequest(event.url) && !this.isLoadTerminal()) {
              this.readAttentionsFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (!event.request.isMainFrame() || !this.isCurrentAttentionRequest(requestUrl)) {
              return;
            }
            if (this.isRemovingAttention) {
              this.failRemoval(this.removeOperationSequence, '取消关注后的服务器列表刷新失败，请稍后重试。');
              return;
            }
            this.failLoad(this.loadSequence, '暂时无法读取服务器关注，请检查网络后重试。');
          })
          .width(1)
          .height(1)
          .opacity(0)

        Column() {
          this.buildContent();
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface'))
      }
      .width('100%')
      .height('100%')
    }
    .title('我的关注')
    .menus(this.buildTitleActions)
  }

  @Builder
  private buildTitleActions() {
    Row({ space: 2 }) {
      Text('收藏')
        .fontSize(15)
        .fontColor($r('app.color.brand'))
        .height(42)
        .padding({ left: 10, right: 10 })
        .enabled(!this.isLoading && !this.isRemovingAttention)
        .onClick(() => {
          this.pathStack.replacePathByName('Favorites', null);
        })
      Image($r('app.media.toolbar_refresh'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .opacity(!this.isLoading && !this.isRemovingAttention ? 1 : 0.35)
        .onClick(() => {
          if (!this.isLoading && !this.isRemovingAttention) {
            this.beginLoad();
          }
        })
    }
  }

  @Builder
  private buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(32).height(32)
        Text('正在读取服务器关注…').fontSize(15).fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.statusMessage.length > 0 && this.attentions.length === 0) {
      Column({ space: 12 }) {
        Text(this.statusMessage).fontSize(15).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
        Button(this.isLoggedIn ? '重试' : '去登录')
          .onClick(() => {
            if (this.isLoggedIn) {
              this.beginLoad();
            } else {
              this.pathStack.pushPathByName('Login', null);
            }
          })
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else if (this.attentions.length === 0) {
      Column({ space: 10 }) {
        Text('还没有关注的主题').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_body'))
        Text('在主题详情点“关注”后，它会出现在这里。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
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
            .padding({ left: 20, right: 20, top: 8, bottom: 4 })
        }
        List({ space: 0 }) {
          ForEach(this.attentions, (attention: FourD4yAttentionThread) => {
            ListItem() {
              this.buildAttentionItem(attention);
            }
          }, (attention: FourD4yAttentionThread) => attention.threadId)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
        this.buildPager();
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  private buildAttentionItem(attention: FourD4yAttentionThread) {
    Column({ space: 5 }) {
      Text(attention.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_strong'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .onClick(() => {
          this.openAttention(attention);
        })
      Row({ space: 10 }) {
        Text(attention.forumName.length > 0 ? attention.forumName : '4D4Y')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .layoutWeight(1)
        Button(this.isRemovingAttention ? '处理中…' : '取消关注')
          .type(ButtonType.Normal)
          .fontSize(12)
          .fontColor($r('app.color.danger_text'))
          .backgroundColor(Color.Transparent)
          .height(30)
          .enabled(!this.isRemovingAttention && !this.isLoading)
          .onClick(() => {
            this.removeAttention(attention.threadId);
          })
      }
      .width('100%')
      if (attention.lastReplyAt.length > 0) {
        Text(attention.lastReplyAt)
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 10 })
  }

  @Builder
  private buildPager() {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor(this.currentPage > 1 ? $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(!this.isLoading && !this.isRemovingAttention && this.currentPage > 1)
        .onClick(() => {
          this.loadAttentionPage(this.currentPage - 1);
        })
      Blank()
      Text(this.currentPage + ' / ' + this.lastPage)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_detail'))
        .backgroundColor($r('app.color.fill_subtle'))
        .borderRadius(14)
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
      Blank()
      Text('›')
        .fontSize(30)
        .fontColor(this.currentPage < this.lastPage ? $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(!this.isLoading && !this.isRemovingAttention && this.currentPage < this.lastPage)
        .onClick(() => {
          this.loadAttentionPage(this.currentPage + 1);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  private async beginLoad(): Promise<void> {
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    const loggedIn: boolean = await FourD4ySession.isLoggedIn();
    if (!this.isPageAlive || sessionGeneration !== this.accountState.getSessionGeneration()) {
      return;
    }
    this.isLoggedIn = loggedIn;
    if (!this.isLoggedIn) {
      this.attentions = [];
      this.isLoading = false;
      this.statusMessage = '请先登录 4D4Y 后查看服务器关注。';
      return;
    }
    this.loadAttentionPage(1);
  }

  private loadAttentionPage(page: number, allowDuringRemoval: boolean = false): void {
    if (!this.isPageAlive || !Number.isFinite(page) || page < 1 ||
      (this.isRemovingAttention && !allowDuringRemoval)) {
      return;
    }
    const requestedPage: number = Math.max(1, Math.floor(page));
    this.loadSequence += 1;
    this.requestSessionGeneration = this.accountState.getSessionGeneration();
    this.requestedPage = requestedPage;
    this.terminalLoadSequence = 0;
    this.isLoading = true;
    this.statusMessage = '';
    // NG and MY 4D4Y both use the server's native attention-list route. Do
    // not force a presentation mode here: its layout differs from favorites
    // and the form controls are the stable contract.
    this.attentionPageUrl = FourD4ySession.forumRoot + 'my.php?item=attention&type=thread&page=' +
      requestedPage + '&oh_attention_load=' + this.loadSequence;
    this.startLoadWatchdog(this.loadSequence);
    if (!this.isWebControllerAttached) {
      return;
    }
    try {
      this.webController.loadUrl(this.attentionPageUrl);
    } catch (_error) {
      this.failLoad(this.loadSequence, '暂时无法打开服务器关注。');
    }
  }

  private onWebControllerAttached(): void {
    this.isWebControllerAttached = true;
    try {
      this.webController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.attentionPageUrl.indexOf('/forum/my.php') >= 0) {
        this.webController.loadUrl(this.attentionPageUrl);
      }
    } catch (_error) {
      if (this.isLoading) {
        this.failLoad(this.loadSequence, '暂时无法初始化服务器关注会话。');
      }
    }
  }

  private async readAttentionsFromWeb(): Promise<void> {
    const expectedSequence: number = this.loadSequence;
    const expectedPage: number = this.requestedPage;
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    try {
      await bindFourD4yCollectionCache(this.getUIContext().getHostContext() as common.Context,
        this.webController, this.attentionState.cache, 'attention', () => this.isPageAlive &&
          expectedSequence === this.loadSequence && sessionGeneration === this.accountState.getSessionGeneration());
      if (!this.isPageAlive || expectedSequence !== this.loadSequence ||
        sessionGeneration !== this.accountState.getSessionGeneration()) return;
      const rawResult: string = await this.webController.runJavaScript(
        this.getAttentionPageExtractionScript(expectedPage, expectedSequence)
      );
      if (!this.isPageAlive || this.requestSessionGeneration !== this.accountState.getSessionGeneration() ||
        this.isLoadTerminal(expectedSequence) || expectedSequence !== this.loadSequence) {
        return;
      }
      const payload: FourD4yAttentionPagePayload | null = parseFourD4yAttentionPagePayload(rawResult);
      if (payload === null || !isExpectedFourD4yAttentionPagePayload(payload, expectedPage, expectedSequence)) {
        this.failLoad(expectedSequence, '4D4Y 关注页已打开，但页面结构无法确认。');
        return;
      }
      const outcome: FourD4yAttentionReaderOutcome = getFourD4yAttentionReaderOutcome(payload);
      if (outcome === FourD4yAttentionReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.attentions = [];
        this.failLoad(expectedSequence, '4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (outcome === FourD4yAttentionReaderOutcome.VerificationRequired) {
        this.failLoad(expectedSequence, '请先完成 4D4Y 安全验证后再读取关注。');
        return;
      }
      if (outcome === FourD4yAttentionReaderOutcome.UnsupportedLayout) {
        this.failLoad(expectedSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '4D4Y 关注页结构暂未适配，请刷新或稍后重试。');
        return;
      }
      this.attentions = payload.threads;
      this.attentionState.observeServerAttentions(payload.threads.map((attention: FourD4yAttentionThread) =>
        attention.threadId), payload.page, payload.lastPage, this.collectionSnapshotSource);
      this.currentPage = payload.page;
      this.lastPage = Math.max(payload.page, payload.lastPage);
      if (this.isRemovingAttention && this.removingThreadId.length > 0) {
        const removed: boolean = !payload.threads.some((attention: FourD4yAttentionThread) =>
          attention.threadId === this.removingThreadId);
        this.finishLoad(expectedSequence);
        if (removed) {
          this.attentionState.markNotAttentioned(this.removingThreadId);
          this.attentionState.notifyConfirmedThreadMutation(this.removingThreadId, false);
          this.completeRemoval(this.removeOperationSequence);
          return;
        }
        if (this.removalRefreshAttempt < 3) {
          this.scheduleRemovalRefresh(this.removeOperationSequence, 1200);
          return;
        }
        this.failRemoval(this.removeOperationSequence, '服务器关注列表仍保留该主题，取消关注未被确认。');
        return;
      }
      this.finishLoad(expectedSequence);
    } catch (_error) {
      if (expectedSequence === this.loadSequence && !this.isLoadTerminal(expectedSequence)) {
        this.failLoad(expectedSequence, '暂时无法读取服务器关注，请检查网络后重试。');
      }
    }
  }

  private async removeAttention(threadId: string): Promise<void> {
    const sessionGeneration: number = this.requestSessionGeneration;
    if (!this.isPageAlive || sessionGeneration !== this.accountState.getSessionGeneration() ||
      !/^\d+$/.test(threadId) || this.isRemovingAttention || this.isLoading ||
      !this.attentions.some((attention: FourD4yAttentionThread) => attention.threadId === threadId)) {
      return;
    }
    const operationSequence: number = this.removeOperationSequence + 1;
    this.removeOperationSequence = operationSequence;
    this.removingThreadId = threadId;
    this.removalVerificationPage = this.currentPage;
    this.isRemovingAttention = true;
    this.statusMessage = '';
    this.startRemovalWatchdog(operationSequence);
    this.scheduleRemovalRefresh(operationSequence, 1200);
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getAttentionRemovalStartScript(threadId, operationSequence)
      );
      if (!this.isPageAlive || sessionGeneration !== this.accountState.getSessionGeneration() ||
        operationSequence !== this.removeOperationSequence || threadId !== this.removingThreadId) {
        return;
      }
      const payload: FourD4yAttentionMutationStartPayload | null =
        parseFourD4yAttentionMutationStartPayload(rawResult);
      if (payload === null || !isExpectedFourD4yAttentionMutationStartPayload(payload, threadId, operationSequence)) {
        this.failRemoval(operationSequence, '取消关注未得到页面端确认；请刷新关注列表核对。');
        return;
      }
      if (!payload.started) {
        this.failRemoval(operationSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前关注页未提供可确认的取消关注表单。');
      }
    } catch (_error) {
      // A native form submission can detach ArkWeb before this promise settles.
      // The scheduled server-list verification remains authoritative.
      if (this.isPageAlive && sessionGeneration === this.accountState.getSessionGeneration() &&
        operationSequence === this.removeOperationSequence && this.isRemovingAttention) {
        this.statusMessage = '正在等待服务器确认取消关注…';
      }
    }
  }

  private startRemovalWatchdog(operationSequence: number): void {
    this.clearRemovalWatchdog();
    const sessionGeneration: number = this.requestSessionGeneration;
    this.removalRefreshAttempt = 0;
    this.removalTimeoutId = setTimeout(() => {
      if (this.isPageAlive && sessionGeneration === this.accountState.getSessionGeneration() &&
        this.isRemovingAttention && operationSequence === this.removeOperationSequence) {
        this.failRemoval(operationSequence, '取消关注请求超时，服务器结果未确认；请刷新关注列表核对。');
      }
    }, this.loadTimeoutMillis);
  }

  private scheduleRemovalRefresh(operationSequence: number, delayMillis: number): void {
    const sessionGeneration: number = this.requestSessionGeneration;
    if (!this.isRemovingAttention || operationSequence !== this.removeOperationSequence) {
      return;
    }
    if (this.removalRefreshTimeoutId >= 0) {
      clearTimeout(this.removalRefreshTimeoutId);
    }
    this.removalRefreshTimeoutId = setTimeout(() => {
      if (!this.isPageAlive || sessionGeneration !== this.accountState.getSessionGeneration() ||
        !this.isRemovingAttention || operationSequence !== this.removeOperationSequence) {
        return;
      }
      this.removalRefreshAttempt += 1;
      this.statusMessage = '正在刷新服务器关注列表…';
      this.loadAttentionPage(this.removalVerificationPage, true);
    }, delayMillis);
  }

  private failRemoval(operationSequence: number, message: string): void {
    if (operationSequence !== this.removeOperationSequence) {
      return;
    }
    this.clearRemovalWatchdog();
    this.isRemovingAttention = false;
    this.removingThreadId = '';
    this.statusMessage = message;
  }

  private completeRemoval(operationSequence: number): void {
    if (operationSequence !== this.removeOperationSequence) {
      return;
    }
    this.clearRemovalWatchdog();
    this.isRemovingAttention = false;
    this.removingThreadId = '';
    this.statusMessage = '已取消关注。';
  }

  private clearRemovalWatchdog(): void {
    if (this.removalTimeoutId >= 0) {
      clearTimeout(this.removalTimeoutId);
      this.removalTimeoutId = -1;
    }
    if (this.removalRefreshTimeoutId >= 0) {
      clearTimeout(this.removalRefreshTimeoutId);
      this.removalRefreshTimeoutId = -1;
    }
  }

  private openAttention(attention: FourD4yAttentionThread): void {
    const threadId: string = attention.threadId;
    this.clearOpenedAttentionMutationListener();
    this.openedAttentionMutationListenerId = this.attentionState.subscribeToThreadMutation(threadId,
      (isAttentioned: boolean) => {
        this.openedAttentionMutationListenerId = -1;
        if (isAttentioned) {
          return;
        }
        this.attentions = this.attentions.filter((item: FourD4yAttentionThread) => item.threadId !== threadId);
        this.statusMessage = '正在刷新服务器关注列表…';
        this.loadAttentionPage(this.currentPage);
      });
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
      attention.threadId, attention.title, attention.replyCount, 1, 0, attention.forumId, false, 1, '', true,
      this.currentPage
    ));
  }

  private clearOpenedAttentionMutationListener(): void {
    if (this.openedAttentionMutationListenerId > 0) {
      this.attentionState.unsubscribeFromThreadMutation(this.openedAttentionMutationListenerId);
      this.openedAttentionMutationListenerId = -1;
    }
  }

  private isCurrentAttentionRequest(url: string): boolean {
    if (!this.isPageAlive || this.requestSessionGeneration !== this.accountState.getSessionGeneration()) {
      return false;
    }
    const sequenceToken: RegExp = new RegExp('[?&]oh_attention_load=' + this.loadSequence + '(?:&|$)');
    const pageToken: RegExp = new RegExp('[?&]page=' + this.requestedPage + '(?:&|$)');
    return url.indexOf('/forum/my.php') >= 0 && url.indexOf('item=attention') >= 0 &&
      sequenceToken.test(url) && pageToken.test(url);
  }

  private isLoadTerminal(sequence: number = this.loadSequence): boolean {
    return this.terminalLoadSequence === sequence;
  }

  private startLoadWatchdog(sequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (sequence === this.loadSequence && !this.isLoadTerminal(sequence)) {
        this.failLoad(sequence, '读取服务器关注超时，请重试。');
        try {
          this.webController.stop();
        } catch (_error) {
          // The page can finish while the queued timeout is firing.
        }
      }
    }, this.loadTimeoutMillis);
  }

  private clearLoadWatchdog(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
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
    this.attentionState.cache.releaseSnapshot(this.collectionSnapshotSource);
    this.finishLoad(sequence);
    this.statusMessage = message;
  }

  private getAttentionPageExtractionScript(page: number, loadSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => { try { const action = new URL(candidate.getAttribute("action") || location.href, location.href); return action.pathname.indexOf("/forum/my.php") >= 0 && action.searchParams.get("item") === "attention" && (action.searchParams.get("type") || "thread") === "thread"; } catch (_) { return false; } });',
      '  const seen = new Set(); const threads = []; const links = Array.from(document.querySelectorAll("a[href]"));',
      '  const getThreadId = (link) => { try { const url = new URL(link.getAttribute("href") || "", location.href); let tid = url.searchParams.get("tid") || ""; if (!tid) { const matched = /thread-(\\d+)-/.exec(url.pathname); tid = matched ? matched[1] : ""; } return /^\\d+$/.test(tid) ? tid : ""; } catch (_) { return ""; } };',
      '  const findThreadLink = (tid, scope) => { const candidates = scope ? Array.from(scope.querySelectorAll("a[href]")) : links; return candidates.find((link) => getThreadId(link) === tid) || null; };',
      '  const getContext = (checkbox, tid) => { let node = checkbox.parentElement; for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) { if (findThreadLink(tid, node)) return node; } const link = findThreadLink(tid, null); return link ? (link.closest("tr, li, dl, div") || link.parentElement) : checkbox.parentElement; };',
      '  const deletionInputs = form ? Array.from(form.querySelectorAll("input[name=\\\"delete[]\\\"]")) : [];',
      '  deletionInputs.forEach((checkbox) => {',
      '    const threadId = checkbox.getAttribute("value") || ""; if (!/^\\d+$/.test(threadId) || seen.has(threadId)) return;',
      '    const context = getContext(checkbox, threadId); const threadLink = findThreadLink(threadId, context) || findThreadLink(threadId, null);',
      '    const contextLinks = context ? Array.from(context.querySelectorAll("a[href]")) : []; const forumLink = contextLinks.find((link) => { try { return /^\\d+$/.test(new URL(link.getAttribute("href") || "", location.href).searchParams.get("fid") || ""); } catch (_) { return false; } }) || null;',
      '    const forumCell = context ? context.querySelector("td.forum, .forum") : null;',
      '    const forumName = text(forumCell) || text(forumLink);',
      '    let forumId = ""; try { forumId = new URL(forumLink ? (forumLink.getAttribute("href") || "") : "", location.href).searchParams.get("fid") || ""; } catch (_) {}',
      '    const replies = text(context ? context.querySelector("td.nums, .nums") : null); const replyMatch = /\\d+/.exec(replies); seen.add(threadId);',
      '    threads.push({ threadId: threadId, forumId: /^\\d+$/.test(forumId) ? forumId : "", title: (threadLink ? text(threadLink) : "") || ("帖子 " + threadId), forumName: forumName.slice(0, 80), replyCount: replyMatch ? Number.parseInt(replyMatch[0], 10) : 0, lastReplyAt: text(context ? context.querySelector("td.lastpost, .lastpost") : null).slice(0, 140) });',
      '  });',
      buildFourD4yCollectionPaginationScript('attention', page),
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({ page: ' + page + ', lastPage: lastPage, loadSequence: ' + loadSequence + ', accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge, formFound: !!form, hasDeletionControl: deletionInputs.length > 0, errorMessage: text(alert).slice(0, 180), threads: threads });',
      '})()'
    ].join('\n');
  }

  private getAttentionRemovalStartScript(threadId: string, operationSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + operationSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]"); if (loginForm) return finish(false, "登录状态已失效。");',
      '  const allowedAction = (value) => { try { const action = new URL(value || location.href, location.href); return action.origin === "https://www.4d4y.com" && !action.username && !action.password && action.pathname === "/forum/my.php" && action.searchParams.get("item") === "attention" && (action.searchParams.get("type") || "thread") === "thread"; } catch (_) { return false; } };',
      '  if (!allowedAction(location.href)) return finish(false, "当前页面不是关注列表。");',
      '  const form = Array.from(document.forms || []).find((candidate) => allowedAction(candidate.getAttribute("action")));',
      '  const checkbox = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "delete[]" && (node.getAttribute("value") || "") === threadId) : null;',
      '  const formhash = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "formhash") : null;',
      '  const submit = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "attentionsubmit") : null;',
      '  if (!form || !checkbox || !formhash || !submit) return finish(false, "当前关注页未提供可确认的取消关注表单。");',
      '  const deletionInputs = Array.from(form.elements || []).filter((node) => (node.getAttribute("name") || "") === "delete[]");',
      '  if (checkbox.disabled || deletionInputs.some((node) => node.type !== "checkbox") || !allowedAction(submit.getAttribute("formaction") || form.getAttribute("action"))) return finish(false, "取消关注表单的提交范围无法确认。");',
      '  if (typeof form.requestSubmit !== "function") return finish(false, "当前页面不支持安全提交关注表单。");',
      '  try { deletionInputs.forEach((node) => { node.checked = node === checkbox; }); form.requestSubmit(submit); return finish(true, ""); } catch (_) { return finish(false, "取消关注表单未能在当前页面启动。"); }',
      '})()'
    ].join('\n');
  }
}
