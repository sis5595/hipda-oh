export interface FourD4yImageDecodeSize {
  width: number;
  height: number;
  scaledPreview: boolean;
}

// App policy, not a promise about a codec's peak working memory. At RGBA8888
// the output is at most 128 MiB. Ordinary originals retain their exact pixels.
export const FOUR_D4Y_MAX_PREVIEW_PIXELS: number = 32 * 1024 * 1024;

export function planFourD4yImageDecode(width: number, height: number): FourD4yImageDecodeSize | undefined {
  if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height) || width < 1 || height < 1 ||
    !Number.isSafeInteger(width * height)) return undefined;
  if (width * height <= FOUR_D4Y_MAX_PREVIEW_PIXELS) {
    return { width: width, height: height, scaledPreview: false };
  }
  const ratio: number = Math.sqrt(FOUR_D4Y_MAX_PREVIEW_PIXELS / (width * height));
  const targetWidth: number = Math.max(1, Math.min(FOUR_D4Y_MAX_PREVIEW_PIXELS, Math.floor(width * ratio)));
  // Capping the second axis also handles extreme 1-pixel-wide header sizes.
  const targetHeight: number = Math.max(1, Math.min(Math.floor(height * ratio),
    Math.floor(FOUR_D4Y_MAX_PREVIEW_PIXELS / targetWidth)));
  return { width: targetWidth, height: targetHeight, scaledPreview: true };
}
