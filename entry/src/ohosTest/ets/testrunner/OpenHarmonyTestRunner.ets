import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const args = abilityDelegatorRegistry.getArguments();
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
      bundleName: args.bundleName,
      moduleName: 'entry_test',
      abilityName: 'TestAbility'
    });
  }
}
