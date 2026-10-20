const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'domain/search/FourD4ySearchRequest.ets'), 'utf8'), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
} }).outputText, { exports: exportsObject, require: id => {
  if (id === '@kit.ArkTS') return { util: {} };
  return { FourD4ySearchMode: { Author: 'author', Title: 'title', FullText: 'fullText' },
    isFourD4ySearchModeSupported: () => true };
} });
const base = 'https://www.4d4y.com/forum/';
const build = exportsObject.buildFourD4yAuthorIdSearchRequestUrl;
assert.equal(build(base, '752784', 'all'),
  base + 'search.php?srchfid=all&srchfrom=0&searchsubmit=yes&srchuid=752784');
assert.equal(new URL(build(base, '752784', '53')).searchParams.get('srchfid'), '53');
for (const bad of ['', '0', '12&srchuid=99', 'name', '-1']) assert.equal(build(base, bad, 'all'), null);
assert.equal(build('https://example.com/', '752784', 'all'), null);
assert.equal(build(base, '752784', '53&srchuid=99'), null);
assert.equal(exportsObject.buildFourD4ySearchRequestUrl(base, { hasAuthorIdField: true },
  'author', '752784', 'all'), build(base, '752784', 'all'));
const page = fs.readFileSync(path.join(root, 'presentation/search/SearchPage.ets'), 'utf8');
const start = page.indexOf('    const searchUrl: string | null =');
const end = page.indexOf('    if (searchUrl === null)', start);
const choice = ts.transpileModule('function choose() {' + page.slice(start, end) +
  'return searchUrl; } exports.choose = choose;', { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText;
const chosen = {};
vm.runInNewContext(choice, { exports: chosen,
  FourD4ySearchMode: { Author: 'author' }, FourD4ySession: { forumRoot: base },
  normalizedKeyword: '752784',
  buildFourD4yAuthorIdSearchRequestUrl: build,
  buildFourD4ySearchRequestUrl: () => 'generic' });
const state = { selectedMode: 'author', profileSearchUserId: '752784', selectedForumId: 'all',
  searchForm: { hasAuthorIdField: false, hasAuthorNameField: true } };
assert.equal(chosen.choose.call(state), build(base, '752784', 'all'),
  'profile UID cannot fall through to username when the form omits srchuid');
assert.equal(chosen.choose.call({ ...state, profileSearchUserId: '99' }), 'generic',
  'editing the keyword must not keep searching the original profile');
assert.equal(chosen.choose.call({ ...state, selectedMode: 'title' }), 'generic');
console.log('PASS: exact profile UID, form-independent routing, forum scope and edited search boundaries.');
