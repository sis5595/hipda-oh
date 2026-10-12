const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const source = fs.readFileSync(path.join(root, 'presentation/about/AboutPage.ets'), 'utf8');
const start = source.indexOf('  private readInstalledVersion(');
const end = source.indexOf('  private async openWebLink(', start);
assert.ok(start >= 0 && end > start);
let installed;
const exportsObject = {};
vm.runInNewContext(ts.transpileModule('class About {' + source.slice(start, end) +
  '} exports.About = About;', { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsObject, bundleManager: {
  BundleFlag: { GET_BUNDLE_INFO_DEFAULT: 0 }, getBundleInfoForSelfSync: flags => {
    assert.equal(flags, 0);
    if (installed instanceof Error) throw installed;
    return installed;
  }
} });
const about = new exportsObject.About();
for (const [versionName, versionCode] of [['older-installed-build', 1000002], ['future-installed-build', 1234567]]) {
  installed = { versionName, versionCode };
  about.readInstalledVersion();
  assert.equal(about.versionName, versionName);
  assert.equal(about.versionCode, String(versionCode));
  assert.equal(about.versionError, false);
}
for (const failure of [new Error('synthetic API failure'), { versionName: '', versionCode: 1 },
  { versionName: 'bad', versionCode: 0 }]) {
  installed = failure;
  about.readInstalledVersion();
  assert.equal(about.versionName, '');
  assert.equal(about.versionCode, '');
  assert.equal(about.versionError, true);
}
assert.doesNotMatch(source, /versionName:\s*string\s*=\s*['"]1\./);
assert.match(source, /FOUR_D4Y_PRIVACY_CONTACT/);
assert.match(source, /GPL-3\.0-or-later/);
assert.match(source, /HiPDA·NG/);
assert.match(fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8'), /routeName === 'About'/);
assert.match(fs.readFileSync(path.join(root, 'presentation/settings/SettingsPage.ets'), 'utf8'),
  /pushPathByName\('About', null\)/);
console.log('About screen reads actual installed bundle/version code, handles failures and keeps policy/contact/license/NG links.');
