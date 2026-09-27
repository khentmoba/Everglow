# Motchi Perfect-Agent Baseline — 2026-09-27 (goal mujzs2h5-qsvnpo)

"Perfect" = 100% on every eval + zero failed tool calls on the offline
corpus. New powers allowed, but every addition must be tied to a
failing case it fixes. Fixes go in agent code — eval cases only grow,
never weaken.

## The evals and their baselines

| Eval | Baseline | Target |
|---|---|---|
| Live routing recall (67 eval cases) | 100% | hold 100% |
| Dart eval `dart tool/motchi_prompt_eval.dart` | 100% (now scores the LIVE router via `tool/motchi_eval_bridge.js`; the old 53.7% strawman is deleted) | hold 100% |
| Failure corpus (152 cases) | **143/152 = 94.1%** | 100% (0 failures) |
| `node --test` (functions) | 233 pass + corpus runner failing (by design, TDD) | all green |
| `flutter test` | 1068 pass | hold green |
| `node functions/eval_gate.js` | pass (v7) | hold pass |
| `tool/ci` guards (12) | all OK | hold |

## The 9 baseline failures (all genuine user needs)

Context routing (follow-ups inherit no intent today):
1. `rt-ctx-move`: "move dentist to friday" after "add dentist appointment thursday" → missing update_calendar_event
2. `rt-ctx-cancel`: "cancel the dentist" + same context → missing delete_calendar_event
3. `rt-pronoun-move`: "move it to friday" + same context → missing update_calendar_event
4. `rt-pronoun-cancel`: "cancel that" after "remind me tomorrow to water plants" → missing cancel_reminder
5. `rt-pronoun-noread`: "read it" after "journal about yesterday" → missing read_journal_entry (and must NOT attach create)

Date parsing (reminder stored with scheduled:false today):
6. `sched-friday`: "friday at 3pm" unparseable
7. `sched-next-friday`: "next friday" unparseable
8. `sched-monday`: "monday" unparseable
9. `sched-tmrw`: "tmrw at 3pm" unparseable

## Known harness gaps (not yet measurable offline)

- Tool loop-guard (`seenToolCalls` repeat detection) is inline in
  `motchi_chat.js` — extract a pure helper so the corpus can pin it.
- Executor behavior past validation (needs Firestore) — covered by
  existing exec tests + live spot-checks, not the corpus.
- Production failure rate (live LLM calls) — sampled from
  `motchi_stats` when available; offline corpus is the gate.
