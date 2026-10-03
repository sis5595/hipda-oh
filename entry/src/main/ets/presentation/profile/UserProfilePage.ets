import { webview } from '@kit.ArkWeb';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yPageAccessState } from '../../domain/reader/FourD4yReaderContracts';
import { buildFourD4yUserProfileUrl, FourD4yUserProfileFact, FourD4yUserProfilePayload,
  FourD4yUserProfileReaderOutcome, getFourD4yUserProfileReaderOutcome,
  isCurrentFourD4yUserProfileRequest, isExpectedFourD4yUserProfilePayload,
  parseFourD4yUserProfilePayload } from '../../domain/profile/FourD4yUserProfileContracts';
import { UserProfileRouteParams } from './UserProfileRouteState';
import { createBlacklistRouteParams } from '../blacklist/BlacklistRouteState';
import { createPrivateMessageRouteParams } from '../notice/PrivateMessageRouteState';
import { createAuthorSearchRouteParams } from '../search/SearchRouteState';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';

/**
 * Native, read-only view of the public profile data that 4D4Y itself exposes
 * from `space.php?uid=`. The hidden ArkWeb document owns its login session;
 * this page retains only displayed text and never profile-page HTML.
 */
@Component
export struct UserProfilePage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('blacklistState') blacklistState: FourD4yBlacklistState;
  @State route: UserProfileRouteParams = { userId: '', userName: '' };
  @State resolvedUserName: string = '';
  @State isOnline: boolean = false;
  @State avatarUrl: string = '';
  @State blacklistActionLabel: string = '黑名单';
  @State facts: FourD4yUserProfileFact[] = [];
  @State isLoading: boolean = true;
  @State statusMessage: string = '';
  @State needsWebVerification: boolean = false;

  private readonly profileWebController: webview.WebviewController = new webview.WebviewController();
  private loadSequence: number = 0;
  private terminalLoadSequence: number = 0;
  private profileUrl: string = '';
  private loadTimeoutId: number = -1;
  private isProfileWebControllerAttached: boolean = false;
  private readonly timeoutMillis: number = 30000;

  aboutToDisappear(): void {
    this.loadSequence += 1;
    this.isLoading = false;
    this.clearLoadWatchdog();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Web({ src: '', controller: this.profileWebController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.onProfileWebControllerAttached();
          })
          .onPageBegin((event) => {
            if (this.isCurrentProfileRequest(event.url) && !this.isLoadTerminal()) {
              this.isLoading = true;
              this.statusMessage = '';
            }
          })
          .onPageEnd((event) => {
            if (this.isCurrentProfileRequest(event.url) && !this.isLoadTerminal()) {
              this.readProfileFromWeb();
            }
          })
          .onErrorReceive((event) => {
            const requestUrl: string = event.request.getRequestUrl();
            if (event.request.isMainFrame() && this.isCurrentProfileRequest(requestUrl)) {
              this.failLoad(this.loadSequence, '暂时无法读取用户资料，请检查网络后重试。');
            }
          })
          .width(this.needsWebVerification ? '100%' : 1)
          .height(this.needsWebVerification ? '100%' : 1)
          .opacity(this.needsWebVerification ? 1 : 0)

        if (this.needsWebVerification) {
          this.buildVerificationContent();
        } else {
          Column() {
            this.buildHeader();
            Divider().color($r('app.color.border'));
            this.buildContent();
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.surface'))
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('用户信息')
    .menus(this.buildTitleActions)
    .onReady((context: NavDestinationContext) => {
      this.initializeRoute(context.pathInfo.param as UserProfileRouteParams);
    })
  }

  @Builder
  private buildHeader() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Stack() {
          Text((this.resolvedUserName || this.route.userName).substring(0, 1).toUpperCase())
            .fontSize(28)
            .fontColor($r('app.color.on_brand'))
            .textAlign(TextAlign.Center)
            .width(68)
            .height(68)
          if (this.avatarUrl.length > 0) {
            Image(this.avatarUrl)
              .width(68)
              .height(68)
              .objectFit(ImageFit.Cover)
              .borderRadius(34)
          }
        }
        .width(68)
        .height(68)
        .borderRadius(34)
        .backgroundColor($r('app.color.drawer_avatar'))
        Text(this.resolvedUserName || this.route.userName)
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Button('搜索帖子')
          .fontSize(14)
          .height(38)
          .enabled(this.canUseProfileActions())
          .onClick(() => {
            if (this.canUseProfileActions()) {
              this.pathStack.pushPathByName('Search', createAuthorSearchRouteParams(
                this.route.userId, this.resolvedUserName || this.route.userName));
            }
          })
      }
      .width('100%')
      Row({ space: 10 }) {
        Text('UID ' + this.route.userId)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        if (!this.isLoading && this.statusMessage.length === 0 && this.isOnline) {
          Text('在线')
            .fontSize(12)
            .fontColor($r('app.color.success_text'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private buildTitleActions() {
    Row({ space: 0 }) {
      Image($r('app.media.drawer_message'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_detail'))
        .padding(9)
        .opacity(this.canUseProfileActions() ? 1 : 0.35)
        .onClick(() => {
          if (this.canUseProfileActions()) {
            this.pathStack.pushPathByName('PrivateMessageDetail', createPrivateMessageRouteParams(
              this.route.userId, this.resolvedUserName || this.route.userName, true));
          }
        })
      Text(this.blacklistActionLabel)
        .fontSize(15)
        .fontColor($r('app.color.brand'))
        .height(42)
        .padding({ left: 8, right: 8 })
        .opacity(this.canUseProfileActions() ? 1 : 0.35)
        .onClick(() => {
          if (this.canUseProfileActions()) {
            this.pathStack.pushPathByName('Blacklist', createBlacklistRouteParams(
              this.resolvedUserName || this.route.userName, true), (_popInfo: PopInfo) => {
                this.updateBlacklistActionLabel();
              });
          }
        })
    }
  }

  @Builder
  private buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在读取用户资料…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.statusMessage.length > 0) {
      Column({ space: 12 }) {
        Text(this.statusMessage)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button(this.isLoggedIn ? '重试' : '去登录')
          .onClick(() => {
            if (this.isLoggedIn) {
              this.loadProfile();
            } else {
              this.pathStack.pushPathByName('Login', null);
            }
          })
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else if (this.facts.length > 0) {
      List({ space: 0 }) {
        ForEach(this.facts, (fact: FourD4yUserProfileFact) => {
          ListItem() {
            this.buildFact(fact);
          }
        }, (fact: FourD4yUserProfileFact, index: number) => fact.label + ':' + fact.value + ':' + index)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
    } else {
      Column({ space: 8 }) {
        Text('该用户没有公开的资料项。')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
        Text('用户名、UID 与在线状态仍来自 4D4Y 当前页面。')
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .textAlign(TextAlign.Center)
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    }
  }

  @Builder
  private buildFact(fact: FourD4yUserProfileFact) {
    Text(fact.label + '：' + fact.value)
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .lineHeight(24)
      .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
    .width('100%')
    .padding({ left: 16, right: 16, top: 3, bottom: 3 })
  }

  @Builder
  private buildVerificationContent() {
    Row({ space: 12 }) {
      Text('请在下方完成 4D4Y 的安全验证。')
        .fontSize(15)
        .fontColor($r('app.color.text_body'))
        .layoutWeight(1)
      Button('完成后重试')
        .fontSize(14)
        .onClick(() => {
          this.needsWebVerification = false;
          this.loadProfile();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.warning_background'))
  }

  private initializeRoute(route: UserProfileRouteParams): void {
    this.route = route;
    this.resolvedUserName = '';
    this.isOnline = false;
    this.avatarUrl = '';
    this.facts = [];
    this.statusMessage = '';
    this.needsWebVerification = false;
    this.updateBlacklistActionLabel();
    this.loadProfile();
  }

  private canUseProfileActions(): boolean {
    return !this.isLoading && this.statusMessage.length === 0 && /^\d{1,20}$/.test(this.route.userId) &&
      (this.resolvedUserName || this.route.userName).length > 0;
  }

  private updateBlacklistActionLabel(): void {
    const userName: string = this.resolvedUserName || this.route.userName;
    this.blacklistActionLabel = !this.blacklistState.hasSnapshot() ? '黑名单' :
      (this.blacklistState.isBlacklisted(userName) ? '移出黑名单' : '加入黑名单');
  }

  private loadProfile(): void {
    const nextSequence: number = this.loadSequence + 1;
    const requestUrl: string | null = buildFourD4yUserProfileUrl(this.route.userId, nextSequence);
    this.loadSequence = nextSequence;
    this.terminalLoadSequence = 0;
    this.profileUrl = requestUrl === null ? '' : requestUrl;
    this.clearLoadWatchdog();
    if (requestUrl === null) {
      this.isLoading = false;
      this.statusMessage = '当前用户资料链接无效。';
      return;
    }
    if (!this.isLoggedIn) {
      this.isLoading = false;
      this.statusMessage = '请先登录 4D4Y 后查看用户资料。';
      return;
    }
    this.isLoading = true;
    this.statusMessage = '';
    this.needsWebVerification = false;
    this.startLoadWatchdog(nextSequence);
    if (!this.isProfileWebControllerAttached) {
      return;
    }
    try {
      this.profileWebController.loadUrl(requestUrl);
    } catch (_error) {
      this.failLoad(nextSequence, '无法初始化用户资料页面，请重试。');
    }
  }

  private onProfileWebControllerAttached(): void {
    this.isProfileWebControllerAttached = true;
    try {
      this.profileWebController.setCustomUserAgent(FourD4ySession.fullSiteUserAgent);
      if (this.profileUrl.length > 0 && this.isLoading) {
        this.profileWebController.loadUrl(this.profileUrl);
      }
    } catch (_error) {
      this.failLoad(this.loadSequence, '无法初始化用户资料会话，请重试。');
    }
  }

  private isCurrentProfileRequest(url: string): boolean {
    return isCurrentFourD4yUserProfileRequest(url, this.route.userId, this.loadSequence);
  }

  private isLoadTerminal(sequence: number = this.loadSequence): boolean {
    return sequence === this.terminalLoadSequence;
  }

  private async readProfileFromWeb(): Promise<void> {
    const expectedSequence: number = this.loadSequence;
    const expectedUserId: string = this.route.userId;
    if (this.isLoadTerminal(expectedSequence)) {
      return;
    }
    try {
      const rawResult: string = await this.profileWebController.runJavaScript(
        this.getProfileExtractionScript()
      );
      if (expectedSequence !== this.loadSequence || this.isLoadTerminal(expectedSequence)) {
        return;
      }
      const payload: FourD4yUserProfilePayload | null = parseFourD4yUserProfilePayload(rawResult);
      if (payload === null || !isExpectedFourD4yUserProfilePayload(payload, expectedUserId, expectedSequence)) {
        this.failLoad(expectedSequence, '4D4Y 页面已加载，但无法确认该用户资料。');
        return;
      }
      const outcome: FourD4yUserProfileReaderOutcome = getFourD4yUserProfileReaderOutcome(payload);
      if (outcome === FourD4yUserProfileReaderOutcome.LoginRequired) {
        this.needsWebVerification = false;
        this.failLoad(expectedSequence, '4D4Y 登录状态已失效，请重新登录后重试。');
        return;
      }
      if (outcome === FourD4yUserProfileReaderOutcome.VerificationRequired) {
        this.clearLoadWatchdog();
        this.terminalLoadSequence = expectedSequence;
        this.isLoading = false;
        this.needsWebVerification = true;
        return;
      }
      if (outcome === FourD4yUserProfileReaderOutcome.Unavailable) {
        this.failLoad(expectedSequence, payload.errorMessage);
        return;
      }
      if (outcome !== FourD4yUserProfileReaderOutcome.Content) {
        this.failLoad(expectedSequence, '当前 4D4Y 用户资料页面结构暂未适配。');
        return;
      }
      this.clearLoadWatchdog();
      this.terminalLoadSequence = expectedSequence;
      this.resolvedUserName = payload.userName;
      this.isOnline = payload.isOnline;
      this.avatarUrl = payload.avatarUrl;
      this.facts = payload.facts;
      this.updateBlacklistActionLabel();
      this.statusMessage = '';
      this.isLoading = false;
      this.needsWebVerification = false;
    } catch (_error) {
      if (expectedSequence === this.loadSequence && !this.isLoadTerminal(expectedSequence)) {
        this.failLoad(expectedSequence, '暂时无法读取用户资料，请检查网络后重试。');
      }
    }
  }

  private failLoad(sequence: number, message: string): void {
    if (sequence !== this.loadSequence || this.isLoadTerminal(sequence)) {
      return;
    }
    this.clearLoadWatchdog();
    this.terminalLoadSequence = sequence;
    this.isLoading = false;
    this.statusMessage = message.length > 0 ? message : '无法读取用户资料，请重试。';
  }

  private startLoadWatchdog(sequence: number): void {
    this.clearLoadWatchdog();
    this.loadTimeoutId = setTimeout(() => {
      this.failLoad(sequence, '读取用户资料超时，请重试。');
    }, this.timeoutMillis);
  }

  private clearLoadWatchdog(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  private getProfileExtractionScript(): string {
    return [
      '(() => {',
      '  const text = (node) => node ? (node.textContent || "").replace(/\\s+/g, " ").trim() : "";',
      '  const params = new URLSearchParams(location.search);',
      '  const requestedUserId = params.get("uid") || "";',
      '  const loadSequence = Number.parseInt(params.get("oh_profile") || "0", 10) || 0;',
      '  const pageText = text(document.body);',
      '  const loginForm = document.querySelector("#loginform, form[name=login], input[name=username], input[name=password]");',
      '  const accessState = loginForm ? "loginRequired" : "available";',
      '  const profileRoot = document.querySelector("#profilecontent");',
      '  const titleRoot = profileRoot ? profileRoot.querySelector(".itemtitle") : null;',
      '  const userName = text(profileRoot ? profileRoot.querySelector(".itemtitle h1") : null);',
      '  const uidNodes = profileRoot ? Array.from(profileRoot.querySelectorAll(".itemtitle ul li")) : [];',
      '  let userId = "";',
      '  uidNodes.some((node) => { const match = /(?:UID\\s*[:：]\\s*|\\(UID\\s*[:：]\\s*)(\\d{1,20})/.exec(text(node)); if (match) { userId = match[1]; return true; } return false; });',
      '  const onlineImage = profileRoot ? profileRoot.querySelector(".itemtitle img") : null;',
      '  const isOnline = !!onlineImage && /online/i.test(onlineImage.getAttribute("src") || "");',
      '  const avatarNode = document.querySelector("div.side div.profile_side div.avatar img");',
      '  let avatarUrl = "";',
      '  try { const candidate = new URL(avatarNode ? (avatarNode.getAttribute("src") || "") : "", location.href);',
      '    if (candidate.protocol === "https:" && /^(www|img02)\\.4d4y\\.com$/i.test(candidate.hostname) &&',
      '      /^\\/forum\\/uc_server\\/data\\/avatar\\//i.test(candidate.pathname)) avatarUrl = candidate.href;',
      '  } catch (_error) {}',
      '  const facts = []; const seen = new Set();',
      '  const headings = profileRoot ? Array.from(profileRoot.querySelectorAll("h3.blocktitle")).slice(0, 2) : [];',
      '  const addFact = (node, requireLabel) => {',
      '    const value = text(node); if (!value || seen.has(value) || facts.length >= 60) return; seen.add(value);',
      '    const match = /^([^:：]{1,80})[：:]\\s*(.+)$/.exec(value);',
      '    if (!match && requireLabel) return;',
      '    facts.push({ label: match ? match[1].trim() : "公开资料", value: (match ? match[2] : value).trim().slice(0, 400) });',
      '  };',
      '  if (headings.length > 0) addFact(headings[0], true);',
      '  const factNodes = profileRoot ? Array.from(profileRoot.querySelectorAll(".main .s_clear ul.commonlist li, ul.commonlist li")) : [];',
      '  factNodes.forEach((node) => addFact(node, false));',
      '  if (headings.length > 1) addFact(headings[1], true);',
      '  const errorNode = document.querySelector("div.alert_error, div.alert_info, #messagetext, .box.message, .messagebox, .showmessage, p.message, [class*=message][class*=box]");',
      '  const knownError = pageText.split(/[。！？]/).find((part) => /(用户不存在|指定的用户|无权访问|您无权|抱歉|错误|不存在)/.test(part)) || "";',
      '  return JSON.stringify({',
      '    requestedUserId: requestedUserId, loadSequence: loadSequence, accessState: accessState,',
      '    hasChallenge: document.documentElement.innerHTML.indexOf("challenge-platform") >= 0 || document.documentElement.innerHTML.indexOf("cf-chl-") >= 0,',
      '    profileLayoutFound: !!profileRoot && !!titleRoot, userId: userId, userName: userName, isOnline: isOnline, avatarUrl: avatarUrl,',
      '    facts: facts, errorMessage: (text(errorNode) || knownError.trim()).slice(0, 240)',
      '  });',
      '})()'
    ].join('\n');
  }
}
