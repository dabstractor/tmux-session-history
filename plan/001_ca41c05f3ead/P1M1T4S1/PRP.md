name: "P1.M1.T4.S1 — Rewrite 'WHAT MAKES A SESSION RELEVANT' comment section"
description: "Rewrite the `# WHAT MAKES A SESSION \"RELEVANT\"` comment block in `scripts/session_history.sh` (current lines 39–64; gap-analysis GAP 6a + 6b) so it mirrors PRD §6's two-cause promotion model exactly: (1) direct selection — any NAVIGATION (pick/sessionx/manual switch-client) or TOGGLE promotes the session you land on to #1 immediately; (2) dwell — reach a session by a WALK and stay longer than @session-history-dwell-ms (default 30000 ms). Remove ALL text about client_activity polling, the 'focused activity (the PRIMARY signal)' framing, 'SILENT-PRESENCE fallback', typing/output detection, alert-activity, and pipe-pane. State explicitly that walking never promotes. This IS the doc update (Mode A — inline documentation on the engine file). Comment-only change; no code logic touched. Block shinks ~26 → 17 lines (~−9 lines net)."

---

## Goal

**Feature Goal**: Make the engine's header comment block for "WHAT MAKES A SESSION RELEVANT"
faithfully describe the PRD §6 two-cause promotion model, eliminating all residue of the removed
`client_activity`-polling activity detector (which T1/T2 already deleted from the code). The comment
must read as if PRD §6 were paraphrased in the engine's own voice.

**Deliverable**: An edited `scripts/session_history.sh` in which the comment block currently spanning
lines 39–64 (the `# WHAT MAKES A SESSION "RELEVANT" ...` heading, its bullets, and the trailing
"Walking ..." paragraph) is replaced with a PRD §6-faithful block. The replacement:
- States promotion happens by **exactly two** causes.
- Bullet 1: **direct selection** — any NAVIGATION (pick / sessionx / manual switch-client) or TOGGLE
  promotes the session you land on to #1 immediately.
- Bullet 2: **dwell** — reach a session by a WALK (back/forward) and stay longer than
  `@session-history-dwell-ms` **(default 30000 ms)**.
- States explicitly: "Walking (back/forward) through a session does NOT promote it by itself."
- Contains the PRD §6 "working in A, walk back to B, toggle → A" rationale and the `promote_tlist`
  idempotent/dedup note.
- Contains **zero** occurrences of: `client_activity`, `poller`, `alert-activity`, `pipe-pane`,
  "focused activity", "PRIMARY signal", "SILENT-PRESENCE", "superseded", "~0.5", or `10000`.

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0 (smoke check — comment edits cannot break parsing).
2. `shellcheck` reports **no new diagnostics** vs. a pre-edit baseline (a pure comment rewrite
   introduces none).
3. The edited WHAT MAKES block contains NONE of the forbidden terms and ALL of the required PRD §6
   phrases (Level 2 content proofs pass).
4. `grep -n '10000' scripts/session_history.sh` → **zero matches** (line 58 was the only `10000` in
   this file).
5. The "When a session closes ..." paragraph (current lines 66–71) and the entire CONCURRENCY block
   (current lines 73–105) are **byte-identical** to pre-edit — they are owned by other tasks
   (CONCURRENCY = T4.S2; the close paragraph is already PRD-correct).
6. No code line (any line not starting with `#`) is modified.

## User Persona (if applicable)

**Target User**: Developer / maintainer reading the engine source to understand the relevance model.

**Use Case**: A future contributor opens `scripts/session_history.sh` and reads the header to learn
how sessions get promoted, before touching `promote_tlist`, `do_hook`, or `arm_dwell`.

**User Journey**: Reader scans the header → finds "WHAT MAKES A SESSION RELEVANT" → sees exactly two
causes (selection + dwell) and the explicit "walking never promotes" rule → correctly understands the
model without ever needing to open the PRD.

**Pain Points Addressed**: Today the header describes a **third** cause ("focused activity (the
PRIMARY signal)") and multi-paragraph `client_activity` polling detail for a feature that **no longer
exists in the code** (removed in T1.S1/T1.S2/T2.S1). A reader is actively misled into believing there
is an output-activity promotion path. This rewrite removes that contradiction.

## Why

- **Truth-in-source.** The engine code already implements the PRD §6 two-cause model (T1 removed the
  `client_activity` poller; T2 removed the pipe-pane legacy + poller bootstrap; T3.S1 set the dwell
  fallback to 30000). The header comment is the last place still asserting the removed three-cause
  model. PRD §6 + §12 are unambiguous: "Relevance comes from **selection** and **dwell** only."
- **Gap closure.** This task is **GAP 6a + 6b** from
  `plan/001_ca41c05f3ead/architecture/gap_analysis.md`. GAP 6a (the relevance bullets) is the 🔴
  rewrite; GAP 6b (the `(default 10000 ms)` literal) is absorbed into the rewrite as
  `(default 30000 ms)`. GAP 6c (the CONCURRENCY block) is a **separate task, T4.S2**.
