// Synthetic window sizes only; no device/account state or forum requests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const moduleConfig = read('module.json5');
assert.match(moduleConfig, /"deviceTypes"\s*:\s*\[\s*"phone",\s*"tablet"\s*\]/);
assert.match(moduleConfig, /"orientation"\s*:\s*"auto_rotation_restricted"/);
const index = read('ets/pages/Index.ets');
assert.match(index, /\.mode\(NavigationMode\.Stack\)/);
assert.equal((index.match(/Navigation\(this\.pathStack\)/g) || []).length, 1,
  'Resizing must not recreate a different navigation tree or its drafts');
assert.match(index, /onAreaChange/);
const source = read('ets/presentation/layout/FourD4yAdaptiveLayout.ets');
const compiled = ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
}}).outputText;
const context = { exports: {} };
vm.runInNewContext(compiled, context);
const { getFourD4ySheetWidth: width, getFourD4ySheetHeight: height } = context.exports;
assert.equal(width(360), 360);
assert.equal(width(599), 599);
assert.equal(width(600), 420);
assert.equal(width(960), 560);
assert.equal(width(1440), 560);
for (const w of [240, 320, 360, 600, 720, 960, 1440]) {
  assert.ok(width(w) > 0 && width(w) <= w);
}
assert.equal(height(460, 760), 460);
assert.equal(height(620, 500), 452);
assert.equal(height(320, 240), 192);
for (const h of [80, 160, 240, 360, 500, 960]) {
  assert.ok(height(620, h) > 0 && height(620, h) <= h);
}
assert.equal(height(320, 0), 320, 'Initial unmeasured window retains existing phone height');
for (const invalid of [NaN, Infinity, -1]) {
  assert.equal(width(invalid), 360);
  assert.equal(height(320, invalid), 320);
}
for (const file of ['home/HomePage.ets', 'thread/ThreadDetailPage.ets',
  'composer/ForumSmileyButton.ets']) {
  const ui = read(`ets/presentation/${file}`);
  assert.match(ui, /preferType: SheetType\.BOTTOM/,
    `${file}: do not let large windows turn bottom sheets into off-screen anchored popups`);
  assert.match(ui, /width: getFourD4ySheetWidth\(this\.viewportWidth\)/);
  assert.match(ui, /height: getFourD4ySheetHeight\(/);
}
const composer = read('ets/presentation/composer/ForumComposerPage.ets');
const home = read('ets/presentation/home/HomePage.ets');
assert.match(home.slice(home.indexOf('private buildMainDrawer()'),
  home.indexOf('private buildDrawerIdentityHeader()')), /\.align\(Alignment\.Top\)/,
  'A tall tablet must not vertically center the drawer entries below a large blank area');
assert.match(composer.slice(composer.indexOf('private buildAdvancedReplyEditor()'),
  composer.indexOf('private requestComposerInputFocus()')), /Scroll\(\)/);
assert.ok((composer.match(/maxHeight: '30%'/g) || []).length >= 3,
  'New topic, advanced reply and edit headers must leave room for the message and send action');
const advanced = composer.slice(composer.indexOf('private buildAdvancedReplyEditor()'),
  composer.indexOf('private requestComposerInputFocus()'));
assert.match(advanced, /availableHeight < 280/);
assert.match(advanced, /padding\(this\.compactReplyLayout \? 4 : 12\)/);
assert.equal((advanced.match(/TextArea\(/g) || []).length, 1,
  'Short-window spacing must not replace the focused input');
console.log('Adaptive single-stack navigation, device declaration and bounded sheet/editor layout passed.');
