/**
 * Forum data owned by the application, independent of the remote HTML layout.
 * Parsing adapters will turn HiPDA pages into these models.
 */
export interface ForumSummary {
  id: string;
  name: string;
  description?: string;
}

export interface ThreadSummary {
  id: string;
  forumId: string;
  title: string;
  authorName: string;
  replyCount: number;
  /** Server-rendered topic views from the board row. */
  viewCount?: number;
  /** Visible board category attached to this topic, not the board-wide filter. */
  threadType?: string;
  /** True only when the board row advertises an image attachment. */
  hasImage?: boolean;
  /** Original topic creation time; never the last-reply cell. */
  createdAt?: string;
  isPinned: boolean;
}

export interface PostContent {
  kind: 'text' | 'quote' | 'emoji' | 'image' | 'attachment' | 'link' | 'video';
  value: string;
  url?: string;
  /** A directly-renderable attachment preview; `url` remains the full image target. */
  previewUrl?: string;
}

export interface ThreadPost {
  id: string;
  threadId: string;
  floor: number;
  authorName: string;
  /** Numeric Discuz uid when the current thread template exposes the author's profile link. */
  authorUserId?: string;
  publishedAt?: string;
  content: PostContent[];
}

/**
 * A value-only poll projection from the currently displayed 4D4Y topic.
 * Option ids identify a selection only for the lifetime of this document; no
 * CSRF value, cookie, or raw form data belongs in the native model.
 */
export interface ThreadPollOption {
  id: string;
  label: string;
  /** Empty before voting when the server hides results. */
  resultText: string;
}

export interface ThreadPoll {
  infoText: string;
  footerText: string;
  maxSelections: number;
  isMultipleChoice: boolean;
  /**
   * True only when the loaded page exposes the expected same-origin vote
   * form. It is a read-only capability signal, not authority to submit.
   */
  isVoteFormAvailable: boolean;
  options: ThreadPollOption[];
}

export interface ThreadPage {
  threadId: string;
  title: string;
  currentPage: number;
  lastPage: number;
  posts: ThreadPost[];
}
