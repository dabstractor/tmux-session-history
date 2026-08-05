name: "P1.M1.T4.S2 — Rewrite CONCURRENCY comment section to remove activity/poller references"
description: "Rewrite the two CONCURRENCY comment regions in `scripts/session_history.sh` (gap-analysis GAP 6c + GAP 6d) so they describe the PRD §13 concurrency model with **dwell as the sole async relevance path** and ZERO references to the removed activity/poller machinery. Region A (header `# CONCURRENCY / SAFETY` block, current lines 80–95): replace the `The TWO further async paths (dwell, activity)` lead-in with `The ONE further async path (dwell)` (mirroring PRD §13 bullet 5's 'touch ONLY tlist AND take the lock ... fully serialized and can never corrupt hist/idx/current/mode'), keep the dwell bullet, and DELETE the entire 'Focused-activity detection runs entirely in that one poller' paragraph. Region B (second concurrency block at the `lock()`/`unlock()` comment, current lines 115–116): remove the clause 'and the poller fires only every ~0.5 s' from the contention note, keeping 'keypresses are ~150 ms apart, so contention is imperceptible'. Remove ALL text naming do_poller, do_activity, client_activity, the poller, ~0.5 s, 'the only resident process for activity', 'focused-activity detection', and 'See the ACTIVITY DETECTION section below'. This IS the doc update (Mode A — inline documentation on the engine file). Comment-only change; no code logic touched. Net −11 lines (header block 16→5, second block line-count-neutral). File 548 → 537."

---

## Goal

**Feature Goal**: Make the engine's CONCURRENCY header comment and the concurrency comment above
`lock()`/`unlock()` faithfully describe the PRD §13 race-safety model with **dwell as the only
asynchronous relevance path**, eliminating every residue of the removed `client_activity`-polling
activity detector (code already deleted by T1.S1/T1.S2). After the edit the concurrency comments must
read as if PRD §13 were paraphrased in the engine's own voice, with no mention of a second "activity"
async path, the poller, `~0.5 s`, or the defunct ACTIVITY DETECTION section.

**Deliverable**: An edited `scripts/session_history.sh` in which exactly two comment regions change:

1. **Region A** — inside the `# CONCURRENCY / SAFETY` header block (current lines 80–95): the
   "TWO further async paths (dwell, activity)" lead-in + the activity bullet + the entire
   "Focused-activity detection runs entirely in that one poller" paragraph are replaced by a
   single lead-in "The ONE further async path (dwell) ..." plus the existing dwell bullet.
2. **Region B** — the `# --- concurrency: serialize the critical sections` comment above
   `LOCK_FILE` (current lines 115–116): the clause "and the poller fires only every ~0.5 s" is
   removed from the contention note.

Nothing else in the file changes. The rewritten regions contain **zero** occurrences of:
`do_poller`, `do_activity`, `client_activity`, `poller`, `~0.5 s`/`0.5 s`, `~2x/sec`,
`resident process`, `Focused-activity`/`focused-activity`, `ACTIVITY DETECTION`, `alert-activity`,
`pipe-pane`.

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0 (comment edits cannot break parsing).
2. `shellcheck` reports **no new diagnostics** vs. a pre-edit baseline (a pure comment rewrite
   introduces none).
3. The edited Region A + Region B contain NONE of the forbidden terms and ALL of the required
   PRD §13 phrases (Level 2 content proofs pass).
4. `wc -l` is **pre-edit count − 11** (currently 548 → 537): Region A 16→5 lines (−11), Region B 2→2 (0).
5. The serialization explanation (current lines 64–79), the WHAT MAKES block (T4.S1), the "When a
   session closes" paragraph, the dwell bullet text, the `lock()`/`unlock()` code, and the do_init
   migration guard at lines 500–506 are all **byte-identical** to pre-edit — they are owned by this
   task (kept), T4.S1, or T2.S1 respectively.
6. No code line (any line not starting with `#`) is modified.

## User Persona (if applicable)

**Target User**: Developer / maintainer reading the engine source to understand the concurrency model
and why the timeline cannot be corrupted.

**Use Case**: A future contributor opens `scripts/session_history.sh`, reads the CONCURRENCY / SAFETY
header, and learns (a) hooks are async so prune and hook can run concurrently; (b) an exclusive flock
serializes every mutating critical section; (c) the **one** async relevance path — dwell — touches
only `tlist` and also takes the lock, so it can never corrupt `hist`/`idx`/`current`/`mode`.

**User Journey**: Reader scans the header → finds "CONCURRENCY / SAFETY" → understands the flock
serialization guarantee → reads that dwell is the sole async path and is also serialized → correctly
extends the locking discipline when adding any new background path, without ever believing a poller
or `client_activity` activity path exists.

**Pain Points Addressed**: Today the CONCURRENCY block asserts a **second** async path ("activity")
fired by a `do_poller` background process reading `#{client_activity}` ~2×/sec, and points the reader
to an "ACTIVITY DETECTION section" that **no longer exists** (T1.S1 deleted the functions). A reader
is actively misled into believing there is a resident poller process. This rewrite removes that
contradiction and mirrors PRD §13.

## Why

- **Truth-in-source.** The engine code already implements the PRD §13 model with dwell as the only
  async relevance path (T1 removed the `client_activity` poller; T2 removed the poller bootstrap +
  pipe-pane legacy; T3.S1 set the dwell fallback to 30000; T4.S1 rewrote the WHAT MAKES relevance
  bullets). The two CONCURRENCY comment regions are the last places still asserting the removed
  two-async-path model. PRD §6 + §12 are unambiguous: "Relevance comes from selection and dwell only"
  and "there is no output-activity signal."
- **Gap closure.** This task is **GAP 6c + GAP 6d** from
  `plan/001_ca41c05f3ead/architecture/gap_analysis.md`. GAP 6c (the CONCURRENCY header block) is the
  🔴 rewrite; GAP 6d (the `~0.5 s` clause in the lock comment) is the 🟡 companion fix. GAP 6a + 6b
  (the WHAT MAKES block) were **T4.S1** (already landed).
- **Mode A documentation.** The contract (point 5) designates these comment blocks as Mode A inline
  documentation — no separate docs subtask. The header IS the doc.
- **Lowest-risk change class.** Comment-only: no logic, no state, no runtime behavior change. The only
  "risk" is textual accuracy, which the Level 2 content proofs fully pin down.

