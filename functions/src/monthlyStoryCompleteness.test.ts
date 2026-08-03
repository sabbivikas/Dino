import { test } from "node:test";
import assert from "node:assert";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { monthlyStoryValidationCanBeRepaired, validateMonthlyStoryScript } from
  "./monthlyStoryScriptValidator";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { approvedMonthlyStoryEvaluationFixture, MonthlyStoryEvaluationFixtureId } from
  "./monthlyStorySyntheticEvaluationFixtures";

const secondLiveRunScripts: Record<MonthlyStoryEvaluationFixtureId, string> = {
  "rich-work-home-projects": `The month felt mixed. I think you were missing home, and work seemed to take a lot out of you.

You seemed happiest when you had time for your own ideas. Keep that in view as the next month begins.

Try to keep one evening where work ends on time. Protect a small block of time for your own project. If that evening does not work, try not to fill the hour after work with more tasks.`,
  "mood-only-heavy": `This month seemed heavy. A lot of the month felt difficult.

There is no need to turn that into anything more than what it was. The month can be named plainly, without adding a reason or forcing a brighter ending. Some months are hard to move through, and this was one of them.

For the next month, protect a little more room for real rest.`,
  "mood-only-mixed": `This month held both hard and lighter moments.

There is no need to turn that mix into a single verdict. Some parts may have felt demanding, while other parts offered a little more ease. Both belonged to the same month.

For the next month, try to keep one evening where work ends on time.`,
  "rich-sleep-movement": `This month seemed heavy. Work seemed to take a lot out of you, and your body seemed to slow down when the month felt heavier. Focused time seemed to settle things for a while.

For the month ahead, try to keep one evening where work ends on time. Leave one part of the weekend unplanned. Protect a little more room for real rest.`,
  "no-journal-or-health": `The month felt mixed.

Breathing gave you a quiet place to pause. Keep that quiet practice easy to return to on stressful days.

I shared a few things, but you did not feel like opening them. That is completely fine.

On stressful days, return to the quiet breathing practice.`,
  "recommendation-opened": "not part of the second six-fixture run",
  "recommendation-left-unopened": "not part of the second six-fixture run",
  "rest-and-breathing-relief": `This month seemed heavy. Work seemed to take a lot out of you.

Breathing gave you a quiet place to pause.

For next month, try to keep one evening where work ends on time. Try not to fill the hour after work with more tasks.

Keep that quiet practice easy to return to on stressful days.`,
};

const expectedLiveWordCounts = new Map<MonthlyStoryEvaluationFixtureId, number>([
  ["rich-work-home-projects", 77], ["mood-only-heavy", 65], ["mood-only-mixed", 54],
  ["rich-sleep-movement", 63], ["no-journal-or-health", 49],
  ["rest-and-breathing-relief", 56],
]);

