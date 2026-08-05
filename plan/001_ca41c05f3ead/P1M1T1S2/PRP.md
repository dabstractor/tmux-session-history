name: "P1.M1.T1.S2 — Remove activity/poller case-dispatch branches and update Usage string"
description: "Pure bash case-dispatch + Usage-string edit. Delete the two dead `activity)`/`poller)` case branches (left behind after S1 deleted their function bodies) and strip `activity|poller|` from the Usage string so the engine's subcommand surface exactly matches PRD §17's 11-command list. Touches ONLY the dispatch/Usage region of scripts/session_history.sh. Depends on S1 having landed (file is 564 lines, line numbers below are POST-S1)."

---

## Goal

**Feature Goal**: Remove the `activity)` and `poller)` branches from the `case "$cmd" in`
dispatch at the bottom of `scripts/session_history.sh`, and remove the `activity|poller|`
tokens from the Usage string, so the engine exposes exactly PRD §17's 11 subcommands and
**no runtime path can invoke the functions S1 deleted.**

**Deliverable**: An edited `scripts/session_history.sh` whose `case` block contains exactly
11 command branches (`init hook dwell prune maintain toggle back forward pick status reset`)
plus the `*)` catch-all, and whose Usage string reads exactly:
`Usage: $0 {init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset} [session]`

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0.
2. `shellcheck scripts/session_history.sh` reports no NEW diagnostics vs. a pre-S2 baseline.
3. `grep -nE 'activity|poller' scripts/session_history.sh` over the dispatch+Usage region
   (post-S2 ~546–562) returns **nothing**. (Header-comment mentions at lines 89–97 remain
   and are T4 scope — NOT touched here.)
4. The 11 surviving case branches match PRD §17's order exactly.
5. File line count is **562** (post-S1 564 − 2 deleted branches).
6. No other line is modified (diff is "pure red" for the 2 deletions + a single-line edit
   for the Usage token removal).

## Why

S1 deleted the *bodies* of `do_activity()`, `do_poller()`, and `do_start_poller()`, but
deliberately left their **call sites** intact (the two `case` branches and the
`do_start_poller` call inside `do_init`). Those call sites now reference undefined
functions — they would fail at runtime if invoked. This task (S2) removes the two
`case`-dispatch branches so no external `session_history.sh activity`/`poller` invocation
can reach the deleted code. The `do_init` poller-start call is a separate task (T2.S1).

PRD §17 is the authoritative subcommand surface: exactly `init, hook, dwell, prune,
maintain, toggle, back, forward, pick, status, reset`. PRD §12 explains why activity
detection is not wired at all. The current `activity)`/`poller)` branches are the two
extra commands the PRD rejects.

This is a **pure deletion + one string edit**: no logic, no refactor, no new code.

## What

Two whole-line deletions and one substring removal, all inside the existing
`case "$cmd" in ... esac` block at the bottom of `scripts/session_history.sh`.

### Success Criteria

- [ ] The `activity)` case branch line is deleted.
- [ ] The `poller)` case branch line is deleted.
- [ ] The Usage string's `{...}` token list no longer contains `activity` or `poller`.
- [ ] The resulting Usage string reads exactly
      `{init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset}` (11 tokens).
- [ ] `bash -n scripts/session_history.sh` passes.
- [ ] `shellcheck` introduces zero new diagnostics vs. pre-S2 baseline.
- [ ] The 3-line locking comment (old 636–638 → post-S1 550–552, sitting just above the
      deleted `activity)` branch) is **unchanged**.
- [ ] The `do_start_poller` call inside `do_init` (post-S1 ~520) is **unchanged** — T2 scope.

## All Needed Context

### Context Completeness Check

Yes. This PRP gives the exact line numbers (POST-S1), the exact byte-for-byte content of
the two lines to delete and the one line to edit, the exact before/after substring for the
Usage string, the exact grep commands to prove success, and the exact sibling-task
boundaries (T2/T4) so the implementer neither over- nor under-deletes. No prior knowledge
of tmux or the engine internals is required.

