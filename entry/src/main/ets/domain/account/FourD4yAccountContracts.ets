/**
 * Non-sensitive account registry contracts.
 *
 * The registry is deliberately separate from session secrets: it may contain
 * only a short display label, a numeric 4D4Y UID, and a random local ID. The
 * authenticated cookie itself is never serialised through this module.
 */
export const FOUR_D4Y_MAX_ACCOUNTS: number = 4;

export interface FourD4yAccountProfile {
  id: string;
  displayName: string;
  userId: string;
  lastActivatedAt: number;
}

export interface FourD4yAccountRegistry {
  activeProfileId: string;
  profiles: FourD4yAccountProfile[];
}

export interface FourD4yAccountIdentity {
  displayName: string;
  userId: string;
}

const MAX_REGISTRY_LENGTH: number = 4096;
const MAX_DISPLAY_NAME_LENGTH: number = 48;

export function createDefaultFourD4yAccountRegistry(): FourD4yAccountRegistry {
  return { activeProfileId: '', profiles: [] };
}

export function parseFourD4yAccountRegistry(rawValue: string): FourD4yAccountRegistry {
  if (rawValue.length === 0 || rawValue.length > MAX_REGISTRY_LENGTH) {
    return createDefaultFourD4yAccountRegistry();
  }
  try {
    const candidate: Object = JSON.parse(rawValue) as Object;
    const record: Record<string, Object> = candidate as Record<string, Object>;
    const rawProfiles: Object = record['profiles'];
    if (!Array.isArray(rawProfiles)) {
      return createDefaultFourD4yAccountRegistry();
    }
    const profiles: FourD4yAccountProfile[] = [];
    rawProfiles.forEach((entry: Object) => {
      const profile: FourD4yAccountProfile | null = normalizeFourD4yAccountProfile(entry);
      if (profile !== null && profiles.findIndex((item: FourD4yAccountProfile) => item.id === profile.id) < 0 &&
        profiles.length < FOUR_D4Y_MAX_ACCOUNTS) {
        profiles.push(profile);
      }
    });
    const activeProfileId: string = typeof record['activeProfileId'] === 'string' ? record['activeProfileId'] : '';
    return {
      activeProfileId: profiles.findIndex((profile: FourD4yAccountProfile) => profile.id === activeProfileId) >= 0 ?
        activeProfileId : '',
      profiles: profiles
    };
  } catch (_error) {
    return createDefaultFourD4yAccountRegistry();
  }
}

export function serializeFourD4yAccountRegistry(registry: FourD4yAccountRegistry): string {
  return JSON.stringify(normalizeFourD4yAccountRegistry(registry));
}

export function normalizeFourD4yAccountRegistry(registry: FourD4yAccountRegistry): FourD4yAccountRegistry {
  const profiles: FourD4yAccountProfile[] = [];
  registry.profiles.forEach((entry: FourD4yAccountProfile) => {
    const profile: FourD4yAccountProfile | null = normalizeFourD4yAccountProfile(entry);
    if (profile !== null && profiles.findIndex((item: FourD4yAccountProfile) => item.id === profile.id) < 0 &&
      profiles.length < FOUR_D4Y_MAX_ACCOUNTS) {
      profiles.push(profile);
    }
  });
  const activeProfileId: string = profiles.findIndex((profile: FourD4yAccountProfile) =>
    profile.id === registry.activeProfileId) >= 0 ? registry.activeProfileId : '';
  return { activeProfileId: activeProfileId, profiles: profiles };
}

export function parseFourD4yAccountIdentity(rawResult: string): FourD4yAccountIdentity | null {
  const payloadText: string | null = unwrapWebResult(rawResult);
  if (payloadText === null || payloadText.length > 1024) {
    return null;
  }
  try {
    const candidate: Object = JSON.parse(payloadText) as Object;
    const record: Record<string, Object> = candidate as Record<string, Object>;
    const userId: string = typeof record['userId'] === 'string' ? record['userId'] : '';
    const displayName: string = normalizeDisplayName(record['displayName']);
    if (!/^\d{1,16}$/.test(userId)) {
      return null;
    }
    return {
      userId: userId,
      displayName: displayName.length > 0 ? displayName : '4D4Y 用户 ' + userId
    };
  } catch (_error) {
    return null;
  }
}

export function createFourD4yAccountProfileId(now: number, randomValue: number): string {
  const timestamp: string = Math.max(0, Math.floor(now)).toString(36);
  const randomPart: string = Math.max(0, Math.floor(randomValue * 0x100000000)).toString(36);
  return 'account_' + timestamp + '_' + randomPart;
}

export function upsertFourD4yAccountProfile(registry: FourD4yAccountRegistry, identity: FourD4yAccountIdentity,
  now: number): FourD4yAccountRegistry | null {
  const normalized: FourD4yAccountRegistry = normalizeFourD4yAccountRegistry(registry);
  const existingIndex: number = normalized.profiles.findIndex((profile: FourD4yAccountProfile) =>
    profile.userId === identity.userId);
  const profile: FourD4yAccountProfile = {
    id: existingIndex >= 0 ? normalized.profiles[existingIndex].id : createFourD4yAccountProfileId(now, Math.random()),
    displayName: normalizeDisplayName(identity.displayName) || '4D4Y 用户 ' + identity.userId,
    userId: identity.userId,
    lastActivatedAt: normalizeTimestamp(now)
  };
  if (existingIndex >= 0) {
    normalized.profiles[existingIndex] = profile;
  } else {
    if (normalized.profiles.length >= FOUR_D4Y_MAX_ACCOUNTS) {
      return null;
    }
    normalized.profiles.push(profile);
  }
  normalized.activeProfileId = profile.id;
  return normalizeFourD4yAccountRegistry(normalized);
}

export function removeFourD4yAccountProfile(registry: FourD4yAccountRegistry, profileId: string): FourD4yAccountRegistry {
  const normalized: FourD4yAccountRegistry = normalizeFourD4yAccountRegistry(registry);
  const profiles: FourD4yAccountProfile[] = normalized.profiles.filter((profile: FourD4yAccountProfile) =>
    profile.id !== profileId);
  return {
    activeProfileId: normalized.activeProfileId === profileId ? '' : normalized.activeProfileId,
    profiles: profiles
  };
}

function normalizeFourD4yAccountProfile(value: Object): FourD4yAccountProfile | null {
  const record: Record<string, Object> = value as Record<string, Object>;
  const id: string = typeof record['id'] === 'string' ? record['id'] : '';
  const userId: string = typeof record['userId'] === 'string' ? record['userId'] : '';
  const displayName: string = normalizeDisplayName(record['displayName']);
  if (!/^account_[a-z0-9]+_[a-z0-9]+$/i.test(id) || !/^\d{1,16}$/.test(userId)) {
    return null;
  }
  return {
    id: id,
    userId: userId,
    displayName: displayName.length > 0 ? displayName : '4D4Y 用户 ' + userId,
    lastActivatedAt: normalizeTimestamp(record['lastActivatedAt'])
  };
}

function normalizeDisplayName(value: Object): string {
  if (typeof value !== 'string') {
    return '';
  }
  return value.replace(/[\u0000-\u001F<>]/g, '').trim().slice(0, MAX_DISPLAY_NAME_LENGTH);
}

function normalizeTimestamp(value: Object): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
}

function unwrapWebResult(rawResult: string): string | null {
  try {
    return rawResult.startsWith('"') ? JSON.parse(rawResult) as string : rawResult;
  } catch (_error) {
    return null;
  }
}
