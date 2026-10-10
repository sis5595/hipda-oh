const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(file, dependencies = {}, globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/' + file + '.ets'), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: name => {
    assert.ok(name in dependencies, name); return dependencies[name];
  }, ...globals });
  return exports;
}
let now = 1000;
const { FourD4yCollectionCache: Cache } = load('domain/favorite/FourD4yCollectionCache', {},
  { Date: { now: () => now } });
(async () => {
  const list = {}, otherList = {};
  let snapshot = new Cache(); snapshot.add('999');
  snapshot.observePage(['11'], 1, 2, list);
  assert.equal(snapshot.has('999'), true, 'partial list cannot prove absence');
  snapshot.observePage(['22'], 2, 2, list);
  assert.equal(snapshot.has('999'), false, 'complete ordered list removes externally deleted IDs');
  assert.equal(snapshot.has('11') && snapshot.has('22'), true);
  for (const interrupt of [
    c => c.add('77'), c => c.delete('77'), c => c.merge(['77']),
    c => c.releaseSnapshot(list),
    c => c.observePage(['22'], 2, 3, list),
    c => c.observePage(['22'], 2, 2, otherList),
    c => c.observePage([], 2, 2, list),
    c => c.observePage(['11'], 2, 2, list),
    c => c.observePage(['22', '22'], 2, 2, list),
    c => c.observePage(['bad'], 2, 2, list),
    c => c.observePage(['22'], 2, 2),
    () => { now += 60001; }
  ]) {
    snapshot = new Cache(); snapshot.add('999');
    snapshot.observePage(['11'], 1, 2, list); interrupt(snapshot);
    snapshot.observePage(['33'], 2, 2, list);
    assert.equal(snapshot.has('999'), true, 'interrupted/mixed/expired traversal must retain old hints');
  }
  snapshot = new Cache(); snapshot.add('999');
  snapshot.observePage(['11'], 1, 3, list);
  snapshot.observePage(['33'], 3, 3, list);
  assert.equal(snapshot.has('999'), true, 'skipped middle page is not a complete list');
  snapshot.observePage(['44'], 1, 2, list);
  snapshot.observePage(['55'], 2, 2, list);
  assert.equal(snapshot.has('999'), false, 'a fresh traversal may recover after interruption');
  snapshot.clear(); snapshot.add('999');
  snapshot.observePage(['11'], 1, 11, list);
  for (let p = 2; p <= 11; p++) snapshot.observePage([String(p + 20)], p, 11, list);
  assert.equal(snapshot.has('999'), true, 'bounded scan cannot imply an unbounded full snapshot');
  snapshot.observePage([], 1, 1, list);
  assert.equal(snapshot.has('999'), false, 'confirmed single empty page still clears old hints');

  const disk = new Map(); let writes = 0;
  const bind = (cache, uid, current = () => true) => cache.bind(uid,
    async () => disk.get(uid) || [], async ids => { writes++; disk.set(uid, [...ids]); }, current);
  let cache = new Cache();
  await bind(cache, '1'); cache.merge(['101', '202']);
  assert.equal(writes, 1, 'one snapshot yields one write, not one per ID');
  cache = new Cache(); await bind(cache, '1');
  assert.equal(cache.has('101'), true, 'cold restore');
  await bind(cache, '2'); assert.equal(cache.has('101'), false, 'other account isolated');
  cache.add('303'); cache.clear(); await bind(cache, '1');
  assert.equal(cache.has('101'), true); assert.equal(cache.has('303'), false);
  cache.delete('101'); cache = new Cache(); await bind(cache, '1');
  assert.equal(cache.has('101'), false, 'confirmed removal persisted');
  let resolve;
  cache = new Cache();
  const pending = cache.bind('1', () => new Promise(done => { resolve = done; }), async () => {}, () => true);
  cache.clear(); await bind(cache, '2'); resolve(['999']); await pending;
  assert.equal(cache.has('999'), false, 'late old-account snapshot ignored');
  cache = new Cache();
  const late = cache.bind('1', () => new Promise(done => { resolve = done; }), async () => {}, () => true);
  cache.replace([]); resolve(['999']); await late;
  assert.equal(cache.has('999'), false, 'late snapshot cannot resurrect confirmed empty list');
  cache = new Cache(); let current = true;
  const exited = cache.bind('1', () => new Promise(done => { resolve = done; }), async () => { writes++; }, () => current);
  current = false; resolve(['999']); await exited; assert.equal(cache.has('999'), false);
  const before = writes;
  await cache.bind('1', async () => { throw new Error('disk unavailable'); }, async () => { writes++; }, () => true);
  cache.add('888'); assert.equal(writes, before, 'read failure cannot overwrite storage');
  await bind(cache, '1'); assert.equal(cache.has('202'), true, 'failed load can retry');
  assert.equal(cache.has('888'), true, 'fresh positive survives retry without erasing other cached pages');
  cache = new Cache();
  await cache.bind('1', async () => { throw new Error('disk unavailable'); }, async () => {}, () => true);
  cache.delete('202'); await bind(cache, '1');
  assert.equal(cache.has('202'), false, 'fresh negative survives disk retry');
  cache = new Cache();
  let firstPageAlive = true;
  const firstLoad = cache.bind('1', () => new Promise(done => { resolve = done; }), async () => {}, () => firstPageAlive);
  let secondReads = 0;
  const secondLoad = cache.bind('1', async () => { secondReads++; return ['707']; }, async () => {}, () => true);
  firstPageAlive = false;
  resolve(['606']);
  await Promise.all([firstLoad, secondLoad]);
  assert.equal(secondReads, 1, 'active page must restore after the shared first-page load was invalidated');
  assert.equal(cache.has('707'), true);
  assert.equal(cache.has('606'), false);

  cache = new Cache(); firstPageAlive = true;
  const obsoleteLoad = cache.bind('1', () => new Promise(done => { resolve = done; }), async () => {}, () => firstPageAlive);
  let finishRecovery; let recoveryReads = 0;
  const recoveringLoad = cache.bind('1', () => { recoveryReads++; return new Promise(done => { finishRecovery = done; }); },
    async () => {}, () => true);
  const otherWaiter = cache.bind('1', async () => { recoveryReads++; return ['999']; }, async () => {}, () => true);
  firstPageAlive = false; resolve(['606']);
  await obsoleteLoad;
  await Promise.resolve(); await Promise.resolve();
  assert.equal(recoveryReads, 1, 'multiple waiting pages must share a single replacement read');
  finishRecovery(['707']);
  await Promise.all([recoveringLoad, otherWaiter]);
  cache.add('808');
  assert.equal(cache.has('707'), true);
  assert.equal(cache.has('999'), false, 'competing recovery must not replace the winning snapshot');

  const values = new Map(); let active = 0, maxActive = 0, failFlush = false;
  const prefs = {
    getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
    put: async (key, value) => { values.set(key, value); },
    flush: async () => { active++; maxActive = Math.max(maxActive, active); await Promise.resolve(); active--;
      if (failFlush) throw new Error('disk full'); }
  };
  const { FourD4yCollectionCacheStore: Store } = load('data/local/FourD4yCollectionCacheStore', {
    '@kit.ArkData': { preferences: { getPreferences: async () => prefs } }
  });
  await Promise.all([Store.save({}, '1', 'favorites', ['11']), Store.save({}, '1', 'favorites', ['22']),
    Store.save({}, '2', 'favorites', ['33']), Store.save({}, '1', 'attention', ['44'])]);
  assert.equal(maxActive, 1);
  assert.deepEqual(Array.from(await Store.load({}, '1', 'favorites')), ['22']);
  assert.deepEqual(Array.from(await Store.load({}, '2', 'favorites')), ['33']);
  assert.deepEqual(Array.from(await Store.load({}, '1', 'attention')), ['44']);
  failFlush = true;
  await assert.rejects(Store.save({}, '1', 'favorites', ['55']));
  failFlush = false;
  assert.deepEqual(Array.from(await Store.load({}, '1', 'favorites')), ['22'], 'failed flush rolls back memory');
  await Store.save({}, '1', 'favorites', Array.from({ length: 500 }, (_, i) => String(i + 1)));
  assert.equal((await Store.load({}, '1', 'favorites')).length, 300);
  values.set('favorites_1', 'broken'); await assert.rejects(Store.load({}, '1', 'favorites'));
  await assert.rejects(Store.load({}, '../account', 'favorites'));
  let cacheReads = 0;
  const binding = load('presentation/common/FourD4yCollectionCacheBinding', {
    '../../data/local/FourD4yCollectionCacheStore': { FourD4yCollectionCacheStore: {
      load: async (_, uid, item) => { cacheReads++; assert.equal(uid, '1'); assert.equal(item, 'favorites'); return ['77']; },
      save: async () => {}
    } },
    '../../domain/account/FourD4yAccountIdentityScript': load('domain/account/FourD4yAccountIdentityScript'),
    '../../domain/account/FourD4yAccountContracts': load('domain/account/FourD4yAccountContracts')
  }).bindFourD4yCollectionCache;
  cache = new Cache();
  await binding({}, { runJavaScript: async () => '' }, cache, 'favorites', () => true);
  assert.equal(cacheReads, 0, 'absent self identity cannot read any account cache');
  let live = true;
  const lateIdentity = binding({}, { runJavaScript: () => new Promise(done => { resolve = done; }) },
    cache, 'favorites', () => live);
  live = false; resolve(JSON.stringify({ userId: '1', displayName: 'fixture' })); await lateIdentity;
  assert.equal(cacheReads, 0, 'stale identity cannot initiate storage reads');
  await binding({}, { runJavaScript: async () => JSON.stringify({ userId: '1', displayName: 'fixture' }) },
    cache, 'favorites', () => true);
  assert.equal(cache.has('77'), true);
  console.log('Account collection cold restore, isolation, stale IO and bounded persistence passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
