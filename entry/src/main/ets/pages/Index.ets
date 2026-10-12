import { HomePage } from '../presentation/home/HomePage';
import { common } from '@kit.AbilityKit';
import { ForumComposerPage } from '../presentation/composer/ForumComposerPage';
import { FavoritesPage } from '../presentation/favorite/FavoritesPage';
import { AttentionPage } from '../presentation/attention/AttentionPage';
import { SearchPage } from '../presentation/search/SearchPage';
import { MyContentPage } from '../presentation/mine/MyContentPage';
import { MessageCenterPage } from '../presentation/notice/MessageCenterPage';
import { PrivateMessageDetailPage } from '../presentation/notice/PrivateMessageDetailPage';
import { LoginPage } from '../presentation/login/LoginPage';
import { ThreadDetailPage } from '../presentation/thread/ThreadDetailPage';
import { UserProfilePage } from '../presentation/profile/UserProfilePage';
import { BlacklistPage } from '../presentation/blacklist/BlacklistPage';
import { SettingsPage } from '../presentation/settings/SettingsPage';
import { AboutPage } from '../presentation/about/AboutPage';
import { PrivacyPolicyPage } from '../presentation/privacy/PrivacyPolicyPage';
import { ReadingHistoryPage } from '../presentation/history/ReadingHistoryPage';
import { WebContentPage } from '../presentation/web/WebContentPage';
import { AccountPage } from '../presentation/account/AccountPage';
import { WebRouteState } from '../presentation/web/WebRouteState';
import { ImageViewerPage } from '../presentation/image/ImageViewerPage';
import { ImageViewerRouteState } from '../presentation/image/ImageViewerRouteState';
import { FourD4yFavoriteState } from '../domain/favorite/FourD4yFavoriteState';
import { FourD4yAttentionState } from '../domain/attention/FourD4yAttentionState';
import { FourD4yBlacklistState } from '../domain/blacklist/FourD4yBlacklistState';
import { FourD4yReadHistoryState } from '../domain/history/FourD4yReadHistoryState';
import { FourD4yAccountState } from '../domain/account/FourD4yAccountState';
import { FourD4yAccountService } from '../domain/account/FourD4yAccountService';
import { FourD4yUnreadState } from '../domain/notice/FourD4yUnreadState';
import { FourD4yObservedReplyCounts } from '../domain/thread/FourD4yObservedReplyCounts';
import { FourD4yThreadMutationState } from '../domain/thread/FourD4yThreadMutationState';
import { FourD4yPrivacyConsentStore } from '../data/local/FourD4yPrivacyConsentStore';
import { FOUR_D4Y_PRIVACY_CONTACT, FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT,
  FOUR_D4Y_PRIVACY_POLICY_SECTIONS, FourD4yPrivacyPolicySection } from '../domain/privacy/FourD4yPrivacyPolicy';

