const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const start = source.indexOf('  private async saveAttachment(');
const end = source.indexOf('  private openPagePicker()', start);
assert.ok(start >= 0 && end > start);
let pickerReady, openReady, copies = 0, starts = 0, cancels = 0;
const removed = [], paths = [];
const output = {};
vm.runInNewContext(ts.transpileModule('let attachmentArtifactSequence = 0; class Reader {' +
  source.slice(start, end) + '} exports.Reader = Reader;', { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, {
  exports: output, console,
  Date: { now: () => 123456 },
  isAllowedFourD4yAttachmentDownloadUrl: () => true,
  createFourD4yAttachmentFileName: label => label,
  picker: { DocumentSaveOptions: class {}, DocumentViewPicker: class {
    save() { return new Promise(resolve => { pickerReady = resolve; }); }
  } },
  fileIo: { OpenMode: { READ_WRITE: 1, TRUNC: 2 },
    open: () => new Promise(resolve => { openReady = resolve; }),
    copyFile: async () => { copies++; }, close: async () => {},
    unlink: async path => { removed.push(path); }
  }, setTimeout, clearTimeout
});
function reader() {
  const instance = new output.Reader();
  Object.assign(instance, {
    isThreadPageAlive: true, isAttachmentPickerActive: false, isAttachmentDownloadActive: false,
    pendingAttachmentUrl: '', attachmentDestinationUri: '', attachmentTemporaryPath: '',
    attachmentDownloadGuid: '', attachmentDownloadSequence: 0, attachmentDownloadStartTimeoutId: -1,
    accountState: { getSessionGeneration: () => 1 },
    getUIContext: () => ({ getHostContext: () => ({ cacheDir: '/synthetic-cache' }) }),
    ensureAttachmentDownloadDelegate: () => true, showLinkToast: () => {},
    startAttachmentDownloadWatchdog: () => {}, clearAttachmentDownloadStartWatchdog: () => {},
    threadWebController: { startDownload: () => { starts++; } }
  });
  return instance;
}
function item(url, guid = 'download-a') {
  return { getOriginalUrl: () => url, getGuid: () => guid,
    getMimeType: () => 'application/octet-stream',
    cancel: () => { cancels++; }, start: path => { paths.push(path); } };
}
const url = 'https://www.4d4y.com/forum/attachment.php?aid=123';
(async () => {
  const left = reader();
  const abandoned = left.saveAttachment(url, 'a.rar');
  left.isThreadPageAlive = false;
  pickerReady(['file://synthetic-user/a.rar']);
  await abandoned;
  assert.equal(starts, 0, 'a picker result after leaving must not start downloading');
  const switched = reader();
  const oldSession = switched.saveAttachment(url, 'a.rar');
  switched.accountState.getSessionGeneration = () => 2;
  pickerReady(['file://synthetic-user/a.rar']);
  await oldSession;
  assert.equal(starts, 0);

  const first = reader(), second = reader();
  for (const instance of [first, second]) {
    const saving = instance.saveAttachment(url, 'a.rar');
    pickerReady(['file://synthetic-user/a.rar']);
    await saving;
    instance.onBeforeAttachmentDownload(item(url + '&old=1'));
    assert.equal(instance.pendingAttachmentUrl, url, 'unrelated callback cannot claim a later selection');
    instance.onBeforeAttachmentDownload(item(url));
  }
  assert.equal(cancels, 2);
  assert.equal(paths.length, 2);
  assert.notEqual(paths[0], paths[1], 'two reader instances must never share a temporary file');

  const finishing = first.onAttachmentDownloadFinished(item(url));
  await first.onAttachmentDownloadFinished(item(url));
  await first.onAttachmentDownloadFailed(item(url));
  openReady({ fd: 1 });
  await finishing;
  assert.equal(copies, 1, 'only one terminal callback may write to the selected document');
  await second.onAttachmentDownloadFailed(item(url));
  assert.ok(removed.every(path => path.startsWith('/synthetic-cache/')),
    'failure cleanup must never unlink a user-selected document');
  console.log('Attachment ownership, callback identity and lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
