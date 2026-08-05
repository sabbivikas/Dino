import { MonthlyStoryControl } from "./monthlyStoryControl";

export const MONTHLY_STORY_SIGNAL_SCHEMA_VERSION = 1;
export const MONTHLY_STORY_SETTINGS_VERSION = 1;
export const MONTHLY_STORY_MAX_EVIDENCE_ITEMS = 64;
export const MONTHLY_STORY_MAX_DAYS_PER_SET = 31;

export class MonthlyStoryValidationError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "MonthlyStoryValidationError";
  }
}

function record(value: unknown, fields: readonly string[], optional: readonly string[] = []): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryValidationError("invalid-object");
  }
  const result = value as Record<string, unknown>;
  const allowed = new Set([...fields, ...optional]);
  if (Object.keys(result).some((key) => !allowed.has(key))) {
    throw new MonthlyStoryValidationError("unknown-field");
  }
  if (fields.some((key) => !Object.prototype.hasOwnProperty.call(result, key))) {
    throw new MonthlyStoryValidationError("missing-field");
  }
  return result;
}

function bool(value: unknown): boolean {
  if (typeof value !== "boolean") throw new MonthlyStoryValidationError("invalid-boolean");
  return value;
}

function integer(value: unknown, minimum: number, maximum: number): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new MonthlyStoryValidationError("invalid-integer");
  }
  return value;
}

function enumValue<T extends string>(value: unknown, values: readonly T[]): T {
  if (typeof value !== "string" || !values.includes(value as T)) {
    throw new MonthlyStoryValidationError("invalid-enum");
  }
  return value as T;
}

function boundedToken(value: unknown, pattern: RegExp, minimum: number, maximum: number): string {
  if (typeof value !== "string" || value.length < minimum || value.length > maximum || !pattern.test(value)) {
    throw new MonthlyStoryValidationError("invalid-token");
  }
  return value;
}

function evidenceId(value: unknown): string {
  const id = boundedToken(value, /^[a-z0-9._-]+$/, 8, 64);
  if (id.includes("..")) throw new MonthlyStoryValidationError("invalid-evidence-id");
  return id;
}

function timestampMillis(value: unknown): number {
  if (value instanceof Date && Number.isFinite(value.getTime())) return value.getTime();
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) return value;
  if (typeof value === "object" && value !== null && "toMillis" in value &&
      typeof (value as { toMillis(): number }).toMillis === "function") {
    const millis = (value as { toMillis(): number }).toMillis();
    if (Number.isSafeInteger(millis) && millis >= 0) return millis;
  }
  throw new MonthlyStoryValidationError("invalid-timestamp");
}

export function authenticatedMonthlyStoryUid(auth: { uid?: unknown } | null | undefined): string {
  if (!auth || typeof auth.uid !== "string" || auth.uid.length < 1 || auth.uid.length > 128) {
    throw new MonthlyStoryValidationError("authentication-required");
  }
  return auth.uid;
}

export function isValidMonthlyStoryTimeZone(value: unknown): value is string {
  if (typeof value !== "string" || value.length < 1 || value.length > 64) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format(0);
    return true;
  } catch {
    return false;
  }
}

export function requireMonthKey(value: unknown): string {
  const monthKey = boundedToken(value, /^\d{4}-(0[1-9]|1[0-2])$/, 7, 7);
  const year = Number(monthKey.slice(0, 4));
  if (year < 2000 || year > 2200) throw new MonthlyStoryValidationError("invalid-month");
  return monthKey;
}

export function requireDay(value: unknown): string {
  const day = boundedToken(value, /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/, 10, 10);
  const [year, month, date] = day.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, date));
  if (parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== date) {
    throw new MonthlyStoryValidationError("invalid-day");
  }
  return day;
}

export function requireGenerationVersion(value: unknown): string {
  return boundedToken(value, /^[A-Za-z0-9._-]+$/, 1, 32);
}

