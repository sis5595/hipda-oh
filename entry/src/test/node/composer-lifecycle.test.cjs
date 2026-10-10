// Execute actual editor methods, with network/UI doubles and deferred preflight.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/composer/ForumComposerPage.ets'), 'utf8');
function method(start, end) {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
let requests = 0;
const code = 'class Editor { ' +
  method('  aboutToDisappear(): void {', '  build() {') +
  method('  private async uploadNativeImage(', '  private buildNativeImageUploadPayload(') +
  method('  private async submitLoadedForm():', '  private async readSubmissionResult():') +
  ' } exports.Editor = Editor;';
const output = {};
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: output, ForumComposerMode: { NewThread: 'newThread' },
  buildFourD4yNewThreadResultReadScript: () => 'read-only-result',
  setTimeout: () => { throw new Error('No late result polling is allowed'); },
  http: { createHttp: () => ({
  request: async () => { requests++; return { result: 'DISCUZUPLOAD|0|123|' }; }, destroy: () => {}
}), RequestMethod: { POST: 'POST' } } });
function editor() {
  const value = new output.Editor();
  Object.assign(value, {
    isComposerRouteReady: true, formSequence: 1, submissionSequence: 1,
    pendingImageUploadSequence: 1, isImageUploading: true, viewerUserId: '5595',
    getDetailedImageUploadContract: async () => ({ userId: '5595', uploadHash: 'synthetic' }),
    getNativeImageUploadCookieHeader: async () => 'synthetic',
    buildNativeImageUploadPayload: () => ({ boundary: 'test', bytes: new ArrayBuffer(0) }),
    getNativeDetailedComposerUrl: () => 'synthetic',
    clearFormWatchdog: () => {}, clearImageUploadHashProbe: () => {},
    clearImageUploadStatusPolling: () => {}, hasAdjustedKeyboardAvoidMode: false
  });
  return value;
}
(async () => {
  let release;
  const first = editor();
  first.getDetailedImageUploadContract = () => new Promise(resolve => { release = resolve; });
  const pending = first.uploadNativeImage({}, 1);
  first.aboutToDisappear();
  release({ userId: '5595', uploadHash: 'synthetic' });
  assert.equal(await pending, '');
  assert.equal(requests, 0, 'closing during preflight must prevent upload POST');
  const second = editor();
  second.getNativeImageUploadCookieHeader = () => new Promise(resolve => { release = resolve; });
  const pendingCookie = second.uploadNativeImage({}, 1);
  await new Promise(resolve => setImmediate(resolve));
  second.aboutToDisappear();
  release('synthetic');
  assert.equal(await pendingCookie, '');
  assert.equal(requests, 0, 'closing during cookie read must prevent upload POST');
  const third = editor();
  third.getDetailedImageUploadContract = async () => ({ userId: '987', uploadHash: 'synthetic' });
  assert.equal(await third.uploadNativeImage({}, 1), '');
  assert.equal(requests, 0, 'foreign account preflight must not upload');
  assert.equal(await editor().uploadNativeImage({}, 1), '123');
  assert.equal(requests, 1);
  for (const reject of [false, true]) {
    const closed = editor();
    closed.route = { mode: 'newThread' };
    closed.isSubmitting = true;
    closed.getSubmissionScript = () => 'single-submit';
    let resume;
    closed.webController = { runJavaScript: () => new Promise((resolve, rejectCall) => {
      resume = () => reject ? rejectCall(new Error('closed')) : resolve('started');
    }) };
    closed.pollNewThreadSubmission = () => { throw new Error('Closed editor must not poll a new sequence'); };
    closed.failSubmission = () => { throw new Error('Closed editor must not report a stale failure'); };
    const sending = closed.submitLoadedForm();
    closed.aboutToDisappear();
    resume();
    await sending;
  }
  const polling = editor();
  polling.isSubmitting = true;
  let resumePoll;
  polling.webController = { runJavaScript: () => new Promise(resolve => { resumePoll = resolve; }) };
  const resultRead = polling.pollNewThreadSubmission(1);
  polling.aboutToDisappear();
  resumePoll('pending');
  await resultRead;
  console.log('Composer lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
