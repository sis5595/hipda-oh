// Exercise login completion without ArkUI, network or actual account secrets.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/login/LoginPage.ets'), 'utf8');
const start = source.indexOf('  private async refreshLoginState()');
const end = source.indexOf('  private onControllerAttached()', start);
const methods = source.slice(start, end);
let secret, identity, cookieCurrent, persists, beforePersist;
const exportsForTest = {};
vm.runInNewContext(ts.transpileModule('class Page {' + methods + '} exports.Page = Page;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exportsForTest,
  FourD4ySession: { captureAccountSessionSecret: async () => secret,
    isCurrentAccountSessionSecret: async () => cookieCurrent,
    persistVerifiedAuthentication: async () => { persists++; beforePersist(); } },
  buildFourD4yAccountIdentityScript: () => 'synthetic-identity',
  parseFourD4yAccountIdentity: () => identity
});
function page({ expectedUserId = '', save = true, saveStatus = '' } = {}) {
  secret = 'synthetic-only'; identity = { userId: '123', displayName: 'Synthetic account' };
  cookieCurrent = true; persists = 0; beforePersist = () => {};
  let closed = 0;
  const p = Object.assign(new exportsForTest.Page(), { isPageActive: true, verificationSequence: 0,
    expectedUserId, lastVerifiedUserId: '', hasPersistedVerifiedLogin: false,
    accountSaveStatus: '', controller: { runJavaScript: async () => '' },
    accountState: { getSessionGeneration: () => 1 },
    saveVerifiedAccountSession: async () => { p.accountSaveStatus = saveStatus; return save; },
    closeLoginPage: () => { closed++; p.isPageActive = false; p.verificationSequence++; }
  });
  return { p, closed: () => closed };
}
(async () => {
  let f = page(); await f.p.refreshLoginState();
  assert.equal(f.closed(), 1); assert.equal(persists, 1); assert.equal(f.p.isLoggedIn, true);
  assert.equal(f.p.isVerifying, false, 'verified and saved before returning');
  f = page({ expectedUserId: '999' }); await f.p.refreshLoginState();
  assert.equal(f.closed(), 0); assert.equal(persists, 0); assert.equal(f.p.rejectedSession, true);
  f = page(); cookieCurrent = false; await f.p.refreshLoginState();
  assert.equal(f.closed(), 0); assert.equal(persists, 0);
  f = page({ save: false }); await f.p.refreshLoginState();
  assert.equal(f.closed(), 0); assert.equal(f.p.isLoggedIn, false);
  f = page({ saveStatus: 'Synthetic storage failure; login still usable' }); await f.p.refreshLoginState();
  assert.equal(f.closed(), 0); assert.equal(f.p.isLoggedIn, true);
  assert.match(f.p.status, /storage failure/, 'save warnings stay visible with manual completion');
  f = page(); identity = null; await f.p.refreshLoginState();
  assert.equal(f.closed(), 0); assert.equal(persists, 0);
  f = page(); beforePersist = () => { f.p.isPageActive = false; f.p.verificationSequence++; };
  await f.p.refreshLoginState(); assert.equal(f.closed(), 0, 'no late return after user cancellation');
  assert.ok(source.includes('.mode(NavDestinationMode.DIALOG)'));
  assert.ok(source.includes('.metaViewport(true)'), 'desktop authentication UA must still respect compact viewport');
  assert.equal((source.match(/Web\(\{ src:/g) || []).length, 1, 'keep one browser/session across fallback changes');
  console.log('Login auto-return only after bound identity/session verification; mismatch, warnings and cancellation passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
