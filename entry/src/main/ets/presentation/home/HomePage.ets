import { ForumSummary, ThreadSummary } from '../../domain/model/ForumModels';
import { FourD4yRowVersions } from '../common/FourD4yRowVersions';
import { buildFourD4yEmptyForumScript, buildFourD4yForumFilterQuery, buildFourD4yForumNavigationScript, retainSelectedFourD4yForumType } from '../../domain/reader/FourD4yForumFilter';
import { FourD4yPageAccessState, FourD4yReaderOutcome, ForumNewThreadPreflightPayload, ForumThreadType, ForumWebPayload, getForumReaderOutcome, isCurrentFourD4yWebRequest, isExpectedForumNewThreadPreflightPayload, isExpectedForumWebPayload, isReadyForumNewThreadForm, parseForumNewThreadPreflightPayload, parseForumWebPayload, WebThreadSummary } from '../../domain/reader/FourD4yReaderContracts';
import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { createThreadRouteParams } from '../thread/ThreadRouteState';
import { createNewThreadComposerRouteParams, ForumComposerThreadPublishedResult,
  isForumComposerThreadPublishedResult } from '../composer/ForumComposerRouteState';
import { FOUR_D4Y_FORUM_GROUPS, FOUR_D4Y_QUICK_FORUM_IDS, FourD4yForumGroup, getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { FourD4yUserSettingsStore } from '../../data/local/FourD4yUserSettingsStore';
import { common } from '@kit.AbilityKit';
import { FourD4yAccountProfileStore } from '../../data/local/FourD4yAccountProfileStore';
import { FourD4yAccountProfile } from '../../domain/account/FourD4yAccountContracts';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { createMyContentRouteParams } from '../mine/MyContentRouteState';
import { createMessageCenterRouteParams } from '../notice/MessageCenterRouteState';
import { FourD4yMessageMode } from '../../domain/notice/FourD4yMessageContracts';
import { FourD4yMessageNativeClient, FourD4yNativeMessagePromptResult } from
  '../../data/remote/FourD4yMessageNativeClient';
import { FourD4yMessagePromptPayload, isExpectedFourD4yMessagePromptPayload } from
  '../../domain/notice/FourD4yMessageContracts';
import { FourD4yUnreadState } from '../../domain/notice/FourD4yUnreadState';
import { FourD4yMyContentMode } from '../../domain/mine/FourD4yMyContentContracts';
import { appendUniqueFourD4yForumThreads } from '../../domain/reader/FourD4yForumPagination';
import { createDefaultFourD4yUserSettings, FOUR_D4Y_FONT_SCALES, FOUR_D4Y_POST_LINE_SPACINGS,
  FourD4yThemeMode, FourD4yUserSettings, normalizeFourD4yUserSettings } from
  '../../domain/settings/FourD4yUserSettings';
import { FourD4yLastForumStore } from '../../data/local/FourD4yLastForumStore';
import { resolveFourD4yHomeForumId } from '../../domain/navigation/FourD4yHomeForumState';
import { isQualifiedFourD4yRightSwipe } from '../../domain/navigation/FourD4yHorizontalGesture';
import { formatFourD4yThreadCount, formatFourD4yThreadCreatedDate } from '../../domain/thread/FourD4yThreadDate';
import { FourD4yObservedReplyCounts } from '../../domain/thread/FourD4yObservedReplyCounts';
import { FourD4yThreadDeletionEvent, FourD4yThreadMutationState } from '../../domain/thread/FourD4yThreadMutationState';

enum HomeAppearanceSheetMode {
  Typography = 'typography',
  Theme = 'theme'
}

@Component
export struct HomePage {
  @Consume('pathStack') pathStack: NavPathStack;
  @StorageLink('fourD4yForegroundGeneration') @Watch('onForegroundGenerationChanged')
  appForegroundGeneration: number = 0;
  @State activeTab: number = 0;
  @State selectedForumIndex: number = 0;
  @State threads: ThreadSummary[] = [];
  private readonly threadRowVersions: FourD4yRowVersions<ThreadSummary> =
    new FourD4yRowVersions<ThreadSummary>((thread: ThreadSummary): string => thread.id);
  /** Types from the active board's top-level `.threadtype` navigation. */
  @State currentForumThreadTypes: ForumThreadType[] = [];
  @State selectedForumTypeId: string = '';
  @State selectedForumTypeLabel: string = '';
  @State currentForumPage: number = 1;
  @State nextForumPage: number = 0;
  @State isLoading: boolean = false;
  /** True while native Refresh is reloading page 1 without hiding the list. */
  @State isRefreshing: boolean = false;
  /** True only while the next server-confirmed board page is being appended. */
  @State isLoadingMore: boolean = false;
  @State loadError: string = '';
  @State loadMoreError: string = '';
  // Do not assign a Web source until its controller has installed the forum
  // identity.  4D4Y makes a different session decision for its mobile page.
  @State forumPageUrl: string = '';
  @State needsWebVerification: boolean = false;
  @State isForumPickerVisible: boolean = false;
  @State isTopicPermissionProbePending: boolean = false;
  @State canCreateTopicInCurrentForum: boolean = false;
  @State topicPermissionMessage: string = '';
  @State quickForumIds: string[] = [...FOUR_D4Y_QUICK_FORUM_IDS];
  @State isMainDrawerOpen: boolean = false;
  @State isAllDrawerForumsVisible: boolean = false;
  @State drawerAccountName: string = '';
  @State drawerAccountUserId: string = '';
  @State drawerSettings: FourD4yUserSettings = createDefaultFourD4yUserSettings();
  @State isAppearanceSheetVisible: boolean = false;
  @State appearanceSheetMode: HomeAppearanceSheetMode = HomeAppearanceSheetMode.Typography;
  @State isAppearanceSaving: boolean = false;
  @State appearanceStatus: string = '';
  @State isForumListPreferenceSaving: boolean = false;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('unreadState') unreadState: FourD4yUnreadState;
  @Consume('observedReplyCounts') observedReplyCounts: FourD4yObservedReplyCounts;
  @Consume('accountState') accountState: FourD4yAccountState;
  @Consume('threadMutationState') threadMutationState: FourD4yThreadMutationState;
  @State observedReplyCountRevision: number = 0;
  @State privateMessageUnreadCount: number = 0;
  @State informationReminderUnreadCount: number = 0;

  private readonly forumWebController: webview.WebviewController = new webview.WebviewController();
  private isForumWebControllerAttached: boolean = false;
  private readonly topicPermissionWebController: webview.WebviewController = new webview.WebviewController();
  private isTopicPermissionWebControllerAttached: boolean = false;
  private readonly tabs: string[] = ['首页', '板块', '收藏', '我的'];
  private readonly forums: ForumSummary[] = getFourD4yForums();
  private readonly forumGroups: FourD4yForumGroup[] = FOUR_D4Y_FORUM_GROUPS;
  private webLoadSequence: number = 0;
  private requestedForumPage: number = 1;
  private readonly webLoadTimeoutMillis: number = 30000;
  private webLoadTimeoutId: number = -1;
  private terminalLoadSequence: number = 0;
  /** The active Web request's presentation mode; stale callbacks are rejected by sequence. */
  private isAppendingForumPage: boolean = false;
  private topicPermissionProbeSequence: number = 0;
  private topicPermissionProbeForumId: string = '';
  private topicPermissionProbeUrl: string = '';
  private topicPermissionTimeoutId: number = -1;
  /**
   * A recognised drawer pan and a ListItem click can both finish on the same
   * pointer-up when they are deliberately observed in parallel. Remember the
   * pan briefly so that releasing over a long title cannot open that thread.
   */
  private isDrawerSwipeGestureActive: boolean = false;
  private suppressThreadOpenUntilMillis: number = 0;
  /** Fixed slightly-over-half width leaves enough room for Chinese labels on phones. */
  private readonly mainDrawerWidth: number = 224;
  private readonly messageClient: FourD4yMessageNativeClient = new FourD4yMessageNativeClient();
  private unreadPromptSequence: number = 0;
  private isUnreadPromptLoading: boolean = false;
  private unreadStateListenerId: number = -1;
  private observedReplyCountListenerId: number = -1;
  private threadDeletionListenerId: number = -1;
  private lastObservedForegroundGeneration: number = 0;
  private isHomeAlive: boolean = false;

  aboutToAppear(): void {
    this.isHomeAlive = true;
    webview.WebviewController.setWebDebuggingAccess(false);
    this.subscribeUnreadState();
    this.subscribeObservedReplyCounts();
    this.threadDeletionListenerId = this.threadMutationState.subscribeDeletion(
      (event: FourD4yThreadDeletionEvent) => this.onConfirmedThreadDeletion(event));
    void this.restoreHomeSettingsAndLoadThreads();
    void this.restoreDrawerAccount();
    this.refreshLoginState();
  }

  aboutToDisappear(): void {
    this.isHomeAlive = false;
    this.webLoadSequence += 1;
    this.topicPermissionProbeSequence += 1;
    this.unreadPromptSequence += 1;
    this.unsubscribeUnreadState();
    this.unsubscribeObservedReplyCounts();
    this.threadMutationState.unsubscribeDeletion(this.threadDeletionListenerId);
    this.threadDeletionListenerId = -1;
    this.clearForumLoadWatchdog();
    this.clearTopicPermissionWatchdog();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildHomeContent();

      if (this.isMainDrawerOpen) {
        Column() {
          this.buildMainDrawer();
        }
        .width(this.mainDrawerWidth)
        .height('100%')
        .transition(
          TransitionEffect.move(TransitionEdge.START)
            .animation({ duration: 220, curve: Curve.EaseOut })
        )
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildHomeContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Web({ src: '', controller: this.forumWebController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        // A new HomePage restarts oh_load at 1, so old board URLs can recur.
        // The thread list must be read from the current forum response.
        .cacheMode(CacheMode.Online)
        .onControllerAttached(() => {
          this.onForumControllerAttached();
        })
        .onPageBegin((event) => {
          if (this.isCurrentForumRequest(event.url) && !this.isForumLoadTerminal()) {
            if (this.isAppendingForumPage) {
              this.isLoadingMore = true;
            } else if (this.threads.length > 0) {
              this.isRefreshing = true;
            } else {
              this.isLoading = true;
            }
          }
        })
        .onPageEnd((event) => {
          if (this.isCurrentForumRequest(event.url) && !this.isForumLoadTerminal()) {
            this.readThreadsFromWeb();
          }
        })
        .onErrorReceive((event) => {
          const requestUrl = event.request.getRequestUrl();
          if (!event.request.isMainFrame() || !this.isCurrentForumRequest(requestUrl)) {
            return;
          }
          this.failForumLoad(this.webLoadSequence, '暂时无法读取 4D4Y 主题，请检查网络后重试。');
        })
        .width('100%')
        .height('100%')

      // Kept separate from the reader document so a permission preflight
      // cannot replace the board currently backing the native thread list.
      Web({ src: '', controller: this.topicPermissionWebController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onControllerAttached(() => {
          this.onTopicPermissionWebControllerAttached();
        })
        .onPageEnd((event) => {
          if (this.isCurrentTopicPermissionProbeRequest(event.url)) {
            this.readTopicPermissionProbe();
          }
        })
        .onErrorReceive((event) => {
          const requestUrl = event.request.getRequestUrl();
          if (event.request.isMainFrame() && this.isCurrentTopicPermissionProbeRequest(requestUrl)) {
            this.failTopicPermissionProbe('暂时无法确认当前版面的发主题权限。');
          }
        })
        .width(1)
        .height(1)

      if (this.needsWebVerification) {
        this.buildVerificationHeader();
      } else {
        Column() {
          this.buildHeader();
          Divider().color($r('app.color.border'));

          this.buildPublicReader();
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface'))
      }

      if (!this.needsWebVerification && !this.isMainDrawerOpen && this.hasUnreadReminder()) {
        this.buildUnreadReminderFab();
      }

      if (this.isMainDrawerOpen) {
        Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_scrim'))
        .onClick(() => {
          this.isMainDrawerOpen = false;
        })
        .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.isAppearanceSheetVisible, this.buildAppearanceSheet(), {
      height: this.appearanceSheetMode === HomeAppearanceSheetMode.Typography ? 460 : 300,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.isAppearanceSheetVisible = false;
        this.appearanceStatus = '';
      }
    })
  }

  @Builder
  private buildHeader() {
    Row({ space: 4 }) {
      Text('☰')
        .fontSize(27)
        .fontColor($r('app.color.text_primary'))
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.openMainDrawer();
        })
      Text(this.forums[this.selectedForumIndex].name +
        (this.selectedForumTypeLabel.length > 0 ? ' · ' + this.selectedForumTypeLabel : ''))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Blank()
      if (this.forums[this.selectedForumIndex].id === '6') {
        Image($r('app.media.toolbar_filter'))
          .width(42)
          .height(42)
          .padding(9)
          .objectFit(ImageFit.Contain)
          .fillColor(this.selectedForumTypeId.length > 0 ? $r('app.color.brand') : $r('app.color.text_detail'))
          .accessibilityText('按分类筛选')
          .bindMenu(this.buildForumTypeMenu())
      }
      Image($r('app.media.toolbar_search'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .onClick(() => {
          this.pathStack.pushPathByName('Search', null);
        })
      Image($r('app.media.toolbar_more'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .bindMenu(this.buildHomeMenu())
    }
    .width('100%')
    .padding({ left: 4, right: 8, top: 4, bottom: 4 })
  }

  /**
   * NG's main navigation is a left overlay drawer, not a row of bottom tabs.
   * Keep all entries here as routes to existing native pages; no menu label is
   * allowed to imply a feature which the Harmony client has not implemented.
   */
  @Builder
  private buildMainDrawer() {
    Column() {
      this.buildDrawerIdentityHeader();

      Scroll() {
        Column({ space: 0 }) {
          this.buildDrawerDestination($r('app.media.drawer_message'), '短消息', 'MessageCenter',
            createMessageCenterRouteParams(FourD4yMessageMode.PrivateMessages), this.privateMessageUnreadCount);
          this.buildDrawerDestination($r('app.media.drawer_notice'), '信息提醒', 'MessageCenter',
            createMessageCenterRouteParams(FourD4yMessageMode.ThreadNotices),
            this.informationReminderUnreadCount);
          this.buildDrawerDestination($r('app.media.drawer_history'), '浏览记录', 'ReadingHistory', null);
          this.buildDrawerDestination($r('app.media.drawer_threads'), '我的主题', 'MyContent', createMyContentRouteParams());
          this.buildDrawerDestination($r('app.media.drawer_replies'), '我的回复', 'MyContent',
            createMyContentRouteParams(FourD4yMyContentMode.Replies));
          this.buildDrawerDestination($r('app.media.drawer_favorite'), '收藏关注', 'Favorites', null);

          Divider().color($r('app.color.border'));
          this.buildDrawerDestination($r('app.media.drawer_settings'), '设置', 'Settings', null);

          Divider().color($r('app.color.border'));
          Text('常用版面')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .padding({ left: 20, right: 16, top: 12, bottom: 6 });
          ForEach(this.getQuickForums(), (forum: ForumSummary) => {
            this.buildDrawerForumRow(forum);
          }, (forum: ForumSummary) => forum.id)
          this.buildDrawerAllForumsRow();

          if (this.isAllDrawerForumsVisible) {
            Divider().color($r('app.color.border_light'));
            ForEach(this.forumGroups, (group: FourD4yForumGroup) => {
              this.buildDrawerForumGroup(group);
            }, (group: FourD4yForumGroup) => group.name)
          }
        }
        .width('100%')
        .padding({ bottom: 22 })
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
  private buildDrawerIdentityHeader() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text(this.getDrawerAccountInitial())
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.drawer_text'))
          .width(58)
          .height(58)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.drawer_avatar'))
          .borderRadius(29)
        Column({ space: 3 }) {
          Text(this.getDrawerAccountName())
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.drawer_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.isLoggedIn && this.drawerAccountUserId.length > 0 ? 'UID ' + this.drawerAccountUserId :
            '登录后可同步账号身份')
            .fontSize(13)
            .fontColor($r('app.color.drawer_text_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row() {
        Text(this.isLoggedIn ? '已登录 4D4Y' : '未登录')
          .fontSize(13)
          .fontColor($r('app.color.drawer_text_muted'))
        Blank()
        Text('账号管理  ›')
          .fontSize(13)
          .fontColor($r('app.color.drawer_text'))
          .padding({ left: 10, right: 2, top: 6, bottom: 6 })
          .onClick(() => {
            this.closeDrawerAndPush('Account', null);
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.buildDrawerAppearanceEntry($r('app.media.drawer_typography'), '字号/行距',
          HomeAppearanceSheetMode.Typography);
        this.buildDrawerAppearanceEntry($r('app.media.drawer_theme'), '主题样式',
          HomeAppearanceSheetMode.Theme);
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 14, top: 30, bottom: 16 })
    .backgroundColor($r('app.color.drawer_surface'))
  }

  @Builder
  private buildDrawerAppearanceEntry(icon: Resource, label: string, mode: HomeAppearanceSheetMode) {
    Row({ space: 5 }) {
      Image(icon)
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.drawer_text'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.drawer_text'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.drawer_entry'))
    .borderRadius(7)
    .onClick(() => {
      this.openAppearanceSheet(mode);
    })
  }

  @Builder
  private buildAppearanceSheet() {
    Column({ space: 14 }) {
      if (this.appearanceSheetMode === HomeAppearanceSheetMode.Typography) {
        this.buildTypographySheetContent();
      } else {
        this.buildThemeSheetContent();
      }
      if (this.appearanceStatus.length > 0) {
        Text(this.appearanceStatus)
          .fontSize(13)
          .fontColor($r('app.color.danger_text'))
          .width('100%');
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 20 })
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private buildTypographySheetContent() {
    Text('字号与行距')
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%');
    Column({ space: 5 }) {
      Text('主题标题示例')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_strong'))
        .width('100%');
      Text('帖子正文预览。调整行距后，阅读页的正文和引用内容会使用新的间距。')
        .fontSize(15)
        .lineHeight(Math.round(23 * this.drawerSettings.postLineSpacing))
        .fontColor($r('app.color.text_body'))
        .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.fill_subtle'))
    .borderRadius(8);
    Text('字号')
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .width('100%');
    Row({ space: 6 }) {
      ForEach(FOUR_D4Y_FONT_SCALES, (scale: number) => {
        this.buildFontScaleChoice(scale);
      }, (scale: number) => String(scale))
    }
    .width('100%');
    Text('帖子行距')
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .width('100%');
    Row({ space: 6 }) {
      ForEach(FOUR_D4Y_POST_LINE_SPACINGS, (spacing: number) => {
        this.buildLineSpacingChoice(spacing);
      }, (spacing: number) => String(spacing))
    }
    .width('100%');
  }

  @Builder
  private buildThemeSheetContent() {
    Text('主题样式')
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%');
    Text('切换后立即应用到整个客户端。')
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
      .width('100%');
    Row({ space: 8 }) {
      this.buildThemeChoice('跟随系统', FourD4yThemeMode.FollowSystem);
      this.buildThemeChoice('浅色', FourD4yThemeMode.Light);
      this.buildThemeChoice('深色', FourD4yThemeMode.Dark);
    }
    .width('100%');
  }

  @Builder
  private buildFontScaleChoice(scale: number) {
    Button(this.getFontScaleLabel(scale))
      .fontSize(13)
      .fontColor(this.drawerSettings.fontScale === scale ? $r('app.color.on_brand') : $r('app.color.text_body'))
      .backgroundColor(this.drawerSettings.fontScale === scale ? $r('app.color.brand') :
        $r('app.color.fill_subtle'))
      .layoutWeight(1)
      .height(38)
      .enabled(!this.isAppearanceSaving)
      .onClick(() => {
        void this.saveDrawerSettings(this.withDrawerFontScale(scale));
      })
  }

  @Builder
  private buildLineSpacingChoice(spacing: number) {
    Button(this.getPostLineSpacingLabel(spacing))
      .fontSize(13)
      .fontColor(this.drawerSettings.postLineSpacing === spacing ? $r('app.color.on_brand') :
        $r('app.color.text_body'))
      .backgroundColor(this.drawerSettings.postLineSpacing === spacing ? $r('app.color.brand') :
        $r('app.color.fill_subtle'))
      .layoutWeight(1)
      .height(38)
      .enabled(!this.isAppearanceSaving)
      .onClick(() => {
        void this.saveDrawerSettings(this.withDrawerPostLineSpacing(spacing));
      })
  }

  @Builder
  private buildThemeChoice(label: string, mode: FourD4yThemeMode) {
    Button(label)
      .fontSize(14)
      .fontColor(this.drawerSettings.themeMode === mode ? $r('app.color.on_brand') : $r('app.color.text_body'))
      .backgroundColor(this.drawerSettings.themeMode === mode ? $r('app.color.brand') :
        $r('app.color.fill_subtle'))
      .layoutWeight(1)
      .height(42)
      .enabled(!this.isAppearanceSaving)
      .onClick(() => {
        void this.saveDrawerSettings(this.withDrawerThemeMode(mode));
      })
  }

  @Builder
  private buildDrawerDestination(icon: Resource, label: string, routeName: string, routeParam: Object | null,
    unreadCount: number = -1) {
    Row({ space: 12 }) {
      Image(icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (unreadCount >= 0) {
        Text(this.formatUnreadCount(unreadCount))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.drawer_text'))
          .minFontScale(0.8)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .height(20)
          .constraintSize({ minWidth: 20 })
          .padding({ left: 5, right: 5 })
          .borderRadius(10)
          .backgroundColor(unreadCount > 0 ? $r('app.color.unread_badge') : $r('app.color.unread_badge_idle'))
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 20, right: 16 })
    .onClick(() => {
      this.closeDrawerAndPush(routeName, routeParam);
    })
  }

  @Builder
  private buildDrawerForumRow(forum: ForumSummary) {
    Row({ space: 10 }) {
      Text(forum.name)
        .fontSize(17)
        .fontWeight(this.isSelectedForum(forum.id) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.isSelectedForum(forum.id) ? $r('app.color.brand') : $r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.isSelectedForum(forum.id)) {
        Text('当前')
          .fontSize(12)
          .fontColor($r('app.color.brand'))
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 20, right: 16 })
    .margin({ left: 8, right: 8 })
    .backgroundColor(this.isSelectedForum(forum.id) ? $r('app.color.fill_selected') : Color.Transparent)
    .borderRadius(7)
    .onClick(() => {
      this.selectForum(forum.id);
      this.isMainDrawerOpen = false;
    })
  }

  @Builder
  private buildDrawerAllForumsRow() {
    Row({ space: 12 }) {
      Text('☷')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
        .width(28)
        .textAlign(TextAlign.Center)
      Text(this.isAllDrawerForumsVisible ? '收起全部版面' : '全部版面')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(this.isAllDrawerForumsVisible ? '⌃' : '⌄')
        .fontSize(18)
        .fontColor($r('app.color.text_muted'))
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 18 })
    .onClick(() => {
      this.isAllDrawerForumsVisible = !this.isAllDrawerForumsVisible;
    })
  }

  @Builder
  private buildDrawerForumGroup(group: FourD4yForumGroup) {
    Column({ space: 0 }) {
      Text(group.name)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
        .width('100%')
        .padding({ left: 20, right: 16, top: 14, bottom: 5 });
      ForEach(group.forums, (forum: ForumSummary) => {
        this.buildDrawerForumRow(forum);
      }, (forum: ForumSummary) => forum.id)
    }
    .width('100%')
  }

  @Builder
  private buildVerificationHeader() {
    Row({ space: 12 }) {
      Text('请在下方完成 4D4Y 的安全验证')
        .fontSize(14)
        .fontColor($r('app.color.text_body'))
        .layoutWeight(1)
      Button('返回列表')
        .fontSize(13)
        .onClick(() => {
          this.needsWebVerification = false;
          this.isLoading = false;
          this.loadError = '请完成 4D4Y 安全验证后点击刷新。';
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.warning_background'))
  }

  @Builder
  private buildPublicReader() {
    Column() {
      if (this.isLoggedIn && !this.isTopicPermissionProbePending && this.topicPermissionMessage.length > 0) {
        Text(this.topicPermissionMessage)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.warning_background'))
      }

      if (this.isLoading && this.threads.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(32)
            .height(32)
          Text('正在读取公开主题…')
            .fontSize(15)
            .fontColor($r('app.color.text_quiet'))
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.loadError.length > 0 && this.threads.length === 0) {
        Column({ space: 12 }) {
          Text(this.loadError)
            .fontSize(15)
            .fontColor($r('app.color.text_quiet'))
            .textAlign(TextAlign.Center)
          Button('重试')
            .onClick(() => {
              this.loadThreads();
            })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .padding(28)
        .width('100%')
      } else {
        Column() {
          if (this.loadError.length > 0) {
            Text(this.loadError)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.warning_background'))
          }

          // Refresh owns the pull-down gesture; List remains the single
          // scrolling surface so reach-end cannot race a nested Scroll.
          Refresh({ refreshing: $$this.isRefreshing, offset: 64, friction: 65 }) {
            List({ space: 0 }) {
              if (this.threads.length === 0) {
                ListItem() {
                  Text(this.selectedForumTypeId.length > 0 ? '当前筛选下暂无主题' : '当前页暂无主题')
                    .fontSize(15)
                    .fontColor($r('app.color.text_quiet'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(28)
                }
              }
              ForEach(this.getVisibleThreads(), (thread: ThreadSummary) => {
                ListItem() {
                  this.buildThreadItem(thread);
                }
                .onClick(() => {
                  if (this.shouldSuppressThreadOpenAfterDrawerSwipe()) {
                    return;
                  }
                  this.pathStack.pushPathByName('ThreadDetail',
                    createThreadRouteParams(thread.id, thread.title, this.displayReplyCount(thread), 1, 0, thread.forumId));
                })
              }, (thread: ThreadSummary) => this.threadRowVersions.key(thread))
              ListItem() {
                this.buildForumLoadFooter();
              }
            }
            .layoutWeight(1)
            .width('100%')
            .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 20, endMargin: 20 })
            .onReachEnd(() => {
              this.loadNextForumPage();
            })
            .parallelGesture(
              PanGesture({ fingers: 1, direction: PanDirection.Right, distance: 24 })
                .onActionStart(() => {
                  this.beginDrawerSwipeGesture();
                })
                .onActionEnd((event: GestureEvent) => {
                  this.openDrawerFromThreadListSwipe(event);
                })
                .onActionCancel(() => {
                  this.finishDrawerSwipeGesture();
                })
            )
          }
          .onRefreshing(() => {
            // With a two-way Refresh binding the component may already have
            // set isRefreshing before it emits this callback.
            this.loadThreads(true);
          })
          .layoutWeight(1)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private buildForumPicker() {
    Column({ space: 10 }) {
      Row() {
        Text('全部版面')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.forums.length + ' 个')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })

      Divider().color($r('app.color.border_light'))

      Scroll() {
        Column({ space: 14 }) {
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
    Column({ space: 0 }) {
      Text(group.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_detail'))
        .padding({ top: 4, bottom: 4 })
        .width('100%')
      ForEach(group.forums, (forum: ForumSummary) => {
        Row({ space: 8 }) {
          Text(forum.name)
            .fontSize(16)
            .fontWeight(this.isSelectedForum(forum.id) ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.isSelectedForum(forum.id) ? $r('app.color.brand') : $r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.isSelectedForum(forum.id)) {
            Text('当前')
              .fontSize(12)
              .fontColor($r('app.color.brand'))
          }
        }
          .width('100%')
          .height(42)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.selectForum(forum.id);
            this.isForumPickerVisible = false;
          })
      }, (forum: ForumSummary) => forum.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildForumLoadFooter() {
    Column() {
      if (this.isLoadingMore) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(18)
            .height(18)
          Text('正在加载下一页…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
      } else if (this.loadMoreError.length > 0) {
        Text(this.loadMoreError + ' 点击重试')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.loadNextForumPage();
          })
      } else if (this.threads.length > 0 && this.nextForumPage <= this.currentForumPage) {
        Text('— 已到底 —')
          .fontSize(12)
          .fontColor($r('app.color.text_quiet'))
      }
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildThreadItem(thread: ThreadSummary) {
    Column({ space: 4 }) {
      Row() {
        Row({ space: 7 }) {
          if (thread.isPinned) {
            Text('置顶')
              .fontSize(11)
              .fontColor($r('app.color.danger_text'))
              .backgroundColor($r('app.color.danger_soft'))
              .borderRadius(4)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          }
          if (thread.authorName.length > 0 && thread.authorName !== '未知作者') {
            Text(thread.authorName)
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)

        Row({ space: 5 }) {
          if ((thread.threadType || '').length > 0) {
            Text(thread.threadType || '')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 92 })
          }
          if (thread.hasImage === true) {
            Image($r('app.media.thread_has_image'))
              .width(17)
              .height(17)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.brand'))
          }
          Text(formatFourD4yThreadCount(this.displayReplyCount(thread)) + '/' +
            formatFourD4yThreadCount(thread.viewCount || 0))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .maxLines(1)
          Text(formatFourD4yThreadCreatedDate(thread.createdAt || ''))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .maxLines(1)
        }
        .justifyContent(FlexAlign.End)
      }
      .width('100%')

      Text(thread.title)
        .fontSize(17)
        .fontColor($r('app.color.text_strong'))
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 10 })
  }

  @Builder
  private buildPlaceholder() {
    Column({ space: 10 }) {
      Text(this.tabs[this.activeTab])
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
      Text('公开主题列表已可读取。登录、收藏和个人功能将在会话与本地存储方案完成后接入。')
        .fontSize(15)
        .fontColor($r('app.color.text_quiet'))
        .lineHeight(23)
        .textAlign(TextAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .padding(28)
    .width('100%')
  }

  @Builder
  private buildTabBar() {
    Row() {
      ForEach(this.tabs, (tab: string, index: number) => {
        this.buildTabItem(tab, index);
      })
    }
    .width('100%')
  }

  @Builder
  private buildForumTypeMenu() {
    Menu() {
      MenuItem(() => {
        this.buildForumTypeMenuItem('全部分类', this.selectedForumTypeId.length === 0);
      })
        .onClick(() => this.selectForumType('', ''))
      ForEach(this.currentForumThreadTypes, (type: ForumThreadType) => {
        MenuItem(() => {
          this.buildForumTypeMenuItem(type.label, this.selectedForumTypeId === type.value);
        })
          .onClick(() => this.selectForumType(type.value, type.label))
      }, (type: ForumThreadType) => type.value)
    }
  }

  private selectForumType(typeId: string, label: string): void {
    if (!this.isHomeAlive || this.forums[this.selectedForumIndex].id !== '6' ||
      typeId === this.selectedForumTypeId || (typeId.length > 0 &&
        !this.currentForumThreadTypes.some((type: ForumThreadType): boolean => type.value === typeId))) {
      return;
    }
    this.selectedForumTypeId = typeId;
    this.selectedForumTypeLabel = label;
    this.threads = this.threadRowVersions.track([]);
    this.currentForumPage = 1;
    this.nextForumPage = 0;
    this.isRefreshing = false;
    this.loadForumPage(1, false);
  }

  @Builder
  private buildForumTypeMenuItem(label: string, selected: boolean) {
    Row({ space: 10 }) {
      Image(selected ? $r('app.media.menu_checkbox_checked') : $r('app.media.menu_checkbox_unchecked'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(212)
    .height(44)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private buildHomeMenu() {
    Menu() {
      MenuItem(() => {
        this.buildHomeMenuTrailingAction('发主题');
      })
        .enabled(this.isLoggedIn && this.canCreateTopicInCurrentForum &&
          !this.isTopicPermissionProbePending && !this.isLoading && !this.isRefreshing && !this.isLoadingMore)
        .onClick(() => {
          const forum: ForumSummary = this.forums[this.selectedForumIndex];
          const generation: number = this.accountState.getSessionGeneration();
          this.pathStack.pushPathByName('ForumComposer',
            createNewThreadComposerRouteParams(forum.id, forum.name, this.currentForumThreadTypes),
            (popInfo: PopInfo) => this.onNewThreadComposerReturned(popInfo, forum.id, generation));
        })
      MenuItem(() => {
        this.buildHomeMenuTrailingToggle('按发表排序', this.isCurrentForumPostTimeSorted());
      })
        .enabled(!this.isLoading && !this.isRefreshing && !this.isLoadingMore &&
          !this.isForumListPreferenceSaving)
        .onClick(() => {
          void this.setCurrentForumPostTimeSort(!this.isCurrentForumPostTimeSorted());
        })
      MenuItem(() => {
        this.buildHomeMenuTrailingToggle('显示置顶帖', this.drawerSettings.showPinnedThreads);
      })
        .enabled(!this.isForumListPreferenceSaving)
        .onClick(() => {
          void this.setPinnedThreadsVisible(!this.drawerSettings.showPinnedThreads);
        })
      MenuItem(() => {
        this.buildHomeMenuTrailingAction('刷新');
      })
        .enabled(!this.isLoading && !this.isRefreshing && !this.isLoadingMore)
        .onClick(() => {
          this.loadThreads();
        })
    }
  }

  @Builder
  private buildHomeMenuTrailingAction(label: string) {
    Row() {
      Blank()
      Text(label)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    // A custom MenuItem does not inherit the system menu's compact width.
    // On the Mate 60 this is the native popup's compact ~160vp width; using
    // physical-pixel-like values here would expand the menu to the viewport.
    // native toggle rows rather than allowing it to expand to the viewport.
    .width(160)
    .height(48)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private buildHomeMenuTrailingToggle(label: string, selected: boolean) {
    Row({ space: 10 }) {
      Blank()
      Image(selected ? $r('app.media.menu_checkbox_checked') : $r('app.media.menu_checkbox_unchecked'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width(160)
    .height(48)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private buildTabItem(tab: string, index: number) {
    Text(tab)
      .fontSize(14)
      .fontColor(index === 0 ? $r('app.color.brand') : $r('app.color.text_quiet'))
      .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: 11, bottom: 13 })
      .onClick(() => {
        if (index === 1) {
          this.isForumPickerVisible = true;
          return;
        }
        if (index === 2) {
          this.pathStack.pushPathByName('Favorites', null);
          return;
        }
        if (index === 3) {
          this.pathStack.pushPathByName('MyContent', null);
          return;
        }
        this.activeTab = 0;
      })
      // A visible, stable bottom-navigation item is the presentation anchor.
      // This makes “板块” the single all-forums entry instead of duplicating
      // it in the board header.
      .bindSheet(this.isForumPickerVisible, this.buildForumPicker(), {
        height: 620,
        dragBar: true,
        showClose: true,
        onDisappear: () => {
          this.isForumPickerVisible = false;
        }
      })
  }

  private getQuickForums(): ForumSummary[] {
    const quickForums: ForumSummary[] = [];
    this.quickForumIds.forEach((forumId: string) => {
      const index: number = this.getForumIndex(forumId);
      if (index >= 0) {
        quickForums.push(this.forums[index]);
      }
    });
    return quickForums;
  }

  private getVisibleThreads(): ThreadSummary[] {
    if (this.drawerSettings.showPinnedThreads) {
      return this.threads;
    }
    return this.threads.filter((thread: ThreadSummary) => !thread.isPinned);
  }

  private isCurrentForumPostTimeSorted(): boolean {
    const forum: ForumSummary = this.forums[this.selectedForumIndex];
    return this.drawerSettings.postTimeSortForumIds.indexOf(forum.id) >= 0;
  }

  private async restoreQuickForums(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const settings: FourD4yUserSettings = await FourD4yUserSettingsStore.load(context);
      if (!this.isHomeAlive) {
        return;
      }
      this.drawerSettings = settings;
      this.quickForumIds = settings.quickForumIds;
    } catch (_error) {
      if (!this.isHomeAlive) {
        return;
      }
      this.drawerSettings = createDefaultFourD4yUserSettings();
      this.quickForumIds = [...FOUR_D4Y_QUICK_FORUM_IDS];
    }
  }

  private async restoreHomeSettingsAndLoadThreads(): Promise<void> {
    await this.restoreQuickForums();
    if (!this.isHomeAlive) {
      return;
    }
    let lastForumId: string = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      lastForumId = await FourD4yLastForumStore.load(context);
    } catch (_error) {
      // The resolver below falls back to the user's first quick board.
    }
    if (!this.isHomeAlive) {
      return;
    }
    this.restoreSelectedForum(lastForumId, this.quickForumIds);
    this.loadThreads();
  }

  private openMainDrawer(): void {
    this.isMainDrawerOpen = true;
    void this.restoreQuickForums();
    void this.restoreDrawerAccount();
    void this.refreshUnreadPromptCounts();
  }

  private beginDrawerSwipeGesture(): void {
    this.isDrawerSwipeGestureActive = true;
    this.suppressThreadOpenUntilMillis = Date.now() + 500;
  }

  private finishDrawerSwipeGesture(): void {
    this.isDrawerSwipeGestureActive = false;
    this.suppressThreadOpenUntilMillis = Date.now() + 500;
  }

  private shouldSuppressThreadOpenAfterDrawerSwipe(): boolean {
    return this.isMainDrawerOpen || this.isDrawerSwipeGestureActive ||
      Date.now() < this.suppressThreadOpenUntilMillis;
  }

  private openDrawerFromThreadListSwipe(event: GestureEvent): void {
    this.finishDrawerSwipeGesture();
    if (this.isMainDrawerOpen || !isQualifiedFourD4yRightSwipe(event.offsetX, event.offsetY)) {
      return;
    }
    this.openMainDrawer();
  }

  private closeDrawerAndPush(routeName: string, routeParam: Object | null): void {
    this.isMainDrawerOpen = false;
    if (routeName === 'Account') {
      const sessionGeneration: number = this.accountState.getSessionGeneration();
      this.pathStack.pushPathByName(routeName, routeParam, (_result: PopInfo) => {
        this.refreshAfterAccountManagement(sessionGeneration);
      });
      return;
    }
    if (routeName === 'MessageCenter') {
      this.pathStack.pushPathByName(routeName, routeParam, (_result: PopInfo) => {
        void this.refreshLoginState();
      });
      return;
    }
    this.pathStack.pushPathByName(routeName, routeParam);
  }

  private refreshAfterAccountManagement(previousGeneration: number): void {
    if (!this.isHomeAlive) {
      return;
    }
    const generation: number = this.accountState.getSessionGeneration();
    if (generation !== previousGeneration) {
      this.selectedForumTypeId = '';
      this.selectedForumTypeLabel = '';
      this.unreadPromptSequence += 1;
      this.isUnreadPromptLoading = false;
      this.observedReplyCounts.syncSession(generation);
      // An account can see different boards, permissions and blacklist rows.
      this.threads = this.threadRowVersions.track([]);
      this.loadForumPage(1, false);
    }
    void this.restoreDrawerAccount();
    void this.refreshLoginState();
  }

  private openAppearanceSheet(mode: HomeAppearanceSheetMode): void {
    this.appearanceSheetMode = mode;
    this.appearanceStatus = '';
    this.isMainDrawerOpen = false;
    this.isAppearanceSheetVisible = true;
  }

  private async saveDrawerSettings(nextSettings: FourD4yUserSettings): Promise<void> {
    if (!this.isHomeAlive || this.isAppearanceSaving) {
      return;
    }
    const normalized: FourD4yUserSettings = normalizeFourD4yUserSettings(nextSettings);
    const previous: FourD4yUserSettings = this.drawerSettings;
    this.drawerSettings = normalized;
    this.isAppearanceSaving = true;
    this.appearanceStatus = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const saved: FourD4yUserSettings | undefined = await FourD4yUserSettingsStore.save(context, normalized, previous);
      if (!this.isHomeAlive) {
        return;
      }
      if (saved === undefined) {
        this.drawerSettings = previous;
        this.appearanceStatus = '保存设置失败，请重试。';
        this.isAppearanceSaving = false;
        return;
      }
      this.drawerSettings = saved;
      FourD4yUserSettingsStore.applyAppearance(context.getApplicationContext(), saved);
      this.quickForumIds = saved.quickForumIds;
    } catch (_error) {
      if (!this.isHomeAlive) {
        return;
      }
      this.drawerSettings = previous;
      this.appearanceStatus = '保存设置失败，请重试。';
    }
    this.isAppearanceSaving = false;
  }

  private async setCurrentForumPostTimeSort(enabled: boolean): Promise<void> {
    const forum: ForumSummary = this.forums[this.selectedForumIndex];
    const nextForumIds: string[] = this.drawerSettings.postTimeSortForumIds.filter(
      (forumId: string) => forumId !== forum.id);
    if (enabled) {
      nextForumIds.push(forum.id);
    }
    await this.saveForumListSettings(this.withForumListSettings(
      this.drawerSettings.showPinnedThreads, nextForumIds), true);
  }

  private async setPinnedThreadsVisible(visible: boolean): Promise<void> {
    await this.saveForumListSettings(this.withForumListSettings(
      visible, this.drawerSettings.postTimeSortForumIds), false);
  }

  private async saveForumListSettings(nextSettings: FourD4yUserSettings, reloadForum: boolean): Promise<void> {
    if (!this.isHomeAlive || this.isForumListPreferenceSaving) {
      return;
    }
    const normalized: FourD4yUserSettings = normalizeFourD4yUserSettings(nextSettings);
    const previous: FourD4yUserSettings = this.drawerSettings;
    this.drawerSettings = normalized;
    this.isForumListPreferenceSaving = true;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const saved: FourD4yUserSettings | undefined = await FourD4yUserSettingsStore.save(context, normalized, previous);
      if (!this.isHomeAlive) {
        return;
      }
      if (saved === undefined) {
        this.drawerSettings = previous;
        this.loadError = '保存列表显示设置失败，请重试。';
        this.isForumListPreferenceSaving = false;
        return;
      }
      this.drawerSettings = saved;
    } catch (_error) {
      if (!this.isHomeAlive) {
        return;
      }
      this.drawerSettings = previous;
      this.loadError = '保存列表显示设置失败，请重试。';
      this.isForumListPreferenceSaving = false;
      return;
    }
    this.isForumListPreferenceSaving = false;
    if (reloadForum) {
      this.loadThreads();
    }
  }

  private withDrawerFontScale(fontScale: number): FourD4yUserSettings {
    return {
      themeMode: this.drawerSettings.themeMode,
      fontScale: fontScale,
      postLineSpacing: this.drawerSettings.postLineSpacing,
      imageLoadPolicy: this.drawerSettings.imageLoadPolicy,
      quickForumIds: [...this.drawerSettings.quickForumIds],
      showPinnedThreads: this.drawerSettings.showPinnedThreads,
      postTimeSortForumIds: [...this.drawerSettings.postTimeSortForumIds],
      addPostTail: this.drawerSettings.addPostTail,
      postTailText: this.drawerSettings.postTailText,
      postTailUrl: this.drawerSettings.postTailUrl
    };
  }

  private withDrawerPostLineSpacing(postLineSpacing: number): FourD4yUserSettings {
    return {
      themeMode: this.drawerSettings.themeMode,
      fontScale: this.drawerSettings.fontScale,
      postLineSpacing: postLineSpacing,
      imageLoadPolicy: this.drawerSettings.imageLoadPolicy,
      quickForumIds: [...this.drawerSettings.quickForumIds],
      showPinnedThreads: this.drawerSettings.showPinnedThreads,
      postTimeSortForumIds: [...this.drawerSettings.postTimeSortForumIds],
      addPostTail: this.drawerSettings.addPostTail,
      postTailText: this.drawerSettings.postTailText,
      postTailUrl: this.drawerSettings.postTailUrl
    };
  }

  private withDrawerThemeMode(themeMode: FourD4yThemeMode): FourD4yUserSettings {
    return {
      themeMode: themeMode,
      fontScale: this.drawerSettings.fontScale,
      postLineSpacing: this.drawerSettings.postLineSpacing,
      imageLoadPolicy: this.drawerSettings.imageLoadPolicy,
      quickForumIds: [...this.drawerSettings.quickForumIds],
      showPinnedThreads: this.drawerSettings.showPinnedThreads,
      postTimeSortForumIds: [...this.drawerSettings.postTimeSortForumIds],
      addPostTail: this.drawerSettings.addPostTail,
      postTailText: this.drawerSettings.postTailText,
      postTailUrl: this.drawerSettings.postTailUrl
    };
  }

  private withForumListSettings(showPinnedThreads: boolean, postTimeSortForumIds: string[]): FourD4yUserSettings {
    return {
      themeMode: this.drawerSettings.themeMode,
      fontScale: this.drawerSettings.fontScale,
      postLineSpacing: this.drawerSettings.postLineSpacing,
      imageLoadPolicy: this.drawerSettings.imageLoadPolicy,
      quickForumIds: [...this.drawerSettings.quickForumIds],
      showPinnedThreads: showPinnedThreads,
      postTimeSortForumIds: [...postTimeSortForumIds],
      addPostTail: this.drawerSettings.addPostTail,
      postTailText: this.drawerSettings.postTailText,
      postTailUrl: this.drawerSettings.postTailUrl
    };
  }

  private getFontScaleLabel(scale: number): string {
    if (scale === 0.9) {
      return '小';
    }
    if (scale === 1) {
      return '标准';
    }
    if (scale === 1.15) {
      return '大';
    }
    return '特大';
  }

  private getPostLineSpacingLabel(spacing: number): string {
    if (spacing === 1) {
      return '默认';
    }
    if (spacing === 1.12) {
      return '稍大';
    }
    if (spacing === 1.24) {
      return '再大点';
    }
    return '很大';
  }

  private async restoreDrawerAccount(): Promise<void> {
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const registry = await FourD4yAccountProfileStore.load(context);
      if (!this.isHomeAlive || sessionGeneration !== this.accountState.getSessionGeneration()) {
        return;
      }
      const activeProfile: FourD4yAccountProfile | undefined = registry.profiles.find(
        (profile: FourD4yAccountProfile) => profile.id === registry.activeProfileId);
      this.drawerAccountName = activeProfile === undefined ? '' : activeProfile.displayName;
      this.drawerAccountUserId = activeProfile === undefined ? '' : activeProfile.userId;
    } catch (_error) {
      if (!this.isHomeAlive || sessionGeneration !== this.accountState.getSessionGeneration()) {
        return;
      }
      this.drawerAccountName = '';
      this.drawerAccountUserId = '';
    }
  }

  private getDrawerAccountName(): string {
    if (!this.isLoggedIn) {
      return '4D4Y 未登录';
    }
    return this.drawerAccountName.length > 0 ? this.drawerAccountName : '4D4Y 用户';
  }

  private getDrawerAccountInitial(): string {
    const name: string = this.getDrawerAccountName();
    return name.length > 0 ? name.charAt(0).toUpperCase() : '4';
  }

  private getForumIndex(forumId: string): number {
    for (let index = 0; index < this.forums.length; index += 1) {
      if (this.forums[index].id === forumId) {
        return index;
      }
    }
    return -1;
  }

  private isSelectedForum(forumId: string): boolean {
    return this.getForumIndex(forumId) === this.selectedForumIndex;
  }

  private restoreSelectedForum(lastForumId: string, quickForumIds: string[]): void {
    const availableForumIds: string[] = this.forums.map((forum: ForumSummary) => forum.id);
    const initialForumId: string = resolveFourD4yHomeForumId(lastForumId, quickForumIds, availableForumIds);
    const initialForumIndex: number = this.getForumIndex(initialForumId);
    this.selectedForumIndex = initialForumIndex >= 0 ? initialForumIndex : 0;
  }

  private async persistLastVisitedForum(forumId: string): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await FourD4yLastForumStore.save(context, forumId);
    } catch (_error) {
      // Navigation remains usable; the next launch falls back to the first quick board.
    }
  }

  private selectForum(forumId: string): void {
    const nextIndex: number = this.getForumIndex(forumId);
    if (nextIndex < 0 || nextIndex === this.selectedForumIndex) {
      return;
    }
    this.selectedForumIndex = nextIndex;
    this.selectedForumTypeId = '';
    this.selectedForumTypeLabel = '';
    void this.persistLastVisitedForum(forumId);
    // A board switch must never leave the old board's rows under the new
    // title while page 1 is loading.
    this.threads = this.threadRowVersions.track([]);
    this.currentForumPage = 1;
    this.nextForumPage = 0;
    this.isLoading = false;
    this.isRefreshing = false;
    this.isLoadingMore = false;
    this.loadError = '';
    this.loadMoreError = '';
    this.loadForumPage(1, false);
  }

  private onNewThreadComposerReturned(popInfo: PopInfo, forumId: string, generation: number): void {
    if (!this.isHomeAlive || generation !== this.accountState.getSessionGeneration() ||
      forumId !== this.forums[this.selectedForumIndex].id ||
      !isForumComposerThreadPublishedResult(popInfo.result, forumId)) {
      return;
    }
    const result: ForumComposerThreadPublishedResult = popInfo.result as ForumComposerThreadPublishedResult;
    // Refresh only after confirmed publication. The editor has already left
    // the stack, so Back from this reader cannot revive a submitted draft.
    this.loadForumPage(1, false);
    this.pathStack.pushPathByName('ThreadDetail',
      createThreadRouteParams(result.threadId, result.title, 0, 1, 0, forumId));
  }

  private onConfirmedThreadDeletion(event: FourD4yThreadDeletionEvent): void {
    if (!this.isHomeAlive || event.sessionGeneration !== this.accountState.getSessionGeneration() ||
      event.forumId !== this.forums[this.selectedForumIndex].id) {
      return;
    }
    // NG refreshes the matching board after confirmed first-post deletion.
    // Supersede any older load so it cannot put the removed row back.
    this.threads = this.threadRowVersions.track(
      this.threads.filter((thread: ThreadSummary) => thread.id !== event.threadId));
    this.loadForumPage(1, false);
  }

  private loadThreads(fromPullGesture: boolean = false): void {
    if (this.isLoading || this.isLoadingMore || (this.isRefreshing && !fromPullGesture)) {
      return;
    }
    this.loadForumPage(1, false);
  }

  private loadNextForumPage(): void {
    if (this.nextForumPage <= this.currentForumPage || this.isLoading || this.isRefreshing || this.isLoadingMore) {
      return;
    }
    this.loadForumPage(this.nextForumPage, true);
  }

  private loadForumPage(page: number, append: boolean): void {
    if (!this.isHomeAlive || !Number.isFinite(page) || page < 1) {
      return;
    }
    const requestedPage: number = Math.max(1, Math.floor(page));
    if (append && (requestedPage !== this.nextForumPage || this.nextForumPage <= this.currentForumPage)) {
      return;
    }
    this.isAppendingForumPage = append;
    if (append) {
      this.isLoadingMore = true;
      this.loadMoreError = '';
    } else if (this.threads.length > 0) {
      this.isLoadingMore = false;
      this.isRefreshing = true;
      this.loadError = '';
      this.loadMoreError = '';
    } else {
      this.isLoadingMore = false;
      this.isLoading = true;
      this.loadError = '';
      this.loadMoreError = '';
    }
    this.loadError = '';
    if (requestedPage === 1) {
      // A filtered document renders the current type as plain text. Keep the
      // same-board catalog until extraction can merge that selected entry.
      // Board/account changes clear selectedForumTypeId before this call.
      if (this.selectedForumTypeId.length === 0) {
        this.currentForumThreadTypes = [];
      }
      this.resetTopicPermissionProbe();
    }
    this.needsWebVerification = false;
    this.webLoadSequence += 1;
    this.requestedForumPage = requestedPage;
    this.startForumLoadWatchdog(this.webLoadSequence);
    const forum: ForumSummary = this.forums[this.selectedForumIndex];
    const orderByQuery: string = this.isCurrentForumPostTimeSorted() ? '&orderby=dateline' : '';
    const filterQuery: string = buildFourD4yForumFilterQuery(forum.id, this.selectedForumTypeId);
    this.forumPageUrl = `https://www.4d4y.com/forum/forumdisplay.php?fid=${forum.id}&page=${requestedPage}${orderByQuery}${filterQuery}&oh_load=${this.webLoadSequence}`;
    if (!this.isForumWebControllerAttached) {
      return;
    }
    try {
      this.forumWebController.loadUrl(this.forumPageUrl);
    } catch (_error) {
      // The initial source is loaded after the Web component is attached.
    }
  }

  private onForumControllerAttached(): void {
    this.isForumWebControllerAttached = true;
    try {
      // This must run before the first 4D4Y URL is loaded.  The login page,
      // board page and reader therefore share one full-site session profile.
      this.forumWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.forumPageUrl.indexOf('/forum/forumdisplay.php') >= 0) {
        this.forumWebController.loadUrl(this.forumPageUrl);
      }
    } catch (_error) {
      if (this.webLoadSequence > 0) {
        this.failForumLoad(this.webLoadSequence, 'Unable to initialize forum session.');
      }
    }
  }

  private onTopicPermissionWebControllerAttached(): void {
    this.isTopicPermissionWebControllerAttached = true;
    try {
      this.topicPermissionWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.topicPermissionProbeUrl.indexOf('/forum/post.php') >= 0) {
        this.topicPermissionWebController.loadUrl(this.topicPermissionProbeUrl);
      }
    } catch (_error) {
      if (this.isTopicPermissionProbePending) {
        this.failTopicPermissionProbe('暂时无法初始化发主题权限检查。');
      }
    }
  }

  private async readThreadsFromWeb(): Promise<void> {
    const expectedSequence: number = this.webLoadSequence;
    const expectedPage: number = this.requestedForumPage;
    const expectedTypeId: string = this.selectedForumTypeId;
    const expectedGeneration: number = this.accountState.getSessionGeneration();
    if (this.isForumLoadTerminal(expectedSequence)) {
      return;
    }
    const forum: ForumSummary = this.forums[this.selectedForumIndex];
    try {
      const rawResult: string = await this.forumWebController.runJavaScript(
        `(() => {
          const toText = (node) => node ? (node.textContent || '').replace(/\\s+/g, ' ').trim() : '';
          const links = Array.from(document.querySelectorAll('a'));
          const params = new URLSearchParams(location.search);
          const currentFid = params.get('fid') || '';
          // 4D4Y leaves the new-topic form's select at its empty typeid=0
          // placeholder. The current board's visible top .threadtype menu
          // is the authoritative source of user-selectable category values.
          ${buildFourD4yForumNavigationScript()}
          const titleLinks = links.filter((link) => {
            const href = link.getAttribute('href') || '';
            return href.indexOf('viewthread.php') >= 0 && toText(link).length > 0;
          });
          const seenThreadIds = new Set();
          const threads = [];
          titleLinks.forEach((titleNode) => {
            const href = titleNode.getAttribute('href') || '';
            const match = /[?&]tid=(\\d+)/.exec(href);
            const threadId = match ? match[1] : '';
            if (threadId.length === 0 || seenThreadIds.has(threadId)) {
              return;
            }
            seenThreadIds.add(threadId);
            const row = titleNode.closest('tr') || titleNode.parentElement;
            const subjectCell = titleNode.closest('th.subject, td.listcon') ||
              (row ? row.querySelector('th.subject, td.listcon') : null);
            const threadTypeNode = subjectCell ?
              subjectCell.querySelector('em a[href*="typeid="], a.threadtype[href*="typeid="]') : null;
            const authorNode = row ? row.querySelector('td.list_user a.user, td.author cite a, td.author a, .author a') : null;
            const authorImage = authorNode ? authorNode.querySelector('img') : null;
            const authorName = toText(authorNode) || (authorNode ? (authorNode.getAttribute('title') || '') : '') ||
              (authorImage ? (authorImage.getAttribute('alt') || '') : '');
            const numsCell = row ? row.querySelector('td.nums, .nums') : null;
            const replyText = toText(numsCell ? numsCell.querySelector('strong, a.num') : null) || toText(numsCell);
            const viewText = toText(numsCell ? numsCell.querySelector('em') : null);
            const hasImage = !!(row && Array.from(row.querySelectorAll('img.attach')).some((image) => {
              const source = (image.getAttribute('src') || '').toLowerCase();
              return /(?:^|\\/)image_s\\.gif(?:[?#]|$)/.test(source);
            }));
            // NG reads timeCreate from the original author's cell and keeps
            // td.lastpost as a separate value. Never use the latter here.
            const authorCell = row ? row.querySelector('td.author, td.list_user') : null;
            const createTimeNode = authorCell ? authorCell.querySelector('em, time, .date, .time') : null;
            const authorTimeText = (toText(createTimeNode) + ' ' + toText(authorCell)).trim();
            const createTimeMatch = /(?:\\d{4}-\\d{1,2}-\\d{1,2}|今天|昨天)(?:\\s+\\d{1,2}:\\d{2})?/.exec(authorTimeText);
            const createdAt = createTimeMatch ? createTimeMatch[0] : '';
            const rowClasses = row ? ((row.className || '') + ' ' + (row.id || '') + ' ' + (row.innerHTML || '')) : '';
            const titleStyle = titleNode.getAttribute('style') || '';
            threads.push({
              id: threadId,
              title: toText(titleNode),
              authorName: authorName,
              replyCount: Number.parseInt(replyText, 10) || 0,
              viewCount: Number.parseInt(viewText, 10) || 0,
              threadType: toText(threadTypeNode).slice(0, 80),
              hasImage: hasImage,
              createdAt: createdAt,
              // Discovery's logged-in mobile list marks pinned topics on the
              // title anchor itself, rather than on its row or container.
              isPinned: /stick|pin_|置顶/i.test(rowClasses) ||
                (/font-weight\\s*:\\s*bold\\b/i.test(titleStyle) && /color\\s*:\\s*#ee1b2e\\b/i.test(titleStyle))
            });
          });
          const forumRowCount = document.querySelectorAll('td.listcon').length;
          const legacyThreadRowCount = document.querySelectorAll('tbody[id^="normalthread_"]').length;
          ${buildFourD4yEmptyForumScript()}
          const layout = forumRowCount > 0 ? 'mobile-listcon' :
            (legacyThreadRowCount > 0 ? 'legacy-threadlist' : (hasEmptyForumTable ? 'legacy-empty' : 'unrecognized'));
          const page = Number.parseInt(params.get('page') || '1', 10) || 1;
          const linkedPages = links.map(linkedBoardPage);
          const nextPageCandidates = linkedPages.filter((linkedPage) => linkedPage > page);
          const nextPage = nextPageCandidates.length > 0 ? Math.min(...nextPageCandidates) : 0;
          const pageText = toText(document.body);
          const loginForm = document.querySelector('#loginform, form[name=login]');
          const accessState = loginForm && /(\u672a\u767b\u5f55|\u65e0\u6743)/.test(pageText) ? 'loginRequired' : 'available';
          return JSON.stringify({
            fid: params.get('fid') || '',
            filterTypeId: filterTypeId,
            page: page,
            nextPage: nextPage,
            loadSequence: Number.parseInt(params.get('oh_load') || '0', 10) || 0,
            layout: layout,
            threadLinkCount: titleLinks.length,
            forumRowCount: forumRowCount,
            hasEmptyForumTable: hasEmptyForumTable,
            accessState: accessState,
            hasChallenge: document.documentElement.innerHTML.indexOf('challenge-platform') >= 0 || document.documentElement.innerHTML.indexOf('cf-chl-') >= 0,
            threadTypes: threadTypes,
            threads: threads
          });
        })()`
      );
      if (this.isForumLoadTerminal(expectedSequence)) {
        return;
      }
      const payload: ForumWebPayload | null = parseForumWebPayload(rawResult);
      if (payload === null) {
        if (expectedSequence === this.webLoadSequence) {
          this.failForumLoad(expectedSequence, '4D4Y 页面已加载，但无法识别页面数据；请刷新后重试。');
        }
        return;
      }
      if (!this.isHomeAlive || expectedGeneration !== this.accountState.getSessionGeneration() ||
        expectedSequence !== this.webLoadSequence || expectedTypeId !== this.selectedForumTypeId ||
        !isExpectedForumWebPayload(payload, forum.id, expectedPage, expectedSequence, expectedTypeId)) {
        return;
      }
      const readerOutcome: FourD4yReaderOutcome = getForumReaderOutcome(payload);
      if (readerOutcome === FourD4yReaderOutcome.LoginRequired) {
        this.needsWebVerification = false;
        this.failForumLoad(expectedSequence, '4D4Y 登录状态已失效，请重新登录后刷新。');
        return;
      }
      if (readerOutcome === FourD4yReaderOutcome.VerificationRequired) {
        this.needsWebVerification = true;
        this.finishForumLoad(expectedSequence);
        return;
      }
      if (readerOutcome === FourD4yReaderOutcome.UnsupportedLayout) {
        this.needsWebVerification = false;
        this.failForumLoad(expectedSequence, '4D4Y 页面已加载，但页面结构暂未适配；请刷新或稍后再试。');
        return;
      }
      this.needsWebVerification = false;
      this.currentForumPage = payload.page;
      this.nextForumPage = payload.nextPage > payload.page ? payload.nextPage : 0;
      this.currentForumThreadTypes = retainSelectedFourD4yForumType(payload.threadTypes,
        this.currentForumThreadTypes, expectedTypeId);
      const parsedThreads: ThreadSummary[] = payload.threads.map((thread: WebThreadSummary): ThreadSummary => ({
        id: thread.id,
        forumId: forum.id,
        title: thread.title,
        authorName: thread.authorName.length > 0 ? thread.authorName : '未知作者',
        replyCount: thread.replyCount,
        viewCount: thread.viewCount,
        threadType: thread.threadType,
        hasImage: thread.hasImage,
        createdAt: thread.createdAt,
        isPinned: thread.isPinned
      }));
      this.observedReplyCounts.acceptBoardRows(parsedThreads.map((thread: ThreadSummary): string => thread.id));
      this.threads = this.threadRowVersions.track(this.isAppendingForumPage ?
        appendUniqueFourD4yForumThreads(this.threads, parsedThreads) : parsedThreads);
      this.finishForumLoad(expectedSequence);
      if (expectedPage === 1) {
        this.startTopicPermissionProbe(forum.id);
      }
    } catch (_error) {
      if (expectedSequence !== this.webLoadSequence || this.isForumLoadTerminal(expectedSequence)) {
        return;
      }
      this.failForumLoad(expectedSequence, '暂时无法读取 4D4Y 主题，请检查网络后重试。');
    }
  }

  private resetTopicPermissionProbe(): void {
    this.topicPermissionProbeSequence += 1;
    this.clearTopicPermissionWatchdog();
    this.topicPermissionProbeForumId = '';
    this.topicPermissionProbeUrl = '';
    this.isTopicPermissionProbePending = false;
    this.canCreateTopicInCurrentForum = false;
    this.topicPermissionMessage = '';
    try {
      this.topicPermissionWebController.stop();
    } catch (_error) {
      // A previous probe can already be detached or complete.
    }
  }

  private startTopicPermissionProbe(forumId: string): void {
    if (!/^\d+$/.test(forumId) || !this.isSelectedForum(forumId)) {
      return;
    }
    this.topicPermissionProbeSequence += 1;
    const probeSequence: number = this.topicPermissionProbeSequence;
    this.clearTopicPermissionWatchdog();
    this.topicPermissionProbeForumId = forumId;
    this.topicPermissionProbeUrl = 'https://www.4d4y.com/forum/post.php?action=newthread&fid=' +
      forumId + '&mobile=no&oh_topic_probe=' + probeSequence;
    this.isTopicPermissionProbePending = true;
    this.canCreateTopicInCurrentForum = false;
    this.topicPermissionMessage = '';
    this.topicPermissionTimeoutId = setTimeout(() => {
      if (probeSequence === this.topicPermissionProbeSequence && this.isTopicPermissionProbePending) {
        this.failTopicPermissionProbe('发主题权限检查超时；请刷新当前版面后重试。');
        try {
          this.topicPermissionWebController.stop();
        } catch (_error) {
          // The probe might have finished while the timeout callback ran.
        }
      }
    }, 20000);
    if (!this.isTopicPermissionWebControllerAttached) {
      return;
    }
    try {
      this.topicPermissionWebController.loadUrl(this.topicPermissionProbeUrl);
    } catch (_error) {
      this.failTopicPermissionProbe('暂时无法检查当前版面的发主题权限。');
    }
  }

  private isCurrentTopicPermissionProbeRequest(url: string): boolean {
    const sequenceToken: RegExp = new RegExp('[?&]oh_topic_probe=' + this.topicPermissionProbeSequence + '(?:&|$)');
    return url.indexOf('/forum/post.php') >= 0 && url.indexOf('action=newthread') >= 0 &&
      url.indexOf('fid=' + this.topicPermissionProbeForumId) >= 0 && sequenceToken.test(url);
  }

  private async readTopicPermissionProbe(): Promise<void> {
    const expectedProbeSequence: number = this.topicPermissionProbeSequence;
    const expectedForumId: string = this.topicPermissionProbeForumId;
    try {
      const rawResult: string = await this.topicPermissionWebController.runJavaScript(
        this.getTopicPermissionProbeExtractionScript(expectedForumId, expectedProbeSequence)
      );
      if (!this.isTopicPermissionProbePending || expectedProbeSequence !== this.topicPermissionProbeSequence) {
        return;
      }
      const payload: ForumNewThreadPreflightPayload | null = parseForumNewThreadPreflightPayload(rawResult);
      if (payload === null || !isExpectedForumNewThreadPreflightPayload(payload, expectedForumId,
        expectedProbeSequence)) {
        this.failTopicPermissionProbe('当前版面的发主题权限无法确认。');
        return;
      }
      this.clearTopicPermissionWatchdog();
      this.isTopicPermissionProbePending = false;
      if (isReadyForumNewThreadForm(payload)) {
        this.canCreateTopicInCurrentForum = true;
        this.topicPermissionMessage = '';
        return;
      }
      this.canCreateTopicInCurrentForum = false;
      if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
        this.topicPermissionMessage = '登录状态已失效，暂时不能发主题。';
      } else if (payload.errorMessage.length > 0) {
        this.topicPermissionMessage = '当前版面只读：' + payload.errorMessage;
      } else if (payload.hasChallenge) {
        // A passive Cloudflare script alone is not an interactive verification.
        // Reaching this branch means neither a valid form nor an explicit server
        // decision was returned, so asking the user to verify is still useful.
        this.topicPermissionMessage = '请先完成论坛安全验证后刷新。';
      } else {
        this.topicPermissionMessage = '当前版面暂不允许发主题。';
      }
    } catch (_error) {
      if (expectedProbeSequence === this.topicPermissionProbeSequence && this.isTopicPermissionProbePending) {
        this.failTopicPermissionProbe('当前版面的发主题权限无法确认。');
      }
    }
  }

  private getTopicPermissionProbeExtractionScript(forumId: string, probeSequence: number): string {
    const safeForumId: string = JSON.stringify(forumId);
    return [
      '(() => {',
      '  const text = (node) => node ? (node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const challenge = document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0 || !!document.querySelector(".cf-turnstile");',
      '  const forms = Array.from(document.forms || []);',
      '  const form = forms.find((candidate) => {',
      '    try { const action = new URL(candidate.getAttribute("action") || location.href, location.href); return action.pathname.indexOf("/forum/post.php") >= 0 && action.searchParams.get("action") === "newthread"; } catch (_) { return false; }',
      '  }) || forms.find((candidate) => candidate.querySelector("input[name=subject]") && candidate.querySelector("textarea[name=message]"));',
      '  const alert = document.querySelector(".alert_info, .alert_error, #messagetext, .message");',
      '  return JSON.stringify({',
      '    forumId: ' + safeForumId + ', probeSequence: ' + probeSequence + ',',
      '    accessState: loginForm ? "loginRequired" : "available", hasChallenge: challenge,',
      '    formFound: !!form, formMethod: form ? (form.method || "get").toLowerCase() : "",',
      '    hasSubjectField: !!(form && form.querySelector("input[name=subject]")),',
      '    hasMessageField: !!(form && form.querySelector("textarea[name=message]")),',
      '    hasFormhashField: !!(form && form.querySelector("input[name=formhash]")),',
      '    hasPosttimeField: !!(form && form.querySelector("input[name=posttime]")),',
      '    hasWysiwygField: !!(form && form.querySelector("input[name=wysiwyg]")),',
      '    hasSubmitAction: !!(form && form.querySelector("input[type=submit], button[type=submit], input[name*=submit], button[name*=submit]")),',
      '    errorMessage: text(alert).slice(0, 180)',
      '  });',
      '})()'
    ].join('\n');
  }

  private failTopicPermissionProbe(message: string): void {
    this.clearTopicPermissionWatchdog();
    this.isTopicPermissionProbePending = false;
    this.canCreateTopicInCurrentForum = false;
    this.topicPermissionMessage = message;
  }

  private clearTopicPermissionWatchdog(): void {
    if (this.topicPermissionTimeoutId >= 0) {
      clearTimeout(this.topicPermissionTimeoutId);
      this.topicPermissionTimeoutId = -1;
    }
  }

  private isCurrentForumRequest(url: string): boolean {
    return this.isHomeAlive && isCurrentFourD4yWebRequest(url, '/forum/forumdisplay.php', this.webLoadSequence);
  }

  private isForumLoadTerminal(sequence: number = this.webLoadSequence): boolean {
    return this.terminalLoadSequence === sequence;
  }

  private startForumLoadWatchdog(sequence: number): void {
    this.clearForumLoadWatchdog();
    this.terminalLoadSequence = 0;
    this.webLoadTimeoutId = setTimeout(() => {
      if (sequence !== this.webLoadSequence || this.isForumLoadTerminal(sequence)) {
        return;
      }
      this.failForumLoad(sequence, '读取 4D4Y 主题超时，请重试。');
      try {
        this.forumWebController.stop();
      } catch (_error) {
        // The Web controller can already be detached when the timeout fires.
      }
    }, this.webLoadTimeoutMillis);
  }

  private clearForumLoadWatchdog(): void {
    if (this.webLoadTimeoutId >= 0) {
      clearTimeout(this.webLoadTimeoutId);
      this.webLoadTimeoutId = -1;
    }
  }

  private finishForumLoad(sequence: number): void {
    if (sequence !== this.webLoadSequence) {
      return;
    }
    this.clearForumLoadWatchdog();
    this.terminalLoadSequence = sequence;
    if (this.isAppendingForumPage) {
      this.isLoadingMore = false;
    } else {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private failForumLoad(sequence: number, message: string): void {
    if (sequence !== this.webLoadSequence) {
      return;
    }
    this.finishForumLoad(sequence);
    if (this.isAppendingForumPage) {
      this.loadMoreError = message;
    } else {
      this.loadError = message;
    }
  }

  private async refreshLoginState(): Promise<void> {
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    const loggedIn: boolean = await FourD4ySession.isLoggedIn();
    if (!this.isHomeAlive || sessionGeneration !== this.accountState.getSessionGeneration()) {
      return;
    }
    this.isLoggedIn = loggedIn;
    if (this.isLoggedIn) {
      void this.refreshUnreadPromptCounts();
    } else {
      this.unreadState.clear();
    }
  }

  @Builder
  private buildUnreadReminderFab() {
    // Match the thread reader's floating action layout: the alignment must be
    // relative to a full reader-sized overlay, not to the icon's own bounds.
    // NG's `fab_notification` is a mini FAB anchored at bottom centre with a
    // 16dp margin. Keep that independent from the regular refresh/reply FAB.
    Stack({ alignContent: Alignment.Bottom }) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.privateMessageUnreadCount > 0 ? $r('app.media.drawer_message') : $r('app.media.drawer_notice'))
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.drawer_text'))
    }
    .width(40)
    .height(40)
    .backgroundColor($r('app.color.unread_fab'))
    .borderRadius(20)
    .shadow({ radius: 6, color: $r('app.color.unread_fab_shadow'), offsetX: 0, offsetY: 2 })
    .onClick(() => {
      this.openUnreadReminder();
    })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private hasUnreadReminder(): boolean {
    return this.privateMessageUnreadCount > 0 || this.informationReminderUnreadCount > 0;
  }

  private formatUnreadCount(value: number): string {
    return value > 99 ? '99+' : String(value);
  }

  private openUnreadReminder(): void {
    if (this.privateMessageUnreadCount > 0) {
      this.pathStack.pushPathByName('MessageCenter',
        createMessageCenterRouteParams(FourD4yMessageMode.PrivateMessages), (_result: PopInfo) => {
          void this.refreshLoginState();
        });
      return;
    }
    if (this.informationReminderUnreadCount > 0) {
      this.pathStack.pushPathByName('MessageCenter',
        createMessageCenterRouteParams(FourD4yMessageMode.ThreadNotices), (_result: PopInfo) => {
          void this.refreshLoginState();
        });
    }
  }

  private subscribeUnreadState(): void {
    if (this.unreadStateListenerId > 0) {
      return;
    }
    this.unreadStateListenerId = this.unreadState.subscribe(() => {
      this.syncUnreadState();
    });
    this.syncUnreadState();
  }

  private subscribeObservedReplyCounts(): void {
    this.observedReplyCounts.syncSession(this.accountState.getSessionGeneration());
    if (this.observedReplyCountListenerId > 0) {
      return;
    }
    this.observedReplyCountListenerId = this.observedReplyCounts.subscribe(() => {
      this.observedReplyCountRevision += 1;
    });
    this.observedReplyCountRevision += 1;
  }

  private unsubscribeObservedReplyCounts(): void {
    if (this.observedReplyCountListenerId > 0) {
      this.observedReplyCounts.unsubscribe(this.observedReplyCountListenerId);
      this.observedReplyCountListenerId = -1;
    }
  }

  private displayReplyCount(thread: ThreadSummary): number {
    // Keep the subscription revision in this ArkUI expression so returning
    // from a thread redraws its corrected row without a board-wide reload.
    const revision: number = this.observedReplyCountRevision;
    if (revision < 0) {
      return thread.replyCount;
    }
    return this.observedReplyCounts.resolve(thread.id, thread.replyCount);
  }

  private unsubscribeUnreadState(): void {
    if (this.unreadStateListenerId > 0) {
      this.unreadState.unsubscribe(this.unreadStateListenerId);
      this.unreadStateListenerId = -1;
    }
  }

  private syncUnreadState(): void {
    this.privateMessageUnreadCount = this.unreadState.getPrivateMessageCount();
    this.informationReminderUnreadCount = this.unreadState.getInformationReminderCount();
  }

  /** Refresh only when the ability returns to foreground; no background polling. */
  private onForegroundGenerationChanged(): void {
    if (this.appForegroundGeneration <= this.lastObservedForegroundGeneration) {
      return;
    }
    this.lastObservedForegroundGeneration = this.appForegroundGeneration;
    void this.refreshLoginState();
  }

  private async refreshUnreadPromptCounts(): Promise<void> {
    if (!this.isHomeAlive || !this.isLoggedIn || this.isUnreadPromptLoading) {
      return;
    }
    const expectedSequence: number = this.unreadPromptSequence + 1;
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    this.unreadPromptSequence = expectedSequence;
    this.isUnreadPromptLoading = true;
    const sharedRefresh: number = this.unreadState.beginRefresh();
    try {
      const result: FourD4yNativeMessagePromptResult = await this.messageClient.loadPrompt(expectedSequence);
      if (this.unreadPromptSequence !== expectedSequence ||
        !this.unreadState.isCurrentRefresh(sharedRefresh) ||
        sessionGeneration !== this.accountState.getSessionGeneration()) {
        return;
      }
      if (result.status === 'cookie-missing' || result.status === 'server-login-required') {
        this.isLoggedIn = false;
        this.unreadState.clear();
        return;
      }
      const payload: FourD4yMessagePromptPayload | null = result.payload;
      if (result.status !== 'success' || payload === null ||
        !isExpectedFourD4yMessagePromptPayload(payload, expectedSequence)) {
        return;
      }
      if (payload.accessState === 'loginRequired') {
        this.isLoggedIn = false;
        this.unreadState.clear();
        return;
      }
      this.isLoggedIn = true;
      this.unreadState.observeServerCounts(payload.privateMessageCount, payload.threadNoticeCount,
        payload.systemNoticeCount, payload.friendNoticeCount);
    } catch (_error) {
      // A failed enhancement refresh must not discard the last forum-confirmed counts.
    } finally {
      if (this.unreadPromptSequence === expectedSequence) {
        this.isUnreadPromptLoading = false;
      }
    }
  }
}
