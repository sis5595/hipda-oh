import http from '@ohos.net.http';
import { fileIo as fs, hash } from '@kit.CoreFileKit';
import { url, util } from '@kit.ArkTS';
import {
  GitHubUpdateCandidate, GitHubUpdateRelease, UPDATE_API, makeUpdateCandidate,
  parseUpdateReleases, parseUpdateChecksum, selectNewerUpdate, updateVersionUrl
} from '../../domain/update/GitHubUpdatePolicy';

/** Separate trust boundary: no forum cookies, tokens, proxy mirrors or permissive fallback. */
export function isOfficialUpdateUrl(value: string): boolean {
  if (value.length > 8192 || /[\s\\]/.test(value)) return false;
  try {
    const parsed: url.URL = new url.URL(value);
    if (parsed.protocol !== 'https:' || parsed.username !== '' || parsed.password !== '' ||
      (parsed.port !== '' && parsed.port !== '443') || parsed.hash !== '') return false;
    if (parsed.hostname === 'api.github.com') {
      return parsed.pathname === '/repos/sis5595/hipda-oh/releases';
    }
    if (parsed.hostname === 'raw.githubusercontent.com') {
      return /^\/sis5595\/hipda-oh\/v\d+\.\d+\.\d+(?:\.\d+|-beta\.\d+(?:\.\d+)?)?\/AppScope\/app\.json5$/.test(parsed.pathname);
    }
    if (parsed.hostname === 'github.com') {
      return /^\/sis5595\/hipda-oh\/releases\/download\/v\d+\.\d+\.\d+(?:\.\d+|-beta\.\d+(?:\.\d+)?)?\/[A-Za-z0-9._-]+$/.test(parsed.pathname);
    }
    return parsed.hostname === 'release-assets.githubusercontent.com' ||
      parsed.hostname === 'objects.githubusercontent.com';
  } catch (_error) {
    return false;
  }
}

class UpdateRedirectBoundary implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.REDIRECTION;
  private hops: number = 0;
  blocked: boolean = false;
  async interceptorHandle(request: http.HttpRequestContext,
    _response: http.HttpResponse): Promise<http.ChainContinue> {
    this.hops += 1;
    if (this.hops > 5 || !isOfficialUpdateUrl(request.url)) {
      this.blocked = true;
      return false;
    }
    return true;
  }
}

export class GitHubUpdateService {
  private active: http.HttpRequest | undefined = undefined;
  private cancelled: boolean = false;
  private abortCurrent: (() => void) | undefined = undefined;

  cancel(): void {
    this.cancelled = true;
    this.abortCurrent?.();
    if (this.active !== undefined) this.active.destroy();
    this.active = undefined;
  }

  async check(installedCode: number): Promise<GitHubUpdateCandidate | undefined> {
    const releases: GitHubUpdateRelease[] = parseUpdateReleases(await this.text(UPDATE_API, 2 * 1024 * 1024));
    const candidates: GitHubUpdateCandidate[] = [];
    for (const release of releases) {
      // The tag's actual versionCode is authoritative, not semver ordering or release dates.
      candidates.push(makeUpdateCandidate(release, await this.text(updateVersionUrl(release.tag_name), 16384)));
    }
    return selectNewerUpdate(candidates, installedCode);
  }

