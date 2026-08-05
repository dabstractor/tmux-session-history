# T4.S2 Research — CONCURRENCY comment rewrite (remove activity/poller)

## Input state (verified in working tree)

- `scripts/session_history.sh` is **548 lines** (T4.S1 already landed: WHAT MAKES
  block rewritten 26→17 lines, file shrunk 557→548).
- T1.S1/T1.S2 already deleted `do_activity()` / `do_poller()` / `do_start_poller()`
  and the `activity)`/`poller)` case branches. T3.S1 changed `dwell_ms()` to 30000.
- Header comment region now: lines 1–95 (CONCURRENCY / SAFETY block ends ~line 95),
  blank `#` at 96, `# Global state...` at 97, blank at 98–99, `set -u` at **100**.

## The two regions in scope (T4.S2)

### REGION A — CONCURRENCY / SAFETY header block

Block spans current **lines 64–95**. Gap-analysis = **GAP 6c** (pre-T1 lines 89–104).
Structure:

- Lines **64–79** — KEEP. The `# CONCURRENCY / SAFETY` heading + the ASYNCHRONOUS
  explanation + the flock-serialization explanation (ends "...corrupt the timeline.)").
  This is the "core flock serialization explanation" the contract says to keep (point 3a).
- Lines **80–88** — REWRITE. "The TWO further async paths (dwell, activity) ... " + the
  two bullets (dwell bullet KEEP, activity bullet REMOVE). Contract 3b: replace
  "TWO ... (dwell, activity)" → "ONE ... (dwell)".
- Lines **89–95** — REMOVE ENTIRELY. The "Focused-activity detection runs entirely in
  that one poller ..." paragraph (references do_poller, client_activity, ~2x/sec,
  "the only resident process for activity", "See the ACTIVITY DETECTION section below").
  Contract 3c: remove all these sentences.

### REGION B — second concurrency block (near lock())

- **Lines 115–116** — REWRAP. Gap-analysis = **GAP 6d** (pre-T1 line 124).
  Current: "keypresses are ~150 ms apart and the poller fires / only every ~0.5 s,
  so contention is imperceptible." Contract 3d: remove "and the poller fires only
  every ~0.5 s", keep "keypresses are ~150 ms apart, so contention is imperceptible".
  Line-count-neutral (2→2).

## CRITICAL SCOPING — out-of-bounds `poller` references

A file-wide grep for `poller` returns matches at **lines 500–506** — the do_init
"one-shot migration guard" (older version may have left a poller process; clears
`@session-history-poller-pid`). These are **CODE COMMENTS in do_init**, owned by
**T2.S1** (or already present legitimately). They are NOT header comments and NOT
in scope. After T4.S2 they STILL match `poller`.

⇒ Every content-proof must be **scoped to the two CONCURRENCY regions** (lines 64–95
and 108–117), NOT file-wide. A file-wide "no poller" assertion would FALSELY FAIL.

## Forbidden terms that go fully file-wide AFTER this task

`client_activity` (lines 85,90), `focused-activity`/`Focused-activity` (89),
`0.5 s` (116), `resident process` (94), `do_poller` (84), `do_activity` (88),
`ACTIVITY DETECTION` (95), `~2x/sec` (90) — all only in my two regions → all gone
file-wide after the edit. (`alert-activity` already removed by T4.S1; 0 hits.)

## Real functions referenced by the rewritten dwell bullet (not dangling)

- `arm_dwell()` at line 217 (grep-verified).
- `do_dwell()` at line 293 (grep-verified); dispatched at line 538 `dwell) ... do_dwell`.
- `run-shell -b` sleep + "am I still current?" self-guard — matches PRD §8 arm_dwell/do_dwell.

## PRD §13 authority for the rewrite

PRD §13 bullet 5 (literal, from selected_prd_content):
> **Dwell and activity** (the async relevance paths) touch ONLY `tlist` AND now take
> the lock too, so they are fully serialized and can never corrupt `hist`/`idx`/`current`/`mode`.

NOTE: PRD §13 *literally* still says "Dwell and activity" — but the broader plan P1
removed the activity path entirely (PRD §6: "selection and dwell only"; PRD §12: no
output-activity signal; T1 deleted the code). Gap-analysis GAP 6c + the item CONTRACT
(point 3b) resolve this contradiction in the *engine comment* by writing dwell as the
**sole** async path. The contract is authoritative for the engine comment wording;
PRD §13 supplies the structure/voice ("touches ONLY ... AND ... take the lock ...
fully serialized and can never corrupt ...").

## Net line-count delta

- REGION A: 16 lines → 5 lines = **−11**.
- REGION B: 2 lines → 2 lines = **0**.
- Total: **−11**. File 548 → 537.