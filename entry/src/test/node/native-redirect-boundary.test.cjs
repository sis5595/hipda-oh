// Synthetic transport callbacks only; never real cookies or forum requests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const result = {};
let attached, chainAccepted = true, applyAccepted = true;
const http = {
  InterceptorType: { REDIRECTION: 'REDIRECTION' },
  HttpInterceptorChain: class {
    addChain(chain) { attached = chain[0]; return chainAccepted; }
    apply(request) { request.boundary = attached; return applyAccepted; }
  }
};
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/data/remote/FourD4yNativeRedirectBoundary.ets'), 'utf8');
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: result, require(name) {
  if (name === '@ohos.net.http') return { default: http };
  if (name === '@kit.ArkTS') return { url: { URL } };
  throw new Error(name);
} });
const Boundary = result.FourD4yNativeRedirectBoundary;
const initial = 'https://www.4d4y.com/forum/my.php?item=threads';
(async () => {
  const safe = new Boundary(initial);
  safe.attach({});
  assert.equal(attached, safe);
  assert.equal(safe.getResponseUrl(), initial);
  for (const target of ['viewthread.php?tid=123', '?page=2',
    '/forum/redirect.php?pid=456', 'https://www.4d4y.com:443/forum/index.php']) {
    const req = { url: target, header: { Cookie: 'synthetic-only' }, body: {} };
    assert.equal(await safe.interceptorHandle(req, {}), true);
    assert.equal(req.header.Cookie, 'synthetic-only');
    assert.ok(req.url.startsWith('https://www.4d4y.com/forum/'));
    assert.equal(safe.getResponseUrl(), req.url, 'retain the actual guarded destination, not the initial URL');
  }
  assert.equal(safe.isResponseAllowed(), true);
  const oneShot = new Boundary(initial, false, false);
  oneShot.attach({});
  assert.equal(await oneShot.interceptorHandle({ url: initial }, {}), false,
    'a destructive GET cannot be repeated even by a same-URL redirect');
  for (const target of ['https://4d4y.com/attachments/a.jpg', 'https://img01.4d4y.com/attachments/a.jpg',
    'https://www.4d4y.com/forum/attachment.php?aid=123']) {
    const imageBoundary = new Boundary(initial, true);
    imageBoundary.attach({});
    assert.equal(await imageBoundary.interceptorHandle({ url: target }, {}), true);
  }
  for (const target of ['https://evil.example/a.jpg', 'http://img01.4d4y.com/a.jpg',
    'https://img01.4d4y.com.evil.example/a.jpg', 'https://img01.4d4y.com:8443/a.jpg',
    'https://user@img01.4d4y.com/a.jpg', 'https://unknown.4d4y.com/a.jpg']) {
    const imageBoundary = new Boundary(initial, true);
    imageBoundary.attach({});
    assert.equal(await imageBoundary.interceptorHandle({ url: target }, {}), false, target);
    assert.equal(imageBoundary.isResponseAllowed(), false);
  }
  for (const target of ['https://example.com/forum/', '//example.com/forum/',
    'http://www.4d4y.com/forum/', 'https://www.4d4y.com.evil.invalid/forum/',
    'https://www.4d4y.com@evil.invalid/forum/', 'https://user@www.4d4y.com/forum/',
    'https://www.4d4y.com:8443/forum/', '/outside', '../outside',
    '/forum/%2e%2e/outside', 'https://www.4d4y.com\\@evil.invalid/forum/',
    'https://www.4d4y.com/\nforum/', 'javascript:alert(1)']) {
    const boundary = new Boundary(initial);
    boundary.attach({});
    assert.equal(await boundary.interceptorHandle({ url: target }, {}), false, target);
    assert.equal(boundary.isResponseAllowed(), false);
    assert.equal(boundary.getResponseUrl(), '', 'a denied destination cannot become a parser hint');
    assert.equal(await boundary.interceptorHandle({ url: initial }, {}), false,
      'blocked chain must never recover and accept cookies');
  }
  const loop = new Boundary(initial);
  loop.attach({});
  for (let i = 0; i < 8; i++) assert.equal(await loop.interceptorHandle({ url: initial }, {}), true);
  assert.equal(await loop.interceptorHandle({ url: initial }, {}), false);
  assert.throws(() => new Boundary('https://example.com/forum/').attach({}));
  chainAccepted = false;
  assert.throws(() => new Boundary(initial).attach({}));
  chainAccepted = true; applyAccepted = false;
  assert.throws(() => new Boundary(initial).attach({}));
  applyAccepted = true;
  // Also exercise all production call sites: even a synthetic HTTP 200 from
  // a denied redirect must not reach the Cookie bridge or HTML decoder.
  let target, accepted = 0, decoded = 0, destroyed = 0;
  http.RequestMethod = { GET: 'GET' };
  http.HttpDataType = { ARRAY_BUFFER: 1 };
  http.ResponseCode = { OK: 200 };
  http.createHttp = () => ({
    async request() {
      await this.boundary.interceptorHandle({ url: target }, {});
      return { responseCode: 200, result: new ArrayBuffer(0), header: {} };
    },
    destroy() { destroyed++; }
  });
  const dependencies = {
    '@ohos.net.http': { default: http },
    '@ohos.util': { default: { TextDecoder: { create: () => ({
      decodeToString: () => { decoded++; return ''; }
    }) } } },
    '@kit.PerformanceAnalysisKit': { hilog: { warn() {} } },
    './FourD4yNativeRedirectBoundary': result,
    './FourD4ySession': { FourD4ySession: {
      forumRoot: 'https://www.4d4y.com/forum/', fullSiteUserAgent: 'synthetic',
      acceptNativeResponseCookies: async () => { accepted++; return 0; }
    } },
    './FourD4yRequestCookieBridge': { appendFourD4ySessionId: value => value },
    './FourD4yNativeRequestFailure': { classifyFourD4yHttpFailure: () => ({ kind: 'synthetic' }),
      classifyFourD4yNetworkFailure: () => ({ kind: 'synthetic' }) },
    '../../domain/search/FourD4ySearchContracts': { isAllowedFourD4ySearchPostTargetUrl: () => true },
    '../../domain/notice/FourD4yMessageContracts': {},
    '../../domain/notice/FourD4yPrivateConversationContracts': {},
    '../../domain/mine/FourD4yMyContentContracts': {},
    './FourD4ySearchNativeParser': { parseFourD4yNativeSearchPage: () => null },
    './FourD4yMyContentNativeParser': { parseFourD4yNativeMyContentPage: () => null },
    './FourD4yMessageNativeParser': {},
    './FourD4yPrivateConversationNativeParser': {},
    './FourD4ySearchPostTargetParser': {}
  };
  for (const [name, method, args] of [
    ['FourD4yMessageNativeClient', 'requestHtml', [initial, 'synthetic', initial]],
    ['FourD4ySearchNativeClient', 'loadOnce', [initial, 1, 'synthetic']],
    ['FourD4yMyContentNativeClient', 'loadOnce', [initial, 1, 'synthetic']],
    ['FourD4ySearchPostNativeResolver', 'loadPage', [initial, 'synthetic', initial]]
  ]) {
    const exports = {};
    const clientSource = fs.readFileSync(path.resolve(__dirname, '../../main/ets/data/remote', name + '.ets'), 'utf8');
    vm.runInNewContext(ts.transpileModule(clientSource, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
    } }).outputText, { exports, ArrayBuffer, Uint8Array, require(key) {
      assert.ok(key in dependencies, key); return dependencies[key];
    } });
    const client = new exports[name]();
    for (const allowed of [false, true]) {
      target = allowed ? '/forum/viewthread.php?tid=123' : 'https://example.com/forum/';
      const before = { accepted, decoded, destroyed };
      await client[method](...args);
      assert.equal(accepted - before.accepted, allowed ? 1 : 0, name + ': cookie boundary');
      assert.equal(decoded - before.decoded, allowed ? 1 : 0, name + ': body boundary');
      assert.equal(destroyed - before.destroyed, 1, name + ': always release request');
    }
  }
  console.log('Native redirect origin, relative URL, downgrade, loop and attachment failure boundaries passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