## What

Replace exactly two contiguous comment regions. Nothing else in the file is touched.

### Region A — the exact region to replace (oldText), current lines 80–95

```bash
#   The TWO further async paths (dwell, activity) touch ONLY @session-history-
#   tlist, AND now also take the lock, so they are fully serialized as well:
#     • dwell — the hook arms a tmux-managed background `run-shell -b` sleep that
#       fires `dwell <session>`; it self-guards ("am I still current?").
#     • activity — fired by the background poller (do_poller) when the attached
#       client's `#{client_activity}` advances while the session stays the same
#       (the user typed / switched panes / ran a tmux command in the session
#       they're viewing). It self-guards against the LIVE attached session (not
#       @current — see do_activity), so a late fire is a clean no-op.
#   Focused-activity detection runs entirely in that one poller: it reads the
#   attached client's session + client_activity ~2x/sec, promotes the current
#   session when activity advances on an unchanged session, and re-anchors its
#   baseline whenever the session changes (so a switch can't be mistaken for
#   work). There are NO per-pane pipes and NO reader processes; the poller is the
#   only resident process for activity, and it self-terminates when toggle is
#   off. See the ACTIVITY DETECTION section below.
```

### Region A — the replacement (newText)

```bash
#   The ONE further async path (dwell) touches ONLY @session-history-tlist AND
#   also takes the lock, so it is fully serialized as well and can never corrupt
#   hist/idx/current/mode:
#     • dwell — the hook arms a tmux-managed background `run-shell -b` sleep that
#       fires `dwell <session>`; it self-guards ("am I still current?").
```

Net effect: 16 lines → 5 lines (−11). The dwell bullet is **preserved verbatim** (it accurately
describes the real `arm_dwell`/`do_dwell` functions). The line immediately above (line 79, ending
"...corrupt the timeline.)") and the blank `#` separator (line 96) are left intact.

### Region B — the exact region to replace (oldText), current lines 115–116

```bash
# section is a few tens of ms; keypresses are ~150 ms apart and the poller fires
# only every ~0.5 s, so contention is imperceptible. The lock auto-releases if a
```

### Region B — the replacement (newText)

```bash
# section is a few tens of ms; keypresses are ~150 ms apart, so contention is
# imperceptible. The lock auto-releases if a
```

Net effect: line-count-neutral (2 → 2). The removed clause is exactly
"and the poller fires only every ~0.5 s". Line 117 ("`# command dies (fd closes / process exits), so
it can never be held stale.`") is untouched and still flows correctly after "...releases if a".

### Success Criteria

- [ ] Region A lead-in reads "The ONE further async path (dwell)" (singular, dwell only).
- [ ] Region A retains the dwell bullet verbatim ("the hook arms a tmux-managed background
      `run-shell -b` sleep ... self-guards").
- [ ] Region A contains NONE of: `TWO`, `activity` (as an async-path name), `do_poller`, `do_activity`,
      `client_activity`, `poller`, `~2x/sec`, `resident process`, `Focused-activity`/`focused-activity`,
      `ACTIVITY DETECTION`, `pipe-pane`.
- [ ] Region A includes the PRD §13 phrase "can never corrupt hist/idx/current/mode".
- [ ] Region B reads "keypresses are ~150 ms apart, so contention is imperceptible" with the
      "and the poller fires only every ~0.5 s" clause gone.
- [ ] `bash -n` passes; `shellcheck` introduces no new diagnostics.
- [ ] `wc -l` = pre-edit − 11 (548 → 537).
- [ ] No non-comment line is changed; the serialization explanation (64–79), dwell bullet, WHAT MAKES
      block (T4.S1), "When a session closes" paragraph, `lock()`/`unlock()` code, and do_init
      migration guard (500–506) are byte-identical to pre-edit.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact `oldText` and `newText` for both regions (verbatim from the
current 548-line working tree) for two `edit`-tool calls; the authoritative source wording (PRD §13,
reproduced in full under Documentation); the gap-analysis mapping (GAP 6c + 6d = this task; GAP 6a/6b =
T4.S1, already landed); the input contract (T1/T2/T3.S1/T4.S1 already landed — confirmed by `wc -l`
548 and grep: WHAT MAKES block rewritten, `dwell_ms()` line 154 echoes 30000, functions gone); proof
that the dwell bullet's references are real functions (`arm_dwell` line 217, `do_dwell` line 293); the
critical scope boundary that `poller` STILL legitimately appears at lines 500–506 (the do_init
migration guard, owned by T2.S1) — so validation must be **region-scoped**, not file-wide; and
deterministic Level 1–3 validation. An implementer with zero prior knowledge can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authoritative concurrency model these comments must mirror
- docfile: PRD.md
  section: "§13. Concurrency & race safety"
  why: "PRD §13 is the single source of truth for the concurrency model. Its bullet 5 (Dwell and
        activity ... touch ONLY tlist AND now take the lock too, so they are fully serialized and can
        never corrupt hist/idx/current/mode) is the wording Region A must mirror — adapted to dwell as
        the SOLE async path per the item contract (point 3b). Its bullet 2 (Serialization. Every
        mutating command takes an exclusive flock ... keypresses are ~150 ms apart ... so lock
        contention is imperceptible) is the wording Region B must mirror — minus the poller clause."
  critical: "NOTE: PRD §13 *literally* still writes 'Dwell and activity'. The item CONTRACT (point 3b)
             and GAP 6c resolve this contradiction for the ENGINE COMMENT by writing dwell as the ONE
             async path, because T1 removed the activity code entirely (PRD §6 'selection and dwell
             only'; PRD §12 'no output-activity signal'). The contract is authoritative for the engine
             comment; PRD §13 supplies the structure and the 'touch ONLY ... AND ... lock ... fully
             serialized and can never corrupt ...' voice."

# MUST READ — why dwell is the only async path and touches only tlist
- docfile: PRD.md
  section: "§8. Dwell + §10 (Why dwell touches only the relevance list)"
  why: "Justifies that dwell is the ONE asynchronous path and is restricted to a read-modify-write of
        tlist alone so it can never corrupt critical state (hist/idx/current/mode). This is the
        authority for 'The ONE further async path (dwell) touches ONLY @session-history-tlist'. Also
        confirms arm_dwell uses `run-shell -b` (tmux-managed background job) and do_dwell self-guards
        with 'am I still current?' — the exact text the preserved dwell bullet cites."
  critical: "The preserved dwell bullet references arm_dwell()/do_dwell() — both are REAL functions
             (line 217 / line 293, grep-verified). Not dangling references."

# MUST READ — why every removed term is gone
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "Justifies deleting client_activity / poller / alert-activity / pipe-pane / 'focused activity'
        references: 'alert-activity only fires for non-focused/background windows' and 'no robust tmux
        primitive ... without heavy per-pane pipe-pane plumbing ... It is therefore not wired.
        Relevance comes from selection and dwell only.'"
  critical: "This is the authority for removing the entire 'activity' bullet and the 'Focused-activity
             detection runs entirely in that one poller' paragraph from Region A, and the
             'poller fires only every ~0.5 s' clause from Region B."

# The scoping document that enumerated this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 6 — HEADER COMMENTS describe activity as the PRIMARY signal (PRD §6)"
  why: "GAP 6c = CONCURRENCY block (THIS task, Region A). GAP 6d = the 'poller fires only every ~0.5 s'
        clause (THIS task, Region B). GAP 6a+6b = the WHAT MAKES block (T4.S1, already landed).
        Note: gap-analysis line numbers (89–104, 124) are from the pre-T1 650-line file; current file
        is 548 lines (T1 removed functions + T4.S1 shrunk WHAT MAKES), so CONCURRENCY header is now
        lines 64–95 and the lock-comment clause is now lines 115–116."
  critical: "GAP 6c + 6d is the ENTIRE scope of T4.S2. Touching GAP 6a/6b collides with T4.S1 (done)."

# The parallel sibling PRP (CONTRACT) — establishes the input state
- docfile: plan/001_ca41c05f3ead/P1M1T4S1/PRP.md
  why: "T4.S1 rewrote the WHAT MAKES block (lines 39–64 → ~39–53) and explicitly LEFT the CONCURRENCY
        block byte-identical (its scope map lists 'CONCURRENCY block (lines 73–105) activity/poller
        rewrite ❌ → T4.S2' and 'line 124 poller-fires wording ❌ → T4.S2'). Confirms the input
        contract: 'scripts/session_history.sh after T1.S1 (functions removed) and T4.S1 (WHAT MAKES
        rewritten)'. T4.S1's edit is line-count-negative (−9), which is why CONCURRENCY now starts at
        line 64 not 89/73."
  critical: "T4.S1's and T4.S2's edits are DISJOINT regions. Anchor on TEXT, not line numbers. Neither
             edit can conflict."

# The file under edit — structure & vocabulary
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash, `set -u` at line
        100 (post-T4.S1). The CONCURRENCY / SAFETY header block runs lines 64–95; the second
        concurrency comment (above LOCK_FILE/lock()/unlock()) runs lines 108–117. arm_dwell() is at
        line 217 and do_dwell() at line 293 (grep-verified), so the preserved dwell bullet's
        references are accurate."
  pattern: "Engine header comment style: lines are `#`-prefixed; nested comment body uses `#   ` (3-space
            indent); section bullets use `#     • name — ...` (5-space indent + UTF-8 bullet • U+2022 +
            em-dash — U+2014); option/function names are backtick-wrapped (`@session-history-tlist`,
            `run-shell -b`, `dwell <session>`). Match this voice exactly in the rewrite."
  gotcha: "The do_init migration guard at lines 500–506 STILL contains the word `poller` and the option
           `@session-history-poller-pid` — legitimately (it is a one-shot cleanup of leftover state
           from the removed machinery, owned by T2.S1). Those are NOT header comments and are out of
           scope. After T4.S2 a FILE-WIDE grep for `poller` STILL matches lines 500–506. Scope every
           content-proof to the two CONCURRENCY regions, never the whole file."

