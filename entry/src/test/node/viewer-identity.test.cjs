const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const output = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/data/remote/FourD4yViewerIdentityParser.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: output });
const read = output.extractFourD4yViewerUserId;
assert.equal(read('<a href="space.php?uid=987">author</a>'), '');
assert.equal(read('<script>var uid=987;</script>'), '');
assert.equal(read('<script>var discuz_uid = "5595";</script>'), '5595');
assert.equal(read('<script>var discuz_uid = "0";</script>'), '');
assert.equal(read('<!-- <script>var discuz_uid = "987";</script> -->'), '');
assert.equal(read('<!-- <script>var discuz_uid = "987";</script> --><script>var discuz_uid = "5595";</script>'), '5595');
assert.equal(read('<a href="space.php?uid=987">author</a><div id="umenu"><cite><a href="space.php?uid=5595">me</a></cite></div>'), '5595');
assert.equal(read('<div id="umenu"><div>prompt</div><cite><a href="space.php?uid=5595">me</a></cite></div>'), '5595');
assert.equal(read('<div id="umenu">guest</div><a href="space.php?uid=987">author</a>'), '');
assert.equal(read('<div id="umenu"><cite><a href="https://example.com/forum/space.php?uid=987">other</a></cite></div>'), '');
assert.equal(read('<div id="umenu"><a href="space.php?uid=5595&amp;foo=1">me</a></div>'), '5595');
assert.equal(read('<script>var discuz_uid = 0;</script><div id="umenu"><cite><a href="space.php?uid=5595">me</a></cite></div>'), '5595');
console.log('Viewer identity boundary regression passed.');
