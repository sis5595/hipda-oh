const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const compile = code => ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText;
function load(file, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(compile(fs.readFileSync(path.join(root, file + '.ets'), 'utf8')),
    { exports, require: name => { assert.ok(name in dependencies, name); return dependencies[name]; } });
  return exports;
}
const tail = load('domain/settings/FourD4yPostTail');
const settings = load('domain/settings/FourD4yUserSettings', {
  '../catalog/FourD4yForumCatalog': load('domain/catalog/FourD4yForumCatalog'),
  './FourD4yPostTail': tail });
const defaults = settings.createDefaultFourD4yUserSettings();
assert.equal(defaults.addPostTail, false);
assert.equal(defaults.postTailText, 'HiPDA·OH');
assert.equal(tail.appendFourD4yPostTail('body', defaults), 'body');
const enabled = { ...defaults, addPostTail: true, postTailText: '自定义文字', postTailUrl: '' };
const bodyWithTail = 'body  [size=1]自定义文字[/size]';
assert.equal(tail.appendFourD4yPostTail('body', enabled), bodyWithTail);
assert.equal(tail.appendFourD4yPostTail(bodyWithTail, enabled), bodyWithTail);
assert.equal(tail.appendFourD4yPostTail(bodyWithTail + '  ', enabled), bodyWithTail + '  ');
assert.equal(tail.appendFourD4yPostTail('body', enabled, true), 'body', 'editing never injects a new tail');
assert.equal(tail.appendFourD4yPostTail('body', undefined), 'body');
assert.equal(tail.appendFourD4yPostTail('  ', enabled), '  ', 'the suffix cannot fabricate an otherwise empty post');
assert.equal(tail.appendFourD4yPostTail('[quote]old reply[/quote]\n\nnew reply', enabled),
  '[quote]old reply[/quote]\n\nnew reply  [size=1]自定义文字[/size]');
assert.equal(tail.appendFourD4yPostTail('body', { ...enabled, postTailText: '' }), 'body');
assert.equal(tail.appendFourD4yPostTail('body', { ...enabled, postTailText: '[quote]x[/quote]' }),
  'body  [size=1]&#91;quote&#93;x&#91;/quote&#93;[/size]');
assert.equal(tail.normalizeFourD4yPostTailUrl('github.com/sis5595/hipda-oh'),
  'https://github.com/sis5595/hipda-oh');
for (const url of ['javascript:alert(1)', 'data:text/html,x', 'file:///tmp/x',
  'https://user:pass@example.com/', 'https://example.com/[/url]', 'https://exa mple.com/',
  'https://example.com/\n[url=x]', 'https://example.com/' + 'x'.repeat(1100)]) {
  assert.equal(tail.normalizeFourD4yPostTailUrl(url), '', url);
}
assert.equal(tail.normalizeFourD4yPostTailUrl(''), '');
assert.equal(tail.normalizeFourD4yPostTailUrl('http://example.com/x?q=a&b=2'), 'http://example.com/x?q=a&b=2');
assert.equal(tail.appendFourD4yPostTail('body', { ...enabled, postTailUrl: 'https://example.com/' }),
  'body  [url=https://example.com/][size=1]自定义文字[/size][/url]');
assert.equal(tail.normalizeFourD4yPostTailText('x'.repeat(100)).length, 40);
const old = settings.parseFourD4yUserSettings('{"fontScale":1.3}');
assert.equal(old.addPostTail, false, 'existing settings must remain opt-out');
assert.equal(old.fontScale, 1.3);
const restored = settings.parseFourD4yUserSettings(settings.serializeFourD4yUserSettings(enabled));
assert.equal(restored.postTailText, enabled.postTailText);
assert.equal(restored.postTailUrl, '');
assert.equal(restored.addPostTail, true);
const merged = settings.mergeFourD4yUserSettingsChanges(enabled, defaults, { ...defaults, fontScale: 1.3 });
assert.equal(merged.addPostTail, true);
assert.equal(merged.postTailText, enabled.postTailText);
assert.equal(merged.fontScale, 1.3);

// The existing appearance/list helper snapshots must preserve all tail fields.
for (const [file, property, methods] of [
  ['presentation/settings/SettingsPage.ets', 'settings', ['withThemeMode', 'withFontScale',
    'withImageLoadPolicy', 'withQuickForumIds', 'withPostLineSpacing']],
  ['presentation/home/HomePage.ets', 'drawerSettings', ['withDrawerFontScale',
    'withDrawerPostLineSpacing', 'withDrawerThemeMode', 'withForumListSettings']]
]) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const definitions = methods.map(name => {
    const from = source.indexOf('  private ' + name + '(');
    const to = source.indexOf('\n  private ', from + 1);
    assert.ok(from >= 0 && to > from);
    return source.slice(from, to);
  }).join('\n');
  const exports = {};
  vm.runInNewContext(compile('class Page {' + definitions + '} exports.Page = Page;'), { exports });
  const page = new exports.Page(); page[property] = enabled;
  for (const name of methods) {
    const changed = name === 'withForumListSettings' ? page[name](false, []) :
      page[name](name.includes('QuickForum') ? ['2'] : 1);
    assert.equal(changed.addPostTail, true, name);
    assert.equal(changed.postTailText, enabled.postTailText, name);
    assert.equal(changed.postTailUrl, '', name);
  }
}
const reader = fs.readFileSync(path.join(root, 'presentation/thread/ThreadDetailPage.ets'), 'utf8');
const composer = fs.readFileSync(path.join(root, 'presentation/composer/ForumComposerPage.ets'), 'utf8');
assert.match(reader, /pendingReplyDraft = appendFourD4yPostTail\(draft, this\.postTailSettings\)/);
assert.match(composer, /appendFourD4yPostTail\(this\.getOutgoingMessage\(\), this\.postTailSettings,\s*this\.route\.mode === ForumComposerMode\.Edit\)/);
for (const file of ['presentation/notice/PrivateMessageDetailPage.ets', 'presentation/notice/PrivateMessageComposePage.ets']) {
  const fullPath = path.join(root, file);
  if (fs.existsSync(fullPath)) assert.doesNotMatch(fs.readFileSync(fullPath, 'utf8'), /appendFourD4yPostTail/);
}
console.log('NG-style post tail: opt-in, bounded plain text/web links, idempotence, quotes, edit exclusion and settings merge passed.');
