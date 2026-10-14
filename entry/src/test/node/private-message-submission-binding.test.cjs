const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/notice/PrivateMessageDetailPage.ets'), 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end);
}
const methods = ['isCurrentPrivateMessagePreflightRequest', 'isCurrentPrivateMessageDocument',
  'isCurrentPrivateMessageSubmissionRequest', 'handleCompletedPrivateMessageWebLoad',
  'handlePrivateMessageWebError', 'getPrivateMessageSubmissionScript',
  'getPrivateMessageSubmissionResultScript'];
const exportsObject = {};
vm.runInNewContext(ts.transpileModule('class Page {\n' + methods.map(method).join('\n') +
  '\n} exports.Page = Page;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, { exports: exportsObject });
const page = new exportsObject.Page();
let reads = 0, errors = 0;
Object.assign(page, { route: { participantUserId: '2' }, isPrivateMessageRouteReady: true,
  routeSessionGeneration: 4, accountState: { getSessionGeneration: () => 4 },
  privateMessageFormSequence: 1, privateMessageSubmissionSequence: 3, isPrivateMessageSending: true,
  readPrivateMessageSubmissionResult() { reads++; }, failPrivateMessageSubmission() { errors++; }
});
const preflight = 'https://www.4d4y.com/forum/pm.php?daterange=1&uid=2&oh_pm_compose=1';
const submitted = 'https://www.4d4y.com/forum/pm.php?action=send&uid=2&oh_pm_submit=3';
assert.equal(page.isCurrentPrivateMessagePreflightRequest(preflight), true);
for (const url of [preflight.replace('compose=1', 'compose=10'),
  preflight.replace('https://www.4d4y.com', 'https://evil.invalid'), preflight + '&uid=3']) {
  assert.equal(page.isCurrentPrivateMessagePreflightRequest(url), false);
}
for (const url of [preflight, submitted.replace('submit=3', 'submit=30'),
  submitted.replace('uid=2', 'uid=3'), submitted + '&action=send',
  submitted.replace('https://www.4d4y.com', 'https://evil.invalid')]) {
  page.handleCompletedPrivateMessageWebLoad(url);
  page.handlePrivateMessageWebError(url);
}
assert.equal(reads, 0, 'late preflight completion cannot read a submission result');
assert.equal(errors, 0, 'unrelated load failure cannot terminate a submission');
page.handleCompletedPrivateMessageWebLoad(submitted);
assert.equal(reads, 1);
page.routeSessionGeneration = 3;
assert.equal(page.isCurrentPrivateMessageSubmissionRequest(submitted), false);
page.routeSessionGeneration = 4;
const resultScript = page.getPrivateMessageSubmissionResultScript('2', 3);
const successDocument = { querySelector: selector => selector === '.summary' ? {} : null,
  documentElement: { innerHTML: '<div class="summary">synthetic</div>' } };
for (const href of [preflight, submitted.replace('submit=3', 'submit=30'),
  submitted.replace('uid=2', 'uid=3')]) {
  assert.equal(vm.runInNewContext(resultScript, { URL, location: { href }, document: successDocument }), '',
    'old conversation summaries must not manufacture success');
}
assert.equal(JSON.parse(vm.runInNewContext(resultScript,
  { URL, location: { href: submitted }, document: successDocument })).succeeded, true);
let posts = 0;
const fields = { message: { value: '' }, formhash: { value: 'synthetic-only' },
  lastdaterange: { value: 'synthetic' } };
const form = { method: 'post', action: '', getAttribute: () => 'pm.php?action=send&uid=2',
  querySelector(selector) {
    const name = (selector.match(/name=["\\]*([^\]"\\]+)/) || [])[1];
    return fields[name] || null;
  }, appendChild(field) { fields[field.name] = field; } };
const context = { URL, location: { href: preflight }, window: {},
  document: { forms: [form], createElement: () => ({}) },
  HTMLFormElement: { prototype: { submit() { posts++; } } } };
const smileyMessage = 'synthetic message :handshake:{:2_41:}{:3_57:}';
const submitScript = page.getPrivateMessageSubmissionScript('2', smileyMessage);
vm.runInNewContext(submitScript, context);
assert.equal(posts, 1);
assert.equal(fields.message.value, smileyMessage, 'forum smiley codes must survive PM submission unchanged');
assert.equal(new URL(form.action).searchParams.get('oh_pm_submit'), '3');
assert.throws(() => vm.runInNewContext(submitScript, context), /pm-document-not-current/);
assert.equal(posts, 1, 'one document can submit only once');
context.window = {};
context.location.href = preflight.replace('compose=1', 'compose=10');
assert.throws(() => vm.runInNewContext(submitScript, context), /pm-document-not-current/);
assert.equal(posts, 1);
console.log('PASS: PM exact document/target/sequence/account binding and one-shot submission.');
