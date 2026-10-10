const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/login/LoginPage.ets'), 'utf8');
const names = ['clearLoadWatchdog', 'beginLoginLoad', 'finishLoginLoad', 'failLoginLoad', 'retryLoginPage'];
const methods = names.map(name => {
  const start = source.indexOf('  private ' + name + '(');
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
  clearTimeout: id => canceled.add(id) });
const p = new exportsForTest.Page();
Object.assign(p, { isPageActive: true, isControllerAttached: true, loadTimeoutId: -1,
  loadSequence: 0, verificationSequence: 0, isLoggedIn: true,
  loginUrl: 'https://www.4d4y.com/forum/logging.php?action=login' });
let stops = 0, verifies = 0, loads = [];
p.controller = { stop: () => stops++, loadUrl: url => loads.push(url) };
p.refreshLoginState = () => verifies++;
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
p.finishLoginLoad(p.loadingUrl);
assert.equal(verifies, 0, 'error-page completion cannot verify identity or replace error status');
p.retryLoginPage();
p.finishLoginLoad(p.loadingUrl);
assert.equal(verifies, 1);
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
p.finishLoginLoad(p.loadingUrl);
p.retryLoginPage();
assert.equal(p.verificationSequence, before, 'no lifecycle work after leaving');
assert.equal(verifies, 1);
assert.equal(stops, 1);
assert.ok(source.includes('event.request.isMainFrame()'));
assert.ok(source.includes('event.response.getResponseCode() >= 400'));
console.log('Login main-document failure, timeout, safe GET retry and lifecycle regression passed.');
