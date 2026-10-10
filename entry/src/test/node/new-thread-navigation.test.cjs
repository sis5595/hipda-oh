const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const read = name => fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/' + name), 'utf8');
function extract(source, start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
const exported = {};
const route = read('composer/ForumComposerRouteState.ets');
const composer = read('composer/ForumComposerPage.ets');
const home = read('home/HomePage.ets');
const code = extract(route, 'export function createForumComposerThreadPublishedResult(',
  'export function createForumComposerReplyPublishedResult(') +
  '\nclass Editor {' + extract(composer, '  private async readSubmissionResult()', '  private hasCategoryOption(') +
  '} class Home {' + extract(home, '  private onNewThreadComposerReturned(', '  private onConfirmedThreadDeletion(') +
  '} exports.Editor = Editor; exports.Home = Home;';
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
}}).outputText, { exports: exported, ForumComposerMode: { NewThread: 'newThread', Reply: 'reply', Quote: 'quote', Edit: 'edit' },
  parseFourD4yComposerSubmissionPayload: JSON.parse,
  isExpectedFourD4yComposerSubmission: (value, _route, seq) => value.sequence === seq,
  createThreadRouteParams: (id, title, _replies, _page, _floor, fid) => ({ id, title, fid }) });
(async () => {
  for (const scenario of ['success', 'rejected', 'stale', 'closed']) {
    const editor = new exported.Editor(); let pops = 0;
    Object.assign(editor, { submissionSequence: 1, readingSubmissionSequence: 0,
      isSubmitting: true, isFormReady: true, pendingSubject: 'synthetic title',
      route: { mode: 'newThread', forumId: '51' }, getSubmissionResultScript: () => '',
      clearFormWatchdog: () => {}, failSubmission: () => {}, recoverFromRejectedSubmission: () => {},
      webController: { runJavaScript: async () => {
        if (scenario === 'stale') editor.submissionSequence++;
        if (scenario === 'closed') editor.isSubmitting = false;
        return JSON.stringify({ sequence: 1, succeeded: scenario !== 'rejected', createdThreadId: '123', errorMessage: '' });
      } }, pathStack: { pushPathByName: () => assert.fail('do not leave a submitted editor under the reader'),
        pop: result => {
          assert.equal(result.kind, 'threadPublished'); assert.equal(result.threadId, '123');
          assert.equal(result.forumId, '51'); pops++;
        } } });
    await editor.readSubmissionResult();
    assert.equal(pops, scenario === 'success' ? 1 : 0);
  }
  for (const scenario of ['success', 'cancel', 'foreign-board', 'stale-account', 'closed', 'bad-id']) {
    const home = new exported.Home(); const actions = [];
    Object.assign(home, { isHomeAlive: scenario !== 'closed', selectedForumIndex: 0,
      forums: [{ id: '51' }], accountState: { getSessionGeneration: () => scenario === 'stale-account' ? 2 : 1 },
      loadForumPage: page => actions.push('refresh:' + page),
      pathStack: { pushPathByName: (name, params) => { assert.equal(params.id, '123'); actions.push(name); } } });
    const result = scenario === 'cancel' ? undefined : exported.createForumComposerThreadPublishedResult(
      scenario === 'bad-id' ? 'bad' : '123', scenario === 'foreign-board' ? '6' : '51', 'synthetic');
    home.onNewThreadComposerReturned({ result }, '51', 1);
    assert.deepEqual(actions, scenario === 'success' ? ['refresh:1', 'ThreadDetail'] : []);
  }
  console.log('New-topic confirmed navigation, editor removal and board/account isolation passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
