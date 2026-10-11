const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/login/LoginPage.ets'), 'utf8');
const names = ['clearLoadWatchdog', 'beginLoginLoad', 'finishLoginLoad', 'failLoginLoad', 'retryLoginPage'];
const methods = names.map(name => {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  const end = source.indexOf('\n  }', start) + 4;
  assert.ok(start > 0 && end > start);
  return source.slice(start, end);
}).join('\n');
const timers = new Map(), canceled = new Set();
let next = 0;
const exportsForTest = {};
vm.runInNewContext(ts.transpileModule('class Page { ' + methods + ' } exports.Page = Page;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exportsForTest,
  setTimeout: (callback, delay) => { assert.equal(delay, 30000); timers.set(++next, callback); return next; },
  clearTimeout: id => canceled.add(id),
  buildFourD4yLoginPresentationScript: () => 'synthetic-presentation' });
const p = new exportsForTest.Page();
Object.assign(p, { isPageActive: true, isControllerAttached: true, loadTimeoutId: -1,
  loadSequence: 0, verificationSequence: 0, isLoggedIn: true,
  loginUrl: 'https://www.4d4y.com/forum/logging.php?action=login' });
let stops = 0, verifies = 0, loads = [];
p.controller = { stop: () => stops++, loadUrl: url => loads.push(url), runJavaScript: async () => '"compact"' };
p.refreshLoginState = () => verifies++;
(async () => {
p.retryLoginPage();
assert.deepEqual(loads, [p.loginUrl]);
const oldTimer = timers.get(next);
p.beginLoginLoad('https://www.4d4y.com/forum/index.php');
oldTimer();
assert.equal(stops, 0, 'old navigation timeout cannot stop the new document');
p.failLoginLoad(p.loginUrl);
assert.equal(p.loadFailed, false, 'late old-page failure ignored');
p.failLoginLoad(p.loadingUrl);
assert.equal(p.loadFailed, true);
assert.equal(p.isVerifying, false);
assert.equal(p.isLoggedIn, true, 'network errors never imply logout');
await p.finishLoginLoad(p.loadingUrl);
assert.equal(verifies, 0, 'error-page completion cannot verify identity or replace error status');
p.retryLoginPage();
await p.finishLoginLoad(p.loadingUrl);
assert.equal(verifies, 1);
assert.equal(p.compactLogin, true);
assert.equal(p.presentationReady, true);
assert.ok(canceled.has(next), 'successful page cancels timeout');
timers.get(next)();
assert.equal(stops, 0, 'already queued timeout cannot stop a successfully loaded page');
assert.equal(p.loadFailed, false);
p.beginLoginLoad(p.loginUrl);
timers.get(next)();
assert.equal(p.loadFailed, true);
assert.equal(stops, 1);
p.retryLoginPage();
const before = p.verificationSequence;
p.isPageActive = false;
timers.get(next)();
p.failLoginLoad(p.loadingUrl);
await p.finishLoginLoad(p.loadingUrl);
p.retryLoginPage();
assert.equal(p.verificationSequence, before, 'no lifecycle work after leaving');
assert.equal(verifies, 1);
assert.equal(stops, 1);
// A queued presentation result must not expose or verify a different document.
p.isPageActive = true;
p.retryLoginPage();
let resume;
p.controller.runJavaScript = () => new Promise(resolve => { resume = resolve; });
const queued = p.finishLoginLoad(p.loadingUrl);
p.beginLoginLoad('https://www.4d4y.com/forum/index.php');
resume('"compact"');
await queued;
assert.equal(verifies, 1);
assert.equal(p.presentationReady, false);
// Missing templates remain usable; injection failure must not block login.
p.controller.runJavaScript = async () => { throw new Error('synthetic unknown template'); };
await p.finishLoginLoad(p.loadingUrl);
assert.equal(p.compactLogin, false);
assert.equal(p.presentationReady, true);
assert.equal(verifies, 2);
p.retryLoginPage();
p.compactLogin = true;
p.controller.runJavaScript = async () => '"website"';
let resumeVerification;
p.refreshLoginState = () => new Promise(resolve => { resumeVerification = resolve; });
const verifying = p.finishLoginLoad(p.loadingUrl);
// The VM and host have different Promise realms; flush the event turn, not
// only one host microtask, while leaving verification deliberately pending.
await new Promise(resolve => setImmediate(resolve));
assert.equal(typeof resumeVerification, 'function');
assert.equal(p.compactLogin, true, 'do not flash an expanded desktop page before identity verification');
assert.equal(p.presentationReady, false);
resumeVerification();
await verifying;
assert.equal(p.compactLogin, false, 'fallback remains available when verification does not close the page');
assert.equal(p.presentationReady, true);
assert.ok(source.includes('event.request.isMainFrame()'));
assert.ok(source.includes('event.response.getResponseCode() >= 400'));
console.log('Login main-document failure, timeout, safe GET retry and lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
