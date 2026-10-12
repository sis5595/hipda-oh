// Exercise the added asynchronous preferences read in the actual preflight methods.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
function method(file, from, to) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const start = source.indexOf(from), end = source.indexOf(to, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
let resolveSettings, rejectSettings, settingsReads;
const exportsObject = {};
vm.runInNewContext(ts.transpileModule('class Reader {' +
  method('presentation/thread/ThreadDetailPage.ets', '  private async readReplyPreflightFromWeb()',
    '  /**\n   * The write path') + '} class Composer {' +
  method('presentation/composer/ForumComposerPage.ets', '  private async readPreflightFromWeb()',
    '  private supportsImageUpload(') + '} exports.Reader=Reader; exports.Composer=Composer;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exportsObject,
  FourD4yUserSettingsStore: { load: () => { settingsReads++; return new Promise((resolve, reject) => {
    resolveSettings = resolve; rejectSettings = reject;
  }); } },
  parseReplyPreflightPayload: payload => payload, isExpectedReplyPreflightPayload: () => true,
  parseFourD4yComposerPreflightPayload: payload => payload, isExpectedFourD4yComposerPreflight: () => true,
  isReadyFourD4yComposerForm: () => true,
  FourD4yPageAccessState: { LoginRequired: 'loginRequired' },
  ForumComposerMode: { Edit: 'edit', Quote: 'quote' },
  ReplyWebOperation: { Submit: 'submit' }, ComposerWebOperation: { Submit: 'submit' }
});
const payload = { accessState: 'available', hasChallenge: false, formFound: true,
  formMethod: 'post', messageFieldName: 'message', hasFormhashField: true,
  hasPosttimeField: true, hasWysiwygField: true, hasReplySubmitAction: true,
  categoryOptions: [{ value: '0', label: 'synthetic category' }], viewerUserId: '101',
  subjectFieldName: '', categoryFieldName: '', tagsFieldName: '', categoryValue: '0' };
const settings = { addPostTail: true, postTailText: 'synthetic tail', postTailUrl: '' };
async function run(kind, action) {
  settingsReads = 0;
  let failures = 0, writes = 0;
  const quick = kind === 'reader';
  const instance = new exportsObject[quick ? 'Reader' : 'Composer']();
  Object.assign(instance, { route: { mode: 'reply', threadId: '123' },
    isThreadPageAlive: true, isReplyComposerVisible: true, isComposerRouteReady: true,
    replyPreflightSequence: 1, formSequence: 1, readingReplyPreflightSequence: -1,
    readingPreflightSequence: -1, isReplyPreflightLoading: true, isPreflightLoading: true,
    isReplyFormReady: false, isFormReady: false, replyWebOperation: 'preflight', webOperation: 'preflight',
    getUIContext: () => ({ getHostContext: () => ({}) }),
    getReplyPreflightExtractionScript: () => 'read-only', getPreflightExtractionScript: () => 'read-only',
    replyWebController: { runJavaScript: async () => payload },
    webController: { runJavaScript: async () => payload },
    clearReplyPreflightWatchdog: () => {}, clearFormWatchdog: () => {},
    supportsImageUpload: () => false, hasCategoryOption: () => true,
    failReplyPreflight: () => failures++, failPreflight: () => failures++,
    beginReplySubmission: () => writes++, beginSubmission: () => writes++ });
  const pending = quick ? instance.readReplyPreflightFromWeb() : instance.readPreflightFromWeb();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(settingsReads, 1);
  assert.equal(instance[quick ? 'isReplyFormReady' : 'isFormReady'], false);
  if (action === 'cancel') { instance.isReplyComposerVisible = false; instance.isComposerRouteReady = false; }
  if (action === 'leave') { instance.isThreadPageAlive = false; instance.isComposerRouteReady = false; }
  if (action === 'reload') { instance.replyPreflightSequence++; instance.formSequence++; }
  if (action === 'timeout') { instance.isReplyPreflightLoading = false; instance.isPreflightLoading = false; }
  if (action === 'read-failure') rejectSettings(new Error('synthetic preferences failure'));
  else resolveSettings(settings);
  await pending;
  assert.equal(instance[quick ? 'isReplyFormReady' : 'isFormReady'], action === 'normal', kind + '/' + action);
  assert.equal(instance.postTailSettings, action === 'normal' ? settings : undefined);
  assert.equal(failures, action === 'read-failure' ? 1 : 0);
  assert.equal(writes, 0, 'preferences/preflight must never submit a forum form');
}
(async () => {
  for (const kind of ['reader', 'composer']) {
    for (const action of ['normal', 'cancel', 'leave', 'reload', 'timeout', 'read-failure']) await run(kind, action);
  }
  console.log('Tail preferences preflight: disabled until loaded; cancellation, timeout, stale reads and failures never send.');
})().catch(error => { console.error(error); process.exitCode = 1; });
