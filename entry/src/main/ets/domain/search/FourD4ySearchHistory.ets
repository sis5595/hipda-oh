import { FourD4ySearchMode } from './FourD4ySearchContracts';

/** A privacy-safe local search-history row. It never carries a session or URL. */
export interface FourD4ySearchHistoryEntry {
  keyword: string;
  mode: FourD4ySearchMode;
  forumId: string;
}

export const FOUR_D4Y_SEARCH_HISTORY_LIMIT: number = 12;

export function parseFourD4ySearchHistory(rawValue: string): FourD4ySearchHistoryEntry[] {
  if (rawValue.length === 0) {
    return [];
  }
  try {
    const source: FourD4ySearchHistoryEntry[] = JSON.parse(rawValue) as FourD4ySearchHistoryEntry[];
    if (!Array.isArray(source)) {
      return [];
    }
    const result: FourD4ySearchHistoryEntry[] = [];
    for (let index: number = 0; index < source.length && result.length < FOUR_D4Y_SEARCH_HISTORY_LIMIT;
      index += 1) {
      const entry: FourD4ySearchHistoryEntry = source[index];
      if (!isValidHistoryEntry(entry) || result.some((item: FourD4ySearchHistoryEntry) =>
        item.keyword === entry.keyword && item.mode === entry.mode && item.forumId === entry.forumId)) {
        continue;
      }
      result.push({ keyword: entry.keyword.trim(), mode: entry.mode, forumId: entry.forumId });
    }
    return result;
  } catch (_error) {
    return [];
  }
}

export function addFourD4ySearchHistoryEntry(entries: FourD4ySearchHistoryEntry[],
  nextEntry: FourD4ySearchHistoryEntry): FourD4ySearchHistoryEntry[] {
  if (!isValidHistoryEntry(nextEntry)) {
    return entries.slice(0, FOUR_D4Y_SEARCH_HISTORY_LIMIT);
  }
  const normalized: FourD4ySearchHistoryEntry = {
    keyword: nextEntry.keyword.trim(), mode: nextEntry.mode, forumId: nextEntry.forumId
  };
  const result: FourD4ySearchHistoryEntry[] = [normalized];
  entries.forEach((entry: FourD4ySearchHistoryEntry) => {
    if (!isValidHistoryEntry(entry) || result.length >= FOUR_D4Y_SEARCH_HISTORY_LIMIT ||
      (entry.keyword.trim() === normalized.keyword && entry.mode === normalized.mode &&
        entry.forumId === normalized.forumId)) {
      return;
    }
    result.push({ keyword: entry.keyword.trim(), mode: entry.mode, forumId: entry.forumId });
  });
  return result;
}

function isValidHistoryEntry(entry: FourD4ySearchHistoryEntry): boolean {
  return entry !== null && typeof entry.keyword === 'string' && entry.keyword.trim().length > 0 &&
    entry.keyword.trim().length <= 120 && (entry.mode === FourD4ySearchMode.Title ||
    entry.mode === FourD4ySearchMode.FullText || entry.mode === FourD4ySearchMode.Author) &&
    (entry.forumId === 'all' || /^\d+$/.test(entry.forumId));
}
