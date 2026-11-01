/** Non-sensitive display preference, independent of device or account identity. */
export const FOUR_D4Y_DEFAULT_SPLIT_PANE_RATIO: number = 0.4;
export const FOUR_D4Y_MIN_LIST_WIDTH: number = 240;
export const FOUR_D4Y_MIN_DETAIL_WIDTH: number = 360;

export function normalizeFourD4ySplitPaneRatio(value: Object): number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 && value < 1 ?
    value : FOUR_D4Y_DEFAULT_SPLIT_PANE_RATIO;
}

/** Clamp for this window only. Never save this automatic clamp as a new preference. */
export function getFourD4ySplitPaneWidth(viewportWidth: number, preferredRatio: number): number {
  if (!Number.isFinite(viewportWidth) || viewportWidth <= 0) {
    return FOUR_D4Y_MIN_LIST_WIDTH;
  }
  if (viewportWidth < FOUR_D4Y_MIN_LIST_WIDTH + FOUR_D4Y_MIN_DETAIL_WIDTH) {
    return viewportWidth;
  }
  return Math.min(viewportWidth - FOUR_D4Y_MIN_DETAIL_WIDTH,
    Math.max(FOUR_D4Y_MIN_LIST_WIDTH, viewportWidth * normalizeFourD4ySplitPaneRatio(preferredRatio)));
}
