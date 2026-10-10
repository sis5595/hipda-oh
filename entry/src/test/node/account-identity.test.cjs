const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/account/FourD4yAccountIdentityScript.ets'), 'utf8');
const output = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: output });
function read(href, page = 'https://www.4d4y.com/forum/index.php', self = true) {
  return vm.runInNewContext(output.buildFourD4yAccountIdentityScript(), {
    URL, location: new URL(page), document: {
      querySelector: selector => {
        assert.equal(selector, '#umenu cite a[href*="space.php"]');
        return self ? { getAttribute: () => href, textContent: ' Test account ' } : null;
      }
    }
  });
}
assert.deepEqual(JSON.parse(read('space.php?uid=123')), { userId: '123', displayName: 'Test account' });
assert.equal(read('space.php?uid=123', undefined, false), '', 'body author links cannot authenticate');
assert.equal(read('https://example.com/forum/space.php?uid=123'), '');
assert.equal(read('space.php?uid=123', 'https://example.com/forum/index.php'), '');
assert.equal(read('space.php?uid=abc'), '');
assert.equal(read('space.php?uid=12345678901234567'), '');
console.log('Account identity regression passed.');
