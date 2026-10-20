import { webview } from '@kit.ArkWeb';
import { FourD4ySearchHistoryStore } from '../../data/local/FourD4ySearchHistoryStore';
import { FourD4yNativeSearchResult, FourD4ySearchNativeClient } from '../../data/remote/FourD4ySearchNativeClient';
import { FourD4ySearchPostNativeResolver, FourD4ySearchPostResolveResult } from
  '../../data/remote/FourD4ySearchPostNativeResolver';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { FOUR_D4Y_FORUM_GROUPS, FourD4yForumGroup, getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { ForumSummary } from '../../domain/model/ForumModels';
import { FourD4ySearchHistoryEntry } from '../../domain/search/FourD4ySearchHistory';
import { FourD4ySearchFormPayload, FourD4ySearchMode, FourD4ySearchPagePayload,
  FourD4ySearchPostTargetPayload, FourD4ySearchReaderOutcome, FourD4ySearchThread,
  getFourD4ySearchReaderOutcome, isMeaningfulFourD4yFullTextResult,
  isAllowedFourD4ySearchPageUrl, isExpectedFourD4ySearchFormPayload,
  isExpectedFourD4ySearchPagePayload, isFourD4ySearchModeSupported,
  parseFourD4ySearchFormPayload } from '../../domain/search/FourD4ySearchContracts';
import { buildFourD4ySearchRequestUrl, buildFourD4yAuthorIdSearchRequestUrl } from
  '../../domain/search/FourD4ySearchRequest';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { SearchRouteParams } from './SearchRouteState';

/**
 * Native UI over the current server-rendered 4D4Y search form.
 *
 * The initial page is a value-free ArkWeb form preflight. Results use the
 * forum's native HTTP contract with an ephemeral ArkWeb cookie header, the
 * same session-bridging pattern already used by the native image uploader.
 */
@Component
export struct SearchPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @State keyword: string = '';
  @State selectedMode: FourD4ySearchMode = FourD4ySearchMode.Title;
  @State selectedForumId: string = 'all';
  @State isForumPickerVisible: boolean = false;
  @State history: FourD4ySearchHistoryEntry[] = [];
  @State threads: FourD4ySearchThread[] = [];
  @State currentPage: number = 1;
  @State lastPage: number = 1;
  @State previousPageUrl: string = '';
  @State nextPageUrl: string = '';
  @State isLoading: boolean = false;
  @State isResolvingPost: boolean = false;
  @State hasSearched: boolean = false;
  @State filteredResultCount: number = 0;
  @State statusMessage: string = '正在读取 4D4Y 搜索能力…';

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private readonly nativeSearchClient: FourD4ySearchNativeClient = new FourD4ySearchNativeClient();
  private readonly nativePostResolver: FourD4ySearchPostNativeResolver = new FourD4ySearchPostNativeResolver();
  private isWebControllerAttached: boolean = false;
  private readonly forums: ForumSummary[] = getFourD4yForums();
  private readonly forumGroups: FourD4yForumGroup[] = FOUR_D4Y_FORUM_GROUPS;
  private searchForm: FourD4ySearchFormPayload | null = null;
  private historyOperationSequence: number = 0;
  private activeSearchMode: FourD4ySearchMode = FourD4ySearchMode.Title;
  private activeSearchKeyword: string = '';
  private formProbeSequence: number = 0;
  private resultLoadSequence: number = 0;
  // Derived from the currently signed-in search form; it is never persisted.
  private viewerUserId: string = '';
  private terminalResultLoadSequence: number = 0;
  private isSubmittingSearch: boolean = false;
  private searchFormUrl: string = '';
  private resultLoadTimeoutId: number = -1;
  private formProbeTimeoutId: number = -1;
  private postResolveSequence: number = 0;
  private postResolveTimeoutId: number = -1;
  private readonly loadTimeoutMillis: number = 30000;
  private profileSearchUserId: string = '';
  @State profileSearchName: string = '';
  private pendingProfileSearch: boolean = false;
  private skipNextHistoryEntry: boolean = false;
  private isSearchAlive: boolean = false;

  aboutToAppear(): void {
    this.isSearchAlive = true;
    this.loadHistory();
    this.loadSearchForm();
  }

  aboutToDisappear(): void {
    this.isSearchAlive = false;
    this.formProbeSequence += 1;
    this.resultLoadSequence += 1;
    this.postResolveSequence += 1;
    this.clearResultLoadWatchdog();
    this.clearFormProbeWatchdog();
    this.clearPostResolveWatchdog();
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
          .onPageEnd((event) => {
            this.onSearchPageEnd(event.url);
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (!event.request.isMainFrame()) {
              return;
            }
            this.onSearchPageError(requestUrl);
          })
          .width(1)
          .height(1)
          .opacity(0)

        Column() {
          this.buildSearchControls();
          Divider().color($r('app.color.border'));
          this.buildSearchContent();
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface'))
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
    }
    .title(this.profileSearchName.length > 0 ? this.profileSearchName + '的帖子' : '搜索')
    .onReady((context: NavDestinationContext) => {
      const route: SearchRouteParams | null = context.pathInfo.param as SearchRouteParams | null;
      if (route !== null && route !== undefined && /^\d{1,20}$/.test(route.authorUserId)) {
        this.profileSearchUserId = route.authorUserId;
        this.profileSearchName = route.authorName;
        this.keyword = route.authorUserId;
        this.selectedMode = FourD4ySearchMode.Author;
        this.selectedForumId = 'all';
        this.pendingProfileSearch = true;
        this.startProfileSearchIfReady();
      }
    })
  }

  @Builder
  private buildSearchControls() {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: this.getKeywordPlaceholder(), text: this.keyword })
          .layoutWeight(1)
          .height(42)
          .backgroundColor($r('app.color.fill_subtle'))
          .borderRadius(6)
          .onChange((value: string) => {
            this.keyword = value;
          })
        Button(this.isLoading ? '搜索中…' : '搜索')
          .fontSize(14)
          .height(42)
          .enabled(!this.isLoading && !this.isResolvingPost)
          .onClick(() => {
            this.beginSearch();
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.buildModeButton(FourD4ySearchMode.Title, '标题');
        this.buildModeButton(FourD4ySearchMode.FullText, '全文');
        this.buildModeButton(FourD4ySearchMode.Author, '作者');
        Blank()
        Button(this.getSelectedForumName())
          .type(ButtonType.Normal)
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .height(32)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.isForumPickerVisible = true;
          })
          .bindSheet(this.isForumPickerVisible, this.buildForumPicker(), {
            height: 620,
            dragBar: true,
            showClose: true,
            onDisappear: () => {
              this.isForumPickerVisible = false;
            }
          })
      }
      .width('100%')

      if (this.statusMessage.length > 0 && !this.isLoading) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  }

  @Builder
  private buildModeButton(mode: FourD4ySearchMode, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.selectedMode === mode ? $r('app.color.on_brand') : $r('app.color.text_chip'))
      .backgroundColor(this.selectedMode === mode ? $r('app.color.brand_strong') : $r('app.color.fill_selected'))
      .borderRadius(16)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .onClick(() => {
        if (!this.isLoading) {
          this.selectedMode = mode;
        }
      })
  }

  @Builder
  private buildForumPicker() {
    Column({ space: 10 }) {
      Row() {
        Text('搜索版面')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('全部或单个版面')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })

      Button('全部版面')
        .fontSize(15)
        .fontColor(this.selectedForumId === 'all' ? $r('app.color.on_brand') : $r('app.color.text_primary'))
        .backgroundColor(this.selectedForumId === 'all' ? $r('app.color.brand_strong') : $r('app.color.fill_subtle'))
        .borderRadius(10)
        .width('100%')
        .height(42)
        .margin({ left: 20, right: 20 })
        .onClick(() => {
          this.selectedForumId = 'all';
          this.isForumPickerVisible = false;
        })

      Divider().color($r('app.color.border_light'))

      Scroll() {
        Column({ space: 18 }) {
          ForEach(this.forumGroups, (group: FourD4yForumGroup) => {
            this.buildForumGroup(group);
          }, (group: FourD4yForumGroup) => group.name)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private buildForumGroup(group: FourD4yForumGroup) {
    Column({ space: 8 }) {
      Text(group.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_detail'))
      ForEach(group.forums, (forum: ForumSummary) => {
        Button(forum.name)
          .fontSize(15)
          .fontColor(this.selectedForumId === forum.id ? $r('app.color.on_brand') : $r('app.color.text_primary'))
          .backgroundColor(this.selectedForumId === forum.id ? $r('app.color.brand_strong') : $r('app.color.fill_subtle'))
          .borderRadius(10)
          .width('100%')
          .height(42)
          .onClick(() => {
            this.selectedForumId = forum.id;
            this.isForumPickerVisible = false;
          })
      }, (forum: ForumSummary) => forum.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSearchContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在搜索 4D4Y…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.hasSearched && (this.threads.length > 0 || this.lastPage > 1)) {
      Column() {
        if (this.filteredResultCount > 0) {
          Text('已过滤 ' + this.filteredResultCount + ' 条仅由引用或链接命中的结果。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 20, right: 20, top: 10, bottom: 8 })
            .width('100%')
        }
        if (this.threads.length > 0) {
          List({ space: 0 }) {
            ForEach(this.threads, (thread: FourD4ySearchThread) => {
              ListItem() {
                this.buildSearchThread(thread);
              }
              .onClick(() => {
                this.openSearchThread(thread);
              })
            }, (thread: FourD4ySearchThread) => thread.postId.length > 0 ?
              'post:' + thread.postId : 'thread:' + thread.threadId)
          }
          .layoutWeight(1)
          .width('100%')
          .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
        } else {
          Column({ space: 8 }) {
            Text('本页结果均为引用或链接命中，已过滤。')
              .fontSize(15)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .padding(28)
          .width('100%')
        }
        this.buildPager();
      }
      .layoutWeight(1)
      .width('100%')
    } else if (this.hasSearched) {
      Column({ space: 12 }) {
        Text(this.statusMessage.length > 0 ? this.statusMessage :
          (this.filteredResultCount > 0 ? '结果仅命中引用或链接，已过滤。' : '未找到匹配主题。'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button('重新搜索')
          .enabled(!this.isLoading)
          .onClick(() => {
            this.beginSearch();
          })
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else {
      this.buildHistory();
    }
  }

  @Builder
  private buildSearchThread(thread: FourD4ySearchThread) {
    Column({ space: 5 }) {
      Text(thread.title)
        .fontSize(17)
        .fontColor($r('app.color.text_strong'))
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (thread.summary.length > 0) {
        Text(thread.summary)
          .fontSize(14)
          .fontColor($r('app.color.text_detail'))
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row() {
        Text(thread.forumName.length > 0 ? thread.forumName : '4D4Y')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (thread.authorName.length > 0) {
          Text(thread.authorName)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 10 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank()
        Text(thread.replyCount + ' 回复')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      if (thread.lastReplyAt.length > 0) {
        Text(thread.lastReplyAt)
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
        .fontColor(this.previousPageUrl.length > 0 ? $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(!this.isLoading && !this.isResolvingPost && this.previousPageUrl.length > 0)
        .onClick(() => {
          this.loadSearchPage(this.previousPageUrl);
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
        .fontColor(this.nextPageUrl.length > 0 ? $r('app.color.brand') : $r('app.color.text_muted'))
        .textAlign(TextAlign.Center)
        .width(64)
        .height(44)
        .enabled(!this.isLoading && !this.isResolvingPost && this.nextPageUrl.length > 0)
        .onClick(() => {
          this.loadSearchPage(this.nextPageUrl);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  @Builder
  private buildHistory() {
    Column({ space: 10 }) {
      Row() {
        Text('搜索历史')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        if (this.history.length > 0) {
          Text('清空')
            .fontSize(13)
            .fontColor($r('app.color.brand'))
            .height(36)
            .padding({ left: 12, right: 4 })
            .onClick(() => {
              this.clearHistory();
            })
        }
      }
      .width('100%')
      if (this.history.length === 0) {
        Text('输入关键词后可搜索标题、全文或作者；最近的搜索会保存在本机。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
      } else {
        List({ space: 0 }) {
          ForEach(this.history, (entry: FourD4ySearchHistoryEntry) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(entry.keyword)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(this.getHistoryDescription(entry))
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›')
                  .fontSize(24)
                  .fontColor($r('app.color.text_muted'))
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
            .onClick(() => {
              this.runHistorySearch(entry);
            })
          }, (entry: FourD4ySearchHistoryEntry) => entry.mode + ':' + entry.forumId + ':' + entry.keyword)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border_subtle') })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 12 })
  }

  private onWebControllerAttached(): void {
    this.isWebControllerAttached = true;
    try {
      this.webController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.searchFormUrl.length > 0) {
        this.webController.loadUrl(this.searchFormUrl);
      }
    } catch (_error) {
      this.statusMessage = '暂时无法初始化 4D4Y 搜索会话。';
    }
  }

  private loadSearchForm(): void {
    if (!this.isSearchAlive) {
      return;
    }
    this.formProbeSequence += 1;
    const probeSequence: number = this.formProbeSequence;
    this.searchForm = null;
    this.viewerUserId = '';
    this.searchFormUrl = FourD4ySession.forumRoot + 'search.php?oh_search_form=' + probeSequence;
    this.statusMessage = '正在读取 4D4Y 搜索能力…';
    this.startFormProbeWatchdog(probeSequence);
    if (!this.isWebControllerAttached) {
      return;
    }
    try {
      this.webController.loadUrl(this.searchFormUrl);
    } catch (_error) {
      this.failFormProbe(probeSequence, '暂时无法打开 4D4Y 搜索页，请检查网络后重试。');
    }
  }

  private onSearchPageEnd(url: string): void {
    if (this.isCurrentSearchFormRequest(url) && !this.isSubmittingSearch && !this.isLoading) {
      this.readSearchFormFromWeb();
    }
  }

  private onSearchPageError(url: string): void {
    if (this.isCurrentSearchFormRequest(url) && !this.isSubmittingSearch) {
      this.failFormProbe(this.formProbeSequence, '暂时无法读取 4D4Y 搜索表单，请检查网络后重试。');
      return;
    }
  }

  private async readSearchFormFromWeb(): Promise<void> {
    const expectedProbeSequence: number = this.formProbeSequence;
    try {
      const rawResult: string = await this.webController.runJavaScript(
        this.getSearchFormExtractionScript(expectedProbeSequence));
      if (expectedProbeSequence !== this.formProbeSequence || this.isSubmittingSearch) {
        return;
      }
      const payload: FourD4ySearchFormPayload | null = parseFourD4ySearchFormPayload(rawResult);
      if (payload === null || !isExpectedFourD4ySearchFormPayload(payload, expectedProbeSequence)) {
        this.failFormProbe(expectedProbeSequence, '4D4Y 搜索页已打开，但表单结构无法确认。');
        return;
      }
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.isLoggedIn = false;
        this.failFormProbe(expectedProbeSequence, '4D4Y 登录状态已失效，请重新登录后再搜索。');
        return;
      }
      if (!payload.formFound || !payload.hasSubmitControl) {
        this.failFormProbe(expectedProbeSequence, payload.hasChallenge ?
          '请先完成 4D4Y 安全验证后再搜索。' :
          (payload.errorMessage.length > 0 ? payload.errorMessage : '当前 4D4Y 搜索表单暂未适配。'));
        return;
      }
      this.clearFormProbeWatchdog();
      this.searchForm = payload;
      this.viewerUserId = payload.viewerUserId;
      this.statusMessage = this.getSearchFormReadyMessage(payload);
      this.startProfileSearchIfReady();
    } catch (_error) {
      this.failFormProbe(expectedProbeSequence, '暂时无法读取 4D4Y 搜索表单，请检查网络后重试。');
    }
  }

  private async beginSearch(): Promise<void> {
    if (!this.isSearchAlive) {
      return;
    }
    const normalizedKeyword: string = this.keyword.trim();
    if (this.isLoading) {
      return;
    }
    if (normalizedKeyword.length === 0) {
      this.statusMessage = this.selectedMode === FourD4ySearchMode.Author ? '请输入用户名或 UID。' : '请输入搜索关键词。';
      return;
    }
    if (normalizedKeyword.length > 120) {
      this.statusMessage = '搜索内容不能超过 120 个字符。';
      return;
    }
    if (this.searchForm === null) {
      this.statusMessage = '正在校验 4D4Y 搜索表单，请稍后重试。';
      this.loadSearchForm();
      return;
    }
    if (!isFourD4ySearchModeSupported(this.searchForm, this.selectedMode, normalizedKeyword)) {
      this.statusMessage = this.getUnsupportedSearchModeMessage(this.searchForm);
      return;
    }
    const loadSequence: number = this.resultLoadSequence + 1;
    this.resultLoadSequence = loadSequence;
    this.terminalResultLoadSequence = 0;
    this.isLoading = true;
    this.isSubmittingSearch = false;
    this.hasSearched = true;
    this.threads = [];
    this.filteredResultCount = 0;
    this.currentPage = 1;
    this.lastPage = 1;
    this.previousPageUrl = '';
    this.nextPageUrl = '';
    this.statusMessage = '';
    this.startResultLoadWatchdog(loadSequence);
    if (this.skipNextHistoryEntry) {
      this.skipNextHistoryEntry = false;
    } else {
      this.addHistory({ keyword: normalizedKeyword, mode: this.selectedMode, forumId: this.selectedForumId });
    }
    const searchUrl: string | null = this.selectedMode === FourD4ySearchMode.Author &&
      this.profileSearchUserId.length > 0 && normalizedKeyword === this.profileSearchUserId ?
      buildFourD4yAuthorIdSearchRequestUrl(FourD4ySession.forumRoot, this.profileSearchUserId,
        this.selectedForumId) : buildFourD4ySearchRequestUrl(FourD4ySession.forumRoot,
        this.searchForm, this.selectedMode, normalizedKeyword, this.selectedForumId);
    if (searchUrl === null) {
      this.failSearchLoad(loadSequence, '当前 4D4Y 搜索请求无法按已验证的 GBK 契约编码。');
      return;
    }
    if (!/^\d+$/.test(this.viewerUserId)) {
      this.failSearchLoad(loadSequence, '当前 4D4Y 登录上下文无法确认，请重新登录后重试。');
      return;
    }
    this.activeSearchMode = this.selectedMode;
    this.activeSearchKeyword = normalizedKeyword;
    this.loadNativeSearchResults(searchUrl, loadSequence);
  }

  private startProfileSearchIfReady(): void {
    if (!this.pendingProfileSearch || this.searchForm === null || this.profileSearchUserId.length === 0) {
      return;
    }
    this.pendingProfileSearch = false;
    this.skipNextHistoryEntry = true;
    void this.beginSearch();
  }

  private loadSearchPage(url: string): void {
    if (!this.isSearchAlive || this.isLoading || !isAllowedFourD4ySearchPageUrl(url)) {
      return;
    }
    const loadSequence: number = this.resultLoadSequence + 1;
    this.resultLoadSequence = loadSequence;
    this.terminalResultLoadSequence = 0;
    this.isLoading = true;
    this.isSubmittingSearch = false;
    this.filteredResultCount = 0;
    this.statusMessage = '';
    this.startResultLoadWatchdog(loadSequence);
    if (!/^\d+$/.test(this.viewerUserId)) {
      this.failSearchLoad(loadSequence, '当前 4D4Y 登录上下文无法确认，请重新登录后重试。');
      return;
    }
    this.loadNativeSearchResults(url, loadSequence);
  }

  private async loadNativeSearchResults(url: string, expectedLoadSequence: number): Promise<void> {
    try {
      const result: FourD4yNativeSearchResult = await this.nativeSearchClient.load(
        url, expectedLoadSequence, this.viewerUserId);
      if (this.isResultLoadTerminal(expectedLoadSequence) || expectedLoadSequence !== this.resultLoadSequence) {
        return;
      }
      if (result.status === 'cookie-missing') {
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence,
          '网页登录已通过，但原生搜索没有取得认证 Cookie，请返回登录页刷新状态后重试。');
        return;
      }
      if (result.status === 'user-context-missing') {
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence,
          '搜索表单已打开，但没有识别到当前账号 UID，请返回登录页刷新状态后重试。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence, '4D4Y 服务器拒绝了本次搜索会话，请重新登录后再搜索。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failSearchLoad(expectedLoadSequence, '暂时无法加载 4D4Y 搜索结果，请检查网络后重试。');
        return;
      }
      const payload: FourD4ySearchPagePayload | null = result.payload;
      if (result.status !== 'success' || payload === null ||
        !isExpectedFourD4ySearchPagePayload(payload, expectedLoadSequence)) {
        this.failSearchLoad(expectedLoadSequence, '4D4Y 搜索结果已返回，但页面结构暂未适配。');
        return;
      }
      const outcome: FourD4ySearchReaderOutcome = getFourD4ySearchReaderOutcome(payload);
      if (outcome === FourD4ySearchReaderOutcome.LoginRequired) {
        this.isLoggedIn = false;
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence, '4D4Y 登录状态已失效，请重新登录后再搜索。');
        return;
      }
      if (outcome === FourD4ySearchReaderOutcome.VerificationRequired) {
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence, '请先完成 4D4Y 安全验证后再搜索。');
        return;
      }
      if (outcome === FourD4ySearchReaderOutcome.UnsupportedLayout) {
        this.threads = [];
        this.failSearchLoad(expectedLoadSequence, payload.errorMessage.length > 0 ? payload.errorMessage :
          '当前 4D4Y 搜索结果结构暂未适配。');
        return;
      }
      const visibleThreads: FourD4ySearchThread[] = this.activeSearchMode === FourD4ySearchMode.FullText ?
        payload.threads.filter((thread: FourD4ySearchThread) =>
          isMeaningfulFourD4yFullTextResult(thread, this.activeSearchKeyword)) : payload.threads;
      this.filteredResultCount = payload.threads.length - visibleThreads.length;
      this.threads = visibleThreads;
      this.currentPage = payload.page;
      this.lastPage = Math.max(payload.page, payload.lastPage);
      this.previousPageUrl = payload.previousPageUrl;
      this.nextPageUrl = payload.nextPageUrl;
      this.isSubmittingSearch = false;
      this.finishSearchLoad(expectedLoadSequence);
      this.statusMessage = outcome === FourD4ySearchReaderOutcome.Empty ?
        (payload.errorMessage.length > 0 ? payload.errorMessage : '未找到匹配主题。') :
        (visibleThreads.length === 0 && this.filteredResultCount > 0 ?
          '本页结果仅命中引用或链接，已过滤。' : '');
    } catch (_error) {
      if (expectedLoadSequence === this.resultLoadSequence && !this.isResultLoadTerminal(expectedLoadSequence)) {
        this.failSearchLoad(expectedLoadSequence, '暂时无法读取搜索结果，请检查网络后重试。');
      }
    }
  }

  private async loadHistory(): Promise<void> {
    const sequence: number = this.historyOperationSequence;
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        return;
      }
      const entries: FourD4ySearchHistoryEntry[] = await FourD4ySearchHistoryStore.load(hostContext);
      if (!this.isSearchAlive || sequence !== this.historyOperationSequence) {
        return;
      }
      this.history = entries;
    } catch (_error) {
      // Search remains available if local history cannot be opened.
    }
  }

  private addHistory(entry: FourD4ySearchHistoryEntry): void {
    void this.persistHistory(entry);
  }

  private clearHistory(): void {
    void this.persistHistory();
  }

  private async persistHistory(entry?: FourD4ySearchHistoryEntry): Promise<void> {
    if (!this.isSearchAlive) {
      return;
    }
    const sequence: number = ++this.historyOperationSequence;
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        throw new Error('search-history-context-unavailable');
      }
      const entries: FourD4ySearchHistoryEntry[] = entry === undefined ?
        await FourD4ySearchHistoryStore.clear(hostContext) : await FourD4ySearchHistoryStore.record(hostContext, entry);
      if (this.isSearchAlive && sequence === this.historyOperationSequence) {
        this.history = entries;
      }
    } catch (_error) {
      // A storage failure must never block a read-only server search.
      if (this.isSearchAlive && sequence === this.historyOperationSequence) {
        try {
          this.getUIContext().getPromptAction().showToast({
            message: entry === undefined ? '清空搜索历史失败，请重试。' : '本次搜索历史未保存；不影响搜索结果。'
          });
        } catch (_toastError) {
          // Feedback failure must not turn history persistence into an unhandled rejection.
        }
      }
    }
  }

  private runHistorySearch(entry: FourD4ySearchHistoryEntry): void {
    if (this.isLoading) {
      return;
    }
    this.keyword = entry.keyword;
    this.selectedMode = entry.mode;
    this.selectedForumId = entry.forumId;
    this.beginSearch();
  }

  private openSearchThread(thread: FourD4ySearchThread): void {
    if (this.isResolvingPost) {
      return;
    }
    if (thread.postId.length > 0) {
      this.resolveSearchPost(thread);
      return;
    }
    if (!/^\d+$/.test(thread.threadId)) {
      this.statusMessage = '这条搜索结果没有可确认的主题地址。';
      return;
    }
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
      thread.threadId, thread.title, thread.replyCount, 1, 0, thread.forumId));
  }

  private async resolveSearchPost(thread: FourD4ySearchThread): Promise<void> {
    const resolveSequence: number = this.postResolveSequence + 1;
    if (!/^\d+$/.test(thread.postId)) {
      this.statusMessage = '这条全文搜索结果没有可确认的帖子地址。';
      return;
    }
    this.postResolveSequence = resolveSequence;
    this.isResolvingPost = true;
    this.statusMessage = '正在定位命中的具体楼层…';
    this.startPostResolveWatchdog(resolveSequence);
    try {
      const result: FourD4ySearchPostResolveResult = await this.nativePostResolver.resolve(
        thread.threadId, thread.postId, resolveSequence, this.viewerUserId);
      if (!this.isResolvingPost || resolveSequence !== this.postResolveSequence) {
        return;
      }
      if (result.status === 'cookie-missing' || result.status === 'user-context-missing') {
        this.failPostResolution('当前 4D4Y 登录上下文无法确认，请重新登录后再打开全文结果。');
        return;
      }
      if (result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.failPostResolution('4D4Y 登录状态已失效，请重新登录后再打开全文结果。');
        return;
      }
      if (result.status === 'request-failed') {
        this.failPostResolution('暂时无法定位这条全文搜索结果，请检查网络后重试。');
        return;
      }
      const payload: FourD4ySearchPostTargetPayload | null = result.payload;
      if (result.status === 'unsupported-response' || payload === null) {
        this.failPostResolution('全文结果已返回，但论坛的帖子定位结构暂未适配。');
        return;
      }
      if (result.status === 'post-unavailable' || !payload.postFound || !/^\d+$/.test(payload.threadId)) {
        this.failPostResolution(payload.errorMessage.length > 0 ? payload.errorMessage :
          '该搜索结果已被删除、移入无权访问的版面，或暂时不可用。');
        return;
      }
      this.clearPostResolveWatchdog();
      this.isResolvingPost = false;
      this.statusMessage = '';
      const title: string = payload.title.length > 0 ? payload.title : thread.title;
      this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
        payload.threadId, title, 0, payload.page, payload.floor, thread.forumId, false, 1, thread.postId));
    } catch (_error) {
      if (this.isResolvingPost && resolveSequence === this.postResolveSequence) {
        this.failPostResolution('暂时无法读取这条全文搜索结果，请稍后重试。');
      }
    }
  }

  private startPostResolveWatchdog(resolveSequence: number): void {
    this.clearPostResolveWatchdog();
    this.postResolveTimeoutId = setTimeout(() => {
      if (this.isResolvingPost && resolveSequence === this.postResolveSequence) {
        this.failPostResolution('定位全文搜索结果超时，请稍后重试。');
      }
    }, this.loadTimeoutMillis);
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

  private getSelectedForumName(): string {
    if (this.selectedForumId === 'all') {
      return '全部版面';
    }
    const forum: ForumSummary | undefined = this.forums.find((item: ForumSummary) =>
      item.id === this.selectedForumId);
    return forum === undefined ? '全部版面' : forum.name;
  }

  private getKeywordPlaceholder(): string {
    return this.selectedMode === FourD4ySearchMode.Author ? '用户名或 UID' : '输入关键词';
  }

  private getHistoryDescription(entry: FourD4ySearchHistoryEntry): string {
    const modeLabel: string = entry.mode === FourD4ySearchMode.Title ? '标题' :
      (entry.mode === FourD4ySearchMode.FullText ? '全文' : '作者');
    if (entry.forumId === 'all') {
      return modeLabel + ' · 全部版面';
    }
    const forum: ForumSummary | undefined = this.forums.find((item: ForumSummary) => item.id === entry.forumId);
    return modeLabel + ' · ' + (forum === undefined ? '全部版面' : forum.name);
  }

  private getSearchFormReadyMessage(payload: FourD4ySearchFormPayload): string {
    const capabilities: string[] = [];
    if (payload.hasKeywordField && payload.searchTypes.indexOf(FourD4ySearchMode.Title) >= 0) {
      capabilities.push('标题');
    }
    // Current 4D4Y does not advertise fulltext in the form controls. NG and
    // MY 4D4Y both expose it through the verified keyword/search.php path.
    if (payload.hasKeywordField) {
      capabilities.push('全文');
    }
    if (payload.hasAuthorNameField || payload.hasAuthorIdField) {
      capabilities.push('作者');
    }
    return capabilities.length > 0 ? '已就绪：可搜索' + capabilities.join('、') + '。' :
      '搜索表单已读取，但当前未发现可用筛选项。';
  }

  private getUnsupportedSearchModeMessage(payload: FourD4ySearchFormPayload): string {
    if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
      return '4D4Y 登录状态已失效，请重新登录后再搜索。';
    }
    if (this.selectedMode === FourD4ySearchMode.Author) {
      return '当前 4D4Y 搜索表单未提供按作者搜索。';
    }
    return this.selectedMode === FourD4ySearchMode.FullText ?
      '当前 4D4Y 搜索表单未提供全文搜索。' : '当前 4D4Y 搜索表单未提供标题搜索。';
  }

  private isCurrentSearchFormRequest(url: string): boolean {
    const token: RegExp = new RegExp('[?&]oh_search_form=' + this.formProbeSequence + '(?:&|$)');
    return url.indexOf('/forum/search.php') >= 0 && token.test(url);
  }

  private startFormProbeWatchdog(probeSequence: number): void {
    this.clearFormProbeWatchdog();
    this.formProbeTimeoutId = setTimeout(() => {
      if (probeSequence === this.formProbeSequence && this.searchForm === null && !this.isSubmittingSearch) {
        this.failFormProbe(probeSequence, '读取 4D4Y 搜索表单超时，请重试。');
        try {
          this.webController.stop();
        } catch (_error) {
          // The page may have completed while this timeout was queued.
        }
      }
    }, this.loadTimeoutMillis);
  }

  private clearFormProbeWatchdog(): void {
    if (this.formProbeTimeoutId >= 0) {
      clearTimeout(this.formProbeTimeoutId);
      this.formProbeTimeoutId = -1;
    }
  }

  private failFormProbe(probeSequence: number, message: string): void {
    if (probeSequence !== this.formProbeSequence) {
      return;
    }
    this.clearFormProbeWatchdog();
    this.searchForm = null;
    this.statusMessage = message;
  }

  private startResultLoadWatchdog(loadSequence: number): void {
    this.clearResultLoadWatchdog();
    this.resultLoadTimeoutId = setTimeout(() => {
      if (loadSequence === this.resultLoadSequence && !this.isResultLoadTerminal(loadSequence)) {
        this.failSearchLoad(loadSequence, '读取搜索结果超时，请重试。');
      }
    }, this.loadTimeoutMillis);
  }

  private clearResultLoadWatchdog(): void {
    if (this.resultLoadTimeoutId >= 0) {
      clearTimeout(this.resultLoadTimeoutId);
      this.resultLoadTimeoutId = -1;
    }
  }

  private isResultLoadTerminal(loadSequence: number = this.resultLoadSequence): boolean {
    return this.terminalResultLoadSequence === loadSequence;
  }

  private finishSearchLoad(loadSequence: number): void {
    if (loadSequence !== this.resultLoadSequence) {
      return;
    }
    this.clearResultLoadWatchdog();
    this.terminalResultLoadSequence = loadSequence;
    this.isLoading = false;
  }

  private failSearchLoad(loadSequence: number, message: string): void {
    if (loadSequence !== this.resultLoadSequence) {
      return;
    }
    this.isSubmittingSearch = false;
    this.finishSearchLoad(loadSequence);
    this.statusMessage = message;
  }

  private getSearchFormExtractionScript(probeSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => { try { const action = new URL(candidate.getAttribute("action") || location.href, location.href); return action.pathname === "/forum/search.php"; } catch (_) { return false; } });',
      '  const elements = form ? Array.from(form.elements || []) : [];',
      '  const named = (name) => elements.filter((node) => (node.getAttribute("name") || "") === name);',
      '  const values = (name) => { const result = []; named(name).forEach((node) => { const tag = (node.tagName || "").toLowerCase(); if (tag === "select") { Array.from(node.options || []).forEach((option) => result.push(option.value || "")); } else { result.push(node.value || ""); } }); return Array.from(new Set(result)); };',
      '  let actionPath = "";',
      '  try { actionPath = form ? new URL(form.getAttribute("action") || location.href, location.href).pathname : ""; } catch (_) {}',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  const currentUserLink = document.querySelector("#umenu > cite > a[href], #umenu cite a[href]");',
      '  const currentUserHref = currentUserLink ? (currentUserLink.getAttribute("href") || "") : "";',
      '  const currentUserMatch = /(?:[?&]uid=|uid-)([0-9]+)/.exec(currentUserHref);',
      '  const pageScriptText = Array.from(document.scripts || []).map((script) => script.textContent || "").join("\\n");',
      '  const scriptUserMatch = /(?:^|[;\\s])discuz_uid\\s*=\\s*["\\\']?([0-9]+)/i.exec(pageScriptText);',
      '  return JSON.stringify({',
      '    probeSequence: ' + probeSequence + ',',
      '    viewerUserId: currentUserMatch ? currentUserMatch[1] : (scriptUserMatch ? scriptUserMatch[1] : ""),',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, formMethod: form ? (form.getAttribute("method") || "get").toLowerCase() : "", actionPath: actionPath,',
      '    hasKeywordField: named("srchtxt").length > 0, searchTypes: values("srchtype").filter((value) => value === "title" || value === "fulltext"),',
      '    hasAuthorNameField: named("srchuname").length > 0, hasAuthorIdField: named("srchuid").length > 0,',
      '    hasForumFilter: named("srchfid[0]").length > 0 || named("srchfid[]").length > 0 || named("srchfid").length > 0, forumFieldName: named("srchfid[0]").length > 0 ? "srchfid[0]" : (named("srchfid[]").length > 0 ? "srchfid[]" : (named("srchfid").length > 0 ? "srchfid" : "")), hasSubmitControl: named("searchsubmit").length > 0,',
      '    errorMessage: text(alert).slice(0, 180)',
      '  });',
      '})()'
    ].join('\n');
  }

  private getSearchResultExtractionScript(loadSequence: number): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const safeUrl = (node) => { try { const value = new URL(node.getAttribute("href") || "", location.href); return value.origin === location.origin && value.pathname === "/forum/search.php" ? value.href : ""; } catch (_) { return ""; } };',
      '  const readThreadId = (node) => { try { const value = new URL(node.getAttribute("href") || "", location.href); const direct = value.searchParams.get("tid") || ""; if (/^\\d+$/.test(direct)) return direct; const match = /thread-(\\d+)-/.exec(value.pathname); return match ? match[1] : ""; } catch (_) { return ""; } };',
      '  const readForumId = (node) => { try { const value = new URL(node ? (node.getAttribute("href") || "") : "", location.href); const fid = value.searchParams.get("fid") || ""; return /^\\d+$/.test(fid) ? fid : ""; } catch (_) { return ""; } };',
      '  const seen = new Set(); const threads = [];',
      '  const rows = Array.from(document.querySelectorAll("table.datatable tbody tr, table.datatable tr, #threadlisttableid tbody tr, #threadlisttableid tr"));',
      '  rows.forEach((row) => {',
      '    const threadLink = row.querySelector("a[href*=viewthread], a[href*=thread-]");',
      '    if (!threadLink) return;',
      '    const threadId = readThreadId(threadLink); if (!/^\\d+$/.test(threadId) || seen.has(threadId)) return;',
      '    const forumCell = row.querySelector("td.forum, .forum"); const forumLink = forumCell ? forumCell.querySelector("a[href]") : null;',
      '    const authorCell = row.querySelector("td.author, .author"); const repliesCell = row.querySelector("td.nums, .nums, td:nth-last-child(2)"); const lastPostCell = row.querySelector("td.lastpost, .lastpost");',
      '    const replyMatch = /\\d+/.exec(text(repliesCell));',
      '    const title = text(threadLink).slice(0, 240); if (!title) return;',
      '    seen.add(threadId); threads.push({ threadId: threadId, forumId: readForumId(forumLink), title: title, forumName: text(forumCell).slice(0, 80), authorName: text(authorCell).slice(0, 80), replyCount: replyMatch ? Number.parseInt(replyMatch[0], 10) : 0, lastReplyAt: text(lastPostCell).slice(0, 140) });',
      '  });',
      '  const pages = Array.from(document.querySelectorAll("div.pages a, div.pages strong, .pg a, .pg strong"));',
      '  let page = 1; let lastPage = 1; let previousPageUrl = ""; let nextPageUrl = "";',
      '  pages.forEach((node) => { const label = text(node); const value = /^\\d+$/.test(label) ? Number.parseInt(label, 10) : 0; if (node.tagName === "STRONG" && value > 0) page = value; if (value > lastPage) lastPage = value; const href = safeUrl(node); const lower = label.toLowerCase(); if (href && (label === "上一页" || lower === "prev" || label === "‹" || label === "«")) previousPageUrl = href; if (href && (label === "下一页" || lower === "next" || label === "›" || label === "»")) nextPageUrl = href; });',
      '  if (!previousPageUrl) { const node = Array.from(document.querySelectorAll("a[href]")).find((item) => /(?:上一页|prev|‹|«)/i.test(text(item)) && safeUrl(item)); if (node) previousPageUrl = safeUrl(node); }',
      '  if (!nextPageUrl) { const node = Array.from(document.querySelectorAll("a[href]")).find((item) => /(?:下一页|next|›|»)/i.test(text(item)) && safeUrl(item)); if (node) nextPageUrl = safeUrl(node); }',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message, .notice");',
      '  const resultLayoutFound = rows.length > 0 || !!document.querySelector(".pages, .pg, #threadlisttableid") || (!!document.querySelector("form[action*=search]") && !!alert);',
      '  const locationInfo = new URL(location.href);',
      '  const searchForm = Array.from(document.forms || []).find((candidate) => { try { return new URL(candidate.getAttribute("action") || location.href, location.href).pathname === "/forum/search.php"; } catch (_) { return false; } });',
      '  const searchDebug = { path: locationInfo.pathname, queryKeys: Array.from(locationInfo.searchParams.keys()).sort().join(","), tableRows: rows.length, threadLinks: document.querySelectorAll("a[href*=viewthread], a[href*=thread-]").length, mobileRows: document.querySelectorAll(".listcon, .thread, li[id^=normalthread_]").length, dataTables: document.querySelectorAll("table.datatable, #threadlisttableid").length, searchFormMethod: searchForm ? (searchForm.getAttribute("method") || "get").toLowerCase() : "", alert: text(alert).slice(0, 180) };',
      '  return JSON.stringify({ loadSequence: ' + loadSequence + ', page: page, lastPage: Math.max(page, lastPage), accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge, resultLayoutFound: resultLayoutFound, previousPageUrl: previousPageUrl, nextPageUrl: nextPageUrl, errorMessage: text(alert).slice(0, 180), threads: threads, searchDebug: searchDebug });',
      '})()'
    ].join('\n');
  }
}
