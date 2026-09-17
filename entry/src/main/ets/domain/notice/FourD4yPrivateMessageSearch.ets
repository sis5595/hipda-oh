import { FourD4yPrivateConversationMessage } from './FourD4yPrivateConversationContracts';

/**
 * Transient, in-memory search result for a private-message conversation.
 * The complete message text never leaves the current request loop and is not
 * written to Preferences, RDB, files, or a search index.
 */
export interface FourD4yPrivateMessageSearchHit {
  participantUserId: string;
  participantName: string;
  messageId: string;
  excerpt: string;
  occurredAt: string;
  isMine: boolean;
}

const MAX_QUERY_LENGTH: number = 120;
const EXCERPT_SIDE_LENGTH: number = 72;
const MAX_EXCERPT_LENGTH: number = 220;

/** Normalizes whitespace and case before matching a message body. */
export function normalizeFourD4yPrivateMessageSearchQuery(value: string): string {
  if (typeof value !== 'string') {
    return '';
  }
  return value.replace(/\s+/g, ' ').trim().toLowerCase().slice(0, MAX_QUERY_LENGTH);
}

/**
 * Finds all body matches in one already-read conversation. This is pure so it
 * can be regression-tested without retaining any private-message fixture.
 */
export function findFourD4yPrivateMessageSearchHits(query: string, participantUserId: string,
  participantName: string, messages: FourD4yPrivateConversationMessage[]): FourD4yPrivateMessageSearchHit[] {
  const normalizedQuery: string = normalizeFourD4yPrivateMessageSearchQuery(query);
  if (normalizedQuery.length === 0 || !/^\d+$/.test(participantUserId) || !Array.isArray(messages)) {
    return [];
  }
  const hits: FourD4yPrivateMessageSearchHit[] = [];
  const identifiers: Set<string> = new Set<string>();
  for (const message of messages) {
    if (message === null || typeof message.body !== 'string' || typeof message.messageId !== 'string' ||
      identifiers.has(message.messageId)) {
      continue;
    }
    const body: string = normalizeSearchText(message.body);
    const matchIndex: number = body.toLowerCase().indexOf(normalizedQuery);
    if (matchIndex < 0) {
      continue;
    }
    identifiers.add(message.messageId);
    hits.push({
      participantUserId: participantUserId,
      participantName: boundedText(participantName, 120),
      messageId: message.messageId,
      excerpt: buildFourD4yPrivateMessageSearchExcerpt(body, matchIndex, normalizedQuery.length),
      occurredAt: boundedText(message.occurredAt, 100),
      isMine: message.isMine
    });
  }
  return hits;
}

export function buildFourD4yPrivateMessageSearchExcerpt(body: string, matchIndex: number,
  queryLength: number): string {
  const normalizedBody: string = normalizeSearchText(body);
  if (normalizedBody.length === 0 || matchIndex < 0 || queryLength < 1 || matchIndex >= normalizedBody.length) {
    return '';
  }
  const start: number = Math.max(0, matchIndex - EXCERPT_SIDE_LENGTH);
  const requiredEnd: number = matchIndex + queryLength + EXCERPT_SIDE_LENGTH;
  const end: number = Math.min(normalizedBody.length, Math.max(start + queryLength, requiredEnd));
  const prefix: string = start > 0 ? '…' : '';
  const suffix: string = end < normalizedBody.length ? '…' : '';
  return (prefix + normalizedBody.slice(start, end) + suffix).slice(0, MAX_EXCERPT_LENGTH);
}

function normalizeSearchText(value: string): string {
  return typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';
}

function boundedText(value: string, maximum: number): string {
  return typeof value === 'string' ? value.slice(0, maximum) : '';
}
