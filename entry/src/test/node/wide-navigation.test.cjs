// Execute production navigation methods with synthetic routes, never accounts.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
function extract(text, start, end) {
  const a = text.indexOf(start), b = text.indexOf(end, a);
  assert.ok(a >= 0 && b > a);
  return text.slice(a, b);
}
const policy = {}, result = {};
vm.runInNewContext(ts.transpileModule(read('presentation/layout/FourD4yAdaptiveLayout.ets'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS }
}).outputText, { exports: policy });
const index = read('pages/Index.ets');
const home = read('presentation/home/HomePage.ets');
const code = 'class Root {' + extract(index, '  aboutToAppear(): void', '  @Builder\n  private routeMap(') +
  '} class Home {' + extract(home, '  private pushHomeRoute(', '  private refreshAfterAccountManagement(') +
  '} exports.Root = Root; exports.Home = Home;';
const selected = new Map();
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
}}).outputText, { exports: result, ...policy,
  AppStorage: { setOrCreate: (key, value) => selected.set(key, value) } });
for (const wide of [false, true]) {
  const h = new result.Home(), stack = [], callback = () => {};
  let clears = 0;
  Object.assign(h, { isWideLayout: wide, pathStack: {
    clear: animated => { assert.equal(animated, false); stack.length = 0; clears++; },
    pushPathByName: (name, param, onPop) => stack.push({ name, param, onPop })
  } });
  h.pushHomeRoute('ThreadDetail', { threadId: '1' });
  h.pushHomeRoute('ThreadDetail', { threadId: '2' }, callback);
  assert.equal(stack.length, wide ? 1 : 2);
  assert.equal(clears, wide ? 2 : 0);
  assert.equal(stack[stack.length - 1].onPop, callback);
}
const app = new result.Root();
let interception, popped = 0;
Object.assign(app, { navigationWidth: 960, activeRouteName: 'ThreadDetail', quickReplyVisible: false,
  loadPrivacyConsent: async () => {}, pathStack: {
    setInterception: value => { interception = value; }, size: () => 1, pop: () => popped++
  } });
app.aboutToAppear();
interception.willShow('navBar', { pathInfo: { name: 'ThreadDetail', param: { threadId: 'synthetic' } } });
assert.equal(selected.get('hipdaoh_selected_thread_id'), 'synthetic');
assert.equal(app.onBackPress(), true); assert.equal(popped, 1);
app.mainDrawerOpen = true;
assert.equal(app.onBackPress(), true);
assert.equal(app.mainDrawerOpen, false);
assert.equal(popped, 1, 'dismiss drawer before closing the detail');
for (const name of ['ForumComposer', 'ImageViewer', 'Login', 'Account']) {
  app.activeRouteName = name;
  assert.equal(app.onBackPress(), false, 'fullscreen destinations own their Back handling');
}
app.activeRouteName = 'ThreadDetail'; app.quickReplyVisible = true;
assert.equal(app.onBackPress(), false, 'quick reply must close through its own handler');
app.quickReplyVisible = false; app.navigationWidth = 400;
assert.equal(app.onBackPress(), false, 'phone Back unchanged');
interception.willShow({}, 'navBar');
assert.equal(selected.get('hipdaoh_selected_thread_id'), '');
assert.equal(app.activeRouteName, '');
let disposed = 0;
app.splitEmptyContent = { dispose: () => disposed++ };
app.aboutToDisappear();
interception.willShow('navBar', { pathInfo: { name: 'ThreadDetail', param: { threadId: 'late' } } });
assert.equal(selected.get('hipdaoh_selected_thread_id'), '');
assert.equal(disposed, 1);
console.log('Wide-pane selection replacement, return callbacks, fullscreen Back and selected-topic state passed.');
