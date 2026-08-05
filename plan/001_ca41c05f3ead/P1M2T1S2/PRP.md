name: "P1.M2.T1.S2 — Remove focused-activity comment block and rewrite bootstrap comment"
description: "Two-region comment edit to `session_history.tmux` (lines 70–83): (a) DELETE the entire `# --- focused-activity detection (only with toggle bound) ---` comment block (lines 70–77) that describes `client_activity`/poller/`alert-activity` — PRD §12 says output-activity is not wired and §9 forbids extra hooks with toggle; (b) REWRITE the bootstrap comment (lines 79–83) which falsely claims `do_init` reads `@session-history-toggle-enabled` to start a poller — that is doubly obsolete (P1.M1.T2 removed `do_start_poller`; `do_init` no longer reads the toggle flag). New comment: init runs LAST because it seeds initial state and must see hooks/keys/options already wired; it starts no background processes. KEEP the `tmux run-shell \"${SCRIPT} init\"` call (line 84) and the epilogue (85–88) byte-for-byte. Executed as ONE combined exact-text replacement (oldText = lines 70–83, the focused block + blank + bootstrap comment; newText = the 5-line rewritten bootstrap comment) because the region is contiguous and the header line makes it globally unique. Net −9 lines (88 → 79). No external docs needed (internal comment cleanup). Sibling entry-point task S1 edits line 55 ABOVE this region (±0 lines) — no collision."

---

## Goal

**Feature Goal**: Remove all activity-detection / poller references from the
`session_history.tmux` entry point's inline comments and replace the obsolete
"poller race" bootstrap rationale with an accurate one. After this edit the
entry script's comments must reflect the PRD's selection-and-dwell relevance
model (§12: output-activity is not wired; §9: no extra hooks with toggle) and
the actual current behavior of `do_init` (state seed only — no poller start).

**Deliverable**: An edited `session_history.tmux` in which:
1. The `# --- focused-activity detection (only with toggle bound) ---` comment
   block (old lines 70–77) is **gone entirely**.
2. The bootstrap comment (old lines 79–83) is **rewritten** to say `init` runs
   LAST because it seeds initial state and must see hooks/keys/options in place;
   it contains **no** mention of the poller, the toggle-enabled flag, racing, or
   "focused-activity".
3. The `tmux run-shell "${SCRIPT} init"` call (old line 84) and the no-op
   epilogue (old lines 85–88) are **byte-identical** to pre-edit.

**Success Definition**:
1. `bash -n session_history.tmux` exits 0.
2. `shellcheck session_history.tmux` reports **no new diagnostics** vs. a
   pre-edit baseline.
3. `grep -niE 'poller|client_activity|alert-activity|focused-activity' session_history.tmux`
   → **zero matches** (all targeted tokens are gone).
4. `grep -ni 'activity' session_history.tmux` → exactly **one** match, the
   line-12 negation `# extra hooks, no background sleepers, no monitor-activity.`
   (a correct "absence" statement, consistent with PRD §9 — KEEP).
5. The line `tmux run-shell "${SCRIPT} init"` is present and **byte-identical**
   (the init call is preserved).
6. The no-op epilogue (`# The bind lines above short-circuit ...` … `:`) is
   byte-identical to pre-edit.
7. File line count = **79** (was 88; net **−9** lines: oldText 14 lines →
   newText 5 lines).

## User Persona (if applicable)

**Target User**: A developer (or future maintainer) reading the entry-point
file to understand the plugin's load sequence.

**Use Case**: The reader scans `session_history.tmux` top-to-bottom to learn
what runs at load time and in what order. The comments must tell a single,
true story: hooks → keys → dwell default → toggle flag → `init` LAST (state
seed).

**User Journey**: Reader opens the file → sees the hook block (§16) → sees the
key bindings → sees the dwell default → sees the toggle block → reads a
bootstrap comment that correctly explains `init` seeds state and must run last
→ finds **no** confusing reference to a poller that no longer exists.

**Pain Points Addressed**: Today the file carries a focused-activity comment
block describing `client_activity`, a poller, and `alert-activity` — all of
which PRD §12 says are **not wired** — and a bootstrap comment whose rationale
("do_init reads the toggle flag to start the poller") is **false** post-P1.M1.T2
(`do_init` no longer reads the flag or starts any poller). A reader who trusts
these comments will misunderstand the relevance model and the load ordering.

## Why

- **Spec compliance (§12).** PRD §12 is explicit: output-activity promotion via
  `alert-activity` is *"unusable"* and *"It is therefore not wired."* The
  focused-activity comment block (70–77) directly contradicts this — it
  describes the poller as the relevance list's "PRIMARY signal." It must go.
- **Spec compliance (§9).** PRD §9: with toggle disabled the user *"pays
  nothing for the toggle machinery — no background timers, no relevance
  bookkeeping, no extra hooks."* The deleted block's claim that *"the poller
  promotes the current session ... no extra hook is needed here"* describes
  machinery that §9 and §12 both reject.
- **Accuracy vs the engine (the bootstrap comment).** The old bootstrap comment
  (79–83) states `do_init` *"reads @session-history-toggle-enabled ... to
  decide whether to start the focused-activity poller."* Verified against the
  current `do_init` (`scripts/session_history.sh:471`): it does **neither** —
  it seeds history state when empty and runs a one-shot stale-poller kill
  (migration guard). It starts **no** background process. The comment must be
  rewritten to describe what `init` actually does and why ordering matters.
- **Decomposition ownership (GAP 8b/8c).** This is exactly GAP 8b (delete
  focused-activity block) and GAP 8c (rewrite bootstrap comment) of
  `architecture/gap_analysis.md:148–149`. The entry point never started the
  poller directly (that was `do_init → do_start_poller`, removed in P1.M1.T2);
  this task finishes removing the *narrative* of activity detection from the
  load sequence.
- **Mode A documentation.** This **is** the doc update for the entry point —
  inline comments in the entry-point file. No separate docs subtask.

