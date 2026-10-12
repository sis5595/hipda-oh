const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const begin = source.indexOf('  private openEditComposer(');
const end = source.indexOf('  private getPostDeletionButtonLabel(', begin);
assert.ok(begin >= 0 && end > begin);
const exported = {};
vm.runInNewContext(ts.transpileModule('class Reader {' + source.slice(begin, end) +
  '} exports.Reader = Reader;', { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exported,
  createEditComposerRouteParams: (tid, pid, title, fid) => ({ threadId: tid, postId: pid, forumId: fid }),
  isForumComposerPostEditedResult: (result, tid, pid) => result &&
    result.kind === 'postEdited' && result.threadId === tid && result.postId === pid });
const reader = new exported.Reader();
Object.assign(reader, { isLoggedIn: true, viewerUserId: '101', currentPage: 1,
  route: { threadId: '123', forumId: '', threadTitle: 'synthetic topic' },
  resolvedTitle: '', pathStack: { pushPathByName: (name, route, callback) => {
    assert.equal(name, 'ForumComposer');
    assert.equal(route.threadId, '123');
    assert.equal(route.postId, '456');
    assert.equal(route.forumId, '');
    reader.onEdited = callback;
  } }, loadPage: page => { reader.reloadedPage = page; } });
const own = { id: '456', authorUserId: '101', authorName: 'synthetic author' };
assert.equal(reader.canEditPost(own), true,
  'notification/search/favorite links with no fid must still expose own-post editing');
assert.equal(reader.canRequestPostDeletion(own), false,
  'deletion keeps its stronger forum-identity contract');
reader.openEditComposer(own);
reader.onEdited({ result: { kind: 'postEdited', threadId: '999', postId: '456' } });
assert.equal(reader.reloadedPage, undefined);
reader.onEdited({ result: { kind: 'postEdited', threadId: '123', postId: '456' } });
assert.equal(reader.reloadedPage, 1);
for (const post of [{ ...own, authorUserId: '202' }, { ...own, authorUserId: undefined },
  { ...own, authorUserId: 'invalid' }, { ...own, id: '' }]) {
  assert.equal(reader.canEditPost(post), false);
}
reader.viewerUserId = '202';
assert.equal(reader.canEditPost(own), false, 'account switching must not inherit editing eligibility');
reader.viewerUserId = '101'; reader.isLoggedIn = false;
assert.equal(reader.canEditPost(own), false);
reader.isLoggedIn = true; reader.route.threadId = '';
assert.equal(reader.canEditPost(own), false);
const composer = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/composer/ForumComposerPage.ets'), 'utf8');
const start = composer.indexOf('  private getPreflightUrl(');
const stop = composer.indexOf('  private isCurrentPreflightRequest(', start);
const out = {};
vm.runInNewContext(ts.transpileModule('class Composer {' + composer.slice(start, stop) +
  '} exports.Composer = Composer;', { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: out, ForumComposerMode: { Edit: 'edit', NewThread: 'newThread', Quote: 'quote' } });
const editor = new out.Composer();
editor.route = { mode: 'edit', threadId: '123', postId: '456', forumId: '' };
let url = new URL(editor.getPreflightUrl(7));
assert.equal(url.searchParams.get('tid'), '123');
assert.equal(url.searchParams.get('pid'), '456');
assert.equal(url.searchParams.has('fid'), false, 'omit unknown fid instead of sending an empty board identity');
editor.route.forumId = '2';
url = new URL(editor.getPreflightUrl(8));
assert.equal(url.searchParams.get('fid'), '2');
console.log('Own-post edit entry: missing fid, account ownership, confirmed return and preflight URL passed.');
