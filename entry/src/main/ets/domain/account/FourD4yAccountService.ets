import { common } from '@kit.AbilityKit';
import { FourD4yAccountProfileStore } from '../../data/local/FourD4yAccountProfileStore';
import { FourD4yAccountSessionStore } from '../../data/local/FourD4yAccountSessionStore';
import { FourD4ySession } from '../../data/remote/FourD4ySession';
import { FourD4yAccountIdentity, FourD4yAccountProfile, FourD4yAccountRegistry,
  upsertFourD4yAccountProfile } from './FourD4yAccountContracts';

export enum FourD4yAccountSaveResult {
  Saved = 'saved',
  AccountLimit = 'accountLimit',
  SessionUnavailable = 'sessionUnavailable',
  VerificationExpired = 'verificationExpired',
  StorageFailed = 'storageFailed'
}

/**
 * Coordinates the non-sensitive profile registry and the encrypted session
 * asset. It never asks for, receives, or stores a password.
 */
export class FourD4yAccountService {
  private static saveTail: Promise<void> = Promise.resolve();

  // Called only behind the privacy gate, before any forum UI is mounted.
  // This restores a credential, not a verified server identity. Existing
  // cookies win; rejected/expired credentials retain the normal login path.
  static async restoreStartupSession(context: common.Context, isCurrent: () => boolean): Promise<void> {
    try {
      if (!isCurrent() || await FourD4ySession.getAuthenticationState() !== 'absent' || !isCurrent()) {
        return;
      }
      const registry: FourD4yAccountRegistry = await FourD4yAccountProfileStore.load(context);
      if (!isCurrent() || registry.activeProfileId.length === 0 ||
        !registry.profiles.some((profile: FourD4yAccountProfile) => profile.id === registry.activeProfileId)) {
        return;
      }
      const secret: string | null = await FourD4yAccountSessionStore.load(registry.activeProfileId);
      if (!isCurrent() || secret === null ||
        await FourD4ySession.getAuthenticationState() !== 'absent' || !isCurrent()) {
        return;
      }
      await FourD4ySession.restoreAccountSessionSecret(secret);
    } catch (_error) {
      // Locked/unavailable Asset or Preferences must not erase saved accounts
      // or block application startup. A manual login remains available.
    }
  }

  static async forgetStartupSelection(context: common.Context,
    isCurrent: () => boolean = () => true): Promise<void> {
    const registry: FourD4yAccountRegistry = await FourD4yAccountProfileStore.load(context);
    if (!isCurrent()) {
      return;
    }
    registry.activeProfileId = '';
    if (!await FourD4yAccountProfileStore.save(context, registry, isCurrent)) {
      throw new Error('account-selection-clear-failed');
    }
  }

  static async saveVerifiedCurrentSession(context: common.Context, identity: FourD4yAccountIdentity,
    sessionSecret: string, isCurrentVerification: () => boolean):
    Promise<FourD4yAccountSaveResult> {
    // Identity and secret are the caller's same verified observation. Never
    // recapture cookies later and accidentally label a new account with an old UID.
    const result: Promise<FourD4yAccountSaveResult> = FourD4yAccountService.saveTail.then(() =>
      FourD4yAccountService.saveVerifiedSessionLocked(context, identity, sessionSecret, isCurrentVerification));
    FourD4yAccountService.saveTail = result.then(() => {}, () => {});
    return result;
  }

  private static async saveVerifiedSessionLocked(context: common.Context, identity: FourD4yAccountIdentity,
    sessionSecret: string, isCurrentVerification: () => boolean): Promise<FourD4yAccountSaveResult> {
    if (!isCurrentVerification() || !await FourD4ySession.isCurrentAccountSessionSecret(sessionSecret) ||
      !isCurrentVerification()) {
      return FourD4yAccountSaveResult.VerificationExpired;
    }
    let before: FourD4yAccountRegistry;
    try {
      before = await FourD4yAccountProfileStore.load(context);
    } catch (_error) {
      return FourD4yAccountSaveResult.StorageFailed;
    }
    if (!isCurrentVerification()) {
      return FourD4yAccountSaveResult.VerificationExpired;
    }
    const next: FourD4yAccountRegistry | null = upsertFourD4yAccountProfile(before, identity, Date.now());
    if (next === null) {
      return FourD4yAccountSaveResult.AccountLimit;
    }
    const profile: FourD4yAccountProfile | undefined = next.profiles.find((item: FourD4yAccountProfile) =>
      item.id === next.activeProfileId);
    if (profile === undefined || !await FourD4yAccountSessionStore.save(profile.id, sessionSecret)) {
      return FourD4yAccountSaveResult.StorageFailed;
    }
    if (!isCurrentVerification() || !await FourD4ySession.isCurrentAccountSessionSecret(sessionSecret) ||
      !isCurrentVerification()) {
      // A completed save still belongs to the verified UID, but it must not
      // select that account after the page or live authentication has changed.
      if (before.profiles.findIndex((item: FourD4yAccountProfile) => item.id === profile.id) < 0) {
        await FourD4yAccountSessionStore.remove(profile.id);
      }
      return FourD4yAccountSaveResult.VerificationExpired;
    }
    if (await FourD4yAccountProfileStore.save(context, next, isCurrentVerification)) {
      return FourD4yAccountSaveResult.Saved;
    }
    // If a brand-new profile cannot be listed, remove its otherwise orphaned
    // session asset. Existing profiles retain their older valid registry row.
    if (before.profiles.findIndex((item: FourD4yAccountProfile) => item.id === profile.id) < 0) {
      await FourD4yAccountSessionStore.remove(profile.id);
    }
    return isCurrentVerification() ? FourD4yAccountSaveResult.StorageFailed :
      FourD4yAccountSaveResult.VerificationExpired;
  }

  static async activateSavedSession(profileId: string, isCurrentOperation: () => boolean): Promise<boolean> {
    const sessionSecret: string | null = await FourD4yAccountSessionStore.load(profileId);
    return isCurrentOperation() && sessionSecret !== null &&
      await FourD4ySession.restoreAccountSessionSecret(sessionSecret);
  }
}
