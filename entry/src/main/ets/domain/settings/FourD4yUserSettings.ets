import { FOUR_D4Y_QUICK_FORUM_IDS, getFourD4yForums } from '../catalog/FourD4yForumCatalog';
import { FOUR_D4Y_DEFAULT_POST_TAIL_TEXT, FOUR_D4Y_DEFAULT_POST_TAIL_URL, FourD4yPostTailSettings,
  normalizeFourD4yPostTailText, normalizeFourD4yPostTailUrl } from './FourD4yPostTail';

/** Appearance choices intentionally mirror the three choices exposed by MY 4D4Y. */
export enum FourD4yThemeMode {
  FollowSystem = 'system',
  Light = 'light',
  Dark = 'dark'
}

/** Applies only to post-body images; emoticons remain small inline content. */
export enum FourD4yImageLoadPolicy {
  Automatic = 'automatic',
  TapToLoad = 'tap'
}

export interface FourD4yUserSettings extends FourD4yPostTailSettings {
  themeMode: FourD4yThemeMode;
  fontScale: number;
  /** Multiplier applied only to readable post-body and quote line heights. */
  postLineSpacing: number;
  imageLoadPolicy: FourD4yImageLoadPolicy;
  quickForumIds: string[];
  /** NG-compatible global visibility switch; true preserves the existing client behavior. */
  showPinnedThreads: boolean;
  /** Forum IDs whose list requests use the server's `orderby=dateline` mode. */
  postTimeSortForumIds: string[];
}

export const FOUR_D4Y_FONT_SCALES: number[] = [0.9, 1, 1.15, 1.3];
export const FOUR_D4Y_POST_LINE_SPACINGS: number[] = [1, 1.12, 1.24, 1.4];
export const FOUR_D4Y_MAX_QUICK_FORUMS: number = 12;

const knownForumIds: string[] = getFourD4yForums().map((forum) => forum.id);

export function createDefaultFourD4yUserSettings(): FourD4yUserSettings {
  return {
    themeMode: FourD4yThemeMode.FollowSystem,
    fontScale: 1,
    postLineSpacing: 1,
    imageLoadPolicy: FourD4yImageLoadPolicy.Automatic,
    quickForumIds: [...FOUR_D4Y_QUICK_FORUM_IDS],
    showPinnedThreads: true,
    postTimeSortForumIds: [],
    addPostTail: false,
    postTailText: FOUR_D4Y_DEFAULT_POST_TAIL_TEXT,
    postTailUrl: FOUR_D4Y_DEFAULT_POST_TAIL_URL
  };
}

/** Accepts only bounded, value-free local preferences. It never contains forum session data. */
export function parseFourD4yUserSettings(rawValue: string): FourD4yUserSettings {
  const defaults: FourD4yUserSettings = createDefaultFourD4yUserSettings();
  if (rawValue.length === 0 || rawValue.length > 4096) {
    return defaults;
  }
  try {
    const candidate: Object = JSON.parse(rawValue) as Object;
    const value: Record<string, Object> = candidate as Record<string, Object>;
    return {
      themeMode: normalizeFourD4yThemeMode(value['themeMode']),
      fontScale: normalizeFourD4yFontScale(value['fontScale']),
      postLineSpacing: normalizeFourD4yPostLineSpacing(value['postLineSpacing']),
      imageLoadPolicy: normalizeFourD4yImageLoadPolicy(value['imageLoadPolicy']),
      quickForumIds: normalizeFourD4yQuickForumIds(value['quickForumIds']),
      showPinnedThreads: normalizeFourD4yShowPinnedThreads(value['showPinnedThreads']),
      postTimeSortForumIds: normalizeFourD4yPostTimeSortForumIds(value['postTimeSortForumIds']),
      addPostTail: value['addPostTail'] === true,
      postTailText: normalizeFourD4yPostTailText(value['postTailText']),
      postTailUrl: normalizeFourD4yPostTailUrl(value['postTailUrl'])
    };
  } catch (_error) {
    return defaults;
  }
}

export function serializeFourD4yUserSettings(settings: FourD4yUserSettings): string {
  const normalized: FourD4yUserSettings = normalizeFourD4yUserSettings(settings);
  return JSON.stringify(normalized);
}

export function normalizeFourD4yUserSettings(settings: FourD4yUserSettings): FourD4yUserSettings {
  return {
    themeMode: normalizeFourD4yThemeMode(settings.themeMode),
    fontScale: normalizeFourD4yFontScale(settings.fontScale),
    postLineSpacing: normalizeFourD4yPostLineSpacing(settings.postLineSpacing),
    imageLoadPolicy: normalizeFourD4yImageLoadPolicy(settings.imageLoadPolicy),
    quickForumIds: normalizeFourD4yQuickForumIds(settings.quickForumIds),
    showPinnedThreads: normalizeFourD4yShowPinnedThreads(settings.showPinnedThreads),
    postTimeSortForumIds: normalizeFourD4yPostTimeSortForumIds(settings.postTimeSortForumIds),
    addPostTail: settings.addPostTail === true,
    postTailText: normalizeFourD4yPostTailText(settings.postTailText),
    postTailUrl: normalizeFourD4yPostTailUrl(settings.postTailUrl)
  };
}

