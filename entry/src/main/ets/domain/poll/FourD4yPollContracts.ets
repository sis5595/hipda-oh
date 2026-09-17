import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

/**
 * Value-only description of one fresh `form#poll` document.  The native side
 * never receives formhash or any raw form HTML; option identifiers live only
 * for the immediate user selection and one form submission attempt.
 */
export interface FourD4yVotePreflightPayload {
  threadId: string;
  formSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionPath: string;
  hasFormhashField: boolean;
  hasPollSubmitAction: boolean;
  maxSelections: number;
  isMultipleChoice: boolean;
  optionIds: string[];
  errorMessage: string;
}

/** A bounded terminal reread after the native form request has started. */
export interface FourD4yVoteVerificationPayload {
  threadId: string;
  submissionSequence: number;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  pollFound: boolean;
  /** Whether the fresh page still offers the same kind of vote form. */
  voteFormAvailable: boolean;
  resultRowCount: number;
  errorMessage: string;
}

/** Immediate local acknowledgement that the fresh browser form accepted submit. */
export interface FourD4yVoteSubmissionStartPayload {
  threadId: string;
  submissionSequence: number;
  started: boolean;
  errorMessage: string;
}

export function parseFourD4yVotePreflightPayload(rawResult: string): FourD4yVotePreflightPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yVotePreflightPayload = JSON.parse(payloadText) as FourD4yVotePreflightPayload;
    if (!isDigits(payload.threadId) || typeof payload.formSequence !== 'number' ||
      !isAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
      typeof payload.actionPath !== 'string' || typeof payload.hasFormhashField !== 'boolean' ||
      typeof payload.hasPollSubmitAction !== 'boolean' || typeof payload.maxSelections !== 'number' ||
      !Number.isFinite(payload.maxSelections) || payload.maxSelections < 1 || payload.maxSelections > 30 ||
      typeof payload.isMultipleChoice !== 'boolean' || !Array.isArray(payload.optionIds) ||
      payload.optionIds.length > 30 || typeof payload.errorMessage !== 'string') {
      return null;
    }
    const seen: string[] = [];
    for (let index: number = 0; index < payload.optionIds.length; index += 1) {
      const optionId: string = payload.optionIds[index];
      if (!isDigits(optionId) || optionId.length > 20 || seen.indexOf(optionId) >= 0) {
        return null;
      }
      seen.push(optionId);
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yVoteVerificationPayload(rawResult: string): FourD4yVoteVerificationPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yVoteVerificationPayload = JSON.parse(payloadText) as FourD4yVoteVerificationPayload;
    if (!isDigits(payload.threadId) || typeof payload.submissionSequence !== 'number' ||
      !isAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.pollFound !== 'boolean' || typeof payload.voteFormAvailable !== 'boolean' ||
      typeof payload.resultRowCount !== 'number' || !Number.isFinite(payload.resultRowCount) ||
      payload.resultRowCount < 0 || payload.resultRowCount > 30 || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yVoteSubmissionStartPayload(rawResult: string): FourD4yVoteSubmissionStartPayload | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null) {
    return null;
  }
  try {
    const payload: FourD4yVoteSubmissionStartPayload = JSON.parse(payloadText) as FourD4yVoteSubmissionStartPayload;
    if (!isDigits(payload.threadId) || typeof payload.submissionSequence !== 'number' ||
      typeof payload.started !== 'boolean' || typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yVotePreflightPayload(payload: FourD4yVotePreflightPayload,
  threadId: string, formSequence: number): boolean {
  return payload.threadId === threadId && payload.formSequence === formSequence;
}

export function isReadyFourD4yVoteForm(payload: FourD4yVotePreflightPayload,
  selectedOptionIds: string[]): boolean {
  if (payload.accessState !== FourD4yPageAccessState.Available || !payload.formFound ||
    payload.formMethod !== 'post' || payload.actionPath !== '/forum/misc.php?action=votepoll&pollsubmit=yes' ||
    !payload.hasFormhashField || !payload.hasPollSubmitAction || payload.optionIds.length < 2 ||
    selectedOptionIds.length < 1 || selectedOptionIds.length > payload.maxSelections) {
    return false;
  }
  const seen: string[] = [];
  for (let index: number = 0; index < selectedOptionIds.length; index += 1) {
    const selected: string = selectedOptionIds[index];
    if (payload.optionIds.indexOf(selected) < 0 || seen.indexOf(selected) >= 0) {
      return false;
    }
    seen.push(selected);
  }
  return true;
}

export function isExpectedFourD4yVoteVerificationPayload(payload: FourD4yVoteVerificationPayload,
  threadId: string, submissionSequence: number): boolean {
  return payload.threadId === threadId && payload.submissionSequence === submissionSequence;
}

export function isExpectedFourD4yVoteSubmissionStartPayload(payload: FourD4yVoteSubmissionStartPayload,
  threadId: string, submissionSequence: number): boolean {
  return payload.threadId === threadId && payload.submissionSequence === submissionSequence;
}

/**
 * The fresh form was actionable immediately before submission. A later
 * results-only poll is therefore the only server-rendered success signal this
 * client accepts; transient Ajax text is deliberately not treated as proof.
 */
export function isConfirmedFourD4yVoteResult(payload: FourD4yVoteVerificationPayload): boolean {
  return payload.accessState === FourD4yPageAccessState.Available && payload.pollFound &&
    !payload.voteFormAvailable && payload.resultRowCount >= 2;
}

function isAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isDigits(value: string): boolean {
  return /^\d+$/.test(value);
}

function unwrapWebResult(rawResult: string): string | null {
  try {
    return rawResult.startsWith('"') ? JSON.parse(rawResult) as string : rawResult;
  } catch (_error) {
    return null;
  }
}