## What

A single exact-text replacement in `session_history.tmux`. The replacement
removes a 14-line region (the focused-activity block + the blank line + the old
bootstrap comment) and inserts a 5-line rewritten bootstrap comment in its
place. The `tmux run-shell "${SCRIPT} init"` call that immediately follows is
untouched.

### The region being replaced (old lines 70–83 — 14 lines)

```bash
# --- focused-activity detection (only with toggle bound) --------------------
# The relevance list's PRIMARY signal is input in the session you are viewing —
# typing, pane/window switches, or any tmux command. tmux's alert-activity cannot
# see the focused window, so the engine watches the attached client's
# client_activity timestamp instead (see scripts/session_history.sh). The
# poller promotes the current session whenever that timestamp advances while the
# session stays the same; no extra hook is needed here. With toggle unbound the
# poller is never started: no resident processes.

# Bootstrap the engine LAST, after every option/hook/key above is in place —
# do_init reads @session-history-toggle-enabled (set by the toggle block) to
# decide whether to start the focused-activity poller, so it must run after that
# flag is set (calling it earlier raced the async run-shell ahead of the toggle
# block and left the poller unset on reload).
```

### The replacement (newText — 5 lines)

```bash
# Bootstrap the engine LAST, after every option/hook/key above is in place.
# do_init seeds the initial state (the current/attached session) into the
# history options when they are empty — a one-shot, idempotent seed that must
# run after the full configuration is wired (hooks, keys, options). It starts
# no background processes, so its only requirement is that ordering.
```

### What is NOT changed (byte-identical, preserved)

- Old line 69 (blank) — the separator after the `[ -n "$pick_key" ] ...` binding.
- Old line 84: `tmux run-shell "${SCRIPT} init"` — the init call itself.
- Old lines 85–88: the no-op epilogue (`# The bind lines above short-circuit …` … `:`).
- Everything above line 70 (shebang, header comment, `get_tmux_option`, hooks,
  key bindings, dwell default on line 55, toggle block) and the line-12
  `no monitor-activity` negation.

### Success Criteria

- [ ] The `# --- focused-activity detection (only with toggle bound) ---` block
      is **entirely absent** (zero matches for its header line).
- [ ] No occurrence of `poller`, `client_activity`, `alert-activity`, or
      `focused-activity` anywhere in the file.
- [ ] The rewritten bootstrap comment (a) states `init` runs LAST, (b) explains
      it seeds initial state and must see hooks/keys/options wired, (c) states it
      starts no background processes, (d) mentions **none** of: poller,
      toggle-enabled flag, racing, focused-activity.
- [ ] `tmux run-shell "${SCRIPT} init"` is present and byte-identical.
- [ ] `bash -n` passes; `shellcheck` introduces no new diagnostics.
- [ ] File is 79 lines (was 88; −9).

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact current 14-line oldText (lines 70–83,
captured byte-accurately including UTF-8 em-dashes) and the exact 5-line
newText; the precise `do_init` body showing why the old rationale is false (it
neither reads the toggle flag nor starts a poller); the full
activity/poller-token enumeration proving only line-12's negation survives; the
edit is executed as ONE atomic replacement because the region is contiguous and
the header line is globally unique; parallel-safety vs S1 (disjoint region,
anchor on text not line numbers); deterministic Level 1–3 validation including a
real `tmux -L` integration test that confirms `init` still runs cleanly after
the comment change (comments don't execute, but the test guards against an
accidental edit to the init line/epilogue). An implementer with zero prior
knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — why output-activity is not wired (authorizes deleting the focused block)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "PRD §12 is the authority for deleting the focused-activity comment block (old lines 70–77).
        It states alert-activity is 'unusable' (fires only for non-focused/background windows),
        there is 'no robust tmux primitive for the focused session produced output', and
        'It is therefore not wired. Relevance comes from selection and dwell only.' The deleted
        block's claim that the poller is the relevance list's 'PRIMARY signal' directly contradicts
        this section."
  critical: "Relevance = SELECTION + DWELL only (§12). The focused-activity block describes a signal
             that the spec explicitly rejects. Delete it wholesale — do not partially rewrite it."

# MUST READ — gating forbids extra hooks with toggle (also authorizes deletion)
- docfile: PRD.md
  section: "§9. Gating"
  why: "PRD §9: with toggle disabled the user 'pays nothing for the toggle machinery — no background
        timers, no relevance bookkeeping, no extra hooks.' The deleted block's 'no extra hook is
        needed here' line describes machinery §9 forbids. §9 also confirms toggle gating is handled
        by the engine reading @session-history-toggle-enabled — NOT by do_init."
  critical: "do_init does NOT branch on the toggle flag. The old bootstrap comment's 'do_init reads
             @session-history-toggle-enabled' is false. The engine (tlist/dwell arms) reads the flag,
             not init. Do not re-introduce any toggle-flag reference in the rewritten comment."

# MUST READ — what 'init' actually does (authority for the rewritten comment)
- docfile: PRD.md
  section: "§17. Subcommand reference"
  why: "§17 row: '| init | Seed initial state if empty (current/attached session). |' This is the
        exact behavior the rewritten comment must describe: init SEEDS state (when empty). Nothing
        about a poller, nothing about reading the toggle flag."
  critical: "init = 'Seed initial state if empty'. That single sentence is the rewritten comment's
             whole subject. The 'runs LAST / ordering' rationale is an entry-point concern (it must
             see hooks/keys/options wired), not an engine-subcommand concern."

# MUST READ — the hook/binding reference confirms the load-time wiring that init must see
- docfile: PRD.md
  section: "§16. Hook & binding reference"
  why: "§16 enumerates exactly what the entry script wires (3 set-hook lines + 4 conditional
        bind-key lines + dwell default + toggle-enabled flag). The rewritten comment's phrase
        'after every option/hook/key above is in place' maps 1:1 onto this list. It is why init
        is ordered LAST in the file."
  critical: "Ordering is about seeing the §16 wiring in place, NOT about a poller/toggle race."

