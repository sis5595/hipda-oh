// Synthetic disposable conversations only; no real secrets or forum requests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(name, deps = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
    '../../main/ets', name + '.ets'), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, Uint8Array, ArrayBuffer, require(name) {
    assert.ok(name in deps, name); return deps[name];
  } });
  return exports;
}
const reader = load('domain/reader/FourD4yReaderContracts');
const contracts = load('domain/notice/FourD4yPrivateConversationContracts', {
  '../reader/FourD4yReaderContracts': reader
});
const parser = load('data/remote/FourD4yPrivateConversationNativeParser', {
  '../../domain/reader/FourD4yReaderContracts': reader,
  '../../domain/notice/FourD4yPrivateConversationContracts': contracts,
  './FourD4yViewerIdentityParser': load('data/remote/FourD4yViewerIdentityParser')
});
const clearLink = '<div class="itemtitle newpm_notice s_clear"><span class="right">' +
  '<a href="pm.php?action=del&amp;uid=2&amp;filter=privatepm" onclick="return confirm(\'irreversible\');">清空</a></span></div>';
const menu = '<div id="umenu"><cite><a href="space.php?uid=1">synthetic viewer</a></cite></div>';
const empty = menu + clearLink + '<div id="pmlist"><ul class="pm_list"><li>暂无短消息</li></ul></div>';
const content = menu + clearLink + '<div id="pmlist"><ul class="pm_list"><li class="s_clear" id="pm_9">' +
  '<p class="cite"><cite><a href="space.php?uid=2">synthetic participant</a></cite></p>' +
  '<div class="summary">synthetic message</div></li></ul></div>';
const extract = parser.extractFourD4yPrivateConversationClearUrl;
assert.equal(extract(content, '2'), 'https://www.4d4y.com/forum/pm.php?action=del&uid=2&filter=privatepm');
assert.equal(extract(content.replace('filter=privatepm', 'filter='), '2'),
  'https://www.4d4y.com/forum/pm.php?action=del&uid=2&filter=');
for (const html of [content.replace('uid=2&amp;filter', 'uid=3&amp;filter'),
  content.replace('pm.php?action=del', 'https://evil.invalid/pm.php?action=del'),
  content.replace('&amp;filter=privatepm', '&amp;filter=privatepm&amp;pmid=999'),
  content.replace('>清空</a>', '>引用链接</a>'), content.replace('onclick=', 'data-onclick='),
  menu + '<!--' + clearLink + '--><ul class="pm_list"></ul>',
  menu + '<script>' + clearLink + '</script><ul class="pm_list"></ul>',
  menu + '<div id="pmlist"><div class="summary">' + clearLink + '</div></div>']) {
  assert.equal(extract(html, '2'), '', 'only the exact server header action can authorize clearing');
}
const view = contracts.buildFourD4yPrivateConversationUrl('2');
assert.equal(contracts.isAllowedFourD4yPrivateConversationUrl(extract(content, '2')), false,
  'read-only transport must never accept the mutation URL');
let responses, requests, alive, authMatches, onRequest, released;
const http = {
  RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 1 }, ResponseCode: { OK: 200 },
  createHttp: () => ({
    async request(url, options) {
      requests.push({ url, options });
      if (onRequest) onRequest(requests.length);
      const next = responses.shift();
      if (next instanceof Error) throw next;
      assert.ok(typeof next === 'string');
      return { responseCode: 200, result: new TextEncoder().encode(next).buffer, header: {} };
    }, destroy() { released++; }
  })
};
const Client = load('data/remote/FourD4yPrivateConversationClearClient', {
  '@ohos.net.http': { default: http },
  '@ohos.util': { default: { TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) } } },
  './FourD4ySession': { FourD4ySession: { forumRoot: 'https://www.4d4y.com/forum/',
    fullSiteUserAgent: 'synthetic', getCookieHeader: async () => 'synthetic-only',
    hasAuthenticationCookie: () => true, createAccountSessionSecret: () => 'synthetic-only',
    isCurrentAccountSessionSecret: async () => authMatches,
    acceptNativeResponseCookies: async () => alive ? 0 : -1 } },
  './FourD4yRequestCookieBridge': { appendFourD4ySessionId: url => url },
  './FourD4yNativeRedirectBoundary': { FourD4yNativeRedirectBoundary: class {
    constructor(url, _images, redirects) { this.url = url; this.redirects = redirects; }
    attach(request) { request.guard = this; }
    isResponseAllowed() { return true; } getResponseUrl() { return this.url; }
  } },
  './FourD4yPrivateConversationNativeParser': parser,
  '../../domain/notice/FourD4yPrivateConversationContracts': contracts
}).FourD4yPrivateConversationClearClient;
async function scenario(pages, options = {}) {
  responses = [...pages]; requests = []; alive = true; authMatches = options.authMatches !== false;
  released = 0; onRequest = options.onRequest;
  const result = await new Client().clear('2', options.viewer || '1', () => alive);
  assert.equal(released, requests.length, 'all request handles are released');
  const writes = requests.filter(request => request.url.includes('action=del'));
  assert.ok(writes.length <= 1, 'a destructive request is never retried');
  return { result, writes, reads: requests.filter(request => request.url === view).length };
}
(async () => {
  assert.equal((await scenario([content, menu + '<p>删除成功</p>', empty])).result, 'confirmed');
  assert.equal((await scenario([content, new Error('lost response'), empty])).result, 'confirmed',
    'a read-back may confirm a lost response, without resubmitting');
  assert.equal((await scenario([content, new Error('lost response'), content])).result, 'unconfirmed');
  assert.equal((await scenario([content, 'success text alone', new Error('read failed')])).result, 'unconfirmed');
  assert.equal((await scenario([content, 'success text alone', empty.replace('uid=1', 'uid=3')])).result, 'unconfirmed');
  assert.equal((await scenario([content, 'success text alone', menu + '<div id="pmlist"><ul class="pm_list"></ul></div>'])).result,
    'unconfirmed', 'an empty shell is not server confirmation');
  assert.equal((await scenario([content, 'success text alone', menu +
    '<div id="pmlist"><ul class="pm_list"><li class="s_clear">malformed old message</li></ul></div>'])).result,
    'unconfirmed', 'a parser mismatch cannot manufacture deletion success');
  for (const pages of [[empty], [content.replace(clearLink, '')], [content.replace('uid=1', 'uid=3')]]) {
    const result = await scenario(pages); assert.equal(result.result, 'not-started'); assert.equal(result.writes.length, 0);
  }
  let result = await scenario([content], { authMatches: false });
  assert.equal(result.result, 'cancelled'); assert.equal(result.writes.length, 0);
  result = await scenario([content], { onRequest: count => { if (count === 1) alive = false; } });
  assert.equal(result.result, 'cancelled'); assert.equal(result.writes.length, 0);
  result = await scenario([content, 'success'], { onRequest: count => { if (count === 2) alive = false; } });
  assert.equal(result.result, 'cancelled'); assert.equal(result.writes.length, 1); assert.equal(result.reads, 1);
  console.log('PASS: private conversation clear scope, fresh viewer/target, single write, lost response, read-back and lifecycle.');
})().catch(error => { console.error(error); process.exitCode = 1; });
