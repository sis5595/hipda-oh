const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const collectionExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/favorite/FourD4yCollectionPagination.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: collectionExports });
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const moduleCache = new Map();
function loadContract(file) {
  if (moduleCache.has(file)) return moduleCache.get(file);
  const exports = {};
  moduleCache.set(file, exports);
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: name => loadContract(path.resolve(path.dirname(file), name + '.ets')) });
  return exports;
}
function extract(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
const exported = {};
const code = 'class Reader {' +
  extract('  private async probeFavoriteOperation(', '  private getFavoriteActionButtonLabel(') +
  extract('  private completeFavoriteSubmission(', '  private failFavoriteSubmission(') +
  extract('  private getFavoriteOperationProbeScript(', '  private getFavoriteVerificationScript(') +
  '} exports.Reader = Reader;';
const operationUrl = (id, favorite) => `https://www.4d4y.com/forum/my.php?item=favorites&action=${favorite ? 'remove' : 'add'}&inajax=1&ajaxtarget=favorite_msg&tid=${id}`;
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
}}).outputText, { exports: exported, bindFourD4yCollectionCache: async () => {}, buildFourD4yFavoriteOperationUrl: operationUrl,
  parseFourD4yFavoriteOperationPayload: value => value,
  isExpectedFourD4yFavoriteOperationPayload: () => true,
  isAllowedFourD4yFavoriteOperationUrl: url => /my.php\?item=favorites&action=(add|remove)/.test(url),
  FourD4yPageAccessState: { LoginRequired: 'loginRequired' } });
const reader = new exported.Reader();
const anchor = (href, onclick = '') => ({ textContent: '收藏',
  getAttribute: name => name === 'href' ? href : onclick });