# The decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 8 — ENTRY POINT focused-activity section (session_history.tmux) → rows 8b and 8c"
  why: "GAP 8b (verbatim, lines 70–77): '# --- focused-activity detection (only with toggle bound)
        --- comment block — describes client_activity/poller/alert-activity → 🔴 DELETE the whole
        block.' GAP 8c (verbatim, lines 79–83): 'Bootstrap comment: do_init reads ... whether to
        start the focused-activity poller → 🟡 REWRITE — keep init running LAST, but the rationale
        is no longer the poller; init seeds state and (post-cleanup) nothing async. Drop
        poller/poller-race wording.' This PRP == GAP 8b + 8c."
  critical: "GAP 8a (line 55, dwell default 10000→30000) is S1 — NOT this task. The note at
             gap_analysis.md:151 confirms 'the entry point itself never starts the poller directly
             (that was do_init → do_start_poller)' — i.e. this comment edit needs no corresponding
             code change in the .tmux file; the call site (tmux run-shell init) stays."

# The file under edit
- file: session_history.tmux
  why: "The ONLY file this task modifies. Bash entry point, shebang #!/usr/bin/env bash, UTF-8
        (uses em-dashes U+2014). The edit region is lines 70–83: lines 70–77 = the focused-activity
        comment block (header at 70 is len-78, unique in the file); line 78 = blank; lines 79–83 =
        the bootstrap comment. Line 84 (tmux run-shell init) and lines 85–88 (epilogue) follow and
        are preserved. Everything above line 70 (hooks/keys/dwell-default/toggle) is untouched."
  pattern: "All block-separator comment headers in this file use the idiom
            '# --- <topic> ---<dashes>' (e.g. line 44 '# --- key bindings (all overridable) ---...').
            The focused-activity header at line 70 is the ONLY such header whose topic is being
            removed; it should disappear entirely (no replacement header). The rewritten bootstrap
            comment is a plain multi-line # comment, matching the prose style of lines 26–39 and
            57–59 (no --- separator)."
  gotcha: "Em-dashes (—) in the file are UTF-8 (bytes E2 80 94). The newText keeps ONE em-dash
           ('empty — a one-shot') to match file convention. Exact-match edits must preserve UTF-8;
           do not substitute '--' or an ASCII dash. The oldText also contains em-dashes on old
           lines 71 and 79 — match them exactly."

# The engine state that makes the old rationale false (CONTRACT — verified, no edit needed here)
- file: scripts/session_history.sh
  why: "do_init() at line 471 is the subject of the bootstrap comment. Verified current body:
        (1) load; (2) if CURRENT empty, seed HIST/IDX/CURRENT from the attached/newest session and
        save; (3) one-shot migration guard that kills a stale @session-history-poller-pid and clears
        the option. It does NOT read @session-history-toggle-enabled and starts NO process (grep for
        run-shell|setsid|nohup|disown|'& $' in the body = 0). Dispatch: 'init) lock; load_alive;
        do_init; unlock ;;' (synchronous, under flock). This is why the old comment is doubly false."
  critical: "This PRP does NOT edit the engine. P1.M1.T2 already removed do_start_poller and the
             pipe-pane block. The only 'poller' text left in the engine is the self-cleaning
             migration guard inside do_init — that is correct and stays. The rewritten .tmux comment
             describes init's seed behavior, which is stable."

# The sibling entry-point task (CONTRACT — same file, disjoint region)
- docfile: plan/001_ca41c05f3ead/P1M2T1S1/PRP.md
  why: "S1 changes the dwell default on line 55 (10000 → 30000), which is ABOVE this task's region
        (70–83) and is ±0 lines. The two edits cannot collide: S1's anchor (the set-option line) is
        unique and above line 70; this task's anchor (the focused-activity header) is unique and at
        line 70+. Merge cleanly in either order."
  critical: "Anchor on TEXT, never line numbers. If S1 lands first, line 55 changes but lines 70–83
             are unaffected (S1 is ±0 lines). If THIS task lands first, line 55 is unaffected. The
             dwells-default change is NOT this task — do not touch line 55."

# The prior removal that made this comment obsolete (CONTRACT — already Complete)
- docfile: plan/001_ca41c05f3ead/P1M1T2S1/PRP.md
  why: "T2.S1 removed do_start_poller + pipe-pane legacy from do_init and added the migration guard.
        That removal is what makes the .tmux bootstrap comment's 'start the focused-activity poller'
        rationale false. This comment edit is the documentation tail of that code change."
  critical: "T2.S1 status in the plan is 'Ready' but the engine file ALREADY reflects it (grep
             verified: do_start_poller = 0 matches; migration guard present at 489–495). Whether or
             not T2.S1 is formally 'Complete', the engine is in the post-removal state this comment
             assumes. Do not block on T2.S1's status flag."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §12/§9/§17/§16 authorize this edit
├── README.md                   # docs (NOT this task — M3 owns README activity removal)
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — do_init() at :471 (READ for accuracy; DO NOT EDIT)
│                                #     post-T2.S1: seeds state + migration guard, NO poller start
├── session_history.tmux        # ← THE FILE TO EDIT (88 lines)
│                                #     line 12  = '# ... no monitor-activity.' (KEEP — negation)
│                                #     line 55  = dwell default (S1 — DO NOT TOUCH)
│                                #     line 69  = blank (KEEP — separator before bootstrap)
│                                #     lines 70–77 = focused-activity block (THIS TASK: DELETE)
│                                #     line 78  = blank (THIS TASK: consumed by the replacement)
│                                #     lines 79–83 = bootstrap comment (THIS TASK: REWRITE)
│                                #     line 84  = tmux run-shell "${SCRIPT} init" (KEEP)
│                                #     lines 85–88 = no-op epilogue (KEEP)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md   # ← GAP 8b (delete) + 8c (rewrite)
        ├── P1M2T1S1/PRP.md                # ← sibling (line 55, disjoint)
        └── P1M2T1S2/
            ├── PRP.md                     # ← THIS task
            └── research/comment_blocks_verification.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only session_history.tmux is modified.