# Region B context — the lock() block (so the implementer sees the full sentence being rewrapped)
- file: scripts/session_history.sh
  section: "concurrency: serialize the critical sections (lines 108–118)"
  why: "Region B lives inside this block. Lines 114–117 read: '... cannot interleave. Each / section is
        a few tens of ms; keypresses are ~150 ms apart and the poller fires / only every ~0.5 s, so
        contention is imperceptible. The lock auto-releases if a / command dies ...'. Removing the
        poller clause rewraps lines 115–116 only; line 117 stays intact."
  critical: "Region B is line-count-neutral (2→2). Do NOT change line 114 or line 117 — only 115–116."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §13/§8/§12/§10 authorize this rewrite
├── README.md                   # docs (NOT this task — M3 owns README activity removal)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (548 lines, working tree, post-T4.S1)
│                                #     lines 64–95  = CONCURRENCY / SAFETY header  (THIS TASK, Region A)
│                                #       64–79       = serialization explanation (KEEP byte-identical)
│                                #       80–95       = "TWO async paths" + activity bullet + Focused-
│                                #                      activity paragraph (REWRITE — Region A)
│                                #     lines 108–117 = second concurrency block (THIS TASK, Region B)
│                                #       115–116     = poller-fires clause (REWRAP — Region B)
│                                #     lines 217, 293 = arm_dwell/do_dwell (real — dwell bullet cites them)
│                                #     lines 500–506 = do_init migration guard (T2.S1 — DO NOT TOUCH)
├── session_history.tmux        # entry point (NOT this task — M2.T1 owns activity removal)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md          # GAP 6c+6d = this task
        ├── P1M1T4S1/PRP.md                        # parallel sibling (WHAT MAKES, already landed)
        └── P1M1T4S2/
            ├── PRP.md                             # ← THIS task
            └── research/concurrency_block_analysis.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified, and ONLY the two CONCURRENCY comment
# regions (Region A lines 80–95, Region B lines 115–116). After this task the file is 537 lines (−11).
# The two CONCURRENCY regions mirror PRD §13; the rest of the file is byte-identical.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — scope boundary #1. The do_init migration guard at lines 500–506 STILL contains the word
# `poller` and the option `@session-history-poller-pid` (legitimately — it is a one-shot cleanup of
# leftover state from the removed machinery, owned by T2.S1). Those are NOT header comments and are
# out of scope. After T4.S2 a FILE-WIDE grep for `poller` STILL matches 500–506. Therefore every
# content-proof is scoped to the two CONCURRENCY regions, NOT the whole file. Asserting file-wide
# "no poller references" would FALSELY FAIL.

