import { common } from '@kit.AbilityKit';
import { FourD4yUserSettingsStore } from '../../data/local/FourD4yUserSettingsStore';
import { FOUR_D4Y_FONT_SCALES, FOUR_D4Y_MAX_QUICK_FORUMS, FOUR_D4Y_POST_LINE_SPACINGS, FourD4yImageLoadPolicy,
  FourD4yThemeMode, FourD4yUserSettings, createDefaultFourD4yUserSettings,
  moveFourD4yQuickForumId, normalizeFourD4yUserSettings } from '../../domain/settings/FourD4yUserSettings';
import { ForumSummary } from '../../domain/model/ForumModels';
import { getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { createBlacklistRouteParams } from '../blacklist/BlacklistRouteState';

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

  private readonly forums: ForumSummary[] = getFourD4yForums();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    void this.loadSettings();
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
          this.buildPrivacySection();
          Divider().color($r('app.color.border'));
          this.buildQuickForumsSection();
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
            .enabled(!this.isLoading && !this.isSaving)
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
            .enabled(!this.isLoading && !this.isSaving)
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
      .enabled(!this.isLoading && !this.isSaving)
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
      .enabled(!this.isLoading && !this.isSaving)
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
        .enabled(index > 0 && !this.isSaving)
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
        .enabled(index < this.settings.quickForumIds.length - 1 && !this.isSaving)
        .onClick(() => {
          void this.updateSettings(this.withQuickForumIds(
            moveFourD4yQuickForumId(this.settings.quickForumIds, forumId, 1)));
        });
      Text('移除')
        .fontSize(13)
        .fontColor($r('app.color.danger_text'))
        .height(34)
        .padding({ left: 6, right: 2 })
        .enabled(this.settings.quickForumIds.length > 1 && !this.isSaving)
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
        .enabled(this.settings.quickForumIds.length < FOUR_D4Y_MAX_QUICK_FORUMS && !this.isSaving)
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
    this.isLoading = true;
    this.statusMessage = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.settings = await FourD4yUserSettingsStore.load(context);
    } catch (_error) {
      this.settings = createDefaultFourD4yUserSettings();
      this.statusMessage = '读取本地设置失败，已使用默认值。';
    }
    this.isLoading = false;
  }

  private async updateSettings(nextSettings: FourD4yUserSettings): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const normalized: FourD4yUserSettings = normalizeFourD4yUserSettings(nextSettings);
    const previous: FourD4yUserSettings = this.settings;
    this.settings = normalized;
    this.isSaving = true;
    this.statusMessage = '';
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const saved: boolean = await FourD4yUserSettingsStore.save(context, normalized);
      if (!saved) {
        this.settings = previous;
        this.statusMessage = '保存设置失败，请重试。';
        this.isSaving = false;
        return;
      }
      FourD4yUserSettingsStore.applyAppearance(context.getApplicationContext(), normalized);
      this.statusMessage = '已保存。';
    } catch (_error) {
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
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds]
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
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds]
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
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds]
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
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds]
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
      postTimeSortForumIds: [...this.settings.postTimeSortForumIds]
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
