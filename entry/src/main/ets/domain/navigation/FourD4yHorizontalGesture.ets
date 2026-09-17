/**
 * Shared direction guard for full-width navigation pans.
 *
 * PanDirection.Right performs the recognizer-level filter. This second guard
 * prevents the horizontal drift of a vertical scroll from becoming navigation
 * when the pointer is released.
 */
export function isQualifiedFourD4yRightSwipe(offsetX: number, offsetY: number,
  minimumHorizontalDistance: number = 72): boolean {
  if (offsetX < minimumHorizontalDistance) {
    return false;
  }
  const verticalDistance: number = Math.abs(offsetY);
  return verticalDistance <= Math.max(36, offsetX * 0.65);
}
