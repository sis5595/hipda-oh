// Execute generated production scripts against synthetic DOM only; never vote online.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const start = source.indexOf('  private getVotePreflightExtractionScript(');
const end = source.indexOf('  private async readThreadFromWeb()', start);
assert.ok(start >= 0 && end > start);
const output = {};
vm.runInNewContext(ts.transpileModule('class Scripts {' + source.slice(start, end) +
  '} exports.Scripts = Scripts;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: output });
const scripts = new output.Scripts();
const root = 'https://www.4d4y.com/forum/';
function fixture(action = 'misc.php?action=votepoll&tid=123&pollsubmit=yes',
  href = root + 'viewthread.php?tid=123') {
  let submissions = 0;
  const button = { disabled: true, getAttribute: () => null };
  const inputs = ['1', '5'].map(value => ({ checked: false, type: 'checkbox',
    click() { this.checked = !this.checked; button.disabled = false; },
    getAttribute: name => name === 'value' ? value : name === 'type' ? 'checkbox' : '' }));
  const form = {
    method: 'post', getAttribute: name => name === 'action' ? action : '',
    querySelector: selector => selector === 'input[name=formhash]' ? {} :
      selector.includes('pollinfo') ? { textContent: '最多可选 2 项' } : button,
    querySelectorAll: selector => selector.includes('pollanswers') ? inputs : [{}, {}],
    requestSubmit: target => { assert.equal(target, button); submissions++; }
  };
  const document = { documentElement: { innerHTML: '' },
    querySelector: selector => selector === 'form#poll' ? form : null };
  return { context: { document, location: { href }, URL, Set }, form, button, inputs, get submissions() { return submissions; } };
}
function run(kind, fixture) {
  const script = kind === 'preflight' ? scripts.getVotePreflightExtractionScript('123', 7) :
    kind === 'submit' ? scripts.getVoteSubmissionScript('123', 9, ['1', '5']) :
      scripts.getVoteVerificationScript('123', 9);
  return JSON.parse(vm.runInNewContext(script, fixture.context));
}
for (const action of [
  'https://other.invalid/forum/misc.php?action=votepoll&tid=123&pollsubmit=yes',
  'misc.php?action=votepoll&tid=999&pollsubmit=yes',
  'misc.php?action=votepoll&pollsubmit=yes',
  'misc.php?action=votepoll&tid=123&tid=999&pollsubmit=yes',
  'misc.php?action=votepoll&action=other&tid=123&pollsubmit=yes',
  'misc.php?action=votepoll&tid=123&pollsubmit=yes&pollsubmit=no',
  'https://user:pass@www.4d4y.com/forum/misc.php?action=votepoll&tid=123&pollsubmit=yes'
]) {
  const bad = fixture(action);
  assert.equal(run('submit', bad).started, false, 'reject ambiguous/wrong vote destination: ' + action);
  assert.equal(bad.submissions, 0);
  assert.equal(run('preflight', bad).hasPollSubmitAction, false);
  assert.equal(run('verify', bad).pollFound, false, 'malformed voting form is not a results-only poll');
}
for (const href of [
  'https://other.invalid/forum/viewthread.php?tid=123',
  root + 'viewthread.php.evil?tid=123',
  root + 'viewthread.php?tid=123&tid=999'
]) {
  const bad = fixture(undefined, href);
  assert.equal(run('submit', bad).started, false);
  assert.equal(run('preflight', bad).formFound, false);
  assert.equal(run('verify', bad).pollFound, false);
  assert.equal(bad.submissions, 0);
}
const valid = fixture();
assert.equal(run('preflight', valid).hasPollSubmitAction, true);
assert.equal(valid.button.disabled, true, 'fresh form normally disables submit before selection');
assert.equal(run('submit', valid).started, true);
assert.equal(valid.submissions, 1);
assert.equal(run('verify', valid).voteFormAvailable, true);
const blocked = fixture();
blocked.inputs.forEach(input => { input.click = function () { this.checked = true; }; });
assert.equal(run('submit', blocked).started, false, 'do not forcibly enable a server-disabled submitter');
assert.equal(blocked.submissions, 0);
const absolute = fixture(root + 'misc.php?action=votepoll&tid=123&pollsubmit=yes');
assert.equal(run('submit', absolute).started, true);
const malformed = fixture();
malformed.form.method = 'get';
assert.equal(run('verify', malformed).pollFound, false, 'broken method cannot masquerade as success');
assert.equal(run('submit', malformed).started, false);
for (const overrides of [
  { formaction: 'https://other.invalid/forum/misc.php?action=votepoll&tid=123&pollsubmit=yes' },
  { formaction: 'misc.php?action=votepoll&tid=999&pollsubmit=yes' },
  { formaction: '' }, { formmethod: 'get' }
]) {
  const override = fixture();
  override.button.getAttribute = name => overrides[name] ?? null;
  assert.equal(run('preflight', override).hasPollSubmitAction, false);
  assert.equal(run('submit', override).started, false);
  assert.equal(override.submissions, 0, 'submitter overrides must not bypass the form destination');
}
const resultOnly = fixture();
resultOnly.form.querySelectorAll = selector => selector.includes('pollanswers') ? [] : [{}, {}];
const result = run('verify', resultOnly);
assert.equal(result.pollFound, true);
assert.equal(result.voteFormAvailable, false);
assert.equal(result.resultRowCount, 2, 'legitimate results-only rows remain available');
console.log('Poll script origin, exact destination and malformed-result boundaries passed.');
