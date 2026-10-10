const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/blacklist/BlacklistPage.ets'), 'utf8');
const lifecycle = source.slice(source.indexOf('  aboutToDisappear()'), source.indexOf('  build()'));
const methods = source.slice(source.indexOf('  private async beginLoad()'),
  source.indexOf('  private getBlacklistExtractionScript('));
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function fixture() {
  let generation = 1, reads = 0, mutations = 0, observations = 0;
  const login = deferred(), dialog = deferred(), js = deferred(), output = {};
  vm.runInNewContext(ts.transpileModule('class Page {' + lifecycle + methods +
    '} exports.Page = Page;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, {
    exports: output, FourD4ySession: { isLoggedIn: () => login.promise },
    normalizeFourD4yBlacklistUserName: value => value.trim(),
    isValidFourD4yBlacklistUserName: value => value.length > 0,
    FourD4yBlacklistMutationKind: { Add: 'add', Remove: 'remove' },
    parseFourD4yBlacklistPagePayload: value => value,
    isExpectedFourD4yBlacklistPagePayload: () => true,
    getFourD4yBlacklistReaderOutcome: () => 'content',
    FourD4yBlacklistReaderOutcome: { Content: 'content' },
    $r: value => value, clearTimeout: () => {}, setTimeout: () => 1
  });
  const page = new output.Page();
  Object.assign(page, {
    isPageAlive: true, beginLoadSequence: 0, loadSequence: 1, operationSequence: 0,
    terminalLoadSequence: 0, requestSessionGeneration: 1,
    isLoading: false, isMutating: false, isLoggedIn: true, hasMutationToken: true,
    hasRemovalControl: true, draftUserName: 'sample', entries: [], statusMessage: '',
    accountState: { getSessionGeneration: () => generation },
    blacklistState: { clearServerSnapshot: () => { observations++; },
      observeServerUserNames: () => { observations++; } },
    loadBlacklist: () => { reads++; }, startMutation: () => { mutations++; },
    webController: { runJavaScript: () => js.promise },
    getBlacklistExtractionScript: () => '',
    getUIContext: () => ({ getPromptAction: () => ({ showDialog: () => dialog.promise }) })
  });
  return { page, login, dialog, js, reads: () => reads, mutations: () => mutations,
    observations: () => observations, switchAccount: () => { generation++; } };
}
(async () => {
  for (const exit of ['leave', 'switch']) {
    const test = fixture();
    const pending = test.page.beginLoad();
    if (exit === 'leave') test.page.aboutToDisappear(); else test.switchAccount();
    test.login.resolve(false);
    await pending;
    assert.equal(test.page.isLoggedIn, true, exit + ': old login check cannot clear shared auth');
    assert.equal(test.observations(), 0);
    assert.equal(test.reads(), 0);
  }
  for (const kind of ['add', 'remove']) {
    for (const exit of ['none', 'leave', 'switch', 'refresh', 'other-operation']) {
      const test = fixture();
      if (kind === 'remove') test.page.entries = [{ userName: 'sample' }];
      if (kind === 'add') test.page.requestAdd(); else test.page.requestRemoval('sample');
      if (exit === 'leave') test.page.aboutToDisappear();
      if (exit === 'switch') test.switchAccount();
      if (exit === 'refresh') test.page.loadSequence++;
      if (exit === 'other-operation') test.page.operationSequence++;
      test.dialog.resolve({ index: 1 });
      await Promise.resolve();
      assert.equal(test.mutations(), exit === 'none' ? 1 : 0, kind + ': stale confirmation ' + exit);
    }
  }
  for (const exit of ['leave', 'switch']) {
    const test = fixture();
    const pending = test.page.readBlacklistFromWeb();
    if (exit === 'leave') test.page.aboutToDisappear(); else test.switchAccount();
    test.js.resolve({ entries: [{ userName: 'sample' }], hasMutationToken: true, hasRemovalControl: true });
    await pending;
    assert.equal(test.observations(), 0, exit + ': old account list cannot overwrite new account');
    assert.equal(test.page.entries.length, 0);
  }
  const test = fixture();
  test.page.aboutToDisappear();
  assert.equal(test.page.canStartMutation('sample'), false);
  console.log('Blacklist login, confirmation and server snapshot lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