  async download(candidate: GitHubUpdateCandidate, cacheDir: string,
    progress: (received: number, total: number) => void): Promise<string> {
    const expected: string = parseUpdateChecksum(await this.text(candidate.checksumUrl, 16384), candidate.fileName);
    const directory: string = cacheDir + '/github-update';
    const path: string = directory + '/' + candidate.fileName;
    const partial: string = path + '.part';
    let file: fs.File | undefined = undefined;
    try {
      if (!fs.accessSync(directory)) fs.mkdirSync(directory);
      // Only remove updater-owned artifacts, never forum data or user documents.
      for (const name of fs.listFileSync(directory)) {
        if (/^hipda-oh-[A-Za-z0-9.-]+-unsigned\.hap(?:\.part)?$/.test(name)) fs.unlinkSync(directory + '/' + name);
      }
      file = fs.openSync(partial, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    } catch (_error) {
      throw new Error('update-storage');
    }
    const output: fs.File = file;
    try {
      let written: number = 0;
      await this.stream(candidate.downloadUrl, candidate.size, (chunk: ArrayBuffer) => {
        try {
          if (fs.writeSync(output.fd, chunk) !== chunk.byteLength) throw new Error('short-write');
        } catch (_error) { throw new Error('update-storage'); }
        written += chunk.byteLength;
        progress(written, candidate.size);
      });
      try { fs.closeSync(output); } catch (_error) { throw new Error('update-storage'); }
      file = undefined;
      if (written !== candidate.size || (await hash.hash(partial, 'sha256')).toLowerCase() !== expected) {
        throw new Error('update-checksum');
      }
      if (this.cancelled) throw new Error('update-cancelled');
      try { fs.renameSync(partial, path); } catch (_error) { throw new Error('update-storage'); }
      return path;
    } finally {
      // Cleanup must not mask the useful failure; an orphan .part is never shareable.
      try { if (file !== undefined) fs.closeSync(file); } catch (_error) {}
      try { if (fs.accessSync(partial)) fs.unlinkSync(partial); } catch (_error) {}
    }
  }

  /** Installer-independent gate used by every file export, including future adapters. */
  async verifyForExport(candidate: GitHubUpdateCandidate, path: string): Promise<void> {
    const expected: string = parseUpdateChecksum(await this.text(candidate.checksumUrl, 16384), candidate.fileName);
    if (fs.statSync(path).size !== candidate.size || (await hash.hash(path, 'sha256')).toLowerCase() !== expected) {
      throw new Error('update-checksum');
    }
  }

  private async text(address: string, maxBytes: number): Promise<string> {
    const buffers: Uint8Array[] = [];
    let size: number = 0;
    await this.stream(address, maxBytes, (chunk: ArrayBuffer) => {
      buffers.push(new Uint8Array(chunk));
      size += chunk.byteLength;
    });
    const merged: Uint8Array = new Uint8Array(size);
    let offset: number = 0;
    for (const buffer of buffers) {
      merged.set(buffer, offset);
      offset += buffer.length;
    }
    return new util.TextDecoder('utf-8', { fatal: true }).decodeToString(merged);
  }

  private async stream(address: string, maxBytes: number, consume: (chunk: ArrayBuffer) => void): Promise<void> {
    if (this.cancelled) throw new Error('update-cancelled');
    if (!isOfficialUpdateUrl(address)) throw new Error('update-metadata');
    const request: http.HttpRequest = http.createHttp();
    this.active = request;
    const guard: UpdateRedirectBoundary = new UpdateRedirectBoundary();
    let timer: number = -1;
    try {
      const chain: http.HttpInterceptorChain = new http.HttpInterceptorChain();
      if (!chain.addChain([guard]) || !chain.apply(request)) throw new Error('update-metadata');
      await new Promise<void>((resolve, reject) => {
        let settled: boolean = false;
        let ended: boolean = false;
        let statusReady: boolean = false;
        let received: number = 0;
        const fail = (reason: string): void => {
          if (settled) return;
          settled = true;
          reject(new Error(reason));
        };
        const finish = (): void => {
          if (settled || !ended || !statusReady) return;
          settled = true;
          resolve();
        };
        this.abortCurrent = (): void => { fail('update-cancelled'); };
        // Absolute deadline also covers a missing dataEnd after the response code.
        timer = setTimeout(() => { fail('update-network'); }, 120000);
        request.on('dataEnd', () => { ended = true; finish(); });
        request.on('dataReceive', (chunk: ArrayBuffer) => {
          if (settled || this.cancelled) return;
          received += chunk.byteLength;
          if (received > maxBytes) { fail('update-checksum'); return; }
          try { consume(chunk); } catch (_error) { fail('update-storage'); }
        });
        request.requestInStream(address, {
          method: http.RequestMethod.GET,
          header: { 'User-Agent': 'HiPDAOH-update', 'Accept': '*/*' },
          usingCache: false, connectTimeout: 20000, readTimeout: 60000, maxRedirects: 5
        }).then((status: number) => {
          if (this.cancelled) { fail('update-cancelled'); return; }
          if (status === 403 || status === 429) { fail('update-rate-limit'); return; }
          if (status !== 200 || guard.blocked) { fail('update-network'); return; }
          statusReady = true;
          finish();
        }).catch(() => { fail(this.cancelled ? 'update-cancelled' : 'update-network'); });
      });
    } finally {
      if (timer !== -1) clearTimeout(timer);
      this.abortCurrent = undefined;
      request.destroy();
      if (this.active === request) this.active = undefined;
    }
  }
}
