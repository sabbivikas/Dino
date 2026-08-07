import { FirestoreDocument, FirestoreSnapshot, FirestoreTransaction,
  MonthlyStoryFirestoreDependency } from "./monthlyStoryRepository";
import { MonthlyStoryBudgetQuery,
  MonthlyStoryCollectionGroupDependency } from "./monthlyStoryBudgetRepository";

/**
 * TEST-SUPPORT MODULE — no production code imports this, and nothing here is wired into index.ts.
 *
 * It lives in `src/` (and so compiles into `lib/`) rather than in a `.test.ts` file for one
 * mechanical reason: `npm test` runs `node --test lib/*.test.js`, and a `.test.js` module imported
 * by another `.test.js` module has its tests RE-REGISTERED inside the importing file's process.
 * When this fake lived in `monthlyStoryAudioRepository.test.ts`, importing it from
 * `monthlyStoryBudgetRepository.test.ts` re-ran that file's 18 tests and inflated the reported
 * total from 481 to 499. The filename deliberately does NOT match `lib/*.test.js`, so `node --test`
 * never picks it up and the count stays true.
 */

type Operation = { kind: "get" | "set" | "create" | "delete"; path: string };

/** One `where(...)` clause, recorded so a test can assert a query was BUILT with it. */
export type FakeQueryPredicate = { field: string; operation: "==" | "<="; value: unknown };
/** A collection-group query as it was built — kept even when its get() is made to throw. */
export type FakeQuery = { collectionId: string; predicates: FakeQueryPredicate[]; limit: number | null };

function matchesPredicate(data: Record<string, unknown>, predicate: FakeQueryPredicate): boolean {
  const value = data[predicate.field];
  // Firestore never matches a document that lacks the filtered field at all — which is precisely
  // how the `ledger` clause excludes the audio ledger's reservations.
  if (value === undefined) return false;
  if (predicate.operation === "==") return value === predicate.value;
  return typeof value === "number" && typeof predicate.value === "number" && value <= predicate.value;
}

// Real Firestore rejects a get() issued after ANY write inside the same transaction. This fake used
// to allow it, and that permissiveness is exactly how the markAudioReady read-after-write bug
// survived a green suite. The rule below is enforced per transaction attempt, so any transaction in
// any production function driven through this fake is checked for free.
export class FakeFirestore implements MonthlyStoryFirestoreDependency, MonthlyStoryCollectionGroupDependency {
  readonly documents = new Map<string, Record<string, unknown>>();
  operations: Operation[] = [];
  /** Every collection-group query built through this fake, in order, with its clauses. */
  readonly queries: FakeQuery[] = [];
  /** When set, every collection-group get() throws it (models a missing composite index). */
  queryFailure: Error | null = null;

  doc(path: string): FirestoreDocument {
    const snapshot = () => this.snapshot(path);
    return { path, get: async () => snapshot(), delete: async () => { this.documents.delete(path); },
      set: async (data: unknown) => { this.documents.set(path, data as Record<string, unknown>); },
    } as unknown as FirestoreDocument;
  }

  collection(): never { throw new Error("collection queries are unused by these tests"); }

  // Collection-group queries are read-only and never run inside a transaction, so they are
  // recorded in `queries` rather than in `operations`: the reads-before-writes rule above, and
  // every existing assertion over `operations`, are untouched by this addition.
  collectionGroup(collectionId: string): MonthlyStoryBudgetQuery {
    const record: FakeQuery = { collectionId, predicates: [], limit: null };
    this.queries.push(record);
    const query: MonthlyStoryBudgetQuery = {
      where: (field, operation, value) => { record.predicates.push({ field, operation, value }); return query; },
      limit: (count) => { record.limit = count; return query; },
      get: async () => {
        if (this.queryFailure !== null) throw this.queryFailure;
        const segments = (path: string): string[] => path.split("/");
        const matched = [...this.documents.entries()]
          .filter(([path]) => segments(path).slice(0, -1).at(-1) === record.collectionId)
          .filter(([, data]) => record.predicates.every((predicate) => matchesPredicate(data, predicate)))
          .map(([path, data]) => ({ id: segments(path).at(-1) as string,
            data: () => structuredClone(data) }));
        return { docs: record.limit === null ? matched : matched.slice(0, record.limit) };
      },
    };
    return query;
  }

  private snapshot(path: string): FirestoreSnapshot {
    const value = this.documents.get(path);
    return { exists: value !== undefined, data: () => structuredClone(value) };
  }

  // Every attempt gets its own transaction object and its own read-only-phase state, so the rule
  // resets per transaction — and would reset per retry too, since a retry is just another attempt().
  runTransaction<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T> {
    return this.attempt(operation);
  }

  private attempt<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T> {
    const pathOf = (reference: unknown): string => (reference as { path: string }).path;
    // null until this attempt issues its first write; from then on the attempt is write-only.
    let firstWrite: { kind: "set" | "create" | "delete"; path: string } | null = null;
    const write = (kind: "set" | "create" | "delete", path: string): void => {
      this.operations.push({ kind, path });
      if (firstWrite === null) firstWrite = { kind, path };
    };
    const transaction: FirestoreTransaction = {
      get: async (reference) => {
        const path = pathOf(reference);
        // Logged before the throw so `operations` still shows the full attempted sequence.
        this.operations.push({ kind: "get", path });
        if (firstWrite !== null) {
          throw new Error("Firestore transactions require all reads to be executed before all writes: " +
            `get(${path}) was issued after ${firstWrite.kind}(${firstWrite.path})`);
        }
        return this.snapshot(path);
      },
      create: (reference, data) => {
        const path = pathOf(reference);
        write("create", path);
        if (this.documents.has(path)) throw new Error("already-exists");
        this.documents.set(path, structuredClone(data) as Record<string, unknown>);
      },
      set: (reference, data) => {
        const path = pathOf(reference);
        write("set", path);
        this.documents.set(path, structuredClone(data) as Record<string, unknown>);
      },
      delete: (reference) => {
        const path = pathOf(reference);
        write("delete", path);
        this.documents.delete(path);
      },
    };
    return operation(transaction);
  }
}
