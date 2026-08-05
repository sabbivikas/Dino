import { MonthlyStoryAudioObject, MonthlyStoryAudioObjectStore,
  MonthlyStoryAudioServiceError } from "./monthlyStoryAudioService";

type StorageFile = {
  exists(): Promise<[boolean]>;
  getMetadata(): Promise<[Record<string, unknown>]>;
  save(data: Buffer, options: { resumable: false; validation: "md5"; metadata: Record<string, unknown> }): Promise<void>;
  delete(options: { ignoreNotFound: true }): Promise<void>;
};
export interface MonthlyStoryStorageBucket { file(path: string): StorageFile }

function integerMetadata(value: unknown): number | null {
  if (typeof value !== "string" || !/^\d+$/.test(value)) return null;
  const parsed = Number(value); return Number.isSafeInteger(parsed) ? parsed : null;
}

export class FirebaseMonthlyStoryAudioObjectStore implements MonthlyStoryAudioObjectStore {
  constructor(private readonly bucket: MonthlyStoryStorageBucket) {}
  async inspect(path: string): Promise<MonthlyStoryAudioObject | null> {
    try {
      const file = this.bucket.file(path); if (!(await file.exists())[0]) return null;
      const metadata = (await file.getMetadata())[0];
      const custom = metadata.metadata as Record<string, unknown> | undefined;
      const hash = custom?.audioHash; const bytes = Number(metadata.size);
      const generatedAtMillis = integerMetadata(custom?.generatedAtMillis);
      const providerRequestCount = integerMetadata(custom?.providerRequestCount);
      const estimatedCostMicros = integerMetadata(custom?.estimatedCostMicros);
      const durationMillis = custom?.durationMillis === "" ? null : integerMetadata(custom?.durationMillis);
      if (typeof hash !== "string" || !/^[a-f0-9]{64}$/.test(hash) || !Number.isSafeInteger(bytes) || bytes < 4 ||
          generatedAtMillis === null || providerRequestCount === null || estimatedCostMicros === null ||
          typeof custom?.ttsVersion !== "string" || typeof custom?.voiceKey !== "string") {
        throw new MonthlyStoryAudioServiceError("storage-failure");
      }
      return { path, hash, bytes, durationMillis, generatedAtMillis, providerRequestCount,
        estimatedCostMicros, ttsVersion: custom.ttsVersion, voiceKey: custom.voiceKey };
    } catch (error) {
      if (error instanceof MonthlyStoryAudioServiceError) throw error;
      throw new MonthlyStoryAudioServiceError("storage-failure");
    }
  }
  async write(path: string, audio: Buffer, metadata: Omit<MonthlyStoryAudioObject, "path" | "bytes">): Promise<void> {
    try {
      await this.bucket.file(path).save(audio, { resumable: false, validation: "md5", metadata: {
        contentType: "audio/mpeg", cacheControl: "private,no-store,max-age=0",
        metadata: { audioHash: metadata.hash, generatedAtMillis: String(metadata.generatedAtMillis),
          providerRequestCount: String(metadata.providerRequestCount),
          estimatedCostMicros: String(metadata.estimatedCostMicros),
          durationMillis: metadata.durationMillis === null ? "" : String(metadata.durationMillis),
          ttsVersion: metadata.ttsVersion, voiceKey: metadata.voiceKey }
      } });
    } catch { throw new MonthlyStoryAudioServiceError("storage-failure"); }
  }
  async delete(path: string): Promise<void> {
    try { await this.bucket.file(path).delete({ ignoreNotFound: true }); }
    catch { throw new MonthlyStoryAudioServiceError("storage-failure"); }
  }
}
