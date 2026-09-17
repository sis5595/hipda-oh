import { common } from '@kit.AbilityKit';
import { FourD4yReadHistoryStore } from '../../data/local/FourD4yReadHistoryStore';
import { addFourD4yReadHistoryEntry, FourD4yReadHistoryEntry } from './FourD4yReadHistory';

type FourD4yReadHistoryListener = () => void;

/**
 * Shared process state keeps all pages on one Preferences write queue. It is
 * intentionally local-only and never observes ArkWeb session state.
 */
export class FourD4yReadHistoryState {
  private entries: FourD4yReadHistoryEntry[] = [];
  private isLoaded: boolean = false;
  private loadingPromise: Promise<void> | null = null;
  private writeQueue: Promise<void> = Promise.resolve();
  private readonly listeners: Map<number, FourD4yReadHistoryListener> =
    new Map<number, FourD4yReadHistoryListener>();
  private nextListenerId: number = 1;

  async load(context: common.Context): Promise<void> {
    if (this.isLoaded) {
      return;
    }
    if (this.loadingPromise !== null) {
      await this.loadingPromise;
      return;
    }
    this.loadingPromise = this.loadOnce(context);
    await this.loadingPromise;
  }

  getEntries(): FourD4yReadHistoryEntry[] {
    return this.entries.map((entry: FourD4yReadHistoryEntry) => copyReadHistoryEntry(entry));
  }

  async record(context: common.Context, entry: FourD4yReadHistoryEntry): Promise<void> {
    await this.load(context);
    this.entries = addFourD4yReadHistoryEntry(this.entries, entry);
    this.notifyListeners();
    const snapshot: FourD4yReadHistoryEntry[] = this.getEntries();
    this.writeQueue = this.writeQueue.then(async () => {
      await FourD4yReadHistoryStore.save(context, snapshot);
    });
    await this.writeQueue;
  }

  async clear(context: common.Context): Promise<void> {
    await this.load(context);
    this.entries = [];
    this.notifyListeners();
    this.writeQueue = this.writeQueue.then(async () => {
      await FourD4yReadHistoryStore.clear(context);
    });
    await this.writeQueue;
  }

  subscribe(listener: FourD4yReadHistoryListener): number {
    const listenerId: number = this.nextListenerId;
    this.nextListenerId += 1;
    this.listeners.set(listenerId, listener);
    return listenerId;
  }

  unsubscribe(listenerId: number): void {
    if (listenerId > 0) {
      this.listeners.delete(listenerId);
    }
  }

  private async loadOnce(context: common.Context): Promise<void> {
    try {
      this.entries = await FourD4yReadHistoryStore.load(context);
    } finally {
      this.isLoaded = true;
      this.loadingPromise = null;
      this.notifyListeners();
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach((listener: FourD4yReadHistoryListener) => {
      listener();
    });
  }
}

function copyReadHistoryEntry(entry: FourD4yReadHistoryEntry): FourD4yReadHistoryEntry {
  return {
    threadId: entry.threadId,
    title: entry.title,
    forumId: entry.forumId,
    lastReadPage: entry.lastReadPage,
    lastReadFloor: entry.lastReadFloor,
    visitedAt: entry.visitedAt
  };
}
