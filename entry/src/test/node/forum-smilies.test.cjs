const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const exportsObject = {};
const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/domain/composer/FourD4ySmilies.ets'), 'utf8');
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsObject });
const { getFourD4ySmilies: list, insertFourD4ySmiley: insert } = exportsObject;
assert.deepEqual([0, 1, 2].map(g => list(g).length), [21, 16, 24]);
const all = [0, 1, 2].flatMap(g => Array.from(list(g)));
assert.equal(new Set(all.map(s => s.code)).size, 61);
for (const item of all) {
  assert.match(item.imageUrl, /^https:\/\/www\.4d4y\.com\/forum\/images\/smilies\/(default\/[a-z]+|coolmonkey\/\d{2}|grapeman\/\d{2})\.gif$/);
  assert.equal(insert('中文', 1, 1, item.code).text, '中' + item.code + '文');
}
assert.equal(list(0)[5].code, ':handshake:');
assert.equal(list(1)[15].code, '{:2_56:}');
assert.equal(list(2)[23].code, '{:3_80:}');
assert.equal(list(3).length, 0);
assert.equal(insert('abc', 2, 1, ':)').text, 'a:)c');
assert.equal(insert('abc', -1, -1, ':)').text, 'abc:)');
assert.equal(insert('abc', 999, 999, ':)').text, 'abc:)');
assert.equal(insert('abc', NaN, NaN, ':)').text, 'abc:)');
assert.equal(insert('abc', 0, 3, 'bad').text, 'abc');
const first = insert('前后', 1, 1, ':handshake:');
const second = insert(first.text, first.caret, first.caret, '{:2_41:}');
assert.equal(second.text, '前:handshake:{:2_41:}后');
console.log('Forum smiley groups, wire codes, selected-text replacement and consecutive insertion passed.');
