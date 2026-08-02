import { createHash } from "crypto";

function nonEmpty(value: string, label: string): void {
  if (value.length < 1 || value.length > 256) throw new Error(`invalid-${label}`);
}

/** Stable for a UID and cohort salt. Rollout percentage changes never reshuffle. */
export function monthlyStoryRolloutBucket(uid: string, rolloutSaltVersion: string): number {
  nonEmpty(uid, "uid");
  nonEmpty(rolloutSaltVersion, "rollout-salt-version");
  const digest = createHash("sha256")
    .update("dino-monthly-story-rollout\0")
    .update(rolloutSaltVersion)
    .update("\0")
    .update(uid)
    .digest();
  return digest.readUInt32BE(0) % 10_000;
}

export function monthlyStoryRolloutEligible(
  uid: string,
  rolloutSaltVersion: string,
  rolloutBasisPoints: number
): boolean {
  if (!Number.isSafeInteger(rolloutBasisPoints) || rolloutBasisPoints < 0 || rolloutBasisPoints > 10_000) {
    return false;
  }
  return monthlyStoryRolloutBucket(uid, rolloutSaltVersion) < rolloutBasisPoints;
}

/** Opaque owner key for server-only job/deletion queries. Never log its input. */
export function monthlyStoryOwnerKey(uid: string, ownerKeyVersion: string): string {
  nonEmpty(uid, "uid");
  nonEmpty(ownerKeyVersion, "owner-key-version");
  return createHash("sha256")
    .update("dino-monthly-story-owner\0")
    .update(ownerKeyVersion)
    .update("\0")
    .update(uid)
    .digest("hex");
}
