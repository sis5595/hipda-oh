// Developer-only, read-only live smoke test. No credentials, uploads, installs or release changes.
// node scripts/verify-github-update.cjs <SDK typescript.js> [installedVersionCode]
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const ts = require(process.argv[2]);
const installed = Number(process.argv[3] || 1000005);
const root = path.resolve(__dirname, '..');
const policy = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'entry/src/main/ets/domain/update/GitHubUpdatePolicy.ets'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
}).outputText, { exports: policy });
function official(address) {
  const u = new URL(address);
  return u.protocol === 'https:' && !u.username && !u.password && !u.port &&
    ['api.github.com', 'raw.githubusercontent.com', 'github.com',
      'release-assets.githubusercontent.com', 'objects.githubusercontent.com'].includes(u.hostname);
}
async function get(address, limit, redirects = 0) {
  if (!official(address) || redirects > 5) throw Error('untrusted URL/redirect');
  const response = await fetch(address, { redirect: 'manual', headers: { 'User-Agent': 'HiPDAOH-release-verifier' },
    signal: AbortSignal.timeout(120000) });
  if ([301, 302, 303, 307, 308].includes(response.status)) {
    await response.body.cancel();
    return get(new URL(response.headers.get('location'), address).href, limit, redirects + 1);
  }
  if (response.status !== 200) throw Error('HTTP ' + response.status);
  let size = 0;
  const chunks = [];
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > limit) throw Error('response too large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
(async () => {
  const releases = policy.parseUpdateReleases((await get(policy.UPDATE_API, 2 * 1024 * 1024)).toString('utf8'));
  const candidates = [];
  for (const r of releases) {
    const candidate = policy.makeUpdateCandidate(r, (await get(policy.updateVersionUrl(r.tag_name), 16384)).toString('utf8'));
    candidates.push(candidate);
    console.log(candidate.tag + ' versionCode=' + candidate.versionCode);
  }
  const update = policy.selectNewerUpdate(candidates, installed);
  if (!update) { console.log('No newer installable release for versionCode=' + installed); return; }
  const expected = policy.parseUpdateChecksum((await get(update.checksumUrl, 16384)).toString('utf8'), update.fileName);
  const hap = await get(update.downloadUrl, update.size);
  const actual = crypto.createHash('sha256').update(hap).digest('hex');
  if (hap.length !== update.size || actual !== expected) throw Error('size/SHA256 mismatch');
  console.log('VERIFIED ' + update.fileName + ' bytes=' + hap.length + ' SHA256=' + actual);
  console.log('No file installed, no GitHub data modified. Native transport/share still require device testing.');
})().catch(error => { console.error(error.message); process.exitCode = 1; });
