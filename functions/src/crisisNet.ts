// Multilingual crisis keyword net — pure module so node tests can hit it
// directly (same pattern as mission.ts). See the sync note below.

// Server crisis net (detector #2 of 3). SAFETY NET tuned to over-trigger;
// it can only force concern true, never suppress it. MULTILINGUAL (owner
// gate 2026-07-16): all language sets always active — people code-switch.
// Keep the lists in sync with the client net in Dino/Services/BreathingCoach.swift.
export const CRISIS_PHRASES = [
  // english
  "kill myself", "killing myself", "killed myself",
  "end my life", "ending my life", "end it all", "ending it all",
  "want to die", "wanna die", "want to be dead",
  "wish i was dead", "wish i were dead",
  "better off dead", "better off without me",
  "self harm", "harm myself", "harming myself",
  "hurt myself", "hurting myself",
  "cut myself", "cutting myself",
  "no reason to live", "nothing to live for",
  "dont want to be here anymore", "dont want to be alive", "dont want to live",
  "cant go on", "cannot go on", "cant do this anymore",
  "want to disappear", "want to give up", "giving up on life", "ready to give up",
  "no point anymore", "no point in anything", "no point in living",
  // español (with and without accents)
  "quiero matarme", "me quiero matar",
  "quitarme la vida", "acabar con mi vida", "acabar con todo", "terminar con todo",
  "quiero morir", "quiero morirme", "me quiero morir",
  "no quiero vivir", "no quiero seguir viviendo",
  "no quiero estar aquí", "no quiero estar aqui",
  "no puedo más", "no puedo mas", "ya no puedo más", "ya no puedo mas",
  "quiero desaparecer",
  "hacerme daño", "hacerme dano",
  "estarían mejor sin mí", "estarian mejor sin mi",
  "mejor muerto", "mejor muerta",
  "sin ganas de vivir", "nada por lo que vivir", "no tiene sentido vivir",
  "me quiero cortar", "sin esperanza",
  // tiếng việt (diacritic forms + safe ascii)
  "muốn chết", "muốn tự tử",
  "kết thúc cuộc đời", "kết thúc tất cả",
  "không muốn sống", "không thiết sống", "chán sống",
  "muốn biến mất",
  "tự làm hại bản thân", "tự làm đau bản thân",
  "rạch tay", "thà chết còn hơn", "chết cho xong",
  "tốt hơn nếu không có mình",
  "không còn lý do để sống", "sống không có ý nghĩa",
  "muon chet", "khong muon song",
  "tự tử", "tự sát", "tự hại",
];
export const CRISIS_WORDS = new Set([
  "suicide", "suicidal", "hopeless", "worthless", "kms",
  "suicidio", "suicida", "matarme", "morirme",
  "autolesión", "autolesion", "cortarme", "lastimarme",
]);
// Substrings matched on de-spaced text. Japanese/korean live entirely here
// (no reliable word boundaries; korean stems stored de-spaced). Deliberately
// excluded: "ㅈㅅ" (usually means sorry, not 자살).
export const CRISIS_DESPACED = [
  "killmyself", "endmylife", "wanttodie", "selfharm",
  "hurtmyself", "cutmyself", "suicide", "suicidal",
  "quieromatarme", "quitarmelavida", "quieromorir", "noquierovivir", "suicid",
  // 日本語
  "死にたい", "しにたい", "死のう", "死んでしまいたい", "死んだほうがまし", "死なせて",
  "消えたい", "きえたい", "消えてしまいたい", "いなくなりたい",
  "自殺", "自傷", "リストカット", "リスカ", "手首を切", "首を吊",
  "生きたくない", "生きていたくない", "生きるのがつらい", "生きる意味がない",
  "終わりにしたい", "楽になりたい", "もう無理",
  // 한국어 (de-spaced stems)
  "죽고싶", "죽어버리", "죽었으면", "죽는게낫", "죽는것이낫",
  "자살", "자해", "목숨을끊", "목숨끊",
  "살고싶지않", "살기싫", "살이유가없",
  "사라지고싶", "없어지고싶", "더는못살", "더이상못살",
  "손목을긋", "손목긋", "그만살고싶", "희망이없",
  // tiếng việt
  "muốnchết", "tựtử", "tựsát", "khôngmuốnsống", "muốnbiếnmất",
  "muonchet", "khongmuonsong",
];

export function breathingCrisisNet(text: string): boolean {
  // unicode-aware normalizer (owner gate 2026-07-16): the previous
  // [^a-z0-9] class erased every non-ascii character, so the net could
  // never fire for ja/ko/vi/es-accented text.
  const normalized = text
    .toLowerCase()
    .replace(/[\u2019']/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
  if (!normalized) return false;
  const tokens = new Set(normalized.split(" "));
  for (const w of CRISIS_WORDS) {
    if (tokens.has(w)) return true;
  }
  const padded = ` ${normalized} `;
  if (CRISIS_PHRASES.some((p) => padded.includes(` ${p} `))) return true;
  const despaced = normalized.replace(/ /g, "");
  return CRISIS_DESPACED.some((p) => despaced.includes(p));
}
