name: "P1.M2.T1.S1 — Change dwell default in session_history.tmux from 10000 to 30000"
description: "Single-literal edit to `session_history.tmux:55`: change `tmux set-option -g '@session-history-dwell-ms' 10000` to `... 30000`. This makes the entry-point's load-time default match PRD §15 / §16 / §3.4 (default 30000; the entry script defaults @session-history-dwell-ms to 30000 if unset). No other line changes. The line-54 `[ -z ... ] && \\` conditional (the 'if unset' guard) and the line-53 comment are byte-identical. This is the entry-point leg (gap-analysis GAP 2b) of the four-way dwell-default alignment; the engine leg is T3.S1 (Complete, echoes 30000); the README leg is M3.T2.S1; the header-comment leg is T4. The sibling entry-point task S2 (remove focused-activity block + rewrite bootstrap comment) edits disjoint regions (lines 70–83) on the same file. Net: ±0 lines."

---

## Goal

**Feature Goal**: Make the tmux-session-history entry point's load-time default for
`@session-history-dwell-ms` conform to the PRD. When the option is unset/empty at plugin load,
`session_history.tmux` must write **30000** (30 s) to the global option, not the legacy value of
10000 (10 s).

**Deliverable**: An edited `session_history.tmux` in which line 55 reads
`    tmux set-option -g '@session-history-dwell-ms' 30000` instead of `... 10000`. Exactly one
literal is changed. No lines added or removed. No other file touched.

**Success Definition**:
1. `bash -n session_history.tmux` exits 0.
2. `shellcheck` reports **no new diagnostics** vs. a pre-edit baseline.
3. `grep -n '10000' session_history.tmux` → **zero matches**.
4. `grep -n "set-option -g '@session-history-dwell-ms' 30000" session_history.tmux` → **exactly 1 match**
   (line 55).
5. Behavioral (Level 3 real-tmux test): the entry-point's defaulting conditional writes `30000` to
   the global option when it is unset, and **leaves a user-set value untouched** (including `"0"` and
   `"5000"`) — the "if unset" guard (PRD §16) is preserved.
