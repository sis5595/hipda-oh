/**
 * Session-only, value-free mirror of server-confirmed favorite thread IDs.
 *
 * The forum always renders an add link in a topic, even when it is already
 * favorited. Keeping this small mirror lets a newly opened detail page retain
 * the result previously confirmed by the server favorites list. Cookies,
 * formhash values, and page HTML are deliberately never stored here.
 */
export class FourD4yFavoriteState {
  private readonly favoriteThreadIds: Set<string> = new Set<string>();
  private readonly mutationListeners: Map<number, FourD4yFavoriteMutationListener> =
    new Map<number, FourD4yFavoriteMutationListener>();
  private nextMutationListenerId: number = 1;

  isFavorite(threadId: string): boolean {
    return /^\d+$/.test(threadId) && this.favoriteThreadIds.has(threadId);
  }

  markFavorite(threadId: string): void {
    if (/^\d+$/.test(threadId)) {
      this.favoriteThreadIds.add(threadId);
    }
  }

  markNotFavorite(threadId: string): void {
    if (/^\d+$/.test(threadId)) {
      this.favoriteThreadIds.delete(threadId);
    }
  }

  observeServerFavorites(threadIds: string[]): void {
    threadIds.forEach((threadId: string) => {
      this.markFavorite(threadId);
    });
  }

  clear(): void {
    this.favoriteThreadIds.clear();
    this.mutationListeners.clear();
  }

  /**
   * A list page registers a one-shot listener before opening its child detail
   * page. The callback is delivered only after the detail page has confirmed
   * the server result, never merely when a user presses the native button.
   */
  subscribeToThreadMutation(threadId: string, callback: (isFavorite: boolean) => void): number {
    if (!/^\d+$/.test(threadId)) {
      return -1;
    }
    const listenerId: number = this.nextMutationListenerId;
    this.nextMutationListenerId += 1;
    this.mutationListeners.set(listenerId, {
      threadId: threadId,
      callback: callback
    });
    return listenerId;
  }

  unsubscribeFromThreadMutation(listenerId: number): void {
    if (listenerId > 0) {
      this.mutationListeners.delete(listenerId);
    }
  }

  notifyConfirmedThreadMutation(threadId: string, isFavorite: boolean): void {
    if (!/^\d+$/.test(threadId)) {
      return;
    }
    const matchingListenerIds: number[] = [];
    this.mutationListeners.forEach((listener: FourD4yFavoriteMutationListener, listenerId: number) => {
      if (listener.threadId === threadId) {
        matchingListenerIds.push(listenerId);
      }
    });
    matchingListenerIds.forEach((listenerId: number) => {
      const listener: FourD4yFavoriteMutationListener | undefined = this.mutationListeners.get(listenerId);
      this.mutationListeners.delete(listenerId);
      if (listener !== undefined) {
        listener.callback(isFavorite);
      }
    });
  }
}

interface FourD4yFavoriteMutationListener {
  threadId: string;
  callback: (isFavorite: boolean) => void;
}