export type MonthlyStorySettings = {
  enabled: boolean;
  useJournalThemes: boolean;
  useHealthPatterns: boolean;
  audioEnabled: boolean;
  timezone: string;
  timezoneEffectiveMonth: string;
  settingsVersion: number;
  updatedAtMillis: number | null;
};

export const SAFE_MONTHLY_STORY_SETTINGS: Readonly<MonthlyStorySettings> = Object.freeze({
  enabled: false,
  useJournalThemes: false,
  useHealthPatterns: false,
  audioEnabled: false,
  timezone: "UTC",
  timezoneEffectiveMonth: "2000-01",
  settingsVersion: MONTHLY_STORY_SETTINGS_VERSION,
  updatedAtMillis: null,
});

export function parseMonthlyStorySettingsDocument(value: unknown): MonthlyStorySettings {
  if (value === undefined || value === null) return { ...SAFE_MONTHLY_STORY_SETTINGS };
  const data = record(value, ["enabled", "useJournalThemes", "useHealthPatterns", "audioEnabled",
    "timezone", "timezoneEffectiveMonth", "settingsVersion", "updatedAt"]);
  if (!isValidMonthlyStoryTimeZone(data.timezone)) throw new MonthlyStoryValidationError("invalid-timezone");
  const settingsVersion = integer(data.settingsVersion, 1, 1_000);
  if (settingsVersion !== MONTHLY_STORY_SETTINGS_VERSION) {
    throw new MonthlyStoryValidationError("unsupported-settings-version");
  }
  return { enabled: bool(data.enabled), useJournalThemes: bool(data.useJournalThemes),
    useHealthPatterns: bool(data.useHealthPatterns), audioEnabled: bool(data.audioEnabled),
    timezone: data.timezone, timezoneEffectiveMonth: requireMonthKey(data.timezoneEffectiveMonth),
    settingsVersion, updatedAtMillis: timestampMillis(data.updatedAt) };
}

export function validateMonthlyStorySettingsContract(
  auth: { uid?: unknown } | null | undefined,
  payload: unknown,
  control: MonthlyStoryControl,
  nowMillis: number
): { uid: string; settings: MonthlyStorySettings } {
  const uid = authenticatedMonthlyStoryUid(auth);
  const data = record(payload, ["enabled", "useJournalThemes", "useHealthPatterns", "audioEnabled",
    "timezone", "timezoneEffectiveMonth", "settingsVersion"]);
  if (!control.enrollmentEnabled) throw new MonthlyStoryValidationError("feature-disabled");
  if (!Number.isFinite(nowMillis)) throw new MonthlyStoryValidationError("invalid-time");
  if (!isValidMonthlyStoryTimeZone(data.timezone)) throw new MonthlyStoryValidationError("invalid-timezone");
  const settingsVersion = integer(data.settingsVersion, 1, 1_000);
  if (settingsVersion !== MONTHLY_STORY_SETTINGS_VERSION) {
    throw new MonthlyStoryValidationError("unsupported-settings-version");
  }
  const audioEnabled = bool(data.audioEnabled);
  if (audioEnabled && !control.audioGenerationEnabled) {
    throw new MonthlyStoryValidationError("feature-disabled");
  }
  return {
    uid,
    settings: {
      enabled: bool(data.enabled),
      useJournalThemes: bool(data.useJournalThemes),
      useHealthPatterns: bool(data.useHealthPatterns),
      audioEnabled,
      timezone: data.timezone,
      timezoneEffectiveMonth: requireMonthKey(data.timezoneEffectiveMonth),
      settingsVersion,
      updatedAtMillis: nowMillis,
    },
  };
}

export const MONTHLY_STORY_EVIDENCE_CATEGORIES = [
  "emotionalShape", "repeatedTheme", "sleepPattern", "movementPattern",
  "restorativePractice", "recommendationAction", "nextMonthSuggestionBasis",
] as const;
export type MonthlyStoryEvidenceCategory = typeof MONTHLY_STORY_EVIDENCE_CATEGORIES[number];

