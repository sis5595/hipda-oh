const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
function compile(code) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports,
    isExpectedFourD4yMessagePromptPayload: (p, sequence) => p.loadSequence === sequence });
  return exports;
}
const State = compile(fs.readFileSync(path.join(root, 'domain/notice/FourD4yUnreadState.ets'), 'utf8'))
  .FourD4yUnreadState;
function page(kind, state) {
  const isHome = kind === 'home';
  const source = fs.readFileSync(path.join(root, isHome ? 'presentation/home/HomePage.ets' :
    'presentation/notice/MessageCenterPage.ets'), 'utf8');
  const method = isHome ? 'refreshUnreadPromptCounts' : 'loadPromptCounts';
  const start = source.indexOf('  private async ' + method + '(');
  const end = isHome ? source.lastIndexOf('\n}') : source.indexOf('  private openItem(', start);
  const Page = compile('class Page {' + source.slice(start, end) + '} exports.Page = Page;').Page;
  let finish;
  const client = { loadPrompt: sequence => new Promise(resolve => {
    finish = (count, status = 'success') => resolve({ status, payload: { loadSequence: sequence,
      accessState: 'available', privateMessageCount: count, threadNoticeCount: 0,
      systemNoticeCount: 0, friendNoticeCount: 0 } });
  }) };
  const p = new Page();
  Object.assign(p, { isHomeAlive: true, isLoggedIn: true, isUnreadPromptLoading: false,
    unreadPromptSequence: 0, promptSequence: 0, unreadState: state,
    accountState: { getSessionGeneration: () => 1 }, messageClient: client, nativeClient: client });
  return { p, run: () => p[method](), finish: (...args) => finish(...args) };
}
(async () => {
  for (const order of [['home', 'center'], ['center', 'home']]) {
    for (const oldStatus of ['success', 'server-login-required']) {
      const state = new State(); state.observeServerCounts(1, 0, 0, 0);
      const older = page(order[0], state), newer = page(order[1], state);
      const oldTask = older.run(), newTask = newer.run();
      newer.finish(0); await newTask;
      older.finish(1, oldStatus); await oldTask;
      assert.equal(state.getPrivateMessageCount(), 0, 'late cross-page response must not resurrect unread');
      assert.equal(state.hasSnapshot(), true, 'late login rejection must not erase a newer verified snapshot');
      assert.equal(older.p.isLoggedIn, true, 'stale auth rejection must not change login UI');
    }
  }
  for (const kind of ['home', 'center']) {
    const state = new State(), active = page(kind, state);
    const task = active.run(); state.clear(); active.finish(9); await task;
    assert.equal(state.hasSnapshot(), false, 'clear must invalidate pending reads even if already empty');
  }
  // Account B may have either more or fewer unread messages than A. A late
  // success or login rejection from A must affect neither B's data nor UI.
  for (const kind of ['home', 'center']) {
    for (const nextCount of [0, 5]) {
      for (const staleStatus of ['success', 'server-login-required', 'cookie-missing']) {
        const state = new State(); state.observeServerCounts(2, 3, 0, 0);
        const oldPage = page(kind, state), stale = oldPage.run();
        let observedReset = false;
        const subscription = state.subscribe(() => {
          if (!state.hasSnapshot() && state.getPrivateMessageCount() === 0 &&
            state.getInformationReminderCount() === 0) observedReset = true;
        });
        state.clear();
        assert.equal(observedReset, true, 'account transition clears both badge types immediately');
        const newPage = page(kind, state), fresh = newPage.run();
        newPage.finish(nextCount); await fresh;
        oldPage.finish(99, staleStatus); await stale;
        assert.equal(state.getPrivateMessageCount(), nextCount);
        assert.equal(state.hasSnapshot(), true);
        assert.equal(newPage.p.isLoggedIn, true);
        state.unsubscribe(subscription);
      }
    }
  }
  // Home additionally binds its native read to account generation even if a
  // caller hasn't yet propagated the shared-state clear notification.
  for (const staleStatus of ['success', 'server-login-required', 'cookie-missing']) {
    const state = new State(); state.observeServerCounts(4, 0, 0, 0);
    const active = page('home', state);
    let generation = 1;
    active.p.accountState.getSessionGeneration = () => generation;
    const pending = active.run(); generation = 2;
    active.finish(99, staleStatus); await pending;
    assert.equal(state.getPrivateMessageCount(), 4);
    assert.equal(active.p.isLoggedIn, true);
    assert.equal(active.p.isUnreadPromptLoading, false, 'discarded read must release loading guard');
  }
  {
    const state = new State(); state.observeServerCounts(2, 3, 0, 0);
    const older = page('home', state), newer = page('center', state);
    const a = older.run(), b = newer.run();
    newer.finish(0, 'request-failed'); await b; older.finish(9); await a;
    assert.equal(state.getPrivateMessageCount(), 2, 'failed latest read preserves last confirmed snapshot');
    const retry = newer.run(); newer.finish(0); await retry;
    assert.equal(state.getPrivateMessageCount(), 0, 'a subsequent valid read can still clear counts');
  }
  console.log('Shared unread cross-page response ordering and session invalidation passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