- **Mode A documentation.** The contract (point 5) designates this comment block as Mode A inline
  documentation — no separate docs subtask. The header IS the doc.
- **Lowest-risk change class.** Comment-only: no logic, no state, no runtime behavior change. The only
  "risk" is textual accuracy, which the Level 2 content proofs fully pin down.

## What

Replace one contiguous comment region (current lines 39–64) with a PRD §6-faithful comment block.
Nothing else in the file is touched.

### The exact region to replace (oldText) — current lines 39–64

```bash
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
#   which is exactly the user's intent ("I'm working here, that's my toggle").
```

### The replacement region (newText)

```bash
# WHAT MAKES A SESSION "RELEVANT" (promoted to #1 of the relevance list)?
#   A session is promoted to the FRONT of the relevance list by exactly TWO
#   causes:
#   • direct selection — any NAVIGATION (pick / sessionx / manual switch-client)
#     or TOGGLE promotes the session you land on (`to`) to #1 immediately.
#   • dwell — if you reach a session by a WALK (back/forward) and stay on it
#     longer than @session-history-dwell-ms (default 30000 ms), it becomes #1.
#
#   Walking (back/forward) through a session does NOT promote it by itself —
#   merely browsing past a session never makes it relevant. This is the rule
#   that makes toggle track USAGE rather than browsing: if you are working in A,
#   walk the timeline back through several sessions to B, and toggle, you flip
#   to A (the thing you were using) — not to the session adjacent to B — because
#   the walk never promoted the in-between sessions.
#
#   promote_tlist is idempotent and dedups, so promoting a session already at
#   #1 is a no-op, and promoting one lower down moves it to #1.
```

Net effect: the block drops from 26 comment lines to 17 (~−9 lines). File shrinks by ~9 lines.
Line 38 (`#` blank) above and line 65 (`#` blank) below are left intact so the block remains
visually separated from THE TOGGLE FEATURE block (above) and the "When a session closes" paragraph
(below).

### Success Criteria

- [ ] The edited block contains the phrase "exactly TWO" (or "exactly two") and exactly two bullets.
- [ ] Bullet 1 names **direct selection** and lists NAVIGATION (pick/sessionx/manual switch-client)
      or TOGGLE as the promoting events.
- [ ] Bullet 2 names **dwell**, ties it to a WALK (back/forward), and cites
      `@session-history-dwell-ms (default 30000 ms)`.
- [ ] The explicit sentence "Walking (back/forward) through a session does NOT promote it by itself"
      is present.
- [ ] The block contains NONE of: `client_activity`, `poller`, `alert-activity`, `pipe-pane`,
      "focused activity", "PRIMARY signal", "SILENT-PRESENCE", "superseded", "~0.5", `10000`.
- [ ] `grep -n '10000' scripts/session_history.sh` → zero matches.
- [ ] `bash -n` passes; `shellcheck` introduces no new diagnostics.
- [ ] No non-comment line is changed; the "When a session closes" paragraph and the CONCURRENCY block
      are byte-identical to pre-edit.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact `oldText` (current lines 39–64) and the exact `newText` for a
single `edit`-tool call; the authoritative source wording (PRD §6, reproduced in full under
Documentation); the gap-analysis mapping (GAP 6a + 6b = this task; GAP 6c = T4.S2, out of scope); the
input contract (T1/T2/T3.S1 already landed — confirmed by grep: `dwell_ms()` line 154 already echoes
30000, functions gone); the mode-flag vocabulary (NAVIGATION/WALK/TOGGLE, defined in the header);
proof that `promote_tlist()` really exists (line 200, so referencing it is not a dangling reference);
the critical scope boundary that the CONCURRENCY block (current 73–105) still contains 5 activity
references owned by T4.S2 — so validation must be **block-scoped**, not file-scoped; and deterministic
Level 1–3 validation. An implementer with zero prior knowledge can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authoritative model this comment must mirror
- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't"
  why: "PRD §6 is the single source of truth for the two-cause model. It states: promote by exactly
        two causes — (1) direct selection (any NAVIGATION or TOGGLE promotes the session you land on,
        `to`), (2) dwell (reach by WALK, stay > @session-history-dwell-ms). 'Walking never promotes.'
        Includes the A/B walk example and the promote_tlist idempotent/dedup note. The rewrite is a
        faithful paraphrase of this section in the engine's comment voice."
  critical: "Use the switch-class vocabulary NAVIGATION / WALK / TOGGLE consistently — these are the
             exact tokens the mode-flag block (header lines ~25–28) defines. PRD §6 uses them."

# MUST READ — why every removed term is gone
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "Justifies deleting client_activity / poller / alert-activity / pipe-pane / 'focused activity'
        references: 'alert-activity only fires for non-focused/background windows ... the opposite of
        the session I'm using.' and 'no robust tmux primitive ... without heavy per-pane pipe-pane
        plumbing ... It is therefore not wired. Relevance comes from selection and dwell only.'"
  critical: "This is the authority for removing the entire 'focused activity (the PRIMARY signal)'
             bullet and the 'superseded the instant you produce output' sentence."

