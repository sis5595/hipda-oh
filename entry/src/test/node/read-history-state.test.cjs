const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(name, dependencies) {
  const output = {};
  const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/domain/history', name + '.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: output, require: name => {
    assert.ok(name in dependencies, name); return dependencies[name];
  } });
  return output;
}
const entry = id => ({ threadId: id, title: 'Synthetic ' + id, forumId: '40',
  lastReadPage: 1, lastReadFloor: 1, visitedAt: 1000 });
let saved = [entry('1')], failLoad = false, failSave = false, failClear = false;
const operations = [];
const store = {
  load: async () => { if (failLoad) throw Error('synthetic read failure'); return saved.slice(); },
  save: async (_context, value) => {
    operations.push('save');
    if (failSave) return false;
    saved = value.slice(); return true;
  },
  clear: async () => {
    operations.push('clear');
    if (failClear) return false;
    saved = []; return true;
  }
};
const { FourD4yReadHistoryState: State } = load('FourD4yReadHistoryState', {
  './FourD4yReadHistory': load('FourD4yReadHistory', {}),
  '../../data/local/FourD4yReadHistoryStore': { FourD4yReadHistoryStore: store }
});
const ids = state => Array.from(state.getEntries(), item => item.threadId);
(async () => {
  const state = new State();
  failLoad = true;
  await assert.rejects(state.load({}));
  failLoad = false;
  await state.load({});
  assert.deepEqual(ids(state), ['1'], 'read failure must remain retryable');
  failClear = true;
  await assert.rejects(state.clear({}));
  assert.deepEqual(ids(state), ['1'], 'failed clear retains visible entries');
  failClear = false;
  await state.clear({});
  assert.deepEqual(ids(state), []);
  failSave = true;
  await assert.rejects(state.record({}, entry('2')));
  assert.deepEqual(ids(state), []);
  failSave = false;
  operations.length = 0;
  await Promise.all([state.record({}, entry('3')), state.clear({}), state.record({}, entry('4'))]);
  assert.deepEqual(operations, ['save', 'clear', 'save']);
  assert.deepEqual(ids(state), ['4'], 'a later record cannot resurrect pre-clear history');
  assert.deepEqual(Array.from(saved, item => item.threadId), ['4']);
  console.log('Reading history failure/ordering regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
