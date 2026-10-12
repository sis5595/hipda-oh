const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/composer/ForumComposerPage.ets'), 'utf8');
const begin = source.indexOf('  private readonly onEditKeyboardHeight');
const end = source.indexOf('  aboutToAppear()', begin);
const out = {};
let resolveWindow;
const modes = [];
const ui = { getHostContext: () => ({}), px2vp: n => n / 2,
  setKeyboardAvoidMode: mode => modes.push(mode) };
let listener;
const win = { on: (event, callback) => { listener = callback; },
  getWindowAvoidArea: type => ({ bottomRect: { height: type === 'nav' ? 40 : 640 } }) };
vm.runInNewContext(ts.transpileModule('class Editor {' + source.slice(begin, end) +
  '} exports.Editor = Editor;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: out,
  ForumComposerMode: { Edit: 'edit' }, KeyboardAvoidMode: { NONE: 4, RESIZE: 1 },
  window: { getLastWindow: () => new Promise(resolve => { resolveWindow = resolve; }),
    AvoidAreaType: { TYPE_KEYBOARD: 'keyboard', TYPE_NAVIGATION_INDICATOR: 'nav' } } });
function editor(mode = 'edit') {
  return Object.assign(new out.Editor(), { route: { mode }, isComposerRouteReady: true,
    getUIContext: () => ui, editKeyboardInset: 0 });
}
(async () => {
  const departed = editor();
  const pending = departed.attachEditKeyboard();
  departed.isComposerRouteReady = false;
  resolveWindow(win);
  await pending;
  assert.equal(listener, undefined, 'late window lookup must not subscribe after leaving');
  assert.equal(modes.length, 0, 'late lookup must not change another page keyboard mode');
  await editor('newThread').attachEditKeyboard();
  assert.equal(listener, undefined, 'new topic must retain its existing keyboard behavior');
  const current = editor();
  const opening = current.attachEditKeyboard();
  resolveWindow(win);
  await opening;
  assert.equal(current.editKeyboardInset, 300, 'exclude navigation inset and convert px to vp');
  assert.equal(modes.at(-1), 4, 'avoid subtracting the keyboard twice');
  listener(0);
  assert.equal(current.editKeyboardInset, 0, 'closing keyboard restores full editor height');
  listener(840);
  assert.equal(current.editKeyboardInset, 400, 'keyboard size changes resize the editor');
  listener(NaN);
  assert.equal(current.editKeyboardInset, 400);
  current.isComposerRouteReady = false;
  listener(0);
  assert.equal(current.editKeyboardInset, 400, 'late keyboard events cannot update disposed state');
  console.log('Edit keyboard inset and late-window/event guards passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
