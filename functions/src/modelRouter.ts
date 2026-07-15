//
// modelRouter.ts — ONE central model registry for the dino fleet.
// Every NEW ai call routes through here; a model swap is a one line change.
// generateComfortRecs is deliberately NOT wired through (owner hard rule:
// never modify it) — its entry below documents the fleet for cost parity.
//
// HARD RULES (owner, non negotiable) are enforced IN CODE by assertRoute:
//   • missions never route to luna
//   • watching never routes to muse spark (or any meta model)
//   • comfort recs stay gpt-4.1-mini
// route() logs {task, provider, model} — never user data — so per model
// cost can be read straight from the function logs.
//

import OpenAI from "openai";
import * as logger from "firebase-functions/logger";

export type AiTask = "watching" | "mission" | "deliveredWords" | "comfortRecs";
export type AiRoute = {
  provider: "openai" | "meta";
  model: string;
  maxTokens: number;
  temperature: number;
};

const ROUTES: Record<AiTask, AiRoute> = {
  // luna is gpt-5 family: the call site must send max_completion_tokens
  // and omit temperature (verified live: max_tokens/temp are 400s). the
  // budget carries reasoning headroom.
  watching:       { provider: "openai", model: "gpt-5.6-luna",   maxTokens: 200, temperature: 0 },
  // muse-spark-1.1 (docs exact string) is a REASONING model — reasoning
  // tokens bill as output, so the cap carries headroom; the call site pins
  // reasoning_effort low (verified live: without it, output starves).
  mission:        { provider: "meta",   model: "muse-spark-1.1", maxTokens: 1500, temperature: 0.6 },
  deliveredWords: { provider: "openai", model: "gpt-4.1-mini",   maxTokens: 200, temperature: 0.7 },
  comfortRecs:    { provider: "openai", model: "gpt-4.1-mini",   maxTokens: 500, temperature: 0.5 },
};

export function assertRoute(task: AiTask, r: AiRoute): void {
  if (task === "mission" && r.model.toLowerCase().includes("luna")) {
    throw new Error("hard rule: missions never route to luna");
  }
  if (task === "watching" && (r.provider === "meta" || r.model.toLowerCase().includes("spark"))) {
    throw new Error("hard rule: watching never routes to muse spark");
  }
  if (task === "comfortRecs" && r.model !== "gpt-4.1-mini") {
    throw new Error("hard rule: comfort recs stay gpt-4.1-mini");
  }
}

export function route(task: AiTask): AiRoute {
  const r = ROUTES[task];
  assertRoute(task, r);
  logger.info("model_route", { task, provider: r.provider, model: r.model });
  return r;
}

/** Build the SDK client for a route. Meta's model api is openai compatible,
 *  so both providers share one SDK — only baseURL and key differ. */
export function clientFor(
  r: AiRoute,
  keys: { openai?: string; metaKey?: string; metaBase?: string }
): OpenAI {
  if (r.provider === "meta") {
    if (!keys.metaKey || !keys.metaBase) throw new Error("meta model api not configured");
    return new OpenAI({ baseURL: keys.metaBase, apiKey: keys.metaKey });
  }
  if (!keys.openai) throw new Error("openai not configured");
  return new OpenAI({ apiKey: keys.openai });
}