# After this task the file is 79 lines (was 88; −9):
#   - the 8-line focused-activity block (old 70–77) is gone
#   - the blank separator (old 78) is gone
#   - the 5-line bootstrap comment (old 79–83) is replaced by a new 5-line comment
#   - the init call (old 84) and epilogue (old 85–88) shift up unchanged
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — em-dashes are UTF-8. The file uses U+2014 (—, bytes E2 80 94) on old lines 71 and 79,
# and the newText keeps one em-dash ('empty — a one-shot'). Match UTF-8 exactly in oldText; preserve
# it in newText. Do NOT replace with '--' or an ASCII '-'. (Verified via cat -A: M-bM-^@M-^YT.)

# CRITICAL — execute as ONE combined edit, not two. The region old lines 70–83 is contiguous
# (focused block 70–77 + blank 78 + bootstrap comment 79–83). A single oldText→newText replacement
# is atomic and unambiguous, and the header line '# --- focused-activity detection (only with toggle
# bound) ---' (len 78, unique in the file) guarantees the oldText matches exactly one location.

# CRITICAL — do NOT touch old line 84 (tmux run-shell "${SCRIPT} init"). It is the load entry that
# seeds initial state. The oldText must END at old line 83 ('... left the poller unset on reload).')
# and the newText must END at the last comment line — the init call is the line AFTER the replaced
# region and must remain byte-identical. (The oldText begins with the focused-activity header at old
# line 70 and ends with the bootstrap comment's last line at old line 83.)

# GOTCHA — keep ONE blank line as the separator above the rewritten comment. Old line 69 (blank,
# after the pick_key binding) is the section separator and stays. The blank at old line 78 is INSIDE
# the replaced region and is consumed by the replacement (the newText does not start with a blank).
# Net structure after edit: pick_key binding (68) / blank (69) / rewritten comment (70–74) / init (75)
# / blank (76) / epilogue (77–79) / ':' (79). Wait — see the exact line map in Task 1; the key point
# is exactly ONE blank separates the key-bindings block from the bootstrap comment.

# GOTCHA — old line 12 ('# extra hooks, no background sleepers, no monitor-activity.') MUST remain.
# It is a correct negation (asserts monitor-activity is absent), consistent with PRD §9. The success
# criterion 'grep -ni activity = exactly one match' relies on this line surviving. Do not delete it.
# (It is far above the edit region and is not inside oldText.)

# GOTCHA — no test framework in this repo (no bats/spec/Makefile). Validation uses bash -n,
# shellcheck (present), grep proofs, and a real tmux 3.6a integration test against a throwaway
# `tmux -L` socket (Level 3) that confirms init still runs cleanly (comments don't execute, but the
# test catches an accidental edit to the init line/epilogue).

# GOTCHA — line numbers shift under parallel execution but anchors don't. S1 (same file) edits line
# 55 ABOVE this region and is ±0 lines, so old lines 70–83 keep their numbers even if S1 lands first.
# This task is net −9, shifting only lines BELOW old line 70 — it never moves line 55. ALWAYS match
# the full TEXT of the header comment and the bootstrap block, not 'line 70'.