function probe({ links = [], activeChallenge = false, posts = true, signedIn = true,
  href = 'https://www.4d4y.com/forum/viewthread.php?tid=123' } = {}) {
  const document = { title: 'test', documentElement: {
    innerHTML: '<script src="/cdn-cgi/challenge-platform/scripts/jsd/api.js"></script>'
  }, querySelector: selector => {
    if (selector.includes('cf-turnstile')) return activeChallenge ? {} : null;
    if (selector.includes('#umenu')) {
      assert.equal(selector, '#umenu cite a[href*="space.php"]', 'attribute values containing a dot must be quoted');
      return signedIn ? anchor('space.php?uid=700001') : null;
    }
    return null;
  }, querySelectorAll: selector => selector === 'a' ? links : posts ? [{}] : [] };
  return JSON.parse(vm.runInNewContext(reader.getFavoriteOperationProbeScript('123', 7),
    { URL, document, location: { href } }));
}
(async () => {
  const header = anchor('my.php?item=favorites&type=thread');
  assert.equal(probe({ links: [header] }).hasChallenge, false,
    'passive detection on a readable signed-in topic is not a challenge page');
  assert.equal(probe({ links: [header] }).errorMessage, '');
  const valid = anchor(operationUrl('123', false));
  assert.equal(probe({ links: [header, valid] }).actionUrl, operationUrl('123', false),
    'the header list entry must not mask a later exact-thread action');
  assert.equal(probe({ links: [valid], activeChallenge: true }).hasChallenge, true);
  for (const fixture of [{ posts: false }, { signedIn: false },
    { href: 'https://evil.example/forum/viewthread.php?tid=123' },
    { href: 'https://www.4d4y.com/forum/viewthread.php?tid=999' }]) {
    assert.notEqual(probe(fixture).errorMessage, '', 'fallback requires the authenticated target document');
  }
  for (const knownFavorite of [false, true]) {
    Object.assign(reader, { route: { threadId: '123' }, isThreadPageAlive: true,
      accountState: { getSessionGeneration: () => 1 }, getUIContext: () => ({ getHostContext: () => ({}) }),
      isLoggedIn: true, isFavoriteSubmitting: false, isFavorite: knownFavorite,
      webLoadSequence: 1, favoriteOperationSequence: 1,
      favoriteState: { isFavorite: () => knownFavorite },
      threadWebController: { runJavaScript: async () => ({ ...probe(), actionUrl: operationUrl('123', false) }) }
    });
    await reader.probeFavoriteOperation(1);
    assert.equal(reader.isFavorite, knownFavorite, 'an add link must not erase server-confirmed membership');
    assert.equal(reader.favoriteOperationUrl, operationUrl('123', knownFavorite));
  }
  let confirmed;
  reader.clearFavoriteSubmissionWatchdog = () => {};
  reader.favoriteState = { markFavorite: () => {}, markNotFavorite: () => {},
    notifyConfirmedThreadMutation: (_, value) => { confirmed = value; } };
  for (const favorite of [false, true, false]) {
    reader.completeFavoriteSubmission(favorite);
    assert.equal(reader.favoriteOperationUrl, operationUrl('123', favorite),
      'a confirmed mutation must also switch the next operation address');
    assert.equal(confirmed, favorite);
  }
  reader.isThreadPageAlive = false;
  reader.favoriteActionMessage = 'unchanged';
  await reader.probeFavoriteOperation(1);
  assert.equal(reader.favoriteActionMessage, 'unchanged');
  console.log('Favorite action identity, passive detection and confirmed-state regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });

// Feed actual generated DOM results through the production contract parser,
// including ArkWeb's JSON-wrapped representation (no live private page data).
for (const kind of ['Favorite', 'Attention']) {
  const item = kind === 'Favorite' ? 'favorites' : 'attention';
  const loaded = {};
  const methods = extract('  private get' + kind + 'VerificationScript(',
    '  private isCurrent' + kind + 'VerificationRequest(');
  vm.runInNewContext(ts.transpileModule('class Reader {' + methods + '} exports.Reader = Reader;', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports: loaded, ...collectionExports });
  const contracts = loadContract(path.resolve(__dirname,
    '../../main/ets/domain/' + kind.toLowerCase() + '/FourD4y' + kind + 'Contracts.ets'));
  for (const present of [false, true]) {
    const form = { getAttribute: () => 'my.php?item=' + item + '&type=thread',
      querySelector: () => present ? { type: 'checkbox' } : null };
    const document = { forms: [form], documentElement: { innerHTML: '' }, querySelector: () => null,
      querySelectorAll: () => [{ getAttribute: () => 'my.php?item=' + item + '&page=23' }] };
    const raw = vm.runInNewContext(new loaded.Reader()['get' + kind + 'VerificationScript']('123', 7, 2), {
      URL, document, location: { href: 'https://www.4d4y.com/forum/my.php?item=' + item + '&page=2' }
    });
    for (const result of [raw, JSON.stringify(raw)]) {
      const payload = contracts['parseFourD4y' + kind + 'VerificationPayload'](result);
      assert.ok(payload, kind + ': real script and parser agree');
      assert.equal(payload.lastPage, 23);
      assert.equal(payload.formFound, true);
      assert.equal(payload[kind === 'Favorite' ? 'favoritePresent' : 'attentionPresent'], present);
      assert.equal(contracts['isExpectedFourD4y' + kind + 'VerificationPayload'](payload, '123', 7, 2), true);
      assert.equal(contracts['parseFourD4y' + kind + 'VerificationPayload'](
        JSON.stringify({ ...JSON.parse(raw), lastPage: 1 })), null);
    }
    const goodUrl = 'https://www.4d4y.com/forum/my.php?item=' + item + '&page=2';
    const run = href => JSON.parse(vm.runInNewContext(
      new loaded.Reader()['get' + kind + 'VerificationScript']('123', 7, 2),
      { URL, document, location: { href } }));
    for (const href of [goodUrl.replace('www.4d4y.com', 'evil.example'),
      goodUrl.replace('my.php?', 'my.php.backup?'), goodUrl.replace('page=2', 'page=1'),
      goodUrl + '&page=2', goodUrl + '&item=' + item, goodUrl + '&type=forum',
      goodUrl.replace('https://', 'http://'), goodUrl.replace('https://', 'https://user@')]) {
      assert.equal(run(href).formFound, false, 'wrong document cannot prove absence or presence');
    }
    form.getAttribute = () => goodUrl.replace('www.4d4y.com', 'evil.example');
    assert.equal(run(goodUrl).formFound, false, 'foreign form is not collection evidence');
    form.getAttribute = () => '';
    assert.equal(run(goodUrl).formFound, true, 'empty form action resolves to verified current document');
  }
}
console.log('Collection verification DOM-to-contract regression passed.');

// A target absent on page one can still be present on page two. Exercise the
// actual detail-page verification methods for both server collections.
(async () => {
  for (const kind of ['Favorite', 'Attention']) {
    const prefix = kind.toLowerCase();
    const methods = extract('  private async read' + kind + 'VerificationFromWeb(',
      '  private complete' + kind + 'Submission(');
    const loaded = {};
    vm.runInNewContext(ts.transpileModule('class Reader {' + methods + '} exports.Reader = Reader;', {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
    }).outputText, { exports: loaded, ...collectionExports, FourD4yPageAccessState: { LoginRequired: 'loginRequired' },
      ['parseFourD4y' + kind + 'VerificationPayload']: value => value,
      ['isExpectedFourD4y' + kind + 'VerificationPayload']: () => true });
    const reader = new loaded.Reader();
    let completed, failed = '', scheduled = 0;
    let payload = { page: 1, lastPage: 2, accessState: 'available', formFound: true,
      hasChallenge: false, errorMessage: '', [prefix === 'favorite' ? 'favoritePresent' : 'attentionPresent']: false };
    Object.assign(reader, { route: { threadId: '123' }, isThreadPageAlive: true,
      ['is' + kind + 'Submitting']: true, [prefix + 'SubmissionSequence']: 1,
      [prefix + 'VerificationPage']: 1, [prefix + 'VerificationAttempt']: 0,
      [prefix + 'VerificationExpectedState']: false,
      [prefix + 'VerificationWebController']: { runJavaScript: async () => payload },
      ['get' + kind + 'VerificationScript']: () => '',
      ['complete' + kind + 'Submission']: value => { completed = value; },
      ['fail' + kind + 'Submission']: message => { failed = message; },
      ['schedule' + kind + 'VerificationLoad']: () => { scheduled++; }
    });
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, undefined, kind + ': first-page absence cannot confirm removal');
    assert.equal(reader[prefix + 'VerificationPage'], 2);
    assert.equal(scheduled, 1);
    payload = { ...payload, page: 2 };
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, false, kind + ': absence across the bounded complete list confirms removal');
    assert.equal(failed, '');
    completed = undefined; scheduled = 0;
    reader[prefix + 'VerificationPage'] = 1;
    reader[prefix + 'VerificationExpectedState'] = true;
    payload = { ...payload, page: 1 };
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, undefined, kind + ': added older topic may be sorted onto a later page');
    payload = { ...payload, page: 2, [prefix === 'favorite' ? 'favoritePresent' : 'attentionPresent']: true };
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, true);
    completed = undefined; scheduled = 0;
    reader[prefix + 'VerificationExpectedState'] = false;
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, undefined, kind + ': target still present means retry, not success');
    assert.equal(reader[prefix + 'VerificationPage'], 1, 'read-only retry starts a fresh traversal');
    assert.equal(reader[prefix + 'VerificationAttempt'], 1);
    assert.equal(scheduled, 1);
    reader[prefix + 'VerificationPage'] = 10;
    payload = { ...payload, page: 10, lastPage: 11,
      [prefix === 'favorite' ? 'favoritePresent' : 'attentionPresent']: false };
    await reader['read' + kind + 'VerificationFromWeb']();
    assert.equal(completed, undefined, kind + ': bounded partial scan cannot prove absence');
    assert.match(failed, /尚未完整核对/);
    failed = ''; scheduled = 0;
    let resolve;
    reader[prefix + 'VerificationWebController'].runJavaScript = () => new Promise(done => { resolve = done; });
    const pending = reader['read' + kind + 'VerificationFromWeb']();
    reader[prefix + 'VerificationAttempt']++;
    resolve({ ...payload, lastPage: 10 });
    await pending;
    assert.equal(completed, undefined, 'previous traversal callback is stale even on the same page');
    assert.equal(scheduled, 0);
    for (const invalidation of ['attempt', 'page', 'exit']) {
      let reject;
      reader.isThreadPageAlive = true;
      reader[prefix + 'VerificationWebController'].runJavaScript = () => new Promise((_, fail) => { reject = fail; });
      const rejected = reader['read' + kind + 'VerificationFromWeb']();
      if (invalidation === 'attempt') reader[prefix + 'VerificationAttempt']++;
      if (invalidation === 'page') reader[prefix + 'VerificationPage']++;
      if (invalidation === 'exit') reader.isThreadPageAlive = false;
      reject(new Error('late Web callback'));
      await rejected;
      assert.equal(failed, '', kind + ': stale rejection must not fail current operation (' + invalidation + ')');
    }
  }
  console.log('Detail collection verification pagination regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
