name: "P1.M1.T1.S1 — Delete do_activity(), do_poller(), do_start_poller() functions"
description: "Pure code-deletion subtask. Remove the three client_activity-polling functions from scripts/session_history.sh so the engine contains no focused-activity relevance path. Sibling tasks S2 (case dispatch + Usage), T2 (do_init), and T4 (header comments) handle the remaining activity references; this task touches ONLY the three function definitions."

---

## Goal

**Feature Goal**: Remove the three functions `do_activity()`, `do_poller()`, and `do_start_poller()` — and their preceding comment/divider blocks — from `scripts/session_history.sh`, eliminating all `client_activity`-polling relevance code from the engine.

**Deliverable**: An edited `scripts/session_history.sh` in which lines 320–405 (the contiguous block of the three functions and their headers) are deleted, leaving the closing `}` of the preceding function (line 319) separated by exactly one blank line from the `# --- toggle:` comment (currently line 406). No other function is modified.

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0 (the script still parses).
2. `shellcheck scripts/session_history.sh` reports no NEW errors vs. the pre-change baseline (the file already has a known set of SC warnings from unchanged code; the diff must not add any).
3. After deletion, the functions are gone and the file line count drops by exactly 86 (650 → 564).
4. `grep -n 'do_activity\|do_poller\|do_start_poller' scripts/session_history.sh` returns ONLY the two case-dispatch lines (`activity)` at the old 639, `poller)` at the old 640) — these are explicitly OUT OF SCOPE here (removed in S2). The `do_start_poller` call inside `do_init` (old line 606) is also OUT OF SCOPE (removed in T2). No other references to the three function *names* remain.
5. The deleted block contained the ONLY references to the `@session-history-poller-pid` option (old lines 369, 393, 401). After deletion those option references are gone.

## Why

PRD §12 is explicit: *"It is therefore not wired. Relevance comes from **selection** and **dwell** only."* PRD §6 lists exactly two promotion causes — (1) direct selection, (2) dwell. The current engine implements a `client_activity`-polling activity promoter as a **third** relevance path that the PRD rejects. This subtask removes the third path's implementation (the three functions). The case-dispatch wiring (S2), the poller bootstrap in `do_init` (T2), and the header-comment narrative (T4) are separate subtasks that depend on this one completing cleanly first.

This is a **pure deletion**: no logic changes, no refactors, no new code. The smallest possible change that removes the functions.

## What

Delete the contiguous line range **320–405** of `scripts/session_history.sh` (verified current state, see "Exact line-by-line deletion spec" below). This range contains exactly:

- The `# --- activity promoter ---` divider + comment + `do_activity()` body + trailing blank.
- The `# --- focused-session activity detection ---` divider + the long multi-paragraph comment about `client_activity` polling + `do_poller()` body + trailing blank.
- The `# Start (or restart) the poller.` comment + `do_start_poller()` body + trailing blank.

### Success Criteria

- [ ] Lines 320–405 of `scripts/session_history.sh` are deleted.
- [ ] No blank-line gap or doubled blank line is left behind at the deletion seam (line 319 `}` → blank → line 406 `# --- toggle:`).
- [ ] `bash -n scripts/session_history.sh` passes.
- [ ] `shellcheck scripts/session_history.sh` introduces zero new diagnostics vs. baseline.
- [ ] `do_hook`, `do_dwell`, `promote_tlist`, `do_toggle`, `do_back`, `do_forward`, `do_pick`, `prune_dead`, `cap_to_live`, `do_maintain`, `do_status`, `do_reset`, `move_to_tip`, `arm_dwell`, and the lock/load helpers are byte-for-byte unchanged.
- [ ] The case-dispatch branches (`activity)` at old 639, `poller)` at old 640), the Usage string (`activity|poller|` at old 649), and the `do_init` poller-start block (old 602–606) are left intact for sibling tasks S2/T2 — NOT touched here.

## All Needed Context

### Context Completeness Check

