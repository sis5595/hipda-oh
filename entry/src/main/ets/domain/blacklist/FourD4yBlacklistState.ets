import { normalizeFourD4yBlacklistUserName } from './FourD4yBlacklistContracts';

/**
 * Session-only projection of the current account's server blacklist.
 *
 * It is intentionally not a second blacklist: callers may replace it only
 * with a successfully parsed `pm.php?action=viewblack` response. No cookie,
 * formhash, HTML, or persisted user-created value is kept here.
 */
export class FourD4yBlacklistState {
  private readonly serverUserNames: Set<string> = new Set<string>();
  private readonly listeners: Map<number, FourD4yBlacklistStateListener> =
    new Map<number, FourD4yBlacklistStateListener>();
  private nextListenerId: number = 1;
  private hasServerSnapshot: boolean = false;

  hasSnapshot(): boolean {
    return this.hasServerSnapshot;
  }

  isBlacklisted(userName: string): boolean {
    const normalized: string = normalizeFourD4yBlacklistUserName(userName);
    return normalized.length > 0 && this.hasServerSnapshot && this.serverUserNames.has(normalized);
  }

  getUserNames(): string[] {
    return Array.from(this.serverUserNames.values());
  }

  /** Replace, rather than merge, because the server blacklist page is complete. */
  observeServerUserNames(userNames: string[]): void {
    const next: Set<string> = new Set<string>();
    userNames.forEach((userName: string) => {
      const normalized: string = normalizeFourD4yBlacklistUserName(userName);
      if (normalized.length > 0) {
        next.add(normalized);
      }
    });
    this.serverUserNames.clear();
    next.forEach((userName: string) => {
      this.serverUserNames.add(userName);
    });
    this.hasServerSnapshot = true;
    this.notifyListeners();
  }

  /** A login transition invalidates the previous account's server snapshot. */
  clearServerSnapshot(): void {
    if (!this.hasServerSnapshot && this.serverUserNames.size === 0) {
      return;
    }
    this.serverUserNames.clear();
    this.hasServerSnapshot = false;
    this.notifyListeners();
  }

  subscribe(callback: FourD4yBlacklistStateListener): number {
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
    const callbacks: FourD4yBlacklistStateListener[] = Array.from(this.listeners.values());
    callbacks.forEach((callback: FourD4yBlacklistStateListener) => {
      callback();
    });
  }
}

type FourD4yBlacklistStateListener = () => void;