# MUST READ — dwell default source (the comment literal 10000 → 30000)
- docfile: PRD.md
  section: "§15. Configuration reference + §8 Dwell + §14 Invariants"
  why: "Default @session-history-dwell-ms = 30000 (§15 row). §8 'arm_dwell' comments 'default 30000'.
        §14 'Non-numeric dwell-ms → treated as the default (30000).' The comment's '(default 30000 ms)'
        must match the already-landed T3.S1 engine fallback (line 154 now echoes 30000)."
  critical: "After this task the engine file has ZERO '10000' (line 58 was the only one). The other
             repo 10000s — session_history.tmux:55 (M2.T1.S1) and README.md:86 (M3.T2.S1) — are
             separate tasks and MUST stay untouched."

# The scoping document that enumerated this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 6 — HEADER COMMENTS describe activity as the PRIMARY signal (PRD §6)"
  why: "GAP 6a = lines 42–66 (THIS task — rewrite to PRD §6 two-cause model). GAP 6b = line 58
        '(default 10000 ms)' (absorbed into this rewrite as 30000). GAP 6c = lines 89–104 CONCURRENCY
        block (T4.S2 — DO NOT TOUCH). GAP 6d = line 124 poller-fires wording (also T4.S2 / CONCURRENCY
        territory). Note the gap-analysis line numbers are from the pre-T1 650-line file; current file
        is 557 lines so WHAT MAKES is now lines 39–64."
  critical: "GAP 6a+6b is the ENTIRE scope of T4.S1. Touching GAP 6c/6d collides with T4.S2."

# The parallel sibling PRP (CONTRACT) — establishes the input state
- docfile: plan/001_ca41c05f3ead/P1M1T3S1/PRP.md
  why: "T3.S1 changes dwell_ms() line 154 (echo 10000 → echo 30000), line-count-neutral, ~115 lines
        BELOW the WHAT MAKES block. Confirms the input contract: 'scripts/session_history.sh after
        T1.S1 (functions removed) and T3.S1 (dwell default changed).' T3.S1 explicitly DEFERS the
        line-58 header comment to T4: 'The line-58 header comment ... is left untouched (owned by T4).'
        So when T4.S1 runs, line 154 is already 30000 and line 58 is still 10000 — both as expected."
  critical: "Both T3.S1 and T4.S1 edit disjoint regions. Anchor on TEXT, not line numbers (T3.S1's
             PRP mandates the same). Neither edit can conflict."

# The file under edit — structure & vocabulary
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash, set -u (line 110
        post-edit). Header comment block runs lines 1–~108 (line after it = `set -u`). The WHAT MAKES
        block is lines 39–64. promote_tlist() is a real function at line 200 (grep-verified), so the
        idempotent/dedup note referencing it is accurate."
  pattern: "Engine header style: lines are `#`-prefixed; section headings are `# ALL-CAPS`; bullets use
            `#   • name — ...` with em-dash; switch classes (NAVIGATION/WALK/TOGGLE) are ALL-CAPS;
            option/function names are backtick-wrapped (`to`, `@session-history-dwell-ms`,
            `promote_tlist`). Match this voice exactly in the rewrite."
  gotcha: "The CONCURRENCY block (current lines 73–105) STILL contains 5 references to client_activity
           / poller / alert-activity / pipe-pane / 'focused activity'. Those are T4.S2's to remove.
           T4.S1 must leave them intact — file-wide greps for those terms will STILL match after this
           task. Scope every content-proof to the WHAT MAKES block (lines 39–64 pre-edit, or the edited
           region post-edit), never the whole file."

# Mode-flag vocabulary — authoritative definition (header lines ~25–28), used verbatim in the rewrite
- file: scripts/session_history.sh
  section: "THE TIMELINE (history) — mode flag values (header lines ~25–28)"
  why: "Defines the three switch classes the rewrite must use: '' = a NAVIGATION (pick/sessionx/manual);
        'walk:<tgt>' = a WALK (back/forward); 'toggle:<tgt>' = the TOGGLE key. PRD §6 'any NAVIGATION
        or TOGGLE' and 'by a WALK' map onto these exactly."
  critical: "Do NOT invent new class names. Use NAVIGATION / WALK / TOGGLE verbatim. This keeps the
             comment consistent with both the mode-flag definitions above it and do_hook's dispatch
             below it."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §6/§12/§15 authorize this rewrite