6. Line 54 (the `[ -z "$(get_tmux_option …)" ] && \` conditional) and line 53 (the
   `# Default the dwell threshold once …` comment) are **byte-identical** to pre-edit.
7. File line count is unchanged (the edit is a value replacement, ±0 lines; file = 88 lines).

## User Persona (if applicable)

**Target User**: tmux-session-history end user who has not set `@session-history-dwell-ms`.

**Use Case**: A user loads the plugin without configuring dwell. The entry point seeds the global
option with the spec default so the engine's walk-dwell timer arms for the correct threshold.

**User Journey**: User starts tmux / sources the plugin → `session_history.tmux` runs → the
`[ -z … ] && tmux set-option` block sees `@session-history-dwell-ms` is empty → writes `30000` to
the global option → later, when the user walks (back/forward) to a session and stays there silently,
`arm_dwell` reads the option (`30000`) and arms a 30 s timer → after 30 s with no switch, the session
is promoted in the relevance list.

**Pain Points Addressed**: Today the load-time default is 10 s, which (a) contradicts the PRD spec
(§15/§16/§3.4: 30000) and (b) is too aggressive — brief silent pauses while walking past sessions
would over-promote them. The PRD-chosen 30 s reflects "you actually stayed to work," not "you paused
to glance." Getting the entry-point write right is what changes the *observed global default* for
users who never touch the option.

## Why

- **Spec compliance.** PRD §16 explicitly states *"The entry script also defaults
  `@session-history-dwell-ms` to `30000` if unset."* §15 and §3.4 both list the default as `30000`.
  The entry script currently writes `10000` — a pre-PRD legacy value. The PRD contains **zero**
  occurrences of `10000` (grep-verified). This task eliminates that legacy value from the entry point.
- **Cross-file consistency (the entry-point leg).** Four sources define the dwell default and must all
  agree on `30000`: the engine fallback `dwell_ms()` (**T3.S1 — Complete**, now echoes 30000), the
  entry-point write (**THIS task**), the README Options table (**M3.T2.S1**), and the engine header
  comment (**T4**). This task is the **entry-point leg**.
- **Complementarity with the engine fallback.** The entry point is the *authoritative load-time
  default* (writes `30000` once at load if unset); `dwell_ms()` is the *runtime safety net* (returns
  `30000` if the option is empty/non-numeric at WALK time). After both land, a fresh load with no user
  setting makes the global option `"30000"`, and even a later `tmux set-option -gu` is still caught by
  the engine fallback. Fully redundant and consistent.
- **User-noticeable behavior shift.** 10 s → 30 s meaningfully changes how long a silent walk must
  persist before promotion. It is a deliberate product decision encoded in the PRD.

## What

Change exactly one literal on one line of `session_history.tmux`.

### The current two-line block (lines 54–55; it is ONE statement — line 54 ends in `\`)

```bash
[ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
    tmux set-option -g '@session-history-dwell-ms' 10000
```

### The target block (after this task — ONLY line 55's literal changes)

```bash
[ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
    tmux set-option -g '@session-history-dwell-ms' 30000
```

Semantics of the conditional (unchanged in structure — only the written literal changes):

| State of `@session-history-dwell-ms` at load | `[ -z … ]` | action | resulting global option |
|----------------------------------------------|-----------|--------|--------------------------|
| unset / empty                                | true      | **write `30000`** | `30000` (was 10000) |
| `"0"`                                        | false     | no write | `0` (preserved — dwell disabled) |
| `"5000"`, `"30000"`, `"120000"` (numeric)    | false     | no write | the user's value (preserved) |
| `"abc"`, `"3.5"` (non-numeric)               | false     | no write | the user's value (engine `dwell_ms()` later normalizes non-numeric → 30000 at runtime) |

> The entry point guards on **empty only** (`-z`), matching PRD §16's *"if unset"*. It deliberately
> does NOT overwrite a non-empty value even if non-numeric — the engine's `dwell_ms()` fallback
> (T3.S1) handles non-numeric normalization at runtime. The two layers are complementary, not
> identical. We change only the written literal.

### Success Criteria

- [ ] The literal `10000` no longer appears anywhere in `session_history.tmux`.
- [ ] Line 55 reads `tmux set-option -g '@session-history-dwell-ms' 30000`.
- [ ] `bash -n` passes; `shellcheck` introduces no new diagnostics.
- [ ] Level 3 real-tmux test: unset option → conditional writes `30000`; user-set value (`5000`, `0`)
      → preserved (not overwritten).
- [ ] File line count is unchanged (no lines added/removed; stays 88).
- [ ] Line 54 conditional and line 53 comment are byte-identical to pre-edit.
- [ ] No other file is modified.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact current two-line block (lines 53–55) and the exact target
block; the exact `oldText`/`newText` pair for the `edit` tool (the full line-55 content, which is
unique in the file); the full semantics table for every option-state at load (including the `"0"`
and `"5000"` preservation cases and the non-numeric handoff to the engine); the
`get_tmux_option` helper definition (line 20) so the implementer understands the `-z` test; the
cross-file ownership map so the implementer does not over-reach into T4/M3/S2; the parallel/sibling
boundaries (S2 edits lines 70–83 on the same file, but disjoint from line 55; T4.S2 is on a
*different* file); and deterministic Level 1–3 validation including a **real tmux 3.6a integration
test** that exercises the entry-point's exact defaulting conditional against a throwaway socket.
An implementer with zero prior knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authoritative load-time default and the exact "if unset" semantics
- docfile: PRD.md
  section: "§16. Hook & binding reference (PRD.md:487)"
  why: "PRD §16 is the single source of truth for the entry-point defaulting behavior: 'The entry
        script also defaults @session-history-dwell-ms to 30000 if unset'. The phrase 'if unset' maps
        exactly onto the line-54 `[ -z ... ] &&` guard. This is the authority for changing the written
        literal on line 55 from 10000 to 30000 while leaving the conditional untouched."
  critical: "'if unset' = empty-string test (the -z guard), NOT 'if non-numeric'. The entry point
             must NOT overwrite a user's non-empty value even if it is non-numeric; the engine
             dwell_ms() (T3.S1) normalizes non-numeric at runtime. Only the literal changes."

# MUST READ — the default value
- docfile: PRD.md
  section: "§15. Configuration reference (PRD.md:460)"
  why: "Row: | @session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables dwell. |.
        This is the target default value (30000), replacing the legacy 10000."
  critical: "The PRD NEVER mentions 10000 anywhere (0 grep hits across the whole spec). 30000 is the
             only spec-sanctioned default. §3.4 (PRD.md:112) repeats the same row verbatim."

# MUST READ — how the written default flows into the timer at runtime
- docfile: PRD.md
  section: "§8. Dwell → Arming (PRD.md:253) and §14 Invariants (PRD.md:442/444)"
  why: "arm_dwell reads: ms = dwell_ms(); if ms <= 0: return; sec = max(1, ms/1000); tmux run-shell -b
        'sleep ${sec}; ...'. So a written default of 30000 → the engine reads '30000' (numeric) on the
        *) passthrough branch → sleep 30. §14 confirms '0' short-circuits (arm_dwell returns
        immediately) and non-numeric → 30000. This is why the entry-point write of 30000 fully
        realizes the spec for the common unset-option case."
  critical: "The entry-point write and the engine fallback are COMPLEMENTARY. Entry point writes
             30000 once at load if the option is empty; dwell_ms() returns 30000 at runtime if the
             option is empty/non-numeric. Both now agree on 30000 (T3.S1 is Complete)."