# GOTCHA — the rewritten comment must mention NONE of: 'poller', 'client_activity', 'alert-activity',
# 'focused-activity', 'toggle-enabled', 'race', 'racing', 'async run-shell'. The success gate
# 'grep -niE poller|client_activity|alert-activity|focused-activity = 0' enforces the first four.
# Read the newText aloud and confirm the other banned terms are absent before finalizing.
```

## Implementation Blueprint

### Data models and structure

None. This is a pure comment edit (delete one comment block + rewrite an adjacent
comment block) in the bash entry-point file. No data models, no schemas, no
options, no dispatch changes. The `tmux run-shell "${SCRIPT} init"` call is
preserved unchanged.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE pre-edit baseline (no source edits)
  - RUN: shellcheck session_history.tmux > /tmp/sc_before_m2t1s2.txt 2>&1; echo "baseline exit: $?"
  - RUN: before=$(wc -l < session_history.tmux); echo "pre-edit lines = $before"   # expect 88
  - RUN: sed -n '68,88p' session_history.tmux | cat -A > /tmp/region_before_m2t1s2.txt
         # Captures pick_key binding (68) + blank (69) + focused block (70-77) + blank (78) +
         # bootstrap comment (79-83) + init call (84) + blank (85) + epilogue (86-88).
         # Regression guard: proves the init call (84) and epilogue (85-88) survive byte-identical.
  - RUN: grep -niE 'poller|client_activity|alert-activity|focused-activity' session_history.tmux \
           | wc -l   # expect 6 (lines 70,72,73,74,75,77,81,83 — count may be 6-8 depending on
                     # overlap; record the EXACT pre-count; post must be 0)
  - WHY: the shellcheck gate is "no NEW diagnostics" (the file may carry pre-existing SC warnings).
         The 68-88 snapshot proves you edited ONLY lines 70-83 (lines 68-69 and 84-88 must match).

Task 2: PERFORM the single combined exact-text replacement (the edit)
  - USE the `edit` tool with oldText/newText below. The oldText is the EXACT bytes of old lines 70–83
    (focused block + blank + bootstrap comment). The newText is the 5-line rewritten bootstrap
    comment. Match UTF-8 em-dashes (—) exactly.
  - oldText (14 lines, byte-exact — begins with the unique focused-activity header):
      # --- focused-activity detection (only with toggle bound) --------------------
      # The relevance list's PRIMARY signal is input in the session you are viewing —
      # typing, pane/window switches, or any tmux command. tmux's alert-activity cannot
      # see the focused window, so the engine watches the attached client's
      # client_activity timestamp instead (see scripts/session_history.sh). The
      # poller promotes the current session whenever that timestamp advances while the
      # session stays the same; no extra hook is needed here. With toggle unbound the
      # poller is never started: no resident processes.

      # Bootstrap the engine LAST, after every option/hook/key above is in place —
      # do_init reads @session-history-toggle-enabled (set by the toggle block) to
      # decide whether to start the focused-activity poller, so it must run after that
      # flag is set (calling it earlier raced the async run-shell ahead of the toggle
      # block and left the poller unset on reload).
  - newText (5 lines):
      # Bootstrap the engine LAST, after every option/hook/key above is in place.
      # do_init seeds the initial state (the current/attached session) into the
      # history options when they are empty — a one-shot, idempotent seed that must
      # run after the full configuration is wired (hooks, keys, options). It starts
      # no background processes, so its only requirement is that ordering.
  - ANCHOR on the full text (header line is unique); do NOT key on 'line 70'.
  - PRESERVE byte-for-byte: old line 69 (blank above), old line 84 (init call),
    old lines 85–88 (epilogue).
  - DO NOT TOUCH: line 55 (dwell default — S1), line 12 (monitor-activity negation),
    the hooks (40–42), key bindings (48–68), toggle block (60–65), get_tmux_option (20).

Task 3: VERIFY parse (no edits)
  - RUN: bash -n session_history.tmux && echo "PARSE OK" || echo "PARSE FAIL"
  - EXPECTED: PARSE OK (exit 0). A comment-only change cannot break parsing; smoke check.

Task 4: VERIFY token removal + lint delta + line count + preservation (no edits)
  - RUN: grep -niE 'poller|client_activity|alert-activity|focused-activity' session_history.tmux
    EXPECTED: ZERO output (all targeted tokens gone).
  - RUN: grep -ni 'activity' session_history.tmux
    EXPECTED: exactly 1 line — the line-12 negation '# ... no monitor-activity.'.
  - RUN: grep -c 'focused-activity detection' session_history.tmux
    EXPECTED: 0 (the block header is gone).
  - RUN: grep -n 'tmux run-shell "\${SCRIPT} init"' session_history.tmux
    EXPECTED: exactly 1 line (the init call survived; it shifts from line 84 to ~75).
  - RUN: shellcheck session_history.tmux > /tmp/sc_after_m2t1s2.txt 2>&1
  - RUN: diff <(sort /tmp/sc_before_m2t1s2.txt) <(sort /tmp/sc_after_m2t1s2.txt)
    EXPECTED: no diff (a comment change introduces no shellcheck diagnostic).
  - RUN: after=$(wc -l < session_history.tmux); echo "post-edit lines = $after"
    EXPECTED: 79 (was 88; −9). Any other count = wrong edit scope — revert.
  - RUN: diff /tmp/region_before_m2t1s2.txt <(sed -n '68,79p' session_history.tmux | cat -A)
    EXPECTED: the pick_key binding line (old 68) and the blank (old 69) at the top are IDENTICAL;
              the init call and epilogue at the bottom are IDENTICAL; only the middle comment
              region changed. (Adjust the sed range to the post-edit span that spans the pick_key
              binding through the epilogue ':' line.)

Task 5: VERIFY behavior with a real tmux integration test (Level 3, no edits)
  - RUN the Level 3 block in the Validation Loop. It sources the edited entry script against a
    throwaway `tmux -L` socket and confirms `init` runs cleanly (no parse/runtime error) and seeds
    state — proving the comment edit didn't disturb the init call or load sequence.
    EXPECTED: entry script loads, init seeds the attached session, no error.
```

### Implementation Patterns & Key Details

