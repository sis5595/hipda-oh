import { FourD4yPageAccessState } from '../reader/FourD4yReaderContracts';

export enum ForumComposerMode {
  Reply = 'reply',
  Quote = 'quote',
  NewThread = 'newThread',
  /** A same-session edit form for one already parsed, current-user post. */
  Edit = 'edit'
}

/** Minimum identity required to validate one preflight or submit callback. */
export interface ForumComposerTarget {
  mode: ForumComposerMode;
  forumId: string;
  threadId: string;
  postId: string;
}

/** A server-provided, visible choice such as the category of a new topic. */
export interface FourD4yComposerChoice {
  value: string;
  label: string;
}

/** A current edit-form image identity with an already-rendered safe preview URL. */
export interface FourD4yComposerImageAttachment {
  attachmentId: string;
  previewUrl: string;
}

/**
 * Value-free form metadata collected from a live 4D4Y form.  CSRF and hidden
 * field values deliberately stay in ArkWeb and are never returned to ArkTS.
 * The signed-in numeric user id is included only as request context for the
 * same-session native image preflight; it is neither a credential nor stored.
 */
export interface FourD4yComposerPreflightPayload {
  mode: ForumComposerMode;
  forumId: string;
  threadId: string;
  postId: string;
  viewerUserId: string;
  loadSequence: number;
  layout: string;
  accessState: FourD4yPageAccessState;
  hasChallenge: boolean;
  formFound: boolean;
  formMethod: string;
  actionKind: string;
  hasSubmitAction: boolean;
  /** Exact tid/pid ownership of an edit form; never inferred from form text. */
  hasMatchingPostId: boolean;
  hasMatchingThreadId: boolean;
  subjectFieldName: string;
  messageFieldName: string;
  hasFormhashField: boolean;
  hasPosttimeField: boolean;
  hasWysiwygField: boolean;
  /** Value-free capability flag observed on the current 4D4Y form. */
  hasImageUploadHash: boolean;
  /** IDs of the server-side image tray; no image content or URL is exposed. */
  unusedImageAttachmentIds: string[];
  /**
   * Image attachment IDs rendered by the live edit form's own attachment
   * list. They are separate from the account-wide unused-upload tray.
   */
  editImageAttachmentIds: string[];
  /** Optional safe previews from the edit form's rendered image nodes. */
  editImageAttachments: FourD4yComposerImageAttachment[];
  categoryFieldName: string;
  categoryValue: string;
  categoryOptions: FourD4yComposerChoice[];
  tagsFieldName: string;
  /** User-authored subject from the live edit form; held only by this page. */
  initialSubject: string;
  initialMessage: string;
  errorMessage: string;
}

/** Terminal navigation result after one native composer submission. */
export interface FourD4yComposerSubmissionPayload {
  mode: ForumComposerMode;
  threadId: string;
  submissionSequence: number;
  succeeded: boolean;
  createdThreadId: string;
  loginRequired: boolean;
  errorMessage: string;
}

/** Value-free progress returned by the isolated ArkWeb image-upload page. */
export enum FourD4yImageUploadPhase {
  Selecting = 'selecting',
  Uploading = 'uploading',
  Succeeded = 'succeeded',
  Failed = 'failed',
  Cancelled = 'cancelled'
}

export interface FourD4yImageUploadStatusPayload {
  uploadSequence: number;
  phase: FourD4yImageUploadPhase;
  attachmentIds: string[];
  errorCode: string;
}