# CRITICAL — scope boundary #2. The serialization explanation (current lines 64–79), the dwell bullet
# (current lines 82–83, preserved verbatim in the newText), the WHAT MAKES block (T4.S1), the "When a
# session closes" paragraph, and the lock()/unlock() code are all OUT OF SCOPE and must stay
# byte-identical. The Region A edit replaces ONLY lines 80–95; the Region B edit rewraps ONLY
# lines 115–116.

# GOTCHA — line numbers drift under parallel/sequential edits. T4.S1 (already landed, −9 lines) is why
# CONCURRENCY now starts at line 64 not 89/73; T2.S1 (not yet landed) will edit do_init at ~lines
# 490–510 (the migration guard region), BELOW both of your regions, but its net line-count delta is
# unknown. ALWAYS anchor each edit on the full oldText TEXT, never on "line 80" or "line 115".
# (T4.S1's and T3.S1's PRPs mandate the same text-anchoring discipline.)

# GOTCHA — em-dash and bullet characters. The engine header uses the UTF-8 em-dash '—' (U+2014) and
# the bullet '•' (U+2022), NOT ASCII '-' or '*'. The Region A newText preserves the dwell bullet line
# verbatim, so it already uses them. The Region B newText contains no bullet/em-dash. Do not
# substitute ASCII glyphs.

# GOTCHA — the comment-wrapping column. Existing header comment lines wrap at ~72–78 chars of text
# (after the leading '#'). The Region B newText is rewrapped to ~73 chars on line 115 to match its
# neighbors. Region A newText lines are ~70–74 chars, consistent with the surrounding block.

# GOTCHA — `set -u` is at line 100 (post-T4.S1). Comment edits do not touch code, so `set -u` is
# irrelevant to this task — but be aware the CONCURRENCY header block ENDS at line 95, then a blank
# `#` (96), then `# Global state...` (97), blank (98/99), `set -u` (100). Do not let the Region A
# edit bleed past line 95 into the blank separator or the Global state line.

# GOTCHA — arm_dwell()/do_dwell() are referenced by the PRESERVED dwell bullet. They are REAL
# functions (line 217 / line 293, grep-verified; do_dwell dispatched at line 538). The
# "am I still current?" self-guard matches PRD §8/§9 verbatim. Do not strip the dwell bullet fearing
# it is dead code — it is the accurate description of the one remaining async path.

# GOTCHA — 'See the ACTIVITY DETECTION section below.' (line 95) points to a section that NO LONGER
# EXISTS (T1 deleted the do_activity/do_poller functions). Removing that sentence is a correctness
# fix, not just a cosmetic one — it was a dangling forward reference.
```

## Implementation Blueprint

### Data models and structure

None. This is a pure comment rewrite. No data models, schemas, types, options, or code logic change.
The only "data" is the human-readable prose of two comment regions.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE a pre-edit baseline (no source edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_before_t4s2.txt 2>&1; echo "baseline exit: $?"
  - RUN: before=$(wc -l < scripts/session_history.sh); echo "pre-edit lines = $before"   # expect 548
  - RUN: sed -n '64,79p' scripts/session_history.sh > /tmp/serial_before.txt      # serialization expl (KEEP)
  - RUN: sed -n '82,83p' scripts/session_history.sh > /tmp/dwell_bullet_before.txt # dwell bullet (KEEP verbatim)
  - RUN: sed -n '/^# When a session closes/,/^# CONCURRENCY/p' scripts/session_history.sh > /tmp/close_before.txt
  - RUN: sed -n '/^# WHAT MAKES A SESSION "RELEVANT"/,/^# When a session closes/p' scripts/session_history.sh > /tmp/whatmakes_before.txt
  - RUN: sed -n '108,118p' scripts/session_history.sh > /tmp/lockblock_before.txt  # includes line 115–116 (Region B)
  - RUN: sed -n '118,130p' scripts/session_history.sh > /tmp/lockcode_before.txt   # LOCK_FILE/lock()/unlock() (KEEP)
  - WHY: this task's shellcheck gate is "no NEW diagnostics"; the file already carries pre-existing SC
         warnings (gap analysis did not clean them). The seven region snapshots are regression guards so
         you can prove you edited ONLY the two CONCURRENCY regions (80–95 and 115–116) and nothing else.

Task 2: REPLACE Region A — the "TWO async paths" + activity bullet + Focused-activity paragraph
         (header block, current lines 80–95)
  - USE the `edit` tool ONCE with oldText = the current lines 80–95 block (reproduced verbatim in the
    "Region A — the exact region to replace" section of this PRP) and newText = the 5-line replacement
    (reproduced verbatim in the "Region A — the replacement" section).
  - ANCHOR on the full block TEXT (from `#   The TWO further async paths (dwell, activity) ...` through
    the line ending `... See the ACTIVITY DETECTION section below.`), NOT on line numbers.
  - PRESERVE the line immediately above (line 79, ending "...corrupt the timeline.)") and the blank `#`
    separator below (line 96). Do NOT delete either.
  - ENSURE the newText preserves the dwell bullet verbatim (em-dash `—`, bullet `•`, backticks around
    `run-shell -b` and `dwell <session>`, the "am I still current?" guard).

