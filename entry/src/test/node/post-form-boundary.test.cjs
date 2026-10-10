const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const compile = code => ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText;
const boundary = {};
vm.runInNewContext(compile(fs.readFileSync(path.join(root, 'domain/composer/FourD4yPostFormBoundary.ets'), 'utf8')),
  { exports: boundary });
function method(file, begin, end) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const start = text.indexOf(begin), stop = text.indexOf(end, start);
  assert.ok(start >= 0 && stop > start);
  return text.slice(start, stop);
}
const output = {};
vm.runInNewContext(compile('class Writer {' +
  method('presentation/thread/ThreadDetailPage.ets', '  private getReplySubmissionScript(',
    '  private getReplySubmissionResultScript(') +
  method('presentation/composer/ForumComposerPage.ets', '  private getSubmissionScript(',
    '  private getSubmissionResultScript(') + '} exports.Writer = Writer;'),
  { exports: output, ...boundary, ForumComposerMode: { NewThread:'newThread', Edit:'edit', Quote:'quote' } });
function environment(mode = 'reply', changes = {}) {
  const action = mode === 'edit' ? 'edit' : 'reply';
  const suffix = mode === 'edit' ? '&pid=456' : '';
  const marker = mode === 'quick' ? 'oh_reply_prepare' : 'oh_compose';
  const pageUrl = 'https://www.4d4y.com/forum/post.php?action=' + action + '&tid=123' + suffix + '&' + marker + '=12';
  let submissions = [];
  const field = (name, value) => ({ name, value, type:'hidden', getAttribute(key) { return this[key] || ''; },
    remove() { form.fields = form.fields.filter(item => item !== this); } });
  const message = field('message', '[quote]synthetic quote[/quote]');
  const form = { method: 'post', fields: [field('tid','123'), field('pid','456'), field('formhash','synthetic-token'),
    field('posttime','1'), field('wysiwyg','0'), field('attachnew[][description]','999'), field('attachdel[]','888'),
    field('Filedata','unused')],
    getAttribute(name) { return name === 'action' ? (changes.target || pageUrl.split('&' + marker)[0]) : this[name] || ''; },
    querySelector(selector) {
      if (selector.includes('textarea')) return message;
      if (selector.includes('name=formhash')) return this.fields.find(item => item.name === 'formhash');
      if (selector.includes('submit')) return { value:'yes', getAttribute: () => action === 'edit' ? 'editsubmit':'replysubmit' };
      return null;
    }, querySelectorAll: function(selector) { return selector === 'input[name]' ? this.fields : []; },
    appendChild: function(child) { this.fields.push(child); }
  };
  if (changes.bodyTid) form.fields[0].value = changes.bodyTid;
  if (changes.noToken) form.fields = form.fields.filter(item => item.name !== 'formhash');
  if (changes.method) form.method = changes.method;
  const globals = { URL, window:{}, location:{href: changes.page || pageUrl},
    document: { forms:[form], querySelectorAll: () => [],
      createElement: tag => tag === 'form' ? { fields:[], style:{}, appendChild: function(child) { this.fields.push(child); } } : field('', ''),
      body:{appendChild: () => {}} },
    FormData: class { constructor(value) { this.form = value; } entries() {
      return this.form.fields.map(item => [item.name,item.value]).concat([['message', message.value]]);
    } },
    HTMLFormElement:{prototype:{submit: function() { submissions.push(this); }}}
  };
  const writer = Object.assign(new output.Writer(), { route:{ mode, threadId:'123', postId:'456' },
    replyPreflightSequence:12, formSequence:12, categoryFieldName:'', tagsFieldName:'' });
  const script = mode === 'quick' ? writer.getReplySubmissionScript('synthetic draft', true) :
    writer.getSubmissionScript('', 'synthetic edited draft', '', '', ['10'], [], ['20'], []);
  return { globals, script, message, form, submissions };
}
for (const mode of ['quick','reply','edit']) {
  const current = environment(mode);
  vm.runInNewContext(current.script, current.globals);
  assert.equal(current.submissions.length,1);
  const fields = current.submissions[0].fields;
  assert.ok(!fields.some(field => field.value === '999' || field.value === '888'), 'old staged uploads/deletions must not leak');
  if (mode === 'quick') {
    assert.ok(!fields.some(field => /^(attachnew|attachdel|Filedata)/i.test(field.name)));
    assert.equal(fields.find(field => field.name === 'message').value, '[quote]synthetic quote[/quote]\n\nsynthetic draft');
  } else {
    assert.ok(fields.some(field => field.name === 'attachnew[][description]' && field.value === '10'));
  }
  assert.throws(() => vm.runInNewContext(current.script, current.globals), /post-document-not-current/);
  assert.equal(current.submissions.length,1,'same document cannot submit twice');
  const baseline = environment(mode);
  const pageUrl = baseline.globals.location.href;
  for (const changes of [
    {page:pageUrl.replace('www.4d4y.com','evil.test')}, {page:pageUrl.replace('tid=123','tid=124')},
    {page:pageUrl.replace(/(oh_compose|oh_reply_prepare)=12/, '$1=123')}, {page:pageUrl+'&tid=123'},
    {target:pageUrl.replace('www.4d4y.com','evil.test')},
    {target:pageUrl.replace('post.php','post.php/extra')}, {target:pageUrl.replace('tid=123','tid=124')},
    {bodyTid:'124'}, {noToken:true}, {method:'get'}
  ]) {
    const rejected = environment(mode, changes);
    assert.throws(() => vm.runInNewContext(rejected.script, rejected.globals), /post-(document-not-current|form-not-ready)/);
    assert.equal(rejected.submissions.length,0);
  }
}
console.log('PASS: quick/advanced/edit actual submit scripts bind document, form and one shot; only selected attachments.');
for (const action of ['reply','edit','newthread']) {
  const current = 'https://www.4d4y.com/forum/post.php?action=' + action + '&tid=123&pid=456&fid=51&oh_compose=12';
  const check = value => boundary.isCurrentFourD4yPostPreflightUrl(value, action, '123', '456', 'oh_compose', 12, '51');
  assert.equal(check(current),true);
  for (const value of [current.replace('oh_compose=12','oh_compose=123'), current + '&oh_compose=12',
    current.replace('www.4d4y.com','evil.test'), current + '#fake', current.replace('post.php','post.php/extra'),
    current.replace(action, 'wrong'), action === 'newthread' ? current.replace('fid=51','fid=52') :
      current.replace('tid=123','tid=124')]) assert.equal(check(value), false);
}
