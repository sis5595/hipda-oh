// Execute production metadata storage with synthetic entries and injected disk failures.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
function load(file, dependencies) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: id => {
    assert.ok(id in dependencies, id); return dependencies[id];
  } });
  return exports;
}
const domain = load('domain/search/FourD4ySearchHistory.ets', {
  './FourD4ySearchContracts': { FourD4ySearchMode: { Title: 'title', FullText: 'fullText', Author: 'author' } }
});
let raw = '', failRead = false, failFlush = false, puts = 0, suspended;
const prefs = { getSync: () => raw, put: async (_key, value) => { raw = value; puts++; },
  flush: async () => {
    if (suspended) await suspended;
    if (failFlush) throw new Error('synthetic flush failure');
  } };
const { FourD4ySearchHistoryStore: store } = load('data/local/FourD4ySearchHistoryStore.ets', {
  '@kit.ArkData': { preferences: { getPreferences: async () => {
    if (failRead) throw new Error('synthetic read failure'); return prefs;
  } } }, '../../domain/search/FourD4ySearchHistory': domain
});
const entry = keyword => ({ keyword, mode: 'title', forumId: 'all' });
const keywords = values => Array.from(values, value => value.keyword);
(async () => {
  const normalized = domain.parseFourD4ySearchHistory(JSON.stringify([
    null, 5, entry(' first '), entry('first'), { ...entry('invalid forum'), forumId: 2 }, entry('second')
  ]));
  assert.deepEqual(keywords(normalized), ['first', 'second']);
  assert.equal(domain.parseFourD4ySearchHistory('x'.repeat(16385)).length, 0);
  failRead = true;
  await assert.rejects(store.record({}, entry('first')));
  assert.equal(puts, 0, 'read failures must not overwrite stored history with an empty list');
  failRead = false;
  await Promise.all([store.record({}, entry('first')), store.record({}, entry('second'))]);
  assert.deepEqual(keywords(await store.load({})), ['second', 'first']);
  let resume;
  suspended = new Promise(resolve => { resume = resolve; });
  const pending = store.record({}, entry('pending'));
  const cleared = store.clear({});
  resume(); suspended = undefined;
  await Promise.all([pending, cleared]);
  assert.equal((await store.load({})).length, 0, 'clear cannot be undone by an older pending record');
  await store.record({}, entry('baseline'));
  failFlush = true;
  await assert.rejects(store.clear({}));
  assert.deepEqual(keywords(domain.parseFourD4ySearchHistory(raw)), ['baseline']);
  failFlush = false;
  await store.record({}, entry('retry'));
  assert.deepEqual(keywords(await store.load({})), ['retry', 'baseline']);
  console.log('Search history normalization, ordering and storage failure regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