Task 3: REPLACE Region B — the poller-fires clause (lock block, current lines 115–116)
  - USE the `edit` tool ONCE with oldText = current lines 115–116 (reproduced verbatim in the "Region B
    — the exact region to replace" section) and newText = the 2-line rewrap (reproduced verbatim in the
    "Region B — the replacement" section).
  - ANCHOR on the full two-line TEXT (from `# section is a few tens of ms; keypresses are ~150 ms apart
    and the poller fires` through `# only every ~0.5 s, so contention is imperceptible. The lock
    auto-releases if a`), NOT on line numbers.
  - PRESERVE line 114 (ending "...cannot interleave. Each") and line 117 ("`# command dies (fd closes
    / process exits), so it can never be held stale.`") byte-for-byte.

Task 4: VERIFY parse + lint delta + line count + region integrity (no edits)
  - RUN: bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"   # expect PARSE OK
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after_t4s2.txt 2>&1
  - RUN: diff <(sort /tmp/sc_before_t4s2.txt) <(sort /tmp/sc_after_t4s2.txt)         # expect empty
  - RUN: after=$(wc -l < scripts/session_history.sh); echo "post-edit lines = $after (expect before - 11)"
         # expect 548 - 11 = 537. Delta MUST be exactly -11 (Region A 16->5; Region B 2->2). Any other
         # delta = wrong number of lines edited in Region A — re-check the newText line count.
  - RUN: diff /tmp/serial_before.txt <(sed -n '64,79p' scripts/session_history.sh)   # expect empty
         NOTE: if line numbers shifted, re-extract by TEXT: sed -n '/^# CONCURRENCY \/ SAFETY/,/^#   The ONE further/p'
  - RUN: diff /tmp/dwell_bullet_before.txt <(sed -n '/• dwell — the hook arms/,/self-guards/p' scripts/session_history.sh)
         # expect empty (dwell bullet preserved verbatim)
  - RUN: diff /tmp/close_before.txt <(sed -n '/^# When a session closes/,/^# CONCURRENCY/p' scripts/session_history.sh)
         # expect empty
  - RUN: diff /tmp/whatmakes_before.txt <(sed -n '/^# WHAT MAKES A SESSION "RELEVANT"/,/^# When a session closes/p' scripts/session_history.sh)
         # expect empty (T4.S1 block untouched)
  - RUN: diff /tmp/lockcode_before.txt <(sed -n '/^LOCK_FILE=/,/^unlock()/p' scripts/session_history.sh)
         # expect empty (lock()/unlock() code untouched)

Task 5: VERIFY region-scoped content (Level 2 — the heart of this task)
  - RUN the Level 2 forbidden-terms + required-phrases block. EXPECTED: all OK (see Validation Loop).
```

### Implementation Patterns & Key Details

```bash
# Region A sits in the CONCURRENCY / SAFETY header block. Its neighbors:
#
#   ... (WHAT MAKES block — T4.S1, rewritten)          <- lines ~39–53
#   #                                                   <- blank separator (KEEP)
#   # When a session closes it is removed ...           <- lines ~55–60, PRD-correct (KEEP)
#   #                                                   <- blank separator (KEEP)
#   # CONCURRENCY / SAFETY                              <- line 64, block heading (KEEP)
#   #   IMPORTANT: the `run-shell` ... ASYNCHRONOUS ... <- lines 65–79, serialization expl (KEEP)
#   #   ... corrupt the timeline.)                      <- line 79 (KEEP — Region A starts AFTER this)
#   #   The ONE further async path (dwell) ...          <- Region A newText (5 lines)
#   #     • dwell — the hook arms ...                   <- (dwell bullet preserved verbatim)
#   #                                                   <- blank separator (KEEP)
#   # Global state, single-client assumption. ...       <- line 97 (KEEP)
#
# Region B sits in the second concurrency block above lock()/unlock(). Its neighbors:
#
#   # --- concurrency: serialize the critical sections --------   <- line 108 (KEEP)
#   # A `run-shell` inside a tmux hook is ASYNCHRONOUS ...        <- lines 109–114 (KEEP)
#   # whole critical section ... cannot interleave. Each          <- line 114 (KEEP — Region B after)
#   # section is a few tens of ms; keypresses are ~150 ms apart, so contention is   <- Region B newText
#   # imperceptible. The lock auto-releases if a                  <- Region B newText
#   # command dies (fd closes / process exits), so it can never be held stale.      <- line 117 (KEEP)
#   LOCK_FILE="${SHT_LOCK:-...}"                                  <- line 118 (KEEP — code)
#   lock()   { exec 9>"$LOCK_FILE"; flock 9; }                   <- (KEEP — code)

# WHY each forbidden term is removed (PRD authority):
#   'TWO further async paths (dwell, activity)' -> 'ONE ... (dwell)'
#     -> T1 removed the activity path entirely (do_activity/do_poller deleted). PRD §6: "selection and
#        dwell only". GAP 6c / item contract point 3b mandate singular dwell.
#   do_poller / do_activity / client_activity / poller / ~2x/sec / 'only resident process for activity'
#     -> PRD §12: "It is therefore not wired." These described the removed poller machinery.
#   'Focused-activity detection runs entirely in that one poller ...' (whole paragraph)
#     -> residue of the removed poller; PRD §13's bullet 5 keeps only the dwell/tlist serialization
#        note, not poller mechanics.
#   'See the ACTIVITY DETECTION section below.'
#     -> DANGLING forward reference: T1 deleted the ACTIVITY DETECTION section (the functions). Removing
#        it is a correctness fix.
#   'and the poller fires only every ~0.5 s' (Region B)
#     -> GAP 6d: remove this clause; the contention note must read "keypresses are ~150 ms apart, so
#        contention is imperceptible" (PRD §13 bullet 2 wording, minus the poller cadence).

# WHY each required phrase is present (PRD §13 authority):
#   'The ONE further async path (dwell)'
#     -> item contract point 3b; mirrors PRD §13 bullet 5 with dwell as sole path.
#   'touches ONLY @session-history-tlist AND also takes the lock'
#     -> PRD §13 bullet 5: "touch ONLY tlist AND now take the lock too"; PRD §8/§10 "dwell touches only
#        the relevance list".
#   'so it is fully serialized as well and can never corrupt hist/idx/current/mode'
#     -> PRD §13 bullet 5 verbatim tail: "fully serialized and can never corrupt hist/idx/current/mode".
#   dwell bullet verbatim
#     -> describes real arm_dwell()/do_dwell() (lines 217/293); matches PRD §8 arm_dwell + §9 firing.
#   'keypresses are ~150 ms apart, so contention is imperceptible' (Region B)
#     -> PRD §13 bullet 2 tail wording; GAP 6d mandates keeping this after removing the poller clause.
```

### Integration Points

