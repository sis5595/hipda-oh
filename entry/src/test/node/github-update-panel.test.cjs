// Exercise production event handlers without ArkUI rendering or a real installer.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/about/UpdatePanel.ets'), 'utf8');
const methods = source.slice(source.indexOf('  private async check()'), source.lastIndexOf('}'));
let checkValue, checkFailure = '', verifyFailure = '', downloadFailure = '', shareFailure = '', shareCalls = 0;
let pendingCheck = null, shares = [];
const candidate = { versionName: '1.0.0-beta.6', versionCode: 1000007,
  fileName: 'hipda-oh-1.0.0-beta.6-unsigned.hap', notes: 'new' };
class Service {
  async check(code) { assert.equal(code, 1000006); if (pendingCheck) return pendingCheck;
    if (checkFailure) throw Error(checkFailure); return checkValue; }
  async download(value, dir, progress) {
    assert.equal(value, candidate); assert.equal(dir, '/cache');
    progress(25, 100); if (downloadFailure) throw Error(downloadFailure); progress(100, 100); return '/verified/file.hap';
  }
  async verifyForSharing(value, file) {
    assert.equal(value, candidate); assert.equal(file, '/verified/file.hap');
    if (verifyFailure) throw Error(verifyFailure);
  }
}
const exported = {};
vm.runInNewContext(ts.transpileModule('class Panel {' + methods + '} exports.Panel = Panel;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exported, GitHubUpdateService: Service,
  updateErrorMessage: code => 'friendly:' + code, UPDATE_RELEASES: 'https://github.com/sis5595/hipda-oh/releases',
  fileUri: { getUriFromPath: p => 'file://' + p },
  utd: { UniformDataType: { FILE: 'general.file' }, getUniformDataTypeByFilenameExtension: () => 'hap-utd' },
  systemShare: {
    SharedData: class { constructor(data) { shares.push(data); } },
    ShareController: class { async show() { shareCalls++; if (shareFailure) throw Error(shareFailure); } },
    SelectionMode: { SINGLE: 1 }, SharePreviewMode: { DETAIL: 1 }
  }
});
function panel() {
  return Object.assign(new exported.Panel(), { alive: true, busy: false, installedCode: '1000006',
    candidate: undefined, verifiedPath: '', percent: 0, downloading: false, status: '',
    getUIContext: () => ({ getHostContext: () => ({ cacheDir: '/cache',
      startAbility: async () => { throw Error('browser unavailable'); } }) })
  });
}
(async () => {
  const p = panel();
  await p.check();
  assert.match(p.status, /最新/);
  assert.equal(p.busy, false);
  checkValue = candidate;
  await p.check();
  assert.equal(p.candidate, candidate);
  await p.download();
  assert.equal(p.percent, 100);
  assert.equal(p.verifiedPath, '/verified/file.hap');
  assert.match(p.status, /校验通过/);
  verifyFailure = 'update-checksum';
  await p.share();
  assert.equal(shareCalls, 0, 'corrupt file must never reach system share');
  assert.equal(p.verifiedPath, '');
  assert.match(p.status, /update-checksum/);
  verifyFailure = '';
  await p.download();
  shareFailure = 'no compatible target';
  await p.share();
  assert.match(p.status, /电脑安装/);
  assert.equal(p.busy, false, 'missing installer must not leave buttons disabled');
  assert.equal(shares[0].uri, 'file:///verified/file.hap');
  shareFailure = '';
  await p.share();
  assert.match(p.status, /确认结果/);
  assert.doesNotMatch(p.status, /安装成功/, 'opening share is not installation success');
  downloadFailure = 'update-cancelled';
  await p.download();
  assert.equal(p.downloading, false);
  assert.equal(p.verifiedPath, '');
  assert.equal(p.busy, false);
  downloadFailure = '';
  checkFailure = 'update-rate-limit';
  await p.check();
  assert.match(p.status, /update-rate-limit/);
  assert.equal(p.candidate, undefined);
  checkFailure = '';
  await p.openDownloads();
  assert.match(p.status, /github.com\/sis5595\/hipda-oh\/releases/);
  let complete;
  pendingCheck = new Promise(resolve => { complete = resolve; });
  const detached = panel();
  const pending = detached.check();
  detached.alive = false;
  const previousStatus = detached.status;
  complete(candidate);
  await pending;
  assert.equal(detached.candidate, undefined);
  assert.equal(detached.status, previousStatus, 'no late UI update after disposal');
  assert.match(source, /aboutToDisappear\(\)[\s\S]*?this\.service\?\.cancel\(\)/);
  console.log('PASS update panel: up-to-date/new release, corrupt-file gate, missing installer, retry and disposed-page callbacks.');
})().catch(error => { console.error(error); process.exitCode = 1; });