Yes. This PRP gives the exact line range to delete (verified against the live file), the exact before/after seam, the exact grep commands to prove success, and the exact sibling-task boundaries so the implementer does not over- or under-delete. No prior knowledge of tmux internals is required.

### Documentation & References

```yaml
# MUST READ — the authoritative reason these functions must die
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "Establishes that alert-activity sees only BACKGROUND windows and that no robust focused-activity primitive exists; therefore activity is NOT wired and relevance = selection + dwell only."
  critical: "This is the spec justification for the deletion. Do not re-implement activity detection."

- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't"
  why: "Lists exactly two promotion causes: (1) direct selection, (2) dwell. do_activity() is a third cause that must not exist."
  critical: "'Walking never promotes' — the poller's current behavior (promote on input in an unchanged session) contradicts this."

# The analysis that decomposed the whole removal into subtasks (READ for boundary clarity)
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 1 — ACTIVITY DETECTION must be removed"
  why: "Maps every activity reference to a line range and assigns each to a subtask (1a/1b/1c = THIS task; 1d/1e/1f = S2; 1g = T2). Confirms no other call sites for the three functions exist."
  critical: "Sub-items 1a/1b/1c (lines 320-341, 342-395, 396-405) are the exact scope of THIS PRP. 1d/1e/1f/1g are NOT this task."

# The file under edit
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash, 'set -u' at line 110."
  pattern: "Functions are delimited by a '# --- <topic> ---' divider comment, a prose comment block, the 'name() {' definition, a body, a closing '}', and one trailing blank line before the next divider."
  gotcha: "Deleting a function body is safe under 'set -u' — removing definitions introduces no unset-variable reads. The only risk is leaving a doubled blank line or a dangling divider comment; the deletion spec below prevents both."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY, do not edit)
├── README.md                   # docs (NOT this task — M3)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (650 lines today)
├── session_history.tmux        # entry point (NOT this task — M2)
└── plan/                       # planning artifacts (READ-ONLY)
    └── 001_ca41c05f3ead/
        └── architecture/gap_analysis.md   # ← read GAP 1 for boundaries
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified.
# After this task it is 564 lines (was 650): the 86-line block of the three
# activity/poller functions is gone. All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL: This is a tmux plugin script invoked via `tmux run-shell` / sourced by
# session_history.tmux. It runs under whatever bash the user has (#!/usr/bin/env bash),
# with `set -u` (line 110). Deletion of standalone function definitions cannot trigger
# an unset-variable error, so set -u is not a concern for THIS change.

# GOTCHA (deletion seam): The block to delete is bracketed by:
#   line 319:  '}'                          (close of the previous function — promote_tlist)
#   line 320:  '# --- activity promoter ...'  (FIRST line to delete)
#   ...
#   line 405:  ''                           (blank — LAST line to delete)
#   line 406:  '# --- toggle: flip to ...'    (do_toggle's divider — must remain)
# Delete lines 320 THROUGH 405 INCLUSIVE. Line 405 is itself blank, so after deletion
# line 319 '}' is followed directly by line 406's divider comment — BUT you must ensure
# exactly ONE blank line separates the '}' from the '# --- toggle' divider, matching the
# file's prevailing convention (one blank line between top-level functions). If your
# editor leaves zero blank lines, add one; if it leaves two, remove one.

# GOTCHA (shellcheck): shellcheck is installed (/usr/bin/shellcheck). The file currently
# has a pre-existing set of SC warnings (the gap analysis did not clean them). Your change
# must not ADD any. A clean deletion of whole functions cannot add SC warnings; the risk
# is accidentally deleting a line that a LATER function references. Since do_activity is
# only called from do_poller (both deleted) and the case dispatch (S2), and do_poller is
# only called from do_start_poller (deleted) and the case dispatch (S2), and do_start_poller
# is only called from do_init (T2) — all remaining references are in sibling-scope tasks.
# So after THIS deletion, the only compile-time "undefined function" risk would surface if
# you deleted the functions but left their call sites; you are leaving the call sites
# intentionally (they are S2/T2 scope). shellcheck does NOT flag calling an undefined shell
# function, so there will be no new SC warning. (bash will only error at runtime if those
# dispatch lines are hit before S2/T2 land — acceptable because this is an intermediate
# commit in a refactor sequence, NOT a shippable state.)

# GOTCHA (do NOT over-delete): Lines 42-66 and 89-104 contain HEADER COMMENTS that
# describe activity as the primary signal. Those are GAP 6 / P1.M1.T4 scope — DO NOT
# touch them in this task. The header comment and the case dispatch will still mention
# activity after this task; that is expected and correct at this point in the sequence.
```

