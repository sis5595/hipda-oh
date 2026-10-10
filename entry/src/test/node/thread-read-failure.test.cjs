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
  extract('  private async readThreadFromWeb()', '  /**\n   * Read the exact full-site action') +
  extract('  private finishThreadLoad(', '  private restoreThreadRefreshPosition(') +
  extract('  private failThreadLoad(', '  /** Persist only confirmed reader position') +
  '} exports.Reader = Reader;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, { exports: exported,
  parseThreadWebPayload: () => null, console: { error: () => {} } });
(async () => {
  for (const mode of ['initial', 'append', 'refresh']) {
    for (const failure of ['null', 'throw']) {
      for (const stale of [false, true]) {
        const reader = new exported.Reader();
        const posts = mode === 'initial' ? [] : [{ id: '101' }];
        const toasts = [];
        let finishCount = 0;
        Object.assign(reader, { webLoadSequence: 1, terminalLoadSequence: 0,
          route: { threadId: '123' }, requestedPage: 2, posts,
          isAppendingThreadPage: mode === 'append', isRefreshing: mode === 'refresh',
          isLoading: mode === 'initial', isLoadingMore: mode === 'append',
          loadError: '', loadMoreError: '',
          isThreadLoadTerminal: sequence => reader.terminalLoadSequence === sequence,
          getThreadExtractionScript: () => '',
          clearThreadLoadWatchdog: () => finishCount++,
          restoreThreadRefreshPosition: () => {}, showLinkToast: text => toasts.push(text),
          threadWebController: { runJavaScript: async () => {
            if (stale) reader.webLoadSequence++;
            if (failure === 'throw') throw new Error('synthetic bridge failure');
            return 'null';
          } } });
        await reader.readThreadFromWeb();
        assert.equal(reader.posts, posts);
        assert.equal(finishCount, stale ? 0 : 1);
        assert.equal(reader.loadError.length > 0, !stale && mode === 'initial');
        assert.equal(reader.loadMoreError.length > 0, !stale && mode === 'append');
        assert.equal(toasts.length, !stale && mode === 'refresh' ? 1 : 0);
        if (!stale) {
          assert.equal(reader.isLoadingMore, false);
          assert.equal(reader.isRefreshing, false);
          assert.equal(reader.terminalLoadSequence, 1);
        }
      }
    }
  }
  console.log('Thread read failure routing regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
