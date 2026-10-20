// Production resolver contract; synthetic forum responses, never live cookies.
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
  } }).outputText, { exports, require: key => {
    assert.ok(key in deps, key); return deps[key];
  } });
  return exports;
}
const reader = load('domain/reader/FourD4yReaderContracts');
const contracts = load('domain/search/FourD4ySearchContracts', {
  '../reader/FourD4yReaderContracts': reader
});
assert.equal(contracts.buildFourD4ySearchPostTargetUrl('', '88'),
  'https://www.4d4y.com/forum/gotopost.php?pid=88',
  'NG uses the PID-only endpoint, never a findpost request with an empty ptid');
assert.equal(contracts.isAllowedFourD4ySearchPostTargetUrl(
  'https://www.4d4y.com/forum/gotopost.php?pid=88'), true);
const parser = load('data/remote/FourD4ySearchPostTargetParser', {
  '../../domain/reader/FourD4yReaderContracts': reader,
  '../../domain/search/FourD4ySearchContracts': contracts
});
let currentSession = true;
const { FourD4ySearchPostNativeResolver: Resolver } = load('data/remote/FourD4ySearchPostNativeResolver', {
  '@ohos.net.http': { default: {} },
  '@ohos.util': { default: { TextDecoder: { create: () => ({}) } } },
  '../../domain/search/FourD4ySearchContracts': contracts,
  './FourD4ySearchPostTargetParser': parser,
  './FourD4yRequestCookieBridge': {},
  './FourD4yNativeRedirectBoundary': {}, // loadPage is replaced; boundary has its own transport tests.
  './FourD4ySession': { FourD4ySession: {
    forumRoot: 'https://www.4d4y.com/forum/', getCookieHeader: async () => 'synthetic',
    hasAuthenticationCookie: () => true, createFullSiteCookieHeader: value => value,
    isCurrentAccountSessionSecret: async () => currentSession
  } }
});
async function run(tid, discovery, final = '<table id="pid88"><a id="postnum88">61#</a></table>', destination = '') {
  const resolver = new Resolver(), urls = [];
  resolver.loadPage = async url => {
    urls.push(url);
    return { status: 'success', finalUrl: !url.includes('viewpid=') && destination ? destination : url,
      html: url.includes('viewpid=') ? final : discovery };
  };
  return { result: await resolver.resolve(tid, '88', 1, '1'), urls };
}
(async () => {
  const known = await run('102', '');
  assert.equal(known.result.status, 'success');
  assert.equal(known.urls.length, 1, 'known topic retains its one-request exact-floor path');
  const discovery = '<meta http-equiv="refresh" content="0;url=viewthread.php?tid=102&amp;rpid=88#pid88">';
  const missing = await run('', discovery);
  assert.equal(missing.result.status, 'success', 'PID-only search hits must first resolve their owning topic');
  assert.equal(missing.result.payload.floor, 61);
  assert.equal(missing.result.payload.page, 2);
  assert.equal(missing.urls.length, 2);
  assert.match(missing.urls[1], /tid=102&viewpid=88/);
  const firstPostLanding = await run('', '<table id="pid77"><a id="postnum77">1#</a></table>',
    undefined, 'https://www.4d4y.com/forum/viewthread.php?tid=102');
  assert.equal(firstPostLanding.result.status, 'success',
    'a same-origin redirect can land on the first post; use its topic as a hint, then verify the exact PID');
  assert.equal(firstPostLanding.result.payload.floor, 61);
  assert.equal(firstPostLanding.urls.length, 2);
  const unrelatedLink = await run('', '<a href="viewthread.php?tid=102&extra=1">other topic</a>');
  assert.equal(unrelatedLink.urls.length, 1, 'arbitrary body links are not a discovered target');
  assert.equal(unrelatedLink.result.status, 'unsupported-response',
    'unrecognized discovery without a server error is not evidence that a post was deleted');
  const external = await run('', '<meta http-equiv="refresh" content="0;url=https://example.com/?tid=102">');
  assert.notEqual(external.result.status, 'success');
  assert.equal(external.urls.length, 1);
  const wrong = await run('', discovery, '<table id="pid99"><a id="postnum99">61#</a></table>');
  assert.notEqual(wrong.result.status, 'success', 'discovery alone never proves the requested post exists');
  const loop = await run('', '<meta http-equiv="refresh" content="0;url=redirect.php?goto=findpost&amp;pid=88">');
  assert.notEqual(loop.result.status, 'success');
  assert.equal(loop.urls.length, 1, 'no recursive redirect loop');
  currentSession = false;
  const changed = await run('', discovery);
  assert.equal(changed.result.status, 'request-failed');
  assert.equal(changed.urls.length, 1, 'account change between steps prevents a follow-up with stale cookies');
  currentSession = true;
  const notice = new Resolver(), noticeUrls = [];
  notice.loadPage = async url => {
    noticeUrls.push(url);
    return { status: 'success', finalUrl: url,
      html: '<table id="pid88"><a id="postnum88">61#</a></table>' };
  };
  const opened = await notice.resolve('102', '88', 2, '1',
    'https://www.4d4y.com/forum/notice.php?filter=threads&page=1', true);
  assert.equal(opened.status, 'success');
  assert.equal(opened.payload.floor, 61);
  assert.equal(noticeUrls.length, 2);
  assert.match(noticeUrls[0], /viewpid=88/);
  assert.match(noticeUrls[1], /redirect\.php\?goto=findpost&ptid=102&pid=88/);
  currentSession = false;
  noticeUrls.length = 0;
  assert.equal((await notice.resolve('102', '88', 3, '1', undefined, true)).status, 'request-failed');
  assert.equal(noticeUrls.length, 1, 'account switch prevents acknowledging another account reminder');
  currentSession = true;
  notice.loadPage = async url => ({ status: url.includes('redirect.php') ? 'request-failed' : 'success',
    finalUrl: url, html: '<table id="pid88"><a id="postnum88">61#</a></table>' });
  assert.equal((await notice.resolve('102', '88', 4, '1', undefined, true)).status, 'request-failed');
  const direct = await run('', '<script>tid = parseInt(\'102\')</script>' +
    '<table id="pid88"><a id="postnum88">1#</a></table>');
  assert.equal(direct.result.status, 'success');
  assert.equal(direct.result.payload.floor, 61, 'discovery floor is not the final authoritative floor');
  console.log('PASS: PID-only discovery, exact-floor verification, known-topic fast path and redirect boundaries.');
})().catch(error => { console.error(error); process.exitCode = 1; });
