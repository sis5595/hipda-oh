const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/profile/FourD4yAvatar.ets'), 'utf8');
const output = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: output });
const avatar = output.buildFourD4yAvatarUrl;
const base = 'https://img02.4d4y.com/forum/uc_server/data/avatar/';
assert.equal(avatar('123456'), base + '000/12/34/56_avatar_middle.jpg');
assert.equal(avatar('1'), base + '000/00/00/01_avatar_middle.jpg');
assert.equal(avatar('123456789'), base + '123/45/67/89_avatar_middle.jpg');
assert.equal(avatar('000123456'), avatar('123456'));
for (const value of [undefined, '', '0', '000', '1234567890', '../1', '1?x=2', '-1', ' 1', '1.0']) {
  assert.equal(avatar(value), '', 'invalid or anonymous UID must not request an avatar');
}
console.log('Avatar URL regression passed.');
