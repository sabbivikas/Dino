export const MONTHLY_STORY_CONTROL_PATH = "featureFlags/monthlyStory";
export const MONTHLY_STORY_CONTROL_MAX_AGE_MS = 24 * 60 * 60 * 1000;
export const MONTHLY_STORY_CONTROL_FUTURE_TOLERANCE_MS = 5 * 60 * 1000;

export type MonthlyStoryControl = {
  visible: boolean;
  enrollmentEnabled: boolean;
  signalUploadEnabled: boolean;
  textGenerationEnabled: boolean;
  audioGenerationEnabled: boolean;
  rolloutBasisPoints: number;
  minimumAppVersion: string;
  dailyTextGenerationCap: number;
  monthlyTextGenerationCap: number;
  dailyAudioGenerationCap: number;
  monthlyBudgetMicros: number;
  monthlyTextBudgetMicros: number;
  monthlyAudioBudgetMicros: number;
  maxTextAttempts: number;
  maxAudioAttempts: number;
  generationVersion: string;
  signalSchemaVersion: number;
  scriptPromptVersion: string;
  criticPromptVersion: string;
  ttsVersion: string;
  updatedAtMillis: number | null;
};

const CONTROL_FIELDS = [
  "visible", "enrollmentEnabled", "signalUploadEnabled",
  "textGenerationEnabled", "audioGenerationEnabled", "rolloutBasisPoints",
  "minimumAppVersion", "dailyTextGenerationCap", "monthlyTextGenerationCap", "dailyAudioGenerationCap",
  "monthlyBudgetMicros", "monthlyTextBudgetMicros", "monthlyAudioBudgetMicros",
  "maxTextAttempts", "maxAudioAttempts", "generationVersion",
  "signalSchemaVersion", "scriptPromptVersion", "criticPromptVersion",
  "ttsVersion", "updatedAt",
] as const;

export const SAFE_DISABLED_MONTHLY_STORY_CONTROL: Readonly<MonthlyStoryControl> = Object.freeze({
  visible: false,
  enrollmentEnabled: false,
  signalUploadEnabled: false,
  textGenerationEnabled: false,
  audioGenerationEnabled: false,
  rolloutBasisPoints: 0,
  minimumAppVersion: "",
  dailyTextGenerationCap: 0,
  monthlyTextGenerationCap: 0,
  dailyAudioGenerationCap: 0,
  monthlyBudgetMicros: 0,
  monthlyTextBudgetMicros: 0,
  monthlyAudioBudgetMicros: 0,
  maxTextAttempts: 0,
  maxAudioAttempts: 0,
  generationVersion: "",
  signalSchemaVersion: 0,
  scriptPromptVersion: "",
  criticPromptVersion: "",
  ttsVersion: "",
  updatedAtMillis: null,
});

export type MonthlyStoryControlParseResult = {
  control: MonthlyStoryControl;
  accepted: boolean;
  reason: "valid" | "missing" | "malformed" | "stale";
};

type TimestampLike = { toMillis(): number };

function exactObject(value: unknown, fields: readonly string[]): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const keys = Object.keys(value);
  return keys.length === fields.length && keys.every((key) => fields.includes(key));
}

function integerIn(value: unknown, minimum: number, maximum: number): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function boundedVersion(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9._-]{1,32}$/.test(value);
}

function validMinimumAppVersion(value: unknown): value is string {
  return typeof value === "string" && /^\d{1,4}(?:\.\d{1,4}){0,3}$/.test(value);
}

function timestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "object" && value !== null && "toMillis" in value &&
      typeof (value as TimestampLike).toMillis === "function") {
    const millis = (value as TimestampLike).toMillis();
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function disabled(reason: MonthlyStoryControlParseResult["reason"]): MonthlyStoryControlParseResult {
  return { control: { ...SAFE_DISABLED_MONTHLY_STORY_CONTROL }, accepted: false, reason };
}

export function parseMonthlyStoryControl(
  value: unknown,
  nowMillis: number,
  maximumAgeMillis = MONTHLY_STORY_CONTROL_MAX_AGE_MS
): MonthlyStoryControlParseResult {
  if (value === undefined || value === null) return disabled("missing");
  if (!Number.isFinite(nowMillis) || !Number.isFinite(maximumAgeMillis) || maximumAgeMillis < 0 ||
      !exactObject(value, CONTROL_FIELDS)) return disabled("malformed");

  const updatedAtMillis = timestampMillis(value.updatedAt);
  const booleans = [value.visible, value.enrollmentEnabled, value.signalUploadEnabled,
    value.textGenerationEnabled, value.audioGenerationEnabled];
  const versions = [value.generationVersion, value.scriptPromptVersion,
    value.criticPromptVersion, value.ttsVersion];

  if (booleans.some((item) => typeof item !== "boolean") ||
      !integerIn(value.rolloutBasisPoints, 0, 10_000) ||
      !validMinimumAppVersion(value.minimumAppVersion) ||
      !integerIn(value.dailyTextGenerationCap, 0, 1_000_000) ||
      !integerIn(value.monthlyTextGenerationCap, 0, 1_000_000) ||
      !integerIn(value.dailyAudioGenerationCap, 0, 1_000_000) ||
      !integerIn(value.monthlyBudgetMicros, 0, Number.MAX_SAFE_INTEGER) ||
      !integerIn(value.monthlyTextBudgetMicros, 0, Number.MAX_SAFE_INTEGER) ||
      !integerIn(value.monthlyAudioBudgetMicros, 0, Number.MAX_SAFE_INTEGER) ||
      (value.monthlyTextBudgetMicros as number) + (value.monthlyAudioBudgetMicros as number) >
        (value.monthlyBudgetMicros as number) ||
      !integerIn(value.maxTextAttempts, 0, 10) ||
      !integerIn(value.maxAudioAttempts, 0, 10) ||
      !integerIn(value.signalSchemaVersion, 1, 1_000) ||
      !versions.every(boundedVersion) || updatedAtMillis === null) {
    return disabled("malformed");
  }

  if (updatedAtMillis > nowMillis + MONTHLY_STORY_CONTROL_FUTURE_TOLERANCE_MS ||
      nowMillis - updatedAtMillis > maximumAgeMillis) return disabled("stale");

  return {
    accepted: true,
    reason: "valid",
    control: {
      visible: value.visible as boolean,
      enrollmentEnabled: value.enrollmentEnabled as boolean,
      signalUploadEnabled: value.signalUploadEnabled as boolean,
      textGenerationEnabled: value.textGenerationEnabled as boolean,
      audioGenerationEnabled: value.audioGenerationEnabled as boolean,
      rolloutBasisPoints: value.rolloutBasisPoints as number,
      minimumAppVersion: value.minimumAppVersion as string,
      dailyTextGenerationCap: value.dailyTextGenerationCap as number,
      monthlyTextGenerationCap: value.monthlyTextGenerationCap as number,
      dailyAudioGenerationCap: value.dailyAudioGenerationCap as number,
      monthlyBudgetMicros: value.monthlyBudgetMicros as number,
      monthlyTextBudgetMicros: value.monthlyTextBudgetMicros as number,
      monthlyAudioBudgetMicros: value.monthlyAudioBudgetMicros as number,
      maxTextAttempts: value.maxTextAttempts as number,
      maxAudioAttempts: value.maxAudioAttempts as number,
      generationVersion: value.generationVersion as string,
      signalSchemaVersion: value.signalSchemaVersion as number,
      scriptPromptVersion: value.scriptPromptVersion as string,
      criticPromptVersion: value.criticPromptVersion as string,
      ttsVersion: value.ttsVersion as string,
      updatedAtMillis,
    },
  };
}

export function monthlyStoryGenerationIsFailClosed(control: MonthlyStoryControl): boolean {
  return !control.enrollmentEnabled || !control.textGenerationEnabled ||
    control.rolloutBasisPoints === 0 || control.dailyTextGenerationCap === 0 ||
    control.monthlyTextGenerationCap === 0 ||
    control.monthlyBudgetMicros === 0 || control.monthlyTextBudgetMicros === 0 ||
    control.maxTextAttempts === 0;
}