# The decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 2 — DWELL DEFAULT must be 30000, currently 10000 (PRD §15) → row 2b"
  why: "GAP 2b (verbatim): 'session_history.tmux:55 | tmux set-option -g @session-history-dwell-ms
        10000 | 🔴 change 10000 → 30000'. GAP 2a = engine (T3.S1, DONE). GAP 2c = line-58 engine
        header comment (T4). GAP 2d = README.md:86 (M3.T2.S1). This PRP == GAP 2b only."
  critical: "GAP 8a (same file, line 55) is the SAME edit as GAP 2b — the gap analysis lists the
             line-55 dwell default under both GAP 2 (dwell default) and GAP 8 (entry-point activity
             removal) because line 55 sits in the entry script. Both resolve to: 10000 → 30000. Do not
             double-edit. GAP 8b/8c (focused-activity block + bootstrap comment) are S2, NOT this task."

# The file under edit
- file: session_history.tmux
  why: "The ONLY file this task modifies. Bash entry point, shebang #!/usr/bin/env bash. The dwell
        defaulting block is lines 53–55: line 53 = comment, line 54 = the `[ -z ... ] && \\` guard
        (with a trailing backslash line-continuation onto line 55), line 55 = the set-option write.
        get_tmux_option() is defined at line 20 (reads `tmux show-option -gqv $1`; returns it if
        non-empty else returns the given default `$2`). The option is set by NO other line in the file."
  pattern: "All option defaults in this entry script use the same idiom: read via get_tmux_option, then
            conditionally write with `[ -z ... ] && tmux set-option -g`. The toggle/back/forward/pick
            keys (lines 48–51) read with default ''; the dwell default (lines 54–55) is the only place
            that WRITEs a numeric default. Match this idiom exactly — only the numeric literal changes."
  gotcha: "Lines 54–55 are a SINGLE statement (line 54 ends in backslash-newline continuation). The
           edit MUST change only the literal on line 55; do NOT touch the line-54 guard or remove the
           backslash, or the statement breaks. The line-53 comment ('Default the dwell threshold once
           (user can override before or after load).') mentions no number and stays accurate — leave it."

# The engine-leg partner (CONTRACT — already landed)
- docfile: plan/001_ca41c05f3ead/P1M1T3S1/PRP.md
  why: "T3.S1 changed the engine dwell_ms() fallback 10000 → 30000 and is Complete (verified: line 134
        now echoes 30000). This task is the entry-point leg of the same four-way alignment. After both,
        the load-time write and the runtime fallback both say 30000."
  critical: "T3.S1 is DONE. Do not re-edit scripts/session_history.sh. This task is session_history.tmux
             ONLY. The README leg (M3.T2.S1) and header-comment leg (T4) are still pending — leave them."

# The sibling entry-point task (CONTRACT — same file, disjoint region)
- docfile: plan/001_ca41c05f3ead/P1M2T1S1/PRP.md
  section: "Scope boundaries vs P1.M2.T1.S2"
  why: "S2 edits session_history.tmux too, but DISJOINT regions: the focused-activity comment block
        (lines 70–77, DELETE) and the bootstrap comment (lines 79–83, REWRITE). Both are BELOW and
        textually separate from line 55. Clean merge in either order: S1 is ±0 lines (S2's line numbers
        70–83 unchanged); S2 is net-negative but only shifts lines BELOW 70 (line 55 is above)."
  critical: "Anchor on the full line-55 TEXT, never on 'line 55'. The line-55 content is unique in the
             file (only one `set-option -g '@session-history-dwell-ms'` line). S2 does not touch it."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §15/§16/§3.4/§8/§14 authorize 30000
