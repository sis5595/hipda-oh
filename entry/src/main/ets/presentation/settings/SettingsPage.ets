import { common } from '@kit.AbilityKit';
import { FourD4yUserSettingsStore } from '../../data/local/FourD4yUserSettingsStore';
import { FOUR_D4Y_FONT_SCALES, FOUR_D4Y_MAX_QUICK_FORUMS, FOUR_D4Y_POST_LINE_SPACINGS, FourD4yImageLoadPolicy,
  FourD4yThemeMode, FourD4yUserSettings, createDefaultFourD4yUserSettings,
  moveFourD4yQuickForumId, normalizeFourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';
import { ForumSummary } from '../../domain/model/ForumModels';
import { getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { createBlacklistRouteParams } from '../blacklist/BlacklistRouteState';
import { FOUR_D4Y_DEFAULT_POST_TAIL_TEXT, FOUR_D4Y_DEFAULT_POST_TAIL_URL,
  FOUR_D4Y_MAX_POST_TAIL_TEXT, FOUR_D4Y_MAX_POST_TAIL_URL,
  normalizeFourD4yPostTailUrl } from '../../domain/settings/FourD4yPostTail';

class SettingsPagePopResult {
  changed: boolean = true;
}

/** Local presentation preferences; they never access the 4D4Y Web session. */
@Component
export struct SettingsPage {
  @State settings: FourD4yUserSettings = createDefaultFourD4yUserSettings();
  @State isLoading: boolean = true;
  @State statusMessage: string = '';
  @State isSaving: boolean = false;
  @State hasLoadedSettings: boolean = false;
  @State postTailTextDraft: string = FOUR_D4Y_DEFAULT_POST_TAIL_TEXT;
  @State postTailUrlDraft: string = FOUR_D4Y_DEFAULT_POST_TAIL_URL;
  private isSettingsPageAlive: boolean = false;

  private readonly forums: ForumSummary[] = getFourD4yForums();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.isSettingsPageAlive = true;
    void this.loadSettings();
  }

  aboutToDisappear(): void {
    this.isSettingsPageAlive = false;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 0 }) {
          this.buildAppearanceSection();
          Divider().color($r('app.color.border'));
          this.buildImageSection();
          Divider().color($r('app.color.border'));
          this.buildForumSettingsSection();
          Divider().color($r('app.color.border'));
          this.buildPostTailSection();
          Divider().color($r('app.color.border'));
          this.buildPrivacySection();
          Divider().color($r('app.color.border'));
          this.buildAboutSection();
          Divider().color($r('app.color.border'));
          this.buildQuickForumsSection();
          if (!this.isLoading && !this.hasLoadedSettings) {
            Button('重试读取设置').onClick(() => { void this.loadSettings(); });
          }
          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(13)
              .fontColor(this.statusMessage.indexOf('失败') >= 0 ? $r('app.color.danger_text') : $r('app.color.success_text'))
              .width('100%');
          }
        }
        .width('100%')
        .padding({ bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor($r('app.color.canvas'))
    }
    .title('设置')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onBackPressed((): boolean => {
      if (this.isSaving) {
        return true;
      }
      // Home refreshes its quick-forum chips from the persisted preferences in its onPop callback.
      // NavPathStack only invokes that callback when a result accompanies pop().
      this.pathStack.pop(new SettingsPagePopResult());
      return true;
    })
  }

  @Builder
  private buildAppearanceSection() {
    Column({ space: 12 }) {
      this.buildSectionTitle('外观');
      Text('主题')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'));
      Row({ space: 6 }) {
        this.buildThemeButton('跟随系统', FourD4yThemeMode.FollowSystem);
        this.buildThemeButton('浅色', FourD4yThemeMode.Light);
        this.buildThemeButton('深色', FourD4yThemeMode.Dark);
      }
      .width('100%');

      Text('字体大小')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 4 });
      Row({ space: 8 }) {
        ForEach(FOUR_D4Y_FONT_SCALES, (scale: number) => {
          Button(this.getFontScaleLabel(scale))
            .fontSize(14)
            .fontColor(this.settings.fontScale === scale ? $r('app.color.on_brand') : $r('app.color.text_body'))
            .backgroundColor(this.settings.fontScale === scale ? $r('app.color.brand') : $r('app.color.fill_subtle'))
            .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
            .onClick(() => {
              void this.updateSettings(this.withFontScale(scale));
            });
        }, (scale: number) => String(scale));
      }
      .width('100%');

      Text('帖子行距')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 4 });
      Row({ space: 6 }) {
        ForEach(FOUR_D4Y_POST_LINE_SPACINGS, (spacing: number) => {
          Button(this.getPostLineSpacingLabel(spacing))
            .fontSize(13)
            .fontColor(this.settings.postLineSpacing === spacing ? $r('app.color.on_brand') :
              $r('app.color.text_body'))
            .backgroundColor(this.settings.postLineSpacing === spacing ? $r('app.color.brand') :
              $r('app.color.fill_subtle'))
            .layoutWeight(1)
            .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
            .onClick(() => {
              void this.updateSettings(this.withPostLineSpacing(spacing));
            });
        }, (spacing: number) => String(spacing));
      }
      .width('100%');
      Text('仅调整本应用的界面与正文排版。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildThemeButton(label: string, mode: FourD4yThemeMode) {
    Button(label)
      .fontSize(14)
      .fontColor(this.settings.themeMode === mode ? $r('app.color.on_brand') : $r('app.color.text_body'))
      .backgroundColor(this.settings.themeMode === mode ? $r('app.color.brand') : $r('app.color.fill_subtle'))
      .borderRadius(6)
      .height(36)
      .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
      .onClick(() => {
        void this.updateSettings(this.withThemeMode(mode));
      });
  }

  @Builder
  private buildImageSection() {
    Column({ space: 12 }) {
      this.buildSectionTitle('图片');
      Text('帖子正文图片')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'));
      Row({ space: 8 }) {
        this.buildImagePolicyButton('自动加载', FourD4yImageLoadPolicy.Automatic);
        this.buildImagePolicyButton('点按加载', FourD4yImageLoadPolicy.TapToLoad);
      }
      .width('100%');
      Text('只影响帖子里的用户图片；表情仍保持小尺寸直接显示。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildImagePolicyButton(label: string, policy: FourD4yImageLoadPolicy) {
    Button(label)
      .fontSize(14)
      .fontColor(this.settings.imageLoadPolicy === policy ? $r('app.color.on_brand') : $r('app.color.text_body'))
      .backgroundColor(this.settings.imageLoadPolicy === policy ? $r('app.color.brand') : $r('app.color.fill_subtle'))
      .borderRadius(6)
      .height(36)
      .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
      .onClick(() => {
        void this.updateSettings(this.withImageLoadPolicy(policy));
      });
  }

  @Builder
  private buildForumSettingsSection() {
    Column({ space: 8 }) {
      this.buildSectionTitle('论坛设置');
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('黑名单')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .width('100%');
          Text('管理与 4D4Y 论坛同步的黑名单用户')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_muted'))
      }
      .width('100%')
      .height(58)
      .onClick(() => {
        this.pathStack.pushPathByName('Blacklist', createBlacklistRouteParams());
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private buildPostTailSection() {
    Column({ space: 10 }) {
      this.buildSectionTitle('小尾巴');
      Row({ space: 12 }) {
        Text('发帖添加小尾巴')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1);
        Toggle({ type: ToggleType.Switch, isOn: this.settings.addPostTail })
          .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
          .onChange((enabled: boolean) => {
            const next: FourD4yUserSettings = normalizeFourD4yUserSettings(this.settings);
            next.addPostTail = enabled;
            void this.updateSettings(next);
          });
      }.width('100%');
      Text('用于新主题、普通回复和引用回复；编辑已有帖子及私信不会自动追加。默认关闭。')
        .fontSize(12).fontColor($r('app.color.text_secondary')).width('100%');
      TextInput({ placeholder: '尾巴文字', text: this.postTailTextDraft })
        .maxLength(FOUR_D4Y_MAX_POST_TAIL_TEXT)
        .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
        .onChange((value: string) => { this.postTailTextDraft = value; });
      TextInput({ placeholder: '尾巴链接（可留空）', text: this.postTailUrlDraft })
        .maxLength(FOUR_D4Y_MAX_POST_TAIL_URL)
        .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
        .onChange((value: string) => { this.postTailUrlDraft = value; });
      Button('保存小尾巴')
        .fontSize(14)
        .enabled(this.hasLoadedSettings && !this.isLoading && !this.isSaving)
        .onClick(() => { void this.savePostTail(); });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildAboutSection() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text('关于 HiPDA·OH').fontSize(16).fontColor($r('app.color.text_primary'));
        Text('版本号、项目地址、反馈与致谢').fontSize(13).fontColor($r('app.color.text_secondary'));
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Text('›').fontSize(24).fontColor($r('app.color.text_muted'));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor($r('app.color.surface'))
    .onClick(() => { this.pathStack.pushPathByName('About', null); });
  }

  private async savePostTail(): Promise<void> {
    if (this.postTailTextDraft.trim().length === 0) {
      this.statusMessage = '保存失败：小尾巴文字不能为空。';
      return;
    }
    const url: string = normalizeFourD4yPostTailUrl(this.postTailUrlDraft);
    if (this.postTailUrlDraft.trim().length > 0 && url.length === 0) {
      this.statusMessage = '保存失败：小尾巴链接须为 http 或 https 地址，不能包含账号、空白或 BBCode。';
      return;
    }
    const next: FourD4yUserSettings = normalizeFourD4yUserSettings(this.settings);
    next.postTailText = this.postTailTextDraft;
    next.postTailUrl = url;
    await this.updateSettings(next);
  }

  @Builder
  private buildPrivacySection() {
    Column({ space: 8 }) {
      this.buildSectionTitle('隐私');
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('隐私政策')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .width('100%');
          Text('查看数据处理说明、保存期限及控制方式')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_muted'));
      }
      .width('100%')
      .height(58)
      .onClick(() => {
        this.pathStack.pushPathByName('PrivacyPolicy', null);
      });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildQuickForumsSection() {
    Column({ space: 12 }) {
      this.buildSectionTitle('首页快捷版面');
      Text('首页按下面顺序显示，最多 ' + FOUR_D4Y_MAX_QUICK_FORUMS + ' 个。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%');
      ForEach(this.settings.quickForumIds, (forumId: string, index: number) => {
        this.buildSelectedForumRow(forumId, index);
      }, (forumId: string) => forumId);
      Divider().color($r('app.color.border'));
      Text('添加版面')
        .fontSize(15)
        .fontColor($r('app.color.text_body'))
        .width('100%');
      ForEach(this.getAvailableForums(), (forum: ForumSummary) => {
        this.buildAvailableForumRow(forum);
      }, (forum: ForumSummary) => forum.id);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'));
  }

  @Builder
  private buildSelectedForumRow(forumId: string, index: number) {
    Row({ space: 8 }) {
      Text(String(index + 1))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(20);
      Text(this.getForumName(forumId))
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);
      Text('↑')
        .fontSize(22)
        .fontColor(index > 0 ? $r('app.color.brand') : $r('app.color.text_muted'))
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .enabled(this.hasLoadedSettings && index > 0 && !this.isSaving)
        .onClick(() => {
          void this.updateSettings(this.withQuickForumIds(
            moveFourD4yQuickForumId(this.settings.quickForumIds, forumId, -1)));
        });
      Text('↓')
        .fontSize(22)
        .fontColor(index < this.settings.quickForumIds.length - 1 ? $r('app.color.brand') :
          $r('app.color.text_muted'))
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .enabled(this.hasLoadedSettings && index < this.settings.quickForumIds.length - 1 && !this.isSaving)
        .onClick(() => {
          void this.updateSettings(this.withQuickForumIds(
            moveFourD4yQuickForumId(this.settings.quickForumIds, forumId, 1)));
        });
      Text('移除')
        .fontSize(13)
        .fontColor($r('app.color.danger_text'))
        .height(34)
        .padding({ left: 6, right: 2 })
        .enabled(this.hasLoadedSettings && this.settings.quickForumIds.length > 1 && !this.isSaving)
        .onClick(() => {
          void this.updateSettings(this.withQuickForumIds(
            this.settings.quickForumIds.filter((id: string) => id !== forumId)));
        });
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 });
  }

  @Builder
  private buildAvailableForumRow(forum: ForumSummary) {
    Row({ space: 8 }) {
      Text(forum.name)
        .fontSize(15)
        .fontColor($r('app.color.text_body'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);
      Text('添加')
        .fontSize(13)
        .fontColor($r('app.color.brand'))
        .height(34)
        .padding({ left: 10, right: 2 })
        .enabled(this.hasLoadedSettings && this.settings.quickForumIds.length < FOUR_D4Y_MAX_QUICK_FORUMS && !this.isSaving)
        .onClick(() => {
          void this.updateSettings(this.withQuickForumIds([...this.settings.quickForumIds, forum.id]));
        });
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 });
  }

  @Builder
  private buildSectionTitle(value: string) {
    Text(value)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.brand'))
      .width('100%');
  }

  private async loadSettings(): Promise<void> {
    if (!this.isSettingsPageAlive || (this.isLoading && this.hasLoadedSettings)) {
      return;
    }
    this.isLoading = true;
    this.hasLoadedSettings = false;
    this.statusMessage = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const settings: FourD4yUserSettings = await FourD4yUserSettingsStore.load(context);
      if (!this.isSettingsPageAlive) {
        return;
      }
      this.settings = settings;
      this.postTailTextDraft = settings.postTailText;
      this.postTailUrlDraft = settings.postTailUrl;
      this.hasLoadedSettings = true;
    } catch (_error) {
      if (!this.isSettingsPageAlive) {
        return;
      }
      this.settings = createDefaultFourD4yUserSettings();
      this.statusMessage = '读取本地设置失败，当前仅显示默认值；重试成功后可修改。';
    }
    this.isLoading = false;
  }

  private async updateSettings(nextSettings: FourD4yUserSettings): Promise<void> {
    if (!this.isSettingsPageAlive || this.isSaving || this.isLoading || !this.hasLoadedSettings) {
      return;
    }
    const normalized: FourD4yUserSettings = normalizeFourD4yUserSettings(nextSettings);
    const previous: FourD4yUserSettings = this.settings;
    this.settings = normalized;
    this.isSaving = true;
    this.statusMessage = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const saved: FourD4yUserSettings | undefined = await FourD4yUserSettingsStore.save(context, normalized, previous);
      if (!this.isSettingsPageAlive) {
        return;
      }
      if (saved === undefined) {
        this.settings = previous;
        this.statusMessage = '保存设置失败，请重试。';
        this.isSaving = false;
        return;
      }
      this.settings = saved;
      FourD4yUserSettingsStore.applyAppearance(context.getApplicationContext(), saved);
      this.statusMessage = '已保存。';
    } catch (_error) {
      if (!this.isSettingsPageAlive) {
        return;
      }
      this.settings = previous;
      this.statusMessage = '保存设置失败，请重试。';
    }
    this.isSaving = false;
  }

  private withThemeMode(themeMode: FourD4yThemeMode): FourD4yUserSettings {
    return {
      themeMode: themeMode,
      fontScale: this.settings.fontScale,
      postLineSpacing: this.settings.postLineSpacing,
      imageLoadPolicy: this.settings.imageLoadPolicy,
      quickForumIds: [...this.settings.quickForumIds],
      showPinnedThreads: this.settings.showPinnedThreads,
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds],
      addPostTail: this.settings.addPostTail,
      postTailText: this.settings.postTailText,
      postTailUrl: this.settings.postTailUrl
    };
  }

  private withFontScale(fontScale: number): FourD4yUserSettings {
    return {
      themeMode: this.settings.themeMode,
      fontScale: fontScale,
      postLineSpacing: this.settings.postLineSpacing,
      imageLoadPolicy: this.settings.imageLoadPolicy,
      quickForumIds: [...this.settings.quickForumIds],
      showPinnedThreads: this.settings.showPinnedThreads,
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds],
      addPostTail: this.settings.addPostTail,
      postTailText: this.settings.postTailText,
      postTailUrl: this.settings.postTailUrl
    };
  }

  private withImageLoadPolicy(imageLoadPolicy: FourD4yImageLoadPolicy): FourD4yUserSettings {
    return {
      themeMode: this.settings.themeMode,
      fontScale: this.settings.fontScale,
      postLineSpacing: this.settings.postLineSpacing,
      imageLoadPolicy: imageLoadPolicy,
      quickForumIds: [...this.settings.quickForumIds],
      showPinnedThreads: this.settings.showPinnedThreads,
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds],
      addPostTail: this.settings.addPostTail,
      postTailText: this.settings.postTailText,
      postTailUrl: this.settings.postTailUrl
    };
  }

  private withQuickForumIds(quickForumIds: string[]): FourD4yUserSettings {
    return {
      themeMode: this.settings.themeMode,
      fontScale: this.settings.fontScale,
      postLineSpacing: this.settings.postLineSpacing,
      imageLoadPolicy: this.settings.imageLoadPolicy,
      quickForumIds: [...quickForumIds],
      showPinnedThreads: this.settings.showPinnedThreads,
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds],
      addPostTail: this.settings.addPostTail,
      postTailText: this.settings.postTailText,
      postTailUrl: this.settings.postTailUrl
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

  private withPostLineSpacing(postLineSpacing: number): FourD4yUserSettings {
    return {
      themeMode: this.settings.themeMode,
      fontScale: this.settings.fontScale,
      postLineSpacing: postLineSpacing,
      imageLoadPolicy: this.settings.imageLoadPolicy,
      quickForumIds: [...this.settings.quickForumIds],
      showPinnedThreads: this.settings.showPinnedThreads,
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds],
      addPostTail: this.settings.addPostTail,
      postTailText: this.settings.postTailText,
      postTailUrl: this.settings.postTailUrl
    };
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

  private getForumName(forumId: string): string {
    const forum: ForumSummary | undefined = this.forums.find((item: ForumSummary) => item.id === forumId);
    return forum === undefined ? forumId : forum.name;
  }

  private getAvailableForums(): ForumSummary[] {
    return this.forums.filter((forum: ForumSummary) => this.settings.quickForumIds.indexOf(forum.id) < 0);
  }
}
