import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/**
 * Value-free contract for the live 4D4Y private-message form.  The hidden
 * ArkWeb document owns every CSRF/session value; ArkTS receives structural
 * facts only and never persists a form field.
 */
export interface FourD4yPrivateMessagePreflightPayload {
  participantUserId: string;
  loadSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionKind: string;
  actionParticipantUserId: string;
  messageFieldName: string;
  hasFormhashField: boolean;
  hasLastDateRangeField: boolean;
  errorMessage: string;
}

/** Value-free terminal result for one private-message form submission. */
export interface FourD4yPrivateMessageSubmissionPayload {
  participantUserId: string;
  submissionSequence: number;
  succeeded: boolean;
  loginRequired: boolean;
  errorMessage: string;
}

export function buildFourD4yPrivateMessagePreflightUrl(participantUserId: string,
  loadSequence: number): string | null {
  if (!isDigitsOnly(participantUserId) || !Number.isInteger(loadSequence) || loadSequence < 1) {
    return null;
  }
  // NG obtains the conversation's current PM form through daterange=1.  The
  // sequence is a client-only correlation marker, never a server credential.
  return 'https://www.4d4y.com/forum/pm.php?daterange=1&uid=' + participantUserId +
    '&oh_pm_compose=' + loadSequence;
}

export function parseFourD4yPrivateMessagePreflightPayload(rawResult: string):
  FourD4yPrivateMessagePreflightPayload | null {
  const value: Object | null = parseWebObject(rawResult);
  if (value === null) {
    return null;
  }
  const payload: FourD4yPrivateMessagePreflightPayload = value as FourD4yPrivateMessagePreflightPayload;
  if (typeof payload.participantUserId !== 'string' || typeof payload.loadSequence !== 'number' ||
    !isPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
    typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
    typeof payload.actionKind !== 'string' || typeof payload.actionParticipantUserId !== 'string' ||
    typeof payload.messageFieldName !== 'string' || typeof payload.hasFormhashField !== 'boolean' ||
    typeof payload.hasLastDateRangeField !== 'boolean' || typeof payload.errorMessage !== 'string') {
    return null;
  }
  return payload;
}

export function parseFourD4yPrivateMessageSubmissionPayload(rawResult: string):
  FourD4yPrivateMessageSubmissionPayload | null {
  const value: Object | null = parseWebObject(rawResult);
  if (value === null) {
    return null;
  }
  const payload: FourD4yPrivateMessageSubmissionPayload = value as FourD4yPrivateMessageSubmissionPayload;
  if (typeof payload.participantUserId !== 'string' || typeof payload.submissionSequence !== 'number' ||
    typeof payload.succeeded !== 'boolean' || typeof payload.loginRequired !== 'boolean' ||
    typeof payload.errorMessage !== 'string') {
    return null;
  }
  return payload;
}

export function isExpectedFourD4yPrivateMessagePreflight(payload: FourD4yPrivateMessagePreflightPayload,
  participantUserId: string, loadSequence: number): boolean {
  return payload.participantUserId === participantUserId && payload.loadSequence === loadSequence &&
    isDigitsOnly(payload.participantUserId) && Number.isInteger(payload.loadSequence) &&
    payload.loadSequence > 0;
}

export function isReadyFourD4yPrivateMessageForm(payload: FourD4yPrivateMessagePreflightPayload,
  participantUserId: string): boolean {
  return payload.accessState === FourD4yPageAccessState.Available && payload.formFound &&
    payload.formMethod.toLowerCase() === 'post' && payload.actionKind === 'send' &&
    payload.actionParticipantUserId === participantUserId && payload.messageFieldName === 'message' &&
    payload.hasFormhashField;
}

export function isExpectedFourD4yPrivateMessageSubmission(payload: FourD4yPrivateMessageSubmissionPayload,
  participantUserId: string, submissionSequence: number): boolean {
  return payload.participantUserId === participantUserId && payload.submissionSequence === submissionSequence &&
    isDigitsOnly(payload.participantUserId) && Number.isInteger(payload.submissionSequence) &&
    payload.submissionSequence > 0;
}

function parseWebObject(rawResult: string): Object | null {
  if (typeof rawResult !== 'string') {
    return null;
  }
  let candidate: string = rawResult.trim();
  for (let attempt: number = 0; attempt < 3; attempt += 1) {
    try {
      const parsed: Object | string = JSON.parse(candidate) as Object | string;
      if (typeof parsed === 'string') {
        candidate = parsed;
        continue;
      }
      return parsed !== null && typeof parsed === 'object' ? parsed : null;
    } catch (_error) {
      return null;
    }
  }
  return null;
}

function isPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigitsOnly(value: string): boolean {
  return typeof value === 'string' && /^\d+$/.test(value) && value.length <= 20;
}
