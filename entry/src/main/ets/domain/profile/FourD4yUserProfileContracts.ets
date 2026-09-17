import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/** A visible profile fact. The app keeps text only, never the source HTML. */
export interface FourD4yUserProfileFact {
  label: string;
  value: string;
}

/** Value-free, read-only profile data extracted inside the signed-in ArkWeb page. */
export interface FourD4yUserProfilePayload {
  requestedUserId: string;
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  profileLayoutFound: boolean;
  userId: string;
  userName: string;
  isOnline: boolean;
  facts: FourD4yUserProfileFact[];
  errorMessage: string;
}

export enum FourD4yUserProfileReaderOutcome {
  Content = 'content',
  LoginRequired = 'loginRequired',
  VerificationRequired = 'verificationRequired',
  Unavailable = 'unavailable',
  UnsupportedLayout = 'unsupportedLayout'
}

/** The current server profile page plus an opaque request identity for ArkWeb callbacks. */
export function buildFourD4yUserProfileUrl(userId: string, loadSequence: number): string | null {
  if (!isDigitsOnly(userId) || !isPositiveInteger(loadSequence)) {
    return null;
  }
  return 'https://www.4d4y.com/forum/space.php?uid=' + userId + '&oh_profile=' + loadSequence;
}

/** Accept only the fixed read-only profile endpoint and our active sequence. */
export function isCurrentFourD4yUserProfileRequest(url: string, userId: string,
  loadSequence: number): boolean {
  if (!isDigitsOnly(userId) || !isPositiveInteger(loadSequence)) {
    return false;
  }
  const match: RegExpMatchArray | null = url.match(
    /^https:\/\/www\.4d4y\.com\/forum\/space\.php\?([^#]*)$/i);
  if (match === null) {
    return false;
  }
  const query: string = match[1];
  return new RegExp('(?:^|&)uid=' + userId + '(?:&|$)').test(query) &&
    new RegExp('(?:^|&)oh_profile=' + loadSequence + '(?:&|$)').test(query);
}

export function parseFourD4yUserProfilePayload(rawResult: string): FourD4yUserProfilePayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yUserProfilePayload = JSON.parse(payloadText) as FourD4yUserProfilePayload;
    if (!isDigitsOnly(payload.requestedUserId) || !isPositiveInteger(payload.loadSequence) ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.profileLayoutFound !== 'boolean' ||
      (payload.userId.length > 0 && !isDigitsOnly(payload.userId)) ||
      typeof payload.userName !== 'string' || typeof payload.isOnline !== 'boolean' ||
      !areProfileFactsValid(payload.facts) || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yUserProfilePayload(payload: FourD4yUserProfilePayload,
  userId: string, loadSequence: number): boolean {
  return payload.requestedUserId === userId && payload.userId === userId &&
    payload.loadSequence === loadSequence && isDigitsOnly(userId) && isPositiveInteger(loadSequence);
}

export function getFourD4yUserProfileReaderOutcome(payload: FourD4yUserProfilePayload):
  FourD4yUserProfileReaderOutcome {
  if (payload.accessState === FourD4yPageAccessState.LoginRequired) {
    return FourD4yUserProfileReaderOutcome.LoginRequired;
  }
  if (payload.profileLayoutFound && payload.userId.length > 0 && payload.userName.length > 0) {
    return FourD4yUserProfileReaderOutcome.Content;
  }
  if (payload.hasChallenge) {
    return FourD4yUserProfileReaderOutcome.VerificationRequired;
  }
  if (payload.errorMessage.length > 0) {
    return FourD4yUserProfileReaderOutcome.Unavailable;
  }
  return FourD4yUserProfileReaderOutcome.UnsupportedLayout;
}

function areProfileFactsValid(facts: FourD4yUserProfileFact[]): boolean {
  if (!Array.isArray(facts) || facts.length > 60) {
    return false;
  }
  for (let index: number = 0; index < facts.length; index += 1) {
    const fact: FourD4yUserProfileFact = facts[index];
    if (typeof fact.label !== 'string' || typeof fact.value !== 'string' ||
      fact.label.length === 0 || fact.label.length > 80 ||
      fact.value.length === 0 || fact.value.length > 400) {
      return false;
    }
  }
  return true;
}

function unwrapWebResult(rawResult: string): string | null {
  let payloadText: string = rawResult;
  try {
    if (payloadText.startsWith('"')) {
      payloadText = JSON.parse(payloadText) as string;
    }
    return payloadText.trim().startsWith('{') ? payloadText.trim() : null;
  } catch (_error) {
    return null;
  }
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigitsOnly(value: string): boolean {
  return typeof value === 'string' && /^\d{1,20}$/.test(value);
}

function isPositiveInteger(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value) && Math.floor(value) === value && value > 0;
}
