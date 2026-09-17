import { FourD4yMessageNativeClient, FourD4yNativeMessagePageResult,
  FourD4yNativeMessagePromptResult, FourD4yNativePrivateConversationResult } from
  '../../data/remote/FourD4yMessageNativeClient';
import { FourD4ySearchPostNativeResolver, FourD4ySearchPostResolveResult } from
  '../../data/remote/FourD4ySearchPostNativeResolver';
import { FourD4yMessageItem, FourD4yMessageKind, FourD4yMessageMode, FourD4yMessagePagePayload,
  FourD4yMessagePromptPayload, FourD4yMessageReaderOutcome, buildFourD4yMessagePageUrl,
  getFourD4yMessageReaderOutcome, isExpectedFourD4yMessagePagePayload,
  isExpectedFourD4yMessagePromptPayload } from '../../domain/notice/FourD4yMessageContracts';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yPrivateConversationPayload, FourD4yPrivateConversationReaderOutcome,
  buildFourD4yPrivateConversationUrl, getFourD4yPrivateConversationReaderOutcome,
  isExpectedFourD4yPrivateConversationPayload } from
  '../../domain/notice/FourD4yPrivateConversationContracts';
import { findFourD4yPrivateMessageSearchHits, FourD4yPrivateMessageSearchHit,
  normalizeFourD4yPrivateMessageSearchQuery } from '../../domain/notice/FourD4yPrivateMessageSearch';
import { describeFourD4yNativeRequestFailure } from '../../data/remote/FourD4yNativeRequestFailure';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { createPrivateMessageRouteParams } from './PrivateMessageRouteState';
import { MessageCenterRouteParams, readMessageCenterRouteMode } from './MessageCenterRouteState';
import { FourD4yUnreadState } from '../../domain/notice/FourD4yUnreadState';

/**
 * Read-only message centre.  Opening this page only fetches the three list
 * endpoints and index.php's prompt counters. PM conversation reading uses the
 * forum's normal GET route; sending, deletion and clearing remain unavailable.
 */
