const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const cacheExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/favorite/FourD4yCollectionCache.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: cacheExports });
const paginationExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/favorite/FourD4yCollectionPagination.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: paginationExports });
const { buildFourD4yCollectionPaginationScript } = paginationExports;
for (const item of ['favorites', 'attention']) {
  const page = href => ({ textContent: '下一页', getAttribute: () => href });
  const parse = (nodes, current = 1) => vm.runInNewContext('(() => {' +
    buildFourD4yCollectionPaginationScript(item, current) + '; return lastPage; })()', {
    URL, location: { href: 'https://www.4d4y.com/forum/my.php?item=' + item },
    document: { querySelectorAll: () => nodes }
  });
  assert.equal(parse([page(`my.php?item=${item}&type=thread&page=23`)]), 23);
  assert.equal(parse([], 7), 7, 'last page without a forward link retains the requested page');
  for (const href of [
    `my.php?item=${item}&page=-1`, `my.php?item=${item}&page=1.5`,
    `my.php?item=${item}&page=99999999999999999`,
    `my.php?item=${item}&page=2&page=888`, `my.php?item=${item}&item=other&page=888`,
    `my.php?item=${item}&type=forum&page=888`,
    `https://user@www.4d4y.com/forum/my.php?item=${item}&page=888`,
    `http://www.4d4y.com/forum/my.php?item=${item}&page=888`
  ]) assert.equal(parse([page(href)]), 1, 'ignore malformed/out-of-scope pagination');
}
// Execute the production mirrors: only a complete, verified single-page
// snapshot proves absence. A partial page must never erase other pages.
for (const kind of ['Favorite', 'Attention']) {
  const exports = {};
  const source = fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/domain/' + kind.toLowerCase() + '/FourD4y' + kind + 'State.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: () => cacheExports });
  const state = new exports['FourD4y' + kind + 'State']();
  const observe = kind === 'Favorite' ? 'observeServerFavorites' : 'observeServerAttentions';
  const contains = kind === 'Favorite' ? 'isFavorite' : 'isAttentioned';
  state[observe](['101', '202']);
  state[observe](['303'], 1, 2);
  assert.equal(state[contains]('101'), true, kind + ': partial first page preserves other pages');
  state[observe](['404'], 2, 2);
  assert.equal(state[contains]('303'), true, kind + ': last page alone is not a complete snapshot');
  let notified = 0;
  state.subscribeToThreadMutation('303', () => { notified++; });
  state[observe](['303'], 1, 1);
  assert.equal(state[contains]('101'), false, kind + ': complete snapshot removes stale positive');
  assert.equal(state[contains]('303'), true);
  assert.equal(notified, 0, 'passive reads are not user mutations');
  state.notifyConfirmedThreadMutation('303', true);
  assert.equal(notified, 1, 'snapshot replacement preserves active listeners');
  state[observe]([], 1, 1);
  assert.equal(state[contains]('303'), false, kind + ': confirmed empty list clears stale IDs');
}
let pendingJs, timer;
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function load(kind) {
  const isFavorite = kind === 'Favorite';
  const file = isFavorite ? 'favorite/FavoritesPage' : 'attention/AttentionPage';
  const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/' + file + '.ets'), 'utf8');
  const life = source.slice(source.indexOf('  aboutToDisappear()'), source.indexOf('  build()'));
  const methods = source.slice(source.indexOf('  private async beginLoad()'),
    source.indexOf('  private get' + kind + 'PageExtractionScript('));
  const output = {};
  const outcome = { LoginRequired: 'login', VerificationRequired: 'challenge', UnsupportedLayout: 'unsupported' };
  vm.runInNewContext(ts.transpileModule('class ListPage {' + life + methods +
    '} exports.ListPage = ListPage;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
      module: ts.ModuleKind.CommonJS } }).outputText, {
    exports: output, console, bindFourD4yCollectionCache: async () => {}, FourD4ySession: { forumRoot: 'https://www.4d4y.com/forum/',
      isLoggedIn: async () => true },
    ['parseFourD4y' + kind + 'PagePayload']: value => value,
    ['isExpectedFourD4y' + kind + 'PagePayload']: () => true,
    ['getFourD4y' + kind + 'ReaderOutcome']: () => 'ready',
    ['FourD4y' + kind + 'ReaderOutcome']: outcome,
    ['parseFourD4y' + kind + 'MutationStartPayload']: value => value,
    ['isExpectedFourD4y' + kind + 'MutationStartPayload']: () => true,
    setTimeout: callback => { timer = callback; return 1; }, clearTimeout: () => {}
  });
  let generation = 1, observed = 0, unsubscribed = 0;
  const page = new output.ListPage();
  Object.assign(page, {
    getUIContext: () => ({ getHostContext: () => ({}) }),
    isPageAlive: true, loadSequence: 1, removeOperationSequence: 1, terminalLoadSequence: 0,
    requestSessionGeneration: 1, requestedPage: 2, currentPage: 2, lastPage: 3,
    isLoading: false, isWebControllerAttached: true,
    accountState: { getSessionGeneration: () => generation },
    webController: { runJavaScript: () => { pendingJs = deferred(); return pendingJs.promise; }, loadUrl: () => {} },
    ['get' + kind + 'PageExtractionScript']: () => 'synthetic-read',
    ['get' + kind + 'RemovalStartScript']: () => 'synthetic-submit',
    [isFavorite ? 'favorites' : 'attentions']: [{ threadId: '321' }],
    [isFavorite ? 'isRemovingFavorite' : 'isRemovingAttention']: false,
    [isFavorite ? 'favoriteState' : 'attentionState']: {
      cache: { releaseSnapshot: () => {} },
      [isFavorite ? 'observeServerFavorites' : 'observeServerAttentions']: () => { observed++; },
      [isFavorite ? 'unsubscribeFromThreadMutation' : 'unsubscribeFromThreadMutation']: () => { unsubscribed++; }
    },
    [isFavorite ? 'openedFavoriteMutationListenerId' : 'openedAttentionMutationListenerId']: 7,
    [isFavorite ? 'clearFavoriteRemovalWatchdog' : 'clearRemovalWatchdog']: () => {},
    clearLoadWatchdog: () => {}
  });
  return { page, observed: () => observed, unsubscribed: () => unsubscribed,
    switchAccount: () => { generation++; } };
}
(async () => {
  for (const kind of ['Favorite', 'Attention']) {
    const removeMethod = kind === 'Favorite' ? 'removeFavorite' : 'removeAttention';
    const loadMethod = kind === 'Favorite' ? 'loadFavoritePage' : 'loadAttentionPage';
    for (const exit of ['leave', 'switch']) {
      const test = load(kind), page = test.page;
      pendingJs = null;
      if (exit === 'leave') page.aboutToDisappear(); else test.switchAccount();
      const pending = page[removeMethod]('321');
      assert.equal(pendingJs, null, kind + ': stale list cannot start a mutation');
      await pending;
    }
    {
      const test = load(kind), page = test.page;
      let reloads = 0;
      page[loadMethod] = () => { reloads++; };
      const pending = page[removeMethod]('321');
      const refresh = timer;
      test.switchAccount();
      pendingJs.resolve({ started: false, errorMessage: 'stale rejection' });
      await pending;
      refresh();
      assert.equal(page.statusMessage, '', kind + ': stale mutation callback cannot change the new session');
      assert.equal(reloads, 0, kind + ': queued verification cannot adopt a new account');
    }
    for (const exit of ['leave', 'switch']) {
      const test = load(kind), page = test.page;
      const pending = page[kind === 'Favorite' ? 'readFavoritesFromWeb' : 'readAttentionsFromWeb']();
      await Promise.resolve();
      if (exit === 'leave') page.aboutToDisappear(); else test.switchAccount();
      pendingJs.resolve({ threads: [{ threadId: '999' }], page: 2, lastPage: 3 });
      await pending;
      assert.equal(test.observed(), 0, kind + ': stale data must not enter shared account state');
      assert.equal(page[kind === 'Favorite' ? 'favorites' : 'attentions'][0].threadId, '321');
      if (exit === 'leave') assert.equal(test.unsubscribed(), 1);
    }
  }
  const { page } = load('Favorite');
  let verifiedPage = 0;
  page.startFavoriteRemovalWatchdog = () => {};
  page.loadFavoritePage = pageNumber => { verifiedPage = pageNumber; };
  const removal = page.removeFavorite('321');
  pendingJs.resolve({ started: true });
  await removal;
  timer();
  assert.equal(verifiedPage, 2, 'removal must be checked on its source page, not always page one');
  console.log('Server list account/lifecycle isolation and favorite pagination regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });

// Execute the production extractor against the plain-text forum-cell layout
// consumed by NG's parseFavorites; no live page content or credentials.
const attentionSource = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/attention/AttentionPage.ets'), 'utf8');
const extractionMethod = attentionSource.slice(
  attentionSource.indexOf('  private getAttentionPageExtractionScript('),
  attentionSource.indexOf('  private getAttentionRemovalStartScript('));
const extractorExports = {};
vm.runInNewContext(ts.transpileModule('class Extractor {' + extractionMethod +
  '} exports.Extractor = Extractor;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: extractorExports, buildFourD4yCollectionPaginationScript });
for (const forumName of ['Discovery', 'Buy & Sell 交易服务区', 'La Femme']) {
  const link = { textContent: 'Synthetic topic', getAttribute: () => 'viewthread.php?tid=123' };
  const row = { querySelectorAll: () => [link], querySelector: selector =>
    selector === 'td.forum, .forum' ? { textContent: forumName } : null };
  const checkbox = { getAttribute: () => '123', parentElement: row };
  const form = { getAttribute: () => 'my.php?item=attention&type=thread', querySelectorAll: () => [checkbox] };
  const result = JSON.parse(vm.runInNewContext(
    new extractorExports.Extractor().getAttentionPageExtractionScript(1, 4), {
      URL, location: { href: 'https://www.4d4y.com/forum/my.php?item=attention&type=thread' },
      document: { forms: [form], documentElement: { innerHTML: '' }, querySelector: () => null,
        querySelectorAll: selector => selector === 'a[href]' ? [link] : [] }
    }));
  assert.equal(result.threads[0].forumName, forumName, 'forum label need not be a link');
  assert.equal(result.threads[0].forumId, '', 'plain text must not manufacture a board id');
}
for (const name of ['attention/AttentionPage', 'favorite/FavoritesPage']) {
  const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/' + name + '.ets'), 'utf8');
  assert.doesNotMatch(source, /Text\([^\n]*replyCount/, 'match NG: no unverified reply count in these lists');
}
console.log('Server list plain-text forum labels and NG metadata visibility passed.');

// NG's favorite cache is based on delete[] values, not arbitrary topic links.
// Before persisting any mirror, prove that unrelated table rows cannot enter it.
{
  const source = fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/presentation/favorite/FavoritesPage.ets'), 'utf8');
  const output = {};
  const method = source.slice(source.indexOf('  private getFavoritePageExtractionScript('),
    source.indexOf('  private getFavoriteRemovalStartScript('));
  vm.runInNewContext(ts.transpileModule('class Extractor {' + method +
    '} exports.Extractor = Extractor;', { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: output, buildFourD4yCollectionPaginationScript });
  const row = tid => ({ querySelector(selector) {
    return selector.startsWith('a[href*=viewthread]') ? {
      textContent: 'Topic ' + tid, getAttribute: () => 'viewthread.php?tid=' + tid
    } : null;
  } });
  const input = { getAttribute: name => name === 'name' ? 'delete[]' : '123' };
  const form = { getAttribute: () => 'my.php?item=favorites&type=thread', elements: [input],
    querySelectorAll: () => [input] };
  const extract = (rows, pages = []) => JSON.parse(vm.runInNewContext(new output.Extractor().getFavoritePageExtractionScript(1, 1), {
    URL, location: { href: 'https://www.4d4y.com/forum/my.php?item=favorites' },
    document: { forms: [form], documentElement: { innerHTML: '' }, querySelector: () => null,
      querySelectorAll: selector => selector.startsWith('table.datatable') ? rows :
        selector.startsWith('div.pages') ? pages : [] }
  }));
  const parsed = extract([row('123'), row('999')]);
  assert.deepEqual(parsed.threads.map(value => value.threadId), ['123'],
    'only a server favorites deletion control establishes membership');
  assert.equal(extract([row('999')]).extractionIncomplete, true,
    'an unparsed membership entry must not be reported as an empty server snapshot');
  const pageLink = (label, href) => ({ textContent: label, getAttribute: () => href });
  assert.equal(extract([row('123')], [
    pageLink('下一页', 'my.php?item=favorites&type=thread&page=2'),
    pageLink('... 23', 'my.php?item=favorites&type=thread&page=23')
  ]).lastPage, 23, 'non-numeric page labels cannot collapse the list to a single page');
  assert.equal(extract([row('123')], [
    pageLink('下一页', 'my.php?item=favorites&type=thread&page=2'),
    pageLink('... 23', 'my.php?item=favorites&type=thread&page=23'),
    pageLink('999', 'viewthread.php?tid=123&page=999'),
    pageLink('888', 'my.php?item=attention&type=thread&page=888'),
    pageLink('777', 'https://evil.example/forum/my.php?item=favorites&page=777')
  ]).lastPage, 23, 'pagination belongs to this collection, and link targets matter more than labels');
}

// A native single-item action must never submit another preselected item.
// Execute the generated production scripts, without network or real forms.
for (const kind of ['Favorite', 'Attention']) {
  const directory = kind === 'Favorite' ? 'favorite/FavoritesPage' : 'attention/AttentionPage';
  const item = kind === 'Favorite' ? 'favorites' : 'attention';
  const submitName = kind === 'Favorite' ? 'favsubmit' : 'attentionsubmit';
  const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/' + directory + '.ets'), 'utf8');
  const start = source.indexOf('  private get' + kind + 'RemovalStartScript(');
  const output = {};
  vm.runInNewContext(ts.transpileModule('class Extractor {' + source.slice(start, source.lastIndexOf('\n}')) +
    '} exports.Extractor = Extractor;', { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: output });
  function run({ action = 'my.php?item=' + item + '&type=thread', override = '', hidden = false } = {}) {
    const input = (name, value, checked = false, type = 'checkbox') => ({ type, checked,
      getAttribute: attr => attr === 'name' ? name : attr === 'value' ? value : null });
    const target = input('delete[]', '123');
    const other = input('delete[]', '456', true, hidden ? 'hidden' : 'checkbox');
    const submit = input(submitName, 'true', false, 'submit');
    const getSubmitAttribute = submit.getAttribute;
    submit.getAttribute = attr => attr === 'formaction' ? override : getSubmitAttribute(attr);
    let submitted = null;
    const form = { elements: [target, other, input('formhash', 'synthetic', false, 'hidden'), submit],
      getAttribute: attr => attr === 'action' ? action : null,
      requestSubmit(button) {
        assert.equal(button, submit);
        submitted = form.elements.filter(node => node.getAttribute('name') === 'delete[]' &&
          (node.type === 'hidden' || node.checked)).map(node => node.getAttribute('value'));
      }
    };
    const result = JSON.parse(vm.runInNewContext(new output.Extractor()['get' + kind + 'RemovalStartScript']('123', 7), {
      URL, location: { href: 'https://www.4d4y.com/forum/my.php?item=' + item + '&type=thread' },
      document: { forms: [form], querySelector: () => null }
    }));
    return { result, submitted };
  }
  assert.deepEqual(run().submitted, ['123'], kind + ': submit only the requested item');
  for (const fixture of [
    { action: 'https://evil.example/forum/my.php?item=' + item },
    { action: 'https://www.4d4y.com/forum/my.php.extra?item=' + item },
    { action: 'my.php?item=' + item + '&type=forum' },
    { override: 'https://evil.example/forum/my.php?item=' + item },
    { hidden: true }
  ]) {
    const { result, submitted } = run(fixture);
    assert.equal(result.started, false, kind + ': reject unexpected submission shape');
    assert.equal(submitted, null);
  }
}
console.log('Single-item list removal scope and form destination regression passed.');