### Documentation & References

```yaml
# MUST READ — the authoritative subcommand surface (the spec we're matching)
- docfile: PRD.md
  section: "§17. Subcommand reference"
  why: "Lists exactly 11 subcommands: init, hook, dwell, prune, maintain, toggle, back,
        forward, pick, status, reset. The engine must expose EXACTLY these, in this order.
        The Usage string token order must mirror this table."
  critical: "There is no `activity` or `poller` row. Those two branches are the gap."

# MUST READ — the reason activity/poller exist at all (and must die)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "Establishes that alert-activity fires only for BACKGROUND windows; no robust
        focused-activity primitive exists; therefore activity is NOT wired and relevance
        = selection + dwell only. do_activity/do_poller were the (now-removed) machinery
        for the rejected signal."
  critical: "Do not re-add activity/poller. The deletion is spec-mandated, not cosmetic."

# The analysis that decomposed the removal (READ for boundary clarity)
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 3 — SUBCOMMAND REFERENCE: remove `activity` and `poller` (PRD §17)"
  why: "Sub-items 3a/3b/3c are the EXACT scope of THIS PRP: case `activity)` (old 639),
        case `poller)` (old 640), and the Usage token removal (old 649). Confirms the
        result must equal PRD §17's 11-command list."
  critical: "GAP 3 == THIS task. GAP 1 (function bodies) == S1 (already landed).
             GAP 7 (do_init poller-start) == T2 (NOT this task)."

# The file under edit
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash,
        `set -u` at line 110. The case dispatch is the LAST executable construct before
        the file ends (no code after `esac`)."
  pattern: "The dispatch is a flat `case \"$cmd\" in` with one branch per line, 4-space
            indented, each ending in ` ;;`. Branches are separated only by newlines (no
            blank lines). A 3-line comment about locking sits between the `dwell)` branch
            and the (to-be-deleted) `activity)` branch — KEEP it."
  gotcha: "Removing whole branches from a case statement is 100% safe under `set -u` —
           no variable reads are introduced or removed. The only risk is a typo'd
           replacement of the Usage string leaving a stray `|` or mismatched brace; the
           exact-string spec below and the L4 grep check prevent that."

# The sibling PRP that defines the state this task starts from (CONTRACT)
- docfile: plan/001_ca41c05f3ead/P1M1T1S1/PRP.md
  why: "S1 deleted lines 320–405 (86 lines). After S1 the file is 564 lines and every
        line after 405 shifts up by exactly 86. The line numbers in THIS PRP are
        POST-S1 (already shifted). S1 also leaves the case branches + Usage + the
        do_init poller call intentionally in place for S2/T2."
  critical: "Do NOT re-derive line numbers from a pre-S1 checkout. S1 has landed; read
             the live file. The branch content (not line numbers) is the stable anchor."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY, do not edit)
├── README.md                   # docs (NOT this task — M3)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (564 lines after S1)
├── session_history.tmux        # entry point (NOT this task — M2)
└── plan/                       # planning artifacts (READ-ONLY)
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md   # ← read GAP 3 for scope
        └── P1M1T1S1/PRP.md                # ← the contract (S1 output)
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified.
# After this task it is 562 lines (was 564 post-S1): the two case branches are gone.
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL: This PRP runs AFTER S1. S1 deleted lines 320–405 of the original 650-line
# file (the do_activity/do_poller/do_start_poller bodies). After S1 the file is 564 lines
# and the case dispatch that was at old-line 632 now sits at ~line 546. Every "POST-S1"
# line number in this PRP already accounts for that −86 shift. The IMPLEMENTATION TASKS
# below key on stable TEXT ANCHORS, not line numbers, so they are robust to any minor
# drift if S1's seam blank-line handling differs slightly.

