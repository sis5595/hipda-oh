const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const source = fs.readFileSync(path.join(root, 'presentation/notice/MessageCenterPage.ets'), 'utf8');
function section(start, end) {
  const from = source.indexOf(start);
  assert.ok(from >= 0);
  const to = source.indexOf(end, from);
  assert.ok(to > from);
  return source.slice(from, to);
}
const failureExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'data/remote/FourD4yNativeRequestFailure.ets'), 'utf8'), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
} }).outputText, { exports: failureExports });
const exportsObject = {};
vm.runInNewContext(ts.transpileModule('class Page {' +
  section('  private async loadPage(', '  private async loadPromptCounts(') +
  section('  private failLoad(', '  private startPostResolveWatchdog(') +
  '} exports.Page = Page;', { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
  } }).outputText, {
  exports: exportsObject,
  describeFourD4yNativeRequestFailure: failureExports.describeFourD4yNativeRequestFailure,
  buildFourD4yMessagePageUrl: (_mode, page) => 'synthetic-page-' + page,
  isExpectedFourD4yMessagePagePayload: (p, mode, page, sequence) =>
    p.mode === mode && p.page === page && p.loadSequence === sequence,
  getFourD4yMessageReaderOutcome: p => p.items.length ? 'content' : 'empty',
  FourD4yMessageReaderOutcome: { Empty: 'empty', LoginRequired: 'loginRequired',
    VerificationRequired: 'verificationRequired', UnsupportedLayout: 'unsupported' }
});
function make(status) {
  const p = new exportsObject.Page();
  const rows = [{ itemId: 'pm:101', isUnread: true }];
  Object.assign(p, { selectedMode: 'private', items: rows, currentPage: 2, lastPage: 4,
    viewerUserId: '101', loadSequence: 0, terminalLoadSequence: 0,
    isLoading: false, isLoggedIn: true, isResolvingPost: false, isPrivateSearchRunning: false,
    noticeRowVersions: { track: items => items },
    startLoadWatchdog() {}, clearLoadWatchdog() {}, getModeLabel: () => '私信',
    nativeClient: { loadPage: async (_url, sequence) => ({ status,
      failure: failureExports.classifyFourD4yNetworkFailure(2300055),
      payload: { mode: 'private', loadSequence: sequence, page: 2, lastPage: 4,
        viewerUserId: '101', items: [] } }) }
  });
  return { p, rows };
}
(async () => {
  for (const requestedPage of [2, 3]) {
    const { p, rows } = make('request-failed');
    await p.loadPage(requestedPage);
    assert.equal(p.items, rows, 'transport failure keeps the previously confirmed page');
    assert.equal(p.currentPage, 2, 'failed next page must not relabel retained rows');
    assert.equal(p.lastPage, 4);
    assert.match(p.statusMessage, /2300055/);
    assert.match(p.statusMessage, /上次读取/);
    assert.equal(p.isLoading, false);
  }
  for (const status of ['cookie-missing', 'server-login-required', 'unsupported-response']) {
    const { p } = make(status); await p.loadPage(2);
    assert.equal(p.items.length, 0, 'auth/contract failure must not keep rows');
    assert.equal(p.viewerUserId, '');
  }
  {
    const { p } = make('request-failed'); p.items = [];
    await p.loadPage(2); assert.doesNotMatch(p.statusMessage, /上次读取/);
  }
  {
    const { p } = make('success'); await p.loadPage(2);
    assert.equal(p.items.length, 0, 'confirmed empty response replaces old rows');
    assert.match(p.statusMessage, /暂无/);
  }
  {
    const { p, rows } = make('request-failed');
    p.loadSequence = 7; p.statusMessage = 'newer';
    p.failLoad(6, 'old');
    assert.equal(p.items, rows); assert.equal(p.statusMessage, 'newer');
  }
  const modeSwitch = section('        this.selectedMode = mode;', '  @Builder\n  private buildContent()');
  assert.match(modeSwitch, /this\.items = \[\]/);
  assert.match(modeSwitch, /this\.currentPage = 1/);
  assert.match(modeSwitch, /this\.viewerUserId = ''/);
  console.log('Message refresh failure preserves same-tab snapshot, with auth/tab/empty boundaries passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
