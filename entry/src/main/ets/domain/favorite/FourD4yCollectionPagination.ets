/** Shared DOM pagination boundary for the forum's two topic collections. */
export function buildFourD4yCollectionPaginationScript(item: 'favorites' | 'attention', page: number): string {
  const initialPage: number = Number.isSafeInteger(page) && page > 0 ? page : 1;
  return [
    '  let lastPage = ' + initialPage + ';',
    '  Array.from(document.querySelectorAll("div.pages a, .pg a")).forEach((node) => {',
    '    try {',
    '      const href = node.getAttribute("href") || ""; if (!href) return;',
    '      const target = new URL(href, location.href);',
    '      if (target.origin !== "https://www.4d4y.com" || target.username || target.password || target.pathname !== "/forum/my.php") return;',
    '      if (target.searchParams.getAll("item").length !== 1 || target.searchParams.get("item") !== ' + JSON.stringify(item) + ') return;',
    '      if (target.searchParams.getAll("type").length > 1 || (target.searchParams.get("type") || "thread") !== "thread") return;',
    '      const pages = target.searchParams.getAll("page"); if (pages.length !== 1 || !/^\\d+$/.test(pages[0])) return;',
    '      const value = Number(pages[0]); if (Number.isSafeInteger(value) && value > lastPage) lastPage = value;',
    '    } catch (_) {}',
    '  });'
  ].join('\n');
}

/** Shared exact collection boundary for readback documents and their forms. */
export function buildFourD4yCollectionVerificationBoundaryScript(item: 'favorites' | 'attention'): string {
  return [
    '  const isCollectionUrl = (url) => url.origin === "https://www.4d4y.com" && !url.username && !url.password &&',
    '    url.pathname === "/forum/my.php" && url.searchParams.getAll("item").length === 1 &&',
    '    url.searchParams.get("item") === ' + JSON.stringify(item) + ' &&',
    '    url.searchParams.getAll("type").length <= 1 && (url.searchParams.get("type") || "thread") === "thread";',
    '  const isCollectionPage = (url, page) => {',
    '    const values = url.searchParams.getAll("page");',
    '    return isCollectionUrl(url) && (values.length === 0 ? page === 1 :',
    '      values.length === 1 && /^\\d+$/.test(values[0]) && Number(values[0]) === page);',
    '  };'
  ].join('\n');
}

export type FourD4yCollectionVerificationStep = 'confirmed' | 'nextPage' | 'retry' | 'limit';

/** Bound read-only verification; the limit is a client budget, not a forum limit. */
export function getFourD4yCollectionVerificationStep(page: number, lastPage: number,
  present: boolean, expectedPresent: boolean): FourD4yCollectionVerificationStep {
  if (present) {
    return expectedPresent ? 'confirmed' : 'retry';
  }
  if (page < lastPage) {
    return page < 10 ? 'nextPage' : 'limit';
  }
  return expectedPresent ? 'retry' : 'confirmed';
}