```yaml
DATABASE:
  - none. Pure comment edit; no DB, no state.

CONFIG (tmux global user options):
  - none changed. The comments MENTION @session-history-tlist but do not read or write any option.

ROUTES / DISPATCH:
  - none changed. No subcommand, no case branch, no function is touched. This is header prose only.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit shellcheck baseline + line count (run BEFORE editing):
shellcheck scripts/session_history.sh > /tmp/sc_before_t4s2.txt 2>&1; echo "baseline exit: $?"
before=$(wc -l < scripts/session_history.sh); echo "pre-edit lines = $before"   # expect 548

# 1. Parse check (run AFTER both edits):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0).

# 2. Lint delta (run AFTER editing):
shellcheck scripts/session_history.sh > /tmp/sc_after_t4s2.txt 2>&1
diff <(sort /tmp/sc_before_t4s2.txt) <(sort /tmp/sc_after_t4s2.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: empty diff (a pure comment rewrite introduces no shellcheck diagnostic).

# 3. Line-count delta (run AFTER editing):
after=$(wc -l < scripts/session_history.sh)
echo "post-edit line count = $after (expect $((before - 11)))"
# Expected: after == before - 11  (548 -> 537). Region A is 16->5 (-11); Region B is 2->2 (0).
# Any other delta = wrong number of lines edited in Region A — re-check the newText line count.
```

### Level 2: Region-Scoped Content Proofs (the heart of this task)

These proofs are scoped to **the two CONCURRENCY regions only** (Region A = header lines 80–95
pre-edit / the edited region post-edit; Region B = lock-comment lines 115–116 pre-edit / edited
post-edit). They are deliberately NOT file-wide, because the do_init migration guard (T2.S1) still
legitimately contains `poller` at lines 500–506.

```bash
# Extract the edited CONCURRENCY header block (from the heading through the Global state line).
HEADER=$(sed -n '/^# CONCURRENCY \/ SAFETY/,/^# Global state/p' scripts/session_history.sh | sed '$d')

# Extract the edited lock concurrency block (from the '--- concurrency ---' banner through LOCK_FILE=).
LOCKBLK=$(sed -n '/^# --- concurrency: serialize the critical sections/,/^LOCK_FILE=/p' scripts/session_history.sh | sed '$d')

pass=0; fail=0
require_h() { if printf '%s' "$HEADER" | grep -qF -- "$1"; then echo "OK   $2"; pass=$((pass+1)); else echo "FAIL $2  (missing: '$1')"; fail=$((fail+1)); fi; }
forbid_h()  { if printf '%s' "$HEADER" | grep -qiF -- "$1"; then echo "FAIL $2  (forbidden term present: '$1')"; fail=$((fail+1)); else echo "OK   $2"; pass=$((pass+1)); fi; }
require_l() { if printf '%s' "$LOCKBLK" | grep -qF -- "$1"; then echo "OK   $2"; pass=$((pass+1)); else echo "FAIL $2  (missing: '$1')"; fail=$((fail+1)); fi; }
forbid_l()  { if printf '%s' "$LOCKBLK" | grep -qiF -- "$1"; then echo "FAIL $2  (forbidden term present: '$1')"; fail=$((fail+1)); else echo "OK   $2"; pass=$((pass+1)); fi; }

# --- Region A (CONCURRENCY / SAFETY header) REQUIRED PRD §13 phrases:
require_h 'CONCURRENCY / SAFETY'                  'Region A: heading preserved'
require_h 'The ONE further async path (dwell)'    'Region A: singular dwell lead-in'
require_h 'touches ONLY @session-history-tlist'   'Region A: tlist-only (PRD §13 b5 / §8)'
require_h 'also takes the lock'                   'Region A: dwell takes the lock (PRD §13 b5)'
require_h 'can never corrupt hist/idx/current/mode' 'Region A: serialization guarantee (PRD §13 b5)'
require_h '• dwell — the hook arms'               'Region A: dwell bullet preserved'
require_h 'run-shell -b'                          'Region A: tmux-managed bg job (PRD §8)'
require_h 'am I still current?'                   'Region A: dwell self-guard (PRD §9)'
#   (the serialization explanation above Region A must still be intact:)
require_h 'ASYNCHRONOUS'                          'Region A: serialization expl intact (kept)'
require_h 'exclusive flock'                       'Region A: flock expl intact (kept)'

# --- Region A FORBIDDEN removed-model terms (none may survive):
forbid_h 'TWO further async paths'   'Region A: no "TWO async paths" framing'
forbid_h 'activity'                  'Region A: no activity-path name (case-insensitive)'
forbid_h 'do_poller'                 'Region A: no do_poller reference'
forbid_h 'do_activity'               'Region A: no do_activity reference'
forbid_h 'client_activity'           'Region A: no client_activity reference'
forbid_h 'poller'                    'Region A: no poller reference'
forbid_h '2x/sec'                    'Region A: no poller cadence residue'
forbid_h 'resident process'          'Region A: no "resident process" residue'
forbid_h 'Focused-activity'          'Region A: no focused-activity paragraph'
forbid_h 'ACTIVITY DETECTION'        'Region A: no dangling section forward-ref'
forbid_h 'pipe-pane'                 'Region A: no pipe-pane residue'
forbid_h 'alert-activity'            'Region A: no alert-activity residue'

# --- Region B (lock concurrency block) REQUIRED + FORBIDDEN:
require_l 'keypresses are ~150 ms apart, so contention is' 'Region B: contention note (poller clause removed)'
require_l 'imperceptible'           'Region B: "imperceptible" retained'
require_l 'auto-releases'           'Region B: lock auto-release note intact'
require_l 'flock'                   'Region B: flock explanation intact'
forbid_l  'poller fires'            'Region B: no "poller fires" clause'
forbid_l  '0.5 s'                   'Region B: no ~0.5 s cadence'

echo "---"; echo "PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] && echo "ALL CONCURRENCY CONTENT PROOFS OK" || { echo "SOME PROOFS FAILED"; exit 1; }
# Expected: PASS=27 FAIL=0.

# File-wide proofs for terms that go FULLY gone after this task (these are safe file-wide because
# every occurrence was inside my two regions — unlike 'poller', which survives at 500–506):
for t in 'client_activity' 'Focused-activity' 'focused-activity' '0.5 s' 'resident process' \
         'do_poller' 'do_activity' 'ACTIVITY DETECTION' '2x/sec' 'alert-activity' 'pipe-pane'; do
  if grep -qiF -- "$t" scripts/session_history.sh; then echo "FILE-WIDE FAIL: '$t' still present"; else echo "FILE-WIDE OK: '$t' gone"; fi
done
# Expected: all OK (gone file-wide). NOTE: do NOT run this for 'poller' — it survives at lines 500–506
#           (do_init migration guard, T2.S1). Asserting 'poller' file-wide would FALSELY FAIL.
```

### Level 3: Region Integrity & Scope Boundary (System Validation)

