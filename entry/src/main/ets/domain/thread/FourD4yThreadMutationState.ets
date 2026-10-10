export interface FourD4yThreadDeletionEvent {
  threadId: string;
  forumId: string;
  sessionGeneration: number;
}

type ThreadDeletionListener = (event: FourD4yThreadDeletionEvent) => void;

/** Process-local confirmed mutations, not persisted forum data or optimistic writes. */
export class FourD4yThreadMutationState {
  private readonly listeners: Map<number, ThreadDeletionListener> = new Map<number, ThreadDeletionListener>();
  private nextId: number = 1;

  subscribeDeletion(listener: ThreadDeletionListener): number {
    const id: number = this.nextId++;
    this.listeners.set(id, listener);
    return id;
  }

  unsubscribeDeletion(id: number): void {
    this.listeners.delete(id);
  }

  notifyDeleted(threadId: string, forumId: string, sessionGeneration: number): void {
    if (!/^\d{1,20}$/.test(threadId) || !/^\d{1,20}$/.test(forumId) ||
      !Number.isInteger(sessionGeneration) || sessionGeneration < 0) {
      return;
    }
    this.listeners.forEach((listener: ThreadDeletionListener) => {
      listener({ threadId: threadId, forumId: forumId, sessionGeneration: sessionGeneration });
    });
  }
}
