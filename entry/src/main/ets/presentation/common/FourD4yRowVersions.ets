interface RowSnapshot<T> {
  value: T;
  key: string;
}

/**
 * ArkUI ForEach retains a builder when its key is unchanged. Reader DTOs are
 * immutable snapshots, not @Observed models: replacing a DTO under the same
 * server ID must invalidate that row when its values change.
 *
 * Keep references only to the current visible collection. No persisted data,
 * body-derived hash, random keys, or whole-list recreation on every refresh.
 */
export class FourD4yRowVersions<T> {
  private rows: Map<string, RowSnapshot<T>> = new Map<string, RowSnapshot<T>>();
  private revision: number = 0;
  private readonly identify: (value: T) => string;

  constructor(identify: (value: T) => string) {
    this.identify = identify;
  }

  track(values: T[]): T[] {
    const next: Map<string, RowSnapshot<T>> = new Map<string, RowSnapshot<T>>();
    values.forEach((value: T) => {
      const id: string = this.identify(value);
      const previous: RowSnapshot<T> | undefined = this.rows.get(id);
      const unchanged: boolean = previous !== undefined &&
        JSON.stringify(previous.value) === JSON.stringify(value);
      const key: string = unchanged && previous !== undefined ? previous.key :
        id + ':revision:' + (++this.revision);
      next.set(id, { value: value, key: key });
    });
    this.rows = next;
    return values;
  }

  key(value: T): string {
    const id: string = this.identify(value);
    const row: RowSnapshot<T> | undefined = this.rows.get(id);
    return row === undefined ? id : row.key;
  }
}
