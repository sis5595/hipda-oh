const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
let requests = [], decodes = [], releasedPixels = 0, releasedSources = 0, destroyed = 0;
let activeAuth = true;
let redirectAllowed = true;
let sourceSize = { width: 4000, height: 3000 }, decodeOptions = [];
let sourceMime = 'image/jpeg', frameCount = 1, requestOptions = [];
const animationFiles = new Set();
let cacheListing = [], writeImpl = async (_fd, bytes) => bytes.byteLength;
const removedFiles = [];
const binary = new ArrayBuffer(16);
const image = { PixelMapFormat: { RGBA_8888: 3 }, DecodingDynamicRange: { SDR: 1 }, createImageSource: () => ({
  getImageInfo: async () => ({ size: sourceSize, mimeType: sourceMime }),
  getFrameCount: async () => frameCount,
  createPixelMap: options => new Promise(resolve => { decodeOptions.push(options); decodes.push(resolve); }),
  release: async () => { releasedSources++; }
}) };
const http = { RequestMethod: { GET: 1 }, HttpDataType: { ARRAY_BUFFER: 1 }, ResponseCode: { OK: 200 },
  createHttp: () => ({ request: (_url, options) => {
    requestOptions.push(options);
    assert.equal(options.maxLimit, 32 * 1024 * 1024);
    return new Promise(resolve => { requests.push(resolve); });
  }, destroy: () => { destroyed++; } }) };
const policy = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/reader/FourD4yImageDecodePolicy.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: policy });
const dependencies = { '@kit.ImageKit': { image }, '@ohos.net.http': { default: http },
  '@ohos.file.fs': { default: { OpenMode: { CREATE:1, READ_WRITE:2, TRUNC:4 },
    listFile: async () => cacheListing,
    open: async path => { animationFiles.add(path); return { fd:10 }; },
    write: (...args) => writeImpl(...args), close: async () => {},
    unlink: async path => { removedFiles.push(path); animationFiles.delete(path); } } },
  '../../domain/reader/FourD4yImageDecodePolicy': policy,
  './FourD4yNativeRedirectBoundary': { FourD4yNativeRedirectBoundary: class {
    constructor(_url, imageHosts) { assert.equal(imageHosts, true); }
    attach() {}
    isResponseAllowed() { return redirectAllowed; }
  } },
  './FourD4ySession': { FourD4ySession: {
    getCookieHeader: async () => 'synthetic-auth', hasAuthenticationCookie: () => true,
    createFullSiteCookieHeader: () => 'synthetic-auth',
    isCurrentAccountSessionSecret: async () => activeAuth,
    forumRoot: 'https://www.4d4y.com/forum/', fullSiteUserAgent: 'synthetic-agent'
  } } };