/** Merge only this user's changed fields, not a stale page's whole snapshot. */
export function mergeFourD4yUserSettingsChanges(current: FourD4yUserSettings,
  before: FourD4yUserSettings, next: FourD4yUserSettings): FourD4yUserSettings {
  return normalizeFourD4yUserSettings({
    themeMode: next.themeMode !== before.themeMode ? next.themeMode : current.themeMode,
    fontScale: next.fontScale !== before.fontScale ? next.fontScale : current.fontScale,
    postLineSpacing: next.postLineSpacing !== before.postLineSpacing ? next.postLineSpacing : current.postLineSpacing,
    imageLoadPolicy: next.imageLoadPolicy !== before.imageLoadPolicy ? next.imageLoadPolicy : current.imageLoadPolicy,
    quickForumIds: JSON.stringify(next.quickForumIds) !== JSON.stringify(before.quickForumIds) ?
      next.quickForumIds : current.quickForumIds,
    showPinnedThreads: next.showPinnedThreads !== before.showPinnedThreads ?
      next.showPinnedThreads : current.showPinnedThreads,
    postTimeSortForumIds: JSON.stringify(next.postTimeSortForumIds) !== JSON.stringify(before.postTimeSortForumIds) ?
      next.postTimeSortForumIds : current.postTimeSortForumIds,
    addPostTail: next.addPostTail !== before.addPostTail ? next.addPostTail : current.addPostTail,
    postTailText: next.postTailText !== before.postTailText ? next.postTailText : current.postTailText,
    postTailUrl: next.postTailUrl !== before.postTailUrl ? next.postTailUrl : current.postTailUrl
  });
}

export function normalizeFourD4yQuickForumIds(value: Object): string[] {
  if (!Array.isArray(value)) {
    return [...FOUR_D4Y_QUICK_FORUM_IDS];
  }
  const result: string[] = [];
  value.forEach((entry: Object) => {
    if (typeof entry === 'string' && knownForumIds.indexOf(entry) >= 0 && result.indexOf(entry) < 0 &&
      result.length < FOUR_D4Y_MAX_QUICK_FORUMS) {
      result.push(entry);
    }
  });
  return result.length > 0 ? result : [...FOUR_D4Y_QUICK_FORUM_IDS];
}

export function moveFourD4yQuickForumId(quickForumIds: string[], forumId: string,
  direction: -1 | 1): string[] {
  const result: string[] = normalizeFourD4yQuickForumIds(quickForumIds);
  const index: number = result.indexOf(forumId);
  const targetIndex: number = index + direction;
  if (index < 0 || targetIndex < 0 || targetIndex >= result.length) {
    return result;
  }
  const current: string = result[index];
  result[index] = result[targetIndex];
  result[targetIndex] = current;
  return result;
}

function normalizeFourD4yThemeMode(value: Object): FourD4yThemeMode {
  if (value === FourD4yThemeMode.Light) {
    return FourD4yThemeMode.Light;
  }
  if (value === FourD4yThemeMode.Dark) {
    return FourD4yThemeMode.Dark;
  }
  return FourD4yThemeMode.FollowSystem;
}

function normalizeFourD4yFontScale(value: Object): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return 1;
  }
  let nearestScale: number = FOUR_D4Y_FONT_SCALES[0];
  let nearestDistance: number = Math.abs(value - nearestScale);
  FOUR_D4Y_FONT_SCALES.forEach((scale: number) => {
    const distance: number = Math.abs(value - scale);
    if (distance < nearestDistance) {
      nearestScale = scale;
      nearestDistance = distance;
    }
  });
  return nearestScale;
}

function normalizeFourD4yPostLineSpacing(value: Object): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return 1;
  }
  let nearestSpacing: number = FOUR_D4Y_POST_LINE_SPACINGS[0];
  let nearestDistance: number = Math.abs(value - nearestSpacing);
  FOUR_D4Y_POST_LINE_SPACINGS.forEach((spacing: number) => {
    const distance: number = Math.abs(value - spacing);
    if (distance < nearestDistance) {
      nearestSpacing = spacing;
      nearestDistance = distance;
    }
  });
  return nearestSpacing;
}

function normalizeFourD4yImageLoadPolicy(value: Object): FourD4yImageLoadPolicy {
  return value === FourD4yImageLoadPolicy.TapToLoad ? FourD4yImageLoadPolicy.TapToLoad :
    FourD4yImageLoadPolicy.Automatic;
}

function normalizeFourD4yShowPinnedThreads(value: Object): boolean {
  return typeof value === 'boolean' ? value : true;
}

function normalizeFourD4yPostTimeSortForumIds(value: Object): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  value.forEach((entry: Object) => {
    if (typeof entry === 'string' && knownForumIds.indexOf(entry) >= 0 && result.indexOf(entry) < 0) {
      result.push(entry);
    }
  });
  return result;
}
