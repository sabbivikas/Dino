import { monthlyStoryOwnerKey } from "./monthlyStoryRollout";

/**
 * Developer inventory only. This module is intentionally not wired into the
 * current account-deletion function on this branch.
 */
export const MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY = Object.freeze({
  documentTrees: [
    "monthlyStorySettings/{uid}",
    "monthlyStorySignals/{uid}",
    "monthlyStories/{uid}",
    "monthlyStoryDeleted/{uid}",
  ],
  serverQueries: [
    "monthlyStoryJobs where ownerKey == hash(uid)",
    "monthlyStorySpend/{month}/reservations where jobId is in owned jobs",
    "monthlyStorySpend/{month}/deterministicJobs where jobId is in owned jobs",
  ],
  storagePrefixes: ["monthlyStories/{uid}/"],
  localCaches: ["Library/Caches/MonthlyStories/{uid}/"],
  integrationStatus: "not-integrated-with-current-account-deletion",
} as const);

export interface MonthlyStoryDeletionDependencies {
  deleteDocumentTree(path: string): Promise<void>;
  findJobIdsByOwnerKey(ownerKey: string): Promise<string[]>;
  deleteSpendReservationsForJob(jobId: string): Promise<void>;
  deleteDeterministicUsageForJob(jobId: string): Promise<void>;
  deleteJob(jobId: string): Promise<void>;
  deleteStoragePrefix(prefix: string): Promise<void>;
}

/**
 * Pure, dependency-injected future hook. Callers must still delete the local
 * audio cache on-device. Existing account deletion does not call this yet.
 */
export async function deleteMonthlyStoryAccountResources(
  uid: string,
  ownerKeyVersion: string,
  dependencies: MonthlyStoryDeletionDependencies
): Promise<void> {
  if (!uid || !ownerKeyVersion) throw new Error("monthly-story-deletion-input-invalid");
  const ownerKey = monthlyStoryOwnerKey(uid, ownerKeyVersion);
  const jobIds = await dependencies.findJobIdsByOwnerKey(ownerKey);
  if (new Set(jobIds).size !== jobIds.length || jobIds.some((id) => !/^ms_[a-f0-9]{64}$/.test(id))) {
    throw new Error("monthly-story-deletion-job-inventory-invalid");
  }

  const firstPass = await Promise.allSettled([
    dependencies.deleteDocumentTree(`monthlyStorySettings/${uid}`),
    dependencies.deleteDocumentTree(`monthlyStorySignals/${uid}`),
    dependencies.deleteDocumentTree(`monthlyStories/${uid}`),
    ...jobIds.map((jobId) => dependencies.deleteSpendReservationsForJob(jobId)),
    ...jobIds.map((jobId) => dependencies.deleteDeterministicUsageForJob(jobId)),
    dependencies.deleteStoragePrefix(`monthlyStories/${uid}/`),
  ]);
  const firstFailure = firstPass.find((result): result is PromiseRejectedResult => result.status === "rejected");
  if (firstFailure) throw firstFailure.reason;

  const secondPass = await Promise.allSettled([
    ...jobIds.map((jobId) => dependencies.deleteJob(jobId)),
    dependencies.deleteDocumentTree(`monthlyStoryDeleted/${uid}`),
  ]);
  const secondFailure = secondPass.find((result): result is PromiseRejectedResult => result.status === "rejected");
  if (secondFailure) throw secondFailure.reason;
}
