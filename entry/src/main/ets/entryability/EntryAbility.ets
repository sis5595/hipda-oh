import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FourD4yUserSettingsStore } from '../data/local/FourD4yUserSettingsStore';

const DOMAIN = 0x0000;
const FOREGROUND_GENERATION_KEY: string = 'fourD4yForegroundGeneration';

export default class EntryAbility extends UIAbility {
  private foregroundGeneration: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<number>(FOREGROUND_GENERATION_KEY, this.foregroundGeneration);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    void this.restoreAppearanceAndLoad(windowStage);
  }

  private async restoreAppearanceAndLoad(windowStage: window.WindowStage): Promise<void> {
    try {
      await FourD4yUserSettingsStore.restoreAndApply(this.context, this.context.getApplicationContext());
    } catch (_error) {
      hilog.error(DOMAIN, 'HiPDAOH', 'Failed to restore display settings.');
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'HiPDAOH', 'Failed to load the content.');
        return;
      }
    });
  }

  onForeground(): void {
    this.foregroundGeneration += 1;
    AppStorage.setOrCreate<number>(FOREGROUND_GENERATION_KEY, this.foregroundGeneration);
  }
}
