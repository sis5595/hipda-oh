import { common } from '@kit.AbilityKit';
import { FourD4yPrivacyConsentStore } from '../../data/local/FourD4yPrivacyConsentStore';
import { FOUR_D4Y_PRIVACY_CONTACT, FOUR_D4Y_PRIVACY_POLICY_SECTIONS,
  FOUR_D4Y_PRIVACY_POLICY_TITLE, FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT,
  FourD4yPrivacyPolicySection } from '../../domain/privacy/FourD4yPrivacyPolicy';

/** A durable, in-app copy of the policy, reachable from Settings in one tap. */
@Component
export struct PrivacyPolicyPage {
  private pathStack: NavPathStack = new NavPathStack();
  @State statusMessage: string = '';
  @State isWithdrawing: boolean = false;
  private isPrivacyPageAlive: boolean = false;

  aboutToAppear(): void {
    this.isPrivacyPageAlive = true;
  }

  aboutToDisappear(): void {
    this.isPrivacyPageAlive = false;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text(FOUR_D4Y_PRIVACY_POLICY_TITLE)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%');
          Text('更新日期：' + FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          Text('开发者：sis5595\n联系邮箱：' + FOUR_D4Y_PRIVACY_CONTACT)
            .fontSize(14)
            .fontColor($r('app.color.text_body'))
            .width('100%');
          ForEach(FOUR_D4Y_PRIVACY_POLICY_SECTIONS, (section: FourD4yPrivacyPolicySection) => {
            this.buildSection(section);
          }, (section: FourD4yPrivacyPolicySection) => section.title);
          Divider().color($r('app.color.border'));
          Text('撤回同意后，本次应用会回到隐私政策页，不会再进入论坛功能。已保存帐号可先在“帐号管理”中移除。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          Button(this.isWithdrawing ? '正在撤回…' : '撤回隐私政策同意')
            .width('100%')
            .height(42)
            .fontSize(15)
            .fontColor($r('app.color.danger_text'))
            .backgroundColor($r('app.color.fill_subtle'))
            .enabled(!this.isWithdrawing)
            .onClick(() => {
              void this.withdrawConsent();
            });
          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(13)
              .fontColor($r('app.color.danger_text'))
              .width('100%');
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 28 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.canvas'))
    }
    .title('隐私政策')
    .hideBackButton(this.isWithdrawing)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onBackPressed((): boolean => {
      if (this.isWithdrawing) {
        return true;
      }
      this.pathStack.pop();
      return true;
    });
  }

  @Builder
  private buildSection(section: FourD4yPrivacyPolicySection) {
    Column({ space: 6 }) {
      Text(section.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
      Text(section.content)
        .fontSize(14)
        .fontColor($r('app.color.text_body'))
        .lineHeight(22)
        .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  private async withdrawConsent(): Promise<void> {
    if (!this.isPrivacyPageAlive || this.isWithdrawing) {
      return;
    }
    this.statusMessage = '';
    this.isWithdrawing = true;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const withdrawn: boolean = await FourD4yPrivacyConsentStore.withdrawConsent(context);
      if (!withdrawn) {
        if (!this.isPrivacyPageAlive) {
          return;
        }
        this.statusMessage = '撤回失败，请稍后重试。';
        this.isWithdrawing = false;
        return;
      }
      // Remove old forum destinations before the consent gate destroys Navigation.
      // A subsequent acceptance starts at Home, not a retained settings/private route.
      this.pathStack.clear();
      AppStorage.set<boolean>('hipdaoh_privacy_accepted', false);
    } catch (_error) {
      if (!this.isPrivacyPageAlive) {
        return;
      }
      this.statusMessage = '撤回失败，请稍后重试。';
      this.isWithdrawing = false;
    }
  }
}
