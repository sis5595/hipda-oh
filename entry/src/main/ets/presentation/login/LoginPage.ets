import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';
import { FourD4yAccountIdentity, parseFourD4yAccountIdentity } from '../../domain/account/FourD4yAccountContracts';
import { FourD4yAccountSaveResult, FourD4yAccountService } from '../../domain/account/FourD4yAccountService';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { FourD4yUnreadState } from '../../domain/notice/FourD4yUnreadState';
import { common } from '@kit.AbilityKit';

class LoginPagePopResult {
  changed: boolean = true;
}

@Component
export struct LoginPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('blacklistState') blacklistState: FourD4yBlacklistState;
  @Consume('accountState') accountState: FourD4yAccountState;
  @Consume('unreadState') unreadState: FourD4yUnreadState;
  @State status: string = '请直接在 4D4Y 页面完成完整站点登录，账号和密码不会经过 HiPDA。';
  @State rejectedSession: boolean = false;

  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private readonly loginUrl: string = FourD4ySession.forumRoot + 'logging.php?action=login';
  private isControllerAttached: boolean = false;
  private hasInitialLoadStarted: boolean = false;
  private hasPersistedVerifiedLogin: boolean = false;
  private hasSavedAccountSession: boolean = false;
  private accountSaveStatus: string = '';

  aboutToAppear(): void {
    this.refreshLoginState();
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          Text(this.status)
            .fontSize(13)
            .fontColor(this.isLoggedIn ? $r('app.color.success_text') : $r('app.color.text_secondary'))
            .layoutWeight(1)
            .maxLines(2)

          if (!this.isLoggedIn && this.rejectedSession) {
            Button('重新登录')
              .fontSize(14)
              .onClick(() => {
                this.startNewLogin();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.isLoggedIn ? $r('app.color.success_background') : $r('app.color.canvas'))

        Web({ src: '', controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onlineImageAccess(true)
          .onControllerAttached(() => {
            this.onControllerAttached();
          })
          .onPageEnd(() => {
            this.refreshLoginState();
          })
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .title('登录 4D4Y')
    .menus(this.buildTitleActions)
  }

  @Builder
  private buildTitleActions() {
    if (this.isLoggedIn) {
      Text('完成')
        .fontSize(15)
        .fontColor($r('app.color.brand'))
        .height(42)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          // AccountPage restores its controls from the Navigation callback.
          this.pathStack.pop(new LoginPagePopResult());
        })
    }
  }

  private async refreshLoginState(): Promise<void> {
    const hasSessionCookie: boolean = await FourD4ySession.isLoggedIn();
    let loggedIn: boolean = false;
    let scriptExecuted: boolean = false;
    if (hasSessionCookie) {
      try {
        const result: string = await this.controller.runJavaScript(
          `(() => { const has = (text) => document.querySelectorAll('a').length > 0 && Array.from(document.querySelectorAll('a')).some((link) => (link.getAttribute('href') || '').indexOf(text) >= 0); return [has('space.php'), has('action=logout'), has('action=login')].map((value) => value ? '1' : '0').join(''); })()`
        );
        scriptExecuted = true;
        const markerMatch: RegExpMatchArray | null = result.match(new RegExp('[01]{3}'));
        const markers: string = markerMatch === null ? '' : markerMatch[0];
        loggedIn = markers.length === 3 && (markers.charAt(0) === '1' || markers.charAt(1) === '1');
      } catch (_error) {
        // The controller is not attached until the Web component has loaded.
      }
    }
    this.isLoggedIn = loggedIn;
    if (loggedIn && !this.hasPersistedVerifiedLogin) {
      await FourD4ySession.persistVerifiedAuthentication();
      this.hasPersistedVerifiedLogin = true;
      await this.saveVerifiedAccountSession();
    }
    if (!loggedIn) {
      this.hasPersistedVerifiedLogin = false;
      this.hasSavedAccountSession = false;
      this.accountSaveStatus = '';
    }
    this.rejectedSession = hasSessionCookie && scriptExecuted && !loggedIn;
    if (loggedIn) {
      this.status = this.accountSaveStatus || '登录成功，完整站点会话已保存在本应用内。';
    } else if (hasSessionCookie) {
      this.status = scriptExecuted ? '当前会话不是完整站点会话，请重新登录一次。' : '正在核验 4D4Y 登录会话…';
    } else {
      this.status = '请直接在 4D4Y 页面完成完整站点登录，账号和密码不会经过 HiPDA。';
    }
  }

  private onControllerAttached(): void {
    this.isControllerAttached = true;
    try {
      // UA must be configured before the first load. This normal ArkWeb
      // container is the only session shared by reading and native requests.
      this.controller.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      this.startInitialLoadWhenReady();
    } catch (_error) {
      this.status = '无法初始化完整站点登录页，请关闭后重试。';
    }
  }

  private startInitialLoadWhenReady(): void {
    if (!this.isControllerAttached || this.hasInitialLoadStarted) {
      return;
    }
    this.hasInitialLoadStarted = true;
    try {
      this.controller.loadUrl(this.loginUrl);
    } catch (_error) {
      this.status = '无法打开 4D4Y 登录页，请检查网络后重试。';
    }
  }

  private async startNewLogin(): Promise<void> {
    this.status = '正在清除失效的 4D4Y 会话…';
    try {
      await FourD4ySession.clearPersistentAuthentication();
      this.isLoggedIn = false;
      this.blacklistState.clearServerSnapshot();
      this.unreadState.clear();
      this.hasSavedAccountSession = false;
      this.accountSaveStatus = '';
      this.rejectedSession = false;
      this.status = '请直接在 4D4Y 页面完成完整站点登录，账号和密码不会经过 HiPDA。';
      this.controller.loadUrl(this.loginUrl);
    } catch (_error) {
      this.status = '无法重置当前会话，请关闭页面后重试。';
    }
  }

  /**
   * Projects only the visible self-profile link from the already verified
   * 4D4Y page. No DOM/HTML is retained; the result is used only to name the
   * encrypted session asset's non-sensitive registry row.
   */
  private async saveVerifiedAccountSession(): Promise<void> {
    if (this.hasSavedAccountSession) {
      return;
    }
    try {
      const rawIdentity: string = await this.controller.runJavaScript(
        `(() => { const links = Array.from(document.querySelectorAll('a[href*="space.php?uid="]')); const link = links.find((item) => /[?&]uid=\\d+/.test(item.getAttribute('href') || '')); if (!link) return ''; const match = (link.getAttribute('href') || '').match(/[?&]uid=(\\d{1,16})/); return match ? JSON.stringify({ userId: match[1], displayName: (link.textContent || '').trim() }) : ''; })()`
      );
      const identity: FourD4yAccountIdentity | null = parseFourD4yAccountIdentity(rawIdentity);
      if (identity === null) {
        return;
      }
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const result: FourD4yAccountSaveResult = await FourD4yAccountService.saveVerifiedCurrentSession(context, identity);
      if (result === FourD4yAccountSaveResult.Saved) {
        this.hasSavedAccountSession = true;
        this.accountState.markSessionChanged();
      } else if (result === FourD4yAccountSaveResult.AccountLimit) {
        this.accountSaveStatus = '登录成功；已保存四个账号，请先在账号管理中移除一个再添加。';
      } else if (result === FourD4yAccountSaveResult.StorageFailed) {
        this.accountSaveStatus = '登录成功；安全保存账号会话失败，本次仍可正常使用。';
      }
    } catch (_error) {
      // Login remains valid even when account metadata cannot be projected.
      // No raw cookie or page value is included in this failure path.
    }
  }
}
