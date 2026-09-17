import { common } from '@kit.AbilityKit';
import { FourD4yAccountProfileStore } from '../../data/local/FourD4yAccountProfileStore';
import { FourD4yAccountSessionStore } from '../../data/local/FourD4yAccountSessionStore';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { createDefaultFourD4yAccountRegistry, FourD4yAccountProfile, FourD4yAccountRegistry,
  FOUR_D4Y_MAX_ACCOUNTS, removeFourD4yAccountProfile } from '../../domain/account/FourD4yAccountContracts';
import { FourD4yAccountService } from '../../domain/account/FourD4yAccountService';
import { FourD4yAccountState } from '../../domain/account/FourD4yAccountState';
import { FourD4yAttentionState } from '../../domain/attention/FourD4yAttentionState';
import { FourD4yBlacklistState } from '../../domain/blacklist/FourD4yBlacklistState';
import { FourD4yFavoriteState } from '../../domain/favorite/FourD4yFavoriteState';
import { FourD4yUnreadState } from '../../domain/notice/FourD4yUnreadState';

/**
 * A maximum-four-account picker inspired by NG's interaction model. Unlike
 * NG, it never keeps a password or security-answer; a user authenticates in
 * the real 4D4Y page and only its verified session is held in Asset Store.
 */
@Component
export struct AccountPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('authState') isLoggedIn: boolean;
  @Consume('favoriteState') favoriteState: FourD4yFavoriteState;
  @Consume('attentionState') attentionState: FourD4yAttentionState;
  @Consume('blacklistState') blacklistState: FourD4yBlacklistState;
  @Consume('accountState') accountState: FourD4yAccountState;
  @Consume('unreadState') unreadState: FourD4yUnreadState;
  @State registry: FourD4yAccountRegistry = createDefaultFourD4yAccountRegistry();
  @State isLoading: boolean = true;
  @State isSwitching: boolean = false;
  @State statusMessage: string = '';

  aboutToAppear(): void {
    void this.loadRegistry();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 0 }) {
          this.buildIntroduction();
          Divider().color($r('app.color.border'));
          this.buildCurrentAccountSection();
          Divider().color($r('app.color.border'));
          this.buildSavedAccountsSection();
          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(13)
              .fontColor(this.statusMessage.indexOf('失败') >= 0 || this.statusMessage.indexOf('失效') >= 0 ?
                $r('app.color.danger_text') : $r('app.color.text_secondary'))
              .width('100%');
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor($r('app.color.canvas'))
    }
    .title('账号管理')
  }

  @Builder
  private buildIntroduction() {
    Column({ space: 6 }) {
      Text('最多保存 ' + FOUR_D4Y_MAX_ACCOUNTS + ' 个 4D4Y 登录身份')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));
      Text('密码仅在 4D4Y 网页中输入，不会经过本应用。已验证的会话由系统安全资产库加密保存；卸载应用会一并移除。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.surface_subtle'));
  }

  @Builder
  private buildCurrentAccountSection() {
    Column({ space: 10 }) {
      Text('当前会话')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));
      if (this.isLoggedIn) {
        Text(this.getActiveProfile() === undefined ? '当前已登录，但尚未进入账号列表。' :
          '当前：' + (this.getActiveProfile() as FourD4yAccountProfile).displayName)
          .fontSize(14)
          .fontColor($r('app.color.text_body'));
        Button(this.getActiveProfile() === undefined ? '校验并保存当前账号' : '重新校验当前账号')
          .width('100%')
          .enabled(!this.isLoading && !this.isSwitching)
          .onClick(() => {
            this.pathStack.pushPathByName('Login', null, (_result: PopInfo) => {
              void this.loadRegistry();
            });
          });
      } else {
        Text('当前未登录。可选择已保存账号，或登录一个新账号。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'));
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildSavedAccountsSection() {
    Column({ space: 10 }) {
      Row() {
        Text('已保存账号')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Blank();
        Text(this.registry.profiles.length + '/' + FOUR_D4Y_MAX_ACCOUNTS)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%');

      if (this.isLoading) {
        LoadingProgress().width(28).height(28);
      } else if (this.registry.profiles.length === 0) {
        Text('还没有已保存的账号。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'));
      } else {
        ForEach(this.registry.profiles, (profile: FourD4yAccountProfile) => {
          this.buildAccountRow(profile);
        }, (profile: FourD4yAccountProfile) => profile.id);
      }

      Button('登录新账号')
        .width('100%')
        .enabled(!this.isLoading && !this.isSwitching && this.registry.profiles.length < FOUR_D4Y_MAX_ACCOUNTS)
        .onClick(() => {
          void this.startNewAccountLogin();
        });
      if (this.registry.profiles.length >= FOUR_D4Y_MAX_ACCOUNTS) {
        Text('已达到四账号上限；移除一个已保存账号后可再添加。')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildAccountRow(profile: FourD4yAccountProfile) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(profile.displayName)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          if (profile.id === this.registry.activeProfileId && this.isLoggedIn) {
            Text('当前')
              .fontSize(11)
              .fontColor($r('app.color.on_brand'))
              .backgroundColor($r('app.color.brand'))
              .borderRadius(5)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 });
          }
        }
        .width('100%');
        Text('UID ' + profile.userId)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(profile.id === this.registry.activeProfileId && this.isLoggedIn ? '已登录' : '切换')
        .fontSize(13)
        .fontColor(profile.id === this.registry.activeProfileId && this.isLoggedIn ?
          $r('app.color.text_muted') : $r('app.color.brand'))
        .height(34)
        .padding({ left: 8, right: 8 })
        .enabled(!this.isSwitching && !(profile.id === this.registry.activeProfileId && this.isLoggedIn))
        .onClick(() => {
          void this.switchToAccount(profile);
        });
      Text('移除')
        .fontSize(13)
        .fontColor($r('app.color.danger_text'))
        .height(34)
        .padding({ left: 8, right: 2 })
        .enabled(!this.isSwitching)
        .onClick(() => {
          this.confirmRemove(profile);
        });
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 });
  }

  private async loadRegistry(): Promise<void> {
    this.isLoading = true;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.registry = await FourD4yAccountProfileStore.load(context);
    } catch (_error) {
      this.registry = createDefaultFourD4yAccountRegistry();
      this.statusMessage = '读取账号列表失败，请重试。';
    }
    this.isLoading = false;
  }

  private async startNewAccountLogin(): Promise<void> {
    this.isSwitching = true;
    this.statusMessage = '';
    try {
      await FourD4ySession.clearPersistentAuthentication();
      this.clearAccountScopedMirrors();
      this.isLoggedIn = false;
      this.accountState.markSessionChanged();
      this.pathStack.pushPathByName('Login', null, (_result: PopInfo) => {
        this.isSwitching = false;
        void this.loadRegistry();
      });
    } catch (_error) {
      this.isSwitching = false;
      this.statusMessage = '无法准备新账号登录，当前会话没有被切换。';
    }
  }

  private async switchToAccount(profile: FourD4yAccountProfile): Promise<void> {
    this.isSwitching = true;
    this.statusMessage = '';
    const restored: boolean = await FourD4yAccountService.activateSavedSession(profile.id);
    if (!restored) {
      this.isSwitching = false;
      this.statusMessage = '无法恢复该账号的安全会话；它可能已失效，请选择“登录新账号”重新登录。';
      return;
    }
    this.clearAccountScopedMirrors();
    this.isLoggedIn = false;
    this.accountState.markSessionChanged();
    this.pathStack.pushPathByName('Login', null, (_result: PopInfo) => {
      this.isSwitching = false;
      void this.loadRegistry();
    });
  }

  private confirmRemove(profile: FourD4yAccountProfile): void {
    this.getUIContext().showAlertDialog({
      title: '移除账号',
      message: '移除“' + profile.displayName + '”的本机安全会话？不会影响 4D4Y 网站账号。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '移除', action: () => { void this.removeAccount(profile); } }
    });
  }

  private async removeAccount(profile: FourD4yAccountProfile): Promise<void> {
    if (this.isSwitching) {
      return;
    }
    this.isSwitching = true;
    this.statusMessage = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const removingActiveProfile: boolean = this.registry.activeProfileId === profile.id;
      const next: FourD4yAccountRegistry = removeFourD4yAccountProfile(this.registry, profile.id);
      if (!await FourD4yAccountProfileStore.save(context, next)) {
        this.statusMessage = '移除账号失败，账号列表未改变。';
        this.isSwitching = false;
        return;
      }
      await FourD4yAccountSessionStore.remove(profile.id);
      this.registry = next;
      if (removingActiveProfile && this.isLoggedIn) {
        await FourD4ySession.clearPersistentAuthentication();
        this.clearAccountScopedMirrors();
        this.isLoggedIn = false;
        this.accountState.markSessionChanged();
      }
      this.statusMessage = '已移除该账号的本机安全会话。';
    } catch (_error) {
      this.statusMessage = '移除账号失败，请重试。';
    }
    this.isSwitching = false;
  }

  private clearAccountScopedMirrors(): void {
    this.favoriteState.clear();
    this.attentionState.clear();
    this.blacklistState.clearServerSnapshot();
    this.unreadState.clear();
  }

  private getActiveProfile(): FourD4yAccountProfile | undefined {
    return this.registry.profiles.find((profile: FourD4yAccountProfile) =>
      profile.id === this.registry.activeProfileId);
  }
}
