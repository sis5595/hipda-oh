/**
 * A deliberately small local reading-progress record. It contains forum
 * identifiers and presentation metadata only: never a URL, cookie, form
 * value, extracted page source, or post body.
 */
export interface FourD4yReadHistoryEntry {
  threadId: string;
  title: string;
  forumId: string;
  lastReadPage: number;
  lastReadFloor: number;
  visitedAt: number;
}

export const FOUR_D4Y_READ_HISTORY_LIMIT: number = 80;
const MAX_TITLE_LENGTH: number = 240;
const MAX_HISTORY_TIMESTAMP: number = 4102444800000;

export function parseFourD4yReadHistory(rawValue: string): FourD4yReadHistoryEntry[] {
  if (rawValue.length === 0 || rawValue.length > 30000) {
    return [];
  }
  try {
    const source: FourD4yReadHistoryEntry[] = JSON.parse(rawValue) as FourD4yReadHistoryEntry[];
    if (!Array.isArray(source)) {
      return [];
    }
    const result: FourD4yReadHistoryEntry[] = [];
    for (let index: number = 0; index < source.length && result.length < FOUR_D4Y_READ_HISTORY_LIMIT;
      index += 1) {
      const entry: FourD4yReadHistoryEntry = source[index];
      if (!isValidFourD4yReadHistoryEntry(entry) || result.some((item: FourD4yReadHistoryEntry) =>
        item.threadId === entry.threadId)) {
        continue;
      }
      result.push(copyFourD4yReadHistoryEntry(entry));
    }
    return result;
  } catch (_error) {
    return [];
  }
}

export function addFourD4yReadHistoryEntry(entries: FourD4yReadHistoryEntry[],
  nextEntry: FourD4yReadHistoryEntry): FourD4yReadHistoryEntry[] {
  if (!isValidFourD4yReadHistoryEntry(nextEntry)) {
    return entries.slice(0, FOUR_D4Y_READ_HISTORY_LIMIT).map(copyFourD4yReadHistoryEntry);
  }
  const normalized: FourD4yReadHistoryEntry = copyFourD4yReadHistoryEntry(nextEntry);
  const result: FourD4yReadHistoryEntry[] = [normalized];
  entries.forEach((entry: FourD4yReadHistoryEntry) => {
    if (!isValidFourD4yReadHistoryEntry(entry) || entry.threadId === normalized.threadId ||
      result.length >= FOUR_D4Y_READ_HISTORY_LIMIT) {
      return;
    }
    result.push(copyFourD4yReadHistoryEntry(entry));
  });
  return result;
}

export function serializeFourD4yReadHistory(entries: FourD4yReadHistoryEntry[]): string {
  return JSON.stringify(entries.slice(0, FOUR_D4Y_READ_HISTORY_LIMIT).map(copyFourD4yReadHistoryEntry));
}

export function isValidFourD4yReadHistoryEntry(entry: FourD4yReadHistoryEntry): boolean {
  return entry !== null && /^\d{1,20}$/.test(entry.threadId) && typeof entry.title === 'string' &&
    entry.title.trim().length > 0 && entry.title.trim().length <= MAX_TITLE_LENGTH &&
    entry.title.indexOf('<') < 0 && entry.title.indexOf('>') < 0 &&
    (entry.forumId.length === 0 || /^\d{1,20}$/.test(entry.forumId)) &&
    Number.isInteger(entry.lastReadPage) && entry.lastReadPage >= 1 && entry.lastReadPage <= 100000 &&
    Number.isInteger(entry.lastReadFloor) && entry.lastReadFloor >= 1 && entry.lastReadFloor <= 10000000 &&
    Number.isInteger(entry.visitedAt) && entry.visitedAt > 0 && entry.visitedAt <= MAX_HISTORY_TIMESTAMP;
}

function copyFourD4yReadHistoryEntry(entry: FourD4yReadHistoryEntry): FourD4yReadHistoryEntry {
  return {
    threadId: entry.threadId,
    title: entry.title.trim(),
    forumId: entry.forumId,
    lastReadPage: entry.lastReadPage,
    lastReadFloor: entry.lastReadFloor,
    visitedAt: entry.visitedAt
  };
}
