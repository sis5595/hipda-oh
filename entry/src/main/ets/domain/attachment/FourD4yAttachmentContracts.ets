/**
 * Only the forum's own attachment endpoint may use the authenticated ArkWeb
 * download path. Ordinary links keep their existing external-browser route.
 */
export function isAllowedFourD4yAttachmentDownloadUrl(value: string): boolean {
  const normalized: string = value.trim().toLowerCase();
  const isAttachmentEndpoint: boolean =
    normalized.startsWith('https://www.4d4y.com/forum/attachment.php?') ||
      normalized.startsWith('https://4d4y.com/forum/attachment.php?');
  // 4D4Y currently emits an opaque aid token on authenticated pages, while
  // printable/public pages may expose a decimal id. Treat the value as a
  // server token just like NG does, but require it to be present and bounded
  // by normal query separators.
  return isAttachmentEndpoint && /[?&]aid=[^&#\s]+(?:[&#]|$)/.test(normalized);
}

/**
 * Produces a safe default for the system save picker. 4D4Y commonly appends a
 * human-readable size to an attachment label; that size belongs in the reader
 * UI, not in the saved file name.
 */
export function createFourD4yAttachmentFileName(label: string): string {
  let fileName: string = label.trim().replace(
    /\s*\(\s*\d+(?:\.\d+)?\s*(?:bytes?|[kmgt]?i?b)\s*\)\s*$/i, '');
  fileName = fileName.replace(/[\\/:*?"<>|\u0000-\u001F\u007F]/g, '_');
  fileName = fileName.replace(/^[.\s]+|[.\s]+$/g, '');
  if (fileName.length === 0) {
    return '4d4y-attachment';
  }
  // Keep the picker default comfortably below the platform's 255-byte file
  // name limit, including names made entirely from three-byte CJK characters.
  return fileName.length > 80 ? fileName.substring(0, 80).replace(/[.\s]+$/g, '') : fileName;
}
