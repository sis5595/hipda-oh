const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
function extract(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
const exported = {};
vm.runInNewContext(ts.transpileModule('class Reader {' +
  extract('  private loadNextThreadPage()', '  /** Reload the visible server page') +
  extract('  private refreshCurrentThreadPage()', '  private openReplyComposer(') +
  '} exports.Reader = Reader;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, { exports: exported,
  buildFourD4yThreadReaderUrl: (_tid, page) => 'page=' + page });
for (const [firstPage, endPage] of [[1, 2], [3, 5], [2, 2]]) {
  const reader = new exported.Reader();
  const posts = [{ id: '101', floor: 17 }]; // Filtering means floor cannot identify the server page.
  Object.assign(reader, { currentPage: endPage, firstRenderedPage: firstPage, lastPage: 8,
    posts, isLoading: false, isLoadingMore: false, isRefreshing: true,
    postListScroller: { offset: () => ({ yOffset: 0 }) },
    cancelPostLayoutAnchor: () => {}, startThreadLoadWatchdog: () => {},
    webLoadSequence: 2, route: { threadId: '123' }, authorOnlyUserId: '456',
    isThreadWebControllerAttached: false, postRowVersions: { track: items => items } });
  reader.refreshCurrentThreadPage();
  assert.equal(reader.requestedPage, firstPage, 'pull refresh must reload the beginning of the rendered range');
  assert.equal(reader.posts, posts, 'keep visible rows mounted while refreshing');
  assert.equal(reader.isRefreshing, true);
  assert.equal(reader.isLoading, false);
}
assert.match(source, /if \(!isAppendingRequest\)\s*\{\s*this\.firstRenderedPage = this\.currentPage;/,
  'only a confirmed replacement response changes the rendered range beginning');
{
  const reader = new exported.Reader();
  let requests = 0;
  Object.assign(reader, { isLoading: false, isLoadingMore: false, isRefreshing: true,
    isAppendingThreadPage: false, currentPage: 1, lastPage: 3,
    loadPage: () => requests++ });
  reader.loadNextThreadPage();
  assert.equal(requests, 0, 'reach-end must not supersede an active pull refresh');
  reader.isRefreshing = false;
  reader.loadNextThreadPage();
  assert.equal(requests, 1);
}
console.log('Thread refresh page-range regression passed.');