const MOOD_SHAPES = ["mostlyBright", "mostlyHeavy", "mixed", "steady", "variable"] as const;
const MOOD_DIRECTIONS = ["brighter", "heavier", "steady", "variable", "unknown"] as const;
const JOURNAL_THEMES = ["workPressure", "missingHome", "family", "relationships", "uncertainty",
  "personalProjects", "rest", "change", "socialConnection"] as const;
const SLEEP_BUCKETS = ["moreRestful", "lessRestful", "variable", "steady"] as const;
const MOVEMENT_BUCKETS = ["moreActive", "lessActive", "variable", "steady"] as const;
const PRACTICES = ["meditation", "breathing", "focus"] as const;
const RECOMMENDATION_ACTIONS = ["delivered", "opened", "kept", "leftUnopened"] as const;
const SUGGESTION_BASES = ["continueRest", "protectPersonalTime", "seekConnection",
  "continueHelpfulPractice", "makeSpaceForProjects"] as const;
const EVIDENCE_SOURCES = ["mood", "authorizedJournalTheme", "authorizedHealthSummary",
  "practicePresence", "recommendationOutcome", "deterministicCombination"] as const;
const CONFIDENCES = ["low", "medium", "high"] as const;
const ELIGIBILITY_CODES = ["eligibleStandard", "eligibleMoodOnly", "featureDisabled", "insufficientSpan",
  "insufficientEvidenceDays", "insufficientMoodDays", "insufficientCorroboration",
  "insufficientObservations", "safetyHold", "monthNotClosed", "alreadyCompleted",
  "deletedTombstone", "invalidTimezone", "invalidMonthBoundary"] as const;

export type MonthlyStoryPermissions = {
  featureEnabled: boolean;
  journalThemesEnabled: boolean;
  healthPatternsEnabled: boolean;
  audioEnabled: boolean;
};

export type MonthlyStoryEvidence = {
  id: string;
  category: MonthlyStoryEvidenceCategory;
  value: Record<string, string>;
  confidence: typeof CONFIDENCES[number];
  startDay: string;
  endDay: string;
  source: typeof EVIDENCE_SOURCES[number];
  allowedForNarration: boolean;
};

export type MonthlyStorySignal = {
  schemaVersion: number;
  monthKey: string;
  timeZone: string;
  evidenceStartDay: string;
  evidenceEndDay: string;
  usableEvidenceDays: string[];
  moodEvidenceDays: string[];
  corroboratingEvidenceDays: string[];
  permissions: MonthlyStoryPermissions;
  isStorySafetyEligible: true;
  evidence: MonthlyStoryEvidence[];
  eligibility?: { code: typeof ELIGIBILITY_CODES[number]; permitsCauseNarration: boolean };
};

function stringArray(value: unknown, maximum: number): string[] {
  if (!Array.isArray(value) || value.length > maximum) throw new MonthlyStoryValidationError("array-limit");
  const result = value.map(requireDay);
  if (new Set(result).size !== result.length) throw new MonthlyStoryValidationError("duplicate-value");
  return result.sort();
}

function parseEvidenceValue(value: unknown): { category: MonthlyStoryEvidenceCategory; value: Record<string, string> } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryValidationError("invalid-evidence-value");
  }
  const type = enumValue((value as Record<string, unknown>).type, MONTHLY_STORY_EVIDENCE_CATEGORIES);
  let data: Record<string, unknown>;
  let parsed: Record<string, string>;
  switch (type) {
  case "emotionalShape":
    data = record(value, ["type", "moodShape", "moodDirection"]);
    parsed = { type, moodShape: enumValue(data.moodShape, MOOD_SHAPES),
      moodDirection: enumValue(data.moodDirection, MOOD_DIRECTIONS) };
    break;
  case "repeatedTheme":
    data = record(value, ["type", "theme"]);
    parsed = { type, theme: enumValue(data.theme, JOURNAL_THEMES) };
    break;
  case "sleepPattern":
    data = record(value, ["type", "sleep"]);
    parsed = { type, sleep: enumValue(data.sleep, SLEEP_BUCKETS) };
    break;
  case "movementPattern":
    data = record(value, ["type", "movement"]);
    parsed = { type, movement: enumValue(data.movement, MOVEMENT_BUCKETS) };
    break;
  case "restorativePractice":
    data = record(value, ["type", "practice"]);
    parsed = { type, practice: enumValue(data.practice, PRACTICES) };
    break;
  case "recommendationAction":
    data = record(value, ["type", "recommendation"]);
    parsed = { type, recommendation: enumValue(data.recommendation, RECOMMENDATION_ACTIONS) };
    break;
  case "nextMonthSuggestionBasis":
    data = record(value, ["type", "suggestion"]);
    parsed = { type, suggestion: enumValue(data.suggestion, SUGGESTION_BASES) };
    break;
  }
  return { category: type, value: parsed };
}

