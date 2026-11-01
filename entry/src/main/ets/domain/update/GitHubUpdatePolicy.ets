/** Public, anonymous GitHub updates. Never use a forum session or infer a code from beta text. */
export const UPDATE_REPOSITORY: string = 'https://github.com/sis5595/hipda-oh';
export const UPDATE_RELEASES: string = UPDATE_REPOSITORY + '/releases';
export const UPDATE_API: string = 'https://api.github.com/repos/sis5595/hipda-oh/releases?per_page=100';
export const UPDATE_MAX_HAP_BYTES: number = 64 * 1024 * 1024;

export interface GitHubUpdateAsset {
  name: string;
  size: number;
  browser_download_url: string;
}

export interface GitHubUpdateRelease {
  tag_name: string;
  draft: boolean;
  prerelease: boolean;
  body: string | null;
  assets: GitHubUpdateAsset[];
}

export interface GitHubUpdateCandidate {
  tag: string;
  versionName: string;
  versionCode: number;
  notes: string;
  fileName: string;
  size: number;
  downloadUrl: string;
  checksumUrl: string;
}

interface TaggedAppVersion {
  app: TaggedAppInfo;
}

interface TaggedAppInfo {
  bundleName: string;
  versionName: string;
  versionCode: number;
}

export function isUpdateTag(tag: string): boolean {
  return typeof tag === 'string' && /^v\d+\.\d+\.\d+(?:\.\d+|-beta\.\d+(?:\.\d+)?)?$/.test(tag) && tag.length <= 64;
}

export function updateVersionUrl(tag: string): string {
  if (!isUpdateTag(tag)) throw new Error('update-metadata');
  return 'https://raw.githubusercontent.com/sis5595/hipda-oh/' + tag + '/AppScope/app.json5';
}

export function parseUpdateReleases(text: string): GitHubUpdateRelease[] {
  let releases: GitHubUpdateRelease[];
  try { releases = JSON.parse(text) as GitHubUpdateRelease[]; } catch (_error) { throw new Error('update-metadata'); }
  if (!Array.isArray(releases) || releases.length >= 100) throw new Error('update-metadata');
  const eligible: GitHubUpdateRelease[] = [];
  for (const release of releases) {
    if (release === null || typeof release !== 'object' || typeof release.draft !== 'boolean' ||
      typeof release.prerelease !== 'boolean' || !Array.isArray(release.assets)) throw new Error('update-metadata');
    for (const asset of release.assets) {
      if (asset === null || typeof asset !== 'object' || typeof asset.name !== 'string') throw new Error('update-metadata');
    }
    // Source-only historical releases (including beta.1) are not installable updates.
    if (!release.draft && isUpdateTag(release.tag_name) &&
      release.assets.some((asset: GitHubUpdateAsset) => asset.name.endsWith('.hap'))) eligible.push(release);
  }
  // A truncated or partially checked history must never be reported as "up to date".
  if (eligible.length > 24) throw new Error('update-metadata');
  return eligible;
}

export function makeUpdateCandidate(release: GitHubUpdateRelease, versionText: string): GitHubUpdateCandidate {
  if (!isUpdateTag(release.tag_name) || release.draft) throw new Error('update-metadata');
  let version: TaggedAppVersion;
  try { version = JSON.parse(versionText) as TaggedAppVersion; } catch (_error) { throw new Error('update-metadata'); }
  if (!version || !version.app || version.app.bundleName !== 'com.sis5595.hipdaoh' ||
    typeof version.app.versionName !== 'string' || 'v' + version.app.versionName !== release.tag_name ||
    !Number.isSafeInteger(version.app.versionCode) || version.app.versionCode < 1) throw new Error('update-metadata');
  const fileName: string = 'hipda-oh-' + version.app.versionName + '-unsigned.hap';
  const files: GitHubUpdateAsset[] = release.assets.filter((asset: GitHubUpdateAsset) => asset.name === fileName);
  const sums: GitHubUpdateAsset[] = release.assets.filter((asset: GitHubUpdateAsset) => asset.name === 'SHA256SUMS.txt');
  const base: string = UPDATE_RELEASES + '/download/' + release.tag_name + '/';
  if (files.length !== 1 || sums.length !== 1 || files[0].browser_download_url !== base + fileName ||
    sums[0].browser_download_url !== base + 'SHA256SUMS.txt' ||
    !Number.isSafeInteger(files[0].size) || files[0].size < 1 || files[0].size > UPDATE_MAX_HAP_BYTES ||
    !Number.isSafeInteger(sums[0].size) || sums[0].size < 1 || sums[0].size > 16384) throw new Error('update-metadata');
  return {
    tag: release.tag_name, versionName: version.app.versionName, versionCode: version.app.versionCode,
    notes: typeof release.body === 'string' ? release.body.slice(0, 16000) : '此版本未提供更新说明。',
    fileName: fileName, size: files[0].size, downloadUrl: files[0].browser_download_url,
    checksumUrl: sums[0].browser_download_url
  };
}

export function selectNewerUpdate(candidates: GitHubUpdateCandidate[],
  installedCode: number): GitHubUpdateCandidate | undefined {
  if (!Number.isSafeInteger(installedCode) || installedCode < 1) throw new Error('update-installed-version');
  let newest: GitHubUpdateCandidate | undefined = undefined;
  for (const candidate of candidates) {
    if (!Number.isSafeInteger(candidate.versionCode) || candidate.versionCode < 1) throw new Error('update-metadata');
    if (candidate.versionCode > installedCode &&
      (newest === undefined || candidate.versionCode > newest.versionCode)) newest = candidate;
  }
  return newest;
}

export function parseUpdateChecksum(text: string, fileName: string): string {
  if (text.length > 16384) throw new Error('update-checksum');
  let found: string = '';
  for (const line of text.replace(/^\uFEFF/, '').split(/\r?\n/)) {
    if (line.trim().length === 0) continue;
    const match: RegExpMatchArray | null = line.match(/^([a-fA-F0-9]{64}) [ *]([A-Za-z0-9._-]+)$/);
    if (match === null) throw new Error('update-checksum');
    if (match[2] === fileName) {
      if (found.length > 0) throw new Error('update-checksum');
      found = match[1].toLowerCase();
    }
  }
  if (found.length !== 64) throw new Error('update-checksum');
  return found;
}

export function updateErrorMessage(code: string): string {
  switch (code) {
    case 'update-rate-limit': return 'GitHub 暂时限制了访问次数，请稍后再试，也可打开下载网页。';
    case 'update-metadata': return '此版本的发布信息不完整或格式暂不支持，无法安全判断更新。请打开下载网页。';
    case 'update-checksum': return '安装包校验失败，已禁止分享和保存。请重新下载；仍失败时请反馈，不要安装此文件。';
    case 'update-storage': return '无法保存安装包，请检查手机剩余空间后重试。';
    case 'update-installed-version': return '未能读取当前版本，请返回后重试。';
    case 'update-cancelled': return '已取消下载。';
    default: return '暂时无法连接 GitHub，或下载中断。请检查网络后重试，也可用电脑打开下载网页。';
  }
}
