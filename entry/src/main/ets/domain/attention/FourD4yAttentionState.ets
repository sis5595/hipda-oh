/**
 * Session-only mirror of topic IDs confirmed by the 4D4Y attention list.
 * It deliberately stores no cookies, HTML, formhash, or account data.
 */
export class FourD4yAttentionState {
  private readonly attentionThreadIds: Set<string> = new Set<string>();
  private readonly mutationListeners: Map<number, FourD4yAttentionMutationListener> =
    new Map<number, FourD4yAttentionMutationListener>();
  private nextMutationListenerId: number = 1;

  isAttentioned(threadId: string): boolean {
    return /^\d+$/.test(threadId) && this.attentionThreadIds.has(threadId);
  }

  markAttentioned(threadId: string): void {
    if (/^\d+$/.test(threadId)) {
      this.attentionThreadIds.add(threadId);
    }
  }

  markNotAttentioned(threadId: string): void {
    if (/^\d+$/.test(threadId)) {
      this.attentionThreadIds.delete(threadId);
    }
  }

  observeServerAttentions(threadIds: string[]): void {
    threadIds.forEach((threadId: string) => {
      this.markAttentioned(threadId);
    });
  }

  clear(): void {
    this.attentionThreadIds.clear();
    this.mutationListeners.clear();
  }

  subscribeToThreadMutation(threadId: string, callback: (isAttentioned: boolean) => void): number {
    if (!/^\d+$/.test(threadId)) {
      return -1;
    }
    const listenerId: number = this.nextMutationListenerId;
    this.nextMutationListenerId += 1;
    this.mutationListeners.set(listenerId, { threadId: threadId, callback: callback });
    return listenerId;
  }

  unsubscribeFromThreadMutation(listenerId: number): void {
    if (listenerId > 0) {
      this.mutationListeners.delete(listenerId);
    }
  }

  notifyConfirmedThreadMutation(threadId: string, isAttentioned: boolean): void {
    if (!/^\d+$/.test(threadId)) {
      return;
    }
    const matchingListenerIds: number[] = [];
    this.mutationListeners.forEach((listener: FourD4yAttentionMutationListener, listenerId: number) => {
      if (listener.threadId === threadId) {
        matchingListenerIds.push(listenerId);
      }
    });
    matchingListenerIds.forEach((listenerId: number) => {
      const listener: FourD4yAttentionMutationListener | undefined = this.mutationListeners.get(listenerId);
      this.mutationListeners.delete(listenerId);
      if (listener !== undefined) {
        listener.callback(isAttentioned);
      }
    });
  }
}

interface FourD4yAttentionMutationListener {
  threadId: string;
  callback: (isAttentioned: boolean) => void;
}
