import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
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
          Button('用小白助手打开').enabled(!this.busy).onClick(() => { void this.openInstaller(); });
          Button('分享已校验的安装包').enabled(!this.busy).onClick(() => { void this.share(); });
          Text('若无法打开小白，可在分享面板中“另存为”，再到小白选择该文件，或用电脑安装。打开工具不代表安装成功。')
            .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%');
        } else {
          Button('下载 / 重新下载 HAP').enabled(!this.busy).onClick(() => { void this.download(); });
        }
      }
      Text('升级不要先卸载旧版，请沿用原来的账号和签名。签名不一致时先停止安装，以免丢失本地数据。')
        .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%');
      Text('打开 GitHub 下载网页').fontSize(15).fontColor($r('app.color.brand')).width('100%')
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
      this.status = 'SHA-256 校验通过。此包仍需由安装工具签名，不能直接安装。';
    } catch (error) {
      if (this.alive) this.status = updateErrorMessage((error as Error).message);
    } finally {
      if (this.alive) { this.busy = false; this.downloading = false; }
    }
  }

  private async openInstaller(): Promise<void> {
    if (this.busy || this.candidate === undefined || this.verifiedPath.length === 0) return;
    this.busy = true;
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    try {
      await service.verifyForSharing(this.candidate, this.verifiedPath);
      if (!this.alive) return;
      const want: Want = {
        bundleName: 'com.xiaobai.hap_installer',
        action: 'ohos.want.action.viewData',
        uri: fileUri.getUriFromPath(this.verifiedPath),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await (this.getUIContext().getHostContext() as common.UIAbilityContext).startAbility(want);
      if (this.alive) this.status = '已交给小白助手。请核对版本，沿用原签名安装；安装结果以小白提示为准。';
    } catch (error) {
      if (this.alive) {
        const reason: string = (error as Error).message;
        if (reason.startsWith('update-')) {
          if (reason === 'update-checksum') this.verifiedPath = '';
          this.status = updateErrorMessage(reason);
        } else {
          this.status = '无法打开小白助手。请确认已安装手机版，或用“分享已校验的安装包”另存为文件，再到小白选择；也可用电脑安装。';
        }
      }
    } finally {
      if (this.alive) this.busy = false;
    }
  }

  private async share(): Promise<void> {
    if (this.busy || this.candidate === undefined || this.verifiedPath.length === 0) return;
    this.busy = true;
    const service: GitHubUpdateService = new GitHubUpdateService();
    this.service = service;
    try {
      await service.verifyForSharing(this.candidate, this.verifiedPath);
      if (!this.alive) return;
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.getUniformDataTypeByFilenameExtension('.hap', utd.UniformDataType.FILE),
        uri: fileUri.getUriFromPath(this.verifiedPath),
        title: this.candidate.fileName,
        description: '未签名 HAP：请沿用原签名覆盖安装，不要卸载旧版。'
      });
      await new systemShare.ShareController(data).show(
        this.getUIContext().getHostContext() as common.UIAbilityContext, {
          selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL
        });
      if (this.alive) this.status = '已打开系统分享。请在安装工具中确认结果；若没有兼容工具，请用电脑安装。';
    } catch (error) {
      if (this.alive) {
        if ((error as Error).message === 'update-checksum') {
          this.verifiedPath = '';
          this.status = updateErrorMessage('update-checksum');
        } else {
          this.status = '暂时无法校验或分享文件。请重试；若系统没有兼容的安装工具，请打开下载网页，用电脑安装。';
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
