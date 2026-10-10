// Synthetic secure-store/session boundary; no credentials or network.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
let state, active, alive, secret, restores, reads, failStore, failSave, onLoad;
const profiles = [{ id: 'synthetic-profile' }];
const dependencies = {
  '../../data/local/FourD4yAccountProfileStore': { FourD4yAccountProfileStore: {
    load: async () => { reads++; if (failStore) throw Error('synthetic'); return { activeProfileId: active, profiles }; },
    save: async (_ctx, registry) => { if (failSave) return false; active = registry.activeProfileId; return true; }
  } },
  '../../data/local/FourD4yAccountSessionStore': { FourD4yAccountSessionStore: {
    load: async () => { if (onLoad) onLoad(); return secret; }
  } },
  '../../data/remote/FourD4ySession': { FourD4ySession: {
    getAuthenticationState: async () => state,
    restoreAccountSessionSecret: async value => { restores.push(value); return true; }
  } },
  './FourD4yAccountContracts': {}
};
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'domain/account/FourD4yAccountService.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsObject, require: id => {
  assert.ok(id in dependencies, id); return dependencies[id];
} });
const service = exportsObject.FourD4yAccountService;
function reset() {
  state = 'absent'; active = 'synthetic-profile'; alive = true;
  secret = 'synthetic-secret'; restores = []; reads = 0;
  failStore = failSave = false; onLoad = null;
}
const run = () => service.restoreStartupSession({}, () => alive);
const loginSource = fs.readFileSync(path.join(root, 'presentation/login/LoginPage.ets'), 'utf8');
const refresh = loginSource.slice(loginSource.indexOf('  private async refreshLoginState()'),
  loginSource.indexOf('  private onControllerAttached()'));
const loginExports = {};
let logoutClears = 0;
vm.runInNewContext(ts.transpileModule('export class LoginProbe {\n' + refresh + '\n}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: loginExports,
  FourD4ySession: { captureAccountSessionSecret: async () => null, getAuthenticationState: async () => state },
  FourD4yAccountService: { forgetStartupSelection: async (_ctx, current) => {
    if (current()) logoutClears++;
  } }
});
(async () => {
  reset(); await run(); assert.deepEqual(restores, ['synthetic-secret']);
  for (const value of ['present', 'read-failed']) {
    reset(); state = value; await run(); assert.equal(restores.length, 0); assert.equal(reads, 0);
  }
  reset(); active = ''; await run(); assert.equal(restores.length, 0);
  reset(); active = 'missing'; await run(); assert.equal(restores.length, 0);
  reset(); secret = null; await run(); assert.equal(restores.length, 0);
  reset(); failStore = true; await run(); assert.equal(restores.length, 0);
  reset(); alive = false; await run(); assert.equal(reads, 0);
  reset(); onLoad = () => { alive = false; }; await run(); assert.equal(restores.length, 0);
  reset(); onLoad = () => { state = 'present'; }; await run(); assert.equal(restores.length, 0);
  reset(); await service.forgetStartupSelection({}); await run(); assert.equal(restores.length, 0);
  reset(); failSave = true; await assert.rejects(service.forgetStartupSelection({}));
  for (const diagnostic of ['absent', 'read-failed', 'present']) {
    reset(); state = diagnostic; logoutClears = 0;
    let generation = 0, mirrorClears = 0;
    const page = Object.assign(new loginExports.LoginProbe(), {
      verificationSequence: 0, hasPersistedVerifiedLogin: true,
      expectedUserId: '', lastVerifiedUserId: 'synthetic-user',
      getUIContext: () => ({ getHostContext: () => ({}) }),
      accountState: { getSessionGeneration: () => generation, markSessionChanged: () => generation++ },
      blacklistState: { clearServerSnapshot: () => mirrorClears++ },
      unreadState: { clear: () => mirrorClears++ }, favoriteState: { clear: () => mirrorClears++ },
      attentionState: { clear: () => mirrorClears++ }
    });
    await page.refreshLoginState();
    assert.equal(logoutClears, diagnostic === 'absent' ? 1 : 0);
    assert.equal(generation, diagnostic === 'absent' ? 1 : 0);
    assert.equal(mirrorClears, diagnostic === 'absent' ? 4 : 0);
  }
  console.log('Startup session restoration boundary regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
