import { common } from '@kit.AbilityKit';
import { getFourD4yForums } from '../../domain/catalog/FourD4yForumCatalog';
import { FourD4yReadHistoryEntry } from '../../domain/history/FourD4yReadHistory';
import { FourD4yReadHistoryState } from '../../domain/history/FourD4yReadHistoryState';
import { ForumSummary } from '../../domain/model/ForumModels';
import { createThreadRouteParams } from '../thread/ThreadRouteState';

/** Local-only reading progress. No forum request is made on this page. */
@Component
export struct ReadingHistoryPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('readHistoryState') readHistoryState: FourD4yReadHistoryState;
  @State entries: FourD4yReadHistoryEntry[] = [];
  @State isLoading: boolean = true;
  @State isClearing: boolean = false;

  private readonly forums: ForumSummary[] = getFourD4yForums();
  private historyListenerId: number = -1;
  private isHistoryPageAlive: boolean = false;

  aboutToAppear(): void {
    this.isHistoryPageAlive = true;
    this.subscribeToHistory();
    void this.loadHistory();
  }

  aboutToDisappear(): void {
    this.isHistoryPageAlive = false;
    this.unsubscribeFromHistory();
  }

  build() {
    NavDestination() {
      Column() {
        this.buildToolbar();
        Divider().color($r('app.color.border'));
        this.buildContent();
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface'))
    }
    .title('阅读历史')
    .menus(this.buildTitleActions)
  }

  @Builder
  private buildToolbar() {
    Text('仅保存在本机，不保存正文、链接或登录信息。')
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .lineHeight(18)
    .width('100%')
    .padding({ left: 16, right: 16, top: 7, bottom: 7 })
    .backgroundColor($r('app.color.surface_subtle'))
  }

  @Builder
  private buildTitleActions() {
    Text('清空')
      .fontSize(15)
      .fontColor($r('app.color.danger_text'))
      .height(42)
      .padding({ left: 10, right: 10 })
      .opacity(this.entries.length > 0 && !this.isLoading && !this.isClearing ? 1 : 0.35)
      .onClick(() => {
        if (this.entries.length > 0 && !this.isLoading && !this.isClearing) {
          void this.clearHistory();
        }
      })
  }

  @Builder
  private buildContent() {
    if (this.isLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在读取本机阅读历史…')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
    } else if (this.entries.length === 0) {
      Column({ space: 10 }) {
        Text('暂无阅读历史')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
        Text('打开一个主题后，会自动记录可继续阅读的位置。')
          .fontSize(13)
          .fontColor($r('app.color.text_muted'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding(28)
      .width('100%')
    } else {
      List({ space: 0 }) {
        ForEach(this.entries, (entry: FourD4yReadHistoryEntry) => {
          ListItem() {
            this.buildEntry(entry);
          }
          .onClick(() => {
            this.openEntry(entry);
          })
        }, (entry: FourD4yReadHistoryEntry) => entry.threadId)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 1, color: $r('app.color.border_subtle'), startMargin: 16, endMargin: 16 })
    }
  }

  @Builder
  private buildEntry(entry: FourD4yReadHistoryEntry) {
    Column({ space: 4 }) {
      Text(entry.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_strong'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row() {
        Text(this.getForumName(entry.forumId))
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text('继续第 ' + entry.lastReadPage + ' 页 · #' + entry.lastReadFloor)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 10 })
  }

  private async loadHistory(): Promise<void> {
    try {
      await this.readHistoryState.load(this.getUIContext().getHostContext() as common.Context);
    } catch (_error) {
      this.showHistoryError('读取浏览记录失败，请返回后重试。');
    } finally {
      if (this.isHistoryPageAlive) {
        this.syncEntries();
        this.isLoading = false;
      }
    }
  }

  private async clearHistory(): Promise<void> {
    if (!this.isHistoryPageAlive || this.isClearing || this.entries.length === 0) {
      return;
    }
    this.isClearing = true;
    try {
      await this.readHistoryState.clear(this.getUIContext().getHostContext() as common.Context);
    } catch (_error) {
      this.showHistoryError('清空浏览记录未成功，请重试。');
    } finally {
      if (this.isHistoryPageAlive) {
        this.syncEntries();
        this.isClearing = false;
      }
    }
  }

  private openEntry(entry: FourD4yReadHistoryEntry): void {
    this.pathStack.pushPathByName('ThreadDetail', createThreadRouteParams(
      entry.threadId, entry.title, 0, entry.lastReadPage, entry.lastReadFloor, entry.forumId));
  }

  private showHistoryError(message: string): void {
    if (!this.isHistoryPageAlive) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // Feedback failure must not reject the handled storage operation.
    }
  }

  private getForumName(forumId: string): string {
    const matched: ForumSummary | undefined = this.forums.find((forum: ForumSummary) => forum.id === forumId);
    return matched === undefined ? '4D4Y' : matched.name;
  }

  private subscribeToHistory(): void {
    if (this.historyListenerId > 0) {
      return;
    }
    this.historyListenerId = this.readHistoryState.subscribe(() => {
      this.syncEntries();
    });
  }

  private unsubscribeFromHistory(): void {
    if (this.historyListenerId > 0) {
      this.readHistoryState.unsubscribe(this.historyListenerId);
      this.historyListenerId = -1;
    }
  }

  private syncEntries(): void {
    if (this.isHistoryPageAlive) {
      this.entries = this.readHistoryState.getEntries();
    }
  }
}
