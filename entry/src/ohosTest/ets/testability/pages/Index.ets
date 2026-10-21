import { bundleManager, common, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { UpdatePanel } from '../../../../main/ets/presentation/about/UpdatePanel';

@Entry
@Component
struct TestIndex {
  @StorageProp('manualGitHubUpdate') private manualUpdater: boolean = false;
  @State private actualCode: string = '';
  @State private simulateOlder: boolean = false;
  @State private signedProbeStatus: string = '';

  // Optional local fixture, intentionally absent from Git and user packages.
  private async openSignedFixture(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const data = context.resourceManager.getRawFileContentSync('local-signed-probe.hap');
      const path = context.cacheDir + '/hipda-oh-local-signed-probe.hap';
      const output = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      try {
        if (fs.writeSync(output.fd, data.buffer) !== data.byteLength) throw new Error('short write');
      } finally {
        fs.closeSync(output);
      }
      await context.startAbility({
        bundleName: 'com.xiaobai.hap_installer', action: 'ohos.want.action.viewData',
        uri: fileUri.getUriFromPath(path), flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      });
      this.signedProbeStatus = '已交给小白；仅在原签名匹配已核验后手动直接安装。';
    } catch (_error) {
      this.signedProbeStatus = '未提供本地已签名样本，或小白无法接收文件。';
    }
  }

  aboutToAppear(): void {
    if (this.manualUpdater) {
      this.actualCode = String(bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionCode);
    }
  }

  build() {
    Column() {
      if (this.manualUpdater) {
        Scroll() {
          Column({ space: 16 }) {
            Text('更新交接：设备测试').fontSize(24).fontWeight(FontWeight.Bold);
            Text('仅存在于 ohosTest。实际内部版本号：' + this.actualCode).fontSize(14);
            Text('模拟旧版仅改变测试传入的版本号，用于下载现有官方 Beta；接收文件后停止，不安装或续期。')
              .fontSize(14);
            Button('交给小白：本地原签名样本').onClick(() => { void this.openSignedFixture(); });
            if (this.signedProbeStatus.length > 0) { Text(this.signedProbeStatus).fontSize(14); }
            Button(this.simulateOlder ? '改用实际版本号检查' : '模拟旧版 1000005')
              .onClick(() => { this.simulateOlder = !this.simulateOlder; });
            if (this.simulateOlder) {
              Text('当前测试输入：1000005').fontSize(16);
              UpdatePanel({ installedCode: '1000005' });
            } else {
              Text('当前测试输入：实际版本号').fontSize(16);
              UpdatePanel({ installedCode: this.actualCode });
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
            .padding({ top: 64, left: 20, right: 20, bottom: 40 });
        }.width('100%').height('100%');
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.canvas'));
  }
}
