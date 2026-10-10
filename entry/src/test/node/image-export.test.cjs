const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
let mime = 'image/png', invalid = false, zeroSize = false, writes = 0, released = 0, destroyed = 0;
let closed = 0, removed = [], holdWrite = false, resumeWrite;
const now = 1791360000000;
const day = 24 * 60 * 60 * 1000;
const exportName = (stamp, suffix = '1.jpg') => `hipdaoh-image-export-${stamp}-${suffix}`;
let cacheEntries = [], cacheStats = new Map(), cleaned = [], failListing = false;
const bytes = new ArrayBuffer(12);
const fakeFs = {
  OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4 },
  openSync: () => ({ fd: 1 }), writeSync: (_fd, value) => { writes++; return value.byteLength; },
  closeSync: () => { closed++; }, accessSync: () => true,
  unlinkSync: value => { removed.push(value); },
  listFile: async (_dir, options) => {
    assert.equal(options.recursion, false);
    if (failListing) throw new Error('synthetic list failure');
    return cacheEntries;
  },
  stat: async value => {
    const entry = cacheStats.get(path.posix.basename(value));
    if (!entry) throw new Error('synthetic stat failure');
    return { isFile: () => !entry.directory, mtime: entry.mtime / 1000 };
  },
  unlink: async value => { cleaned.push(value); },
  write: (_fd, value) => {
    writes++;
    return holdWrite ? new Promise(resolve => { resumeWrite = resolve; }) : Promise.resolve(value.byteLength);
  }
};
const http = {
  RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 1 }, ResponseCode: { OK: 200 },
  createHttp: () => ({ request: async (_url, options) => {
    assert.equal(options.maxLimit, 32 * 1024 * 1024);
    assert.equal(options.header.Cookie, undefined);
    return { responseCode: 200, result: bytes };
  }, destroy: () => { destroyed++; } })
};
const image = { createImageSource: () => ({
  getImageInfo: async () => {
    if (invalid) throw new Error('invalid encoded image');
    return { size: { width: zeroSize ? 0 : 20, height: 30 }, mimeType: mime };
  }, release: async () => { released++; }
}) };
const dependencies = {
  '@ohos.file.fs': { default: fakeFs }, '@ohos.net.http': { default: http }, '@kit.ImageKit': { image },
  './FourD4yAuthenticatedImageLoader': { FourD4yAuthenticatedImageLoader: class {
    static isAuthenticatedAttachmentUrl() { return false; }
  } }
};
const output = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/data/remote/FourD4yImageExport.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: output, require: name => {
  assert.ok(name in dependencies, name); return dependencies[name];
}, ArrayBuffer, Date: class extends Date { static now() { return now; } } });
(async () => {
  const old = exportName(now - 8 * day);
  const recent = exportName(now - day);
  const future = exportName(now + day);
  const touched = exportName(now - 9 * day, '2.png');
  const directory = exportName(now - 10 * day, '3.jpg');
  cacheEntries = [old, recent, future, touched, directory, '../' + old, 'sub/' + old,
    'user-photo.jpg', 'hipdaoh-image-export-not-ours.jpg', exportName(now - 8 * day, '9.txt')];
  cacheStats = new Map([[old, { mtime: now - 8 * day }], [recent, { mtime: now - day }],
    [touched, { mtime: now }], [directory, { mtime: now - 10 * day, directory: true }]]);
  await output.FourD4yImageExport.cleanupExpiredExports('/synthetic-cache');
  assert.deepEqual(cleaned, ['/synthetic-cache/' + old],
    'remove only expired owned export files, with seconds converted to milliseconds');
  cleaned = [];
  cacheEntries = Array.from({ length: 100 }, (_, index) => exportName(now - 8 * day, `${index + 1}.jpg`));
  cacheStats = new Map(cacheEntries.map(name => [name, { mtime: now - 8 * day }]));
  await output.FourD4yImageExport.cleanupExpiredExports('/synthetic-cache');
  assert.equal(cleaned.length, 64, 'housekeeping has a per-process candidate budget');
  cleaned = []; failListing = true;
  await output.FourD4yImageExport.cleanupExpiredExports('/synthetic-cache');
  assert.deepEqual(cleaned, [], 'cleanup failure must not prevent a user export');
  cacheEntries = [];
  const exporter = new output.FourD4yImageExport();
  const prepare = () => exporter.prepare('/synthetic-cache', 'https://example.com/wrong.jpg', '', '', '');
  const result = await prepare();
  failListing = false;
  assert.ok(result, 'a listing failure does not block saving or sharing');
  assert.equal(result.extension, 'png', 'encoded type takes priority over URL suffix');
  assert.equal(writes, 1);
  invalid = true;
  assert.equal(await prepare(), undefined, 'HTML/error response must not be exported');
  invalid = false; zeroSize = true;
  assert.equal(await prepare(), undefined);
  zeroSize = false; mime = 'text/html';
  assert.equal(await prepare(), undefined);
  assert.equal(writes, 1);
  assert.equal(released, 4);
  assert.equal(destroyed, 4);
  mime = 'image/png'; holdWrite = true;
  const closedBefore = closed;
  let settled = false;
  const pending = prepare().then(value => { settled = true; return value; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(typeof resumeWrite, 'function', 'export must use asynchronous bulk file I/O');
  assert.equal(settled, false, 'do not publish a file before its bytes are written');
  assert.equal(closed, closedBefore, 'descriptor stays open until writing settles');
  resumeWrite(bytes.byteLength);
  assert.ok(await pending);
  assert.equal(closed, closedBefore + 1);
  const shortWrite = prepare();
  await new Promise(resolve => setImmediate(resolve));
  resumeWrite(bytes.byteLength - 1);
  assert.equal(await shortWrite, undefined, 'partial output is never a successful export');
  assert.equal(removed.length, 1);
  assert.match(removed[0], /^\/synthetic-cache\/hipdaoh-image-export-\d+-\d+\.png$/);
  console.log('Image export content validation regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
