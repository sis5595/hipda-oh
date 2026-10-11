// Synthetic 4D4Y form + Discuz simulateSelect. No network or real credentials.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/login/FourD4yLoginPresentation.ets'), 'utf8');
const exportsForTest = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsForTest });
const script = exportsForTest.buildFourD4yLoginPresentationScript();
function fixture({ simulated = true, challenge = false, target, method = 'post', malformed = false } = {}) {
  const ids = new Map();
  function node() {
    return { attributes: {}, children: [], textContent: '', setAttribute(k, v) { this.attributes[k] = v; },
      getAttribute(k) { return this.attributes[k] || ''; }, appendChild(child) {
        this.children.push(child); if (child.id) ids.set(child.id, child);
      }, replaceChildren() { this.children = []; } };
  }
  const body = node(), layer = node(), form = node(), head = node();
  layer.parentElement = body; form.parentElement = layer;
  form.attributes = { method, action: target || 'logging.php?action=login&loginsubmit=yes' };
  let submissions = 0;
  form.onsubmit = () => submissions++;
  const username = node(), password = node(), answer = node();
  for (const input of [username, password, answer]) {
    Object.defineProperty(input, 'value', { get() { throw new Error('must NEVER read a credential'); },
      set() { throw new Error('must NEVER rewrite a credential'); } });
  }
  const question = node(), loginfield = node(), remember = node(), submit = node(), hash = node();
  Object.defineProperty(hash, 'value', { get() { throw new Error('must NEVER read a form token'); } });
  question.value = '0';
  question.options = simulated ? [{ value: '0', textContent: '' }] : Array.from({ length: 8 }, (_, i) => ({
    value: String(i), textContent: 'Synthetic question ' + i
  }));
  const fields = new Map([
    ['input[name="username"][type="text"]', username],
    ['input[name="password"][type="password"]#password3', password],
    ['select[name="questionid"]#questionid', question],
    ['input[name="answer"][type="text"]#answer', answer],
    ['button[name="loginsubmit"][type="submit"]', submit],
    ['select[name="loginfield"]', loginfield],
    ['input[name="cookietime"][type="checkbox"]', remember],
    ['input[name="formhash"][type="hidden"]', hash]
  ]);
  form.querySelector = s => fields.get(s) || null;
  if (simulated) ids.set('questionid_ctrl_menu', { querySelectorAll: () =>
    Array.from({ length: malformed ? 7 : 8 }, (_, i) => ({ k_value: String(i), textContent: 'Synthetic question ' + i })) });
  const message = node(); message.textContent = '用户登录'; ids.set('returnmessage', message);
  const document = { body, head, createElement: node, getElementById: id => ids.get(id) || null,
    querySelector: s => s === 'form#loginform' ? form : s.includes('challenge-form') && challenge ? node() : null };
  const run = (page = 'https://www.4d4y.com/forum/logging.php?action=login') => vm.runInNewContext(script, {
    document, location: new URL(page), URL
  });
  return { run, form, fields, question, submit, message, ids, head, remember,
    submissions: () => submissions };
}
for (const simulated of [false, true]) {
  const f = fixture({ simulated });
  const handler = f.form.onsubmit, fields = [...f.fields.values()];
  assert.equal(f.run(), 'compact');
  assert.equal(f.question.children.length, 8);
  assert.equal(f.question.children[0].textContent, '无安全提问');
  assert.equal(f.question.value, '0');
  assert.equal(f.remember.checked, true);
  assert.equal(f.submissions(), 0, 'presentation never submits or retries login');
  assert.equal(f.form.onsubmit, handler, 'forum password hashing / AJAX handler is preserved');
  assert.deepEqual([...f.fields.values()], fields, 'inputs, submit and hidden token are not replaced');
  assert.equal(f.message.textContent, '', 'keep original error target; only remove its initial title');
  const count = f.head.children.length;
  assert.equal(f.run(), 'compact'); assert.equal(f.head.children.length, count, 'idempotent');
}
for (const config of [{ method: 'get' }, { challenge: true }, { malformed: true },
  { target: 'https://example.com/forum/logging.php?action=login&loginsubmit=yes' },
  { target: 'logging.php?action=logout&loginsubmit=yes' }, { target: 'logging.php?action=login' }]) {
  const f = fixture(config); assert.equal(f.run(), 'website');
  assert.equal(f.head.children.length, 0, 'unknown/security forms are never hidden');
  assert.equal(f.submissions(), 0);
}
for (const page of ['http://www.4d4y.com/forum/logging.php?action=login',
  'https://example.com/forum/logging.php?action=login',
  'https://www.4d4y.com/forum/index.php', 'https://www.4d4y.com/forum/logging.php?action=logout']) {
  assert.equal(fixture().run(page), 'website');
}
const missing = fixture(); missing.fields.delete('input[name="formhash"][type="hidden"]');
assert.equal(missing.run(), 'website');
console.log('NG login presentation: trusted target, original form, no credential access, questions and fallback passed.');
