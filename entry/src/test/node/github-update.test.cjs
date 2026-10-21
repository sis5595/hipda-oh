// Real policy/service methods with synthetic transport and files. No network or device mutations.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../../main/ets');
const timers = new Map();
let timerId = 0;
function load(file, dependencies) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText, { exports, require: dependencies, Uint8Array, ArrayBuffer,
    setTimeout: cb => { timers.set(++timerId, cb); return timerId; },
    clearTimeout: id => timers.delete(id) });
  return exports;
}
const policy = load('domain/update/GitHubUpdatePolicy.ets', () => { throw Error('unexpected import'); });
const hap = Buffer.from('synthetic unsigned HAP fixture');
const sha = crypto.createHash('sha256').update(hap).digest('hex');
const tag = 'v1.0.0-beta.10';
const fileName = 'hipda-oh-1.0.0-beta.10-unsigned.hap';
const base = policy.UPDATE_RELEASES + '/download/' + tag + '/';
const release = { tag_name: tag, draft: false, prerelease: true, body: '修复问题', assets: [
  { name: fileName, size: hap.length, browser_download_url: base + fileName },
  { name: 'SHA256SUMS.txt', size: 120, browser_download_url: base + 'SHA256SUMS.txt' }
] };
const version = { app: { bundleName: 'com.sis5595.hipdaoh', versionName: '1.0.0-beta.10', versionCode: 1000011 } };
const candidate = policy.makeUpdateCandidate(release, JSON.stringify(version));
assert.equal(policy.parseUpdateReleases(JSON.stringify([release])).length, 1, 'include prereleases');
assert.equal(policy.parseUpdateReleases(JSON.stringify([{ ...release, draft: true }])).length, 0);
assert.equal(policy.parseUpdateReleases(JSON.stringify([{ ...release, assets: [] }])).length, 0, 'source-only beta1');
assert.equal(policy.selectNewerUpdate([candidate], 1000006).versionCode, 1000011);
assert.equal(policy.selectNewerUpdate([candidate], 1000011), undefined);
assert.equal(policy.selectNewerUpdate([candidate], 1000012), undefined, 'never downgrade');
assert.equal(policy.selectNewerUpdate([{ ...candidate, versionName: '0.1', versionCode: 9999999 }, candidate],
  1000006).versionCode, 9999999, 'code, not label/order');
assert.throws(() => policy.selectNewerUpdate([candidate], NaN));
assert.throws(() => policy.makeUpdateCandidate(release, JSON.stringify({ app: { ...version.app, bundleName: 'other' } })));
assert.throws(() => policy.makeUpdateCandidate(release, JSON.stringify({ app: { ...version.app, versionName: '1.0.0' } })));
assert.throws(() => policy.makeUpdateCandidate({ ...release, assets: [release.assets[0]] }, JSON.stringify(version)));
assert.throws(() => policy.makeUpdateCandidate({ ...release, assets: [
  { ...release.assets[0], browser_download_url: 'https://mirror.invalid/a.hap' }, release.assets[1]
] }, JSON.stringify(version)));
assert.throws(() => policy.makeUpdateCandidate({ ...release, assets: [
  { ...release.assets[0], size: 1000000000 }, release.assets[1]
] }, JSON.stringify(version)));
for (const bad of ['../main', 'v1.0.0?q=a', 'v1.0.0/evil', 'main']) assert.throws(() => policy.updateVersionUrl(bad));
assert.equal(policy.parseUpdateChecksum(sha + '  ' + fileName + '\r\n', fileName), sha);
assert.equal(policy.parseUpdateChecksum('\ufeff' + sha.toUpperCase() + ' *' + fileName, fileName), sha);
for (const bad of ['wrong', sha + '  other.hap', sha + '  ../' + fileName,
  (sha + '  ' + fileName + '\n').repeat(2)]) assert.throws(() => policy.parseUpdateChecksum(bad, fileName));
for (const code of ['update-rate-limit', 'update-metadata', 'update-checksum', 'update-storage', 'update-network']) {
  assert.ok(policy.updateErrorMessage(code).length > 10);
}