function parseEvidence(value: unknown): MonthlyStoryEvidence {
  const data = record(value, ["id", "value", "confidence", "startDay", "endDay", "source", "allowedForNarration"]);
  const parsedValue = parseEvidenceValue(data.value);
  const source = enumValue(data.source, EVIDENCE_SOURCES);
  const startDay = requireDay(data.startDay);
  const endDay = requireDay(data.endDay);
  if (startDay > endDay) throw new MonthlyStoryValidationError("invalid-evidence-range");
  if (parsedValue.category === "repeatedTheme" && source !== "authorizedJournalTheme") {
    throw new MonthlyStoryValidationError("invalid-evidence-source");
  }
  if ((parsedValue.category === "sleepPattern" || parsedValue.category === "movementPattern") &&
      source !== "authorizedHealthSummary") throw new MonthlyStoryValidationError("invalid-evidence-source");
  return {
    id: evidenceId(data.id),
    category: parsedValue.category,
    value: parsedValue.value,
    confidence: enumValue(data.confidence, CONFIDENCES),
    startDay,
    endDay,
    source,
    allowedForNarration: bool(data.allowedForNarration),
  };
}

export function parseMonthlyStorySignal(value: unknown): MonthlyStorySignal {
  const data = record(value, ["schemaVersion", "monthKey", "timeZone", "evidenceStartDay", "evidenceEndDay",
    "usableEvidenceDays", "moodEvidenceDays", "corroboratingEvidenceDays", "permissions",
    "isStorySafetyEligible", "evidence"], ["eligibility"]);
  const schemaVersion = integer(data.schemaVersion, 1, 1_000);
  if (schemaVersion !== MONTHLY_STORY_SIGNAL_SCHEMA_VERSION) {
    throw new MonthlyStoryValidationError("unsupported-signal-schema");
  }
  const monthKey = requireMonthKey(data.monthKey);
  if (!isValidMonthlyStoryTimeZone(data.timeZone)) throw new MonthlyStoryValidationError("invalid-timezone");
  const evidenceStartDay = requireDay(data.evidenceStartDay);
  const evidenceEndDay = requireDay(data.evidenceEndDay);
  const usableEvidenceDays = stringArray(data.usableEvidenceDays, MONTHLY_STORY_MAX_DAYS_PER_SET);
  const moodEvidenceDays = stringArray(data.moodEvidenceDays, MONTHLY_STORY_MAX_DAYS_PER_SET);
  const corroboratingEvidenceDays = stringArray(data.corroboratingEvidenceDays, MONTHLY_STORY_MAX_DAYS_PER_SET);
  const permissionsData = record(data.permissions,
    ["featureEnabled", "journalThemesEnabled", "healthPatternsEnabled", "audioEnabled"]);
  const permissions: MonthlyStoryPermissions = {
    featureEnabled: bool(permissionsData.featureEnabled),
    journalThemesEnabled: bool(permissionsData.journalThemesEnabled),
    healthPatternsEnabled: bool(permissionsData.healthPatternsEnabled),
    audioEnabled: bool(permissionsData.audioEnabled),
  };
  if (data.isStorySafetyEligible !== true) throw new MonthlyStoryValidationError("safety-ineligible");
  if (!Array.isArray(data.evidence) || data.evidence.length > MONTHLY_STORY_MAX_EVIDENCE_ITEMS) {
    throw new MonthlyStoryValidationError("evidence-limit");
  }
  const evidence = data.evidence.map(parseEvidence);
  if (new Set(evidence.map((item) => item.id)).size !== evidence.length) {
    throw new MonthlyStoryValidationError("duplicate-evidence-id");
  }
  const allDays = [...usableEvidenceDays, ...moodEvidenceDays, ...corroboratingEvidenceDays,
    evidenceStartDay, evidenceEndDay, ...evidence.flatMap((item) => [item.startDay, item.endDay])];
  if (evidenceStartDay > evidenceEndDay || allDays.some((day) => !day.startsWith(`${monthKey}-`) ||
      day < evidenceStartDay || day > evidenceEndDay) ||
      moodEvidenceDays.some((day) => !usableEvidenceDays.includes(day)) ||
      corroboratingEvidenceDays.some((day) => !usableEvidenceDays.includes(day))) {
    throw new MonthlyStoryValidationError("evidence-outside-month");
  }
  if (!permissions.journalThemesEnabled && evidence.some((item) => item.category === "repeatedTheme")) {
    throw new MonthlyStoryValidationError("journal-permission-required");
  }
  if (!permissions.healthPatternsEnabled && evidence.some((item) =>
    item.category === "sleepPattern" || item.category === "movementPattern")) {
    throw new MonthlyStoryValidationError("health-permission-required");
  }
  let eligibility: MonthlyStorySignal["eligibility"];
  if (data.eligibility !== undefined) {
    const eligibilityData = record(data.eligibility, ["code", "permitsCauseNarration"]);
    eligibility = {
      code: enumValue(eligibilityData.code, ELIGIBILITY_CODES),
      permitsCauseNarration: bool(eligibilityData.permitsCauseNarration),
    };
  }
  return {
    schemaVersion, monthKey, timeZone: data.timeZone, evidenceStartDay, evidenceEndDay,
    usableEvidenceDays, moodEvidenceDays, corroboratingEvidenceDays, permissions,
    isStorySafetyEligible: true, evidence, ...(eligibility ? { eligibility } : {}),
  };
}

