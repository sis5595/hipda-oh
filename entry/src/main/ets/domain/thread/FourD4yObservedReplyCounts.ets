import { ThreadPost } from '../model/ForumModels';

type ReplyCountListener = () => void;

interface ObservedReplyCount {
  count: number;
  observedAt: number;
}

/**
 * NG updates a board row after reading the thread's final page, using the
 * last server floor minus one. A fallback floor calculated from page size is
 * not authoritative on a multi-page thread. The caller excludes author-only
 * views, which cannot represent the full thread.
 */
export function countObservedLastPageReplies(posts: ThreadPost[], currentPage: number,
  lastPage: number): number | undefined {
  if (!Number.isInteger(currentPage) || !Number.isInteger(lastPage) || currentPage < 1 ||
    currentPage !== lastPage || posts.length === 0) {
    return undefined;
  }
  const lastPost: ThreadPost = posts[posts.length - 1];
  if (!Number.isInteger(lastPost.floor) || lastPost.floor < 1) {
    return undefined;
  }
  for (let index: number = 0; index < posts.length; index += 1) {
    if (posts[index].threadId !== lastPost.threadId ||
      (index > 0 && posts[index].floor <= posts[index - 1].floor)) {
      return undefined;
    }
  }
  if (lastPage === 1 && posts.length === lastPost.floor && posts[0].floor === 1) {
    return lastPost.floor - 1;
  }
  return lastPost.hasExplicitFloor === true ? lastPost.floor - 1 : undefined;
}

/** In-memory and session-scoped: never makes a second forum request. */
export class FourD4yObservedReplyCounts {
  private readonly counts: Map<string, ObservedReplyCount> = new Map<string, ObservedReplyCount>();
  private readonly listeners: Map<number, ReplyCountListener> = new Map<number, ReplyCountListener>();
  private nextListenerId: number = 1;
  private readonly maxAgeMillis: number = 60 * 60 * 1000;
  private sessionGeneration: number = -1;

  syncSession(generation: number): void {
    if (!Number.isInteger(generation) || generation < 0 || generation === this.sessionGeneration) {
      return;
    }
    this.sessionGeneration = generation;
    if (this.counts.size > 0) {
      this.counts.clear();
      this.listeners.forEach((listener: ReplyCountListener) => listener());
    }
  }

  observe(threadId: string, count: number, now: number = Date.now()): void {
    if (!/^\d+$/.test(threadId) || !Number.isInteger(count) || count < 0 ||
      !Number.isFinite(now) || now < 0) {
      return;
    }
    this.counts.set(threadId, { count: count, observedAt: now });
    this.listeners.forEach((listener: ReplyCountListener) => listener());
  }

  resolve(threadId: string, boardCount: number, now: number = Date.now()): number {
    const observed: ObservedReplyCount | undefined = this.counts.get(threadId);
    if (observed === undefined || now < observed.observedAt ||
      now - observed.observedAt > this.maxAgeMillis) {
      return boardCount;
    }
    // Like NG's ThreadUpdatedEvent, replace the row rather than only raising
    // it: deleting replies can make an authoritative last-page count smaller.
    return observed.count;
  }

  /** A newly read board row replaces its old detail-derived snapshot (NG). */
  acceptBoardRows(threadIds: string[]): void {
    let changed: boolean = false;
    threadIds.forEach((threadId: string) => {
      if (this.counts.delete(threadId)) {
        changed = true;
      }
    });
    if (changed) {
      this.listeners.forEach((listener: ReplyCountListener) => listener());
    }
  }

  subscribe(listener: ReplyCountListener): number {
    const id: number = this.nextListenerId;
    this.nextListenerId += 1;
    this.listeners.set(id, listener);
    return id;
  }

  unsubscribe(id: number): void {
    this.listeners.delete(id);
  }
}
