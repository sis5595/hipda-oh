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
  StorageFailed = 'storageFailed'
}

/**
 * Coordinates the non-sensitive profile registry and the encrypted session
 * asset. It never asks for, receives, or stores a password.
 */
export class FourD4yAccountService {
  static async saveVerifiedCurrentSession(context: common.Context, identity: FourD4yAccountIdentity):
    Promise<FourD4yAccountSaveResult> {
    const sessionSecret: string | null = await FourD4ySession.captureAccountSessionSecret();
    if (sessionSecret === null) {
      return FourD4yAccountSaveResult.SessionUnavailable;
    }
    const before: FourD4yAccountRegistry = await FourD4yAccountProfileStore.load(context);
    const next: FourD4yAccountRegistry | null = upsertFourD4yAccountProfile(before, identity, Date.now());
    if (next === null) {
      return FourD4yAccountSaveResult.AccountLimit;
    }
    const profile: FourD4yAccountProfile | undefined = next.profiles.find((item: FourD4yAccountProfile) =>
      item.id === next.activeProfileId);
    if (profile === undefined || !await FourD4yAccountSessionStore.save(profile.id, sessionSecret)) {
      return FourD4yAccountSaveResult.StorageFailed;
    }
    if (await FourD4yAccountProfileStore.save(context, next)) {
      return FourD4yAccountSaveResult.Saved;
    }
    // If a brand-new profile cannot be listed, remove its otherwise orphaned
    // session asset. Existing profiles retain their older valid registry row.
    if (before.profiles.findIndex((item: FourD4yAccountProfile) => item.id === profile.id) < 0) {
      await FourD4yAccountSessionStore.remove(profile.id);
    }
    return FourD4yAccountSaveResult.StorageFailed;
  }

  static async activateSavedSession(profileId: string): Promise<boolean> {
    const sessionSecret: string | null = await FourD4yAccountSessionStore.load(profileId);
    return sessionSecret !== null && await FourD4ySession.restoreAccountSessionSecret(sessionSecret);
  }
}
