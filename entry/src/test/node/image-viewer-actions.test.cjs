// Exercise production actions while album creation/download is suspended.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/image/ImageViewerPage.ets'), 'utf8');
const renderOutput = {};
const renderStart = source.indexOf('  private createRenderedImageCallback(');
const renderEnd = source.indexOf('  private loadActiveFullImage()', renderStart);
assert.ok(renderStart >= 0 && renderEnd > renderStart);
vm.runInNewContext(ts.transpileModule('class RenderState {' + source.slice(renderStart, renderEnd) +
  '} exports.RenderState = RenderState;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: renderOutput,
  FourD4yAuthenticatedImageLoader: { isAuthenticatedAttachmentUrl: url => url.includes('attachment.php') } });
const render = new renderOutput.RenderState();
const attachment = { key: 'a', url: 'https://synthetic/attachment.php?aid=1', previewUrl: 'preview' };
Object.assign(render, { isViewerActive: true, activeImageIndex: 0,
  activeAnimationPath: '',
  imageRoute: { items: [attachment], threadId: '123' }, imageLoadStates: ['loading'] });
render.onRenderedImageResult(attachment, 0, 'preview', true);
assert.equal(render.imageLoadStates[0], 'loading', 'thumbnail success must not finish original download');
render.onRenderedImageResult(attachment, 0, 'preview', false);
assert.equal(render.imageLoadStates[0], 'loading', 'thumbnail failure must not abort original download');
render.imageLoadStates = ['preview-failed'];
render.onRenderedImageResult(attachment, 0, 'preview', true);
assert.equal(render.imageLoadStates[0], 'preview-failed', 'late thumbnail must preserve original failure');
const pixels = {};
const latePreviewFailure = render.createRenderedImageCallback(attachment, 0, 'preview', false);
render.activeFullImage = pixels;
render.activeFullImageKey = 'a';
render.imageLoadStates = ['ready'];
latePreviewFailure();
assert.equal(render.imageLoadStates[0], 'ready', 'registered callback keeps its original source identity');
render.onRenderedImageResult(attachment, 0, 'preview', false);
assert.equal(render.imageLoadStates[0], 'ready', 'old preview must not invalidate new original');
render.onRenderedImageResult(attachment, 0, pixels, false);
assert.equal(render.imageLoadStates[0], 'failed', 'current original rendering failure remains visible');
render.onRenderedImageResult(attachment, 0, pixels, true);
assert.equal(render.imageLoadStates[0], 'ready');
render.imageLoadStates = ['scaled-preview'];
render.onRenderedImageResult(attachment, 0, pixels, true);
assert.equal(render.imageLoadStates[0], 'scaled-preview', 'render completion cannot hide the preview disclosure');
render.imageLoadStates = ['ready'];
render.isViewerActive = false;
render.onRenderedImageResult(attachment, 0, pixels, false);
assert.equal(render.imageLoadStates[0], 'ready', 'destroyed view ignores render callbacks');
const publicImage = { key: 'b', url: 'https://synthetic/public.jpg', previewUrl: 'https://synthetic/public.jpg' };
render.isViewerActive = true;
render.imageRoute.items = [publicImage];
render.imageLoadStates = ['loading'];
assert.equal(render.getImageRenderSource(publicImage, 0), '', 'same-URL public preview cannot bypass the decode budget');
render.onRenderedImageResult(publicImage, 0, publicImage.url, false);
assert.equal(render.imageLoadStates[0], 'loading', 'public URL must not bypass bounded native decode');
render.onRenderedImageResult(publicImage, 0, publicImage.url, true);
assert.equal(render.imageLoadStates[0], 'loading');
render.activeFullImageKey = 'b';
render.onRenderedImageResult(publicImage, 0, pixels, true);
assert.equal(render.imageLoadStates[0], 'ready');
render.imageLoadStates = ['static-preview'];
render.onRenderedImageResult(publicImage, 0, pixels, true);
assert.equal(render.imageLoadStates[0], 'static-preview');
assert.ok(source.includes('原图加载失败，当前仅为预览图'), 'fallback must be visibly identified');
assert.match(source, /Image\(this\.getImageRenderSource\(item, index\)\)/,
  'Image must observe state directly, not a frozen by-value Builder source parameter');
