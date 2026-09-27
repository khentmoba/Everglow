# Motchi Agent Baseline — 2026-09-27 (goal mujy4ocd-sefy1a)

Offline probe: `node tool/motchi_baseline.js` over 67 eval cases
(`functions/test/motchi_eval_cases.json`), feature=`assistant`.
Zero LLM cost. Re-run after changes to score the composite.

## Baseline numbers (main @ 2026-09-27, before changes)

| Metric | Value | Notes |
|---|---|---|
| routing_recall | **100%** (67/67) | expectedTools ⊆ attached. GATE: must stay 100%. |
| avg_attached_tools | **9.9** | of 63 total; histogram 6–18, no case >20 |
| avg_waste_tools | **8.91** | attached minus expected per turn |
| avg_schema_tokens | **1311** | 16.1% of full 8122 (all 63 schemas) |
| avg_context_blocks | **7.0** | always exactly maxKeys — no selectivity |
| fastpath_hits | **4** / 67 | get_xp_stats, get_today_recap, list_reminders, get_relationship_insights |
| plain_chat_lean | 2/2 | greeting/smalltalk paths attach ≤11 tools |
| cold-turn Firestore reads | **~10** | 7 block queries + 2 memory queries (60 fresh + 20 pinned) + 1 persona doc (5-min cached) |

The Dart keyword eval (`tool/motchi_prompt_eval.dart`, 53.7%) is a
strawman router, NOT live quality — live routing is the superset-based
`selectToolsForRequest` measured above. Tracked for reference only.

## Composite improvement formula

Gate (fail if broken): routing_recall stays 100% on all 67 cases.

Improvable metrics, each capped at 50% contribution so no single
metric carries the goal:

1. schema_tokens_down = (1311 − new) / 1311
2. attached_down = (9.9 − new) / 9.9
3. blocks_down = (7.0 − new) / 7.0
4. fastpath_up = (new − 4) / 4

**composite = mean of the four, target ≥ +25%.**

## Where the waste was (attack plan)

1. Read/write bundling: a read ask ("what is on our watchlist")
   attached write tools too (add/mark/remove). Splitting groups into
   read vs write halves most intents. Biggest schema-token win.
   → DONE (v7): 9.9 → 5.9 tools, 1311 → ~745 tokens.
2. Context blocks always fetch 7: `selectBlockKeys` filled to maxKeys
   even with zero keyword hits. Score-threshold it → ~4 avg.
   → DONE (v7): minKeys=4 floor, hits scale to 7.
3. Fast-path covers 4 asks: safe zero-arg reads (watchlist, calendar,
   starlight…) can join with narrow anchored patterns.
   → DONE (v7): 4 → 7 fast-paths, each one read + one LLM call.

## Result (2026-09-27, branch motchi/agent-efficiency)

| Metric | Before | After | Δ |
|---|---|---|---|
| routing_recall | 100% | 100% | gate holds |
| avg_attached_tools | 9.9 | 5.85 | −40.9% |
| avg_schema_tokens | 1311 | 745 | −43.2% |
| avg_context_blocks | 7.0 | 4.0 | −42.9% |
| fastpath_hits | 4 | 7 | +75% (capped 50%) |
| cold-turn reads | ~10 | ~7 | −30% |

composite = (43.2 + 40.9 + 42.9 + 50) / 4 = **+44.3%** ≥ +25% ✓
4. CORE_TOOLS (5) rode every intent turn; awareness set (+6) rode
   every unmatched turn.
   → DONE (v7): core is read_memories + add_xp; the three write
   tools moved to their intent groups.