## Implementation Blueprint

### Exact line-by-line deletion spec

The block to delete is **lines 320–405** (verified against the current 650-line file). It consists of three function blocks, each `divider-comment → [prose comment] → function → blank-line`:

```text
LINE 320:  # --- activity promoter (async; touches ONLY the relevance list) ------
LINES 321-325: comment block ("Called by the background poller...")
LINE 326:  do_activity() {
LINES 327-340: body (toggle_enabled guard, session_exists guard, list-clients
              attached-session check, tlist read-modify-write, save)
LINE 340:  }                          # (last line of do_activity body)
LINE 341:  (blank)

LINE 342:  # --- focused-session activity detection (client_activity polling) -----
LINES 343-367: long prose comment (alert-activity background-window limitation,
              client_activity semantics, why session-switch doesn't promote via
              this path, pipe-pane history, 1s resolution / 0.5s poll)
LINE 368:  do_poller() {
LINES 369-394: body (set poller-pid, SIGTERM trap, poll loop over list-clients,
              lock/load_alive/do_activity/unlock per fire, sleep 0.5, clear trap,
              clear poller-pid)
LINE 394:  }                          # (last line of do_poller body)
LINE 395:  (blank)

LINES 396-398: comment ("Start (or restart) the poller...")
LINE 399:  do_start_poller() {
LINES 400-403: body (toggle_enabled guard, read old poller-pid, kill old, run-shell poller)
LINE 404:  }                          # (last line of do_start_poller body)
LINE 405:  (blank)   ← also delete this blank; the blank that was line 312-ish before
                     promote_tlist already separates promote_tlist's '}' from this block,
                     but since we delete 320-405 entirely the separator becomes the single
                     blank you must leave between line-319 '}' and line-406 '# --- toggle'.
```

**What immediately precedes (line 319):** the closing `}` of the relevance-list promote helper (the function whose body ends with `if [ "${#nh[@]}" -eq 0 ]; then S "$(H tlist)" ""` / `else S "$(H tlist)" "${nh[*]}"; fi` / `}`). **Do not touch it.**

**What immediately follows (line 406):** `# --- toggle: flip to the other most-relevant session ---` — the divider for `do_toggle()`. **Do not touch it.**

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: DELETE the contiguous block lines 320-405 of scripts/session_history.sh
  - DELETE: the three function blocks described above IN ONE edit (they are contiguous;
    there are no other functions interleaved).
  - INCLUDE in the deletion: the divider comments, the prose comment blocks, the function
    bodies, and the single trailing blank line at 405.
  - PRESERVE: line 319 '}' (close of promote helper) and line 406 '# --- toggle:' divider.
  - SEAM CHECK: after deletion, the region must read:
        ...
            else S "$(H tlist)" "${nh[*]}"; fi
    }
                                          ← exactly ONE blank line here
    # --- toggle: flip to the other most-relevant session -------------------------
    ...
    If your editor produced zero blank lines, insert one. If two, delete one.

Task 2: VERIFY parse + lint (no edits — just run the gates)
  - RUN: bash -n scripts/session_history.sh   (must exit 0)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after.txt 2>&1; echo $?
  - COMPARE the shellcheck output count to a pre-change baseline (see Validation Loop L1).
    The post-change count must be <= pre-change count.