const lifecycleOutput = {};
const lifecycle = source.slice(source.indexOf('  aboutToDisappear()'), source.indexOf('  build()'));
const cleanup = source.slice(source.indexOf('  private releaseActiveFullImage()'),
  source.indexOf('  private getImageZoomScale('));
vm.runInNewContext(ts.transpileModule('class Lifecycle {' + lifecycle + cleanup +
  '} exports.Lifecycle = Lifecycle;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: lifecycleOutput });
let pixelReleases = 0;
const leavingViewer = new lifecycleOutput.Lifecycle();
Object.assign(leavingViewer, { isViewerActive: true, fullImageLoadSequence: 1,
  fullImageLoader: { cancelActiveDownload: () => {} }, activeFullImageKey: 'a',
  activeFullImage: { release: async () => { pixelReleases++; } } });
leavingViewer.aboutToDisappear();
assert.equal(leavingViewer.activeFullImage, undefined, 'released pixels must not remain a render source');
assert.equal(leavingViewer.activeFullImageKey, '');
leavingViewer.aboutToDisappear();
assert.equal(pixelReleases, 1, 'cleanup must be idempotent');
const start = source.indexOf('  private getActiveImageItem()');
const end = source.indexOf('  private async copyPreparedImageToOpenAsset(', start);
assert.ok(start >= 0 && end > start);
let assetReady, downloadReady, releaseCount = 0, closeCount = 0, shares = 0;
let downloads = [], assetExtensions = [], now = 1000;
const dependencies = {
  Date: { now: () => now },
  fs: { accessSync: () => false, openSync: () => ({ fd: 1 }), closeSync: () => { closeCount++; },
    OpenMode: { READ_WRITE: 1, CREATE: 2 } },
  photoAccessHelper: { PhotoType: { IMAGE: 1 }, getPhotoAccessHelper: () => ({
    createAsset: (_type, extension) => {
      assetExtensions.push(extension);
      return new Promise(resolve => { assetReady = resolve; });
    },
    release: async () => { releaseCount++; }
  }) },
  utd: { getUniformDataTypeByFilenameExtension: extension => extension, UniformDataType: { IMAGE: 'image' } },
  fileUri: { getUriFromPath: path => path },
  systemShare: { SharedData: class {}, ShareController: class {
    async show() { shares++; }
  }, SelectionMode: { SINGLE: 1 }, SharePreviewMode: { DETAIL: 1 } }
};
const output = {};
vm.runInNewContext(ts.transpileModule('class Viewer {' + source.slice(start, end) +
  '} exports.Viewer = Viewer;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, { exports: output, ...dependencies });
function viewer() {
  const instance = new output.Viewer();
  Object.assign(instance, {
    activeImageIndex: 0, imageActionState: '', isViewerActive: true,
    imageRoute: { items: [{ key: 'a', url: 'https://example.com/a.png' },
      { key: 'b', url: 'https://example.com/b.jpg' }], threadId: '123', viewerUserId: '456', forumId: '2' },
    getUIContext: () => ({ getHostContext: () => ({ cacheDir: '/synthetic-cache' }) }),
    showImageActionToast: () => {},
    copyPreparedImageToOpenAsset: () => true,
    imageExport: { prepare: async (...args) => {
      downloads.push(args);
      return new Promise(resolve => { downloadReady = resolve; });
    } }
  });
  return instance;
}
async function tick() { await new Promise(resolve => setImmediate(resolve)); }
(async () => {
  const save = viewer();
  const saving = save.saveCurrentImageWithTemporaryGrant();
  save.activeImageIndex = 1;
  save.imageRoute.threadId = '999';
  save.imageRoute.viewerUserId = '888';
  assert.equal(assetExtensions.length, 0, 'download/validation must precede album creation');
  assert.deepEqual(downloads[0], ['/synthetic-cache', 'https://example.com/a.png', '123', '456', '2']);
  downloadReady({ filePath: '/synthetic-cache/a.gif', extension: 'gif' });
  await tick();
  assert.equal(assetExtensions[0], 'gif', 'album type comes from validated bytes, not a URL suffix');
  assetReady('file://synthetic-album');
  await saving;
  assert.equal(releaseCount, 1);
  assert.equal(closeCount, 1);
  assert.equal(save.imageActionState, '');

  const share = viewer();
  const sharing = share.shareCurrentImage();
  share.activeImageIndex = 1;
  share.isViewerActive = false;
  downloadReady({ filePath: '/synthetic-cache/a.png', extension: 'png' });
  await sharing;
  assert.equal(shares, 0, 'leaving the viewer must not open a late share panel');
  assert.equal(share.imageActionState, 'sharing', 'a destroyed viewer must not mutate reactive state');

  const leavingSave = viewer();
  const leftSaving = leavingSave.saveCurrentImageWithTemporaryGrant();
  leavingSave.isViewerActive = false;
  leavingSave.getUIContext = () => { throw new Error('destroyed UI context'); };
  downloadReady({ filePath: '/synthetic-cache/a.png', extension: 'png' });
  await leftSaving;
  assert.equal(assetExtensions.length, 1, 'leaving during download must not create a late album entry');
  assert.equal(leavingSave.imageActionState, 'saving');

  const failure = viewer();
  const failing = failure.saveCurrentImageWithTemporaryGrant();
  downloadReady(undefined);
  await failing;
  assert.equal(assetExtensions.length, 1, 'failed download leaves no empty album entry');
  assert.equal(releaseCount, 1);
  assert.equal(closeCount, 1);
  const slow = viewer(), slowNotices = [];
  slow.showImageActionToast = value => slowNotices.push(value);
  const slowSaving = slow.saveCurrentImageWithTemporaryGrant();
  now += 56000;
  downloadReady({ filePath: '/synthetic-cache/a.png', extension: 'png' });
  await slowSaving;
  assert.equal(assetExtensions.length, 1, 'do not consume an almost-expired SaveButton grant');
  assert.equal(slow.preparedImagePath, '/synthetic-cache/a.png', 'a retry can reuse downloaded bytes');
  assert.ok(slowNotices.some(value => value.includes('再次点击')));
  assert.equal(slow.imageActionState, '');
  const asyncFailure = viewer(), notices = [];
  asyncFailure.showImageActionToast = value => notices.push(value);
  asyncFailure.copyPreparedImageToOpenAsset = async () => false;
  const rejectedSave = asyncFailure.saveCurrentImageWithTemporaryGrant();
  downloadReady({ filePath: '/synthetic-cache/a.png', extension: 'png' });
  await tick();
  assetReady('file://synthetic-album');
  await rejectedSave;
  assert.equal(notices.some(value => value.includes('图片已保存')), false,
    'an unresolved Promise is not a successful copy');
  assert.equal(notices.some(value => value.includes('保存图片失败')), true);
  const copyStart = source.indexOf('  private async copyPreparedImageToOpenAsset(');
  const copyEnd = source.indexOf('  private showImageActionToast(', copyStart);
  const copyOutput = {}, closed = [];
  let finishCopy, rejectCopy, size = 1024, copyCalls = 0;
  vm.runInNewContext(ts.transpileModule('class Copier {' + source.slice(copyStart, copyEnd) +
    '} exports.Copier = Copier;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
      module: ts.ModuleKind.CommonJS } }).outputText, { exports: copyOutput, fs: {
    OpenMode: { READ_ONLY: 0 }, openSync: () => ({ fd: 10 }),
    statSync: () => ({ size }), closeSync: file => closed.push(file.fd),
    copyFile: (src, dest) => {
      assert.equal(src, 10); assert.equal(dest, 20); copyCalls++;
      return new Promise((resolve, reject) => { finishCopy = resolve; rejectCopy = reject; });
    }
  } });
  const copier = new copyOutput.Copier();
  const copying = copier.copyPreparedImageToOpenAsset('/synthetic-source', { fd: 20 });
  assert.equal(copyCalls, 1, 'copy via the system API without allocating a full image-sized JS buffer');
  assert.deepEqual(closed, [], 'source descriptor stays open while async copy is pending');
  finishCopy();
  assert.equal(await copying, true);
  assert.deepEqual(closed, [10], 'destination descriptor belongs to the save operation');
  const failedCopy = copier.copyPreparedImageToOpenAsset('/synthetic-source', { fd: 20 });
  rejectCopy(new Error('synthetic copy failure'));
  assert.equal(await failedCopy, false);
  assert.deepEqual(closed, [10, 10]);
  size = 33 * 1024 * 1024;
  assert.equal(await copier.copyPreparedImageToOpenAsset('/synthetic-source', { fd: 20 }), false);
  assert.equal(copyCalls, 2, 'oversized inputs never start copying');
  console.log('Image viewer action snapshot and lifecycle regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
