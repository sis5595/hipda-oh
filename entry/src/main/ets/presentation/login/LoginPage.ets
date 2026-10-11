import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';
import { FourD4yAccountIdentity, parseFourD4yAccountIdentity } from '../../domain/account/FourD4yAccountContracts';
import { FourD4yAccountSaveResult, FourD4yAccountService } from '../../domain/account/FourD4yAccountService';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { FourD4yUnreadState } from '../../domain/notice/FourD4yUnreadState';
import { FourD4yFavoriteState } from '../../domain/favorite/FourD4yFavoriteState';
import { FourD4yAttentionState } from '../../domain/attention/FourD4yAttentionState';
import { common } from '@kit.AbilityKit';
import { buildFourD4yAccountIdentityScript } from '../../domain/account/FourD4yAccountIdentityScript';
import { LoginRouteParams } from './LoginRouteState';
import { buildFourD4yLoginPresentationScript } from './FourD4yLoginPresentation';

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
  @Consume('favoriteState') favoriteState: FourD4yFavoriteState;
  @Consume('attentionState') attentionState: FourD4yAttentionState;
  @State status: string = '正在准备登录…';
  @State rejectedSession: boolean = false;
  @State isVerifying: boolean = true;
  @State loadFailed: boolean = false;
  @State compactLogin: boolean = true;
  @State presentationReady: boolean = false;

  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private readonly loginUrl: string = FourD4ySession.forumRoot + 'logging.php?action=login';
  private isControllerAttached: boolean = false;
  private hasInitialLoadStarted: boolean = false;
  private hasPersistedVerifiedLogin: boolean = false;
  private hasSavedAccountSession: boolean = false;
  private accountSaveStatus: string = '';
  private verificationSequence: number = 0;
  private expectedUserId: string = '';
  private lastVerifiedUserId: string = '';
  private isPageActive: boolean = false;
  private loadingUrl: string = '';
  private loadSequence: number = 0;
  private loadTimeoutId: number = -1;

  aboutToAppear(): void {
    this.isPageActive = true;
    this.verificationSequence++;
  }

  aboutToDisappear(): void {
    this.isPageActive = false;
    this.clearLoadWatchdog();
    this.verificationSequence++;
  }

  build() {
    NavDestination() {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#99000000')
          .onClick(() => this.closeLoginPage())
        Column() {
          if (!this.compactLogin) {
            Row() {
              Text('4D4Y 登录 / 安全验证').fontSize(15).layoutWeight(1)
              Text('关闭').fontSize(14).onClick(() => this.closeLoginPage())
            }
            .width('100%')
            .padding(14)
          }
          if (this.loadFailed || this.rejectedSession || this.accountSaveStatus.length > 0 || !this.compactLogin) {
            Row({ space: 12 }) {
              Text(this.status)
                .fontSize(13)
                .fontColor(this.isLoggedIn ? $r('app.color.success_text') : $r('app.color.text_secondary'))
                .layoutWeight(1)
                .maxLines(2)

              if (this.loadFailed) {
                Button('重试')
                  .fontSize(14)
                  .onClick(() => this.retryLoginPage())
              } else if (!this.isLoggedIn && this.rejectedSession) {
                Button('重新登录')
                  .fontSize(14)
                  .enabled(!this.isVerifying)
                  .onClick(() => {
                    this.startNewLogin();
                  })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(this.isLoggedIn ? $r('app.color.success_background') : $r('app.color.canvas'))
          }

          Stack() {
            Web({ src: '', controller: this.controller })
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .onlineImageAccess(true)
              // Full-site UA is needed for shared authentication, but it has no
              // Mobile marker. Enable viewport instead of changing login UA.
              .metaViewport(true)
              .onControllerAttached(() => {
                this.onControllerAttached();
              })
              .onPageEnd((event) => {
                this.finishLoginLoad(event.url);
              })
              .onPageBegin((event) => {
                this.beginLoginLoad(event.url);
              })
              .onErrorReceive((event) => {
                if (event.request.isMainFrame()) {
                  this.failLoginLoad(event.request.getRequestUrl());
                }
              })
              .onHttpErrorReceive((event) => {
                if (event.request.isMainFrame() && event.response.getResponseCode() >= 400) {
                  this.failLoginLoad(event.request.getRequestUrl());
                }
              })
              .width('100%')
              .height('100%')
              .opacity(this.presentationReady ? 1 : 0)
              .hitTestBehavior(this.presentationReady ? HitTestMode.Default : HitTestMode.None)
            if (!this.presentationReady && !this.loadFailed) {
              Column({ space: 12 }) {
                LoadingProgress().width(28).height(28)
                Text(this.status).fontSize(14).fontColor($r('app.color.text_secondary')).maxLines(3)
              }
              .padding(20)
            }
          }
          .width('100%')
          .layoutWeight(1)
          if (this.isLoggedIn && !this.isVerifying && !this.loadFailed) {
            this.buildTitleActions();
          }
        }
        .width(this.compactLogin ? '78%' : '94%')
        .constraintSize({ maxWidth: this.compactLogin ? 360 : 10000 })
        .height(this.compactLogin ? 346 : '94%')
        .backgroundColor(Color.White)
        .borderRadius(2)
        .clip(true)
        .shadow({ radius: 16, color: '#33000000', offsetY: 8 })
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavDestinationMode.DIALOG)
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
    .onBackPressed(() => this.closeLoginPage())
    .onReady((context: NavDestinationContext) => {
      const route: LoginRouteParams | null = context.pathInfo.param as LoginRouteParams | null;
      this.expectedUserId = route !== null && route !== undefined && /^\d{1,16}$/.test(route.expectedUserId) ?
        route.expectedUserId : '';
    })
  }

  @Builder
  private buildTitleActions() {
    if (this.isLoggedIn && !this.isVerifying && !this.loadFailed) {
      Text('完成')
        .fontSize(15)
        .fontColor($r('app.color.brand'))
        .height(42)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          // AccountPage restores its controls from the Navigation callback.
          this.closeLoginPage();
        })
    }
  }

  private closeLoginPage(): boolean {
    if (!this.isPageActive) return true;
    this.isPageActive = false;
    this.clearLoadWatchdog();
    this.verificationSequence++;
    this.pathStack.pop(new LoginPagePopResult());
    return true;
  }

  private clearLoadWatchdog(): void {
    // Also invalidate a timeout callback that has already entered the event queue.
    this.loadSequence++;
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  private beginLoginLoad(url: string): void {
    if (!this.isPageActive || url.length === 0 || url === 'about:blank') return;
    this.clearLoadWatchdog();
    this.loadingUrl = url;
    this.loadFailed = false;
    this.presentationReady = false;
    this.isVerifying = true;
    this.verificationSequence++;
    const sequence: number = ++this.loadSequence;
    this.loadTimeoutId = setTimeout(() => {
      if (!this.isPageActive || sequence !== this.loadSequence) return;
      this.failLoginLoad(url);
      try {
        this.controller.stop();
      } catch (_error) {
        // The page may have detached while the timeout callback was queued.
      }
    }, 30000);
  }

  private async finishLoginLoad(url: string): Promise<void> {
    if (!this.isPageActive || this.loadFailed || url !== this.loadingUrl) return;
    this.clearLoadWatchdog();
    const sequence: number = this.loadSequence;
    let compact: boolean = false;
    try {
      const result: string = await this.controller.runJavaScript(buildFourD4yLoginPresentationScript());
      compact = result === 'compact' || result === '"compact"';
    } catch (_error) {
      // Unknown templates and challenges remain usable in the forum fallback.
    }
    if (!this.isPageActive || this.loadFailed || url !== this.loadingUrl || sequence !== this.loadSequence) return;
    await this.refreshLoginState();
    if (this.isPageActive && !this.loadFailed && url === this.loadingUrl && sequence === this.loadSequence) {
      // Verified login closes above. Do not expand to a desktop-page fallback
      // for the brief interval while its account/session is being checked.
      this.compactLogin = compact;
      this.presentationReady = true;
    }
  }

  private failLoginLoad(url: string): void {
    if (!this.isPageActive || this.loadFailed || url !== this.loadingUrl) return;
    this.clearLoadWatchdog();
    this.verificationSequence++;
    this.isVerifying = false;
    this.loadFailed = true;
    this.presentationReady = false;
    // A transport error does not prove logout. Keep cookies and account state.
    this.status = '登录页加载失败或超时，请检查网络后重试；不会自动重复提交登录。';
  }

  private retryLoginPage(): void {
    if (!this.isPageActive || !this.isControllerAttached) return;
    this.beginLoginLoad(this.loginUrl);
    try {
      // Always a new GET of the login entry, never refresh a submitted form.
      this.controller.loadUrl(this.loginUrl);
    } catch (_error) {
      this.failLoginLoad(this.loginUrl);
    }
  }

  private async refreshLoginState(): Promise<void> {
    const sequence: number = ++this.verificationSequence;
    const sessionGeneration: number = this.accountState.getSessionGeneration();
    this.isVerifying = true;
    const verifiedSecret: string | null = await FourD4ySession.captureAccountSessionSecret();
    const hasSessionCookie: boolean = verifiedSecret !== null;
    if (sequence !== this.verificationSequence) {
      return;
    }
    let loggedIn: boolean = false;
    let scriptExecuted: boolean = false;
    let identity: FourD4yAccountIdentity | null = null;
    if (hasSessionCookie) {
      try {
        const result: string = await this.controller.runJavaScript(
          buildFourD4yAccountIdentityScript()
        );
        scriptExecuted = true;
        identity = parseFourD4yAccountIdentity(result);
        loggedIn = identity !== null;
      } catch (_error) {
        // The controller is not attached until the Web component has loaded.
      }
    }
    if (sequence !== this.verificationSequence) {
      return;
    }
    if (identity !== null && verifiedSecret !== null &&
      (!await FourD4ySession.isCurrentAccountSessionSecret(verifiedSecret) ||
      sessionGeneration !== this.accountState.getSessionGeneration())) {
      if (sequence === this.verificationSequence) {
        this.isLoggedIn = false;
        this.isVerifying = false;
        this.status = '会话在校验期间发生变化，请重新打开登录页核验。';
      }
      return;
    }
    if (sequence !== this.verificationSequence) {
      return;
    }
    if (identity !== null && this.expectedUserId.length > 0 && identity.userId !== this.expectedUserId) {
      this.isLoggedIn = false;
      this.rejectedSession = true;
      this.isVerifying = false;
      this.status = '网站返回的账号与所选账号不一致，请重新登录所选账号。';
      return;
    }
    if (identity !== null && identity.userId !== this.lastVerifiedUserId) {
      this.hasPersistedVerifiedLogin = false;
      this.hasSavedAccountSession = false;
      this.accountSaveStatus = '';
      this.lastVerifiedUserId = identity.userId;
    }
    // The ordinary website also exposes logout. Once this page has verified
    // a login, a successful cookie read proving its removal must deselect the
    // startup account; do not resurrect a website logout on the next launch.
    if (!hasSessionCookie && this.hasPersistedVerifiedLogin &&
      await FourD4ySession.getAuthenticationState() === 'absent') {
      try {
        await FourD4yAccountService.forgetStartupSelection(
          this.getUIContext().getHostContext() as common.Context,
          () => sequence === this.verificationSequence &&
            sessionGeneration === this.accountState.getSessionGeneration());
      } catch (_error) {
        if (sequence === this.verificationSequence) {
          this.isLoggedIn = false;
          this.isVerifying = false;
          this.status = '会话已退出，但自动恢复设置保存失败，请重新登录或在账号管理移除该账号。';
        }
        return;
      }
      if (sequence !== this.verificationSequence ||
        sessionGeneration !== this.accountState.getSessionGeneration()) {
        return;
      }
      this.blacklistState.clearServerSnapshot();
      this.unreadState.clear();
      this.favoriteState.clear();
      this.attentionState.clear();
      this.accountState.markSessionChanged();
    }
    this.isLoggedIn = loggedIn;
    if (loggedIn && !this.hasPersistedVerifiedLogin) {
      await FourD4ySession.persistVerifiedAuthentication();
      if (sequence !== this.verificationSequence) {
        return;
      }
      this.hasPersistedVerifiedLogin = true;
      if (identity !== null && verifiedSecret !== null) {
        if (!await this.saveVerifiedAccountSession(identity, verifiedSecret, sequence, sessionGeneration)) {
          if (sequence === this.verificationSequence) {
            this.isLoggedIn = false;
            this.isVerifying = false;
            this.hasPersistedVerifiedLogin = false;
            this.status = '本次账号校验已过期，请重新打开登录页核验。';
          }
          return;
        }
      }
    }
    if (sequence !== this.verificationSequence) {
      return;
    }
    this.isVerifying = false;
    if (!loggedIn) {
      this.hasPersistedVerifiedLogin = false;
      this.hasSavedAccountSession = false;
      this.accountSaveStatus = '';
    }
    this.rejectedSession = hasSessionCookie && scriptExecuted && !loggedIn;
    if (loggedIn) {
      this.status = this.accountSaveStatus || '登录成功，完整站点会话已保存在本应用内。';
      if (this.isPageActive && this.accountSaveStatus.length === 0) {
        this.closeLoginPage();
      }
    } else if (hasSessionCookie) {
      this.status = scriptExecuted ? '当前会话不是完整站点会话，请重新登录一次。' : '正在核验 4D4Y 登录会话…';
    } else {
      this.status = '请填写用户名、密码及安全提问（如有）。';
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
      this.isVerifying = false;
      this.status = '无法初始化完整站点登录页，请关闭后重试。';
    }
  }

  private startInitialLoadWhenReady(): void {
    if (!this.isControllerAttached || this.hasInitialLoadStarted) {
      return;
    }
    this.hasInitialLoadStarted = true;
    this.retryLoginPage();
  }

  private async startNewLogin(): Promise<void> {
    if (this.isVerifying) {
      return;
    }
    const sequence: number = ++this.verificationSequence;
    this.isVerifying = true;
    this.hasPersistedVerifiedLogin = false;
    this.status = '正在清除失效的 4D4Y 会话…';
    try {
      await FourD4yAccountService.forgetStartupSelection(this.getUIContext().getHostContext() as common.Context);
      await FourD4ySession.clearPersistentAuthentication();
      this.isLoggedIn = false;
      this.blacklistState.clearServerSnapshot();
      this.unreadState.clear();
      this.favoriteState.clear();
      this.attentionState.clear();
      this.accountState.markSessionChanged();
      if (sequence !== this.verificationSequence) {
        return;
      }
      this.lastVerifiedUserId = '';
      this.hasSavedAccountSession = false;
      this.accountSaveStatus = '';
      this.rejectedSession = false;
      this.status = '正在准备登录…';
      this.retryLoginPage();
    } catch (_error) {
      if (sequence === this.verificationSequence) {
        this.isVerifying = false;
        this.status = '无法重置当前会话，请关闭页面后重试。';
      }
    }
  }

  /**
   * Projects only the visible self-profile link from the already verified
   * 4D4Y page. No DOM/HTML is retained; the result is used only to name the
   * encrypted session asset's non-sensitive registry row.
   */
  private async saveVerifiedAccountSession(identity: FourD4yAccountIdentity, verifiedSecret: string,
    sequence: number, sessionGeneration: number): Promise<boolean> {
    if (this.hasSavedAccountSession) {
      return true;
    }
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const result: FourD4yAccountSaveResult = await FourD4yAccountService.saveVerifiedCurrentSession(context, identity,
        verifiedSecret, () => sequence === this.verificationSequence &&
          sessionGeneration === this.accountState.getSessionGeneration());
      if (sequence !== this.verificationSequence || sessionGeneration !== this.accountState.getSessionGeneration()) {
        return false;
      }
      if (result === FourD4yAccountSaveResult.VerificationExpired) {
        return false;
      } else if (result === FourD4yAccountSaveResult.Saved) {
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
    return true;
  }
}
