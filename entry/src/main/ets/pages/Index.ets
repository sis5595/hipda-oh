import { HomePage } from '../presentation/home/HomePage';
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
import { FourD4yUnreadState } from '../domain/notice/FourD4yUnreadState';

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
    } else if (routeName === 'ReadingHistory') {
      ReadingHistoryPage();
    } else if (routeName === 'Account') {
      AccountPage();
    }
  }

  build() {
    Navigation(this.pathStack) {
      HomePage();
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .navDestination(this.routeMap)
  }

}
