// Offline protocol regression: no real Cookie, formhash, HTML, or forum writes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const sourceRoot = path.resolve(__dirname, '../../main/ets/domain/composer');

// Exercise production conversion logic with a GBK codec, not a UTF-8 stand-in.
const gbk = new TextDecoder('gbk');
const table = new Map();
for (let byte = 0; byte < 128; byte++) table.set(String.fromCharCode(byte), [byte]);
for (let lead = 0x81; lead <= 0xFE; lead++) {
  for (let trail = 0x40; trail <= 0xFE; trail++) {
    if (trail === 0x7F) continue;
    const character = gbk.decode(Uint8Array.of(lead, trail));
    if (!character.includes('\uFFFD') && !table.has(character)) table.set(character, [lead, trail]);
  }
}
const util = {
  TextEncoder: { create: encoding => {
    assert.equal(encoding, 'gbk');
    return { encodeInto: value => Uint8Array.from([...value].flatMap(c => table.get(c) || [0x3F])) };
  } },
  TextDecoder: { create: encoding => ({ decodeToString: value => new TextDecoder(encoding).decode(value) }) }
};
function load(name, dependencies) {
  const source = fs.readFileSync(path.join(sourceRoot, `${name}.ets`), 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  } }).outputText;
  const exports = {};
  vm.runInNewContext(code, { exports, require: name => {
    assert.ok(name in dependencies, `Unexpected dependency: ${name}`);
    return dependencies[name];
  }, Uint8Array });
  return exports;
}
const encoding = load('FourD4yPostEncoding', { '@ohos.util': util });
assert.equal(encoding.encodeFourD4yPostField('中文 +&😀'), '%D6%D0%CE%C4+%2B%26%26%23128512%3B');
assert.equal(encoding.encodeFourD4yPostField('a\nb'), 'a%0Ab');
assert.equal(encoding.encodeFourD4yPostField(''), '');
const submission = load('FourD4yNewThreadSubmission', { './FourD4yPostEncoding': encoding });
const draft = { forumId: '40', categoryValue: '7', subject: '中文', message: '内容😀', tags: '标签',
  imageIds: ['123', 'not-an-id'], discardedImageIds: ['456'], submissionSequence: 1 };
const script = submission.buildFourD4yNewThreadSubmissionScript(draft);
assert.equal(script.includes('console.'), false);
assert.equal(script.includes('document.cookie'), false);
assert.equal(script.includes('.submit()'), false);
function environment(outcome) {
  const attributes = new Map();
  const requests = [];
  const form = {
    action: 'https://www.4d4y.com/forum/post.php?action=newthread&fid=40&extra=page%3D1', method: 'post',
    querySelector: selector => selector === 'input[name=formhash]' ? { value: '1234abcd' } : {}
  };
  const sandbox = {
    URL, TextDecoder, Date, location: { origin: 'https://www.4d4y.com',
      href: 'https://www.4d4y.com/forum/post.php?action=newthread&fid=40&oh_compose=2' },
    document: { characterSet: 'GBK', forms: [form], documentElement: {
      getAttribute: name => attributes.get(name) || null,
      setAttribute: (name, value) => attributes.set(name, value)
    } },
    DOMParser: class { parseFromString() { return { querySelector: selector => {
      if (selector.startsWith('input[name=username]')) return outcome === 'login' ? {} : null;
      return outcome === 'reject' ? { textContent: '不足5字\n[ 点击这里返回上一页 ]' } : null;
    } }; } },
    fetch: async (url, options) => {
      requests.push({ url, options });
      if (outcome === 'network') throw new Error('offline');
      return { url: outcome === 'success' ? 'https://www.4d4y.com/forum/viewthread.php?tid=789&extra=' : url,
        ok: outcome !== 'http-error', arrayBuffer: async () => new ArrayBuffer(0) };
    }
  };
  return { sandbox, attributes, requests };
}
(async () => {
  for (const outcome of ['success', 'reject', 'login', 'network', 'unknown', 'http-error']) {
    const env = environment(outcome);
    vm.runInNewContext(script, env.sandbox);
    vm.runInNewContext(script, env.sandbox); // Re-entering the same callback must not POST twice.
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(env.requests.length, 1);
    const { url, options } = env.requests[0];
    assert.equal(url, 'https://www.4d4y.com/forum/post.php?action=newthread&fid=40&typeid=7&topicsubmit=yes');
    assert.equal(options.method, 'POST');
    assert.equal(options.credentials, 'same-origin');
    assert.equal(options.mode, 'same-origin');
    assert.equal(options.cache, 'no-store');
    assert.match(options.body, /subject=%D6%D0%CE%C4/);
    assert.match(options.body, /attachnew%5B%5D%5Bdescription%5D=123/);
    assert.match(options.body, /attachdel%5B%5D=456/);
    assert.equal(options.body.includes('not-an-id'), false);
    const result = JSON.parse(env.attributes.get(submission.FOUR_D4Y_TOPIC_SUBMIT_ATTRIBUTE));
    assert.equal(result.phase, ['network', 'unknown', 'http-error'].includes(outcome) ? 'uncertain' : 'result');
    if (result.payload) {
      assert.equal(result.payload.succeeded, outcome === 'success');
      assert.equal(result.payload.createdThreadId, outcome === 'success' ? '789' : '');
      assert.equal(result.payload.loginRequired, outcome === 'login');
      if (outcome === 'reject') assert.equal(result.payload.errorMessage, '不足5字');
    }
    assert.equal(vm.runInNewContext(submission.buildFourD4yNewThreadResultReadScript(2), env.sandbox), 'pending');
  }
  const bad = environment('success');
  bad.sandbox.location.origin = 'https://example.com';
  assert.throws(() => vm.runInNewContext(script, bad.sandbox), /unexpected-topic-origin/);
  assert.equal(bad.requests.length, 0);
  console.log('PASS: GBK/entity encoding; one POST; category/attachments; success/rejection/login/uncertain; origin and sequence isolation.');
})().catch(error => { console.error(error); process.exitCode = 1; });