@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  @Provide('webRoute') webRoute: WebRouteState = new WebRouteState();
  @Provide('imageViewerRoute') imageViewerRoute: ImageViewerRouteState = new ImageViewerRouteState();
  @Provide('authState') authState: boolean = false;
  @Provide('favoriteState') favoriteState: FourD4yFavoriteState = new FourD4yFavoriteState();
  @Provide('attentionState') attentionState: FourD4yAttentionState = new FourD4yAttentionState();
  @Provide('blacklistState') blacklistState: FourD4yBlacklistState = new FourD4yBlacklistState();
  @Provide('readHistoryState') readHistoryState: FourD4yReadHistoryState = new FourD4yReadHistoryState();
  @Provide('accountState') accountState: FourD4yAccountState = new FourD4yAccountState();
  @Provide('unreadState') unreadState: FourD4yUnreadState = new FourD4yUnreadState();
  @Provide('observedReplyCounts') observedReplyCounts: FourD4yObservedReplyCounts =
    new FourD4yObservedReplyCounts();
  @Provide('threadMutationState') threadMutationState: FourD4yThreadMutationState = new FourD4yThreadMutationState();
  @StorageLink('hipdaoh_privacy_accepted') privacyAccepted: boolean = false;
  @State privacyReady: boolean = false;
  @State isAcceptingPrivacyPolicy: boolean = false;
  @State isRejectingPrivacyPolicy: boolean = false;
  @State privacyErrorMessage: string = '';
  @State isPolicyDetailVisible: boolean = false;
  private isIndexAlive: boolean = false;

  aboutToAppear(): void {
    this.isIndexAlive = true;
    void this.loadPrivacyConsent();
  }

  aboutToDisappear(): void {
    this.isIndexAlive = false;
  }

  @Builder
  private routeMap(routeName: string) {
    if (routeName === 'ThreadDetail') {
      ThreadDetailPage();
    } else if (routeName === 'UserProfile') {
      UserProfilePage();
    } else if (routeName === 'Blacklist') {
      BlacklistPage();
    } else if (routeName === 'ForumComposer') {
      ForumComposerPage();
    } else if (routeName === 'WebContent') {
      WebContentPage();
    } else if (routeName === 'ImageViewer') {
      ImageViewerPage();
    } else if (routeName === 'Login') {
      LoginPage();
    } else if (routeName === 'Favorites') {
      FavoritesPage();
    } else if (routeName === 'Attention') {
      AttentionPage();
    } else if (routeName === 'Search') {
      SearchPage();
    } else if (routeName === 'MyContent') {
      MyContentPage();
    } else if (routeName === 'MessageCenter') {
      MessageCenterPage();
    } else if (routeName === 'PrivateMessageDetail') {
      PrivateMessageDetailPage();
    } else if (routeName === 'Settings') {
      SettingsPage();
    } else if (routeName === 'About') {
      AboutPage();
    } else if (routeName === 'PrivacyPolicy') {
      PrivacyPolicyPage();
    } else if (routeName === 'ReadingHistory') {
      ReadingHistoryPage();
    } else if (routeName === 'Account') {
      AccountPage();
    }
  }

  build() {
    if (!this.privacyReady) {
      this.buildPrivacyLoading();
    } else if (!this.privacyAccepted) {
      this.buildPrivacyConsent();
    } else {
      Navigation(this.pathStack) {
        HomePage();
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .navDestination(this.routeMap)
    }
  }

  @Builder
  private buildPrivacyLoading() {
    Column({ space: 10 }) {
      LoadingProgress().width(28).height(28);
      Text('正在准备应用…')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.canvas'));
  }

  @Builder
  private buildPrivacyConsent() {
    Scroll() {
      Column({ space: 16 }) {
        Text('隐私政策')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%');
        Text('HiPDA·OH 在进入论坛前需要你的同意。应用会按你的操作访问 4D4Y，显示论坛内容；登录并保存帐号时，会将会话快照保存在系统 Asset Store 加密存储中。本地还会保存显示偏好与阅读历史。')
          .fontSize(15)
          .fontColor($r('app.color.text_body'))
          .lineHeight(23)
          .width('100%');
        Text('应用不保存论坛密码；不集成广告、统计、推送或帐号 SDK；不申请广泛相册、定位、通讯录、相机、麦克风或通知权限。你主动选择图片并确认上传时，才会经系统 Picker 读取该图片并上传至 4D4Y。')
          .fontSize(15)
          .fontColor($r('app.color.text_body'))
          .lineHeight(23)
          .width('100%');
        Text(this.isPolicyDetailVisible ? '收起完整隐私政策' : '阅读完整隐私政策')
          .fontSize(15)
          .fontColor($r('app.color.brand'))
          .width('100%')
          .onClick(() => {
            this.isPolicyDetailVisible = !this.isPolicyDetailVisible;
          });
        if (this.isPolicyDetailVisible) {
          Text('开发者：sis5595；联系邮箱：' + FOUR_D4Y_PRIVACY_CONTACT +
            '；更新日期：' + FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT + '。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.fill_subtle'));
          ForEach(FOUR_D4Y_PRIVACY_POLICY_SECTIONS, (section: FourD4yPrivacyPolicySection) => {
            this.buildPrivacyPolicySection(section);
          }, (section: FourD4yPrivacyPolicySection) => section.title);
        }
        if (this.privacyErrorMessage.length > 0) {
          Text(this.privacyErrorMessage)
            .fontSize(13)
            .fontColor($r('app.color.danger_text'))
            .width('100%');
        }
        Button(this.isAcceptingPrivacyPolicy ? '正在确认…' : '同意并继续')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor($r('app.color.brand'))
          .enabled(!this.isAcceptingPrivacyPolicy && !this.isRejectingPrivacyPolicy)
          .onClick(() => {
            void this.acceptPrivacyPolicy();
          });
        Button(this.isRejectingPrivacyPolicy ? '正在退出…' : '不同意并退出')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .backgroundColor($r('app.color.fill_subtle'))
          .height(44)
          .enabled(!this.isAcceptingPrivacyPolicy && !this.isRejectingPrivacyPolicy)
          .onClick(() => {
            void this.rejectPrivacyPolicy();
          });
        Text('未同意前，应用不会进入论坛或读取已保存帐号。你可以关闭应用，或稍后再同意。')
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 36, bottom: 28 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.canvas'));
  }

  @Builder
  private buildPrivacyPolicySection(section: FourD4yPrivacyPolicySection) {
    Column({ space: 5 }) {
      Text(section.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
      Text(section.content)
        .fontSize(13)
        .fontColor($r('app.color.text_body'))
        .lineHeight(20)
        .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  private async loadPrivacyConsent(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const accepted: boolean = await FourD4yPrivacyConsentStore.hasAcceptedCurrentPolicy(context);
      if (accepted && this.isIndexAlive) {
        await FourD4yAccountService.restoreStartupSession(context, () => this.isIndexAlive);
      }
      if (!this.isIndexAlive) {
        return;
      }
      AppStorage.setOrCreate<boolean>('hipdaoh_privacy_accepted', accepted);
      AppStorage.set<boolean>('hipdaoh_privacy_accepted', accepted);
    } catch (_error) {
      if (!this.isIndexAlive) {
        return;
      }
      AppStorage.setOrCreate<boolean>('hipdaoh_privacy_accepted', false);
      AppStorage.set<boolean>('hipdaoh_privacy_accepted', false);
    }
    this.privacyReady = true;
  }

  private async acceptPrivacyPolicy(): Promise<void> {
    if (!this.isIndexAlive || this.isAcceptingPrivacyPolicy || this.isRejectingPrivacyPolicy) {
      return;
    }
    this.privacyErrorMessage = '';
    this.isAcceptingPrivacyPolicy = true;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const accepted: boolean = await FourD4yPrivacyConsentStore.acceptCurrentPolicy(context);
      if (!this.isIndexAlive) {
        return;
      }
      if (!accepted) {
        this.privacyErrorMessage = '无法保存你的选择，请稍后重试。';
        this.isAcceptingPrivacyPolicy = false;
        return;
      }
      await FourD4yAccountService.restoreStartupSession(context, () => this.isIndexAlive);
      if (!this.isIndexAlive) {
        return;
      }
      AppStorage.set<boolean>('hipdaoh_privacy_accepted', true);
    } catch (_error) {
      if (!this.isIndexAlive) {
        return;
      }
      this.privacyErrorMessage = '无法保存你的选择，请稍后重试。';
    }
    this.isAcceptingPrivacyPolicy = false;
  }

  private async rejectPrivacyPolicy(): Promise<void> {
    if (!this.isIndexAlive || this.isAcceptingPrivacyPolicy || this.isRejectingPrivacyPolicy) {
      return;
    }
    this.isRejectingPrivacyPolicy = true;
    this.privacyErrorMessage = '';
    // Keep the gate closed even if terminating the ability fails. No account or Web is started.
    AppStorage.set<boolean>('hipdaoh_privacy_accepted', false);
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.terminateSelf();
    } catch (_error) {
      if (this.isIndexAlive) {
        this.privacyErrorMessage = '未同意隐私政策，论坛功能保持关闭。退出失败，请返回桌面或重试。';
        this.isRejectingPrivacyPolicy = false;
      }
    }
  }

}
