import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    await Promise.resolve();
  }

  async onRestore(_bundleVersion: BundleVersion): Promise<void> {
    await Promise.resolve();
  }
}
