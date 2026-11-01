const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const read = name => fs.readFileSync(path.join(root, name + '.ets'), 'utf8');
function evaluate(source, globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, ...globals });
  return exports;
}
const geometry = evaluate(read('domain/settings/FourD4ySplitPane'));
const layout = evaluate(read('presentation/layout/FourD4yAdaptiveLayout'));
const width = geometry.getFourD4ySplitPaneWidth;
assert.equal(width(1440, 0.5), 720);
assert.equal(width(600, 0.7), 240);
assert.equal(width(960, 0.7), 600);
assert.equal(width(960, 0.01), 240);
assert.equal(width(400, 0.7), 400);
assert.ok(Math.abs(width(1440, 0.7) - 1008) < 1e-8,
  'the wide-window preference survives a narrow clamp');
for (const invalid of [0, 1, -1, Infinity, NaN, '0.5', null, undefined]) {
  assert.equal(geometry.normalizeFourD4ySplitPaneRatio(invalid), 0.4);
}
for (const w of [600, 707.2, 960, 1440, 1920]) {
  for (const r of [0.01, 0.4, 0.6, 0.99]) {
    assert.ok(width(w, r) >= 240 && w - width(w, r) >= 360);
  }
}
const index = read('pages/Index');
const begin = index.indexOf('  aboutToAppear(): void');
const end = index.indexOf('  @Builder\n  private routeMap(');
const production = 'class Root {' + index.slice(begin, end) + '} exports.Root = Root;';
let saveResult = {}, resolveLoad;
const toasts = [];
const Root = evaluate(production, { ...geometry, ...layout,
  FourD4yUserSettingsStore: {
    load: () => new Promise(resolve => { resolveLoad = resolve; }),
    saveSplitPaneRatio: async () => saveResult
  }
}).Root;
function app(w = 1440, ratio = 0.4) {
  return Object.assign(new Root(), { isIndexAlive: true, splitPreferenceReady: true,
    navigationWidth: w, splitPaneRatio: ratio, isResizingSplit: false,
    activeRouteName: 'ThreadDetail', mainDrawerOpen: false, quickReplyVisible: false,
    splitSaveSequence: 0, getUIContext: () => ({ getHostContext: () => ({}),
      getPromptAction: () => ({ showToast: t => toasts.push(t.message) }) }) });
}
const a = app(), writes = [];
a.persistSplitPreference = ratio => writes.push(ratio);
a.beginSplitDrag(); a.updateSplitDrag(144); a.endSplitDrag();
assert.equal(a.splitPaneRatio, 0.5); assert.deepEqual(writes, [0.5]);
a.beginSplitDrag(); a.updateSplitDrag(10000); a.cancelSplitDrag();
assert.equal(a.splitPaneRatio, 0.5); assert.equal(writes.length, 1, 'cancel must not save');
a.beginSplitDrag(); a.updateSplitDrag(120); a.navigationWidth = 960; a.endSplitDrag();
assert.equal(a.splitPaneRatio, 0.5); assert.equal(writes.length, 1, 'resize cancels the drag');
const narrow = app(600, 0.7);
narrow.persistSplitPreference = () => assert.fail('automatic clamping is not a preference');
narrow.beginSplitDrag(); narrow.updateSplitDrag(100); narrow.endSplitDrag();
assert.equal(narrow.splitPaneRatio, 0.7);
for (const name of ['ForumComposer', 'ImageViewer', 'Login', 'Account']) {
  const full = app(); full.activeRouteName = name; full.beginSplitDrag();
  assert.equal(full.isResizingSplit, false);
}
const phone = app(400); phone.beginSplitDrag(); assert.equal(phone.isResizingSplit, false);
assert.match(index, /PanGesture\(\{ fingers: 1, direction: PanDirection\.Horizontal/);
assert.match(index, /\.onActionEnd\(\(event: GestureEvent\) => \{\s*this\.updateSplitDrag\(event\.offsetX\);\s*this\.endSplitDrag\(\);/,
  'the final gesture position is applied before saving');
assert.match(index, /this\.navigationWidth - this\.splitPaneWidth\(\)/,
  'drawer dismissal overlay must track the adjusted right-pane width');
(async () => {
  const restoring = app(); restoring.splitPreferenceReady = false;
  const load = restoring.restoreSplitPreference();
  resolveLoad({ splitPaneRatio: 0.55 }); await load;
  assert.equal(restoring.splitPaneRatio, 0.55); assert.equal(restoring.splitPreferenceReady, true);
  const closed = app(); closed.splitPreferenceReady = false;
  const late = closed.restoreSplitPreference(); closed.isIndexAlive = false;
  resolveLoad({ splitPaneRatio: 0.6 }); await late;
  assert.equal(closed.splitPaneRatio, 0.4); assert.equal(closed.splitPreferenceReady, false);
  const failed = app(); saveResult = undefined;
  await failed.persistSplitPreference(0.6); assert.equal(toasts.length, 1);
  failed.isIndexAlive = false; await failed.persistSplitPreference(0.5);
  assert.equal(toasts.length, 1, 'no late UI after disposal');
  console.log('Split-pane limits, gesture intent, cancellation, restoration and save-failure UI passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
