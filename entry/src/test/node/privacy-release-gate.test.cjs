// Exercise the production Index gate without ArkUI, network or real account data.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const project = path.resolve(__dirname, '../../../..');
const source = fs.readFileSync(path.join(project, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
function method(name) {
  const start = source.indexOf('  private async ' + name + '(');
  const end = source.indexOf('\n  }', start) + 4;
  assert.ok(start > 0 && end > start);
  return source.slice(start, end);
}
const exportsObject = {};
let accepted = false, restored = 0, exits = 0, failExit = false, saved = 0;
let storedConsent = false;
vm.runInNewContext(ts.transpileModule('export class Gate {\n' +
  ['loadPrivacyConsent', 'acceptPrivacyPolicy', 'rejectPrivacyPolicy'].map(method).join('\n') + '\n}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exportsObject,
  AppStorage: { set: (_key, value) => { accepted = value; },
    setOrCreate: (_key, value) => { accepted = value; } },
  FourD4yPrivacyConsentStore: { hasAcceptedCurrentPolicy: async () => storedConsent,
    acceptCurrentPolicy: async () => { saved++; return true; } },
  FourD4yAccountService: { restoreStartupSession: async () => { restored++; } }
});
function gate() {
  const page = new exportsObject.Gate();
  Object.assign(page, { isIndexAlive: true, isAcceptingPrivacyPolicy: false,
    isRejectingPrivacyPolicy: false, privacyErrorMessage: '', privacyReady: false,
    getUIContext: () => ({ getHostContext: () => ({ terminateSelf: async () => {
      exits++; if (failExit) throw new Error('synthetic failure');
    } }) }) });
  return page;
}
(async () => {
  const first = gate();
  await first.loadPrivacyConsent();
  assert.equal(accepted, false); assert.equal(restored, 0); assert.equal(first.privacyReady, true);
  await first.rejectPrivacyPolicy();
  assert.equal(exits, 1); assert.equal(accepted, false); assert.equal(restored, 0); assert.equal(saved, 0);
  await first.acceptPrivacyPolicy();
  assert.equal(saved, 0, 'cannot accept while terminating');
  const failed = gate(); failExit = true;
  await failed.rejectPrivacyPolicy();
  assert.equal(accepted, false); assert.equal(restored, 0);
  assert.equal(failed.isRejectingPrivacyPolicy, false); assert.ok(failed.privacyErrorMessage);
  await failed.acceptPrivacyPolicy();
  assert.equal(accepted, true); assert.equal(saved, 1); assert.equal(restored, 1);
  const busy = gate(); busy.isAcceptingPrivacyPolicy = true;
  await busy.rejectPrivacyPolicy(); assert.equal(exits, 2, 'acceptance and rejection are mutually exclusive');
  const dead = gate(); dead.isIndexAlive = false;
  await dead.rejectPrivacyPolicy(); assert.equal(exits, 2);
  storedConsent = true; const returning = gate(); await returning.loadPrivacyConsent();
  assert.equal(restored, 2); assert.equal(accepted, true);
  // UI must not instantiate Home/Web before the consent gate has resolved.
  assert.match(source, /if \(!this\.privacyReady\)[\s\S]*else if \(!this\.privacyAccepted\)[\s\S]*else \{\s*Navigation/);
  assert.match(source, /void this\.rejectPrivacyPolicy\(\)/);
  const policySource = fs.readFileSync(path.join(project, 'entry/src/main/ets/domain/privacy/FourD4yPrivacyPolicy.ets'), 'utf8');
  const policy = {};
  vm.runInNewContext(ts.transpileModule(policySource, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: policy });
  const doc = fs.readFileSync(path.join(project, 'docs/PRIVACY_POLICY.md'), 'utf8');
  assert.ok(doc.includes(policy.FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT));
  assert.ok(doc.includes(policy.FOUR_D4Y_PRIVACY_POLICY_VERSION));
  assert.ok(doc.includes(policy.FOUR_D4Y_PRIVACY_CONTACT));
  assert.ok(source.includes('FOUR_D4Y_PRIVACY_POLICY_UPDATED_AT'));
  assert.ok(source.includes('FOUR_D4Y_PRIVACY_CONTACT'));
  for (const file of ['README.md', 'docs/PRIVACY_POLICY.md', 'entry/src/main/ets/pages/Index.ets']) {
    assert.ok(!fs.readFileSync(path.join(project, file), 'utf8').includes('sis5595@hotmail.com'));
  }
  console.log('Privacy revision, documentation parity, refusal/exit and pre-consent account gate passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