# GOTCHA (which lines to delete): The two branches to delete are the ones whose PATTERN
# is literally `activity)` and `poller)`:
#   POST-S1 ~553:  '    activity)  lock; load_alive; do_activity "$to"; unlock ;;'
#   POST-S1 ~554:  '    poller)    do_poller ;;           # long-running; ...'
# They are CONSECUTIVE. The line ABOVE them is a 3-line `# ...` comment about locking
# (KEEP it). The line BELOW them is `prune)` (KEEP it).

# GOTCHA (do NOT delete the comment): Immediately above `activity)` is a 3-line comment:
#       # Every mutating command holds the exclusive lock for its whole critical
#       # section, so concurrent async hooks (a close that also relocates the client
#       # fires prune + hook at once) cannot interleave their read-modify-writes.
# This comment is generic (about locking) and still fully accurate for the surviving
# branches. LEAVE IT. Your diff must not include it.

# GOTCHA (Usage string is ONE line): The `*)` catch-all is a single line. Edit it in
# place by removing the substring `activity|poller|` (with both pipes). Do NOT rewrite
# the whole branch, do NOT change the `>&2` redirect, the `exit 1`, or `[session]`.

# GOTCHA (shellcheck): shellcheck is installed (/usr/bin/shellcheck). A clean branch
# deletion + in-place string edit cannot add SC warnings. The pre-S2 baseline already
# includes warnings from unchanged code (gap analysis did not clean them). Your change
# must not ADD any. Capture baseline BEFORE editing (see L1).

# GOTCHA (set -u): Line 110 has `set -u`. Removing two case branches and editing a
# literal string in an echo introduces no new variable references, so set -u is not a
# concern for THIS change.

# GOTCHA (do NOT touch do_init): The do_start_poller CALL SITE inside do_init still
# exists after S1 (S1 only deleted the function DEFINITION, not its call sites).
# That call (post-S1 ~520) + its preceding comment are T2.S1 scope. Leave them. This
# task touches ONLY the case dispatch + Usage string.
```

## Implementation Blueprint

### Text-anchor view (POST-S1 line numbers; anchors are the stable key)

The region after S1 (file = 564 lines) looks like this (POST-S1 ~546–564):

```bash
case "$cmd" in
    # Every mutating command holds the exclusive lock for its whole critical
    # section, so concurrent async hooks (a close that also relocates the client
    # fires prune + hook at once) cannot interleave their read-modify-writes.
    init)      lock; load_alive; do_init; unlock ;;
    hook)      lock; load_alive; load; do_hook "$to"; unlock ;;
    dwell)     lock; load_alive; do_dwell "$to"; unlock ;;
    activity)  lock; load_alive; do_activity "$to"; unlock ;;            ← DELETE (Task 1)
    poller)    do_poller ;;           # long-running; locks per fire of do_activity   ← DELETE (Task 1)
    prune)     lock; load_alive; load; prune_dead; save; unlock ;;
    maintain)  lock; load_alive; do_maintain; unlock ;;
    toggle)    lock; load_alive; do_toggle "$to"; unlock ;;
    back)      lock; load_alive; do_back "$to"; unlock ;;
    forward)   lock; load_alive; do_forward "$to"; unlock ;;
    pick)      do_pick "$to" ;;        # self-manages the lock (releases before fzf)
    status)    do_status ;;            # read-only; no lock
    reset)     lock; do_reset; unlock ;;
    *) echo "Usage: $0 {init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;   ← EDIT (Task 2)
esac
```

### Expected POST-S2 region (~546–562, 562 lines total)

```bash
case "$cmd" in
    # Every mutating command holds the exclusive lock for its whole critical
    # section, so concurrent async hooks (a close that also relocates the client
    # fires prune + hook at once) cannot interleave their read-modify-writes.
    init)      lock; load_alive; do_init; unlock ;;
    hook)      lock; load_alive; load; do_hook "$to"; unlock ;;
    dwell)     lock; load_alive; do_dwell "$to"; unlock ;;
    prune)     lock; load_alive; load; prune_dead; save; unlock ;;
    maintain)  lock; load_alive; do_maintain; unlock ;;
    toggle)    lock; load_alive; do_toggle "$to"; unlock ;;
    back)      lock; load_alive; do_back "$to"; unlock ;;
    forward)   lock; load_alive; do_forward "$to"; unlock ;;
    pick)      do_pick "$to" ;;        # self-manages the lock (releases before fzf)
    status)    do_status ;;            # read-only; no lock
    reset)     lock; do_reset; unlock ;;
    *) echo "Usage: $0 {init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;