├── README.md                   # docs (NOT this task — M3 owns README activity removal)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (557 lines, working tree)
│                                #     lines 39–64  = WHAT MAKES block  (THIS TASK)
│                                #     line  154    = dwell_ms() echo 30000 (T3.S1 — already landed)
│                                #     lines 73–105 = CONCURRENCY block   (T4.S2 — DO NOT TOUCH)
│                                #     line  200    = promote_tlist() def (referenced by new comment)
├── session_history.tmux        # entry point (NOT this task — M2.T1.S1 owns line 55)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md          # GAP 6a+6b = this task
        ├── P1M1T3S1/PRP.md                        # parallel sibling (dwell_ms, disjoint region)
        └── P1M1T4S1/
            ├── PRP.md                             # ← THIS task
            └── research/what_makes_relevant_block.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified, and ONLY its comment block
# at lines 39–64 (the WHAT MAKES region). After this task the file is ~548 lines (−9).
# The WHAT MAKES block mirrors PRD §6; the rest of the file is byte-identical.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — scope boundary. The CONCURRENCY block (current lines 73–105) STILL references
# client_activity / poller / alert-activity / pipe-pane / 'focused activity' (5 occurrences).
# Those are T4.S2's to remove. After T4.S1, a FILE-WIDE grep for those terms STILL matches.
# Therefore every content-proof below is scoped to the WHAT MAKES block (lines 39–64 pre-edit),
# NOT the whole file. Asserting file-wide "no poller references" would FALSELY FAIL.

# GOTCHA — line numbers drift under parallel/sequential edits. T3.S1 edits line 154 (dwell_ms,
# line-count-neutral, ±0) and T4.S2 will edit the CONCURRENCY block (line-count-negative). The
# WHAT MAKES block (39–64) is ABOVE both, but T4.S1's own edit is line-count-negative (−9), so
# any later task's line numbers shift. ALWAYS anchor the edit on the full oldText TEXT, never
# on "line 39". (T3.S1's PRP mandates the same text-anchoring discipline.)

# GOTCHA — em-dash and bullet characters. The engine header uses the UTF-8 em-dash '—' (U+2014)
# and the bullet '•' (U+2022), NOT ASCII '-' or '*'. The newText must use these exact characters
# to match the surrounding comment voice. (The oldText contains them too — copy faithfully.)

# GOTCHA — the comment-wrapping column. Existing header comment lines wrap at ~72 chars of text
# (after the leading '#'). Keep the rewrite within the same visual width so the block stays
# aligned with its neighbors. The newText above is already wrapped to this width.

# GOTCHA — set -u is at line 110 (post-edit ~101). Comment edits do not touch code, so set -u is
# irrelevant to this task — but be aware the header block ENDS just above it; do not let the edit
# bleed into the 'set -u' line or the blank lines around it.

# GOTCHA — promote_tlist() is referenced in the new comment. It is a REAL function (line 200,
# grep-verified). This is an accurate cross-reference mirroring PRD §6, not a dangling name. Do
# not strip it fearing it is dead code — it is the core promotion helper.
```

## Implementation Blueprint

### Data models and structure

None. This is a pure comment rewrite. No data models, schemas, types, options, or code logic change.
The only "data" is the human-readable prose of one comment block.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE a pre-edit shellcheck + region snapshot (no source edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_before_t4s1.txt 2>&1; echo "baseline exit: $?"
  - RUN: wc -l scripts/session_history.sh   # note the pre-edit count (currently 557; assert equality later)
  - RUN: sed -n '66,71p' scripts/session_history.sh > /tmp/close_para_before.txt   # the "When a session
         closes" paragraph (PRD-correct, must stay byte-identical)
  - RUN: sed -n '73,105p' scripts/session_history.sh > /tmp/concurrency_before.txt # T4.S2 territory,
         must stay byte-identical
  - WHY: this task's shellcheck gate is "no NEW diagnostics"; the file already carries pre-existing SC
         warnings (gap analysis did not clean them). The two region snapshots are regression guards so
         you can prove you edited ONLY the WHAT MAKES block.

Task 2: REPLACE the WHAT MAKES comment block (single exact-text edit)
  - USE the `edit` tool ONCE with oldText = the current lines 39–64 block (reproduced verbatim in the
    "The exact region to replace" section of this PRP) and newText = the PRD §6-faithful replacement
    (reproduced verbatim in the "The replacement region" section).
  - ANCHOR on the full block TEXT (from `# WHAT MAKES A SESSION "RELEVANT" ...` through the line ending
    `... ("I'm working here, that's my toggle").`), NOT on line numbers. T3.S1 may land before or after;
    line 39–64 is stable relative to the block because T3.S1's edit is ~115 lines below and ±0 lines,
    but text-matching is fully robust to any ordering.
  - PRESERVE the surrounding blank-comment separators: line 38 (`#`) above and line 65 (`#`) below
    must remain. Do NOT delete them.
  - DO NOT TOUCH: the "When a session closes" paragraph (66–71), the CONCURRENCY block (73–105),
    line 154 (dwell_ms — T3.S1), any code line, any line outside the WHAT MAKES block.
  - ENSURE the newText uses the engine's exact comment glyphs: UTF-8 em-dash '—' and bullet '•'
    (copy them from the oldText — do not substitute ASCII '-' / '*').

