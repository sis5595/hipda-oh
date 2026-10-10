import { ForumThreadType } from './FourD4yReaderContracts';

/** The selected category may be plain text instead of a link in 4D4Y. */
export function retainSelectedFourD4yForumType(incoming: ForumThreadType[], previous: ForumThreadType[],
  selectedId: string): ForumThreadType[] {
  const result: ForumThreadType[] = incoming.slice();
  if (!/^[1-9]\d*$/.test(selectedId) || result.some((item: ForumThreadType) => item.value === selectedId)) {
    return result;
  }
  const index: number = previous.findIndex((item: ForumThreadType) => item.value === selectedId);
  if (index >= 0) result.splice(Math.min(index, result.length), 0, previous[index]);
  return result;
}

/** Only Buy & Sell exposes NG's board-level category filter. */
export function buildFourD4yForumFilterQuery(forumId: string, typeId: string): string {
  return forumId === '6' && /^[1-9]\d*$/.test(typeId) ? '&filter=type&typeid=' + typeId : '';
}

/** Shared by the live extractor and synthetic DOM tests; never exports HTML. */
export function buildFourD4yForumNavigationScript(): string {
  return `
    const forumUrl = new URL(location.href);
    const isBoardUrl = (value) => value.origin === 'https://www.4d4y.com' &&
      value.pathname === '/forum/forumdisplay.php' && value.searchParams.getAll('fid').length === 1 &&
      value.searchParams.get('fid') === currentFid;
    const boardType = (value) => {
      const query = value.searchParams;
      if (query.getAll('typeid').length > 1 || query.getAll('filter').length > 1) return null;
      const type = query.get('typeid') || '';
      if (type && type !== '0') return /^[1-9]\\d*$/.test(type) &&
        query.get('filter') === 'type' ? type : null;
      return query.get('filter') && query.get('filter') !== 'type' ? null : '';
    };
    if (!isBoardUrl(forumUrl) || forumUrl.searchParams.getAll('oh_load').length !== 1 ||
      forumUrl.searchParams.getAll('page').length > 1 || boardType(forumUrl) === null) {
      throw new Error('Mismatched board document');
    }
    const filterTypeId = boardType(forumUrl);
    const seenThreadTypeIds = new Set();
    const threadTypes = [];
    Array.from(document.querySelectorAll('div.threadtype a[href]')).forEach((link) => {
      try {
        const typeUrl = new URL(link.getAttribute('href') || '', location.href);
        const typeId = boardType(typeUrl);
        const label = toText(link);
        if (!isBoardUrl(typeUrl) || !typeId || !label || seenThreadTypeIds.has(typeId)) return;
        seenThreadTypeIds.add(typeId);
        threadTypes.push({ value: typeId, label: label.slice(0, 80) });
      } catch (_) { }
    });
    const linkedBoardPage = (link) => {
      try {
        const target = new URL(link.getAttribute('href') || '', location.href);
        if (!isBoardUrl(target) || boardType(target) !== filterTypeId ||
          target.searchParams.getAll('page').length > 1 ||
          target.searchParams.getAll('orderby').length > 1 ||
          (target.searchParams.get('orderby') || '') !== (forumUrl.searchParams.get('orderby') || '')) return 0;
        const pageText = target.searchParams.get('page') || '1';
        return /^[1-9]\\d*$/.test(pageText) ? Number(pageText) : 0;
      } catch (_) { return 0; }
    };
  `;
}
/** 4D4Y's observed empty legacy list is a header-only board table, not an alert. */
export function buildFourD4yEmptyForumScript(): string {
  return `
    const emptyTable = document.getElementById('forum_' + currentFid);
    const emptyHead = emptyTable ? emptyTable.querySelector('thead.colplural') : null;
    const emptyHeadText = emptyHead ? toText(emptyHead) : '';
    const hasEmptyForumTable = !!(emptyTable && emptyTable.tagName === 'TABLE' &&
      emptyTable.classList.contains('datatable') && emptyTable.parentElement &&
      emptyTable.parentElement.id === 'moderate' && emptyTable.children.length === 1 &&
      emptyTable.children[0] === emptyHead && emptyTable.rows.length === 1 &&
      /作者\\s*\\/\\s*时间/.test(emptyHeadText) && /回复/.test(emptyHeadText) &&
      /查看/.test(emptyHeadText) && /最后发表/.test(emptyHeadText));
  `;
}

