// Production startup and consent gate with synthetic storage/window lifecycle.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
function execute(source, dependencies = {}, globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: id => {
    assert.ok(id in dependencies, id); return dependencies[id];
  }, ...globals });
  return exports;
}
let raw = '', failFlush = false;
const policy = execute(fs.readFileSync(path.join(root, 'domain/privacy/FourD4yPrivacyPolicy.ets'), 'utf8'));
const prefs = { getSync: () => raw, put: async (_key, value) => { raw = value; },
  flush: async () => { if (failFlush) throw new Error('synthetic flush failure'); } };
const store = execute(fs.readFileSync(path.join(root, 'data/local/FourD4yPrivacyConsentStore.ets'), 'utf8'), {
  '@kit.ArkData': { preferences: { getPreferences: async () => prefs } },
  '../../domain/privacy/FourD4yPrivacyPolicy': policy
}).FourD4yPrivacyConsentStore;
let pending = [];
const EntryAbility = execute(fs.readFileSync(path.join(root, 'entryability/EntryAbility.ets'), 'utf8'), {
  '@kit.AbilityKit': { UIAbility: class {} },
  '@kit.PerformanceAnalysisKit': { hilog: { error: () => {} } },
  '../data/local/FourD4yUserSettingsStore': { FourD4yUserSettingsStore: {
    restoreAndApply: () => new Promise(resolve => pending.push(resolve))
  } }
}, { AppStorage: { setOrCreate: () => {} } }).default;
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  assert.equal(store.POLICY_VERSION, policy.FOUR_D4Y_PRIVACY_POLICY_VERSION);
  for (const previous of ['', '2026-09-20', '2026-10-10']) {
    raw = previous;
    assert.equal(await store.hasAcceptedCurrentPolicy({}), false, 'old or absent consent must be renewed');
  }
  raw = '';
  failFlush = true;
  assert.equal(await store.acceptCurrentPolicy({}), false);
  assert.equal(await store.hasAcceptedCurrentPolicy({}), false,
    'failed acceptance cannot leave an accepted in-memory preference');
  failFlush = false;
  assert.equal(await store.acceptCurrentPolicy({}), true);
  failFlush = true;
  assert.equal(await store.withdrawConsent({}), false);
  assert.equal(await store.hasAcceptedCurrentPolicy({}), true, 'failed withdrawal retains the prior gate');
  failFlush = false;
  await Promise.all([store.acceptCurrentPolicy({}), store.withdrawConsent({})]);
  assert.equal(await store.hasAcceptedCurrentPolicy({}), false, 'the latest consent action wins');

  const ability = new EntryAbility();
  ability.context = { getApplicationContext: () => ({}) };
  let oldLoads = 0, newLoads = 0;
  const oldWindow = { loadContent: () => oldLoads++ };
  ability.onWindowStageCreate(oldWindow);
  ability.onWindowStageDestroy();
  pending.shift()(); await tick();
  assert.equal(oldLoads, 0, 'destroyed windows must not receive a late loadContent');
  ability.onWindowStageCreate(oldWindow);
  ability.onWindowStageCreate({ loadContent: () => newLoads++ });
  pending.shift()(); pending.shift()(); await tick();
  assert.equal(oldLoads, 0); assert.equal(newLoads, 1);
  ability.onWindowStageCreate(oldWindow); ability.onDestroy();
  pending.shift()(); await tick(); assert.equal(oldLoads, 0);
  console.log('Startup window generation and consent storage failure regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