export function validateMonthlyStorySignalUploadContract(
  auth: { uid?: unknown } | null | undefined,
  payload: unknown,
  control: MonthlyStoryControl,
  settings: MonthlyStorySettings
): { uid: string; signal: MonthlyStorySignal } {
  const uid = authenticatedMonthlyStoryUid(auth);
  if (!control.enrollmentEnabled || !control.signalUploadEnabled) {
    throw new MonthlyStoryValidationError("signal-upload-disabled");
  }
  const signal = parseMonthlyStorySignal(payload);
  if (signal.schemaVersion !== control.signalSchemaVersion || !settings.enabled ||
      signal.timeZone !== settings.timezone ||
      signal.permissions.featureEnabled !== settings.enabled ||
      signal.permissions.journalThemesEnabled !== settings.useJournalThemes ||
      signal.permissions.healthPatternsEnabled !== settings.useHealthPatterns ||
      signal.permissions.audioEnabled !== settings.audioEnabled) {
    throw new MonthlyStoryValidationError("settings-mismatch");
  }
  return { uid, signal };
}

export const MONTHLY_STORY_STATUSES = ["pending", "planning", "scriptGenerating", "scriptValidating",
  "textReady", "audioGenerating", "ready", "failed", "deleted"] as const;
export type MonthlyStoryStatus = typeof MONTHLY_STORY_STATUSES[number];

export type MonthlyStoryStorageCleanupMarker = {
  state: "notRequired" | "pending" | "complete";
  updatedAtMillis: number;
};

function parseStorageCleanup(value: unknown): MonthlyStoryStorageCleanupMarker {
  const data = record(value, ["state", "updatedAtMillis"]);
  return {
    state: enumValue(data.state, ["notRequired", "pending", "complete"] as const),
    updatedAtMillis: integer(data.updatedAtMillis, 0, Number.MAX_SAFE_INTEGER),
  };
}

