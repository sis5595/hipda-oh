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
  private readonly delegator: abilityDelegatorRegistry.AbilityDelegator =
    abilityDelegatorRegistry.getAbilityDelegator();

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    Hypium.hypiumTest(this.delegator, abilityDelegatorRegistry.getArguments(), testsuite);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index');
  }
}