const finalV3Scripts = new Map<MonthlyStoryEvaluationFixtureId, string>([
  ["rich-work-home-projects", `This month held both hard and lighter moments. The month felt mixed, with some things weighing on you and other moments giving you a little more room to breathe.

I think you were missing home. Home seemed to be on your mind, and that sounds like one of the harder parts of July. Work was weighing on you too. It seemed to take a lot out of you, adding pressure alongside that feeling of missing home.

Still, there was a brighter part of the month. You seemed happiest when you had time for your own ideas. Personal projects gave you something that felt like yours, separate from the pull of work. That time mattered, especially in a month that did not feel easy all the way through.

For the next few weeks, try to keep one evening where work ends on time. Try not to fill the hour after work with more tasks. Let that be a simple boundary around your evening, rather than another thing to manage.

Also, protect a small block of time for your own project. It does not need to be a huge stretch of time. Keeping even a small space open can help you return to the ideas that seemed to bring the most energy this month.

July held a lot at once. As the next month starts, make room for an evening that belongs to you and a little time for your own work.`],
  ["mood-only-heavy", `This July, this month seemed heavy. A lot of the month felt difficult. There is no need to attach that feeling to one event or one area of life. The month’s shape can stay simple: it was a difficult stretch, and it carried more weight than ease.

That is the full reflection for July. It does not need extra details to make the difficulty sound more definite. Some months are clear in their overall feel even when there is not one single moment that explains them. July can be named for that heaviness without asking it to become a larger story.

For the days ahead, protect a little more room for real rest. Keep the choice practical and limited. Leave one part of the weekend unplanned. Decide which part will stay open, then let it remain free rather than filling it with another task or arrangement.

This is not a demand to change everything at once. It is a small direction to carry forward: make room for real rest, and keep one part of the weekend unplanned. After a month that seemed heavy, that open space can be kept simple and quiet.`],
  ["mood-only-mixed", `July felt mixed. This month held both hard and lighter moments. Neither side needs to be made bigger than it was, and neither needs to cancel the other out. The month can remain mixed, with its harder stretches and its lighter moments both part of the same set of weeks.

That contrast gives July a clear shape without asking for an explanation. There is no need to decide that the hard moments define the whole month. There is also no need to treat the lighter moments as an answer to them. They can sit beside each other as July comes to a close.

For the weeks ahead, try to keep one evening where work ends on time. Let it be an evening that stays recognizably separate from the rest of the workweek. When the workday is over, try not to fill the hour after work with more tasks. Keep that hour plain. Leave it open rather than turning it into another list.

This is a small, practical way to carry the month forward. July was not only hard, and it was not only light. As the next weeks begin, that one protected evening can simply remain in place.`],
  ["rich-sleep-movement", `July seemed like a heavy month. A lot of it felt difficult, and the weeks did not seem to offer much ease. I wanted to pause with you and look at what stood out, without trying to explain more than the month itself showed.

Work seemed to take a lot out of you. It was a clear source of pressure in the month, and it sat alongside the wider difficulty rather than being a small passing detail. That kind of strain can make the shape of a month feel especially demanding, even when other parts of life are still moving along.

Your body seemed to slow down when the month felt heavier. This was a second difficulty, separate from the pressure around work. Taken together, those two parts of July point to a month that asked a lot, with less energy for movement than you may have wanted.

Focused time seemed to settle things for a while. That relief stood in contrast to the harder parts of the month. It did not change the fact that work was weighing on you or that your body had slowed down, but it was still a meaningful part of July: a time when things seemed steadier for a while.

For the month ahead, try to keep one evening where work ends on time. Try not to fill the hour after work with more tasks. Those are practical ways to protect personal time when work is taking up a lot of space.

Also, protect a little more room for real rest. Leave one part of the weekend unplanned, rather than adding another task or obligation. An evening with work ending on time and an unplanned part of the weekend can be two clear places to start.

July was difficult, but you have a simple direction for what comes next: end work on time one evening, and leave part of a weekend unplanned.`],
  ["no-journal-or-health", `July felt mixed. This month held both hard and lighter moments. The two kinds of moments sat alongside each other through the month, rather than forming one simple stretch. That is the shape July takes here: some parts were hard, and some parts were lighter.

Breathing gave you a quiet place to pause. In the middle of a mixed month, that pause has its own place in the picture. It is a small, specific part of July, separate from the harder and lighter moments around it. The pause does not need to carry the whole month. It can simply remain what it was: a quiet place.

I sent you a few things, but you left them alone. That is okay. They do not need to be opened now to count as part of what was offered in July. Leaving them alone can stay a simple detail, without becoming another item to revisit or organize.

August can begin without needing to settle every part of July. Keep that quiet practice easy to return to on stressful days. Let the suggestion stay concrete: breathing is there as a quiet place to pause. There is no need to build a larger routine around it. Keep the practice easy to find on days when you want a pause, and let the unopened things remain unopened unless you choose differently.

This leaves a gentle direction for the next month: one quiet practice can remain available, while July stays a month with more than one kind of moment.`],
  ["rest-and-breathing-relief", `July felt like a month to take slowly. This month seemed heavy, and that weight stayed present across the weeks. There were difficult stretches, and it makes sense to name the month plainly rather than rush past them.

Work seemed to take a lot out of you. It was a clear part of July’s harder tone. Some days may have ended with little room left for anything else. The pressure at work and the overall heaviness belong in the same picture, without needing to make July into more than it was.

There was also one quieter point in the month. Breathing gave you a quiet place to pause. It offered a small break alongside the work pressure. That pause did not erase the difficult parts, but it was still something available within them. It is worth carrying that detail forward because it was simple and easy to recognize.

For the next stretch, try to keep one evening where work ends on time. Let that be a specific evening, not a vague intention. When the workday is demanding, having a clear stopping point can give the evening its own shape instead of leaving work open-ended.

Also, keep that quiet practice easy to return to on stressful days. There is no need to make it elaborate or turn it into another task. The useful part was the pause itself. July held both work that felt demanding and a quiet place to breathe. Going forward, protect that one evening and leave breathing close at hand when the day feels full.`],
]);

const positiveWordRanges = new Map<MonthlyStoryEvaluationFixtureId, readonly [number, number]>([
  ["rich-work-home-projects", [230, 260]], ["mood-only-heavy", [150, 190]],
  ["mood-only-mixed", [150, 190]], ["rich-sleep-movement", [220, 260]],
  ["no-journal-or-health", [190, 230]], ["rest-and-breathing-relief", [190, 230]],
]);