```bash
# Why ONE combined edit (not two):
#   The region old lines 70–83 is contiguous: focused block (70–77) + blank (78) + bootstrap
#   comment (79–83). Replacing it as a single oldText→newText is atomic and unambiguous. The
#   header '# --- focused-activity detection (only with toggle bound) ---' is the unique anchor
#   that guarantees exactly one match. Doing it in one edit also makes the git diff a single
#   hunk (easy to review) and makes the −9 line-count assertion deterministic.

# Why the newText says what it says (each clause maps to a verified fact / PRD section):
#   "Bootstrap the engine LAST, after every option/hook/key above is in place."
#       → Matches the file's actual ordering (hooks 40-42, keys 48-68, dwell 54-55, toggle 60-65,
#         all BEFORE init at 84) and PRD §16's enumeration of that wiring.
#   "do_init seeds the initial state (the current/attached session) into the history options
#    when they are empty"
#       → PRD §17 row for `init`: "Seed initial state if empty (current/attached session)." Verified
#         against do_init() body: `if [ -z "$CURRENT" ]; then ... seed HIST/IDX/CURRENT ... save; fi`.
#   "a one-shot, idempotent seed that must run after the full configuration is wired (hooks,
#    keys, options)."
#       → "idempotent/reload-safe" matches the file header (line 6: "reload-safe: hooks/keys/init
#         are all idempotent"). The ordering rationale (see full config wired) replaces the old
#         false poller-race rationale.
#   "It starts no background processes, so its only requirement is that ordering."
#       → Verified: do_init() has no run-shell/setsid/nohup/disown/'& $' (grep = 0). It explicitly
#         dispels the old "start the focused-activity poller" claim.

# What the newText deliberately OMITS (banned terms — all must be absent):
#   poller, client_activity, alert-activity, focused-activity (enforced by success gate grep = 0),
#   and also: toggle-enabled, race/racing, "async run-shell" (read the newText aloud to confirm).

# How the load sequence looks AFTER the edit (lines 68–75 region):
#     [pick_key binding]                                  # old 68 (KEEP)
#     (blank)                                             # old 69 (KEEP — separator)
#     # Bootstrap the engine LAST, after every ...        # new comment line 1
#     # do_init seeds the initial state ...               # new comment line 2
#     # history options when they are empty — a one-shot  # new comment line 3
#     # run after the full configuration is wired ...     # new comment line 4
#     # no background processes, so its only ...          # new comment line 5
#     tmux run-shell "${SCRIPT} init"                     # old 84 (KEEP, shifts up)
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin; no DB.

CONFIG (tmux global user options):
  - none changed. This is a comment-only edit. The @session-history-* options written by the entry
        script (dwell-ms on line 55 — owned by S1; toggle-enabled on lines 61/64) are untouched.

ROUTES / DISPATCH:
  - none changed. The subcommand dispatch lives in the engine (scripts/session_history.sh). The
        entry point's only dispatch-style line is `tmux run-shell "${SCRIPT} init"` (old line 84),
        which is PRESERVED byte-identical. No subcommand added/removed/renamed.

HOOKS / BINDINGS:
  - none changed. The set-hook lines (40–42) and bind-key lines (48–68) are untouched. This edit
        is purely the two comment blocks at old lines 70–83.

DOCUMENTATION:
  - THIS edit IS the entry-point documentation (Mode A — inline comments). No README change here
        (README activity removal is M3). No engine header-comment change here (T4 owns the engine
        header). After this edit, the entry script's comments no longer describe any
        activity/poller mechanism — consistent with PRD §12/§9.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit baseline (run BEFORE editing):
shellcheck session_history.tmux > /tmp/sc_before_m2t1s2.txt 2>&1; echo "baseline exit: $?"
before=$(wc -l < session_history.tmux); echo "pre-edit lines = $before"   # expect 88
sed -n '68,88p' session_history.tmux | cat -A > /tmp/region_before_m2t1s2.txt

# 1. Parse check (run AFTER the single edit):
bash -n session_history.tmux && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0). Comment-only change; cannot break parsing.

# 2. Lint delta (run AFTER editing):
shellcheck session_history.tmux > /tmp/sc_after_m2t1s2.txt 2>&1
diff <(sort /tmp/sc_before_m2t1s2.txt) <(sort /tmp/sc_after_m2t1s2.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: empty diff (a comment change introduces no shellcheck diagnostic).

# 3. Line-count delta (capture before & after within THIS task):
after=$(wc -l < session_history.tmux)
echo "lines: $before -> $after (expect 88 -> 79, delta -9)"
[ "$after" = "79" ] && echo "LINE COUNT OK" || echo "LINE COUNT WRONG"
# Expected: LINE COUNT OK (79). The edit is 14 oldText lines -> 5 newText lines = -9.
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo. These grep/diff proofs pin the exact token removal, the init-call
preservation, and the byte-identical epilogue.

```bash
# A. All targeted activity/poller tokens are gone:
grep -niE 'poller|client_activity|alert-activity|focused-activity' session_history.tmux
# Expected: NO output (zero matches). [Pre-edit there were matches on lines 70,72,73,74,75,77,81,83.]

# B. The ONLY remaining 'activity' token is the line-12 negation (asserts absence):
grep -ni 'activity' session_history.tmux
# Expected: exactly 1 line — '# extra hooks, no background sleepers, no monitor-activity. ...'
# (This is a CORRECT negation consistent with PRD §9. It is far above the edit region and survives.)

# C. The focused-activity block header is gone:
grep -c 'focused-activity detection' session_history.tmux
# Expected: 0.

# D. The init call survived byte-identical (it shifts up from line 84 but is unchanged):
grep -nF 'tmux run-shell "${SCRIPT} init"' session_history.tmux
# Expected: exactly 1 line (now around line 75, was 84). Byte-identical content.

# E. The rewritten bootstrap comment is present and contains the seed/ordering rationale:
grep -c 'Bootstrap the engine LAST' session_history.tmux          # Expected: 1
grep -c 'seeds the initial state' session_history.tmux            # Expected: 1
grep -c 'starts' session_history.tmux | grep -q . && echo ok      # 'no background processes' present
# Expected: all three present exactly once.

# F. Banned rationale terms are absent from the rewritten comment (read the new comment region):
sed -n '/Bootstrap the engine LAST/,/no background processes/p' session_history.tmux \
  | grep -niE 'poller|toggle-enabled|race|racing|focused-activity|alert-activity|client_activity|async run-shell'
# Expected: NO output. The rewritten comment must contain NONE of these.

# G. The pick_key binding (old 68), the blank separator (old 69), the init call (old 84), and the
#    epilogue (old 85-88) are byte-identical to pre-edit:
sed -n '1p;2p' /tmp/region_before_m2t1s2.txt   # old lines 68-69 (pick_key binding + blank)
# Now find the same two lines in the post-edit file:
grep -nF '[ -n "$pick_key" ]    && tmux bind-key "$pick_key"    run-shell "${SCRIPT} pick' session_history.tmux
# Expected: exactly 1 line; the NEXT line must be blank (the preserved separator), then the comment.
tail -4 session_history.tmux   # the epilogue: blank / '# The bind lines above ...' / '# end on ...' / ':'
# Expected: byte-identical to the last 4 lines of /tmp/region_before_m2t1s2.txt.

# H. Scope guard — the dwell default (line 55, owned by S1) is untouched:
grep -n "set-option -g '@session-history-dwell-ms'" session_history.tmux
# Expected: exactly 1 line. Its value is whatever S1 produced (30000 if S1 landed, 10000 if not) —
# NOT this task's concern. Confirm the LINE still exists and is structurally intact; do not change it.
```

### Level 3: Integration Testing (System Validation — real tmux 3.6a)

Comments do not execute, so the behavioral risk is an accidental edit to the `init` line or the load
sequence. This test sources the **edited** entry script against a throwaway `tmux -L` socket and
confirms the plugin loads and `init` seeds state cleanly. (It isolates against a throwaway server so
it does not touch the user's real tmux session or persist global hooks/keys.)

```bash
if ! command -v tmux >/dev/null; then
  echo "tmux not installed — skipping L3 (Level 2 already proves token removal + preservation)."
  exit 0
fi

