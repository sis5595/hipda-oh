import util from '@ohos.util';

/** Form encoding after GBK conversion, not UTF-8 encodeURIComponent(text). */
export function encodeFourD4yFormBytes(bytes: Uint8Array): string {
  let result: string = '';
  bytes.forEach((byte: number) => {
    if ((byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) ||
      (byte >= 0x61 && byte <= 0x7A) || byte === 0x2A || byte === 0x2D || byte === 0x2E || byte === 0x5F) {
      result += String.fromCharCode(byte);
    } else {
      result += byte === 0x20 ? '+' : '%' + byte.toString(16).toUpperCase().padStart(2, '0');
    }
  });
  return result;
}

/** NG sends GBK and decimal entities for emoji; also preserve unmappable BMP text. */
export function encodeFourD4yPostField(value: string): string {
  if (value.length === 0) {
    return '';
  }
  const encoder: util.TextEncoder = util.TextEncoder.create('gbk');
  const decoder: util.TextDecoder = util.TextDecoder.create('gbk');
  const bytes: Uint8Array = encoder.encodeInto(value);
  if (decoder.decodeToString(bytes) === value) {
    return encodeFourD4yFormBytes(bytes);
  }
  let compatible: string = '';
  for (let index: number = 0; index < value.length; index += 1) {
    const point: number = value.codePointAt(index) ?? 0;
    const character: string = String.fromCodePoint(point);
    const encoded: Uint8Array = encoder.encodeInto(character);
    compatible += decoder.decodeToString(encoded) === character ? character : '&#' + point + ';';
    if (point > 0xFFFF) {
      index += 1;
    }
  }
  return encodeFourD4yFormBytes(encoder.encodeInto(compatible));
}
