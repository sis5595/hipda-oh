import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

/**
 * Encrypted storage for an already authenticated 4D4Y session snapshot.
 *
 * Asset Store is the only persistent location for the secret. The asset is
 * not marked IS_PERSISTENT, so it is removed with the app on uninstall; it
 * also uses DEVICE_UNLOCKED access. Passwords never enter this class.
 */
export class FourD4yAccountSessionStore {
  private static readonly aliasPrefix: string = 'hipdaoh_4d4y_session_';
  private static readonly maxSecretBytes: number = 1024;
  private static readonly encoder: util.TextEncoder = new util.TextEncoder();
  private static readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  static async save(profileId: string, sessionSecret: string): Promise<boolean> {
    if (!FourD4yAccountSessionStore.isValidProfileId(profileId) || sessionSecret.length === 0) {
      return false;
    }
    const alias: Uint8Array = FourD4yAccountSessionStore.toBytes(
      FourD4yAccountSessionStore.aliasPrefix + profileId);
    const secret: Uint8Array = FourD4yAccountSessionStore.toBytes(sessionSecret);
    if (secret.length > FourD4yAccountSessionStore.maxSecretBytes) {
      return false;
    }
    try {
      const attributes: asset.AssetMap = new Map();
      attributes.set(asset.Tag.ALIAS, alias);
      attributes.set(asset.Tag.SECRET, secret);
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      await asset.add(attributes);
      return true;
    } catch (_addError) {
      try {
        const query: asset.AssetMap = new Map();
        query.set(asset.Tag.ALIAS, alias);
        const replacement: asset.AssetMap = new Map();
        replacement.set(asset.Tag.SECRET, secret);
        // Asset Store only permits SECRET as the mutable session payload here.
        // ACCESSIBILITY is established when the asset is first created and is a
        // query constraint, not an update attribute.
        await asset.update(query, replacement);
        return true;
      } catch (_updateError) {
        return false;
      }
    }
  }

  static async load(profileId: string): Promise<string | null> {
    if (!FourD4yAccountSessionStore.isValidProfileId(profileId)) {
      return null;
    }
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, FourD4yAccountSessionStore.toBytes(
        FourD4yAccountSessionStore.aliasPrefix + profileId));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const results: Array<asset.AssetMap> = await asset.query(query);
      if (results.length !== 1) {
        return null;
      }
      const secret: Uint8Array | undefined = results[0].get(asset.Tag.SECRET) as Uint8Array | undefined;
      if (secret === undefined || secret.length === 0 || secret.length > FourD4yAccountSessionStore.maxSecretBytes) {
        return null;
      }
      const value: string = FourD4yAccountSessionStore.decoder.decodeToString(secret);
      return value.length > 0 && value.length <= 900 ? value : null;
    } catch (_error) {
      return null;
    }
  }

  static async remove(profileId: string): Promise<boolean> {
    if (!FourD4yAccountSessionStore.isValidProfileId(profileId)) {
      return false;
    }
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, FourD4yAccountSessionStore.toBytes(
        FourD4yAccountSessionStore.aliasPrefix + profileId));
      await asset.remove(query);
      return true;
    } catch (_error) {
      // Removing an already absent secret has the same desired end state.
      return true;
    }
  }

  private static toBytes(value: string): Uint8Array {
    return FourD4yAccountSessionStore.encoder.encodeInto(value);
  }

  private static isValidProfileId(profileId: string): boolean {
    return /^account_[a-z0-9]+_[a-z0-9]+$/i.test(profileId);
  }

}