```bash
# A. Regions OUTSIDE my two edits are byte-identical to pre-edit (regression guards).

# A.1 — serialization explanation (header lines 64–79, KEEP):
diff /tmp/serial_before.txt <(sed -n '/^# CONCURRENCY \/ SAFETY/,/corrupt the timeline\./p' scripts/session_history.sh)
# Expected: empty diff. (If line numbers shifted, the TEXT range '# CONCURRENCY / SAFETY' .. 'corrupt the timeline.' is stable.)

# A.2 — dwell bullet preserved verbatim:
diff /tmp/dwell_bullet_before.txt <(sed -n '/• dwell — the hook arms/,/self-guards/p' scripts/session_history.sh)
# Expected: empty diff.

# A.3 — "When a session closes" paragraph (PRD-correct; KEEP):
diff /tmp/close_before.txt <(sed -n '/^# When a session closes/,/^# CONCURRENCY/p' scripts/session_history.sh)
# Expected: empty diff.

# A.4 — WHAT MAKES block (T4.S1; KEEP):
diff /tmp/whatmakes_before.txt <(sed -n '/^# WHAT MAKES A SESSION "RELEVANT"/,/^# When a session closes/p' scripts/session_history.sh)
# Expected: empty diff.

# A.5 — lock()/unlock() code + surrounding lock comment (KEEP except the 115–116 rewrap):
#   Compare everything EXCEPT the two rewrapped lines. Simplest: confirm LOCK_FILE/lock/unlock unchanged:
diff /tmp/lockcode_before.txt <(sed -n '/^LOCK_FILE=/,/^unlock()/p' scripts/session_history.sh)
# Expected: empty diff.

# B. No CODE line changed. Every changed line in the diff must begin with '#':
git diff scripts/session_history.sh | grep -E '^[-+]' | grep -vE '^([-+]{3}|[-+]#)'
# Expected: NO output. Any line here is a NON-comment change = over-reach; revert it.

# C. The git diff is two contiguous hunks (Region A + Region B):
git diff --stat scripts/session_history.sh
# Expected: a single file, Region A ~+5/-16 and Region B ~+2/-2  => net ~+7/-18 (−11).

# D. The do_init migration guard (T2.S1 territory) is untouched — proves you did NOT over-reach:
sed -n '/One-shot migration guard/,/machinery is gone/p' scripts/session_history.sh
# Expected: the migration-guard comment is intact (it still contains the word 'poller' — that is CORRECT;
#           it is a one-shot cleanup of leftover state, owned by T2.S1, NOT a header comment).

# E. 'poller' file-wide count AFTER edit (informational — must be >= the do_init guard's count):
grep -c 'poller' scripts/session_history.sh
# Expected: a small positive number (the do_init migration guard at ~500–506 legitimately uses 'poller').
#           This is NOT a failure — it proves you correctly left T2.S1's region alone.
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Prove the rewritten CONCURRENCY block is internally consistent with the rest of the engine.

# D.1 — the dwell bullet the comment preserves accurately describes the real functions:
sed -n '/^arm_dwell()/,/^}/p' scripts/session_history.sh | grep -q 'run-shell -b' && echo "OK arm_dwell uses run-shell -b" || echo "FAIL"
sed -n '/^do_dwell()/,/^}/p' scripts/session_history.sh | grep -q 'current' && echo "OK do_dwell checks current (self-guard)" || echo "FAIL"
# Expected: both OK. The comment's "run-shell -b" + "am I still current?" accurately reflect the code.

# D.2 — the concurrency model is coherent: every mutating subcommand really does lock. Confirm the
#       dispatch case still wraps each mutating command in lock/unlock (this is the behavior the
#       comment promises — verify the comment is not lying):
grep -nE '\)\s+lock;' scripts/session_history.sh | head
# Expected: lines for hook, prune, maintain, init, back, forward, toggle, pick, dwell, reset — all
#           wrapped in `lock; ... unlock`. The comment's "Every mutating command takes an exclusive
#           flock" is therefore accurate. (No edit to these lines — informational consistency check.)

# D.3 — PRD §13 cross-check: the comment's 'can never corrupt hist/idx/current/mode' enumerates the
#       same four critical-state options PRD §3/§13 names. Confirm they all still exist as options:
for opt in hist idx current mode tlist; do
  printf '%-8s engine-comment=%s\n' "$opt" "$(printf '%s' "$HEADER" | grep -c "@session-history-$opt")"
done
# Expected: hist/idx/current/mode each >=1 in the header (the 'can never corrupt' line names them);
#           tlist >=1 (the 'touches ONLY ... tlist' line). Vocabulary consistent with PRD §3.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_t4s2.txt` (sorted diff empty).
- [ ] `wc -l scripts/session_history.sh` is **pre-edit count − 11** (548 → 537).
- [ ] Region B is line-count-neutral (2→2); Region A is 16→5.

### Feature Validation

- [ ] Level 2 content proofs report `PASS=27 FAIL=0` (Region A: 10 required + 11 forbidden; Region B:
      4 required + 2 forbidden).
- [ ] File-wide proofs: `client_activity`, `Focused-activity`, `0.5 s`, `resident process`, `do_poller`,
      `do_activity`, `ACTIVITY DETECTION`, `2x/sec`, `alert-activity`, `pipe-pane` all **gone file-wide**.
- [ ] Region A reads "The ONE further async path (dwell)" and includes "can never corrupt hist/idx/current/mode".
- [ ] Region A's dwell bullet is preserved verbatim ("the hook arms a tmux-managed background
      `run-shell -b` sleep ... am I still current?").
- [ ] Region B reads "keypresses are ~150 ms apart, so contention is imperceptible" (poller clause gone).

### Code Quality Validation

- [ ] The edit touches ONLY comment lines (`git diff | grep -E '^[-+]' | grep -vE '^([-+]{3}|[-+]#)'` → empty).
- [ ] The serialization explanation (header 64–79) is byte-identical to pre-edit (diff empty).
- [ ] The dwell bullet is byte-identical to pre-edit (diff empty).
- [ ] The "When a session closes" paragraph is byte-identical to pre-edit (diff empty).
- [ ] The WHAT MAKES block (T4.S1) is byte-identical to pre-edit (diff empty).
- [ ] `LOCK_FILE`/`lock()`/`unlock()` code is byte-identical to pre-edit (diff empty).
- [ ] The do_init migration guard (~lines 500–506) is untouched (still contains `poller` legitimately).
- [ ] The rewrite uses the engine's exact comment glyphs (UTF-8 em-dash `—`, bullet `•`) — preserved in
      the dwell bullet; no ASCII substitution.