Task 3: VERIFY removal scope with grep (no edits)
  - RUN: grep -nc 'do_activity\|do_poller\|do_start_poller' scripts/session_history.sh
    EXPECTED: 4 hits — exactly:
      - old line 639:  activity)  lock; load_alive; do_activity "$to"; unlock ;;
      - old line 640:  poller)    do_poller ;;
      - old line 606:  do_start_poller        (inside do_init)
      - (these three are S2/T2 scope; they are EXPECTED to remain)
    If you see MORE than these, you under-deleted. If you see do_activity/do_poller/
    do_start_poller DEFINITIONS ('() {'), you under-deleted.
  - RUN: grep -nc 'poller-pid' scripts/session_history.sh
    EXPECTED: 0  (all @session-history-poller-pid references were inside the deleted block)
  - RUN: grep -nc 'client_activity' scripts/session_history.sh
    EXPECTED: remaining hits are ONLY in the header comment region (lines 42-104) — those
    are T4 scope and MUST remain. No hits in the 320-405 region (it no longer exists).

Task 4: VERIFY no collateral damage (no edits)
  - RUN: wc -l scripts/session_history.sh    EXPECTED: 564 (was 650; 650 - 86 = 564)
  - RUN: grep -c 'do_hook()' scripts/session_history.sh   EXPECTED: 1
  - RUN: grep -c 'do_dwell()' scripts/session_history.sh   EXPECTED: 1
  - RUN: grep -c 'do_toggle()' scripts/session_history.sh  EXPECTED: 1
  - RUN: grep -c 'do_init()' scripts/session_history.sh    EXPECTED: 1
  - RUN: grep -c 'do_back()' scripts/session_history.sh    EXPECTED: 1
  - RUN: grep -c 'do_forward()' scripts/session_history.sh EXPECTED: 1
```

### Implementation Patterns & Key Details

```bash
# This task has NO implementation "patterns" — it is a deletion. The only pattern is:
# delete a contiguous, self-contained block and prove nothing else moved.

# Recommended edit technique (pick whichever your tooling supports cleanly):
#  Option A (sed, exact and scriptable):
#     sed -i '320,405d' scripts/session_history.sh
#     # then verify the seam has exactly one blank line:
#     sed -n '317,322p' scripts/session_history.sh
#  Option B (editor/patch): match the unique anchor strings and remove the block:
#     - oldText starts at:  "# --- activity promoter (async; touches ONLY the relevance list) -"
#     - oldText ends at:    the closing '}' of do_start_poller() followed by the blank line,
#                           immediately before "# --- toggle: flip to the other most-relevant"
#     Whichever tool, the result must be byte-identical to Option A.

# CRITICAL: Do NOT attempt to "tidy" while deleting. Do not reflow the surrounding
# comments, do not rename anything, do not fix unrelated SC warnings. The diff for
# this commit should show ONLY removed lines (pure red). If your diff shows any '+'
# lines outside the blank-line seam adjustment in Task 1, you over-reached.
```

### Integration Points

```yaml
DATABASE:
  - none. This is a stateless tmux plugin script; no DB, no migrations.

CONFIG:
  - none added or removed BY THIS TASK. The @session-history-poller-pid option is
    referenced only inside the deleted block, so it effectively becomes dead after
    this task — but S2/T2 will remove the last call sites. Do NOT proactively clean
    the option elsewhere.

ROUTES:
  - none.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Capture a PRE-change shellcheck baseline BEFORE editing (do this first):
shellcheck scripts/session_history.sh > /tmp/sc_before.txt 2>&1; echo "baseline exit: $?"
wc -l /tmp/sc_before.txt   # note the line count

# 1. Parse check (run after the deletion):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0). bash -n does not execute, only parses.

