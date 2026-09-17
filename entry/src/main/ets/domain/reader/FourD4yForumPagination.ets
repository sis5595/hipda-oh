import { ThreadSummary } from '../model/ForumModels';

/**
 * Combines adjacent 4D4Y board pages without displaying duplicated pinned
 * rows. The first occurrence stays authoritative because it is the one the
 * reader showed before the user reached the page boundary.
 */
export function appendUniqueFourD4yForumThreads(existing: ThreadSummary[], incoming: ThreadSummary[]): ThreadSummary[] {
  const merged: ThreadSummary[] = [...existing];
  const seenIds: string[] = [];
  for (let index = 0; index < merged.length; index += 1) {
    if (merged[index].id.length > 0) {
      seenIds.push(merged[index].id);
    }
  }
  for (let index = 0; index < incoming.length; index += 1) {
    const candidate: ThreadSummary = incoming[index];
    if (candidate.id.length > 0 && seenIds.indexOf(candidate.id) < 0) {
      seenIds.push(candidate.id);
      merged.push(candidate);
    }
  }
  return merged;
}
