// Synthetic registry; Preferences cache and disk deliberately behave separately.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(relative, dependencies = {}) {
  const exports = {};
  const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets', relative), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  }}).outputText, { exports, require: name => {
    assert.ok(name in dependencies, name); return dependencies[name];
  } });
  return exports;
}
const contracts = load('domain/account/FourD4yAccountContracts.ets');
let cache = '', disk = '', failFlush = false, failRead = false, gate;
const prefs = {
  getSync: () => cache,
  put: async (_key, value) => { cache = value; },
  flush: async () => {
    if (gate) await gate;
    if (failFlush) throw new Error('synthetic disk failure');
    disk = cache;
  }
};
const store = load('data/local/FourD4yAccountProfileStore.ets', {
  '@kit.ArkData': { preferences: { getPreferences: async () => {
    if (failRead) throw new Error('synthetic read failure'); return prefs;
  } } },
  '../../domain/account/FourD4yAccountContracts': contracts
}).FourD4yAccountProfileStore;
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const first = contracts.upsertFourD4yAccountProfile(contracts.createDefaultFourD4yAccountRegistry(),
    { userId: '11', displayName: 'synthetic first' }, 1000);
  const second = contracts.upsertFourD4yAccountProfile(first,
    { userId: '22', displayName: 'synthetic second' }, 2000);
  assert.equal(await store.save({}, first), true);
  const original = disk;
  failFlush = true;
  assert.equal(await store.save({}, second), false);
  assert.equal(disk, original);
  assert.equal(cache, original, 'failed flush must not leave a phantom selected account');
  assert.equal((await store.load({})).activeProfileId, first.activeProfileId);
  failFlush = false;
  let resume; gate = new Promise(resolve => { resume = resolve; });
  const saving = store.save({}, second);
  let readFinished = false;
  const reading = store.load({}).then(value => { readFinished = true; return value; });
  await tick();
  assert.equal(readFinished, false, 'reads wait for committed registry writes');
  const savingAgain = store.save({}, first);
  resume(); gate = undefined;
  assert.equal(await saving, true);
  await reading;
  assert.equal(await savingAgain, true);
  assert.equal((await store.load({})).activeProfileId, first.activeProfileId);
  failRead = true;
  await assert.rejects(store.load({}), /account-registry-read-failed/);
  assert.equal(await store.save({}, second), false);
  failRead = false;
  assert.equal(await store.save({}, second), true, 'failed operation must not poison queue');
  assert.equal(await store.save({}, first), true);
  let current = true;
  gate = new Promise(resolve => { resume = resolve; });
  const expiring = store.save({}, second, () => current);
  await tick();
  current = false;
  resume(); gate = undefined;
  assert.equal(await expiring, false, 'verification expiring during flush must not report success');
  assert.equal(disk, original, 'expired activation is restored before releasing the write queue');
  assert.equal(cache, original);
  assert.equal(await store.save({}, second, () => false), false);
  assert.equal(disk, original, 'already expired queued operation cannot change the registry');
  assert.equal(await store.save({}, second), true, 'subsequent legitimate operation still succeeds');
  current = true;
  gate = new Promise(resolve => { resume = resolve; });
  const staleThenNew = store.save({}, first, () => current);
  await tick();
  const validAfterStale = store.save({}, second);
  current = false;
  resume(); gate = undefined;
  assert.equal(await staleThenNew, false);
  assert.equal(await validAfterStale, true);
  assert.equal(contracts.parseFourD4yAccountRegistry(disk).activeProfileId, second.activeProfileId,
    'expired compensation cannot overwrite the next valid queued write');
  console.log('Account registry ordering, cache rollback and read failure regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
