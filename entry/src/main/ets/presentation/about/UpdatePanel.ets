import { common, Want } from '@kit.AbilityKit';
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { GitHubUpdateService } from '../../data/update/GitHubUpdateService';
import { GitHubUpdateCandidate, UPDATE_RELEASES, updateErrorMessage } from '../../domain/update/GitHubUpdatePolicy';

@Component
export struct UpdatePanel {
  @Prop installedCode: string = '';
  @State private candidate: GitHubUpdateCandidate | undefined = undefined;
  @State private status: string = '手动检查 GitHub 正式版和 Beta 版，不会自动安装。';
  @State private busy: boolean = false;
  @State private percent: number = 0;
  @State private downloading: boolean = false;
  @State private verifiedPath: string = '';
  private alive: boolean = false;
  private service: GitHubUpdateService | undefined = undefined;

  aboutToAppear(): void { this.alive = true; }
  aboutToDisappear(): void {
    this.alive = false;
    this.service?.cancel();
  }

  build() {
    Column({ space: 10 }) {
      Text('应用更新').fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%');
      Text(this.status).fontSize(14).fontColor($r('app.color.text_body')).width('100%');
      Button('检查更新').enabled(!this.busy && Number(this.installedCode) > 0)
        .onClick(() => { void this.check(); });
      if (this.candidate !== undefined) {
        Text('新版本：' + this.candidate.versionName).fontSize(16)
          .fontColor($r('app.color.text_primary')).width('100%');
        Text(this.candidate.notes).fontSize(14).fontColor($r('app.color.text_body')).width('100%');
        if (this.downloading) {
          Progress({ value: this.percent, total: 100, type: ProgressType.Linear }).width('100%');
          Text(String(this.percent) + '%').fontSize(13).fontColor($r('app.color.text_secondary'));
          Button('取消下载').onClick(() => { this.service?.cancel(); });
        } else if (this.verifiedPath.length > 0) {
          Button('分享安装包').enabled(!this.busy).onClick(() => { void this.share(); });
          Button('保存安装包').enabled(!this.busy).onClick(() => { void this.save(); });
          Text('分享面板不一定包含安装工具。可保存安装包，再在支持 HarmonyOS NEXT 的工具中手动导入；分享或保存不代表安装成功。')
            .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%');
        } else {
          Button('下载更新包').enabled(!this.busy).onClick(() => { void this.download(); });
        }
      }
      Text('安装工具正在重新验证。升级前请确认能否沿用原签名；如需重新安装，请先了解本地账号会话、设置和阅读记录可能丢失。')
        .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%');
      Text('前往下载页面').fontSize(15).fontColor($r('app.color.brand')).width('100%')
        .onClick(() => { void this.openDownloads(); });
    }.width('100%').alignItems(HorizontalAlign.Start);
  }

  private async check(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.candidate = undefined;
    this.verifiedPath = '';
    this.status = '正在检查版本，请稍候…';
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    try {
      const candidate: GitHubUpdateCandidate | undefined = await service.check(Number(this.installedCode));
      if (!this.alive) return;
      this.candidate = candidate;
      this.status = candidate === undefined ? '当前已是最新版本（包含 Beta 版）。' : '发现新版本。下载后会先校验文件，再由你选择安装工具。';
    } catch (error) {
      if (this.alive) this.status = updateErrorMessage((error as Error).message);
    } finally {
      if (this.alive) this.busy = false;
    }
  }