# 2. Lint check (run after the deletion):
shellcheck scripts/session_history.sh > /tmp/sc_after.txt 2>&1; echo "after exit: $?"
diff <(sort /tmp/sc_before.txt) <(sort /tmp/sc_after.txt) && echo "NO NEW SC DIAGNOSTICS"
wc -l /tmp/sc_after.txt
# Expected: line count of /tmp/sc_after.txt <= /tmp/sc_before.txt.
#           `diff` of sorted output shows only REMOVED diagnostics (if any), never added.
# If diff shows ADDED SC lines (starting with '>'), you introduced a problem — read it and fix.

# 3. Line-count sanity:
wc -l scripts/session_history.sh
# Expected: 564   (650 - 86)
```

### Level 2: Unit Tests (Component Validation)

```bash
# This repo has NO test framework (no bats, no test/ dir, no Makefile target).
# "Unit testing" for a pure deletion is the grep-based structural verification in Task 3.

# Prove the three function DEFINITIONS are gone (only call-site references should remain):
grep -nE 'do_activity\(\)|do_poller\(\)|do_start_poller\(\)' scripts/session_history.sh
# Expected: NO output (zero definition sites). The '()' makes this match definitions only.

# Prove the @session-history-poller-pid option is fully gone (it lived only in the deleted fns):
grep -n 'poller-pid' scripts/session_history.sh
# Expected: NO output.

# Prove the surviving references are exactly the known call sites (S2/T2 scope):
grep -nE 'do_activity|do_poller|do_start_poller' scripts/session_history.sh
# Expected: exactly three lines (line numbers will have shifted by -86 after the block that
# came before them is removed; the do_init call at old 606 -> ~520, the case branches at old
# 639/640 -> ~553/554):
#     ~520:      do_start_poller          (inside do_init, before its closing })
#     ~553:      activity)  lock; load_alive; do_activity "$to"; unlock ;;
#     ~554:      poller)    do_poller ;;
# Any other match = under-deletion.
```

### Level 3: Integration Testing (System Validation)

```bash
# The script is a tmux plugin engine. A true integration test requires a tmux server.
# Because this is an INTERMEDIATE step in a refactor (S2 and T2 have not landed), the
# engine still references do_activity/do_poller/do_start_poller at three call sites.
# Running it end-to-end would fail at those call sites. So integration testing is
# DEFERRED to after S2+T2 and is OUT OF SCOPE for this commit.

# The only integration-relevant check here is: does the script still PARSE under the
# target interpreter? Covered by L1 `bash -n`.

# (Optional, if a tmux binary is available and you want a smoke check that does not
#  hit the deleted paths):
if command -v tmux >/dev/null; then
  tmux -L prpsmoke new-session -d -s prptest 2>/dev/null
  SESSION_HISTORY_TOGGLE_ENABLED=1 \
    tmux -L prpsmoke run-shell "scripts/session_history.sh status" 2>&1 | head -20
  # `status` and `reset` paths do NOT call any deleted function, so they should print.
  tmux -L prpsmoke kill-server 2>/dev/null
fi
# Expected: the status command prints the timeline/relevance list without error.
#           (This only proves non-activity paths still load; the activity/poller
#            subcommands will now be dead-letter until S2 removes their dispatch.)
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Domain-specific: prove the deletion is "pure red" in git.
git diff --stat scripts/session_history.sh
# Expected: a single line, e.g.: "1 file changed, 86 deletions(-)"
git diff scripts/session_history.sh | grep -c '^+' 
# Expected: 0 (no additions, not even in the hunk header body — only the seam blank line
#           might show as context, not as '+'). If this is > 0, inspect the diff: only an
#           exactly-one-blank-line seam adjustment is acceptable, and even that should
#           ideally be absorbed as unchanged context.

# Structural invariant: the function count (definition sites) should drop by exactly 3.
grep -cE '^[a-z_]+\(\) \{' scripts/session_history.sh
# Compare to the pre-change value (should be 3 fewer). Pre-change the file defines ~16
# functions; post-change ~13. Record the pre-change number first.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-change output has NO new diagnostics vs. pre-change baseline (`/tmp/sc_before.txt` vs `/tmp/sc_after.txt`).
- [ ] `git diff --stat` shows ONLY deletions for `scripts/session_history.sh` (1 file, 86 deletions).
- [ ] Line count is 564 (`wc -l scripts/session_history.sh`).
- [ ] `grep -nE 'do_activity\(\)|do_poller\(\)|do_start_poller\(\)'` returns nothing (no definition sites remain).
- [ ] `grep -n 'poller-pid'` returns nothing.

