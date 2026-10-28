import { bundleManager } from '@kit.AbilityKit';
import { UpdatePanel } from '../../../../main/ets/presentation/about/UpdatePanel';

@Entry
@Component
struct TestIndex {
  @StorageProp('manualGitHubUpdate') private manualUpdater: boolean = false;
  @State private actualCode: string = '';
  @State private simulateOlder: boolean = false;

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
            Text('更新文件导出：设备测试').fontSize(24).fontWeight(FontWeight.Bold);
            Text('仅存在于 ohosTest。实际内部版本号：' + this.actualCode).fontSize(14);
            Text('模拟旧版仅改变测试传入的版本号，用于下载现有官方 Beta；接收文件后停止，不安装或续期。')
              .fontSize(14);
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
