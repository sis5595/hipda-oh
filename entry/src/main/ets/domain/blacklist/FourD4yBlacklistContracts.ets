import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** One server-side username rendered by 4D4Y's native blacklist page. */
export interface FourD4yBlacklistEntry {
  userName: string;
}

/** Value-free result extracted from `pm.php?action=viewblack`. */
export interface FourD4yBlacklistPagePayload {
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  blacklistLayoutFound: boolean;
  hasMutationToken: boolean;
  hasRemovalControl: boolean;
  errorMessage: string;
  entries: FourD4yBlacklistEntry[];
}

/** Immediate acknowledgement that an in-page blacklist form was started. */
export interface FourD4yBlacklistMutationStartPayload {
  userName: string;
  operationSequence: number;
  started: boolean;
  errorMessage: string;
}

/**
 * Value-free terminal state from the exact add/remove response page. It can
 * report a server rejection early, but a fresh blacklist read still decides
 * success.
 */
export interface FourD4yBlacklistMutationResultPayload {
  operationSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  message: string;
  errorMessage: string;
}

export enum FourD4yBlacklistMutationKind {
  Add = 'add',
  Remove = 'remove'
}

export enum FourD4yBlacklistReaderOutcome {
  Content = 'content',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  UnsupportedLayout = 'unsupportedLayout'
}

/** Fixed, read-only endpoint with an opaque ArkWeb callback identity. */
export function buildFourD4yBlacklistUrl(loadSequence: number): string | null {
  if (!isPositiveInteger(loadSequence)) {
    return null;
  }
  return 'https://www.4d4y.com/forum/pm.php?action=viewblack&oh_blacklist_load=' + loadSequence;
}

/** Accept callbacks only from the fixed endpoint and the active request. */
export function isCurrentFourD4yBlacklistRequest(url: string, loadSequence: number): boolean {
  if (!isPositiveInteger(loadSequence) || typeof url !== 'string' ||
    url.indexOf('https://www.4d4y.com/forum/pm.php?') !== 0) {
    return false;
  }
  return /(?:[?&])action=viewblack(?:&|$)/.test(url) &&
    new RegExp('(?:[?&])oh_blacklist_load=' + loadSequence + '(?:&|$)').test(url);
}

export function parseFourD4yBlacklistPagePayload(rawResult: string): FourD4yBlacklistPagePayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yBlacklistPagePayload = JSON.parse(payloadText) as FourD4yBlacklistPagePayload;
    if (!isPositiveInteger(payload.loadSequence) || !isAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.blacklistLayoutFound !== 'boolean' ||
      typeof payload.hasMutationToken !== 'boolean' || typeof payload.hasRemovalControl !== 'boolean' ||
      typeof payload.errorMessage !== 'string' || !Array.isArray(payload.entries) ||
      !areEntriesValid(payload.entries)) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yBlacklistMutationStartPayload(rawResult: string):
  FourD4yBlacklistMutationStartPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yBlacklistMutationStartPayload =
      JSON.parse(payloadText) as FourD4yBlacklistMutationStartPayload;
    if (!isValidFourD4yBlacklistUserName(payload.userName) || !isPositiveInteger(payload.operationSequence) ||
      typeof payload.started !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yBlacklistMutationResultPayload(rawResult: string):
  FourD4yBlacklistMutationResultPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yBlacklistMutationResultPayload =
      JSON.parse(payloadText) as FourD4yBlacklistMutationResultPayload;
    if (!isPositiveInteger(payload.operationSequence) || !isAccessState(payload.accessState) ||
      typeof payload.hasChallenge !== 'boolean' || typeof payload.message !== 'string' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yBlacklistPagePayload(payload: FourD4yBlacklistPagePayload,
  loadSequence: number): boolean {
  return payload.loadSequence === loadSequence;
}

export function isExpectedFourD4yBlacklistMutationStartPayload(
  payload: FourD4yBlacklistMutationStartPayload, userName: string, operationSequence: number): boolean {
  return payload.userName === normalizeFourD4yBlacklistUserName(userName) &&
    payload.operationSequence === operationSequence;
}

export function isExpectedFourD4yBlacklistMutationResultPayload(
  payload: FourD4yBlacklistMutationResultPayload, operationSequence: number): boolean {
  return payload.operationSequence === operationSequence;
}

export function getFourD4yBlacklistReaderOutcome(payload: FourD4yBlacklistPagePayload):
  FourD4yBlacklistReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yBlacklistReaderOutcome.LoginRequired;
  }
  if (payload.blacklistLayoutFound) {
    return FourD4yBlacklistReaderOutcome.Content;
  }
  if (payload.hasChallenge) {
    return FourD4yBlacklistReaderOutcome.VerificationRequired;
  }
  return FourD4yBlacklistReaderOutcome.UnsupportedLayout;
}

/** Usernames are data, never a URL or a script fragment. */
export function normalizeFourD4yBlacklistUserName(value: string): string {
  return typeof value === 'string' ? value.trim().substring(0, 160) : '';
}

export function isValidFourD4yBlacklistUserName(value: string): boolean {
  const normalized: string = normalizeFourD4yBlacklistUserName(value);
  return normalized.length > 0 && !/[\u0000-\u001F\u007F]/.test(normalized);
}

function areEntriesValid(entries: FourD4yBlacklistEntry[]): boolean {
  const seen: Set<string> = new Set<string>();
  for (const entry of entries) {
    if (entry === null || typeof entry !== 'object' || !isValidFourD4yBlacklistUserName(entry.userName) ||
      entry.userName !== normalizeFourD4yBlacklistUserName(entry.userName) || seen.has(entry.userName)) {
      return false;
    }
    seen.add(entry.userName);
  }
  return true;
}

function isAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isPositiveInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value >= 1;
}

function unwrapWebResult(rawResult: string): string | null {
  let payloadText: string = rawResult;
  try {
    if (payloadText.startsWith('"')) {
      payloadText = JSON.parse(payloadText) as string;
    }
    return payloadText;
  } catch (_error) {
    return null;
  }
}