export function parseFourD4yComposerPreflightPayload(rawResult: string): FourD4yComposerPreflightPayload | null {
  const text: string | null = unwrapWebResult(rawResult);
  if (text === null) {
    return null;
  }
  try {
    const payload: FourD4yComposerPreflightPayload = JSON.parse(text) as FourD4yComposerPreflightPayload;
    if (!isForumComposerMode(payload.mode) || typeof payload.forumId !== 'string' ||
      typeof payload.threadId !== 'string' || typeof payload.postId !== 'string' ||
      typeof payload.viewerUserId !== 'string' ||
      typeof payload.loadSequence !== 'number' || typeof payload.layout !== 'string' ||
      !isFourD4yPageAccessState(payload.accessState) || typeof payload.hasChallenge !== 'boolean' ||
      typeof payload.formFound !== 'boolean' || typeof payload.formMethod !== 'string' ||
      typeof payload.actionKind !== 'string' || typeof payload.hasSubmitAction !== 'boolean' ||
      typeof payload.hasMatchingPostId !== 'boolean' || typeof payload.hasMatchingThreadId !== 'boolean' ||
      typeof payload.subjectFieldName !== 'string' || typeof payload.messageFieldName !== 'string' ||
      typeof payload.hasFormhashField !== 'boolean' || typeof payload.hasPosttimeField !== 'boolean' ||
      typeof payload.hasWysiwygField !== 'boolean' || typeof payload.hasImageUploadHash !== 'boolean' ||
      !areAttachmentIdsValid(payload.unusedImageAttachmentIds) ||
      typeof payload.categoryFieldName !== 'string' ||
      typeof payload.categoryValue !== 'string' ||
      !Array.isArray(payload.categoryOptions) || !areComposerChoicesValid(payload.categoryOptions) ||
      typeof payload.tagsFieldName !== 'string' || typeof payload.initialSubject !== 'string' ||
      typeof payload.initialMessage !== 'string' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    // This was added after the first composer contract.  A missing field is
    // safe to treat as an empty edit image list; it never authorizes a delete.
    if (payload.editImageAttachmentIds === undefined) {
      payload.editImageAttachmentIds = [];
    }
    if (!areAttachmentIdsValid(payload.editImageAttachmentIds)) {
      return null;
    }
    if (payload.editImageAttachments === undefined) {
      payload.editImageAttachments = [];
    }
    if (!areComposerImageAttachmentsValid(payload.editImageAttachments)) {
      return null;
    }
    if (payload.viewerUserId.length > 0 && !/^\d+$/.test(payload.viewerUserId)) {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yComposerSubmissionPayload(rawResult: string): FourD4yComposerSubmissionPayload | null {
  const text: string | null = unwrapWebResult(rawResult);
  if (text === null) {
    return null;
  }
  try {
    const payload: FourD4yComposerSubmissionPayload = JSON.parse(text) as FourD4yComposerSubmissionPayload;
    if (!isForumComposerMode(payload.mode) || typeof payload.threadId !== 'string' ||
      typeof payload.submissionSequence !== 'number' || typeof payload.succeeded !== 'boolean' ||
      typeof payload.createdThreadId !== 'string' || typeof payload.loginRequired !== 'boolean' ||
      typeof payload.errorMessage !== 'string') {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function parseFourD4yImageUploadStatusPayload(rawResult: string): FourD4yImageUploadStatusPayload | null {
  const text: string | null = unwrapWebResult(rawResult);
  if (text === null) {
    return null;
  }
  try {
    const payload: FourD4yImageUploadStatusPayload = JSON.parse(text) as FourD4yImageUploadStatusPayload;
    if (typeof payload.uploadSequence !== 'number' || !isFourD4yImageUploadPhase(payload.phase) ||
      !Array.isArray(payload.attachmentIds) || payload.attachmentIds.length > 1 ||
      typeof payload.errorCode !== 'string' || payload.errorCode.length > 80) {
      return null;
    }
    for (let index: number = 0; index < payload.attachmentIds.length; index += 1) {
      if (!/^\d+$/.test(payload.attachmentIds[index])) {
        return null;
      }
    }
    return payload;
  } catch (_error) {
    return null;
  }
}

export function isExpectedFourD4yComposerPreflight(payload: FourD4yComposerPreflightPayload,
  route: ForumComposerTarget, loadSequence: number): boolean {
  return payload.mode === route.mode && payload.forumId === route.forumId &&
    payload.threadId === route.threadId && payload.postId === route.postId &&
    payload.loadSequence === loadSequence;
}

export function isReadyFourD4yComposerForm(payload: FourD4yComposerPreflightPayload,
  route: ForumComposerTarget): boolean {
  if (!isExpectedFourD4yComposerPreflight(payload, route, payload.loadSequence) ||
    !payload.formFound || payload.formMethod !== 'post' || payload.messageFieldName !== 'message' ||
    !payload.hasFormhashField || !payload.hasPosttimeField || !payload.hasWysiwygField ||
    !payload.hasSubmitAction) {
    return false;
  }
  if (route.mode === ForumComposerMode.NewThread) {
    return payload.actionKind === 'newthread' && payload.subjectFieldName === 'subject';
  }
  if (route.mode === ForumComposerMode.Edit) {
    return payload.actionKind === 'edit' && payload.hasMatchingPostId && payload.hasMatchingThreadId;
  }
  return payload.actionKind === 'reply';
}

export function isExpectedFourD4yComposerSubmission(payload: FourD4yComposerSubmissionPayload,
  route: ForumComposerTarget, submissionSequence: number): boolean {
  if (payload.mode !== route.mode || payload.submissionSequence !== submissionSequence) {
    return false;
  }
  if (route.mode === ForumComposerMode.NewThread) {
    return payload.threadId === '';
  }
  return payload.threadId === route.threadId;
}

export function getFourD4yComposerTitle(route: ForumComposerTarget): string {
  if (route.mode === ForumComposerMode.NewThread) {
    return '发新主题';
  }
  if (route.mode === ForumComposerMode.Quote) {
    return '引用回复';
  }
  return route.mode === ForumComposerMode.Edit ? '编辑' : '回复';
}

/**
 * Returns only the numeric image attachment IDs that the member explicitly
 * placed in an edit message.  This deliberately does not inspect page HTML
 * or the server's unused-upload tray: those can contain stale uploads from
 * other composing attempts and are not evidence of an image in this post.
 */
export function extractFourD4yInlineImageAttachmentIds(message: string): string[] {
  const attachmentIds: string[] = [];
  const pattern: RegExp = /\[attachimg\]([0-9]+)\[\/attachimg\]/ig;
  let matched: RegExpExecArray | null = pattern.exec(message);
  while (matched !== null) {
    const attachmentId: string = matched[1];
    if (attachmentIds.indexOf(attachmentId) < 0) {
      attachmentIds.push(attachmentId);
    }
    matched = pattern.exec(message);
  }
  return attachmentIds;
}

function unwrapWebResult(rawResult: string): string | null {
  let text: string = rawResult.trim();
  for (let index: number = 0; index < 2; index += 1) {
    if (!text.startsWith('"')) {
      break;
    }
    try {
      const decoded: string = JSON.parse(text) as string;
      if (typeof decoded !== 'string') {
        return null;
      }
      text = decoded.trim();
    } catch (_error) {
      return null;
    }
  }
  return text.length > 0 ? text : null;
}

function isForumComposerMode(value: ForumComposerMode): boolean {
  return value === ForumComposerMode.Reply || value === ForumComposerMode.Quote ||
    value === ForumComposerMode.NewThread || value === ForumComposerMode.Edit;
}

function isFourD4yPageAccessState(value: FourD4yPageAccessState): boolean {
  return value === FourD4yPageAccessState.Available || value === FourD4yPageAccessState.LoginRequired;
}

function isFourD4yImageUploadPhase(value: FourD4yImageUploadPhase): boolean {
  return value === FourD4yImageUploadPhase.Selecting ||
    value === FourD4yImageUploadPhase.Uploading ||
    value === FourD4yImageUploadPhase.Succeeded ||
    value === FourD4yImageUploadPhase.Failed ||
    value === FourD4yImageUploadPhase.Cancelled;
}

function areComposerChoicesValid(options: FourD4yComposerChoice[]): boolean {
  if (options.length > 50) {
    return false;
  }
  for (let index: number = 0; index < options.length; index += 1) {
    const option: FourD4yComposerChoice = options[index];
    if (typeof option.value !== 'string' || typeof option.label !== 'string' ||
      option.value.length > 80 || option.label.length > 80) {
      return false;
    }
  }
  return true;
}

function areAttachmentIdsValid(attachmentIds: string[]): boolean {
  if (!Array.isArray(attachmentIds) || attachmentIds.length > 100) {
    return false;
  }
  for (let index: number = 0; index < attachmentIds.length; index += 1) {
    if (typeof attachmentIds[index] !== 'string' || !/^\d+$/.test(attachmentIds[index])) {
      return false;
    }
  }
  return true;
}

function areComposerImageAttachmentsValid(attachments: FourD4yComposerImageAttachment[]): boolean {
  if (!Array.isArray(attachments) || attachments.length > 100) {
    return false;
  }
  for (let index: number = 0; index < attachments.length; index += 1) {
    const attachment: FourD4yComposerImageAttachment = attachments[index];
    if (attachment === undefined || !/^\d+$/.test(attachment.attachmentId) ||
      typeof attachment.previewUrl !== 'string' || attachment.previewUrl.length > 2048 ||
      (attachment.previewUrl.length > 0 && !/^https?:\/\//i.test(attachment.previewUrl))) {
      return false;
    }
  }
  return true;
}