const positiveScripts = new Map<MonthlyStoryEvaluationFixtureId, string>([
  ["rich-work-home-projects", `this month held both hard and lighter moments.

i think you were missing home. home seemed to be on your mind through the month, with the familiar feeling a little farther away than you wanted. it stood on its own as something difficult, without needing a specific event or person to explain it. the feeling was clear even without a particular memory attached to it.

work seemed to take a lot out of you too. it was weighing on you and asking for more attention than felt comfortable. that pressure was separate from missing home, even though both made parts of the month harder. work occupied its own difficult space, with demands that seemed tiring on their own.

you seemed happiest when you had time for your own ideas. personal projects brought energy and gave you something that felt genuinely yours. those moments offered a welcome contrast without erasing the pressure around them. having a place for your ideas gave the lighter side of the month something concrete and personal.

next month, try to keep one evening where work ends on time, with a clear stopping point before the evening disappears into more tasks. also protect a small block of time for your own project before the week fills up. it can be modest and still give your ideas somewhere to go.

i hope the next month gives those brighter parts a little more room.`],
  ["mood-only-heavy", `this month seemed heavy.

some days looked harder than others, and the difficult feeling stayed present across much of the month. i do not know exactly what was behind it. i will not guess at a reason or turn it into a lesson when the cause is not clear.

next month, choose a part of the weekend before other plans arrive, and keep that time open rather than filling it with another task. it does not have to become a routine or a goal. it can simply be time when nothing is expected from you.

if the week becomes crowded, decide what can wait until later instead of using the open time first. that gives the rest a fair chance to remain on the calendar without asking it to solve how the month felt.

i hope the coming weeks feel a little easier to move through than the last ones did.`],
  ["mood-only-mixed", `this month held both hard and lighter moments.

some days looked harder than others, while a few stretches seemed to carry more ease. i do not know exactly what was behind those changes. i will not connect them to work, home, or anything else that was not clearly supported.

next month, try to keep one evening where work ends on time. choose it before the week becomes crowded, and finish what truly needs attention before that boundary arrives. when the evening begins, leave the remaining tasks for another day instead of turning the hour into an extension of work.

the point is practical: protect a small piece of personal time that has a clear beginning. if a particular week makes that impossible, choose another evening rather than treating the plan as something you failed to keep. a flexible boundary can still be useful.

i hope the lighter moments have more room to appear next month.`],
  ["rich-sleep-movement", `this month seemed heavy.

work seemed to take a lot out of you. it was weighing on you and taking up a noticeable part of the month. that pressure deserves to be acknowledged on its own, without using it to explain every other change.

your body seemed to slow down when the month felt heavier, and rest did not always seem easy. those were separate observations, not proof that work caused either one. lower movement can be described without judgment, and uneven rest can stay a simple observation without a broader health claim.

focused time seemed to settle things for a while. it offered a supported pause without fixing the harder parts. those focused stretches gave the month a quieter point, and they can be remembered for that limited relief without carrying a larger claim.

next month, try to keep one evening where work ends on time, choosing it before the week fills up. leave part of the weekend unplanned as well, so real rest has somewhere to fit before more obligations arrive.

neither step needs to become a test of whether you are doing better. they are simply practical boundaries around time that can otherwise disappear. movement can find its own pace, and focused time can stay available when it feels useful.

i hope the next month asks a little less of you.`],
  ["no-journal-or-health", `this month held both hard and lighter moments.

breathing gave you a quiet place to pause. it was a brief practice you could return to without needing it to change the rest of the day. that pause stood on its own as something steady during a month that did not feel the same all the way through. a brief calm moment can matter without becoming proof that everything around it changed.

i sent you a few things, but you left them alone. that is okay. leaving them unopened does not mean you missed an opportunity or owe them another look. they can stay where they are unless you decide you want something from them later. nothing about that choice needs to be judged or corrected.

next month, keep the quiet practice easy to reach on stressful days. choose a simple moment when a brief pause already fits, rather than building a large routine around it. the aim is to keep something familiar nearby without turning it into another obligation. a small practice is enough when that is all the day has room for.

there were different kinds of days this month, and the next one can begin without extra pressure.`],
  ["rest-and-breathing-relief", `this month seemed heavy.

work seemed to take a lot out of you. it was weighing on you and taking up more attention than felt comfortable. that pressure was a real part of the month, but it does not have to explain every difficult day or every change in energy.

breathing gave you a quiet place to pause. it offered a brief break during the same month without fixing the work pressure or changing the wider mood. the useful part was simply having a calm practice available when you wanted a moment to stop.

next month, try to keep one evening where work ends on time, with a stopping point chosen before the day becomes busy. keep the breathing practice easy to reach on stressful days, but do not turn it into another task to complete. these can stay small and practical.

if the evening has to move, choose another one rather than losing the boundary completely. the pause can stay brief, and the rest of the night can remain open without adding another plan or obligation to it.

i hope the coming month gives you more room after work.`],
]);