esac
```

That is exactly 11 branches (init, hook, dwell, prune, maintain, toggle, back, forward,
pick, status, reset) matching PRD §17, in order, plus the `*)` catch-all.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: DELETE the two case branches (activity) and (poller)) from scripts/session_history.sh
  - DELETE (whole line): the branch whose pattern is `activity)`
      exact line text:
        '    activity)  lock; load_alive; do_activity "$to"; unlock ;;'
  - DELETE (whole line): the branch whose pattern is `poller)`
      exact line text:
        '    poller)    do_poller ;;           # long-running; locks per fire of do_activity'
  - ANCHOR: these two lines are consecutive and sit between the `dwell)` branch above and
    the `prune)` branch below. Match by the unique substrings `activity)` and `poller)`,
    NOT by line number (line numbers shifted when S1 landed).
  - PRESERVE: the 3-line `# Every mutating command holds the exclusive lock ...` comment
    that sits above `init)`/the dispatch — do NOT delete it.
  - PRESERVE: the `prune)` branch that now directly follows `dwell)`.

Task 2: EDIT the Usage string in the `*)` catch-all line
  - FIND (exact substring inside the `{...}`): `activity|poller|`
  - REPLACE WITH: ``  (empty — remove the substring entirely)
  - BEFORE:  ...{init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset}...
  - AFTER:   ...{init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset}...
  - KEEP UNCHANGED: the leading `    *) echo "Usage: $0 ` and the trailing
    ` [session]" >&2; exit 1 ;;`
  - NAMING/ORDER: the 11 remaining tokens MUST stay in PRD §17 order
    (init, hook, dwell, prune, maintain, toggle, back, forward, pick, status, reset).
    Removing the middle `activity|poller|` substring already yields this order — verify.

Task 3: VERIFY parse + lint (no edits — just run the gates)
  - RUN: bash -n scripts/session_history.sh            (must exit 0)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after_s2.txt 2>&1; echo $?
  - COMPARE: post-S2 shellcheck output vs. a pre-S2 baseline captured before editing
    (see Validation Loop L1). Post-S2 must be <= baseline (no ADDED diagnostics).

Task 4: VERIFY removal + collateral with grep (no edits)
  - RUN: grep -nE 'activity|poller' scripts/session_history.sh
    EXPECTED: matches ONLY in the header-comment region (lines 89–97) and the
    do_start_poller call/comment inside do_init (~518–520). ZERO matches in the
    case-dispatch + Usage region (post-S2 ~546–562). If any `activity)`/`poller)` branch
    or any `activity|poller|` Usage token remains, you under-edited.
  - RUN: wc -l scripts/session_history.sh
    EXPECTED: 562  (post-S1 564 − 2 deleted branches).
  - RUN: grep -c 'do_hook()' scripts/session_history.sh    EXPECTED: 1
  - RUN: grep -c 'do_dwell()' scripts/session_history.sh   EXPECTED: 1
  - RUN: grep -c 'do_toggle()' scripts/session_history.sh  EXPECTED: 1
  - RUN: grep -c 'do_init()' scripts/session_history.sh    EXPECTED: 1
  - RUN: grep -c 'do_start_poller' scripts/session_history.sh
    EXPECTED: >=1  (the do_init CALL SITE + comment survive — T2 scope; do NOT remove here)
  - RUN: count surviving case branches:
        sed -n '/case "$cmd" in/,/^esac/p' scripts/session_history.sh | grep -cE '^\s+[a-z]+\)'
    EXPECTED: 12  (11 command branches + 1 `*)` catch-all)
