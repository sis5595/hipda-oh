// Deterministic race regression; synthetic cookies, no device/network access.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const diagnostics = [];
const root = path.resolve(__dirname, '../../main/ets/data/remote');
function load(name, dependencies) {
  const exports = {};
  const source = fs.readFileSync(path.join(root, name + '.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, console: { info: message => diagnostics.push(message) }, require: name => {
    assert.ok(name in dependencies, name);
    return dependencies[name];
  } });
  return exports;
}
const jar = new Map([['cdb_auth', 'synthetic_a']]);
let blockWrite = null;
const manager = {
  fetchCookie: async () => [...jar].map(([k, v]) => k + '=' + v).join('; '),
  configCookie: async (_url, cookie) => {
    if (blockWrite) await blockWrite;
    const pair = cookie.split(';')[0];
    const equals = pair.indexOf('=');
    const name = pair.slice(0, equals), value = pair.slice(equals + 1);
    if (cookie.includes('Max-Age=0')) jar.delete(name);
    else jar.set(name, value);
  },
  saveCookieAsync: async () => {}
};
const session = load('FourD4ySession', {
  '@kit.ArkWeb': { webview: { WebCookieManager: manager } },
  './FourD4yResponseCookieBridge': load('FourD4yResponseCookieBridge', {})
}).FourD4ySession;
(async () => {
  const url = 'https://www.4d4y.com/forum/index.php';
  assert.equal(session.hasAuthenticationCookie('cdb_auth=; cdb_other=x'), false);
  assert.equal(session.hasAuthenticationCookie('cdb_auth=   ; cdb_other=x'), false);
  assert.equal(session.hasAuthenticationCookie('cdb_auth=synthetic_a'), true);
  assert.equal(await session.getAuthenticationState(), 'present');
  assert.equal(await session.isCurrentAccountSessionSecret('cdb_auth=synthetic_a'), true);
  assert.equal(await session.isCurrentAccountSessionSecret('cdb_auth=synthetic_b'), false);
  assert.equal(await session.isCurrentAccountSessionSecret(''), false);
  assert.equal(await session.isCurrentAccountSessionSecret('cdb_auth=synthetic_a\ncdb_long=' + 'x'.repeat(700) +
    '\ncdb_more=' + 'y'.repeat(500)), true, 'asset size must not invalidate a live login');
  assert.equal(await session.restoreAccountSessionSecret('cdb_auth=synthetic_b'), true);
  assert.equal(await session.acceptNativeResponseCookies(url,
    { 'set-cookie': 'cdb_auth=late_a' }, 'cdb_auth=synthetic_a'), -1);
  assert.equal(jar.get('cdb_auth'), 'synthetic_b');
  assert.equal(await session.acceptNativeResponseCookies(url,
    { 'set-cookie': 'cdb_sid=rotated' }, 'cdb_auth=synthetic_b'), 1);
  // Start an accepted response write, then switch before that write completes.
  let release;
  blockWrite = new Promise(resolve => { release = resolve; });
  const response = session.acceptNativeResponseCookies(url,
    { 'set-cookie': 'cdb_auth=response_b' }, 'cdb_auth=synthetic_b');
  await new Promise(resolve => setImmediate(resolve));
  const switchAccount = session.restoreAccountSessionSecret('cdb_auth=synthetic_c');
  release();
  blockWrite = null;
  assert.equal(await response, 1);
  assert.equal(await switchAccount, true);
  assert.equal(jar.get('cdb_auth'), 'synthetic_c', 'old write cannot land after restored account');
  await session.clearPersistentAuthentication();
  assert.equal(await session.acceptNativeResponseCookies(url,
    { 'set-cookie': 'cdb_auth=resurrected' }, 'cdb_auth=synthetic_c'), -1);
  assert.equal(jar.has('cdb_auth'), false);
  assert.equal(await session.acceptNativeResponseCookies('https://example.com/forum/', {}, ''), -1);
  const fetch = manager.fetchCookie;
  manager.fetchCookie = async () => { throw new Error('synthetic_private_error'); };
  assert.equal(await session.getAuthenticationState(), 'read-failed');
  assert.equal(await session.getCookieHeader(), '');
  assert.equal(diagnostics.at(-1), '[HiPDAOHSession] authentication=read-failed');
  manager.fetchCookie = fetch;
  assert.equal(await session.getAuthenticationState(), 'absent');
  assert.equal(await session.getCookieHeader(), '');
  assert.equal(diagnostics.at(-1), '[HiPDAOHSession] authentication=absent');
  await session.persistVerifiedAuthentication();
  assert.equal(diagnostics.at(-1), '[HiPDAOHSession] verified-flush=success');
  manager.saveCookieAsync = async () => { throw new Error('synthetic_private_error'); };
  await session.persistVerifiedAuthentication();
  assert.equal(diagnostics.at(-1), '[HiPDAOHSession] verified-flush=failed');
  assert.ok(diagnostics.every(message => /^\[HiPDAOHSession\] (authentication=(present|absent|read-failed)|verified-flush=(success|failed))$/.test(message)),
    'diagnostics must contain fixed labels only, never credentials or exception details');
  console.log('Session cookie isolation regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
