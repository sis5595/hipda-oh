// Exercise production update/export handlers without ArkUI, a real picker or installer.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname, '../../main/ets/presentation/about/UpdatePanel.ets'), 'utf8');
const methods = source.slice(source.indexOf('  private async check()'), source.lastIndexOf('}'));
let checkValue, checkFailure = '', verifyFailure = '', downloadFailure = '', shareFailure = '';
let pendingCheck = null, pendingPicker = null, afterPicker = null, afterCopy = null;
let shares = [], abilityCalls = [], abilityFailure = '', pickerOptions = [];
let destinations = ['file://docs/Download/update.hap'], pickerFailure = '', copyFailure = '', openFailure = '';
let opened = [], closed = [], copyCalls = 0, verifyCalls = 0, savedSize = 128;
const candidate = { versionName: '1.0.0-beta.6', versionCode: 1000007, size: 128,
  fileName: 'hipda-oh-1.0.0-beta.6-unsigned.hap', notes: 'new' };
class Service {
  async check(code) { assert.equal(code, 1000006); if (pendingCheck) return pendingCheck;
    if (checkFailure) throw Error(checkFailure); return checkValue; }
  async download(value, dir, progress) {
    assert.equal(value, candidate); assert.equal(dir, '/cache');
    progress(25, 100); if (downloadFailure) throw Error(downloadFailure); progress(100, 100); return '/verified/file.hap';
  }
  async verifyForExport(value, file) {
    verifyCalls++;
    assert.equal(value, candidate); assert.equal(file, '/verified/file.hap');
    if (verifyFailure) throw Error(verifyFailure);
  }
}
const exportFs = {
  OpenMode: { READ_ONLY: 1, WRITE_ONLY: 2, TRUNC: 4 },
  openSync(file, mode) {
    if (openFailure && file.startsWith('file://')) throw Error(openFailure);
    const handle = { fd: opened.length + 1, file, mode }; opened.push(handle); return handle;
  },
  async copyFile(from, to) {
    copyCalls++;
    assert.equal(opened.find(f => f.fd === from).file, '/verified/file.hap');
    assert.equal(opened.find(f => f.fd === to).file, destinations[0]);
    if (afterCopy) afterCopy();
    if (copyFailure) throw Error(copyFailure);
  },
  statSync: () => ({ size: savedSize }),
  closeSync: file => { closed.push(file.fd); }
};
const exported = {};
vm.runInNewContext(ts.transpileModule('class Panel {' + methods + '} exports.Panel = Panel;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: exported, GitHubUpdateService: Service,
  updateErrorMessage: code => 'friendly:' + code, UPDATE_RELEASES: 'https://github.com/sis5595/hipda-oh/releases',
  fileUri: { getUriFromPath: p => 'file://' + p }, fs: exportFs,
  picker: {
    DocumentSaveOptions: class {},
    DocumentViewPicker: class {
      async save(options) {
        pickerOptions.push(options);
        if (pickerFailure) throw Error(pickerFailure);
        if (pendingPicker) return pendingPicker;
        if (afterPicker) afterPicker();
        return destinations;
      }
    }
  },
  utd: { UniformDataType: { FILE: 'general.file' }, getUniformDataTypeByFilenameExtension: () => 'hap-utd' },
  systemShare: {
    SharedData: class { constructor(data) { shares.push(data); } },
    ShareController: class { async show() { if (shareFailure) throw Error(shareFailure); } },
    SelectionMode: { SINGLE: 1 }, SharePreviewMode: { DETAIL: 1 }
  }
});
function panel() {
  return Object.assign(new exported.Panel(), { alive: true, busy: false, installedCode: '1000006',
    candidate: undefined, verifiedPath: '', percent: 0, downloading: false, status: '',
    getUIContext: () => ({ getHostContext: () => ({ cacheDir: '/cache',
      startAbility: async want => { abilityCalls.push(want); if (abilityFailure) throw Error(abilityFailure); } }) })
  });
}
function resetCopy() { opened = []; closed = []; copyCalls = 0; savedSize = candidate.size; }
(async () => {
  const p = panel();
  await p.check(); assert.match(p.status, /最新/); assert.equal(p.busy, false);
  checkValue = candidate;
  await p.check(); assert.equal(p.candidate, candidate);
  await p.download();
  assert.equal(p.percent, 100); assert.equal(p.verifiedPath, '/verified/file.hap');
  assert.equal(p.status, '安装包已下载并校验完成。请使用支持 HarmonyOS NEXT 的安装工具完成签名和安装。');
  await p.share();
  assert.equal(abilityCalls.length, 0, 'file export must never launch a hard-coded installer');
  assert.equal(shares[0].uri, 'file:///verified/file.hap'); assert.equal(shares[0].title, candidate.fileName);
  assert.match(p.status, /不代表安装成功/);
  verifyFailure = 'update-network';
  const beforeShare = shares.length; await p.share();
  assert.equal(shares.length, beforeShare); assert.match(p.status, /friendly:update-network/);
  assert.equal(p.verifiedPath, '/verified/file.hap', 'transient verification failure permits retry');
  verifyFailure = 'update-checksum'; await p.share();
  assert.equal(shares.length, beforeShare, 'corrupt file must never reach share');
  assert.equal(p.verifiedPath, ''); assert.match(p.status, /update-checksum/);
  p.verifiedPath = '/verified/file.hap'; const beforePicker = pickerOptions.length; await p.save();
  assert.equal(pickerOptions.length, beforePicker, 'corrupt file must not reach save picker');
  assert.equal(p.verifiedPath, ''); assert.equal(copyCalls, 0);
  verifyFailure = ''; await p.download();
  shareFailure = 'no compatible target'; await p.share();
  assert.match(p.status, /保存安装包/); assert.equal(p.busy, false);
  shareFailure = ''; await p.share(); assert.match(p.status, /不代表安装成功/);
  resetCopy(); const beforeSaveVerify = verifyCalls; await p.save();
  assert.equal(copyCalls, 1); assert.equal(verifyCalls - beforeSaveVerify, 2, 'verify before picker and after it returns');
  assert.equal(opened[0].mode, exportFs.OpenMode.READ_ONLY);
  assert.equal(opened[1].mode, exportFs.OpenMode.WRITE_ONLY | exportFs.OpenMode.TRUNC);
  assert.deepEqual(closed.sort(), [1, 2]);
  assert.deepEqual(Array.from(pickerOptions.at(-1).newFileNames), [candidate.fileName]);
  assert.deepEqual(Array.from(pickerOptions.at(-1).fileSuffixChoices), ['HarmonyOS 安装包|.hap']);
  assert.match(p.status, /已保存到所选位置/); assert.match(p.status, /保存不代表安装成功/);
  resetCopy(); destinations = []; await p.save();
  assert.equal(copyCalls, 0); assert.equal(opened.length, 0); assert.match(p.status, /已取消保存/);
  assert.equal(p.verifiedPath, '/verified/file.hap'); assert.equal(p.busy, false);
  destinations = ['file://docs/Download/update.hap'];
  pickerFailure = 'cancelled'; await p.save();
  assert.match(p.status, /保存未完成/); assert.equal(p.busy, false); assert.equal(opened.length, 0);
  pickerFailure = ''; destinations = ['one', 'two']; await p.save();
  assert.equal(opened.length, 0, 'ambiguous destination must not be written');
  destinations = ['file://docs/Download/update.hap'];
  afterPicker = () => { verifyFailure = 'update-checksum'; }; await p.save();
  assert.equal(opened.length, 0, 'file changed while picker was open must not be written');
  assert.equal(p.verifiedPath, ''); assert.match(p.status, /update-checksum/);
  afterPicker = null; verifyFailure = ''; await p.download();
  openFailure = 'access denied'; resetCopy(); await p.save();
  assert.equal(copyCalls, 0); assert.deepEqual(closed, [1], 'close source if destination cannot open');
  assert.match(p.status, /保存未完成/); assert.equal(p.busy, false);
  openFailure = ''; copyFailure = 'disk full'; resetCopy(); await p.save();
  assert.equal(copyCalls, 1); assert.deepEqual(closed.sort(), [1, 2]);
  assert.match(p.status, /不完整文件/); assert.equal(p.busy, false);
  copyFailure = ''; resetCopy(); savedSize = candidate.size - 1; await p.save();
  assert.match(p.status, /保存未完成/); assert.deepEqual(closed.sort(), [1, 2]);
  resetCopy(); await p.save(); assert.match(p.status, /已保存到所选位置/, 'retry succeeds after storage failure');
  resetCopy(); let finishPicker;
  pendingPicker = new Promise(resolve => { finishPicker = resolve; });
  const leaving = panel(); leaving.candidate = candidate; leaving.verifiedPath = '/verified/file.hap';
  const pendingSave = leaving.save(); await new Promise(resolve => setImmediate(resolve));
  const previousSaveStatus = leaving.status; leaving.alive = false; finishPicker(destinations); await pendingSave;
  assert.equal(opened.length, 0, 'leaving page while picker is open must not write a file');
  assert.equal(leaving.status, previousSaveStatus); pendingPicker = null;
  const copying = panel(); copying.candidate = candidate; copying.verifiedPath = '/verified/file.hap';
  afterCopy = () => { copying.alive = false; }; await copying.save();
  assert.deepEqual(closed.sort(), [1, 2]); assert.equal(copying.status, '', 'no late status update after copy');
  afterCopy = null;
  const locked = panel(); locked.busy = true; locked.candidate = candidate; locked.verifiedPath = '/verified/file.hap';
  const callsBeforeBusy = verifyCalls; await locked.save(); await locked.share();
  assert.equal(verifyCalls, callsBeforeBusy, 'busy guard excludes concurrent exports');
  downloadFailure = 'update-cancelled'; await p.download();
  assert.equal(p.downloading, false); assert.equal(p.verifiedPath, ''); assert.equal(p.busy, false);
  downloadFailure = ''; checkFailure = 'update-rate-limit'; await p.check();
  assert.match(p.status, /update-rate-limit/); assert.equal(p.candidate, undefined); checkFailure = '';
  abilityFailure = 'browser unavailable'; await p.openDownloads();
  assert.match(p.status, /github.com\/sis5595\/hipda-oh\/releases/);
  assert.equal(abilityCalls.at(-1).uri, 'https://github.com/sis5595/hipda-oh/releases');
  assert.equal(abilityCalls.at(-1).bundleName, undefined, 'browser fallback does not bind an installer');
  let complete; pendingCheck = new Promise(resolve => { complete = resolve; });
  const detached = panel(); const pending = detached.check(); detached.alive = false;
  const previousStatus = detached.status; complete(candidate); await pending;
  assert.equal(detached.candidate, undefined); assert.equal(detached.status, previousStatus);
  assert.match(source, /aboutToDisappear\(\)[\s\S]*?this\.service\?\.cancel\(\)/);
  console.log('PASS update panel: neutral share/save, integrity gates, picker cancellation, storage failures, retries and disposed callbacks.');
})().catch(error => { console.error(error); process.exitCode = 1; });