```

### Implementation Patterns & Key Details

```bash
# This task has NO algorithmic "patterns" — it is 2 line deletions + 1 substring removal.
# The only pattern is: anchor on unique TEXT, not line numbers, because S1 shifted lines.

# Recommended edit technique (use the exact-text `edit` tool, NOT line-number sed):
#
# Task 1 — delete the two consecutive branches. Because they are adjacent and unique,
# match the two-line block as ONE oldText and replace with empty:
#     oldText:
#         "    activity)  lock; load_alive; do_activity \"$to\"; unlock ;;\n    poller)    do_poller ;;           # long-running; locks per fire of do_activity\n"
#     newText: ""   (empty)
#   (Delete both lines together so there is no risk of leaving a stray blank line
#    between the two deletions; deleting them as a unit collapses cleanly.)
#
# Task 2 — edit the Usage string in place. Match the unique substring only:
#     oldText: "{init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset}"
#     newText: "{init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset}"
#   (Anchor on the full {...} token list to guarantee the edit lands in the Usage string
#    and not somewhere else.)

# CRITICAL: Do NOT attempt to "tidy" while editing. Do not re-align the surviving
# branches' indentation, do not reorder them, do not fix unrelated SC warnings. The diff
# for this commit should show: 2 removed lines + 1 modified line (the Usage string).
# If your diff shows any other '+'/'-' lines, you over-reached.

# Verify the seam: after deleting the two branches, `dwell)` must be immediately followed
# by `prune)` with NO blank line between them (matching the file's no-blank-line-between-
# branches convention). Inspect with:
#   sed -n '/dwell)/,/prune)/p' scripts/session_history.sh
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin script; no DB, no migrations.