SOCK=m2t1s2
tmux -L "$SOCK" kill-server 2>/dev/null
tmux -L "$SOCK" new-session -d -s seedprobe 2>/dev/null   # an attached-ish session for init to seed

# Source the edited entry script against the throwaway server.
# CAVEAT: session_history.tmux calls bare `tmux` (no -L). We wrap with a PATH shim that aliases
# tmux -> 'tmux -L SOCK' so the whole script targets the throwaway server.
TMPBIN="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexec /usr/bin/env tmux -L %q "$@"\n' "$SOCK" > "$TMPBIN/tmux"
chmod +x "$TMPBIN/tmux"
export PATH="$TMPBIN:$PATH"

if bash session_history.tmux 2>/tmp/m2t1s2_load.err; then
  echo "ENTRY SCRIPT LOAD OK (no runtime error)"
else
  echo "ENTRY SCRIPT LOAD FAILED:"; cat /tmp/m2t1s2_load.err
fi

# Confirm init seeded state for the probe session (history option is now non-empty):
hseed="$(tmux -L "$SOCK" show-option -gv '@session-history-hist' 2>/dev/null)"
cur="$(tmux -L "$SOCK" show-option -gv '@session-history-current' 2>/dev/null)"
echo "seeded hist='$hseed' current='$cur'"
[ -n "$hseed" ] && echo "INIT SEEDED STATE OK" || echo "INIT DID NOT SEED (acceptable if no attached session)"

# Confirm the entry script left NO poller/async artifact (there must be no @session-history-poller-pid,
# no resident process) — proves the rewritten comment's 'no background processes' is behaviorally true:
ppid="$(tmux -L "$SOCK" show-option -gv '@session-history-poller-pid' 2>/dev/null)"
echo "poller-pid after load='$ppid'"; [ -z "$ppid" ] && echo "NO POLLER ARTIFACT OK"

# Cleanup: undo hooks/keys on the throwaway server and kill it.
tmux -L "$SOCK" set-hook -gu client-session-changed 2>/dev/null
tmux -L "$SOCK" set-hook -gu session-closed 2>/dev/null
tmux -L "$SOCK" set-hook -gu session-created 2>/dev/null
tmux -L "$SOCK" kill-server 2>/dev/null
rm -rf "$TMPBIN"
echo "LEVEL 3 DONE"
# Expected:
#   ENTRY SCRIPT LOAD OK (no runtime error)  — the comment edit didn't break the init call / load.
#   INIT SEEDED STATE OK (or the acceptable no-attached-session caveat) — init still seeds.
#   NO POLLER ARTIFACT OK — no @session-history-poller-pid left, confirming 'no background processes'.
```

### Level 4: Creative & Domain-Specific Validation

```bash
# A. The change is minimal and scoped in git:
git diff --stat session_history.tmux
# Expected: a single file. The diff is one hunk: 14 lines removed (old 70-83), 5 lines added
# (the rewritten bootstrap comment). Net -9.

git diff session_history.tmux
# Manually confirm:
#   - the '-' side is EXACTLY the focused-activity block + blank + old bootstrap comment (14 lines).
#   - the '+' side is the 5-line rewritten bootstrap comment.
#   - the line 'tmux run-shell "${SCRIPT} init"' appears UNCHANGED (no +/- prefix) immediately after.
#   - NOTHING above old line 70 or below old line 84 changed.
# If you see a change to line 55 (dwell default) in this diff, that is S1's parallel work — coordinate/
# rebase; do not fold it into this task's commit.

# B. Cross-file consistency — the entry-point comment now matches the engine reality:
echo "entry-point bootstrap comment:"; sed -n '/Bootstrap the engine LAST/,/no background processes/p' session_history.tmux
echo "engine do_init (no poller start, seeds state):"; sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | head -20
# Expected: the comment says 'seeds the initial state ... starts no background processes'; the engine
# body has the seed-if-empty block + the migration guard (kill stale pid) and NO process start.
# They now tell the same story.

# C. The PRD contains the authority for every clause of the new comment:
grep -n 'Seed initial state' PRD.md                       # §17 — 'init' purpose
grep -n 'not wired' PRD.md                                # §12 — why no activity/poller
grep -n 'no extra hooks' PRD.md                           # §9 — gating, no background timers
# Expected: all present (the rewritten comment's claims are each grounded in a PRD section).

# D. Full-file token sweep (final consistency check):
echo "activity tokens (expect only the line-12 negation):"; grep -ni 'activity' session_history.tmux
echo "poller/focused tokens (expect zero):"; grep -niE 'poller|focused-activity|client_activity|alert-activity' session_history.tmux
# Expected: 'activity' -> 1 line (the negation); poller/focused -> nothing.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n session_history.tmux` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_m2t1s2.txt`
      (sorted diff is empty).
- [ ] `wc -l session_history.tmux` == **79** (was 88; −9).
- [ ] `grep -niE 'poller|client_activity|alert-activity|focused-activity' session_history.tmux`
      → **zero matches**.
- [ ] `grep -ni 'activity' session_history.tmux` → exactly **one** match (the line-12 negation).
- [ ] `grep -c 'focused-activity detection' session_history.tmux` → **0**.

### Feature Validation

- [ ] The focused-activity comment block (old lines 70–77) is **entirely absent**.
- [ ] The rewritten bootstrap comment (a) states `init` runs LAST, (b) says it seeds initial state
      when empty and must see hooks/keys/options wired, (c) states it starts no background
      processes, (d) contains **none** of: poller, toggle-enabled, race/racing, focused-activity.
- [ ] `tmux run-shell "${SCRIPT} init"` is present and byte-identical (shifts from line 84 → ~75).
- [ ] The no-op epilogue (`# The bind lines above ...` … `:`) is byte-identical to pre-edit.
- [ ] Level 3 real-tmux test: entry script loads cleanly, `init` seeds state, no poller artifact.
- [ ] Cross-file consistency: the entry-point comment now matches the engine `do_init` reality
      (seed + migration guard, no process start).

