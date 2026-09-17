import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yFavoriteMutationStartPayload, FourD4yFavoritePagePayload, FourD4yFavoriteReaderOutcome,
  FourD4yFavoriteThread, getFourD4yFavoriteReaderOutcome,
  isExpectedFourD4yFavoriteMutationStartPayload, isExpectedFourD4yFavoritePagePayload,
  parseFourD4yFavoriteMutationStartPayload, parseFourD4yFavoritePagePayload } from '../../domain/favorite/FourD4yFavoriteContracts';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { FourD4yFavoriteState } from '../../domain/favorite/FourD4yFavoriteState';

/**
 * Server-owned 4D4Y favorites. The page keeps the forum's CSRF token entirely
 * inside its isolated ArkWeb document; ArkTS receives only value-free results.
 */
@Component
export struct FavoritesPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('favoriteState') favoriteState: FourD4yFavoriteState;
  @State favorites: FourD4yFavoriteThread[] = [];
  @State currentPage: number = 1;
  @State lastPage: number = 1;
  @State isLoading: boolean = false;
  @State isRemovingFavorite: boolean = false;
  @State statusMessage: string = '';

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private isWebControllerAttached: boolean = false;
  private favoritePageUrl: string = '';
  private loadSequence: number = 0;
  private requestedPage: number = 1;
  private terminalLoadSequence: number = 0;
  private loadTimeoutId: number = -1;
  private removeOperationSequence: number = 0;
  private removingThreadId: string = '';
  private favoriteRemovalTimeoutId: number = -1;
  private favoriteRemovalRefreshTimeoutId: number = -1;
  private favoriteRemovalRefreshAttempt: number = 0;
  private openedFavoriteMutationListenerId: number = -1;
  private readonly loadTimeoutMillis: number = 30000;

  aboutToAppear(): void {
    this.beginLoad();
  }

  aboutToDisappear(): void {
    this.clearLoadWatchdog();
    this.clearFavoriteRemovalWatchdog();
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
            if (this.isCurrentFavoriteRequest(event.url) && !this.isLoadTerminal()) {
              this.isLoading = true;
              if (!this.isRemovingFavorite) {
                this.statusMessage = '';
              }
              return;
            }
          })
          .onPageEnd((event) => {
            if (this.isCurrentFavoriteRequest(event.url) && !this.isLoadTerminal()) {
              this.readFavoritesFromWeb();
              return;
            }
          })
          .onErrorReceive((event) => {
            const requestUrl = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentFavoriteRequest(requestUrl)) {
              if (this.isRemovingFavorite) {
                this.failFavoriteRemoval(this.removeOperationSequence,
                  '取消收藏后的服务器列表刷新失败，请稍后重试。');
                return;
              }
              this.failFavoriteLoad(this.loadSequence, '暂时无法读取服务器收藏，请检查网络后重试。');
              return;
            }
          })
          .width(1)
          .height(1)
          .opacity(0)

        Column() {
          this.buildFavoriteContent();
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface'))
      }
      .width('100%')
      .height('100%')
    }
    .title('我的收藏')
    .menus(this.buildTitleActions)
  }

  @Builder
  private buildTitleActions() {
    Row({ space: 2 }) {
      Text('关注')
        .fontSize(15)
        .fontColor($r('app.color.brand'))
        .height(42)
        .padding({ left: 10, right: 10 })
        .enabled(!this.isLoading && !this.isRemovingFavorite)
        .onClick(() => {
          this.pathStack.replacePathByName('Attention', null);
        })
      Image($r('app.media.toolbar_refresh'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .opacity(!this.isLoading && !this.isRemovingFavorite ? 1 : 0.35)
        .onClick(() => {
          if (!this.isLoading && !this.isRemovingFavorite) {
            this.beginLoad();
          }
        })
    }
  }

  @Builder
  private buildFavoriteContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在读取服务器收藏…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.statusMessage.length > 0 && this.favorites.length === 0) {
      Column({ space: 12 }) {
        Text(this.statusMessage)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
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
    } else if (this.favorites.length === 0) {
      Column({ space: 10 }) {
        Text('还没有服务器收藏')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_body'))
        Text('在主题详情点“收藏”后，它会出现在这里。')
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
          ForEach(this.favorites, (favorite: FourD4yFavoriteThread) => {
            ListItem() {
              this.buildFavoriteItem(favorite);
            }
          }, (favorite: FourD4yFavoriteThread) => favorite.threadId)
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
  private buildFavoriteItem(favorite: FourD4yFavoriteThread) {
    Column({ space: 5 }) {
      Text(favorite.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_strong'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .onClick(() => {
          this.openFavorite(favorite);
        })

      Row({ space: 10 }) {
        Text(favorite.forumName.length > 0 ? favorite.forumName : '4D4Y')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .layoutWeight(1)
        Text(favorite.replyCount + ' 回复')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Button(this.isRemovingFavorite ? '处理中…' : '取消收藏')
          .type(ButtonType.Normal)
          .fontSize(12)
          .fontColor($r('app.color.danger_text'))
          .backgroundColor(Color.Transparent)
          .height(30)
          .enabled(!this.isRemovingFavorite && !this.isLoading)
          .onClick(() => {
            this.removeFavorite(favorite.threadId);
          })
      }
      .width('100%')

      if (favorite.lastReplyAt.length > 0) {
        Text(favorite.lastReplyAt)
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
        .enabled(!this.isLoading && !this.isRemovingFavorite && this.currentPage > 1)
        .onClick(() => {
          this.loadFavoritePage(this.currentPage - 1);
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
        .enabled(!this.isLoading && !this.isRemovingFavorite && this.currentPage < this.lastPage)
        .onClick(() => {
          this.loadFavoritePage(this.currentPage + 1);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  private async beginLoad(): Promise<void> {
    this.isLoggedIn = await FourD4ySession.isLoggedIn();
    if (!this.isLoggedIn) {
      this.favorites = [];
      this.isLoading = false;
      this.statusMessage = '请先登录 4D4Y 后查看服务器收藏。';
      return;
    }
    this.loadFavoritePage(1);
  }

  private loadFavoritePage(page: number, allowDuringRemoval: boolean = false): void {
    if (!Number.isFinite(page) || page < 1 || (this.isRemovingFavorite && !allowDuringRemoval)) {
      return;
    }
    const requestedPage: number = Math.max(1, Math.floor(page));
    this.loadSequence += 1;
    this.requestedPage = requestedPage;
    this.terminalLoadSequence = 0;
    this.isLoading = true;
    this.statusMessage = '';
    this.favoritePageUrl = FourD4ySession.forumRoot + 'my.php?item=favorites&type=thread&mobile=no&page=' +
      requestedPage + '&oh_favorite_load=' + this.loadSequence;
    this.startLoadWatchdog(this.loadSequence);
    if (!this.isWebControllerAttached) {
      return;
    }
    try {
      this.webController.loadUrl(this.favoritePageUrl);
    } catch (_error) {
      this.failFavoriteLoad(this.loadSequence, '暂时无法打开服务器收藏。');
    }
  }

  private onWebControllerAttached(): void {
    this.isWebControllerAttached = true;
    try {
      this.webController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.favoritePageUrl.indexOf('/forum/my.php') >= 0) {
        this.webController.loadUrl(this.favoritePageUrl);
      }
    } catch (_error) {
      if (this.isLoading) {
        this.failFavoriteLoad(this.loadSequence, '暂时无法初始化服务器收藏会话。');
      }
    }
  }

  private async readFavoritesFromWeb(): Promise<void> {
    const expectedSequence: number = this.loadSequence;
    const expectedPage: number = this.requestedPage;
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getFavoritePageExtractionScript(expectedPage, expectedSequence)
      );
      if (this.isLoadTerminal(expectedSequence) || expectedSequence !== this.loadSequence) {
        return;
      }
      const payload: FourD4yFavoritePagePayload | null = parseFourD4yFavoritePagePayload(rawResult);
      if (payload === null || !isExpectedFourD4yFavoritePagePayload(payload, expectedPage, expectedSequence)) {
        this.failFavoriteLoad(expectedSequence, '4D4Y 收藏页已打开，但页面结构无法确认。');
        return;
      }
      const outcome: FourD4yFavoriteReaderOutcome = getFourD4yFavoriteReaderOutcome(payload);
      if (outcome === FourD4yFavoriteReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.favorites = [];
        this.failFavoriteLoad(expectedSequence, '4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (outcome === FourD4yFavoriteReaderOutcome.VerificationRequired) {
        this.failFavoriteLoad(expectedSequence, '请先完成 4D4Y 安全验证后再读取收藏。');
        return;
      }
      if (outcome === FourD4yFavoriteReaderOutcome.UnsupportedLayout) {
        this.failFavoriteLoad(expectedSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '4D4Y 收藏页结构暂未适配，请刷新或稍后重试。');
        return;
      }
      this.favorites = payload.threads;
      this.favoriteState.observeServerFavorites(payload.threads.map((favorite: FourD4yFavoriteThread) =>
        favorite.threadId));
      this.currentPage = payload.page;
      this.lastPage = Math.max(payload.page, payload.lastPage);
      if (this.isRemovingFavorite && this.removingThreadId.length > 0) {
        const removed: boolean = !payload.threads.some((favorite: FourD4yFavoriteThread) =>
          favorite.threadId === this.removingThreadId);
        if (removed) {
          this.finishFavoriteLoad(expectedSequence);
          this.favoriteState.markNotFavorite(this.removingThreadId);
          this.completeFavoriteRemoval(this.removeOperationSequence);
          return;
        }
        this.finishFavoriteLoad(expectedSequence);
        if (this.favoriteRemovalRefreshAttempt < 3) {
          this.scheduleFavoriteRemovalRefresh(this.removeOperationSequence, 1200);
          return;
        }
        this.failFavoriteRemoval(this.removeOperationSequence,
          '服务器列表仍保留该主题，取消收藏未被确认。');
        return;
      }
      this.finishFavoriteLoad(expectedSequence);
    } catch (_error) {
      if (expectedSequence === this.loadSequence && !this.isLoadTerminal(expectedSequence)) {
        this.failFavoriteLoad(expectedSequence, '暂时无法读取服务器收藏，请检查网络后重试。');
      }
    }
  }

  private async removeFavorite(threadId: string): Promise<void> {
    if (!/^\d+$/.test(threadId) || this.isRemovingFavorite || this.isLoading ||
      !this.favorites.some((favorite: FourD4yFavoriteThread) => favorite.threadId === threadId)) {
      return;
    }
    const operationSequence: number = this.removeOperationSequence + 1;
    this.removeOperationSequence = operationSequence;
    this.removingThreadId = threadId;
    this.isRemovingFavorite = true;
    this.statusMessage = '';
    this.startFavoriteRemovalWatchdog(operationSequence);
    // Native requestSubmit can replace the document before ArkWeb settles the
    // pending runJavaScript promise. Schedule the read-only server-list
    // verification first, so completion never depends on that promise.
    this.scheduleFavoriteRemovalRefresh(operationSequence, 1200);
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getFavoriteRemovalStartScript(threadId, operationSequence)
      );
      if (operationSequence !== this.removeOperationSequence || threadId !== this.removingThreadId) {
        return;
      }
      const payload: FourD4yFavoriteMutationStartPayload | null =
        parseFourD4yFavoriteMutationStartPayload(rawResult);
      if (payload === null || !isExpectedFourD4yFavoriteMutationStartPayload(payload, threadId, operationSequence)) {
        this.failFavoriteRemoval(operationSequence, '取消收藏未得到页面端确认；请刷新收藏列表核对。');
        return;
      }
      if (!payload.started) {
        this.failFavoriteRemoval(operationSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前收藏页未提供可确认的取消收藏表单。');
        return;
      }
    } catch (_error) {
      // A successful native form submission can detach the page before this
      // JavaScript invocation returns. The page callbacks / watchdog own the
      // final outcome instead of treating that interruption as a failure.
      if (operationSequence === this.removeOperationSequence && this.isRemovingFavorite) {
        this.statusMessage = '正在等待服务器确认取消收藏…';
      }
    }
  }

  private startFavoriteRemovalWatchdog(operationSequence: number): void {
    this.clearFavoriteRemovalWatchdog();
    this.favoriteRemovalRefreshAttempt = 0;
    this.favoriteRemovalTimeoutId = setTimeout(() => {
      if (this.isRemovingFavorite && operationSequence === this.removeOperationSequence) {
        this.failFavoriteRemoval(operationSequence,
          '取消收藏请求超时，服务器结果未确认；请刷新收藏列表核对。');
      }
    }, this.loadTimeoutMillis);
  }

  /**
   * ArkWeb does not consistently emit a terminal page callback for this
   * server's native form submit. Reload the server list itself and use the
   * checkbox's disappearance as the authoritative completion signal.
   */
  private scheduleFavoriteRemovalRefresh(operationSequence: number, delayMillis: number): void {
    if (!this.isRemovingFavorite || operationSequence !== this.removeOperationSequence) {
      return;
    }
    if (this.favoriteRemovalRefreshTimeoutId >= 0) {
      clearTimeout(this.favoriteRemovalRefreshTimeoutId);
    }
    this.favoriteRemovalRefreshTimeoutId = setTimeout(() => {
      if (!this.isRemovingFavorite || operationSequence !== this.removeOperationSequence) {
        return;
      }
      this.favoriteRemovalRefreshAttempt += 1;
      this.statusMessage = '正在刷新服务器收藏列表…';
      this.loadFavoritePage(1, true);
    }, delayMillis);
  }

  private failFavoriteRemoval(operationSequence: number, message: string): void {
    if (operationSequence !== this.removeOperationSequence) {
      return;
    }
    this.clearFavoriteRemovalWatchdog();
    this.isRemovingFavorite = false;
    this.removingThreadId = '';
    this.statusMessage = message;
  }

  private completeFavoriteRemoval(operationSequence: number): void {
    if (operationSequence !== this.removeOperationSequence) {
      return;
    }
    this.clearFavoriteRemovalWatchdog();
    this.isRemovingFavorite = false;
    this.removingThreadId = '';
    this.statusMessage = '已取消收藏。';
  }

  private clearFavoriteRemovalWatchdog(): void {
    if (this.favoriteRemovalTimeoutId >= 0) {
      clearTimeout(this.favoriteRemovalTimeoutId);
      this.favoriteRemovalTimeoutId = -1;
    }
    if (this.favoriteRemovalRefreshTimeoutId >= 0) {
      clearTimeout(this.favoriteRemovalRefreshTimeoutId);
      this.favoriteRemovalRefreshTimeoutId = -1;
    }
  }

  private openFavorite(favorite: FourD4yFavoriteThread): void {
    const threadId: string = favorite.threadId;
    this.clearOpenedFavoriteMutationListener();
    const listenerId: number = this.favoriteState.subscribeToThreadMutation(threadId, (isFavorite: boolean) => {
      this.openedFavoriteMutationListenerId = -1;
      if (isFavorite) {
        return;
      }
      // The child detail has confirmed removal against the server list. Drop
      // the stale row immediately, then refresh the page it came from.
      this.favorites = this.favorites.filter((item: FourD4yFavoriteThread) => item.threadId !== threadId);
      this.statusMessage = '正在刷新服务器收藏列表…';
      this.loadFavoritePage(this.currentPage);
    });
    this.openedFavoriteMutationListenerId = listenerId;
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
      favorite.threadId, favorite.title, favorite.replyCount, 1, 0, favorite.forumId, true, this.currentPage
    ));
  }

  private clearOpenedFavoriteMutationListener(): void {
    if (this.openedFavoriteMutationListenerId > 0) {
      this.favoriteState.unsubscribeFromThreadMutation(this.openedFavoriteMutationListenerId);
      this.openedFavoriteMutationListenerId = -1;
    }
  }

  private isCurrentFavoriteRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_favorite_load=' + this.loadSequence + '(?:&|$)');
    const pageToken: RegExp = new RegExp('[?&]page=' + this.requestedPage + '(?:&|$)');
    return url.indexOf('/forum/my.php') >= 0 && url.indexOf('item=favorites') >= 0 &&
      sequenceToken.test(url) && pageToken.test(url);
  }

  private isLoadTerminal(sequence: number = this.loadSequence): boolean {
    return this.terminalLoadSequence === sequence;
  }

  private startLoadWatchdog(sequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (sequence === this.loadSequence && !this.isLoadTerminal(sequence)) {
        this.failFavoriteLoad(sequence, '读取服务器收藏超时，请重试。');
        try {
          this.webController.stop();
        } catch (_error) {
          // The page can finish while this timeout is queued.
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

  private finishFavoriteLoad(sequence: number): void {
    if (sequence !== this.loadSequence) {
      return;
    }
    this.clearLoadWatchdog();
    this.terminalLoadSequence = sequence;
    this.isLoading = false;
  }

  private failFavoriteLoad(sequence: number, message: string): void {
    if (sequence !== this.loadSequence) {
      return;
    }
    this.finishFavoriteLoad(sequence);
    this.statusMessage = message;
  }

  private getFavoritePageExtractionScript(page: number, loadSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => { try { const action = new URL(candidate.getAttribute("action") || location.href, location.href); return action.pathname.indexOf("/forum/my.php") >= 0 && action.searchParams.get("item") === "favorites" && (action.searchParams.get("type") || "thread") === "thread"; } catch (_) { return false; } });',
      '  const seen = new Set();',
      '  const threads = [];',
      '  const rows = Array.from(document.querySelectorAll("table.datatable tbody tr, table.datatable tr"));',
      '  rows.forEach((row) => {',
      '    const threadLink = row.querySelector("a[href*=viewthread], a[href*=thread-]");',
      '    if (!threadLink) return;',
      '    let threadId = "";',
      '    try { const threadUrl = new URL(threadLink.getAttribute("href") || "", location.href); threadId = threadUrl.searchParams.get("tid") || ""; if (!threadId) { const matched = /thread-(\\d+)-/.exec(threadUrl.pathname); threadId = matched ? matched[1] : ""; } } catch (_) { return; }',
      '    if (!/^\\d+$/.test(threadId) || seen.has(threadId)) return;',
      '    const forumCell = row.querySelector("td.forum");',
      '    const forumLink = forumCell ? forumCell.querySelector("a[href]") : null;',
      '    let forumId = "";',
      '    try { const forumUrl = new URL(forumLink ? (forumLink.getAttribute("href") || "") : "", location.href); forumId = forumUrl.searchParams.get("fid") || ""; } catch (_) {}',
      '    const replies = text(row.querySelector("td.nums"));',
      '    const replyMatch = /\\d+/.exec(replies);',
      '    seen.add(threadId);',
      '    threads.push({ threadId: threadId, forumId: /^\\d+$/.test(forumId) ? forumId : "", title: text(threadLink).slice(0, 240), forumName: text(forumCell).slice(0, 80), replyCount: replyMatch ? Number.parseInt(replyMatch[0], 10) : 0, lastReplyAt: text(row.querySelector("td.lastpost")).slice(0, 140) });',
      '  });',
      '  let lastPage = ' + page + ';',
      '  Array.from(document.querySelectorAll("div.pages a, div.pages strong, .pg a, .pg strong")).forEach((node) => { const label = text(node); const value = /^\\d+$/.test(label) ? Number.parseInt(label, 10) : 0; if (value > lastPage) lastPage = value; });',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({',
      '    page: ' + page + ', lastPage: lastPage, loadSequence: ' + loadSequence + ',',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, hasDeletionControl: !!(form && Array.from(form.elements || []).some((node) => (node.getAttribute("name") || "") === "delete[]")),',
      '    errorMessage: text(alert).slice(0, 180), threads: threads',
      '  });',
      '})()'
    ].join('\n');
  }

  private getFavoriteRemovalStartScript(threadId: string, operationSequence: number): string {
    const safeThreadId: string = JSON.stringify(threadId);
    return [
      '(() => {',
      '  const threadId = ' + safeThreadId + ';',
      '  const finish = (started, errorMessage) => JSON.stringify({ threadId: threadId, operationSequence: ' + operationSequence + ', started: started, errorMessage: (errorMessage || "").slice(0, 180) });',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  if (loginForm) return finish(false, "登录状态已失效。");',
      '  const form = Array.from(document.forms || []).find((candidate) => { try { const action = new URL(candidate.getAttribute("action") || location.href, location.href); return action.pathname.indexOf("/forum/my.php") >= 0 && action.searchParams.get("item") === "favorites"; } catch (_) { return false; } });',
      '  const checkbox = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "delete[]" && (node.getAttribute("value") || "") === threadId) : null;',
      '  const formhash = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "formhash") : null;',
      '  const submit = form ? Array.from(form.elements || []).find((node) => (node.getAttribute("name") || "") === "favsubmit") : null;',
      '  if (!form || !checkbox || !formhash || !submit) return finish(false, "当前收藏页未提供可确认的取消收藏表单。");',
      '  if (typeof form.requestSubmit !== "function") return finish(false, "当前页面不支持安全提交收藏表单。");',
      '  try {',
      '    checkbox.checked = true;',
      '    form.requestSubmit(submit);',
      '    return finish(true, "");',
      '  } catch (_) { return finish(false, "取消收藏表单未能在当前页面启动。"); }',
      '})()'
    ].join('\n');
  }

}
