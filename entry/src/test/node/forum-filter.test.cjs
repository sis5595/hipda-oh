// Execute production navigation extraction; synthetic nodes only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(name) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/domain/reader/' + name + '.ets'), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports });
  return exports;
}
const filter = load('FourD4yForumFilter');
const contracts = load('FourD4yReaderContracts');
const knownTypes = [{value:'1',label:'A'},{value:'2',label:'B'},{value:'3',label:'C'}];
assert.deepEqual(Array.from(filter.retainSelectedFourD4yForumType([knownTypes[0],knownTypes[2]], knownTypes, '2')),
  knownTypes, 'plain-text current category must remain selectable and checked in its old position');
assert.equal(filter.retainSelectedFourD4yForumType(knownTypes, knownTypes, '2').length,3);
assert.equal(filter.retainSelectedFourD4yForumType([], knownTypes, '').length,0);
assert.equal(filter.retainSelectedFourD4yForumType([], knownTypes, '999').length,0);
assert.equal(filter.retainSelectedFourD4yForumType([], [], '2').length,0, 'no invented cross-board category');
const base = 'https://www.4d4y.com/forum/forumdisplay.php?fid=6&page=1&oh_load=12';
const node = (href, textContent = 'Synthetic category') => ({ textContent, getAttribute: () => href });
function extract(url, categories = [], pages = []) {
  return vm.runInNewContext(`const currentFid = new URL(location.href).searchParams.get('fid');
    const toText = n => n.textContent;
    ${filter.buildFourD4yForumNavigationScript()}
    ({ types: threadTypes, type: filterTypeId, pages: pages.map(linkedBoardPage) });`, {
    URL, location: { href: url }, document: { querySelectorAll: () => categories }, pages
  });
}
assert.equal(filter.buildFourD4yForumFilterQuery('6', '27'), '&filter=type&typeid=27');
for (const board of ['2', '51', '62', '6&fid=2']) {
  assert.equal(filter.buildFourD4yForumFilterQuery(board, '27'), '');
}
for (const value of ['', '0', '01', '-2', '1&fid=2', '1.5']) {
  assert.equal(filter.buildFourD4yForumFilterQuery('6', value), '');
}
const filtered = base + '&filter=type&typeid=27';
const category = 'forumdisplay.php?fid=6&filter=type&typeid=27';
const result = extract(filtered, [node(category), node(category),
  node('https://evil.test/forum/forumdisplay.php?fid=6&filter=type&typeid=9'),
  node(category.replace('fid=6', 'fid=62')), node(category + '&typeid=9'),
  node(category.replace('forumdisplay.php', 'forumdisplay.php/evil'))], [
  node(category + '&page=2'), node('forumdisplay.php?fid=6&page=3'),
  node(category.replace('27', '9') + '&page=4'),
  node(category + '&page=2&page=3'), node(category + '&page=2bad'),
  node(category + '&orderby=dateline&page=2'), node(category.replace('fid=6', 'fid=62') + '&page=2')
]);
assert.equal(result.types.length, 1);
assert.equal(result.types[0].value, '27', 'do not hard-code NG historical category ids');
assert.equal(result.type, '27');
assert.deepEqual(Array.from(result.pages), [2, 0, 0, 0, 0, 0, 0]);
assert.equal(extract(base, [], [node(category + '&page=2')]).pages[0], 0);
assert.equal(extract(filtered + '&orderby=dateline', [],
  [node(category + '&orderby=dateline&page=2')]).pages[0], 2);
for (const url of [filtered.replace('www.4d4y.com', 'evil.test'), filtered + '&typeid=1',
  filtered + '&oh_load=13', filtered + '&fid=62', filtered + '&page=2']) {
  assert.throws(() => extract(url), /Mismatched/);
}
const payload = { fid: '6', page: 2, loadSequence: 12, filterTypeId: '27' };
assert.equal(contracts.isExpectedForumWebPayload(payload, '6', 2, 12, '27'), true);
for (const values of [['6', 2, 12, ''], ['6', 2, 12, '9'], ['6', 2, 13, '27'], ['2', 2, 12, '27']]) {
  assert.equal(contracts.isExpectedForumWebPayload(payload, ...values), false);
}
// Switching a category must discard old rows/pagination and supersede the old request.
const home = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/home/HomePage.ets'), 'utf8');
const methodStart = home.indexOf('  private selectForumType(');
const method = home.slice(methodStart, home.indexOf('  @Builder', methodStart));
const out = {};
vm.runInNewContext(ts.transpileModule('class Page {' + method + '} exports.Page = Page;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: out });
const page = Object.assign(new out.Page(), { isHomeAlive: true, forums: [{id:'6'}], selectedForumIndex:0,
  selectedForumTypeId:'', selectedForumTypeLabel:'', currentForumThreadTypes:[{value:'27',label:'Synthetic'}],
  threads:[{id:'1'}], currentForumPage:9, nextForumPage:10, isRefreshing:true,
  threadRowVersions: { track: rows => rows } });
let loaded = 0;
page.loadForumPage = (n, append) => { assert.equal(n,1); assert.equal(append,false); loaded++; };
page.selectForumType('999', 'Unknown'); assert.equal(loaded,0);
page.selectForumType('27', 'Synthetic'); assert.equal(loaded,1);
assert.equal(page.threads.length,0); assert.equal(page.currentForumPage,1); assert.equal(page.nextForumPage,0);
page.selectForumType('27', 'Synthetic'); assert.equal(loaded,1);
page.selectForumType('', ''); assert.equal(loaded,2);
page.forums[0].id = '51'; page.selectForumType('27', 'Synthetic'); assert.equal(loaded,2);
// Run the real load step too: a mocked loadForumPage hid a catalog reset bug.
const loadStart = home.indexOf('  private loadForumPage(');
const loadEnd = home.indexOf('  private async readThreadsFromWeb(', loadStart);
const loadExports = {};
vm.runInNewContext(ts.transpileModule('class Page {' + home.slice(loadStart, loadEnd) +
  '} exports.Page = Page;', { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: loadExports, buildFourD4yForumFilterQuery: filter.buildFourD4yForumFilterQuery });
const loadingPage = Object.assign(new loadExports.Page(), {
  isHomeAlive: true, threads: [], currentForumThreadTypes: knownTypes.slice(), selectedForumTypeId: '2',
  forums: [{ id:'6' }], selectedForumIndex: 0, webLoadSequence: 0, isForumWebControllerAttached: false,
  resetTopicPermissionProbe() {}, startForumLoadWatchdog() {}, isCurrentForumPostTimeSorted: () => false
});
loadingPage.loadForumPage(1, false);
assert.equal(loadingPage.currentForumThreadTypes.length, 3, 'selected category needs its previous catalog');
assert.match(loadingPage.forumPageUrl, /filter=type&typeid=2/);
loadingPage.selectedForumTypeId = '';
loadingPage.loadForumPage(1, false);
assert.equal(loadingPage.currentForumThreadTypes.length, 0, 'unfiltered/board/account reload clears old catalog');
console.log('Forum category scope, pagination, request binding and switch reset passed.');