CONFIG:
  - none. No tmux options (@session-history-*) are added or removed by this task.
    (The @session-history-poller-pid option's references were already removed by S1.)

ROUTES:
  - none. The case dispatch IS the "router"; this task removes two of its routes.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Capture a PRE-S2 shellcheck baseline BEFORE editing (S1 has already landed, so the
#    file is 564 lines; this baseline is the S2 starting point):
shellcheck scripts/session_history.sh > /tmp/sc_before_s2.txt 2>&1; echo "baseline exit: $?"
wc -l /tmp/sc_before_s2.txt     # note the count

# 1. Parse check (run AFTER the two deletions + Usage edit):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0). bash -n parses only; it does not execute the case body.

# 2. Lint check (run AFTER editing):
shellcheck scripts/session_history.sh > /tmp/sc_after_s2.txt 2>&1; echo "after exit: $?"
diff <(sort /tmp/sc_before_s2.txt) <(sort /tmp/sc_after_s2.txt) && echo "NO NEW SC DIAGNOSTICS"
wc -l /tmp/sc_after_s2.txt
# Expected: /tmp/sc_after_s2.txt line count <= /tmp/sc_before_s2.txt.
#           `diff` of sorted output shows only REMOVED diagnostics (if any), never added.
# If diff shows ADDED SC lines (leading '>'), you introduced a problem — read & fix.

# 3. Line-count sanity:
wc -l scripts/session_history.sh
# Expected: 562   (post-S1 564 − 2)
```

### Level 2: Unit Tests (Component Validation)

```bash
# This repo has NO test framework (no bats, no test/ dir, no Makefile target).
# "Unit testing" here = the grep-based structural verification in Task 4.

# Prove the two branches are GONE from the dispatch:
sed -n '/case "$cmd" in/,/^esac/p' scripts/session_history.sh | grep -nE 'activity\)|poller\)'
# Expected: NO output (zero matches).

# Prove the Usage string no longer contains activity/poller:
grep 'Usage: \$0' scripts/session_history.sh | grep -E 'activity|poller'
# Expected: NO output (the Usage line exists but has neither token).

# Prove the 11 surviving command branches are present and in PRD §17 order:
sed -n '/case "$cmd" in/,/^esac/p' scripts/session_history.sh \
  | grep -oE '^\s+(init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset)\)' \
  | tr -d ' )'
# Expected (one per line, in this order):
#   init
#   hook
#   dwell
#   prune
#   maintain
#   toggle
#   back
#   forward
#   pick
#   status
#   reset
# (11 lines, exact PRD §17 order.)

# Prove the do_init poller CALL SITE still exists (T2 scope — must NOT have been removed):
grep -n 'do_start_poller' scripts/session_history.sh
# Expected: at least one match (the call + comment inside do_init, post-S2 ~518–520).
```

### Level 3: Integration Testing (System Validation)

```bash
# The script is a tmux plugin engine. A true integration test runs it under a tmux server.
# IMPORTANT INTERMEDIATE-STATE CAVEAT: after S2 but BEFORE T2 lands, `do_init` still
# calls the (now-deleted) `do_start_poller`. So invoking `session_history.sh init` would
# hit an undefined function and fail. That is EXPECTED — it is the S2→T2 boundary, not a
# defect of S2. Therefore: test ONLY paths that do NOT go through do_init's poller-start.

# Smoke test the non-poller paths under a throwaway tmux server (status/reset are safe):
if command -v tmux >/dev/null; then
  SOCK=prps2smoke
  tmux -L "$SOCK" new-session -d -s prptest 2>/dev/null
  # status: read-only, no lock, no do_init, no poller — safe:
  SESSION_HISTORY_TOGGLE_ENABLED=1 \
    tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh status" 2>&1 | head -20
  # reset: locks + do_reset only, no do_init, no poller — safe:
  SESSION_HISTORY_TOGGLE_ENABLED=1 \
    tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh reset" 2>&1 | head -20
  # NEGATIVE test: the removed subcommands now fall through to the Usage error:
  tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh activity foo" 2>&1 | head -5
  # Expected: prints the Usage string (the new 11-token one) to stderr, exits 1.
  #           The word "activity" must NOT appear in the echoed Usage token list.
  tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh poller" 2>&1 | head -5
  # Expected: same — Usage error, no "poller" in the token list.
  tmux -L "$SOCK" kill-server 2>/dev/null
fi
# Expected: status/reset print without error; activity/poller now print the Usage error
#           (proving the dispatch no longer routes to deleted functions).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Domain-specific: prove the change is minimal and well-scoped in git.
git diff --stat scripts/session_history.sh
# Expected: a single line. S2 is layered on top of S1; if S1 is already committed, the
#           stat shows roughly "1 file changed, 2 deletions(-), 1 modification" (the 2
#           branch lines removed and the Usage line changed — git may report the Usage
#           change as 1 insertion + 1 deletion, i.e. "3 insertions(+), ... " style: in
#           practice expect ~1-2 +/-). The key invariant: ONLY the dispatch+Usage region
#           changes; the rest of the file is untouched.

git diff scripts/session_history.sh
# Manually confirm the diff touches ONLY:
#   - the deleted `activity)` line
#   - the deleted `poller)` line
#   - the `*) ... Usage ...` line (substring removal)
# Any other changed line = over-reach.

# Structural invariant: the surviving case-branch count (excluding the `*)` catch-all)
# is exactly 11.
sed -n '/case "$cmd" in/,/^esac/p' scripts/session_history.sh \
  | grep -cE '^\s+[a-z]+\)' \
  | awk '{print "branch count (incl *): "$1}'
# Expected: 12 (11 commands + 1 catch-all `*)`).

# Cross-check against PRD §17's count (should be 11 commands, no activity/poller):
# init hook dwell prune maintain toggle back forward pick status reset = 11.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-S2 output has NO new diagnostics vs. pre-S2 baseline
      (`/tmp/sc_before_s2.txt` vs. `/tmp/sc_after_s2.txt`).
- [ ] `wc -l scripts/session_history.sh` == 562.
- [ ] `sed -n '/case "$cmd" in/,/^esac/p' scripts/session_history.sh | grep -cE '^\s+[a-z]+\)'` == 12.
- [ ] The 11 command branches (excl. `*)`) appear in exactly PRD §17 order.

### Feature Validation

- [ ] `grep -nE 'activity\)|poller\)' scripts/session_history.sh` over the dispatch region
      returns nothing.
- [ ] The Usage `{...}` token list contains neither `activity` nor `poller`, and reads
      exactly `{init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset}`.
- [ ] Invoking a removed subcommand (e.g. `... activity x`) now falls through to the
      `*)` Usage error (verified in L3 negative test).
- [ ] The `do_start_poller` call inside `do_init` is STILL PRESENT (T2 scope, untouched).
- [ ] Header-comment mentions of activity (lines 89–97) are STILL PRESENT (T4 scope).

### Code Quality Validation

- [ ] The diff touches ONLY the two deleted branch lines and the one edited Usage line.
- [ ] No re-alignment, reordering, or "drive-by" fixes to the surviving branches.
- [ ] The 3-line locking comment above `init)` is unchanged.
- [ ] Commit message / change description is scoped to "remove activity/poller dispatch +
      Usage tokens (S2)" — does not claim T2/T4 work.

### Documentation & Deployment

- [ ] No documentation changes in this task (README is M3; header comments are T4).
- [ ] No environment-variable or tmux-option changes.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT delete the `do_start_poller` call inside `do_init`** — that is T2.S1. S2
  removes ONLY the two `case` branches and the Usage tokens.
- ❌ **Do NOT rewrite the header comment region** (lines 89–97) that still mentions
  activity — that is T4.S2.
- ❌ **Do NOT re-align or reformat the surviving case branches.** Each keeps its current
  spacing/inline-comment. The diff must be surgical.
- ❌ **Do NOT rewrite the entire `*)` Usage branch.** Edit only the `{...}` token list by
  removing `activity|poller|`; keep `>&2`, `exit 1`, and `[session]` byte-for-byte.
- ❌ **Do NOT "fix" unrelated shellcheck warnings** while in the file — diff must stay minimal.
- ❌ **Do NOT key the edit on hard line numbers** — S1 shifted them. Match on the unique
  text substrings (`activity)`, `poller)`, the full `{...}` Usage token list).
- ❌ **Do NOT run `session_history.sh init` and call failure a defect** — `init` still
  routes through `do_start_poller` (deleted by S1) until T2 lands. That is the S2→T2
  boundary; S2 only guarantees the `activity`/`poller` *subcommands* are dead.

---

## Scope Boundaries (one-screen reference)

| Item | This task (S2)? | Owner |
|------|:---:|-------|
| Delete case branch `activity)` (POST-S1 ~553) | ✅ | S2 |
| Delete case branch `poller)` (POST-S1 ~554) | ✅ | S2 |
| Remove `activity\|poller\|` from Usage string (POST-S1 ~563) | ✅ | S2 |
| Delete `do_activity()`/`do_poller()`/`do_start_poller()` bodies | ❌ | **S1** (already landed) |
| Delete `do_start_poller` call + pipe-pane legacy inside `do_init` | ❌ | **T2.S1** |
| Rewrite header comment "WHAT MAKES A SESSION RELEVANT" / CONCURRENCY | ❌ | **T4.S1 / T4.S2** |
| Change dwell default 10000→30000 | ❌ | **T3** |
| README.md / session_history.tmux changes | ❌ | **M3 / M2** |

---

## Confidence Score

**9/10** for one-pass success. This is a mechanically unambiguous edit — two whole-line
deletions of unique, adjacent text anchors and one substring removal in a unique single
line — with parse-only (`bash -n`) + lint (`shellcheck`) gates, grep-based structural
proof, and an exact-text expected output for the surviving dispatch + Usage string. The
single residual risk is anchoring on line numbers that drifted when S1 landed; the spec
mitigates this by keying every edit on stable text substrings and by providing the exact
post-S2 expected region verbatim.