export type MonthlyStoryDocument = {
  monthKey: string;
  generationVersion: string;
  status: MonthlyStoryStatus;
  signalSchemaVersion: number;
  createdAtMillis: number;
  updatedAtMillis: number;
  expiresAtMillis: number;
  storageCleanup: MonthlyStoryStorageCleanupMarker;
};

export function parseMonthlyStoryDocument(value: unknown): MonthlyStoryDocument {
  const data = record(value, ["monthKey", "generationVersion", "status", "signalSchemaVersion",
    "createdAtMillis", "updatedAtMillis", "expiresAtMillis", "storageCleanup"]);
  const result: MonthlyStoryDocument = {
    monthKey: requireMonthKey(data.monthKey),
    generationVersion: requireGenerationVersion(data.generationVersion),
    status: enumValue(data.status, MONTHLY_STORY_STATUSES),
    signalSchemaVersion: integer(data.signalSchemaVersion, 1, 1_000),
    createdAtMillis: integer(data.createdAtMillis, 0, Number.MAX_SAFE_INTEGER),
    updatedAtMillis: integer(data.updatedAtMillis, 0, Number.MAX_SAFE_INTEGER),
    expiresAtMillis: integer(data.expiresAtMillis, 0, Number.MAX_SAFE_INTEGER),
    storageCleanup: parseStorageCleanup(data.storageCleanup),
  };
  if (result.updatedAtMillis < result.createdAtMillis || result.expiresAtMillis <= result.createdAtMillis) {
    throw new MonthlyStoryValidationError("invalid-story-time");
  }
  return result;
}

export type MonthlyStoryDeletedTombstone = {
  monthKey: string;
  generationVersion: string;
  reason: "accountDeletion" | "userRequest" | "retention" | "safety";
  deletedAtMillis: number;
  expiresAtMillis: number;
  storageCleanup: MonthlyStoryStorageCleanupMarker;
};

export function parseMonthlyStoryDeletedTombstone(value: unknown): MonthlyStoryDeletedTombstone {
  const data = record(value, ["monthKey", "generationVersion", "reason", "deletedAtMillis",
    "expiresAtMillis", "storageCleanup"]);
  const result: MonthlyStoryDeletedTombstone = {
    monthKey: requireMonthKey(data.monthKey),
    generationVersion: requireGenerationVersion(data.generationVersion),
    reason: enumValue(data.reason, ["accountDeletion", "userRequest", "retention", "safety"] as const),
    deletedAtMillis: integer(data.deletedAtMillis, 0, Number.MAX_SAFE_INTEGER),
    expiresAtMillis: integer(data.expiresAtMillis, 0, Number.MAX_SAFE_INTEGER),
    storageCleanup: parseStorageCleanup(data.storageCleanup),
  };
  if (result.expiresAtMillis <= result.deletedAtMillis) {
    throw new MonthlyStoryValidationError("invalid-tombstone-time");
  }
  return result;
}

export function monthlyStoryTombstoneBlocks(
  tombstone: MonthlyStoryDeletedTombstone | null,
  monthKey: string,
  generationVersion: string,
  nowMillis: number
): boolean {
  return tombstone !== null && tombstone.monthKey === monthKey &&
    tombstone.generationVersion === generationVersion && tombstone.expiresAtMillis > nowMillis;
}

export const MONTHLY_STORY_PATHS = Object.freeze({
  settings: (uid: string) => `monthlyStorySettings/${uid}`,
  signal: (uid: string, monthKey: string) => `monthlyStorySignals/${uid}/months/${monthKey}`,
  story: (uid: string, monthKey: string) => `monthlyStories/${uid}/months/${monthKey}`,
  tombstone: (uid: string, monthKey: string) => `monthlyStoryDeleted/${uid}/months/${monthKey}`,
  audio: (uid: string, monthKey: string, generationVersion: string) =>
    `monthlyStories/${uid}/${monthKey}/${generationVersion}/story.mp3`,
});
