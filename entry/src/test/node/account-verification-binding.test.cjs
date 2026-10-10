// Production coordination, synthetic identities/secrets; no real session data.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets/domain/account');
function load(name, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, name + '.ets'), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: name => {
    assert.ok(name in dependencies, name);
    return dependencies[name];
  } });
  return exports;
}
const contracts = load('FourD4yAccountContracts');
let registry = contracts.createDefaultFourD4yAccountRegistry();
let live = 'synthetic-a', writes = [], removals = [], registryWrites = 0;
let loadRegistry = async () => registry;
let saveAsset = async (id, secret) => { writes.push({ id, secret }); return true; };
let beforeRegistrySave = () => {};
const accountModule = load('FourD4yAccountService', {
  '../../data/local/FourD4yAccountProfileStore': { FourD4yAccountProfileStore: {
    load: () => loadRegistry(), save: async (_context, next, guard) => {
      beforeRegistrySave();
      if (!guard()) return false;
      registry = next; registryWrites++; return true;
    }
  } },
  '../../data/local/FourD4yAccountSessionStore': { FourD4yAccountSessionStore: {
    save: (id, secret) => saveAsset(id, secret), remove: async id => { removals.push(id); return true; },
    load: async () => null
  } },
  '../../data/remote/FourD4ySession': { FourD4ySession: { isCurrentAccountSessionSecret: async s => s === live } },
  './FourD4yAccountContracts': contracts
});
const service = accountModule.FourD4yAccountService;
const result = accountModule.FourD4yAccountSaveResult;
const first = { userId: '11', displayName: 'synthetic first' };
const second = { userId: '22', displayName: 'synthetic second' };
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  assert.equal(await service.saveVerifiedCurrentSession({}, first, live, () => true), result.Saved);
  assert.equal(writes[0].secret, 'synthetic-a');
  const baselineWrites = writes.length;
  assert.equal(await service.saveVerifiedCurrentSession({}, second, 'old-secret', () => true),
    result.VerificationExpired);
  assert.equal(writes.length, baselineWrites, 'do not associate a changed live cookie with the old identity');
  let resume, current = true;
  loadRegistry = () => new Promise(resolve => { resume = resolve; });
  const leaving = service.saveVerifiedCurrentSession({}, second, live, () => current);
  await tick();
  current = false;
  resume(registry);
  assert.equal(await leaving, result.VerificationExpired);
  assert.equal(writes.length, baselineWrites, 'closing while loading registry must not create an asset');
  loadRegistry = async () => registry;
  saveAsset = (id, secret) => new Promise(resolve => {
    writes.push({ id, secret }); resume = resolve;
  });
  const registryBefore = registryWrites;
  const switching = service.saveVerifiedCurrentSession({}, second, 'synthetic-a', () => true);
  await tick();
  live = 'synthetic-b';
  resume(true);
  assert.equal(await switching, result.VerificationExpired);
  assert.equal(registryWrites, registryBefore, 'late save cannot activate a stale account');
  assert.equal(removals.length, 1, 'clean up only the newly-created unlisted asset');
  live = 'synthetic-a';
  const existing = service.saveVerifiedCurrentSession({}, first, live, () => current);
  current = true;
  await tick();
  current = false;
  resume(true);
  assert.equal(await existing, result.VerificationExpired);
  assert.equal(removals.length, 1, 'a known account is never deleted by an expired verification');
  saveAsset = async (id, secret) => { writes.push({ id, secret }); return true; };
  loadRegistry = async () => { throw new Error('synthetic storage outage'); };
  assert.equal(await service.saveVerifiedCurrentSession({}, first, live, () => true), result.StorageFailed);
  loadRegistry = async () => registry;
  const saves = await Promise.all([
    service.saveVerifiedCurrentSession({}, first, live, () => true),
    service.saveVerifiedCurrentSession({}, second, live, () => true)
  ]);
  assert.deepEqual(saves, [result.Saved, result.Saved]);
  assert.equal(registry.profiles.length, 2, 'queued saves cannot overwrite one another with a stale registry');
  current = true;
  beforeRegistrySave = () => { current = false; };
  const beforeExpiredWrite = registryWrites;
  assert.equal(await service.saveVerifiedCurrentSession({}, first, live, () => current), result.VerificationExpired);
  assert.equal(registryWrites, beforeExpiredWrite, 'verification guard reaches the registry write boundary');
  console.log('Verified identity/session binding and save queue regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