### Documentation & Deployment

- [ ] This IS the doc update (Mode A — inline documentation on the engine file). No separate docs file.
- [ ] No README change (README activity removal = M3.T1/T3; README default = M3.T2.S1).
- [ ] No entry-point change (session_history.tmux = M2.T1).
- [ ] No new environment variables or options.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT touch the do_init migration guard** (~lines 500–506, "One-shot migration guard ... left a
  poller process ... tracked in @session-history-poller-pid ... That machinery is gone"). It legitimately
  references `poller` as a one-shot cleanup of leftover state from the removed machinery, and is owned by
  **T2.S1**. Editing it here is a scope collision. After T4.S2 a file-wide `grep poller` STILL matches it.
- ❌ **Do NOT edit the serialization explanation** (header lines 64–79, "IMPORTANT: the run-shell ... is
  ASYNCHRONOUS ... exclusive flock ... corrupt the timeline.)"). The contract (point 3a) says KEEP it.
- ❌ **Do NOT modify the dwell bullet text.** It is preserved VERBATIM in the Region A newText. Only the
  lead-in ("TWO ... (dwell, activity)" → "ONE ... (dwell)") and the removed activity bullet + Focused-
  activity paragraph change. If your edit alters the dwell bullet's wording, you have over-reached.
- ❌ **Do NOT touch the WHAT MAKES block** (T4.S1) or the "When a session closes" paragraph. Both are
  already PRD-correct / owned elsewhere. Leave them byte-identical.
- ❌ **Do NOT change any non-comment line**, including `LOCK_FILE=`, `lock()`, `unlock()`. This is a
  header/comment-prose rewrite. Any `git diff` line not starting with `#` (excluding `---`/`+++`) is over-reach.
- ❌ **Do NOT key either edit on hard line numbers** (80–95, 115–116). Anchor on the full block TEXT.
  T4.S1 (already landed, −9) shifted these regions up; T2.S1 (not yet landed) will shift lines below
  `set -u`. Text-matching is robust to all of it.
- ❌ **Do NOT substitute ASCII `-`/`*` for the em-dash `—`/bullet `•`** in the dwell bullet. The engine
  header is UTF-8 and uses those glyphs; ASCII substitution breaks visual consistency.
- ❌ **Do NOT assert file-wide "no poller references" as a success criterion.** That would FALSELY FAIL —
  the do_init migration guard legitimately still has `poller`. Scope every `poller` proof to the two
  CONCURRENCY regions. (Terms like `client_activity` / `0.5 s` / `Focused-activity` ARE safe to assert
  file-wide — their only occurrences are inside your regions.)
- ❌ **Do NOT add or remove the blank `#` separator lines** around the CONCURRENCY block (line 96 below,
  and the separator above at the end of the "When a session closes" paragraph). Keep both.
- ❌ **Do NOT "also fix" `session_history.tmux` or `README.md`** activity references. Those are separate
  work items (M2.T1.S2, M3.T1.S1/S2, M3.T2.S2). This task is the two engine CONCURRENCY comments ONLY.

---

## Scope Boundaries (one-screen reference)

| Item | This task (T4.S2)? | Owner |
|------|:---:|-------|
| Region A: "TWO async paths" → "ONE async path (dwell)" lead-in (header ~80–81) | ✅ | T4.S2 |
| Region A: delete activity bullet (header ~84–88) | ✅ | T4.S2 |
| Region A: delete "Focused-activity detection ... poller" paragraph (header ~89–95) | ✅ | T4.S2 |
| Region A: add "can never corrupt hist/idx/current/mode" (PRD §13 b5 tail) | ✅ | T4.S2 |
| Region A: dwell bullet preserved verbatim (~82–83) | ✅ (preserve) | T4.S2 |
| Region B: remove "and the poller fires only every ~0.5 s" clause (lock ~115–116) | ✅ | T4.S2 (GAP 6d) |
| Serialization explanation (header 64–79) | ❌ | untouched (preserve byte-identical) |
| WHAT MAKES block | ❌ | **T4.S1** (already landed) |
| "When a session closes" paragraph | ❌ | untouched (preserve byte-identical) |
| `LOCK_FILE` / `lock()` / `unlock()` code | ❌ | untouched (preserve byte-identical) |
| do_init migration guard (~500–506, contains `poller`) | ❌ | **T2.S1** (do NOT touch) |
| `dwell_ms()` default (line 154 = 30000) | ❌ | **T3.S1** (already landed) |
| `session_history.tmux` focused-activity comment / bootstrap | ❌ | **M2.T1.S2** |
| `README.md` activity prose / Options table | ❌ | **M3.T1 / M3.T2** |

---

## Confidence Score

**10/10** for one-pass success. This is a two-region comment rewrite with: the exact `oldText` and
`newText` for both regions (verbatim from the current 548-line working tree) supplied for two
`edit`-tool calls; the authoritative source (PRD §13 + §8 + §12) quoted in full, with an explicit note
that the contract overrides PRD §13's literal "Dwell and activity" wording for the engine comment;
the gap-analysis mapping pinning this to GAP 6c (Region A) + GAP 6d (Region B) and fencing out GAP 6a/6b
(T4.S1, done); the input contract verified by `wc -l` 548 and grep (WHAT MAKES rewritten, dwell_ms 30000,
functions gone); proof that `arm_dwell()`/`do_dwell()` are real functions (217/293) so the preserved
dwell bullet is accurate; the critical scope boundary that `poller` survives at the do_init migration
guard (500–506, T2.S1) — so all content proofs are region-scoped while the truly-gone terms
(`client_activity`/`0.5 s`/`Focused-activity`/etc.) are also safe file-wide; deterministic Level 1–3
validation including 27 region-scoped content proofs, region-integrity diffs for every untouched
neighbor, a no-non-comment-line git-diff guard, a −11 line-count assertion, and an explicit scope map
separating T4.S2 from T4.S1, T2.S1, T3.S1, M2, and M3. No ambiguity, no hidden dependencies, zero
runtime-behavior change (comment-only). The only failure mode is textual inaccuracy, which the Level 2
proofs fully pin down.