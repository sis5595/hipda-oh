const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
function extract(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
const lifecycle = extract('  aboutToDisappear()', '  private initializeRoute(');
const code = 'class Reader {' + lifecycle +
  extract('  private cancelPostLayoutAnchor()', '  private armPostLayoutAnchor(') +
  extract('  private closeQuickReply(', '  private openAdvancedReplyComposer(') +
  extract('  private async readReplyPreflightFromWeb()', '  /**\n   * The write path') +
  extract('  private async beginReplySubmission(', '  private startReplySubmissionWatchdog(') +
  extract('  private recoverRejectedReply(', '  private getReplySubmissionScript(') +
  '} exports.Reader = Reader;';
const output = {};
const modes = { Preflight: 'preflight', Submit: 'submit' };
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, { exports: output,
  ReplyWebOperation: modes, QuickReplyMode: { Thread: 'thread', Quote: 'quote' },
  parseReplyPreflightPayload: value => value, isExpectedReplyPreflightPayload: () => true,
  FourD4yUserSettingsStore: { load: async () => ({ addPostTail: false }) },
  FourD4yPageAccessState: { LoginRequired: 'login' } });
function reader() {
  let ready, posts = 0;
  const instance = new output.Reader();
  Object.assign(instance, {
    isThreadPageAlive: true, isReplyComposerVisible: true, isReplySubmitting: false, isReplyPreflightLoading: true,
    replyPreflightSequence: 1, replySubmissionSequence: 1, readingReplyPreflightSequence: -1,
    replyWebOperation: 'submit', pendingReplyDraft: 'test reply', route: { threadId: '123' },
    getReplyPreflightExtractionScript: () => 'preflight', getReplySubmissionScript: () => 'submit',
    startReplySubmissionWatchdog: () => {},
    getUIContext: () => ({ getHostContext: () => ({}) }),
    replyWebController: { runJavaScript: script => {
      if (script === 'submit') { posts++; return Promise.resolve(''); }
      return new Promise(resolve => { ready = resolve; });
    } }
  });
  for (const match of lifecycle.matchAll(/this\.(clear\w+|restore\w+|unsubscribe\w+)\(/g)) {
    instance[match[1]] = () => {};
  }
  instance.clearReplyPreflightWatchdog = () => {};
  instance.restoreQuickReplyKeyboardAvoidMode = () => {};
  return { instance, posts: () => posts, ready: () => ready({ formFound: true, formMethod: 'post',
    messageFieldName: 'message', hasFormhashField: true, hasPosttimeField: true,
    hasWysiwygField: true, hasReplySubmitAction: true }) };
}
(async () => {
  for (const action of ['cancel', 'leave', 'normal']) {
    const test = reader(), page = test.instance;
    const preflight = page.readReplyPreflightFromWeb();
    if (action === 'cancel') page.closeQuickReply(true);
    if (action === 'leave') page.aboutToDisappear();
    test.ready();
    await preflight;
    assert.equal(test.posts(), action === 'normal' ? 1 : 0,
      'a canceled or destroyed reply must never dispatch its late preflight');
  }
  const { instance } = reader();
  instance.isReplySubmitting = true;
  instance.closeQuickReply(true);
  assert.equal(instance.replySubmissionSequence, 1, 'an already dispatched reply still needs its result tracked');
  assert.equal(instance.isReplySubmitting, true, 'closing must not unlock a duplicate submission');
  const rejected = reader();
  rejected.instance.isReplySubmitting = true;
  rejected.instance.replyDraft = 'preserved draft';
  let reloaded;
  rejected.instance.prepareReplyForm = operation => { reloaded = operation; };
  rejected.instance.recoverRejectedReply('synthetic minimum-length rejection');
  assert.equal(reloaded, 'preflight', 'a rejection gets a fresh read-only form, not a submit');
  assert.equal(rejected.instance.isReplySubmitting, false);
  assert.equal(rejected.instance.replyDraft, 'preserved draft');
  assert.equal(rejected.instance.replySubmissionErrorMessage, 'synthetic minimum-length rejection');
  assert.equal(rejected.posts(), 0, 'recovering must not retry a POST automatically');
  const focusExports = {}, callbacks = [];
  const focusCode = 'class FocusReader {' +
    extract('  private onPostContextMenuClosed()', '  /** The route carries only stable ids;') +
    '} exports.FocusReader = FocusReader;';
  vm.runInNewContext(ts.transpileModule(focusCode, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: focusExports, setTimeout: fn => callbacks.push(fn) });
  let focused = 0, resized = 0;
  const focusReader = new focusExports.FocusReader();
  Object.assign(focusReader, { isThreadPageAlive: true, isReplyComposerVisible: true,
    isPostContextMenuVisible: true, replyPreflightSequence: 1, quickReplyInputId: 'synthetic-input',
    setQuickReplyKeyboardAvoidMode: () => resized++, getUIContext: () => ({
      getFocusController: () => ({ requestFocus: () => focused++ })
    }) });
  focusReader.requestQuickReplyFocus(); callbacks.shift()();
  assert.equal(focused, 0, 'the menu child window must finish closing before focusing the reader');
  focusReader.onPostContextMenuClosed(); callbacks.shift()();
  assert.equal(resized, 1); assert.equal(focused, 1);
  focusReader.requestQuickReplyFocus(); focusReader.replyPreflightSequence++;
  callbacks.shift()(); assert.equal(focused, 1, 'a closed/replaced reply cannot steal focus');
  focusReader.isThreadPageAlive = false;
  focusReader.onPostContextMenuClosed();
  assert.equal(resized, 1, 'a destroyed reader must not change keyboard avoidance');
  console.log('Quick reply cancellation and pending-submit lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
