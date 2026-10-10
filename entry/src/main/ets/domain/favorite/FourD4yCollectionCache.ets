/** Opaque identity only: never holds a page, context, WebView or private data. */
export class FourD4yCollectionSnapshotSource {}

/** Account-bound ID hints, never a replacement for server mutation confirmation. */
export class FourD4yCollectionCache {
  private ids: Set<string> = new Set<string>();
  private owner: string = '';
  private epoch: number = 0;
  private pendingAdds: Set<string> = new Set<string>();
  private pendingDeletes: Set<string> = new Set<string>();
  private pendingReplace: boolean = false;
  private writer: ((ids: string[]) => Promise<void>) | undefined = undefined;
  private loading: Promise<void> | undefined = undefined;
  private snapshotSource: Object | undefined = undefined;
  private snapshotIds: string[] = [];
  private snapshotNextPage: number = 0;
  private snapshotLastPage: number = 0;
  private snapshotStartedAt: number = 0;

  has(id: string): boolean { return this.ids.has(id); }

  add(id: string): void {
    this.cancelSnapshot();
    if (!/^\d{1,20}$/.test(id) || this.ids.has(id)) return;
    this.ids.add(id);
    if (this.writer === undefined) { this.pendingAdds.add(id); this.pendingDeletes.delete(id); }
    this.changed();
  }

  delete(id: string): void {
    this.cancelSnapshot();
    // A confirmed negative must also invalidate an in-flight cache restore.
    this.ids.delete(id);
    if (this.writer === undefined) { this.pendingDeletes.add(id); this.pendingAdds.delete(id); }
    this.changed();
  }

  replace(ids: string[]): void {
    this.cancelSnapshot();
    this.ids = new Set<string>(ids.filter((id: string) => /^\d{1,20}$/.test(id)));
    if (this.writer === undefined) {
      this.pendingReplace = true;
      this.pendingAdds = new Set<string>(this.ids);
      this.pendingDeletes.clear();
    }
    this.changed();
  }

  merge(ids: string[]): void {
    this.cancelSnapshot();
    this.mergeIds(ids);
  }

  /** Only a short, complete, ordered traversal may prove absence.
   * No background requests are added; pages already read by the user are reused.
   * A source object prevents two list instances from completing one another.
   */
  observePage(ids: string[], page: number, lastPage: number, source?: Object): void {
    const now: number = Date.now();
    const valid: boolean = ids.every((id: string) => /^\d{1,20}$/.test(id)) &&
      new Set<string>(ids).size === ids.length && Number.isInteger(page) &&
      Number.isInteger(lastPage) && page >= 1 && page <= lastPage;
    if (valid && page === 1 && lastPage === 1) {
      this.replace(ids);
      return;
    }
    if (page === 1) {
      this.cancelSnapshot();
      if (valid && source !== undefined && lastPage <= 10 && ids.length > 0) {
        this.snapshotSource = source;
        this.snapshotNextPage = 1;
        this.snapshotLastPage = lastPage;
        this.snapshotStartedAt = now;
      }
    }
    const continues: boolean = valid && source !== undefined && source === this.snapshotSource &&
      page === this.snapshotNextPage && lastPage === this.snapshotLastPage &&
      now >= this.snapshotStartedAt && now - this.snapshotStartedAt <= 60000 && ids.length > 0 &&
      this.snapshotIds.length + ids.length <= 300 &&
      !ids.some((id: string) => this.snapshotIds.indexOf(id) >= 0);
    if (!continues) {
      this.cancelSnapshot();
      this.mergeIds(ids);
      return;
    }
    this.snapshotIds = this.snapshotIds.concat(ids);
    this.snapshotNextPage += 1;
    if (page === lastPage) {
      const completeIds: string[] = this.snapshotIds;
      this.replace(completeIds);
      return;
    }
    this.mergeIds(ids);
  }

  private cancelSnapshot(): void {
    this.snapshotSource = undefined;
    this.snapshotIds = [];
    this.snapshotNextPage = 0;
    this.snapshotLastPage = 0;
    this.snapshotStartedAt = 0;
  }

  releaseSnapshot(source: Object): void {
    if (this.snapshotSource === source) this.cancelSnapshot();
  }

  private mergeIds(ids: string[]): void {
    ids.forEach((id: string) => {
      if (/^\d{1,20}$/.test(id)) {
        this.ids.add(id);
        if (this.writer === undefined) { this.pendingAdds.add(id); this.pendingDeletes.delete(id); }
      }
    });
    this.changed();
  }

  clear(): void {
    this.cancelSnapshot();
    this.epoch += 1;
    this.pendingAdds.clear();
    this.pendingDeletes.clear();
    this.pendingReplace = false;
    this.ids.clear();
    this.owner = '';
    this.writer = undefined;
    this.loading = undefined;
  }

  async bind(userId: string, read: () => Promise<string[]>, write: (ids: string[]) => Promise<void>,
    isCurrent: () => boolean): Promise<void> {
    if (!/^\d{1,16}$/.test(userId) || !isCurrent()) return;
    if (this.owner === userId && this.writer !== undefined) return;
    if (this.owner === userId && this.loading !== undefined) {
      const waitingEpoch: number = this.epoch;
      const awaitedLoad: Promise<void> = this.loading;
      await awaitedLoad;
      if (!isCurrent() || waitingEpoch !== this.epoch || this.owner !== userId || this.writer !== undefined) return;
      if (this.loading !== undefined && this.loading !== awaitedLoad) {
        // Another waiter has already taken over. Never overwrite its in-flight
        // task or start competing restores which could erase fresh server IDs.
        await this.loading;
        return;
      }
      // The first page may have exited while another live page awaited its IO.
      // Continue once with this caller's lifecycle; do not loop on disk failure.
      this.loading = undefined;
    }
    if (this.owner !== userId) {
      this.clear();
      this.owner = userId;
    }
    const epoch: number = this.epoch;
    const task: Promise<void> = this.restore(epoch, read, write, isCurrent);
    this.loading = task;
    try { await task; } finally {
      if (this.loading === task) this.loading = undefined;
    }
  }

  private async restore(epoch: number, read: () => Promise<string[]>,
    write: (ids: string[]) => Promise<void>, isCurrent: () => boolean): Promise<void> {
    try {
      const ids: string[] = await read();
      if (epoch !== this.epoch || !isCurrent()) return;
      // Live server observations win over a late disk snapshot, including empty lists.
      const changed: boolean = this.pendingReplace || this.pendingAdds.size > 0 || this.pendingDeletes.size > 0;
      this.ids = this.pendingReplace ? new Set<string>() :
        new Set<string>(ids.filter((id: string) => /^\d{1,20}$/.test(id)));
      this.pendingAdds.forEach((id: string) => this.ids.add(id));
      this.pendingDeletes.forEach((id: string) => this.ids.delete(id));
      this.pendingAdds.clear();
      this.pendingDeletes.clear();
      this.pendingReplace = false;
      this.writer = write;
      if (changed) this.persist();
    } catch (_error) {
      // Do not install a writer after an unreadable snapshot: avoid overwriting it with empty data.
    }
  }

  private changed(): void {
    this.persist();
  }

  private persist(): void {
    if (this.writer !== undefined) {
      void this.writer(Array.from(this.ids)).catch(() => {});
    }
  }
}