### Code Quality Validation

- [ ] The git diff is a single hunk: −14/+5 on the old lines 70–83 region; nothing else.
- [ ] old line 69 (blank separator after pick_key binding) is byte-identical.
- [ ] old line 84 (`tmux run-shell "${SCRIPT} init"`) and old lines 85–88 (epilogue) byte-identical.
- [ ] UTF-8 em-dash (—) in the new comment is preserved (not downgraded to `--`).
- [ ] No "drive-by" fixes; no edit to line 55 (S1's dwell default) or line 12 (monitor-activity negation).
- [ ] Edit is anchored on the full oldText text (header line is unique), not the line number 70.

### Documentation & Deployment

- [ ] This edit IS the entry-point documentation (Mode A — inline comments). No README change here.
- [ ] The entry script's comments now tell a single true story: hooks → keys → dwell default →
      toggle flag → `init` LAST (state seed, no background processes). No activity/poller narrative.
- [ ] No new environment variables, options, hooks, or bindings.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT touch `tmux run-shell "${SCRIPT} init"`** (old line 84). It is the load entry that
  seeds initial state. The oldText must END at the bootstrap comment's last line (old line 83); the
  init call is the line AFTER the replaced region and must remain byte-identical.
- ❌ **Do NOT delete the line-12 `no monitor-activity` negation.** It is a *correct* statement
  (asserts monitor-activity is absent), consistent with PRD §9. It is far above the edit region and
  must survive — the success gate `grep -ni activity = exactly one match` depends on it.
- ❌ **Do NOT mention `poller`, `toggle-enabled`, `race`, `focused-activity`, `client_activity`, or
  `alert-activity` in the rewritten comment.** Even an explanatory "we used to have a poller" note
  violates the spec-cleanup intent (the file must contain *zero* activity-detection narrative) and
  fails the token-removal gate. Describe only the seed-and-order behavior.
- ❌ **Do NOT split this into two edits** (delete block + rewrite comment separately) if the single
  combined edit is feasible. The region is contiguous (70–83) and the header line is unique; one
  atomic replacement gives a clean single-hunk diff and a deterministic −9 line count. (Two edits
  risk leaving the blank line at old 78 orphaned or double-counted.)
- ❌ **Do NOT touch line 55 (the dwell default).** That is **S1** (GAP 2b/8a), a disjoint region
  above this task. If you see `10000` → `30000` in your diff, you have crossed into S1's scope.
- ❌ **Do NOT edit `scripts/session_history.sh` or `README.md`.** The engine is already in the
  post-T2.S1 state this comment assumes (grep-verified); the README activity removal is M3. This
  task is `session_history.tmux` comments ONLY.
- ❌ **Do NOT key the edit on the hard line number `70`.** S1 edits the same file above line 70
  (±0 lines, so 70–83 stays put), but always match the full TEXT of the focused-activity header and
  the bootstrap block. Line numbers are for orientation, not anchoring.
- ❌ **Do NOT reformat surrounding lines, "fix" quoting, or adjust the em-dash style elsewhere.**
  The edit is the two comment blocks (old 70–83) only. Preserve UTF-8 em-dashes as-is.
- ❌ **Do NOT add a new `# --- <separator> ---` header for the bootstrap comment.** The original
  bootstrap comment had no separator header (it was a plain prose comment following a separator-less
  blank line). The rewritten comment follows the same plain-prose style (like lines 26–39, 57–59).

---

## Scope Boundaries (one-screen reference)

| Item | This task (M2.T1.S2)? | Owner |
|------|:---:|-------|
| Focused-activity comment block, old lines 70–77 (DELETE) | ✅ | M2.T1.S2 (GAP 8b) |
| Bootstrap comment, old lines 79–83 (REWRITE) | ✅ | M2.T1.S2 (GAP 8c) |
| Keep `tmux run-shell "${SCRIPT} init"` (old 84) byte-identical | ✅ (preserve) | M2.T1.S2 |
| Keep epilogue, old lines 85–88 byte-identical | ✅ (preserve) | M2.T1.S2 |
| Keep line-12 `no monitor-activity` negation | ✅ (preserve) | M2.T1.S2 |
| Dwell default on line 55 (`10000` → `30000`) | ❌ | **M2.T1.S1** (GAP 2b/8a) |
| `scripts/session_history.sh` `do_init` / migration guard | ❌ | **T2.S1** (already done) |
| `scripts/session_history.sh` header comment activity refs | ❌ | **T4** |
| `README.md` activity/dwell references | ❌ | **M3** |
| Hooks (40–42) / key bindings (48–68) / toggle block (60–65) | ❌ | out of scope (preserve) |

---

## Confidence Score

**10/10** for one-pass success. This is a comment-only edit (delete one block + rewrite one adjacent
block) with: the exact 14-line oldText supplied byte-accurately (including UTF-8 em-dashes, verified
via `cat -A`) and the exact 5-line newText supplied; the rewrite's every clause mapped to a verified
fact (`do_init` seeds state + migration guard, no process start — grep-confirmed) and a PRD section
(§12 not-wired, §9 no-extra-hooks, §17 init=seed, §16 wiring-ordering); the full token enumeration
proving only line-12's negation survives; executed as ONE atomic replacement because the region is
contiguous and the header line is globally unique; a real tmux 3.6a Level 3 integration test that
sources the edited script against a throwaway socket and confirms init still seeds + leaves no poller
artifact (behaviorally proving the "no background processes" claim); deterministic grep proofs
(token removal, single `activity` negation, init-call preservation); a −9 line-count assertion;
explicit parallel-safety vs S1 (disjoint region, anchor on text not line numbers); and an explicit
scope map separating M2.T1.S2 from M2.T1.S1 (line 55), T2.S1 (engine, already done), T4 (engine
header), and M3 (README). No ambiguity: the oldText is unique, the newText is fully specified, and
the validation gates are deterministic.