Task 3: VERIFY parse (no edits)
  - RUN: bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
  - EXPECTED: PARSE OK (exit 0). A comment rewrite cannot break parsing; this is a smoke check that
    confirms no accidental deletion of a line-continuation or stray backtick leaked into code.

Task 4: VERIFY shellcheck delta + line count + region integrity (no edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after_t4s1.txt 2>&1
  - RUN: diff <(sort /tmp/sc_before_t4s1.txt) <(sort /tmp/sc_after_t4s1.txt)
    EXPECTED: no diff (a pure comment rewrite introduces no shellcheck diagnostic).
  - RUN: wc -l scripts/session_history.sh
    EXPECTED: pre-edit count MINUS 9 (currently 557 → 548). Assert the delta is exactly −9; any other
    delta means you added/removed the wrong number of lines — re-check the newText line count.
  - RUN: sed -n '1,/^set -u$/p' scripts/session_history.sh | tail -5   # confirm the edited block still
         ends in a blank `#` followed by the "When a session closes" paragraph, then CONCURRENCY.
  - RUN: diff /tmp/close_para_before.txt <(sed -n '/^# When a session closes/,/^# CONCURRENCY/p' \
         scripts/session_history.sh | sed '$d')
    EXPECTED: no diff (the close paragraph is byte-identical).
  - RUN: diff /tmp/concurrency_before.txt <(sed -n '/^# CONCURRENCY \/ SAFETY/,/^# Global state/p' \
         scripts/session_history.sh | sed '$d')
    EXPECTED: no diff (the CONCURRENCY block is byte-identical — T4.S2 owns it).

Task 5: VERIFY block-scoped content (Level 2 — the heart of this task)
  - RUN the Level 2 forbidden-terms + required-phrases block. EXPECTED: all OK (see Validation Loop).
```

### Implementation Patterns & Key Details

```bash
# The WHAT MAKES block sits in the engine header, immediately after THE TOGGLE FEATURE block and
# immediately before the "When a session closes" paragraph. Its neighbors:
#
#   ... (THE TOGGLE FEATURE block, lines ~30–37)
#   #                                          <- line 38, blank separator (KEEP)
#   # WHAT MAKES A SESSION "RELEVANT" ...      <- line 39, block START (this task)
#   ...
#   #   ... ("I'm working here, that's my toggle").   <- line 64, block END (this task)
#   #                                          <- line 65, blank separator (KEEP)
#   # When a session closes it is removed ...  <- line 66, PRD-correct paragraph (KEEP)
#
# The replacement block keeps the same heading line and the same trailing structure, so the only
# visible change is the bullets + the Walking paragraph being rewritten. Line 38 and line 65 stay.

# WHY each forbidden term is removed (PRD authority):
#   client_activity / poller / alert-activity / "focused activity (the PRIMARY signal)" / "~0.5–1.5 s"
#     -> PRD §12: "alert-activity only fires for non-focused/background windows ... the opposite of
#        'the session I'm using'." and "It is therefore not wired." T1.S1/T2.S1 already deleted the
#        do_activity/do_poller/do_start_poller functions and the pipe-pane bootstrap.
#   pipe-pane
#     -> PRD §12: "no robust tmux primitive ... without heavy per-pane pipe-pane plumbing." T2.S1
#        already deleted the do_init pipe-pane cleanup block.
#   "SILENT-PRESENCE fallback" + "superseded the instant you produce output"
#     -> PRD §6 presents dwell as a co-equal FIRST-CLASS cause ("exactly two causes"), not a fallback
#        subordinate to activity. That framing was an artifact of the removed three-cause model.
#   "But the moment you produce output in a walked-to session, activity promotes it immediately"
#     -> pure residue of the removed activity detector; PRD §6 replaces it with the A/B walk rationale.

# WHY each required phrase is added (PRD §6 authority):
#   "exactly TWO causes" / two bullets         -> PRD §6: "promoted ... by exactly two causes".
#   "direct selection"                         -> PRD §6 cause 1 name.
#   "NAVIGATION (pick / sessionx / manual switch-client) or TOGGLE" -> PRD §6: "Any NAVIGATION or
#      TOGGLE ... This covers pick, tmux-sessionx, a manual switch-client, and toggle itself."
#   "dwell" + "reach ... by a WALK (back/forward)" + "@session-history-dwell-ms (default 30000 ms)"
#     -> PRD §6 cause 2 + §15 default (30000, matching the already-landed T3.S1 engine fallback).
#   "Walking (back/forward) through a session does NOT promote it by itself" -> contract point 3
#      explicit requirement; mirrors PRD §6 "Walking never promotes."
#   "if you are working in A, walk the timeline back ... to B, and toggle, you flip to A" -> PRD §6
#      rationale paragraph (why walking never promoting makes toggle track usage not browsing).
#   "promote_tlist is idempotent and dedups"   -> PRD §6 final paragraph; promote_tlist() is a real
#      function at line 200, so the reference is accurate.
```

### Integration Points

```yaml
DATABASE:
  - none. Pure comment edit; no DB, no state.

CONFIG (tmux global user options):
  - none changed. The comment MENTIONS @session-history-dwell-ms (default 30000 ms) but does not
        read or write any option. The runtime default already lives in dwell_ms() (T3.S1, line 154).

ROUTES / DISPATCH:
  - none changed. No subcommand, no case branch, no function is touched. This is header prose only.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit shellcheck baseline (run BEFORE editing):
shellcheck scripts/session_history.sh > /tmp/sc_before_t4s1.txt 2>&1; echo "baseline exit: $?"
wc -l scripts/session_history.sh   # remember this number (currently 557)

# 1. Parse check (run AFTER the single edit):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0).

# 2. Lint delta (run AFTER editing):
shellcheck scripts/session_history.sh > /tmp/sc_after_t4s1.txt 2>&1
diff <(sort /tmp/sc_before_t4s1.txt) <(sort /tmp/sc_after_t4s1.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: empty diff (a pure comment rewrite introduces no shellcheck diagnostic).

# 3. Line-count delta (run AFTER editing):
after=$(wc -l < scripts/session_history.sh)
# Expected: after == pre-edit-count - 9  (currently 557 -> 548). The oldText block is 26 lines; the
# newText block is 17 lines; delta = -9. Any other delta = wrong number of lines edited.
echo "post-edit line count = $after (expect pre-edit - 9)"
```

### Level 2: Block-Scoped Content Proofs (the heart of this task)

These proofs are scoped to the **WHAT MAKES block only** (lines 39–64 pre-edit; the edited region
post-edit). They are deliberately NOT file-wide, because the CONCURRENCY block (T4.S2 territory)
still legitimately contains activity/poller references.

```bash
# Extract the edited WHAT MAKES block into a scratch variable for scoped assertions.
BLOCK=$(sed -n '/^# WHAT MAKES A SESSION "RELEVANT"/,/^# When a session closes/p' scripts/session_history.sh | sed '$d')

pass=0; fail=0
require() { # require <needle> <label>   — needle MUST appear in BLOCK
  if printf '%s' "$BLOCK" | grep -qF -- "$1"; then echo "OK   $2"; pass=$((pass+1))
  else echo "FAIL $2  (missing: '$1')"; fail=$((fail+1)); fi
}
forbid() { # forbid <needle> <label>    — needle MUST NOT appear in BLOCK
  if printf '%s' "$BLOCK" | grep -qF -- "$1"; then echo "FAIL $2  (forbidden term present: '$1')"; fail=$((fail+1))
  else echo "OK   $2"; pass=$((pass+1)); fi
}

# REQUIRED PRD §6 phrases:
require 'WHAT MAKES A SESSION "RELEVANT"'           'heading preserved'
require 'exactly TWO'                               'states exactly two causes'
require 'direct selection'                          'cause 1: direct selection'
require 'NAVIGATION'                                'cause 1: NAVIGATION class'
require 'switch-client'                             'cause 1: manual switch-client example'
require 'TOGGLE'                                    'cause 1: TOGGLE class'
require 'dwell'                                     'cause 2: dwell'
require 'WALK'                                      'cause 2: WALK class'
require 'back/forward'                              'cause 2: back/forward elaboration'
require '@session-history-dwell-ms'                 'cause 2: option name'
require '30000 ms'                                  'cause 2: default 30000 (NOT 10000)'
require 'does NOT promote it by itself'             "explicit 'walking never promotes' sentence"
require 'promote_tlist is idempotent'               'PRD §6 idempotent/dedup note'

# FORBIDDEN removed-model terms (none may survive in the block):
forbid 'client_activity'        'no client_activity polling reference'
forbid 'alert-activity'         'no alert-activity reference'
forbid 'poller'                 'no poller reference'
forbid 'pipe-pane'              'no pipe-pane reference'
forbid 'PRIMARY signal'         "no 'focused activity (PRIMARY signal)' framing"
forbid 'SILENT-PRESENCE'        "no 'SILENT-PRESENCE fallback' framing"
forbid 'focused activity'       'no focused-activity framing at all'
forbid 'superseded'             'no activity-supersedes-dwell residue'
forbid '0.5'                    'no poller-interval residue'
forbid '10000'                  'no legacy 10000 default (must be 30000)'

echo "---"; echo "PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] && echo "ALL WHAT-MAKES CONTENT PROOFS OK" || { echo "SOME PROOFS FAILED"; exit 1; }
# Expected: PASS=23 FAIL=0.

# Whole-FILE proof that the legacy default literal is gone from the engine file:
grep -n '10000' scripts/session_history.sh
# Expected: NO output (zero matches). Line 58 was the only '10000' in this file; the rewrite
#           turned it into '30000 ms'. (If you see a match, the edit did not land correctly.)
```

### Level 3: Region Integrity & Scope Boundary (System Validation)

```bash
# A. The two regions OUTSIDE the WHAT MAKES block are byte-identical to pre-edit (regression guards).

# A.1 — "When a session closes" paragraph (PRD-correct; was already correct, must stay unchanged):
diff /tmp/close_para_before.txt \
     <(sed -n '/^# When a session closes/,/^# CONCURRENCY/p' scripts/session_history.sh | sed '$d')
# Expected: empty diff.

# A.2 — CONCURRENCY block (T4.S2 territory; still has activity references that T4.S2 will remove):
diff /tmp/concurrency_before.txt \
     <(sed -n '/^# CONCURRENCY \/ SAFETY/,/^# Global state/p' scripts/session_history.sh | sed '$d')
# Expected: empty diff. (NOTE: this block STILL contains client_activity/poller/alert-activity
#           references — that is CORRECT for now; T4.S2 owns removing them.)

# B. No CODE line changed. Every changed line in the diff must begin with '#':
git diff scripts/session_history.sh | grep -E '^[-+]' | grep -vE '^([-+]{3}|[-+]#)' 
# Expected: NO output. Any line here is a NON-comment change = over-reach; revert it.
#           (The ^---/+++ file-header lines are excluded; ^[-+]# are comment add/removes — allowed.)

# C. The git diff is a single contiguous hunk in the WHAT MAKES region:
git diff --stat scripts/session_history.sh
# Expected: a single file, ~+17/-26 lines (the block rewrite).

# D. Cross-file awareness (informational — NOT to be changed in this task):
grep -n '10000' session_history.tmux   # line 55 still says 10000 -> M2.T1.S1's job
grep -n '10000' README.md              # line 86 still says 10000 -> M3.T2.S1's job
# These are EXPECTED to still show 10000 after THIS task. They are separate work items.

# E. CONCURRENCY block still references the removed model (proves you did NOT over-reach into T4.S2):
sed -n '/^# CONCURRENCY \/ SAFETY/,/^# Global state/p' scripts/session_history.sh | grep -c 'client_activity\|poller\|alert-activity\|pipe-pane\|focused activity'
# Expected: 5 (the same count as pre-edit — T4.S2 will bring this to 0; not this task).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Prove the rewrite is internally consistent with the rest of the header.

# D.1 — switch-class vocabulary consistency: the rewrite uses the SAME class tokens the mode-flag
#       block defines. Confirm all three appear in the WHAT MAKES block AND in the mode-flag block:
for cls in NAVIGATION WALK TOGGLE; do
  printf '%-12s header-mode-block=%s  what-makes-block=%s\n' "$cls" \
    "$(sed -n '/^# THE TIMELINE (history) — always on/,/^# THE TOGGLE FEATURE/p' scripts/session_history.sh | grep -c "$cls")" \
    "$(printf '%s' "$BLOCK" | grep -c "$cls")"
done
# Expected: each class appears >=1 in BOTH blocks (consistent vocabulary across the header).

# D.2 — the dwell default cited in the comment matches the engine's runtime default (T3.S1):
printf 'comment says: %s\n' "$(printf '%s' "$BLOCK" | grep -oE 'default [0-9]+ ms')"
printf 'engine echoes: %s\n' "$(grep -oE 'echo [0-9]+' scripts/session_history.sh | grep -oE '[0-9]+' | sort -u | tr '\n' ' ')"
# Expected: comment says "default 30000 ms"; engine echoes include 30000. They agree.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_t4s1.txt`
      (sorted diff is empty).
- [ ] `wc -l scripts/session_history.sh` is **pre-edit count − 9** (currently 557 → 548).
- [ ] `grep -n '10000' scripts/session_history.sh` → **zero matches**.

### Feature Validation

- [ ] Level 2 content proofs report `PASS=23 FAIL=0` (13 required PRD §6 phrases present + 10
      forbidden removed-model terms absent).
- [ ] The WHAT MAKES block states "exactly TWO" causes with exactly two bullets.
- [ ] Cause 1 = direct selection (NAVIGATION or TOGGLE); cause 2 = dwell (WALK + @session-history-dwell-ms).
- [ ] The explicit "Walking (back/forward) through a session does NOT promote it by itself" sentence
      is present.
- [ ] `(default 30000 ms)` is present; `(default 10000 ms)` is gone.

### Code Quality Validation

- [ ] The edit touches ONLY comment lines (`git diff | grep -E '^[-+]' | grep -vE '^([-+]{3}|[-+]#)'` → empty).
- [ ] The "When a session closes" paragraph is **byte-identical** to pre-edit (diff empty).
- [ ] The CONCURRENCY block is **byte-identical** to pre-edit (diff empty) — its activity references
      remain, owned by T4.S2.
- [ ] The rewrite uses the engine's exact comment glyphs (UTF-8 em-dash `—`, bullet `•`), not ASCII.
- [ ] Switch-class vocabulary (NAVIGATION/WALK/TOGGLE) is consistent with the mode-flag block above.
- [ ] Surrounding blank `#` separator lines (pre-edit line 38 and line 65) are preserved.

### Documentation & Deployment

- [ ] This IS the doc update (Mode A — inline documentation on the engine file). No separate docs file.
- [ ] No README change (README activity removal = M3.T3.S1/S2; README default = M3.T2.S1).
- [ ] No entry-point change (session_history.tmux:55 = M2.T1.S1).
- [ ] No new environment variables or options.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT edit the CONCURRENCY block** (current lines 73–105). It still references client_activity /
  poller / alert-activity / pipe-pane / "focused activity" — and that is **correct for now**. Those are
  **T4.S2's** to remove. Editing them here is a scope collision with T4.S2.
- ❌ **Do NOT touch the "When a session closes" paragraph** (current lines 66–71). It is already
  PRD-correct (says "navigate to it, or dwell on it", no activity mention). Leave it byte-identical.
- ❌ **Do NOT "also fix" `session_history.tmux:55` or `README.md:86`.** Both still say `10000` and are
  separate work items (M2.T1.S1 and M3.T2.S1). This task is the engine comment ONLY.
- ❌ **Do NOT edit line 154** (`dwell_ms()` `echo 30000`). That is **T3.S1's** change (already landed in
  the working tree). The comment's `(default 30000 ms)` must *agree* with it, not duplicate-edit it.
- ❌ **Do NOT change any non-comment line.** This is a header-prose rewrite. Any `git diff` line not
  starting with `#` (excluding the `---`/`+++` headers) is over-reach.
- ❌ **Do NOT key the edit on hard line numbers (39–64).** Anchor on the full block TEXT. T3.S1 (±0,
  ~115 lines below) and your own −9 edit both shift line numbers; text-matching is robust to all of it.
- ❌ **Do NOT substitute ASCII `-`/`*` for the em-dash `—`/bullet `•`.** The engine header is UTF-8 and
  uses those glyphs throughout; ASCII substitution breaks visual consistency with neighbors.
- ❌ **Do NOT assert file-wide "no poller/client_activity references" as a success criterion.** That
  would FALSELY FAIL — the CONCURRENCY block legitimately still has them until T4.S2. Scope every
  content-proof to the WHAT MAKES block.
- ❌ **Do NOT add or remove blank `#` separator lines** around the block. Pre-edit line 38 and line 65
  separate the block from THE TOGGLE FEATURE block and the "When a session closes" paragraph; keep both.

---

## Scope Boundaries (one-screen reference)

| Item | This task (T4.S1)? | Owner |
|------|:---:|-------|
| WHAT MAKES comment block (current lines 39–64) → PRD §6 two-cause rewrite | ✅ | T4.S1 |
| `(default 10000 ms)` → `(default 30000 ms)` inside the dwell bullet (line 58) | ✅ | T4.S1 (absorbed into rewrite) |
| Keep blank `#` separators (line 38 above, line 65 below) | ✅ (preserve) | T4.S1 |
| "When a session closes" paragraph (lines 66–71, already PRD-correct) | ❌ | untouched (preserve byte-identical) |
| CONCURRENCY block (lines 73–105) activity/poller rewrite | ❌ | **T4.S2** |
| Line 124 "poller fires only every ~0.5 s" wording | ❌ | **T4.S2** (CONCURRENCY territory) |
| `dwell_ms()` line 154 default (10000 → 30000) | ❌ | **T3.S1** (already landed) |
| `session_history.tmux:55` entry-point default | ❌ | **M2.T1.S1** |
| `session_history.tmux:70–77` focused-activity comment block | ❌ | **M2.T1.S2** |
| `README.md:86` Options table default + `110–148` activity prose | ❌ | **M3.T2.S1 / M3.T1.S1** |

---

## Confidence Score

**10/10** for one-pass success. This is a single contiguous comment-block rewrite with: the exact
`oldText` (current lines 39–64, reproduced verbatim) and the exact `newText` (PRD §6-faithful,
reproduced verbatim) supplied for one `edit`-tool call; the authoritative source (PRD §6 + §12 + §15)
quoted in full; the gap-analysis mapping pinning this to GAP 6a+6b and explicitly fencing out GAP 6c
(T4.S2's CONCURRENCY block); the input contract verified by grep (T1/T2/T3.S1 landed — `dwell_ms`
already 30000, functions gone, only line 58 still says 10000); proof that `promote_tlist()` is a real
function (line 200) so the idempotent note is accurate; deterministic Level 1–3 validation including
23 block-scoped content proofs (13 required phrases + 10 forbidden terms), region-integrity diffs for
both untouched neighbors, a no-non-comment-line git-diff guard, a −9 line-count assertion, and an
explicit scope map separating T4.S1 from T4.S2, T3.S1, M2, and M3. No ambiguity, no hidden
dependencies, zero runtime-behavior change (comment-only). The only failure mode is textual inaccuracy,
which the Level 2 proofs fully pin down.