const files = new Map(), handles = new Map();
let handleId = 0, responses = new Map(), calls = [], failWrite = false, attach = true, lateBody = false;
const fakeFs = {
  OpenMode: { CREATE: 1, TRUNC: 2, WRITE_ONLY: 4 },
  accessSync: p => p === '/cache/github-update' || files.has(p),
  mkdirSync: () => {},
  listFileSync: dir => [...files.keys()].filter(p => p.startsWith(dir + '/')).map(p => p.slice(dir.length + 1)),
  openSync: p => { const file = { fd: ++handleId }; files.set(p, Buffer.alloc(0)); handles.set(file.fd, p); return file; },
  writeSync: (fd, b) => {
    if (failWrite) throw Error('disk full');
    const p = handles.get(fd); files.set(p, Buffer.concat([files.get(p), Buffer.from(b)])); return b.byteLength;
  },
  closeSync: f => handles.delete(f.fd),
  unlinkSync: p => files.delete(p),
  renameSync: (a, b) => { files.set(b, files.get(a)); files.delete(a); },
  statSync: p => { if (!files.has(p)) throw Error('missing'); return { size: files.get(p).length }; }
};
const hash = { hash: async p => crypto.createHash('sha256').update(files.get(p)).digest('hex') };
const http = {
  InterceptorType: { REDIRECTION: 1 }, RequestMethod: { GET: 'GET' },
  HttpInterceptorChain: class {
    addChain(c) { this.guard = c[0]; return attach; }
    apply(r) { r.guard = this.guard; return true; }
  },
  createHttp() {
    return {
      destroyed: false,
      on(name, cb) { if (name === 'dataReceive') this.consume = cb; if (name === 'dataEnd') this.end = cb; },
      destroy() { this.destroyed = true; },
      async requestInStream(address, options) {
        calls.push(address);
        assert.equal(options.usingCache, false);
        assert.equal(Object.keys(options.header).some(k => /cookie|authorization/i.test(k)), false);
        assert.equal(options.method, 'GET');
        const response = responses.get(address);
        if (!response) throw Error('offline');
        if (response.redirect && !await this.guard.interceptorHandle({ url: response.redirect }, {})) throw Error('blocked');
        const emit = () => {
          if (this.destroyed) return;
          const b = Buffer.from(response.body || '');
          for (let i = 0; i < b.length; i += 7) {
            const chunk = b.subarray(i, i + 7);
            this.consume(Uint8Array.from(chunk).buffer);
            if (this.destroyed) return;
          }
          if (!response.noEnd) this.end();
        };
        if (lateBody) setImmediate(emit); else emit();
        return response.status || 200;
      }
    };
  }
};
const service = load('data/update/GitHubUpdateService.ets', id => {
  if (id === '@ohos.net.http') return { default: http };
  if (id === '@kit.CoreFileKit') return { fileIo: fakeFs, hash };
  if (id === '@kit.ArkTS') return { url: { URL }, util: { TextDecoder: class {
    decodeToString(b) { return new TextDecoder('utf-8', { fatal: true }).decode(b); }
  } } };
  return policy;
});
for (const address of [policy.UPDATE_API, policy.updateVersionUrl(tag), base + fileName,
  'https://release-assets.githubusercontent.com/github-production-release-asset/1/abc?sig=example']) {
  assert.equal(service.isOfficialUpdateUrl(address), true, address);
}
for (const address of ['http://github.com/sis5595/hipda-oh/releases', 'https://github.com.evil/a',
  'https://user:pass@api.github.com/repos/sis5595/hipda-oh/releases', 'https://github.com/other/hipda-oh/releases/download/v1.0.0/a',
  'https://raw.githubusercontent.com/sis5595/hipda-oh/main/AppScope/app.json5', 'file:///tmp/hap', 'https://mirror.invalid/a',
  'https://release-assets.githubusercontent.com:444/a', 'https://github.com\\@evil/a']) {
  assert.equal(service.isOfficialUpdateUrl(address), false, address);
}
function setup() {
  files.clear(); calls = []; failWrite = false; attach = true; lateBody = false;
  responses = new Map([
    [policy.UPDATE_API, { body: JSON.stringify([release, { ...release, assets: [], tag_name: 'v1.0.0-beta.1' }]) }],
    [policy.updateVersionUrl(tag), { body: JSON.stringify(version) }],
    [candidate.checksumUrl, { body: sha + '  ' + fileName }],
    [candidate.downloadUrl, { body: hap }]
  ]);
}
(async () => {
  setup();
  assert.equal((await new service.GitHubUpdateService().check(1000006)).versionCode, 1000011);
  assert.equal(await new service.GitHubUpdateService().check(1000011), undefined);
  const progress = [];
  const api = new service.GitHubUpdateService();
  const p = await api.download(candidate, '/cache', (n, total) => progress.push([n, total]));
  assert.equal(files.get(p).toString(), hap.toString());
  assert.equal(progress.at(-1)[0], hap.length);
  assert.equal(handles.size, 0);
  await api.verifyForSharing(candidate, p);
  files.set(p, Buffer.from('corrupted'));
  await assert.rejects(api.verifyForSharing(candidate, p), /update-checksum/);
  setup();
  responses.set(candidate.downloadUrl, { body: Buffer.alloc(hap.length, 5) });
  await assert.rejects(new service.GitHubUpdateService().download(candidate, '/cache', () => {}), /update-checksum/);
  assert.equal(files.size, 0, 'no corrupt/partial file available for share');
  setup();
  responses.set(candidate.downloadUrl, { body: Buffer.alloc(hap.length + 100) });
  await assert.rejects(new service.GitHubUpdateService().download(candidate, '/cache', () => {}), /update-checksum/);
  assert.equal(files.size, 0);
  setup(); failWrite = true;
  await assert.rejects(new service.GitHubUpdateService().download(candidate, '/cache', () => {}), /update-storage/);
  assert.equal(handles.size, 0);
  setup();
  const cancelled = new service.GitHubUpdateService();
  await assert.rejects(cancelled.download(candidate, '/cache', () => cancelled.cancel()), /update-cancelled/);
  assert.equal(files.size, 0);
  setup();
  responses.set(policy.UPDATE_API, { status: 429 });
  await assert.rejects(new service.GitHubUpdateService().check(1), /update-rate-limit/);
  setup(); responses.clear();
  await assert.rejects(new service.GitHubUpdateService().check(1));
  setup();
  responses.set(candidate.downloadUrl, { redirect: 'https://mirror.invalid/package', body: hap });
  await assert.rejects(new service.GitHubUpdateService().download(candidate, '/cache', () => {}));
  assert.equal(files.size, 0);
  setup(); attach = false;
  await assert.rejects(new service.GitHubUpdateService().check(1), /update-metadata/);
  assert.equal(calls.length, 0, 'fail closed without interceptor');
  setup(); lateBody = true;
  const late = new service.GitHubUpdateService();
  assert.equal((await late.check(1000006)).versionCode, 1000011);
  const latePath = await late.download(candidate, '/cache', () => {});
  assert.equal(files.get(latePath).toString(), hap.toString(), 'await dataEnd even when status resolves first');
  setup();
  responses.set(policy.UPDATE_API, { status: 200, noEnd: true });
  const waiting = new service.GitHubUpdateService();
  const waitingCheck = assert.rejects(waiting.check(1), /update-network/);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(timers.size, 1);
  [...timers.values()][0]();
  await waitingCheck;
  assert.equal(timers.size, 0, 'absolute timeout cleaned up');
  const cancelling = new service.GitHubUpdateService();
  const cancelledCheck = assert.rejects(cancelling.check(1), /update-cancelled/);
  await new Promise(resolve => setImmediate(resolve));
  cancelling.cancel();
  await cancelledCheck;
  assert.equal(timers.size, 0, 'cancellation settles even if native promise has returned but dataEnd never arrives');
  console.log('PASS GitHub updates: beta codes, trust boundary, progress, corruption, cancellation, rate limit, cleanup and share recheck.');
})().catch(error => { console.error(error); process.exitCode = 1; });
