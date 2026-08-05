# Research — P1.M1.T4.S1: Rewrite "WHAT MAKES A SESSION RELEVANT" comment block

## Task

Rewrite the `# WHAT MAKES A SESSION "RELEVANT"` comment block in
`scripts/session_history.sh` (gap-analysis **GAP 6a** + **6b**) so it mirrors PRD §6's
two-cause promotion model. Remove every reference to `client_activity` polling, the
"focused activity (the PRIMARY signal)" framing, "SILENT-PRESENCE fallback", output
detection, `alert-activity`, and `pipe-pane`. Update `(default 10000 ms)` →
`(default 30000 ms)`. This is the doc update itself (Mode A — inline documentation).

## Input contract (what exists when T4.S1 begins)

Source of truth for state: `scripts/session_history.sh` in the working tree.

- **T1.S1 + T1.S2 (Complete):** `do_activity()`, `do_poller()`, `do_start_poller()`
  functions and their `activity)`/`poller)` case-dispatch branches are GONE. Usage
  string no longer lists them. → file shrank from 650 → 557 lines region.
- **T2.S1 (Complete, committed 85779f4):** `do_init()` pipe-pane legacy cleanup block
  and the poller start call removed.
- **T3.S1 (applied in working tree, uncommitted):** `dwell_ms()` line 154 fallback is
  already `echo 30000` (was `echo 10000`). Confirmed via grep: `grep -n 'echo 30000'`
  → line 154 only; `grep -n 'echo 10000'` → zero matches.

So the engine CODE already matches the PRD two-cause model. Only the HEADER COMMENT
still describes the old three-cause model. T4.S1 fixes the comment block;
T4.S2 fixes the CONCURRENCY block (separate task).

## Exact current text (the oldText for the edit) — lines 39–64

```
# WHAT MAKES A SESSION "RELEVANT" (promoted to #1 of the relevance list)?
#   • direct navigation — pick / sessionx / manual switch / toggle: the session
#     you select becomes #1 immediately.
#   • focused activity (the PRIMARY signal) — typing, switching panes/windows,
#     or doing ANY tmux action in the session you are CURRENTLY VIEWING promotes
#     it to #1 within ~0.5–1.5 s. tmux's alert-activity can't see the focused
#     window (it fires only for background windows), so this is detected instead
#     via the attached client's `#{client_activity}` timestamp: tmux advances it
#     on every keystroke the client sends (a character passed through to the
#     shell, a pane/window switch, or any tmux command). A single background
#     poller promotes the current session whenever that timestamp advances while
#     the session STAYS the same — which is exactly "the user is working in the
#     session they're viewing". A session-switch keystroke (back/forward/toggle/
#     sessionx) also advances client_activity, but it CHANGES the session in the
#     same key event, so the poller sees "session changed" and skips it (walks/
#     nav/toggle keep their own promotion logic). No per-pane pipes, no reader
#     processes, no focus-following — and it captures typing AND pane/window
#     switches AND any tmux action alike.
#   • dwell (the SILENT-PRESENCE fallback) — if you reach a session by a WALK
#     and stay on it longer than @session-history-dwell-ms (default 10000 ms)
#     WITHOUT producing output, it becomes #1. Covers reading/thinking; it is
#     superseded the instant you produce output.
#   Walking (back/forward) through a session does NOT promote it by itself —
#   merely browsing past a session never makes it relevant. But the moment you
#   produce output in a walked-to session, activity promotes it immediately,
#     which is exactly the user's intent ("I'm working here, that's my toggle").
```

Surrounding context (UNCHANGED — out of scope):
- Line 38: `#` (blank separator after THE TOGGLE FEATURE block).
- Line 65: `#` (blank separator).
- Lines 66–71: `# When a session closes it is removed from BOTH lists ...` — this
  paragraph is **already PRD-correct** (says "navigate to it, or dwell on it", no
  activity mention). LEAVE IT.

## Verified facts that constrain the rewrite