├── README.md                   # docs (NOT this task — M3.T2.S1 owns the 10000 at line 86)
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — dwell_ms() fallback ALREADY 30000 (T3.S1 Complete)
├── session_history.tmux        # ← THE FILE TO EDIT (88 lines)
│                                #     line 20  = get_tmux_option() definition
│                                #     line 53  = comment '# Default the dwell threshold once ...' (KEEP)
│                                #     line 54  = `[ -z ... ] && \` guard (KEEP byte-identical)
│                                #     line 55  = set-option write (THIS TASK: 10000 → 30000)
│                                #     lines 70–77 = focused-activity comment block (S2 — DO NOT TOUCH)
│                                #     lines 79–83 = bootstrap comment (S2 — DO NOT TOUCH)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md   # ← GAP 2b / 8a (this task)
        ├── P1M1T3S1/PRP.md                # ← engine leg (Complete)
        └── P1M2T1S1/
            ├── PRP.md                     # ← THIS task
            └── research/dwell_default_verification.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only session_history.tmux is modified, and ONLY the literal on line 55.
# After this task the file is still 88 lines (±0). Line 55 writes 30000 as the load-time default.
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — lines 54–55 are ONE statement. Line 54 ends in a backslash line-continuation (`\`).
# The edit changes ONLY the literal on line 55 (10000 → 30000). Do NOT touch the backslash, the
# `[ -z ... ]` guard, or the `&&`. Removing/altering the guard would break the "if unset" semantics
# (it would unconditionally overwrite the user's value on every reload).

# CRITICAL — the guard is `-z` (empty test), matching PRD §16 "if unset". It does NOT overwrite a
# non-empty value, even a non-numeric one. That is intentional: the engine dwell_ms() (T3.S1)
# normalizes non-numeric → 30000 at runtime. The two layers are complementary. Do NOT "improve" the
# guard to also clobber non-numeric values — that is out of scope and would surprise users who set a
# sentinel.

# GOTCHA — line 53 comment ('# Default the dwell threshold once (user can override before or after
# load).') mentions NO number. It stays accurate after the change. LEAVE IT byte-identical.

# GOTCHA — line numbers under sibling execution. S2 (same file) edits lines 70–83, BELOW line 55; its
# edit is net-negative (deletes ~8 lines). If S2 lands first, lines below 70 shift but line 55 is
# stable (above 70). T4.S2 (currently implementing) is on a DIFFERENT file (scripts/session_history.sh)
# — no collision at all. ALWAYS anchor on the full line-55 TEXT, not the line number.

# GOTCHA — no test framework in this repo (no bats/spec/Makefile). Validation uses bash -n, shellcheck
# (present), and a real tmux 3.6a integration test against a throwaway `tmux -L` socket (see Level 3).

# GOTCHA — get_tmux_option (line 20) shells out to `tmux show-option -gqv "$1"`. In the Level 3 test
# we replicate the conditional with `tmux -L SOCK` so it targets the throwaway server; the entry
# script's real helper has no socket arg (it talks to the default server). The test is a faithful
# behavioral mirror of the conditional, not a re-execution of the whole plugin.

# GOTCHA — the literal `10000` appears EXACTLY ONCE in session_history.tmux (line 55; grep-verified).
# After this task `grep -c 10000 session_history.tmux` must be 0. There is no comment in the entry
# script that references the numeric default, so unlike the engine file (which has a line-58 comment
# still saying 10000, owned by T4), here the literal is the ONLY occurrence — a clean zero after edit.
```

## Implementation Blueprint

### Data models and structure

None. This is a pure literal-value change in a conditional option-write at plugin load. No data
models, no schemas, no types beyond the existing string `@session-history-dwell-ms` option.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE a pre-edit shellcheck baseline + line count (no source edits)
  - RUN: shellcheck session_history.tmux > /tmp/sc_before_m2t1s1.txt 2>&1; echo "baseline exit: $?"
  - RUN: before=$(wc -l < session_history.tmux); echo "pre-edit lines = $before"   # expect 88
  - RUN: sed -n '53,55p' session_history.tmux > /tmp/dwell_block_before.txt       # the 3-line block (KEEP 53,54)
  - WHY: this task's shellcheck gate is "no NEW diagnostics"; the file may carry pre-existing SC
         warnings (the gap analysis did not clean them). The 3-line snapshot is a regression guard so
         you can prove you edited ONLY line 55 (lines 53 and 54 must be byte-identical after).

Task 2: EDIT the dwell default literal (single exact-text replacement)
  - USE the `edit` tool with this oldText/newText (match the FULL line-55 content so the edit is
    unique and the line-54 guard / line-53 comment cannot be touched):
      oldText:  "    tmux set-option -g '@session-history-dwell-ms' 10000"
      newText:  "    tmux set-option -g '@session-history-dwell-ms' 30000"
    (i.e. the ONLY difference is 10000 → 30000. The line begins with exactly 4 spaces of indent.)
  - ANCHOR on the full line-55 text, NOT the line number (S2 edits the same file below line 55;
    T4.S2 edits a different file — both are robust to text-matching).
  - PRESERVE byte-for-byte: line 53 comment, line 54 `[ -z "$(get_tmux_option …)" ] && \` guard
    (including the trailing backslash continuation).
  - DO NOT TOUCH: any other line, the get_tmux_option definition (line 20), the toggle block, the
    hooks, the focused-activity comment block (70–77, S2), the bootstrap comment (79–83, S2).

Task 3: VERIFY parse (no edits)
  - RUN: bash -n session_history.tmux && echo "PARSE OK" || echo "PARSE FAIL"
  - EXPECTED: PARSE OK (exit 0). A one-literal change cannot break parsing; this is a smoke check.

Task 4: VERIFY the literal swap + lint delta + line count (no edits)
  - RUN: grep -n '10000' session_history.tmux
    EXPECTED: ZERO output (the legacy literal is gone from the entry script).
  - RUN: grep -n "set-option -g '@session-history-dwell-ms' 30000" session_history.tmux
    EXPECTED: exactly 1 line — line 55.
  - RUN: shellcheck session_history.tmux > /tmp/sc_after_m2t1s1.txt 2>&1
  - RUN: diff <(sort /tmp/sc_before_m2t1s1.txt) <(sort /tmp/sc_after_m2t1s1.txt)
    EXPECTED: no diff (a literal change in a set-option argument introduces no shellcheck diagnostic).
  - RUN: after=$(wc -l < session_history.tmux); echo "post-edit lines = $after"
    EXPECTED: EQUAL to $before (88). The edit is ±0 lines. Any delta = accidental line add/remove — revert.
  - RUN: diff /tmp/dwell_block_before.txt <(sed -n '53,55p' session_history.tmux)
    EXPECTED: a 2-line diff showing ONLY line 55 changed (10000 → 30000); lines 53 and 54 identical.

Task 5: VERIFY behavior with a real tmux integration test (Level 3, no edits)
  - RUN the Level 3 block in the Validation Loop. It replicates the entry-point's EXACT defaulting
    conditional against a throwaway `tmux -L` socket and asserts all three option-state cases.
    EXPECTED: all 3 OK (unset → 30000; user 5000 → preserved; user 0 → preserved).
```

### Implementation Patterns & Key Details

```bash
# The dwell defaulting block (lines 54–55) is ONE statement via backslash-continuation:
#
#   [ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
#       tmux set-option -g '@session-history-dwell-ms' 30000     # after this task
#
# get_tmux_option (line 20):
#   get_tmux_option() {
#       local value
#       value="$(tmux show-option -gqv "$1")"
#       [ -n "$value" ] && echo "$value" || echo "$2"
#   }
# Called with default '' → returns the option value if set+non-empty, else ''. So `[ -z ... ]` is
# true ONLY when the option is unset/empty → the write fires ONLY then. This is PRD §16 "if unset".

# How the written default flows into the timer (cross-file, for context — NOT edited here):
#   At load: option empty → entry point writes '30000' to the global option.
#   At a WALK: arm_dwell() -> ms="$(dwell_ms)"; dwell_ms() reads '30000' (numeric) -> *) branch
#              echoes '30000' -> sec=max(1,30000/1000)=30 -> tmux run-shell -b 'sleep 30; ... dwell'.
#   If the user later clears the option: dwell_ms() falls back to 30000 (T3.S1). Consistent.

# Why the guard is -z (empty) and not a non-numeric check:
#   PRD §16 says "if unset". The engine dwell_ms() (T3.S1) already normalizes non-numeric -> 30000 at
#   runtime via its case glob (''|*[!0-9]*). The entry point need only seed the empty case; clobbering
#   a user's explicit non-empty value on every reload would be surprising. So only the literal changes.
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin; no DB.

CONFIG (tmux global user options):
  - @session-history-dwell-ms: WRITTEN by the entry point (line 55) once at load IF currently empty.
        This task changes the written value 10000 -> 30000. READ by the engine dwell_ms() (T3.S1, done)
        on every WALK. After both land, an unset option is written 30000 at load AND falls back to 30000
        in the engine — fully consistent.
  - No other option is changed. The toggle/back/forward/pick keys (lines 48–51) and the
        @session-history-toggle-enabled flag (lines 57–62) are untouched.

ROUTES / DISPATCH:
  - none changed. The entry point sets hooks/keys/init; no subcommand dispatch is touched. This is a
        one-literal change to a load-time default write.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit shellcheck baseline + line count (run BEFORE editing):
shellcheck session_history.tmux > /tmp/sc_before_m2t1s1.txt 2>&1; echo "baseline exit: $?"
before=$(wc -l < session_history.tmux); echo "pre-edit lines = $before"   # expect 88
sed -n '53,55p' session_history.tmux > /tmp/dwell_block_before.txt

# 1. Parse check (run AFTER the single edit):
bash -n session_history.tmux && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0).

# 2. Lint delta (run AFTER editing):
shellcheck session_history.tmux > /tmp/sc_after_m2t1s1.txt 2>&1
diff <(sort /tmp/sc_before_m2t1s1.txt) <(sort /tmp/sc_after_m2t1s1.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: empty diff (a literal change in a set-option argument introduces no shellcheck diagnostic).

# 3. Line-count is unchanged (capture before & after within THIS task):
after=$(wc -l < session_history.tmux)
[ "$before" = "$after" ] && echo "LINE COUNT UNCHANGED ($after)" || echo "LINE COUNT CHANGED: $before -> $after"
# Expected: LINE COUNT UNCHANGED (88). Any delta = accidental line add/remove — revert.
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo. These grep/diff proofs pin down the exact literal swap and prove
lines 53–54 were not collateral damage.

```bash
# A. The legacy literal is gone from the entry script:
grep -n '10000' session_history.tmux
# Expected: NO output (zero matches). [Unlike the engine file, NO comment here references 10000.]

# B. The new literal is present exactly once, on the set-option line:
grep -n "set-option -g '@session-history-dwell-ms' 30000" session_history.tmux
# Expected: exactly 1 line — line 55.

# C. The 3-line block changed ONLY on line 55; lines 53 (comment) and 54 (guard) are byte-identical:
diff /tmp/dwell_block_before.txt <(sed -n '53,55p' session_history.tmux)
# Expected: a 2-line diff: one '-' line with '... 10000' and one '+' line with '... 30000'.
#           Lines 53 and 54 must NOT appear in the diff. If they do, you over-reached — revert.

# D. The guard (line 54) and its backslash continuation are intact:
sed -n '54p' session_history.tmux
# Expected exactly:  [ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
# (note the trailing backslash). If the backslash is gone, the statement is broken — revert.

# E. The get_tmux_option helper and the toggle/key blocks are untouched (scope guard):
grep -c 'get_tmux_option()' session_history.tmux   # Expected: 1 (definition still present)
grep -c "set-option -g '@session-history-toggle-enabled'" session_history.tmux  # Expected: 2 (on/off, untouched)
```

### Level 3: Integration Testing (System Validation — real tmux 3.6a)

This is the **behavioral proof**. It replicates the entry-point's *exact* defaulting conditional
against a throwaway `tmux -L` socket (so it does not touch the user's real tmux server or run the
whole plugin, which would set hooks / bind keys / run init). It asserts the three option-state cases.

```bash
if ! command -v tmux >/dev/null; then
  echo "tmux not installed — skipping L3 tmux probe (Level 2 already proves the literal swap)."
  exit 0
fi

SOCK=m2t1s1
tmux -L "$SOCK" kill-server 2>/dev/null
tmux -L "$SOCK" new-session -d -s probe 2>/dev/null

# Mirror get_tmux_option + the line-54/55 conditional, pointed at the throwaway server via -L.
get_tmux_option_L() {  # $1 = option, $2 = default
    local value; value="$(tmux -L "$SOCK" show-option -gqv "$1")"
    [ -n "$value" ] && echo "$value" || echo "$2"
}
default_dwell_L() {  # the line-54/55 conditional, faithfully replicated
    [ -z "$(get_tmux_option_L '@session-history-dwell-ms' '')" ] && \
        tmux -L "$SOCK" set-option -g '@session-history-dwell-ms' 30000
}

pass=0; fail=0
case_check() {  # case_check <setup> <expected_after>
    tmux -L "$SOCK" set-option -gu '@session-history-dwell-ms' 2>/dev/null   # clear first
    [ -n "$1" ] && tmux -L "$SOCK" set-option -g '@session-history-dwell-ms' "$1"
    default_dwell_L   # run the replicated entry-point conditional
    got="$(tmux -L "$SOCK" show-option -gv '@session-history-dwell-ms')"
    if [ "$got" = "$2" ]; then echo "OK   $3 (input='${1:-<unset>}' -> $got)"; pass=$((pass+1))
    else echo "FAIL $3 (input='${1:-<unset>}' expected='$2' got='$got')"; fail=$((fail+1)); fi
}

case_check ''     '30000' 'unset/empty -> entry point writes 30000 (PRD §16 "if unset") *** core case ***'
case_check '5000' '5000'  'user override -> preserved (guard is -z, NOT overwritten)'
case_check '0'    '0'     'user 0 -> preserved (dwell-disabled sentinel, NOT clobbered to 30000)'

echo "---"; echo "PASS=$pass FAIL=$fail"
tmux -L "$SOCK" kill-server 2>/dev/null
[ "$fail" = 0 ] && echo "ALL ENTRY-POINT DEFAULT CASES OK" || { echo "SOME CASES FAILED"; exit 1; }
# Expected: PASS=3 FAIL=0.
#   - '' -> 30000  proves the new default is written when the option is unset.
#   - '5000' -> 5000  proves the -z guard does NOT overwrite a user value.
#   - '0' -> 0  proves the dwell-disable sentinel survives a reload (critical regression guard).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# A. The change is minimal and scoped in git:
git diff --stat session_history.tmux
# Expected: a single file, exactly +1/-1 within line 55 only.

git diff session_history.tmux
# Manually confirm the diff touches ONLY line 55:
#   - one '-' line: "     tmux set-option -g '@session-history-dwell-ms' 10000"
#   - one '+' line: "     tmux set-option -g '@session-history-dwell-ms' 30000"
#   - NOTHING else. Any changed line outside line 55 = over-reach OR a collision with S2's parallel
#     edit. If you see focused-activity-block (70–77) or bootstrap-comment (79–83) changes, that is
#     S2's work — coordinate/rebase, do not commit both under this task's description.

# B. Cross-file consistency: after this task, BOTH default sources agree on 30000.
echo "entry-point write : $(grep -o "dwell-ms' [0-9]*" session_history.tmux)"
echo "engine fallback   : $(grep -o 'echo [0-9]*' scripts/session_history.sh | head -1)"
# Expected:
#   entry-point write : dwell-ms' 30000
#   engine fallback   : echo 30000
# (T3.S1 is Complete; this confirms the entry-point leg now matches it.)

# C. The PRD contains zero occurrences of 10000 (informational — the value we removed is spec-banned):
grep -c '10000' PRD.md   # Expected: 0

# D. Remaining known-pending 10000 occurrences (NOT this task — informational only):
grep -n '10000' README.md               # line 86 -> M3.T2.S1
grep -n '10000' scripts/session_history.sh   # header comment -> T4 (T4.S1 done; verify current state)
# These are EXPECTED to still show 10000 after THIS task. They are separate work items.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n session_history.tmux` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_m2t1s1.txt`
      (sorted diff is empty).
- [ ] `wc -l session_history.tmux` is **unchanged** vs. this task's own pre-edit baseline (88).
- [ ] `grep -n '10000' session_history.tmux` → zero matches.
- [ ] `grep -n "set-option -g '@session-history-dwell-ms' 30000" session_history.tmux` → exactly 1 match (line 55).

### Feature Validation

- [ ] Level 3 real-tmux test reports `PASS=3 FAIL=0`, including the `'' → 30000` core case and the
      `'5000' → 5000` / `'0' → 0` preservation guards.
- [ ] The entry point writes `30000` to the global option when it is unset (PRD §16 "if unset").
- [ ] The `-z` guard leaves a user-set value untouched (including `"0"` and `"5000"`).
- [ ] Cross-file consistency: entry-point write (`30000`) matches engine fallback `dwell_ms()` (`30000`, T3.S1).

### Code Quality Validation

- [ ] The diff touches ONLY line 55 (single `10000` → `30000`).
- [ ] Line 54 (`[ -z … ] && \` guard, incl. backslash continuation) is byte-identical to pre-edit.
- [ ] Line 53 comment (`# Default the dwell threshold once …`) is byte-identical to pre-edit.
- [ ] No re-formatting, no "drive-by" fixes, no guard/glob changes.
- [ ] Edit is anchored on the full line-55 text (robust to S2's parallel line shifts below line 55).

### Documentation & Deployment

- [ ] No documentation changes in this task (README is M3.T2.S1; engine header comments are T4).
      The line-53 comment mentions no number and stays accurate — no edit.
- [ ] No new environment variables or options.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT touch line 54** (the `[ -z "$(get_tmux_option …)" ] && \` guard) or its trailing backslash.
  It is the "if unset" semantics (PRD §16). Altering it would either break the statement (remove `\`)
  or unconditionally clobber the user's value on every reload. Only line 55's literal changes.
- ❌ **Do NOT "also fix" `scripts/session_history.sh` or `README.md`.** The engine leg is T3.S1
  (**Complete**); the README leg is M3.T2.S1; the engine header comment is T4. This task is the
  entry-point literal ONLY. Re-editing the engine file collides with T4.S2 (currently implementing
  there).
- ❌ **Do NOT "improve" the guard to also overwrite non-numeric values.** The `-z` (empty) test is
  intentional and matches PRD §16 "if unset". The engine `dwell_ms()` (T3.S1) normalizes non-numeric
  at runtime. Clobbering a user's explicit non-empty value would surprise them.
- ❌ **Do NOT edit the line-53 comment.** It mentions no number ("Default the dwell threshold once …")
  and stays accurate after the change. Any comment edit is scope creep.
- ❌ **Do NOT edit the focused-activity comment block (lines 70–77) or bootstrap comment (79–83).**
  Those are **S2** on the same file. This task is line 55 ONLY. (GAP 8b/8c = S2; this task is GAP 2b/8a.)
- ❌ **Do NOT key the edit on the hard line number `55`.** S2 edits the same file below line 55 (net
  negative); T4.S2 edits a different file. Match the full line-55 **text**, which is unique.
- ❌ **Do NOT add lines / reformat / split the two-line statement.** It must remain lines 54–55 as-is
  (one backslash-continued statement) so the diff is trivially `+1/-1` and merges cleanly with S2.
- ❌ **Do NOT run the whole plugin as the integration test.** Sourcing `session_history.tmux` against a
  throwaway server would set global hooks, bind keys, and run `init` — side effects you do not want.
  The Level 3 test replicates ONLY the defaulting conditional (faithful behavioral mirror).

---

## Scope Boundaries (one-screen reference)

| Item | This task (M2.T1.S1)? | Owner |
|------|:---:|-------|
| Line 55 dwell write `10000` → `30000` | ✅ | M2.T1.S1 (GAP 2b / 8a) |
| Keep line 54 `[ -z … ] && \` guard byte-identical | ✅ (preserve) | M2.T1.S1 |
| Keep line 53 comment byte-identical | ✅ (preserve) | M2.T1.S1 |
| Lines 70–77 focused-activity comment block (DELETE) | ❌ | **M2.T1.S2** (GAP 8b) |
| Lines 79–83 bootstrap comment (REWRITE) | ❌ | **M2.T1.S2** (GAP 8c) |
| `scripts/session_history.sh` dwell_ms() fallback | ❌ | **T3.S1** (Complete — already 30000) |
| `scripts/session_history.sh` header comment `10000` | ❌ | **T4** |
| `README.md:86` Options table `10000` → `30000` | ❌ | **M3.T2.S1** |
| `README.md:119` (already "default 30 s") | ❌ | already correct |
| `get_tmux_option()` definition / toggle block / hooks | ❌ | out of scope (preserve) |

---

## Confidence Score

**10/10** for one-pass success. This is a single-literal change (`10000` → `30000`) on a unique line
with: the exact `oldText`/`newText` pair supplied (the full line-55 content, unique in the file); the
full option-state semantics table (including the `"0"` / `"5000"` preservation guards and the
non-numeric handoff to the engine); a real tmux 3.6a Level 3 integration test that replicates the
entry-point's exact defaulting conditional against a throwaway socket and asserts all three cases;
deterministic grep proofs (the literal is the ONLY `10000` in the entry script — a clean zero after
edit, unlike the engine file which still has a T4-owned comment); a byte-identical guard for lines
53–54; a line-count-neutrality assertion; cross-file consistency confirmation (T3.S1 is Complete at
30000); and an explicit scope map separating M2.T1.S1 from M2.T1.S2 (same file, disjoint region
70–83), T3.S1 (engine, done), T4 (header comment), and M3.T2.S1 (README). No ambiguity, no hidden
dependencies, no behavioral surprise beyond the intended load-time default shift. The engine leg is
already done, so after this task the two runtime-relevant default sources fully agree on 30000.