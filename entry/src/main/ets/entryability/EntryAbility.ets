import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FourD4yUserSettingsStore } from '../data/local/FourD4yUserSettingsStore';

const DOMAIN = 0x0000;
const FOREGROUND_GENERATION_KEY: string = 'fourD4yForegroundGeneration';

export default class EntryAbility extends UIAbility {
  private foregroundGeneration: number = 0;
  private windowStageGeneration: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<number>(FOREGROUND_GENERATION_KEY, this.foregroundGeneration);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const generation: number = ++this.windowStageGeneration;
    void this.restoreAppearanceAndLoad(windowStage, generation);
  }

  onWindowStageDestroy(): void {
    this.windowStageGeneration += 1;
  }

  onDestroy(): void {
    this.windowStageGeneration += 1;
  }

  private async restoreAppearanceAndLoad(windowStage: window.WindowStage, generation: number): Promise<void> {
    try {
      await FourD4yUserSettingsStore.restoreAndApply(this.context, this.context.getApplicationContext());
    } catch (_error) {
      hilog.error(DOMAIN, 'HiPDAOH', 'Failed to restore display settings.');
    }
    if (generation !== this.windowStageGeneration) {
      return;
    }
    try {
    windowStage.loadContent('pages/Index', (err) => {
        if (generation === this.windowStageGeneration && err.code) {
          hilog.error(DOMAIN, 'HiPDAOH', 'Failed to load the content.');
        }
      });
    } catch (_error) {
      hilog.error(DOMAIN, 'HiPDAOH', 'Failed to initialize the window content.');
    }
  }

  onForeground(): void {
    this.foregroundGeneration += 1;
    AppStorage.setOrCreate<number>(FOREGROUND_GENERATION_KEY, this.foregroundGeneration);
  }
}
