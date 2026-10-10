const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const start = source.indexOf('  private cancelPostLayoutAnchor()');
const end = source.indexOf('  private consumePendingPostIndex()', start);
assert.ok(start >= 0 && end > start, 'production layout anchor methods must exist');
const exportsObject = {}, tasks = [], scrolls = [];
vm.runInNewContext(ts.transpileModule('class Reader {' + source.slice(start, end) +
  '} exports.Reader = Reader;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, {
  exports: exportsObject, setTimeout: callback => tasks.push(callback), console,
  ScrollAlign: { START: 'start' }
});
function make() {
  return Object.assign(new exportsObject.Reader(), {
    postLayoutAnchorIndex: -1, postLayoutAnchorRevision: 0, postLayoutAnchorQueued: false,
    isThreadPageAlive: true, webLoadSequence: 1, posts: [{ id: 'a' }, { id: 'b' }, { id: 'c' }],
    postListScroller: { scrollToIndex: index => scrolls.push(index) }
  });
}
for (const scenario of ['normal', 'touch', 'leave', 'reload', 'new-target']) {
  tasks.length = 0; scrolls.length = 0;
  const reader = make(); reader.armPostLayoutAnchor(2);
  reader.onPostLayoutSizeChanged('a'); reader.onPostLayoutSizeChanged('b');
  assert.equal(tasks.length, 1, 'one layout pass coalesces corrections');
  if (scenario === 'touch') reader.cancelPostLayoutAnchor();
  if (scenario === 'leave') reader.isThreadPageAlive = false;
  if (scenario === 'reload') reader.webLoadSequence++;
  if (scenario === 'new-target') reader.armPostLayoutAnchor(1);
  tasks.shift()();
  assert.deepEqual(scrolls, scenario === 'normal' ? [2] : []);
  if (scenario === 'normal') {
    reader.onPostLayoutSizeChanged('a'); tasks.shift()();
    assert.deepEqual(scrolls, [2, 2], 'later image expansion must retain target');
    reader.cancelPostLayoutAnchor(); reader.onPostLayoutSizeChanged('a');
    assert.equal(tasks.length, 0, 'never pull the reader back after interaction');
  }
}
const reader = make(); reader.armPostLayoutAnchor(1);
tasks.length = 0;
reader.onPostLayoutSizeChanged('c'); reader.onPostLayoutSizeChanged('missing');
assert.equal(tasks.length, 0, 'unrelated/later rows cannot affect target start');
assert.match(source, /\.onSizeChange\([\s\S]*?onPostLayoutSizeChanged\(post.id\)/);
assert.match(source, /\.onTouch\([\s\S]*?TouchType.Down[\s\S]*?cancelPostLayoutAnchor\(\)/);
assert.doesNotMatch(source, /ReaderPositionAudit/);
console.log('PASS: image layout anchoring, coalescing and user/page/target cancellation.');
