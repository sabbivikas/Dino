import { MonthlyStoryClaimKey } from "./monthlyStoryClaims";

export type MonthlyStoryPhraseSet = {
  core: readonly string[];
  support: readonly string[];
  transition: readonly string[];
};

const phrases = (core: readonly string[], support: readonly string[],
  transition: readonly string[] = []): MonthlyStoryPhraseSet => ({ core, support, transition });

export const MONTHLY_STORY_PHRASE_LIBRARY: Readonly<Record<MonthlyStoryClaimKey,
MonthlyStoryPhraseSet>> = Object.freeze({
  monthBright: phrases(
    ["{month} seemed lighter overall.", "there was more ease in {month} than heaviness.",
      "{month} had a mostly brighter tone."],
    ["the lighter feeling was present often enough to shape the month.",
      "there was room for ordinary moments to feel a little easier.",
      "the month did not need to be perfect for that ease to matter.",
      "the brighter tone remained visible across different parts of the month.",
      "easier moments appeared often enough to support the overall tone.",
      "the lighter tone did not depend on any single part of the month.",
      "the easier feeling showed up in ordinary parts of the month as well."],
    ["that brighter tone is a useful place to begin."]),
  monthHeavy: phrases(
    ["{month} seemed heavy overall.", "a lot of {month} felt difficult.",
      "{month} carried a heavier tone."],
    ["some days were harder than others, but the weight stayed present across the month.",
      "the difficult feeling was not the same every day, yet it remained part of the month.",
      "there were changes from day to day without the heaviness fully leaving.",
      "the harder feeling returned often enough to shape the overall tone.",
      "even when a day shifted, the month still carried noticeable weight.",
      "the heavier tone was present in ordinary parts of the month too.",
      "the weight did not lift completely, even on the easier days."],
    ["it is worth saying that directly before looking ahead."]),
  monthMixed: phrases(
    ["{month} held both hard and lighter moments.", "{month} felt mixed overall.",
      "there were difficult and easier parts of {month}."],
    ["neither side of the month erased the other.",
      "the balance shifted, with some days carrying more ease than others.",
      "the different parts of the month stayed distinct rather than forming one simple mood.",
      "some stretches were lighter, while others were more demanding.",
      "the changes between easier and harder days remained noticeable.",
      "a lighter day did not define the difficult ones around it.",
      "a harder day did not remove the easier parts that also appeared.",
      "the harder and easier parts kept trading places through the month.",
      "each kind of day stayed part of the month in its own right."],
    ["that mix stayed present through the month."]),
  monthSteady: phrases(
    ["{month} felt fairly steady.", "the emotional tone of {month} stayed mostly even.",
      "{month} moved at a fairly consistent emotional pace."],
    ["there were changes between days, but no large swing defined the month.",
      "the steadier feeling gave the month a consistent shape.",
      "small shifts happened without changing the overall tone.",
      "the general feeling remained recognizable from one stretch to the next.",
      "ordinary changes happened inside an otherwise even month.",
      "the month kept a similar feel from its early part to its later part.",
      "nothing in the month pulled sharply away from that even tone.",
      "the evenness was noticeable without making the month feel flat or empty."],
    ["that steadiness is the clearest place to begin."]),
  monthVariable: phrases(
    ["{month} shifted from one kind of day to another.", "the feeling of {month} changed often.",
      "{month} had a variable emotional pace."],
    ["some days felt easier to move through, while others carried more weight.",
      "there was no single feeling that covered the whole month.",
      "the changes between days were part of what made the month feel uneven.",
      "the emotional pace moved enough that no single stretch defined it.",
      "easier and harder days appeared at different points in the month.",
      "the month did not settle into one steady rhythm for very long.",
      "one stretch of the month could feel quite different from the next."],
    ["that variation is the clearest summary of the month."]),
  workPressure: phrases(
    ["work seemed to take a lot out of you this month.", "work was one of the heavier parts of the month.",
      "work seemed to carry more pressure than usual."],
    ["the demands around it seemed to stay present even when the day was moving on.",
      "it took up enough room in the month to be worth naming on its own.",
      "that pressure mattered without needing to explain every other part of the month."],
    ["work was difficult in its own right, separate from the other parts of the month."]),
  missingHome: phrases(
    ["i think you were missing home.", "home seemed to be on your mind this month.",
      "there seemed to be a little more homesickness than usual."],
    ["the feeling could be present quietly and still carry real weight.",
      "it seemed to stay nearby even when other parts of the day needed attention.",
      "missing home was meaningful without pointing to any single event or person."],
    ["it was another distinct part of the month, not an explanation for everything else."]),
  familyConnection: phrases(
    ["time connected with family seemed meaningful.", "family connection stood out as a warmer part of the month.",
      "being in touch with family seemed to bring some ease."],
    ["those moments had value without needing to change the rest of the month.",
      "the connection offered something steady to return to.",
      "it was one source of warmth among everything else that was happening."],
    ["that connection deserves its own place among the brighter parts."]),
  relationshipWeight: phrases(
    ["some relationships seemed to feel complicated.", "relationships carried some extra weight this month.",
      "parts of your relationships seemed harder to navigate."],
    ["the difficulty can be acknowledged without guessing at details.",
      "it seemed important without revealing one simple explanation.",
      "that tension was present, though its exact shape is not something to assume."],
    ["it stood as a separate difficulty in the month."]),
  uncertainty: phrases(
    ["not knowing what came next seemed hard.", "uncertainty was one of the harder parts of the month.",
      "the lack of a clear next step seemed difficult."],
    ["waiting for clarity can take up attention even when nothing specific changes.",
      "the uncertainty mattered without requiring a prediction about what comes next.",
      "it added weight while remaining separate from the other parts of the month."],
    ["that uncertainty deserves to be named on its own."]),
  personalProjects: phrases(
    ["you seemed happiest when you had time for your own ideas.",
      "your own projects seemed to bring more energy into the month.",
      "time spent on your ideas stood out as one of the brighter parts."],
    ["those projects gave your attention somewhere personal to go.",
      "the time mattered even when it was brief or unfinished.",
      "your ideas offered interest and energy without needing to fix the harder parts."],
    ["that was a distinct source of energy worth carrying forward."]),
  rest: phrases(
    ["quiet time seemed to give you a little room.", "rest stood out as one of the more helpful parts of the month.",
      "time with fewer demands seemed to offer some relief."],
    ["the pause had value without needing to change the whole day.",
      "having less asked of you for a while seemed worthwhile on its own.",
      "the quieter time gave the month a small area with fewer demands."],
    ["that relief was modest, but it was still useful."]),
  change: phrases(
    ["there was a lot of change to carry.", "change was one of the more demanding parts of the month.",
      "the amount of change made part of the month feel unsettled."],
    ["adjusting took attention even when no single moment explains it all.",
      "the changes mattered without pointing to a specific event.",
      "that unsettled feeling occupied its own place in the month."],
    ["it was a separate difficulty rather than a cause assigned to everything else."]),
  socialConnection: phrases(
    ["being around people you care about seemed to bring some ease.",
      "social connection stood out as a lighter part of the month.",
      "time with people you care about seemed worthwhile."],
    ["the connection offered a change of pace without needing to solve anything.",
      "those moments could matter even when they were simple.",
      "being connected gave the month a little more room and warmth."],
    ["that was one useful source of relief."]),
  lessRestful: phrases(
    ["you seemed more tired than usual.", "rest did not seem to come easily.",
      "sleep seemed less restful than usual."],
    ["the tiredness can be acknowledged without assigning it a cause.",
      "rest seemed harder to find, though that does not explain how the rest of the month felt.",
      "the lack of easy rest was a difficulty in its own right."],
    ["it sat beside the other difficulties without being used to explain them."]),
  moreRestful: phrases(
    ["rest seemed to come a little more easily.", "more restful time was one of the steadier parts of the month.",
      "sleep seemed to offer a little more ease."],
    ["that ease was useful without needing to change everything else.",
      "more room for rest stood out as something worth preserving.",
      "the steadier rest belonged among the month's sources of relief."],
    ["it was one practical source of ease."]),
  variableRest: phrases(
    ["rest seemed uneven through the month.", "the quality of rest appeared to vary.",
      "some parts of the month seemed more restful than others."],
    ["the variation can be described without guessing what caused it.",
      "the unevenness was noticeable without explaining the emotional tone.",
      "rest changed enough to stand as its own part of the month."],
    ["it remained separate from the other difficulties."]),
  lessActive: phrases(
    ["your body seemed to slow down when the month felt heavier.", "movement seemed harder to make room for.",
      "there seemed to be less room for movement this month."],
    ["that slowing down is not a failure or a reason to judge the month.",
      "it can be acknowledged without turning movement into an obligation.",
      "the change in pace mattered without being used to explain your feelings."],
    ["it was another part of the month's pace, not a prescription to do more."]),
  moreActive: phrases(
    ["having room to move seemed to bring some energy.", "movement stood out as an energizing part of the month.",
      "there seemed to be more room for movement."],
    ["the energy mattered without turning movement into a requirement.",
      "it offered a useful change of pace on its own.",
      "that movement was one source of energy among the month's other parts."],
    ["it is worth keeping available without making it a target."]),
  variableMovement: phrases(
    ["your energy for movement seemed to come and go.", "movement had an uneven place in the month.",
      "some parts of the month had more room for movement than others."],
    ["the variation does not need to be judged or corrected.",
      "it can be noted without using it to explain the emotional tone.",
      "the changing pace was simply one part of the month."],
    ["it does not create an obligation for next month."]),
  meditationRelief: phrases(
    ["meditation seemed to give you a little room.", "meditation offered a quiet place to pause.",
      "a little meditation seemed useful during harder moments."],
    ["the practice could matter without changing everything around it.",
      "it gave you something familiar to return to for a while.",
      "the pause was useful on its own, without being treated as a solution."],
    ["that small practice was one clear source of relief."]),
  breathingRelief: phrases(
    ["breathing gave you a quiet place to pause.",
      "breathing seemed to give you a small break during harder moments.",
      "a few quiet breathing moments gave the month a little more space."],
    ["the practice was useful without needing to fix or change the month.",
      "it offered a pause that could stand on its own.",
      "the breathing moments gave you something simple to return to."],
    ["that pause was small, but it still had value."]),
  focusRelief: phrases(
    ["focused time seemed to settle things for a while.", "having time to focus offered a useful pause.",
      "focused time stood out as a steadier part of the month."],
    ["the focus had value without needing to make everything manageable.",
      "it gave your attention one clear place to be for a while.",
      "that time could help simply by asking less of your attention."],
    ["it was one distinct source of relief."]),
  recommendationOpened: phrases(
    ["i sent you something when things felt heavy. i hope it gave you a small break.",
      "i shared something with you during one of the harder stretches. i hope it was useful for a little while.",
      "i sent something your way during a difficult stretch. i hope it offered a brief change of pace."],
    ["opening it does not tell me what it meant to you, so i will not assume that it helped.",
      "it is enough that it was available; i cannot know what effect it had.",
      "whatever you thought of it remains yours, and no benefit is being assumed."],
    ["it can remain a small part of the month without being treated as an outcome."]),
  recommendationKept: phrases(
    ["you kept something i sent your way. i hope it was worth having nearby.",
      "something i shared stayed with you. i hope it was useful to keep around.",
      "you chose to keep something i sent. i hope it suited what you wanted then."],
    ["keeping it does not show what effect it had, and i will not assume one.",
      "it can matter as a choice without becoming proof that it helped.",
      "what you kept and why remains yours to decide."],
    ["it belongs here only as something you chose to keep."]),
  recommendationLeftUnopened: phrases(
    ["i sent you a few things, but you left them alone. that is okay.",
      "i shared a few things, but you did not feel like opening them. that is completely fine.",
      "a few things i sent stayed unopened, and there is nothing wrong with that."],
    ["they can stay untouched unless you decide you want them later.",
      "leaving them alone did not create a missed obligation.",
      "you do not owe those suggestions your attention."],
    ["that choice can remain neutral rather than becoming something to correct."]),
  continueRest: phrases(
    ["next month, leave one part of the weekend unplanned.",
      "next month, protect a little time where nothing needs to be productive.",
      "next month, keep a small stretch of time open for real rest."],
    ["choose the time before other plans fill it, and let it stay simple.",
      "keep the plan modest so the open time does not become another task.",
      "decide what can wait so that the rest has a clear place on the calendar."],
    ["the point is a practical pause, not a new routine to maintain."]),
  protectPersonalTime: phrases(
    ["next month, try to keep one evening where work ends on time.",
      "next month, choose one evening where the workday has a clear ending.",
      "next month, give one evening a firm stopping point for work."],
    ["decide when work will end before the day becomes crowded.",
      "a concrete boundary makes it clear when the evening begins.",
      "unfinished tasks can move to another time instead of taking the whole evening."],
    ["the boundary can stay small and specific."]),
  seekConnection: phrases(
    ["next month, make room for an easy moment with someone you trust.",
      "next month, choose a simple way to spend time with someone you trust.",
      "next month, keep a little room for comfortable company."],
    ["choose something low-pressure that does not need a special occasion.",
      "a brief plan is enough; it does not need to become a large commitment.",
      "make the invitation simple enough to fit an ordinary week."],
    ["the suggestion is about access to connection, not a promise about how it will feel."]),
  continueHelpfulPractice: phrases(
    ["next month, keep that quiet practice easy to return to on stressful days.",
      "next month, leave the helpful practice simple enough to use when the day feels full.",
      "next month, keep the familiar practice within easy reach."],
    ["attach it to a moment that already exists instead of building a large routine.",
      "let a brief version count so it does not become another demand.",
      "choose the easiest form of the practice and keep the setup minimal."],
    ["the goal is to keep it available, not to require it every day."]),
  makeSpaceForProjects: phrases(
    ["next month, protect a small block of time for your own project.",
      "next month, keep a little time each week for the ideas that felt like yours.",
      "next month, reserve a modest pocket of time for your own ideas."],
    ["choose the time before the week fills, and let unfinished work remain unfinished.",
      "a small block makes starting less like another large task.",
      "decide in advance what can wait while that personal time is protected."],
    ["the time can be useful without needing to produce a finished result."]),
});

export function monthlyStoryPhraseSet(key: MonthlyStoryClaimKey): MonthlyStoryPhraseSet {
  return MONTHLY_STORY_PHRASE_LIBRARY[key];
}

export function isApprovedMonthlyStoryPhrase(key: MonthlyStoryClaimKey, sentence: string): boolean {
  const normalized = sentence.trim().toLowerCase();
  const set = monthlyStoryPhraseSet(key);
  const escape = (value: string): string => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return [...set.core, ...set.support, ...set.transition].some((candidate) => {
    const pattern = candidate.toLowerCase().split("{month}").map(escape).join("[a-z]{3,12}");
    return new RegExp(`^${pattern}$`).test(normalized);
  });
}
