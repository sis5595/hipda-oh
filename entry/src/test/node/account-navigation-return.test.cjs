const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets/presentation');
function load(relative, method, resultClass) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const start = source.indexOf('  private ' + method + '(');
  const end = source.indexOf('\n  }', start) + 4;
  assert.ok(start > 0 && end > start);
  assert.ok(source.includes('.onBackPressed(() => this.' + method + '())'));
  const exports = {};
  vm.runInNewContext(ts.transpileModule('class ' + resultClass +
    ' { changed = true; } class Page {' + source.slice(start, end) + '} exports.Page = Page;', {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
    }).outputText, { exports });
  return new exports.Page();
}
let returns = 0;
const stack = { pop(result) {
  assert.equal(result.changed, true, 'Back must provide a result to invoke the onPop refresh');
  returns++;
} };
const account = load('account/AccountPage.ets', 'closeAccountPage', 'AccountPagePopResult');
account.pathStack = stack;
account.isSwitching = true;
assert.equal(account.closeAccountPage(), true);
assert.equal(returns, 0, 'do not leave while replacing the global session');
account.isSwitching = false;
assert.equal(account.closeAccountPage(), true);
assert.equal(returns, 1);
const login = load('login/LoginPage.ets', 'closeLoginPage', 'LoginPagePopResult');
login.pathStack = stack;
login.clearLoadWatchdog = () => {};
login.verificationSequence = 10;
login.isPageActive = true;
assert.equal(login.closeLoginPage(), true);
assert.equal(login.verificationSequence, 11, 'cancel stale verification before navigation');
assert.equal(returns, 2, 'cancel/Back releases the account page through the same return callback');
assert.equal(login.closeLoginPage(), true);
assert.equal(returns, 2, 'queued backdrop/Back cannot pop the underlying account page twice');
console.log('Account and login native Back return results and in-flight switching guard passed.');