  private async download(): Promise<void> {
    if (this.busy || this.candidate === undefined) return;
    const candidate: GitHubUpdateCandidate = this.candidate;
    this.busy = true;
    this.downloading = true;
    this.percent = 0;
    this.verifiedPath = '';
    this.status = '正在从 GitHub 下载，请保持此页面打开…';
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const path: string = await service.download(candidate, context.cacheDir, (received: number, total: number) => {
        if (this.alive) {
          this.percent = Math.min(100, Math.floor(received * 100 / total));
          if (received === total) this.status = '下载完成，正在校验文件…';
        }
      });
      if (!this.alive) return;
      this.verifiedPath = path;
      this.status = '安装包已下载并校验完成。请使用支持 HarmonyOS NEXT 的安装工具完成签名和安装。';
    } catch (error) {
      if (this.alive) this.status = updateErrorMessage((error as Error).message);
    } finally {
      if (this.alive) { this.busy = false; this.downloading = false; }
    }
  }

  private async save(): Promise<void> {
    if (this.busy || this.candidate === undefined || this.verifiedPath.length === 0) return;
    const candidate: GitHubUpdateCandidate = this.candidate;
    const sourcePath: string = this.verifiedPath;
    this.busy = true;
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    let source: fs.File | undefined = undefined;
    let destination: fs.File | undefined = undefined;
    try {
      await service.verifyForExport(candidate, sourcePath);
      if (!this.alive) return;
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [candidate.fileName];
      options.fileSuffixChoices = ['HarmonyOS 安装包|.hap'];
      options.defaultFilePathUri = 'file://docs/storage/Users/currentUser/Download/';
      const destinations: string[] = await new picker.DocumentViewPicker(context).save(options);
      if (!this.alive) return;
      if (destinations.length === 0) {
        this.status = '已取消保存，可再次选择保存位置。';
        return;
      }
      if (destinations.length !== 1 || destinations[0].length === 0) throw new Error('save-destination');
      // The system picker may stay open for a while. Recheck before writing any bytes.
      await service.verifyForExport(candidate, sourcePath);
      if (!this.alive) return;
      source = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      destination = fs.openSync(destinations[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      await fs.copyFile(source.fd, destination.fd);
      if (fs.statSync(destination.fd).size !== candidate.size) throw new Error('save-short-copy');
      fs.closeSync(destination);
      destination = undefined;
      if (this.alive) this.status = '安装包已保存到所选位置。请在安装工具中手动导入此 HAP；保存不代表安装成功。';
    } catch (error) {
      if (this.alive) {
        const reason: string = (error as Error).message;
        if (reason.startsWith('update-')) {
          if (reason === 'update-checksum') this.verifiedPath = '';
          this.status = updateErrorMessage(reason);
        } else {
          this.status = '保存未完成，可能已取消或存储空间不足。请重新选择位置；如出现不完整文件，请勿导入，也可前往下载页面。';
        }
      }
    } finally {
      try { if (destination !== undefined) fs.closeSync(destination); } catch (_error) {}
      try { if (source !== undefined) fs.closeSync(source); } catch (_error) {}
      if (this.alive) this.busy = false;
    }
  }

  private async share(): Promise<void> {
    if (this.busy || this.candidate === undefined || this.verifiedPath.length === 0) return;
    this.busy = true;
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    try {
      await service.verifyForExport(this.candidate, this.verifiedPath);
      if (!this.alive) return;
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.getUniformDataTypeByFilenameExtension('.hap', utd.UniformDataType.FILE),
        uri: fileUri.getUriFromPath(this.verifiedPath),
        title: this.candidate.fileName,
        description: '已校验的未签名 HAP，请使用支持 HarmonyOS NEXT 的安装工具签名和安装。'
      });
      await new systemShare.ShareController(data).show(
        this.getUIContext().getHostContext() as common.UIAbilityContext, {
          selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL
        });
      if (this.alive) this.status = '已打开系统分享，不代表安装成功。若没有合适的安装工具，请使用“保存安装包”后手动导入。';
    } catch (error) {
      if (this.alive) {
        if ((error as Error).message === 'update-checksum') {
          this.verifiedPath = '';
          this.status = updateErrorMessage('update-checksum');
        } else {
          const reason: string = (error as Error).message;
          this.status = reason.startsWith('update-') ? updateErrorMessage(reason) :
            '暂时无法分享文件。可重试，或使用“保存安装包”后手动导入，也可前往下载页面。';
        }
      }
    } finally {
      if (this.alive) this.busy = false;
    }
  }

  private async openDownloads(): Promise<void> {
    try {
      const want: Want = { uri: UPDATE_RELEASES, action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'] };
      await (this.getUIContext().getHostContext() as common.UIAbilityContext).startAbility(want);
    } catch (_error) {
      if (this.alive) this.status = '无法打开浏览器，请在电脑访问 github.com/sis5595/hipda-oh/releases。';
    }
  }
}
