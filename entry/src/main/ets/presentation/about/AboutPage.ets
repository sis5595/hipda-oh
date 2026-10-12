import { bundleManager, common, Want } from '@kit.AbilityKit';
import { FOUR_D4Y_PRIVACY_CONTACT } from '../../domain/privacy/FourD4yPrivacyPolicy';

/** Reads the installed bundle, not a source-code version string. No forum request is made here. */
@Component
export struct AboutPage {
  @State versionName: string = '';
  @State versionCode: string = '';
  @State versionError: boolean = false;
  private pathStack: NavPathStack = new NavPathStack();
  private isAboutPageAlive: boolean = false;

  aboutToAppear(): void {
    this.isAboutPageAlive = true;
    this.readInstalledVersion();
  }

  aboutToDisappear(): void {
    this.isAboutPageAlive = false;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Text('HiPDA·OH')
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'));
          Text('一个以 NG 为体验参考的 4D4Y 非官方原生鸿蒙客户端。\n与论坛运营方无隶属关系。')
            .fontSize(15).lineHeight(23).fontColor($r('app.color.text_body')).width('100%');
          Column({ space: 6 }) {
            Text('版本：' + (this.versionError ? '读取失败' : this.versionName))
              .fontSize(16).fontColor($r('app.color.text_primary')).width('100%');
            Text('内部版本号：' + (this.versionError ? '读取失败' : this.versionCode))
              .fontSize(14).fontColor($r('app.color.text_secondary')).width('100%');
            if (this.versionError) {
              Button('重试读取版本').onClick(() => { this.readInstalledVersion(); });
            }
          }.width('100%').alignItems(HorizontalAlign.Start);
          Divider().color($r('app.color.border'));
          this.buildWebLink('项目与下载', 'github.com/sis5595/hipda-oh', 'https://github.com/sis5595/hipda-oh');
          this.buildWebLink('反馈问题', 'GitHub Issues', 'https://github.com/sis5595/hipda-oh/issues');
          Text('联系邮箱：' + FOUR_D4Y_PRIVACY_CONTACT)
            .fontSize(15).fontColor($r('app.color.text_body')).width('100%')
            .copyOption(CopyOptions.LocalDevice);
          this.buildWebLink('开源许可证', 'GPL-3.0-or-later', 'https://github.com/sis5595/hipda-oh/blob/main/LICENSE');
          Text('隐私政策').fontSize(16).fontColor($r('app.color.brand')).width('100%')
            .onClick(() => { this.pathStack.pushPathByName('PrivacyPolicy', null); });
          Divider().color($r('app.color.border'));
          Text('特别感谢 HiPDA·NG 的作者与贡献者，为本项目提供了成熟的交互设计、论坛适配经验及开源参考。')
            .fontSize(15).lineHeight(23).fontColor($r('app.color.text_body')).width('100%');
          this.buildWebLink('HiPDA·NG', 'GreenSkinMonster/hipda', 'https://github.com/GreenSkinMonster/hipda');
          this.buildWebLink('第三方素材声明', '保留原作者与许可证说明',
            'https://github.com/sis5595/hipda-oh/blob/main/THIRD_PARTY_NOTICES.md');
        }
        .width('100%').alignItems(HorizontalAlign.Start).padding(20);
      }.width('100%').height('100%').backgroundColor($r('app.color.canvas'));
    }
    .title('关于')
    .onReady((context: NavDestinationContext) => { this.pathStack = context.pathStack; });
  }

  @Builder
  private buildWebLink(label: string, detail: string, url: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(16).fontColor($r('app.color.brand'));
      Text(detail).fontSize(13).fontColor($r('app.color.text_secondary'));
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .onClick(() => { void this.openWebLink(url); });
  }

  private readInstalledVersion(): void {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      if (info.versionName.length === 0 || !Number.isSafeInteger(info.versionCode) || info.versionCode < 1) {
        throw new Error('installed-version-unavailable');
      }
      this.versionName = info.versionName;
      this.versionCode = String(info.versionCode);
      this.versionError = false;
    } catch (_error) {
      this.versionName = '';
      this.versionCode = '';
      this.versionError = true;
    }
  }

  private async openWebLink(url: string): Promise<void> {
    if (!this.isAboutPageAlive) return;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = { uri: url, action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'] };
      await context.startAbility(want);
    } catch (_error) {
      if (this.isAboutPageAlive) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: '系统暂时无法打开此链接' });
        } catch (_noticeError) {
          // A destination detaching during external navigation needs no further UI action.
        }
      }
    }
  }
}
