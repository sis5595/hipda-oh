/** Window-local layout only. Never branch the navigation tree on a device type. */
export function isFourD4yWideLayout(width: number): boolean {
  // At 40/60 this leaves at least 240vp for the list and 360vp for reading.
  // A tablet's narrow portrait/split window must still be usable as one pane.
  return Number.isFinite(width) && width >= 600;
}

export function isFourD4yFullWidthRoute(name: string): boolean {
  return name === 'ForumComposer' || name === 'ImageViewer' || name === 'Login' || name === 'Account';
}

export function getFourD4ySheetWidth(viewportWidth: number): number {
  if (!Number.isFinite(viewportWidth) || viewportWidth <= 0) {
    return 360;
  }
  // Keep NG's compact bottom-dialog feel, not a popup anchored below a button.
  return viewportWidth < 600 ? viewportWidth : Math.min(560, viewportWidth * 0.7);
}

export function getFourD4ySheetHeight(preferredHeight: number, viewportHeight: number): number {
  if (!Number.isFinite(viewportHeight) || viewportHeight <= 0) {
    return preferredHeight;
  }
  // Leave space above the sheet, including in a short landscape/split window.
  return Math.min(preferredHeight, Math.max(1, viewportHeight - 48));
}