@Component
export struct MessageCenterPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('unreadState') unreadState: FourD4yUnreadState;
  @State selectedMode: FourD4yMessageMode = FourD4yMessageMode.PrivateMessages;
  @State items: FourD4yMessageItem[] = [];
  @State currentPage: number = 1;
  @State lastPage: number = 1;
  @State privateMessageCount: number = 0;
  @State threadNoticeCount: number = 0;
  @State systemNoticeCount: number = 0;
  @State isLoading: boolean = false;
  @State isResolvingPost: boolean = false;
  @State statusMessage: string = '';
  @State privateSearchQuery: string = '';
  @State isPrivateSearchActive: boolean = false;
  @State isPrivateSearchRunning: boolean = false;
  @State isPrivateSearchCompleted: boolean = false;
  @State privateSearchHits: FourD4yPrivateMessageSearchHit[] = [];
  @State privateSearchResultPage: number = 1;
  @State privateSearchStatus: string = '';
  @State privateSearchCheckedConversationCount: number = 0;
  @State privateSearchConversationCount: number = 0;

  private readonly nativeClient: FourD4yMessageNativeClient = new FourD4yMessageNativeClient();
  private readonly postResolver: FourD4ySearchPostNativeResolver = new FourD4ySearchPostNativeResolver();
  private viewerUserId: string = '';
  private loadSequence: number = 0;
  private terminalLoadSequence: number = 0;
  private promptSequence: number = 0;
  private postResolveSequence: number = 0;
  private loadTimeoutId: number = -1;
  private postResolveTimeoutId: number = -1;
  private readonly timeoutMillis: number = 30000;
  private privateSearchSequence: number = 0;
  private privateSearchNetworkSequence: number = 0;
  private readonly privateSearchResultPageSize: number = 40;

  aboutToDisappear(): void {
    this.loadSequence += 1;
    this.promptSequence += 1;
    this.postResolveSequence += 1;
    this.privateSearchSequence += 1;
    this.clearPrivateSearchResults();
    this.clearLoadWatchdog();
    this.clearPostResolveWatchdog();
  }

  build() {
    NavDestination() {
      Column() {
        this.buildToolbar();
        Divider().color($r('app.color.border'));
        this.buildContent();
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
    }
    .title(this.getModeLabel(this.selectedMode))
    .menus(this.buildTitleActions)
    // Navigation keeps this destination alive underneath a PM conversation.
    // onActive, unlike aboutToAppear, runs again after the user returns.
    .onActive(() => {
      this.refreshAfterChildDestination();
    })
    .onReady((context: NavDestinationContext) => {
      const route: MessageCenterRouteParams = context.pathInfo.param as MessageCenterRouteParams;
      this.selectedMode = readMessageCenterRouteMode(route);
      this.loadPromptCounts();
      this.loadPage(1);
    })
  }

  @Builder
  private buildToolbar() {
    Row({ space: 8 }) {
      this.buildModeButton(FourD4yMessageMode.PrivateMessages, '私信');
      this.buildModeButton(FourD4yMessageMode.ThreadNotices, '帖子提醒');
      this.buildModeButton(FourD4yMessageMode.SystemNotices, '系统');
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
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
      .opacity(!this.isLoading && !this.isResolvingPost && !this.isPrivateSearchRunning ? 1 : 0.35)
      .onClick(() => {
        if (!this.isLoading && !this.isResolvingPost && !this.isPrivateSearchRunning) {
          this.loadPromptCounts();
          this.loadPage(this.currentPage);
        }
      })
  }

  @Builder
  private buildModeButton(mode: FourD4yMessageMode, label: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.selectedMode === mode ? $r('app.color.on_brand') : $r('app.color.text_chip'))
      if (this.getUnreadCount(mode) > 0) {
        Text(this.formatUnreadCount(this.getUnreadCount(mode)))
          .fontSize(10)
          .fontColor(this.selectedMode === mode ? $r('app.color.on_brand') : $r('app.color.danger_text'))
      }
    }
    .backgroundColor(this.selectedMode === mode ? $r('app.color.brand_strong') : $r('app.color.fill_selected'))
    .borderRadius(6)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 11, right: 11, top: 8, bottom: 8 })
    .onClick(() => {
      if (!this.isLoading && !this.isResolvingPost && !this.isPrivateSearchRunning && this.selectedMode !== mode) {
        this.clearPrivateSearchResults();
        this.selectedMode = mode;
        this.loadPage(1);
      }
    })
  }

  @Builder
  private buildContent() {
    Column() {
      if (this.selectedMode === FourD4yMessageMode.PrivateMessages) {
        this.buildPrivateSearchHeader();
      }
      if (this.selectedMode === FourD4yMessageMode.PrivateMessages && this.isPrivateSearchActive) {
        this.buildPrivateSearchResults();
      } else {
        this.buildMessageListContent();
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private buildMessageListContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在读取' + this.getModeLabel(this.selectedMode) + '…')
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
          ForEach(this.items, (item: FourD4yMessageItem) => {
            ListItem() {
              this.buildItem(item);
            }
            .onClick(() => {
              this.openItem(item);
            })
          }, (item: FourD4yMessageItem) => item.itemId)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
        this.buildPager();
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      Column({ space: 12 }) {
        Text(this.statusMessage.length > 0 ? this.statusMessage : '暂无' + this.getModeLabel(this.selectedMode))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button(this.isLoggedIn ? '重试' : '去登录')
          .onClick(() => {
            if (this.isLoggedIn) {
              this.loadPromptCounts();
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
  private buildPrivateSearchHeader() {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索全部私信正文', text: this.privateSearchQuery })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .enabled(!this.isPrivateSearchRunning && !this.isLoading && !this.isResolvingPost)
          .onChange((value: string) => {
            this.privateSearchQuery = value;
          })
        Button(this.isPrivateSearchRunning ? '停止' : '搜索')
          .fontSize(13)
          .height(36)
          .enabled(this.isPrivateSearchRunning || (!this.isLoading && !this.isResolvingPost &&
            normalizeFourD4yPrivateMessageSearchQuery(this.privateSearchQuery).length > 0))
          .onClick(() => {
            if (this.isPrivateSearchRunning) {
              this.stopPrivateSearch();
            } else {
              void this.startPrivateSearch();
            }
          })
      }
      .width('100%')
      if (this.isPrivateSearchActive) {
        Row({ space: 8 }) {
          Text(this.privateSearchStatus)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button('关闭结果')
            .fontSize(12)
            .height(30)
            .enabled(!this.isPrivateSearchRunning)
            .onClick(() => {
              this.clearPrivateSearchResults();
            })
        }
        .width('100%')
      } else {
        Text('搜索会读取全部私信会话的正文，未读私信可能被论坛标为已读；不会在本机保存私信历史或全文索引。')
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 6 })
  }

  @Builder
  private buildPrivateSearchResults() {
    if (this.isPrivateSearchRunning && this.privateSearchHits.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text(this.privateSearchStatus.length > 0 ? this.privateSearchStatus : '正在搜索私信…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else if (!this.isPrivateSearchRunning && this.privateSearchHits.length === 0) {
      Column({ space: 9 }) {
        Text(this.isPrivateSearchCompleted ? ('没有命中“' + this.privateSearchQuery.trim() + '”的私信正文') :
          this.privateSearchStatus)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        if (this.isPrivateSearchCompleted) {
          Text(this.privateSearchStatus)
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .textAlign(TextAlign.Center)
        }
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else {
      Column() {
        if (this.isPrivateSearchRunning) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(18)
              .height(18)
            Text(this.privateSearchStatus)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 6, bottom: 4 })
        }
        List({ space: 0 }) {
          ForEach(this.getPrivateSearchPageHits(), (hit: FourD4yPrivateMessageSearchHit) => {
            ListItem() {
              this.buildPrivateSearchHit(hit);
            }
            .onClick(() => {
              this.openPrivateSearchHit(hit);
            })
          }, (hit: FourD4yPrivateMessageSearchHit) => hit.participantUserId + ':' + hit.messageId)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
        if (!this.isPrivateSearchRunning) {
          this.buildPrivateSearchPager();
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  private buildPrivateSearchHit(hit: FourD4yPrivateMessageSearchHit) {
    Column({ space: 5 }) {
      Row({ space: 7 }) {
        Text(hit.isMine ? '我' : (hit.participantName.length > 0 ? hit.participantName : '私信会话'))
          .fontSize(11)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.info_subtle'))
          .borderRadius(8)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
      .width('100%')
      Row() {
        Text(hit.excerpt)
          .fontSize(14)
          .fontColor($r('app.color.text_detail'))
          .lineHeight(21)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(hit.occurredAt.length > 0 ? hit.occurredAt : '打开会话查看上下文')
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 10 })
  }

  @Builder
  private buildItem(item: FourD4yMessageItem) {
    Column({ space: 5 }) {
      Row({ space: 7 }) {
        if (item.isUnread) {
          Text('未读')
            .fontSize(11)
            .fontColor($r('app.color.danger_text'))
            .backgroundColor($r('app.color.danger_background'))
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        Text(item.title)
          .fontSize(17)
          .fontWeight(item.isUnread ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('app.color.text_strong'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      if (item.summary.length > 0 && item.summary !== item.title) {
        Text(item.summary)
          .fontSize(14)
          .fontColor($r('app.color.text_detail'))
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row() {
        Text(this.buildSourceLabel(item))
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(item.occurredAt)
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

  @Builder
  private buildPrivateSearchPager() {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor(this.privateSearchResultPage > 1 ? $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(this.privateSearchResultPage > 1)
        .onClick(() => {
          if (this.privateSearchResultPage > 1) {
            this.privateSearchResultPage -= 1;
          }
        })
      Blank()
      Text(this.privateSearchResultPage + ' / ' + this.getPrivateSearchLastPage())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_detail'))
        .backgroundColor($r('app.color.fill_subtle'))
        .borderRadius(14)
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
      Blank()
      Text('›')
        .fontSize(30)
        .fontColor(this.privateSearchResultPage < this.getPrivateSearchLastPage() ?
          $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(this.privateSearchResultPage < this.getPrivateSearchLastPage())
        .onClick(() => {
          if (this.privateSearchResultPage < this.getPrivateSearchLastPage()) {
            this.privateSearchResultPage += 1;
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  private async loadPage(page: number): Promise<void> {
    if (this.isLoading || this.isResolvingPost || this.isPrivateSearchRunning) {
      return;
    }
    const requestMode: FourD4yMessageMode = this.selectedMode;
    const requestUrl: string | null = buildFourD4yMessagePageUrl(requestMode, page);
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
      const result: FourD4yNativeMessagePageResult = await this.nativeClient.loadPage(requestUrl, expectedLoadSequence);
      if (!this.isLoading || this.loadSequence !== expectedLoadSequence || this.selectedMode !== requestMode ||
        this.terminalLoadSequence === expectedLoadSequence) {
        return;
      }
      if (result.status === 'cookie-missing') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '请先登录 4D4Y 后查看消息。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failLoad(expectedLoadSequence, '暂时无法读取 4D4Y 消息，请检查网络后重试。');
        return;
      }
      const payload: FourD4yMessagePagePayload | null = result.payload;
      if (result.status === 'unsupported-response' || payload === null ||
        !isExpectedFourD4yMessagePagePayload(payload, requestMode, page, expectedLoadSequence)) {
        this.failLoad(expectedLoadSequence, '4D4Y 消息页已返回，但页面结构暂未适配。');
        return;
      }
      const outcome: FourD4yMessageReaderOutcome = getFourD4yMessageReaderOutcome(payload);
      if (outcome === FourD4yMessageReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.failLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再查看。');
        return;
      }
      if (outcome === FourD4yMessageReaderOutcome.VerificationRequired) {
        this.failLoad(expectedLoadSequence, '请先在登录页完成 4D4Y 安全验证后再查看消息。');
        return;
      }
      if (outcome === FourD4yMessageReaderOutcome.UnsupportedLayout) {
        this.failLoad(expectedLoadSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前 4D4Y 消息页结构暂未适配。');
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
      this.statusMessage = outcome === FourD4yMessageReaderOutcome.Empty ?
        '暂无' + this.getModeLabel(requestMode) + '。' : '';
    } catch (_error) {
      if (this.isLoading && this.loadSequence === expectedLoadSequence) {
        this.failLoad(expectedLoadSequence, '暂时无法读取 4D4Y 消息，请稍后重试。');
      }
    }
  }

  private async loadPromptCounts(): Promise<void> {
    const expectedPromptSequence: number = this.promptSequence + 1;
    this.promptSequence = expectedPromptSequence;
    try {
      const result: FourD4yNativeMessagePromptResult = await this.nativeClient.loadPrompt(expectedPromptSequence);
      if (this.promptSequence !== expectedPromptSequence) {
        return;
      }
      if (result.status === 'cookie-missing' || result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.unreadState.clear();
        return;
      }
      const payload: FourD4yMessagePromptPayload | null = result.payload;
      if (result.status !== 'success' || payload === null ||
        !isExpectedFourD4yMessagePromptPayload(payload, expectedPromptSequence)) {
        return;
      }
      if (payload.accessState === 'loginRequired') {
        this.isLoggedIn = false;
        this.unreadState.clear();
        return;
      }
      this.isLoggedIn = true;
      this.privateMessageCount = payload.privateMessageCount;
      this.threadNoticeCount = payload.threadNoticeCount;
      this.systemNoticeCount = payload.systemNoticeCount;
      this.unreadState.observeServerCounts(payload.privateMessageCount, payload.threadNoticeCount,
        payload.systemNoticeCount, payload.friendNoticeCount);
    } catch (_error) {
      // Counts are an enhancement only. The selected list keeps its own error state.
    }
  }

  private openItem(item: FourD4yMessageItem): void {
    if (this.isLoading || this.isResolvingPost || this.isPrivateSearchRunning) {
      return;
    }
    if (item.kind === FourD4yMessageKind.PrivateMessage) {
      if (!/^\d+$/.test(item.senderUserId)) {
        this.statusMessage = '这条私信缺少可确认的发件人标识。';
        return;
      }
      this.pathStack.pushPathByName('PrivateMessageDetail',
        createPrivateMessageRouteParams(item.senderUserId, item.senderName), (_popInfo: PopInfo) => {
          this.loadPromptCounts();
          this.loadPage(this.currentPage);
        });
      return;
    }
    if (!/^\d+$/.test(item.threadId)) {
      this.statusMessage = '这条提醒没有可确认的主题地址。';
      return;
    }
    if (/^\d+$/.test(item.postId)) {
      this.resolveNoticePost(item);
      return;
    }
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(item.threadId, item.title, 0, 1));
  }

  private refreshAfterChildDestination(): void {
    if (this.isLoading || this.isResolvingPost) {
      return;
    }
    this.loadPromptCounts();
    this.loadPage(this.currentPage);
  }

  private async resolveNoticePost(item: FourD4yMessageItem): Promise<void> {
    if (!/^\d+$/.test(this.viewerUserId)) {
      this.statusMessage = '当前账号标识无法确认，请刷新当前提醒后重试。';
      return;
    }
    const resolveSequence: number = this.postResolveSequence + 1;
    this.postResolveSequence = resolveSequence;
    this.isResolvingPost = true;
    this.statusMessage = '正在定位这条提醒对应的楼层…';
    this.startPostResolveWatchdog(resolveSequence);
    try {
      const referer: string | null = buildFourD4yMessagePageUrl(this.selectedMode, this.currentPage);
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
        this.failPostResolution('暂时无法定位这条提醒，请检查网络后重试。');
        return;
      }
      if (result.payload === null || result.status === 'unsupported-response' ||
        result.status === 'post-unavailable' || !result.payload.postFound) {
        this.failPostResolution(result.payload !== null && result.payload.errorMessage.length > 0 ?
          result.payload.errorMessage : '这条提醒对应的回复可能已删除、回收或暂时无权访问。');
        return;
      }
      this.clearPostResolveWatchdog();
      this.isResolvingPost = false;
      this.statusMessage = '';
      this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
        result.payload.threadId, result.payload.title.length > 0 ? result.payload.title : item.title,
        0, result.payload.page, result.payload.floor, '', false, 1, item.postId));
    } catch (_error) {
      if (this.isResolvingPost && this.postResolveSequence === resolveSequence) {
        this.failPostResolution('暂时无法读取这条提醒，请稍后重试。');
      }
    }
  }

  private async startPrivateSearch(): Promise<void> {
    const query: string = normalizeFourD4yPrivateMessageSearchQuery(this.privateSearchQuery);
    if (query.length === 0 || this.isPrivateSearchRunning || this.isLoading || this.isResolvingPost) {
      return;
    }
    if (!this.isLoggedIn) {
      this.statusMessage = '请先登录 4D4Y 后再搜索私信。';
      return;
    }
    const searchSequence: number = this.privateSearchSequence + 1;
    this.privateSearchSequence = searchSequence;
    this.isPrivateSearchActive = true;
    this.isPrivateSearchRunning = true;
    this.isPrivateSearchCompleted = false;
    this.privateSearchHits = [];
    this.privateSearchResultPage = 1;
    this.privateSearchCheckedConversationCount = 0;
    this.privateSearchConversationCount = 0;
    this.privateSearchStatus = '正在读取全部私信列表…';
    const participantNames: Map<string, string> = new Map<string, string>();
    let expectedViewerUserId: string = '';
    let lastPage: number = 1;
    try {
      for (let page: number = 1; page <= lastPage; page += 1) {
        if (!this.isPrivateSearchCurrent(searchSequence)) {
          return;
        }
        this.privateSearchStatus = '正在读取私信列表 ' + page + ' / ' + lastPage + '…';
        const requestUrl: string | null = buildFourD4yMessagePageUrl(FourD4yMessageMode.PrivateMessages, page);
        if (requestUrl === null) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：私信列表页码无效。');
          return;
        }
        const loadSequence: number = this.nextPrivateSearchNetworkSequence();
        const result: FourD4yNativeMessagePageResult = await this.nativeClient.loadPage(requestUrl, loadSequence);
        if (!this.isPrivateSearchCurrent(searchSequence)) {
          return;
        }
        const payload: FourD4yMessagePagePayload | null = result.payload;
        if (result.status === 'cookie-missing' || result.status === 'server-login-required') {
          this.isLoggedIn = false;
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：4D4Y 登录状态已失效。');
          return;
        }
        if (result.status === 'request-failed') {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：读取私信列表失败，请检查网络后重试。');
          return;
        }
        if (result.status === 'unsupported-response' || payload === null ||
          !isExpectedFourD4yMessagePagePayload(payload, FourD4yMessageMode.PrivateMessages, page, loadSequence)) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：当前私信列表结构暂未适配。');
          return;
        }
        const outcome: FourD4yMessageReaderOutcome = getFourD4yMessageReaderOutcome(payload);
        if (outcome === FourD4yMessageReaderOutcome.LoginRequired) {
          this.isLoggedIn = false;
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：4D4Y 登录状态已失效。');
          return;
        }
        if (outcome === FourD4yMessageReaderOutcome.VerificationRequired) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：请先在登录页完成 4D4Y 安全验证。');
          return;
        }
        if (outcome === FourD4yMessageReaderOutcome.UnsupportedLayout) {
          this.finishPrivateSearch(searchSequence, false, payload.errorMessage.length > 0 ? payload.errorMessage :
            '搜索未完成：当前私信列表结构暂未适配。');
          return;
        }
        if (expectedViewerUserId.length === 0 && /^\d+$/.test(payload.viewerUserId)) {
          expectedViewerUserId = payload.viewerUserId;
        } else if (expectedViewerUserId.length > 0 && /^\d+$/.test(payload.viewerUserId) &&
          expectedViewerUserId !== payload.viewerUserId) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：读取期间 4D4Y 账号发生变化。');
          return;
        }
        lastPage = payload.lastPage;
        for (const item of payload.items) {
          if (!/^\d+$/.test(item.senderUserId)) {
            continue;
          }
          const previousName: string | undefined = participantNames.get(item.senderUserId);
          if (previousName === undefined || (previousName.length === 0 && item.senderName.length > 0)) {
            participantNames.set(item.senderUserId, item.senderName);
          }
        }
      }
      if (!this.isPrivateSearchCurrent(searchSequence)) {
        return;
      }
      const participantIds: string[] = [];
      const participantDisplayNames: string[] = [];
      participantNames.forEach((name: string, userId: string) => {
        participantIds.push(userId);
        participantDisplayNames.push(name);
      });
      this.privateSearchConversationCount = participantIds.length;
      if (participantIds.length === 0) {
        this.finishPrivateSearch(searchSequence, true, '已检查私信列表，没有可读取的私信会话。');
        return;
      }
      for (let index: number = 0; index < participantIds.length; index += 1) {
        if (!this.isPrivateSearchCurrent(searchSequence)) {
          return;
        }
        const participantUserId: string = participantIds[index];
        this.privateSearchStatus = '正在搜索会话 ' + (index + 1) + ' / ' + participantIds.length + '…';
        const requestUrl: string | null = buildFourD4yPrivateConversationUrl(participantUserId);
        if (requestUrl === null) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：私信会话标识无效。');
          return;
        }
        const loadSequence: number = this.nextPrivateSearchNetworkSequence();
        const result: FourD4yNativePrivateConversationResult = await this.nativeClient.loadPrivateConversation(
          requestUrl, loadSequence);
        if (!this.isPrivateSearchCurrent(searchSequence)) {
          return;
        }
        const payload: FourD4yPrivateConversationPayload | null = result.payload;
        if (result.status === 'cookie-missing' || result.status === 'server-login-required') {
          this.isLoggedIn = false;
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：4D4Y 登录状态已失效。');
          return;
        }
        if (result.status === 'request-failed') {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：' +
            describeFourD4yNativeRequestFailure(result.failure) + '。');
          return;
        }
        if (result.status === 'unsupported-response' || payload === null ||
          !isExpectedFourD4yPrivateConversationPayload(payload, participantUserId, loadSequence)) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：当前私信会话结构暂未适配。');
          return;
        }
        const outcome: FourD4yPrivateConversationReaderOutcome =
          getFourD4yPrivateConversationReaderOutcome(payload);
        if (outcome === FourD4yPrivateConversationReaderOutcome.LoginRequired) {
          this.isLoggedIn = false;
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：4D4Y 登录状态已失效。');
          return;
        }
        if (outcome === FourD4yPrivateConversationReaderOutcome.VerificationRequired) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：请先在登录页完成 4D4Y 安全验证。');
          return;
        }
        if (outcome === FourD4yPrivateConversationReaderOutcome.UnsupportedLayout) {
          this.finishPrivateSearch(searchSequence, false, payload.errorMessage.length > 0 ? payload.errorMessage :
            '搜索未完成：当前私信会话结构暂未适配。');
          return;
        }
        if (expectedViewerUserId.length > 0 && /^\d+$/.test(payload.viewerUserId) &&
          expectedViewerUserId !== payload.viewerUserId) {
          this.finishPrivateSearch(searchSequence, false, '搜索未完成：读取期间 4D4Y 账号发生变化。');
          return;
        }
        const hits: FourD4yPrivateMessageSearchHit[] = findFourD4yPrivateMessageSearchHits(
          query, participantUserId, participantDisplayNames[index], payload.messages);
        if (hits.length > 0) {
          this.privateSearchHits = this.privateSearchHits.concat(hits);
        }
        this.privateSearchCheckedConversationCount = index + 1;
      }
      this.finishPrivateSearch(searchSequence, true, '已检查 ' + participantIds.length + ' 个会话，命中 ' +
        this.privateSearchHits.length + ' 条私信。');
    } catch (_error) {
      if (this.isPrivateSearchCurrent(searchSequence)) {
        this.finishPrivateSearch(searchSequence, false, '搜索未完成：读取私信时发生异常，请稍后重试。');
      }
    }
  }

  private stopPrivateSearch(): void {
    if (!this.isPrivateSearchRunning) {
      return;
    }
    this.privateSearchSequence += 1;
    this.isPrivateSearchRunning = false;
    this.isPrivateSearchCompleted = false;
    this.privateSearchStatus = '搜索已停止：已检查 ' + this.privateSearchCheckedConversationCount + ' / ' +
      this.privateSearchConversationCount + ' 个会话，当前命中 ' + this.privateSearchHits.length + ' 条。';
  }

  private finishPrivateSearch(searchSequence: number, completed: boolean, message: string): void {
    if (this.privateSearchSequence !== searchSequence) {
      return;
    }
    this.isPrivateSearchRunning = false;
    this.isPrivateSearchActive = true;
    this.isPrivateSearchCompleted = completed;
    this.privateSearchStatus = message;
  }

  private clearPrivateSearchResults(): void {
    this.privateSearchSequence += 1;
    this.isPrivateSearchActive = false;
    this.isPrivateSearchRunning = false;
    this.isPrivateSearchCompleted = false;
    this.privateSearchHits = [];
    this.privateSearchResultPage = 1;
    this.privateSearchStatus = '';
    this.privateSearchCheckedConversationCount = 0;
    this.privateSearchConversationCount = 0;
  }

  private isPrivateSearchCurrent(searchSequence: number): boolean {
    return this.isPrivateSearchRunning && this.privateSearchSequence === searchSequence &&
      this.selectedMode === FourD4yMessageMode.PrivateMessages;
  }

  private nextPrivateSearchNetworkSequence(): number {
    this.privateSearchNetworkSequence += 1;
    return this.privateSearchNetworkSequence;
  }

  private getPrivateSearchPageHits(): FourD4yPrivateMessageSearchHit[] {
    const start: number = (this.privateSearchResultPage - 1) * this.privateSearchResultPageSize;
    return this.privateSearchHits.slice(start, start + this.privateSearchResultPageSize);
  }

  private getPrivateSearchLastPage(): number {
    return Math.max(1, Math.ceil(this.privateSearchHits.length / this.privateSearchResultPageSize));
  }

  private openPrivateSearchHit(hit: FourD4yPrivateMessageSearchHit): void {
    if (this.isPrivateSearchRunning || !/^\d+$/.test(hit.participantUserId)) {
      return;
    }
    this.pathStack.pushPathByName('PrivateMessageDetail',
      createPrivateMessageRouteParams(hit.participantUserId, hit.participantName), (_popInfo: PopInfo) => {
        this.loadPromptCounts();
      });
  }

  private getUnreadCount(mode: FourD4yMessageMode): number {
    if (mode === FourD4yMessageMode.PrivateMessages) {
      return this.privateMessageCount;
    }
    if (mode === FourD4yMessageMode.ThreadNotices) {
      return this.threadNoticeCount;
    }
    return this.systemNoticeCount;
  }

  private formatUnreadCount(value: number): string {
    return value > 99 ? '99+' : String(value);
  }

  private getModeLabel(mode: FourD4yMessageMode): string {
    if (mode === FourD4yMessageMode.PrivateMessages) {
      return '私信';
    }
    if (mode === FourD4yMessageMode.ThreadNotices) {
      return '帖子提醒';
    }
    return '系统消息';
  }

  private buildSourceLabel(item: FourD4yMessageItem): string {
    const sender: string = item.senderName.length > 0 ? item.senderName : '';
    if (item.kind === FourD4yMessageKind.PrivateMessage) {
      return sender.length > 0 ? sender : '私信';
    }
    if (item.kind === FourD4yMessageKind.Thread) {
      return sender.length > 0 ? sender + ' · 关注主题' : '关注主题';
    }
    if (item.kind === FourD4yMessageKind.Quote) {
      return sender.length > 0 ? sender + ' · 引用' : '引用提醒';
    }
    if (item.kind === FourD4yMessageKind.Reply) {
      return sender.length > 0 ? sender + ' · 回复' : '回复提醒';
    }
    return sender.length > 0 ? sender : '系统通知';
  }

  private startLoadWatchdog(loadSequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      if (this.isLoading && this.loadSequence === loadSequence) {
        this.failLoad(loadSequence, '读取 4D4Y 消息超时，请重试。');
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
        this.failPostResolution('定位提醒楼层超时，请稍后重试。');
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
