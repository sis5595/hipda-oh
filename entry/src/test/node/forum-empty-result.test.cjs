// Structural fixture from Joggler / type 19 / page 2, 2026-10-09. No page HTML or session data.
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
  }}).outputText, { exports });
  return exports;
}
const filter = load('FourD4yForumFilter'), contracts = load('FourD4yReaderContracts');
const head = { textContent: '类型 主题 作者/时间 回复 查看 最后发表' };
function table() {
  return { tagName: 'TABLE', classList: { contains: name => name === 'datatable' },
    parentElement: { id: 'moderate' }, children: [head], rows: [head],
    querySelector: selector => selector === 'thead.colplural' ? head : null };
}
function extract(element) {
  return vm.runInNewContext(filter.buildFourD4yEmptyForumScript() + 'hasEmptyForumTable;', {
    currentFid: '62', toText: node => node.textContent,
    document: { getElementById: id => id === 'forum_62' ? element : null }
  });
}
assert.equal(extract(table()), true);
assert.equal(extract(null), false);
for (const mutate of [t => t.children.push({}), t => t.rows.push({}),
  t => t.parentElement.id = 'different', t => t.tagName = 'DIV',
  t => t.querySelector = () => ({ textContent: '登录失败' }),
  t => t.classList.contains = () => false]) {
  const t = table(); mutate(t); assert.equal(extract(t), false);
}
const payload = { fid: '62', page: 2, nextPage: 0, loadSequence: 1, layout: 'legacy-empty',
  threadLinkCount: 0, forumRowCount: 0, hasEmptyForumTable: true,
  accessState: 'available', hasChallenge: false, threadTypes: [], threads: [] };
assert.ok(contracts.parseForumWebPayload(JSON.stringify(payload)));
assert.equal(contracts.getForumReaderOutcome(payload), 'content');
for (const change of [{ hasEmptyForumTable: undefined }, { hasEmptyForumTable: false },
  { layout: 'unrecognized' }, { threadLinkCount: 1 }, { forumRowCount: 1 }, { nextPage: 3 }]) {
  assert.equal(contracts.getForumReaderOutcome({ ...payload, ...change }), 'unsupportedLayout');
}
assert.equal(contracts.getForumReaderOutcome({ ...payload, hasChallenge: true }), 'verificationRequired');
assert.equal(contracts.getForumReaderOutcome({ ...payload, accessState: 'loginRequired' }), 'loginRequired');
assert.equal(contracts.parseForumWebPayload(JSON.stringify({ ...payload, hasEmptyForumTable: 'true' })), null);
console.log('Real header-only forum template accepted; blank, partial, login, challenge and contradictory results rejected.');
