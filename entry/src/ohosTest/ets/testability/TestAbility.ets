import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { window } from '@kit.ArkUI';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

/**
 * Explicit test Ability scaffold required by current DevEco test templates.
 * Newer templates can omit it, but this project's generated test manifest
 * still declares TestAbility as its entry point.
 */
export default class TestAbility extends UIAbility {
  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // Explicit device-only UI probe; never included in the distribution HAP.
    const manualUpdater: boolean = want.parameters?.['manualGitHubUpdate'] === true;
    AppStorage.setOrCreate<boolean>('manualGitHubUpdate', manualUpdater);
    if (!manualUpdater) {
      const delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), testsuite);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index');
  }
}
