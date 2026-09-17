/**
 * Reads Set-Cookie response headers without retaining or logging their values.
 *
 * Native HTTP and ArkWeb have separate cookie stores on HarmonyOS.  Keep the
 * header parsing pure so its RFC edge cases can be covered by local tests;
 * FourD4ySession remains responsible for writing accepted same-origin cookies
 * into ArkWeb.
 */
export function extractFourD4ySetCookieHeaders(responseHeaders: Object): string[] {
  const headerMap: Record<string, string | string[]> =
    responseHeaders as Record<string, string | string[]>;
  const names: string[] = Object.keys(headerMap);
  const result: string[] = [];
  for (let index: number = 0; index < names.length; index += 1) {
    const name: string = names[index];
    if (name.toLowerCase() !== 'set-cookie') {
      continue;
    }
    const value: string | string[] = headerMap[name];
    if (typeof value === 'string') {
      appendSetCookieValue(result, value);
      continue;
    }
    for (let valueIndex: number = 0; valueIndex < value.length; valueIndex += 1) {
      appendSetCookieValue(result, value[valueIndex]);
    }
  }
  return result;
}

function appendSetCookieValue(result: string[], value: string): void {
  const entries: string[] = splitCombinedSetCookieHeader(value);
  for (let index: number = 0; index < entries.length; index += 1) {
    const entry: string = entries[index].trim();
    if (isSafeSetCookieValue(entry)) {
      result.push(entry);
    }
  }
}

/**
 * Some transports collapse multiple Set-Cookie fields into one string.  A
 * comma inside Expires is not a delimiter, so split only when the following
 * token is syntactically another cookie-name followed by '='.
 */
export function splitCombinedSetCookieHeader(value: string): string[] {
  const result: string[] = [];
  let entryStart: number = 0;
  for (let index: number = 0; index < value.length; index += 1) {
    if (value[index] !== ',' || !startsCookiePair(value, index + 1)) {
      continue;
    }
    result.push(value.slice(entryStart, index).trim());
    entryStart = index + 1;
  }
  result.push(value.slice(entryStart).trim());
  return result.filter((entry: string): boolean => entry.length > 0);
}

function startsCookiePair(value: string, start: number): boolean {
  let index: number = start;
  while (index < value.length && (value[index] === ' ' || value[index] === '\t')) {
    index += 1;
  }
  const nameStart: number = index;
  while (index < value.length && isCookieTokenCharacter(value[index])) {
    index += 1;
  }
  return index > nameStart && index < value.length && value[index] === '=';
}

function isCookieTokenCharacter(value: string): boolean {
  return /^[!#$%&'*+\-.^_`|~0-9A-Za-z]$/.test(value);
}

function isSafeSetCookieValue(value: string): boolean {
  return value.length > 0 && value.length <= 8192 && value.indexOf('\r') < 0 && value.indexOf('\n') < 0 &&
    /^[!#$%&'*+\-.^_`|~0-9A-Za-z]+=/.test(value);
}
