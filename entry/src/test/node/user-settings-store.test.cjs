// Production field merging and storage failure/ordering with synthetic preferences.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
function load(relative, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, relative + '.ets'), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: name => {
    assert.ok(name in dependencies, name);
    return dependencies[name];
  } });
  return exports;
}
const catalog = load('domain/catalog/FourD4yForumCatalog');
const contracts = load('domain/settings/FourD4yUserSettings', { '../catalog/FourD4yForumCatalog': catalog,
  './FourD4yPostTail': load('domain/settings/FourD4yPostTail') });
const baseline = contracts.createDefaultFourD4yUserSettings();
let memory = JSON.stringify(baseline), disk = memory, failRead = false, failFlush = false;
let flushGate;
const preferences = {
  getPreferences: async () => {
    if (failRead) throw new Error('synthetic read outage');
    return { getSync: () => memory, put: async (_key, value) => { memory = value; },
      flush: async () => { if (flushGate) await flushGate;
        if (failFlush) throw new Error('synthetic flush outage'); disk = memory; }
    };
  }
};
const store = load('data/local/FourD4yUserSettingsStore', {
  '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: {} } },
  '@kit.ArkData': { preferences },
  '../../domain/settings/FourD4yUserSettings': contracts
}).FourD4yUserSettingsStore;
(async () => {
  failRead = true;
  await assert.rejects(store.load({}), /user-settings-read-failed/);
  assert.equal(await store.save({}, { ...baseline, fontScale: 1.3 }, baseline), undefined);
  assert.equal(memory, disk, 'failed reads must not fabricate an empty writable baseline');
  failRead = false;
  const [appearance, board] = await Promise.all([
    store.save({}, { ...baseline, themeMode: 'dark', fontScale: 1.3 }, baseline),
    store.save({}, { ...baseline, showPinnedThreads: false }, baseline)
  ]);
  assert.equal(appearance.themeMode, 'dark');
  assert.equal(board.showPinnedThreads, false);
  assert.equal(board.themeMode, 'dark', 'stale board snapshot must preserve newly-saved appearance');
  assert.equal(board.fontScale, 1.3);
  failFlush = true;
  const previousDisk = disk;
  assert.equal(await store.save({}, { ...board, fontScale: 0.9 }, board), undefined);
  assert.equal(memory, previousDisk, 'unconfirmed put must not become the next cached baseline');
  assert.equal(disk, previousDisk);
  failFlush = false;
  const recovered = await store.save({}, { ...baseline, postLineSpacing: 1.4 }, baseline);
  assert.equal(recovered.postLineSpacing, 1.4);
  assert.equal(recovered.fontScale, 1.3, 'a failed write cannot poison subsequent saves');
  assert.equal(recovered.showPinnedThreads, false);
  assert.equal(JSON.parse(disk).postLineSpacing, 1.4);
  for (const fails of [false, true]) {
    let release;
    flushGate = new Promise(resolve => { release = resolve; });
    failFlush = fails;
    const confirmed = JSON.parse(disk);
    const pending = store.save({}, { ...confirmed, fontScale: fails ? 1 : 1.15 }, confirmed);
    for (let i = 0; i < 8; i++) await Promise.resolve();
    let hasRead = false;
    const read = store.load({}).then(value => { hasRead = true; return value; });
    for (let i = 0; i < 8; i++) await Promise.resolve();
    assert.equal(hasRead, false, 'a page must not restore settings from an unconfirmed put');
    release();
    await pending;
    const restored = await read;
    assert.equal(restored.fontScale, fails ? confirmed.fontScale : 1.15);
    assert.equal(restored.fontScale, JSON.parse(disk).fontScale);
    flushGate = undefined;
    failFlush = false;
  }
  console.log('User settings field merge, write queue and failure recovery regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
