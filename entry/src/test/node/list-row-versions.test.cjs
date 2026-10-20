const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets/presentation');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'common/FourD4yRowVersions.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsObject });
const RowVersions = exportsObject.FourD4yRowVersions;
const rows = new RowVersions(item => item.id);
const original = [{ id: '1', count: 2 }, { id: '2', count: 3 }];
assert.equal(rows.track(original), original);
const keys = original.map(item => rows.key(item));
const equal = original.map(item => ({ ...item }));
rows.track(equal);
assert.deepEqual(equal.map(item => rows.key(item)), keys, 'equal server DTOs must not redraw rows');
const changed = [{ id: '1', count: 1 }, { id: '2', count: 3 }];
rows.track(changed);
assert.notEqual(rows.key(changed[0]), keys[0], 'decremented counts must replace stale rendered rows');
assert.equal(rows.key(changed[1]), keys[1]);
const reordered = [changed[1], changed[0], { id: '3', count: 0 }];
const changedKey = rows.key(changed[0]);
rows.track(reordered);
assert.equal(rows.key(reordered[0]), keys[1], 'reordering is not a content change');
assert.equal(rows.key(reordered[1]), changedKey);
rows.track([reordered[2]]);
assert.equal(rows.rows.size, 1, 'previous page snapshots must not accumulate');
rows.track(original);
assert.notEqual(rows.key(original[1]), keys[1], 'removed/reintroduced rows get new instances');
rows.track([]);
assert.equal(rows.rows.size, 0);

// Simulate ForEach's retained builders using keys from the production class.
// Only the changed row should be rebuilt when a response replaces all DTOs.
for (const [before, after] of [
  [{ id: 'post', content: [{ kind: 'text', value: 'before' }] },
    { id: 'post', content: [{ kind: 'text', value: 'after' }] }],
  [{ id: 'pm', isUnread: true, isMine: false }, { id: 'pm', isUnread: false, isMine: false }],
  [{ id: 'pm', isUnread: false, isMine: false }, { id: 'pm', isUnread: false, isMine: true }],
  [{ id: 'notice:1', postId: '88' }, { id: 'notice:1', postId: '99' }]
]) {
  const state = new RowVersions(item => item.id), builders = new Map();
  const render = items => state.track(items).map(item => {
    const key = state.key(item);
    if (!builders.has(key)) builders.set(key, JSON.stringify(item));
    return builders.get(key);
  });
  render([before]);
  assert.equal(render([after])[0], JSON.stringify(after));
  assert.equal(builders.size, 2);
  assert.ok(!state.key(after).includes('after'), 'keys contain IDs and versions, never private body text');
}
for (const [file, state, value] of [
  ['home/HomePage.ets', 'threadRowVersions', 'thread'],
  ['thread/ThreadDetailPage.ets', 'postRowVersions', 'post'],
  ['notice/PrivateMessageDetailPage.ets', 'messageRowVersions', 'message'],
  ['notice/MessageCenterPage.ets', 'noticeRowVersions', 'item']
]) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  assert.ok(source.includes(`this.${state}.track(`), file + ' must publish tracked snapshots');
  assert.ok(source.includes(`this.${state}.key(${value})`), file + ' must bind the ForEach key');
}
console.log('PASS: selective row invalidation, stable unchanged rows, nested content, order and bounded lifetime.');
