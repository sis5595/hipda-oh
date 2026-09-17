import { FourD4yMyContentNativeClient, FourD4yNativeMyContentResult } from
  '../../data/remote/FourD4yMyContentNativeClient';
import { FourD4ySearchPostNativeResolver, FourD4ySearchPostResolveResult } from
  '../../data/remote/FourD4ySearchPostNativeResolver';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yMyContentItem, FourD4yMyContentMode, FourD4yMyContentPagePayload,
  FourD4yMyContentReaderOutcome, buildFourD4yMyContentUrl, getFourD4yMyContentReaderOutcome,
  isExpectedFourD4yMyContentPagePayload } from '../../domain/mine/FourD4yMyContentContracts';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { MyContentRouteParams, readMyContentRouteMode } from './MyContentRouteState';

/** Native, read-only UI for the account lists owned by 4D4Y. */
@Component
export struct MyContentPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @State selectedMode: FourD4yMyContentMode = FourD4yMyContentMode.Threads;
  @State items: FourD4yMyContentItem[] = [];
  @State currentPage: number = 1;
  @State lastPage: number = 1;
  @State isLoading: boolean = false;
  @State isResolvingPost: boolean = false;
  @State statusMessage: string = '';

  private readonly nativeClient: FourD4yMyContentNativeClient = new FourD4yMyContentNativeClient();
  private readonly postResolver: FourD4ySearchPostNativeResolver = new FourD4ySearchPostNativeResolver();
  private viewerUserId: string = '';
  private loadSequence: number = 0;
  private terminalLoadSequence: number = 0;
  private postResolveSequence: number = 0;
  private loadTimeoutId: number = -1;
  private postResolveTimeoutId: number = -1;
  private readonly timeoutMillis: number = 30000;

  aboutToDisappear(): void {
    this.loadSequence += 1;
    this.postResolveSequence += 1;
    this.clearLoadWatchdog();
    this.clearPostResolveWatchdog();
  }

  build() {
    NavDestination() {
      Column() {
        this.buildContent();
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
    }
    .title(this.selectedMode === FourD4yMyContentMode.Threads ? '我的主题' : '我的回复')
    .menus(this.buildTitleActions)
    .onReady((context: NavDestinationContext) => {
      const route: MyContentRouteParams = context.pathInfo.param as MyContentRouteParams;
      this.selectedMode = readMyContentRouteMode(route);
      this.loadPage(1);
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
      .opacity(!this.isLoading && !this.isResolvingPost ? 1 : 0.35)
      .onClick(() => {
        if (!this.isLoading && !this.isResolvingPost) {
          this.loadPage(this.currentPage);
        }
      })
  }

  @Builder
  private buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text(this.selectedMode === FourD4yMyContentMode.Threads ?
          '正在读取我的主题…' : '正在读取我的回复…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.items.length > 0) {
      Column() {
        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 20, right: 20, top: 8, bottom: 4 })
            .width('100%')
        }
        List({ space: 0 }) {
          ForEach(this.items, (item: FourD4yMyContentItem) => {
            ListItem() {
              this.buildItem(item);
            }
            .onClick(() => {
              this.openItem(item);
            })
          }, (item: FourD4yMyContentItem) => item.postId.length > 0 ?
            'post:' + item.postId : 'thread:' + item.threadId)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 20, endMargin: 20 })
        this.buildPager();
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      Column({ space: 12 }) {
        Text(this.statusMessage.length > 0 ? this.statusMessage :
          (this.selectedMode === FourD4yMyContentMode.Threads ? '还没有发表过主题' : '还没有发表过回复'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button(this.isLoggedIn ? '重试' : '去登录')
          .onClick(() => {
            if (this.isLoggedIn) {
              this.loadPage(1);
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
  private buildItem(item: FourD4yMyContentItem) {
    Column({ space: 5 }) {
      Text(item.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_strong'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (item.summary.length > 0) {
        Text(item.summary)
          .fontSize(14)
          .fontColor($r('app.color.text_detail'))
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row() {
        Text(item.forumName.length > 0 ? item.forumName : '4D4Y')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.postId.length > 0) {
          Text('我的回复')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 10 })
        }
        Blank()
        Text(item.lastReplyAt)
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
      }
      .width('100%')
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
        .enabled(!this.isLoading && !this.isResolvingPost && this.currentPage > 1)
        .onClick(() => {
          this.loadPage(this.currentPage - 1);
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
        .enabled(!this.isLoading && !this.isResolvingPost && this.currentPage < this.lastPage)
        .onClick(() => {
          this.loadPage(this.currentPage + 1);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  private async loadPage(page: number): Promise<void> {
    if (this.isLoading || this.isResolvingPost) {
      return;
    }
    const requestMode: FourD4yMyContentMode = this.selectedMode;
    const requestUrl: string | null = buildFourD4yMyContentUrl(requestMode, page);
    if (requestUrl === null) {
      this.statusMessage = '当前页码无法读取。';
      return;
    }
    const expectedLoadSequence: number = this.loadSequence + 1;
    this.loadSequence = expectedLoadSequence;
    this.terminalLoadSequence = 0;
    this.isLoading = true;
    this.statusMessage = '';
    this.startLoadWatchdog(expectedLoadSequence);
    try {
      const result: FourD4yNativeMyContentResult = await this.nativeClient.load(requestUrl, expectedLoadSequence);
      if (!this.isLoading || this.loadSequence !== expectedLoadSequence || this.selectedMode !== requestMode ||
        this.terminalLoadSequence === expectedLoadSequence) {
        return;
      }
      if (result.status === 'cookie-missing') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '请先登录 4D4Y 后查看账号内容。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failLoad(expectedLoadSequence, '暂时无法读取 4D4Y 账号内容，请检查网络后重试。');
        return;
      }
      const payload: FourD4yMyContentPagePayload | null = result.payload;
      if (result.status === 'unsupported-response' || payload === null ||
        !isExpectedFourD4yMyContentPagePayload(payload, requestMode, page, expectedLoadSequence)) {
        this.failLoad(expectedLoadSequence, '4D4Y 账号列表已返回，但页面结构暂未适配。');
        return;
      }
      const outcome: FourD4yMyContentReaderOutcome = getFourD4yMyContentReaderOutcome(payload);
      if (outcome === FourD4yMyContentReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (outcome === FourD4yMyContentReaderOutcome.VerificationRequired) {
        this.failLoad(expectedLoadSequence, '请先在登录页完成 4D4Y 安全验证后再查看。');
        return;
      }
      if (outcome === FourD4yMyContentReaderOutcome.UnsupportedLayout) {
        this.failLoad(expectedLoadSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前 4D4Y 账号列表结构暂未适配。');
        return;
      }
      this.clearLoadWatchdog();
      this.terminalLoadSequence = expectedLoadSequence;
      this.isLoading = false;
      this.isLoggedIn = true;
      this.items = payload.items;
      this.currentPage = payload.page;
      this.lastPage = payload.lastPage;
      this.viewerUserId = payload.viewerUserId;
      this.statusMessage = outcome === FourD4yMyContentReaderOutcome.Empty ?
        (requestMode === FourD4yMyContentMode.Threads ? '还没有发表过主题。' : '还没有发表过回复。') : '';
    } catch (_error) {
      if (this.isLoading && this.loadSequence === expectedLoadSequence) {
        this.failLoad(expectedLoadSequence, '暂时无法读取 4D4Y 账号内容，请稍后重试。');
      }
    }
  }

  private openItem(item: FourD4yMyContentItem): void {
    if (this.isLoading || this.isResolvingPost) {
      return;
    }
    if (item.postId.length > 0) {
      this.resolveReplyPost(item);
      return;
    }
    if (this.selectedMode === FourD4yMyContentMode.Replies) {
      this.statusMessage = '4D4Y 没有为这条回复提供可确认的楼层地址。';
      return;
    }
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
      item.threadId, item.title, 0, 1, 0, item.forumId));
  }

  private async resolveReplyPost(item: FourD4yMyContentItem): Promise<void> {
    if (!/^\d+$/.test(this.viewerUserId)) {
      this.statusMessage = '当前账号标识无法确认，请刷新“我的回复”后重试。';
      return;
    }
    const resolveSequence: number = this.postResolveSequence + 1;
    this.postResolveSequence = resolveSequence;
    this.isResolvingPost = true;
    this.statusMessage = '正在定位这条回复的楼层…';
    this.startPostResolveWatchdog(resolveSequence);
    try {
      const referer: string | null = buildFourD4yMyContentUrl(FourD4yMyContentMode.Replies, this.currentPage);
      const result: FourD4ySearchPostResolveResult = await this.postResolver.resolve(
        item.threadId, item.postId, resolveSequence, this.viewerUserId,
        referer === null ? FourD4ySession.forumRoot : referer);
      if (!this.isResolvingPost || this.postResolveSequence !== resolveSequence) {
        return;
      }
      if (result.status === 'cookie-missing' || result.status === 'user-context-missing') {
        this.failPostResolution('当前 4D4Y 登录上下文无法确认，请重新登录后再打开。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.failPostResolution('4D4Y 登录状态已失效，请重新登录后再打开。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failPostResolution('暂时无法定位这条回复，请检查网络后重试。');
        return;
      }
      if (result.payload === null || result.status === 'unsupported-response' ||
        result.status === 'post-unavailable' || !result.payload.postFound) {
        this.failPostResolution(result.payload !== null && result.payload.errorMessage.length > 0 ?
          result.payload.errorMessage : '这条回复可能已删除、回收或暂时无权访问。');
        return;
      }
      this.clearPostResolveWatchdog();
      this.isResolvingPost = false;
      this.statusMessage = '';
      this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
        result.payload.threadId, result.payload.title.length > 0 ? result.payload.title : item.title,
        0, result.payload.page, result.payload.floor, item.forumId, false, 1, item.postId));
    } catch (_error) {
      if (this.isResolvingPost && this.postResolveSequence === resolveSequence) {
        this.failPostResolution('暂时无法读取这条回复，请稍后重试。');
      }
    }
  }

  private startLoadWatchdog(loadSequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (this.isLoading && this.loadSequence === loadSequence) {
        this.failLoad(loadSequence, '读取 4D4Y 账号列表超时，请重试。');
      }
    }, this.timeoutMillis);
  }

  private clearLoadWatchdog(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  private failLoad(loadSequence: number, message: string): void {
    if (loadSequence !== this.loadSequence) {
      return;
    }
    this.clearLoadWatchdog();
    this.terminalLoadSequence = loadSequence;
    this.isLoading = false;
    this.items = [];
    this.statusMessage = message;
  }

  private startPostResolveWatchdog(resolveSequence: number): void {
    this.clearPostResolveWatchdog();
    this.postResolveTimeoutId = setTimeout(() => {
      if (this.isResolvingPost && this.postResolveSequence === resolveSequence) {
        this.failPostResolution('定位回复楼层超时，请稍后重试。');
      }
    }, this.timeoutMillis);
  }

  private clearPostResolveWatchdog(): void {
    if (this.postResolveTimeoutId >= 0) {
      clearTimeout(this.postResolveTimeoutId);
      this.postResolveTimeoutId = -1;
    }
  }

  private failPostResolution(message: string): void {
    this.clearPostResolveWatchdog();
    this.isResolvingPost = false;
    this.statusMessage = message;
  }
}