const exported = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/data/remote/FourD4yAuthenticatedImageLoader.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exported, ArrayBuffer, require: name => {
  assert.ok(name in dependencies, name); return dependencies[name];
} });
const tick = () => new Promise(resolve => setImmediate(resolve));
const respond = () => requests.shift()({ responseCode: 200, result: binary });
const pixel = () => ({ release: async () => { releasedPixels++; } });
const url = 'https://www.4d4y.com/forum/attachment.php?aid=123';
(async () => {
  const loader = new exported.FourD4yAuthenticatedImageLoader();
  let current = true;
  const canceled = loader.load(url, '123', '456', '51', () => current);
  await tick(); current = false; loader.cancelActiveDownload(); respond();
  assert.equal((await canceled).pixelMap, undefined);
  assert.equal(decodes.length, 0, 'an obsolete downloaded original must not be decoded');
  current = true;
  const changedAccount = loader.download(url, '123', '456', '51');
  await tick(); activeAuth = false; respond();
  assert.equal((await changedAccount).bytes, undefined, 'old-account binary response cannot be exposed');
  activeAuth = true;
  redirectAllowed = false;
  const denied = loader.download(url, '123', '456', '51');
  await tick(); respond();
  assert.equal((await denied).bytes, undefined, 'blocked redirect response cannot be decoded or exported');
  redirectAllowed = true;
  const first = loader.load(url, '123', '456', '51', () => current);
  await tick(); respond(); await tick();
  assert.equal(decodes.length, 1);
  current = false;
  const second = new exported.FourD4yAuthenticatedImageLoader().load(url, '123', '456', '51');
  await tick();
  assert.equal(requests.length, 0, 'queued originals must not retain downloaded buffers while a decoder is busy');
  assert.equal(decodes.length, 1, 'second decoder must wait for the first decoder to release obsolete pixels');
  decodes.shift()(pixel());
  assert.equal((await first).pixelMap, undefined);
  await tick(); respond();
  await tick(); assert.equal(decodes.length, 1);
  const expected = pixel(); decodes.shift()(expected);
  assert.equal((await second).pixelMap, expected);
  assert.equal(releasedPixels, 1);
  assert.equal(releasedSources, 2);
  assert.ok(destroyed >= 4);
  const blocking = loader.load(url, '123', '456', '51');
  await tick(); respond(); await tick();
  let queuedCurrent = true;
  const skipped = loader.load(url, '123', '456', '51', () => queuedCurrent);
  queuedCurrent = false;
  const latest = loader.load(url, '123', '456', '51');
  await tick(); assert.equal(requests.length, 0);
  decodes.shift()(pixel()); await blocking;
  assert.equal((await skipped).pixelMap, undefined);
  await tick(); assert.equal(requests.length, 1, 'stale queued item must not download; latest proceeds');
  respond(); await tick(); decodes.shift()(pixel()); await latest;
  assert.ok(decodeOptions.every(value => value === undefined), 'ordinary originals are never downsampled');
  sourceSize = { width: 10000, height: 10000 };
  const huge = loader.load(url, '123', '456', '51');
  await tick(); respond(); await tick();
  const options = decodeOptions[decodeOptions.length - 1];
  assert.ok(options.desiredSize.width * options.desiredSize.height <= policy.FOUR_D4Y_MAX_PREVIEW_PIXELS);
  assert.equal(options.desiredDynamicRange, image.DecodingDynamicRange.SDR);
  decodes.shift()(pixel());
  assert.equal((await huge).scaledPreview, true, 'preview must be explicitly identified to the view');
  for (const dimensions of [[0, 1], [NaN, 1], [1.5, 100], [Number.MAX_SAFE_INTEGER, 2]]) {
    assert.equal(policy.planFourD4yImageDecode(...dimensions), undefined);
  }
  for (const dimensions of [[1080, 30000], [6000, 8000], [1, 100000000], [100000000, 1], [8192, 4096]]) {
    const plan = policy.planFourD4yImageDecode(...dimensions);
    assert.ok(plan.width >= 1 && plan.height >= 1);
    assert.ok(plan.width * plan.height <= policy.FOUR_D4Y_MAX_PREVIEW_PIXELS);
    assert.equal(plan.scaledPreview, dimensions[0] * dimensions[1] > policy.FOUR_D4Y_MAX_PREVIEW_PIXELS);
  }
  sourceSize = { width: 8000, height: 8000 };
  const publicImage = loader.load('https://external.test/a.jpg', '', '', '', () => true, '/cache');
  await tick();
  const headers = requestOptions.at(-1).header;
  assert.equal(headers.Cookie, undefined);
  assert.equal(headers.Referer, undefined);
  respond(); await tick(); decodes.shift()(pixel());
  assert.equal((await publicImage).scaledPreview, true);
  sourceSize = { width: 100, height: 100 }; sourceMime = 'image/gif'; frameCount = 10;
  const animated = loader.load('https://external.test/animation', '', '', '', () => true, '/cache');
  await tick(); respond();
  const animationResult = await animated;
  assert.equal(animationResult.pixelMap, undefined);
  assert.ok(animationResult.animatedPath.endsWith('.gif'));
  assert.equal(animationFiles.size, 1, 'retain only validated animation bytes, not a second URL fetch');
  loader.releaseAnimation('/cache/not-owned');
  assert.equal(animationFiles.size, 1);
  loader.releaseAnimation(animationResult.animatedPath); await tick();
  assert.equal(animationFiles.size, 0);
  sourceSize = { width: 1000, height: 1000 }; frameCount = 100;
  const hugeAnimation = loader.load('https://external.test/b.gif', '', '', '', () => true, '/cache');
  await tick(); respond(); await tick(); decodes.shift()(pixel());
  assert.equal((await hugeAnimation).staticPreview, true, 'large animation must disclose static preview');
  assert.equal(animationFiles.size, 0);
  sourceSize = { width: 100, height: 100 }; frameCount = 10;
  let finishWrite, animationCurrent = true;
  writeImpl = () => new Promise(resolve => { finishWrite = resolve; });
  const canceledAnimation = loader.load('https://external.test/c.gif', '', '', '', () => animationCurrent, '/cache');
  await tick(); respond(); await tick();
  assert.equal(typeof finishWrite, 'function');
  animationCurrent = false; finishWrite(binary.byteLength);
  assert.equal((await canceledAnimation).animatedPath, undefined);
  await tick(); assert.equal(animationFiles.size, 0, 'cancel during async write deletes only its own transient file');
  const oldName = 'hipdaoh-image-animation-1700000000000-1.gif';
  const futureName = 'hipdaoh-image-animation-9999999999999-1.webp';
  cacheListing = [oldName, futureName, 'unrelated.gif', '../' + oldName, 'hipdaoh-image-export-1700000000000-1.gif'];
  const cleanupStart = removedFiles.length;
  await exported.FourD4yAuthenticatedImageLoader.cleanupOldAnimations('/cache');
  assert.deepEqual(removedFiles.slice(cleanupStart), ['/cache/' + oldName]);
  await exported.FourD4yAuthenticatedImageLoader.cleanupOldAnimations('/cache/../other');
  assert.equal(removedFiles.length, cleanupStart + 1, 'cleanup rejects traversal roots');
  console.log('Authenticated/public images: cancellation, ordered bounded decode, cookie isolation and animation lifecycle passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
