/**
 * Session-only projection of the unread counters exposed by 4D4Y's signed-in
 * `#myprompt` menu.
 *
 * The state deliberately retains only four non-sensitive integers.  It never
 * stores HTML, cookies, account identifiers, message text or a locally
 * inferred "read" result: every change must come from a newly validated
 * forum response.  `prompt_friend` belongs to the same aggregate information
 * reminder as `prompt_threads` and `prompt_systempm`, matching NG's rule.
 */
export class FourD4yUnreadState {
  private privateMessageCount: number = 0;
  private threadNoticeCount: number = 0;
  private systemNoticeCount: number = 0;
  private friendNoticeCount: number = 0;
  private hasServerSnapshot: boolean = false;
  private readonly listeners: Map<number, FourD4yUnreadStateListener> =
    new Map<number, FourD4yUnreadStateListener>();
  private nextListenerId: number = 1;
  private refreshSequence: number = 0;

  /** Home and message center share one projection, so local page tokens alone
   * cannot reject an older response from the other still-mounted page.
   */
  beginRefresh(): number {
    this.refreshSequence += 1;
    return this.refreshSequence;
  }

  isCurrentRefresh(sequence: number): boolean {
    return sequence > 0 && sequence === this.refreshSequence;
  }

  hasSnapshot(): boolean {
    return this.hasServerSnapshot;
  }

  getPrivateMessageCount(): number {
    return this.privateMessageCount;
  }

  getThreadNoticeCount(): number {
    return this.threadNoticeCount;
  }

  getSystemNoticeCount(): number {
    return this.systemNoticeCount;
  }

  getFriendNoticeCount(): number {
    return this.friendNoticeCount;
  }

  /** All non-private prompt groups share the information-reminder bell. */
  getInformationReminderCount(): number {
    return this.threadNoticeCount + this.systemNoticeCount + this.friendNoticeCount;
  }

  observeServerCounts(privateMessageCount: number, threadNoticeCount: number,
    systemNoticeCount: number, friendNoticeCount: number): void {
    if (!isUnreadCount(privateMessageCount) || !isUnreadCount(threadNoticeCount) ||
      !isUnreadCount(systemNoticeCount) || !isUnreadCount(friendNoticeCount)) {
      return;
    }
    const changed: boolean = !this.hasServerSnapshot ||
      this.privateMessageCount !== privateMessageCount || this.threadNoticeCount !== threadNoticeCount ||
      this.systemNoticeCount !== systemNoticeCount || this.friendNoticeCount !== friendNoticeCount;
    this.privateMessageCount = privateMessageCount;
    this.threadNoticeCount = threadNoticeCount;
    this.systemNoticeCount = systemNoticeCount;
    this.friendNoticeCount = friendNoticeCount;
    this.hasServerSnapshot = true;
    if (changed) {
      this.notifyListeners();
    }
  }

  /** An account transition or rejected session invalidates every old count. */
  clear(): void {
    this.refreshSequence += 1;
    if (!this.hasServerSnapshot && this.privateMessageCount === 0 && this.threadNoticeCount === 0 &&
      this.systemNoticeCount === 0 && this.friendNoticeCount === 0) {
      return;
    }
    this.privateMessageCount = 0;
    this.threadNoticeCount = 0;
    this.systemNoticeCount = 0;
    this.friendNoticeCount = 0;
    this.hasServerSnapshot = false;
    this.notifyListeners();
  }

  subscribe(callback: FourD4yUnreadStateListener): number {
    const listenerId: number = this.nextListenerId;
    this.nextListenerId += 1;
    this.listeners.set(listenerId, callback);
    return listenerId;
  }

  unsubscribe(listenerId: number): void {
    if (listenerId > 0) {
      this.listeners.delete(listenerId);
    }
  }

  private notifyListeners(): void {
    const callbacks: FourD4yUnreadStateListener[] = Array.from(this.listeners.values());
    callbacks.forEach((callback: FourD4yUnreadStateListener) => {
      callback();
    });
  }
}

type FourD4yUnreadStateListener = () => void;

function isUnreadCount(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 0;
}