### Feature Validation

- [ ] Exactly three surviving references to `do_activity`/`do_poller`/`do_start_poller` remain: the `do_init` call site and the two case branches. (These are S2/T2 scope; leaving them is correct.)
- [ ] Header comment region (lines 42–104) still mentions activity — and is LEFT UNTOUCHED (T4 scope).
- [ ] `do_hook`, `do_dwell`, `promote_tlist`, `do_toggle`, `do_init` (seed block), `do_back`, `do_forward`, `do_pick`, `prune_dead`, `cap_to_live`, `do_maintain`, `do_status`, `do_reset`, `move_to_tip`, `arm_dwell` all unchanged (each has exactly 1 definition site, verified by Task 4 greps).

### Code Quality Validation

- [ ] The deletion seam has exactly ONE blank line between the previous function's `}` and the `# --- toggle:` divider.
- [ ] No reformatting, reflowing, or "drive-by" fixes outside the deleted block.
- [ ] Commit message / change description is scoped to "remove do_activity/do_poller/do_start_poller (S1)" — does not claim S2/T2/T4 work.

### Documentation & Deployment

- [ ] No documentation changes in this task (README + header comments are M3 / T4 scope).
- [ ] No environment-variable or config changes.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT delete the case-dispatch lines (`activity)`, `poller)`)** — that is S2. This task leaves them in place; they become dead-letter until S2 lands.
- ❌ **Do NOT delete the `do_start_poller` call inside `do_init`** (old line 606) or the surrounding comment — that is T2.
- ❌ **Do NOT rewrite the header comments** (lines 42–66, 89–104) even though they describe activity as the primary signal — that is T4.
- ❌ **Do NOT "fix" unrelated shellcheck warnings** while you're in the file — the diff must be pure red.
- ❌ **Do NOT replace the deleted functions with a stub or comment placeholder** — the whole point is their absence.
- ❌ **Do NOT run a live `activity`/`poller` subcommand as a test** and conclude failure when it errors — those subcommands are now intentionally broken until S2; their breakage is the S1→S2 boundary, not a defect of S1.

---

## Scope Boundaries (one-screen reference)

| Item | This task (S1)? | Owner |
|------|:---:|-------|
| Delete `do_activity()` body + comment | ✅ | S1 |
| Delete `do_poller()` body + comment | ✅ | S1 |
| Delete `do_start_poller()` body + comment | ✅ | S1 |
| Delete `@session-history-poller-pid` references (inside deleted fns) | ✅ | S1 |
| Delete case branches `activity)` / `poller)` (old 639/640) | ❌ | **S2** |
| Edit Usage string (drop `activity\|poller\|`, old 649) | ❌ | **S2** |
| Delete `do_init` pipe-pane cleanup (old 595–601) | ❌ | **T2.S1** |
| Delete `do_init` poller-start call + comment (old 602–606) | ❌ | **T2.S1** |
| Rewrite header "WHAT MAKES A SESSION RELEVANT" (42–66) | ❌ | **T4.S1** |
| Rewrite header CONCURRENCY block (89–104) | ❌ | **T4.S2** |
| Change dwell default 10000→30000 (old 154) | ❌ | **T3** |

**Confidence Score: 9/10** for one-pass success. This is a mechanically unambiguous deletion of a contiguous, self-contained block with verified line numbers, a parse-only validation gate (`bash -n` + `shellcheck`), and grep-based proof of scope. The single residual risk is a blank-line-seam cosmetic issue at the deletion boundary, which the spec calls out explicitly and the L4 "pure red diff" check will catch.