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
let memory = '51', disk = memory, failFlush = false;
let releaseRead;
const preferences = { getPreferences: async () => {
  if (releaseRead === null) await new Promise(resolve => { releaseRead = resolve; });
  return { getSync: () => memory, put: async (_, value) => { memory = value; },
    flush: async () => { if (failFlush) throw new Error('synthetic failure'); disk = memory; } };
} };
const catalog = load('domain/catalog/FourD4yForumCatalog');
const contract = load('domain/navigation/FourD4yHomeForumState');
const store = load('data/local/FourD4yLastForumStore', { '@kit.ArkData': { preferences },
  '../../domain/catalog/FourD4yForumCatalog': catalog,
  '../../domain/navigation/FourD4yHomeForumState': contract }).FourD4yLastForumStore;
(async () => {
  releaseRead = null;
  const first = store.save({}, '2'), second = store.save({}, '6'), pendingLoad = store.load({});
  await Promise.resolve(); await Promise.resolve();
  releaseRead();
  assert.equal(await first, true); assert.equal(await second, true);
  assert.equal(await pendingLoad, '6', 'the latest requested board wins despite delayed preferences acquisition');
  assert.equal(disk, '6');
  failFlush = true;
  assert.equal(await store.save({}, '51'), false);
  assert.equal(memory, '6', 'failed flush must not appear as a successful board change in cache');
  failFlush = false;
  assert.equal(await store.save({}, '2'), true, 'a failed write must not poison subsequent writes');
  assert.equal(await store.save({}, '999999'), false);
  assert.equal(await store.load({}), '2');
  console.log('Last-board persistence ordering and failure regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