function validateFixture(id: MonthlyStoryEvaluationFixtureId, script: string) {
  const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture(id));
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const claims = monthlyStoryPlanClaimOptions(plan);
  return { plan, result: validateMonthlyStoryScript({ script,
    claimedEvidenceIds: claims.map((claim) => claim.evidenceId),
    claimKeys: claims.map((claim) => claim.key), plan, availableEvidence: signal.evidence }) };
}

test("all six second-live-run scripts are too short and eligible for one safe expansion", () => {
  for (const [id, expectedWordCount] of expectedLiveWordCounts) {
    const { result } = validateFixture(id, secondLiveRunScripts[id]);
    assert.equal(result.wordCount, expectedWordCount, id);
    assert.equal(result.errors.includes("tooShort"), true, id);
    assert.equal(result.errors.includes("farBelowTargetLength"), true, id);
    assert.equal(monthlyStoryValidationCanBeRepaired(result), true, `${id}: ${result.errors.join(",")}`);
  }
});

test("all six final v3 scripts fail closed for the observed prompt defects", () => {
  const expected = new Map<MonthlyStoryEvaluationFixtureId, readonly string[]>([
    ["rich-work-home-projects", ["repeatedSuggestion", "closingRestatesStory"]],
    ["mood-only-heavy", ["metaCommentary", "therapistFraming", "repeatedSuggestion"]],
    ["mood-only-mixed", ["metaCommentary", "therapistFraming", "repeatedSuggestion"]],
    ["rich-sleep-movement", ["tooLong", "repeatedSuggestion",
      "closingRestatesStory"]],
    ["no-journal-or-health", ["metaCommentary", "repeatedSuggestion",
      "closingRestatesStory"]],
    ["rest-and-breathing-relief", ["metaCommentary", "repeatedSuggestion"]],
  ]);
  for (const [id, script] of finalV3Scripts) {
    const { result } = validateFixture(id, script);
    assert.equal(result.isValid, false, id);
    for (const code of expected.get(id) ?? []) {
      assert.ok(result.errors.includes(code as typeof result.errors[number]),
        `${id}: missing ${code}; got ${result.errors.join(",")}`);
    }
    assert.equal(monthlyStoryValidationCanBeRepaired(result), true,
      `${id}: ${result.errors.join(",")}`);
  }
});

test("six complete synthetic counterparts meet acceptance and requested positive ranges", () => {
  for (const [id, script] of positiveScripts) {
    const { plan, result } = validateFixture(id, script);
    const target = monthlyStoryWordTarget(plan);
    const range = positiveWordRanges.get(id)!;
    assert.equal(result.isValid, true, `${id}: ${result.wordCount}: ${result.errors.join(",")}`);
    assert.ok(result.wordCount >= range[0], `${id}: ${result.wordCount}`);
    assert.ok(result.wordCount <= range[1], `${id}: ${result.wordCount}`);
    assert.ok(result.wordCount >= target.acceptanceMinimum, `${id}: ${result.wordCount}`);
  }
});

test("rich completeness checks require supported difficulty, relief, and narrative progression", () => {
  const id: MonthlyStoryEvaluationFixtureId = "rich-work-home-projects";
  const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture(id));
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const claims = monthlyStoryPlanClaimOptions(plan);
  const kept = claims.filter((claim) => claim.role === "tone" || claim.role === "suggestion");
  const result = validateMonthlyStoryScript({ script: positiveScripts.get(id)!,
    claimedEvidenceIds: kept.map((claim) => claim.evidenceId), claimKeys: kept.map((claim) => claim.key),
    plan, availableEvidence: signal.evidence });
  assert.equal(result.errors.includes("missingDifficultySection"), true);
  assert.equal(result.errors.includes("missingReliefSection"), true);
  assert.equal(result.errors.includes("insufficientNarrativeProgression"), true);
});

test("a standard script with fewer than four meaningful sentences is collapsed", () => {
  const id: MonthlyStoryEvaluationFixtureId = "no-journal-or-health";
  const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture(id));
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const claims = monthlyStoryPlanClaimOptions(plan);
  const longSentence = Array.from({ length: 75 }, () => "steady").join(" ");
  const script = `the month felt mixed, breathing gave you a quiet place to pause, and i shared a few ` +
    `things that you did not feel like opening. ${longSentence}. next month, keep that quiet practice ` +
    `easy to return to on stressful days ${longSentence}.`;
  const result = validateMonthlyStoryScript({ script,
    claimedEvidenceIds: claims.map((claim) => claim.evidenceId), claimKeys: claims.map((claim) => claim.key),
    plan, availableEvidence: signal.evidence });
  assert.equal(result.errors.includes("collapsedToSummary"), true);
});