1. **`promote_tlist()` exists at line 200** (`grep -n 'promote_tlist()'` → 200). So
   referencing it in the comment (mirroring PRD §6's idempotent/dedup note) is accurate
   and not a dangling reference.

2. **"PRIMARY signal" and "SILENT-PRESENCE" appear ONLY in the WHAT MAKES block**
   (lines 42 and 57). Rewriting 39–64 removes both. No other occurrence anywhere.

3. **Within header lines 1–72, the activity/poller/client_activity/pipe-pane/
   alert-activity terms appear ONLY in lines 42–53** (the WHAT MAKES block). After the
   rewrite, lines 1–72 are clean of all of them.

4. **CRITICAL SCOPE BOUNDARY — the CONCURRENCY block (current lines 73–105) STILL
   contains 5 occurrences of those terms.** That block is **T4.S2's territory** and
   MUST remain untouched by T4.S1. Therefore:
   - File-wide `grep poller|client_activity|alert-activity|pipe-pane` will STILL return
     matches after T4.S1 (they live in the CONCURRENCY block). T4.S1's validation must
     be **block-scoped** (assert the WHAT MAKES block is clean), NOT file-scoped.

5. **After T4.S1, `grep -n '10000' scripts/session_history.sh` returns ZERO matches.**
   Line 58 was the only `10000` in this file. The other two repo `10000`s —
   `session_history.tmux:55` (M2.T1.S1) and `README.md:86` (M3.T2.S1) — are separate
   tasks and stay out of scope.

6. **Mode-flag vocabulary (defined in header lines ~25–28) is authoritative:**
   `""` = NAVIGATION (pick/sessionx/manual), `"walk:<tgt>"` = WALK (back/forward),
   `"toggle:<tgt>"` = TOGGLE. PRD §6's "Direct selection = any NAVIGATION or TOGGLE"
   maps directly onto these. The rewrite MUST use NAVIGATION/WALK/TOGGLE consistently.

## Parallel-execution / sibling coordination

- **T3.S1 (parallel):** changes line 154 `dwell_ms()` (echo 10000 → 30000). It is
  ~115 lines BELOW the WHAT MAKES block and is line-count-neutral (±0). No textual
  overlap. T4.S1's edit is line-count-negative (~−9); both will merge cleanly. **Anchor
  edits on TEXT, not line numbers** (T3.S1's PRP mandates the same).
- **T4.S2 (sequential, not yet started):** rewrites the CONCURRENCY block (current
  73–105). Disjoint region from WHAT MAKES (39–64). T4.S1 landing first shifts T4.S2's
  line numbers down by ~9, but T4.S2 will anchor on text too. No conflict.

## Target wording (mirrors PRD §6 verbatim in substance)

PRD §6 (authoritative, from selected_prd_content):

> A session is promoted to the **front** of the relevance list (`promote_tlist`)
> by exactly two causes:
> 1. **Direct selection.** Any NAVIGATION or TOGGLE promotes the session you land
>    on (`to`). This covers `pick`, tmux-sessionx, a manual `switch-client`, and
>    toggle itself.
> 2. **Dwell.** Reaching a session by a WALK and staying longer than
>    `@session-history-dwell-ms` (see §8).
> **Walking never promotes.** ... If you are working in A, walk the timeline back
> through several sessions to B, and toggle, you flip to A ... because the walk
> never promoted the in-between sessions.
> `promote_tlist` is idempotent and dedups, so promoting a session already at #1
> is a no-op and promoting one lower down moves it to #1.

The replacement comment block is written to match this, using the engine's own
comment conventions (em-dashes, ALL-CAPS for the NAVIGATION/WALK/TOGGLE switch
classes, backtick-wrapped option/function names, `•` bullets). See PRP §"Implementation
Tasks" Task 2 for the exact newText.

## PRD cross-references (why each removed term is gone)

- **client_activity / poller / alert-activity / "focused activity (PRIMARY signal)":**
  PRD §12 — "It is therefore not wired. Relevance comes from **selection** and
  **dwell** only." and "alert-activity only fires for non-focused/background windows."
- **pipe-pane:** PRD §12 — "no robust tmux primitive ... without heavy per-pane
  pipe-pane plumbing ... It is therefore not wired."
- **"SILENT-PRESENCE fallback" framing:** PRD §6 presents dwell as a first-class
  co-equal cause, not a fallback. The "superseded the instant you produce output"
  sentence is pure activity-model residue and must go.
- **(default 10000 ms) → (default 30000 ms):** PRD §15 row + §8 + §14 (non-numeric →
  default 30000). Aligns the comment with the already-landed T3.S1 engine change.

## Validation approach

No test framework in this repo (consistent with T3.S1's approach). Validation is
deterministic and structural:

- **Level 1:** `bash -n` parse check (comment edits cannot break parsing, but it's a
  smoke check); `shellcheck` delta vs. pre-edit baseline (a pure comment rewrite
  introduces no new diagnostics).
- **Level 2 (block-scoped content proofs):** assert the WHAT MAKES block (the edited
  region) contains NONE of {client_activity, poller, alert-activity, pipe-pane,
  "focused activity", "PRIMARY signal", "SILENT-PRESENCE", 10000, "~0.5", "superseded"},
  DOES contain the required PRD §6 phrases {"exactly", "direct selection", "NAVIGATION",
  "TOGGLE", "dwell", "WALK", "30000", "does NOT promote it by itself"}, and the
  "When a session closes" paragraph + CONCURRENCY block are byte-identical to pre-edit.
- **Level 3:** `grep -n '10000' scripts/session_history.sh` → zero (block was the only
  source in this file); `git diff --stat` → single file, comment-only hunk; the OTHER
  two repo `10000`s (`.tmux:55`, `README.md:86`) are UNCHANGED (separate tasks).