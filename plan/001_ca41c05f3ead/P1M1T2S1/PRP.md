name: "P1.M1.T2.S1 — Remove pipe-pane legacy cleanup and poller start; add stale-poller migration guard"
description: "Surgical bash edit to `do_init()` in `scripts/session_history.sh`. Delete the pipe-pane legacy-cleanup block (POST-S1 lines 509–515 + trailing blank 516) and delete the poller-start block (517–520) whose `do_start_poller` call now targets a function body S1 already removed (so `init` currently throws 'command not found'). Replace the poller-start block with a one-shot, self-cleaning migration guard that reads the old `@session-history-poller-pid`, kills that stale PID, and clears the option — mirroring the exact kill pattern the deleted `do_start_poller` used on every reload. Seed logic (491–508) is kept byte-for-byte. No new background processes are started. Net: −5 lines (FINAL = BASELINE − 5; see Baseline Note below)."

---

## Goal

**Feature Goal**: Make `do_init()` conform to PRD §17 — *"Seed initial state if empty (current/attached session)."* — and nothing more, by (a) deleting the dead pipe-pane legacy-cleanup block, (b) deleting the `do_start_poller` call that currently references an undefined function (broken since S1), and (c) adding a defensive one-shot migration guard that cleans up a stale poller process left over from a prior install on the first `init` after upgrade.

**Deliverable**: An edited `do_init()` in `scripts/session_history.sh` whose body is exactly: unchanged seed-if-empty logic, followed by a one-shot stale-poller migration guard (read `@session-history-poller-pid` → kill if non-empty → clear option). No `do_start_poller` call. No `pipe-pane`/`piped-pane` references. No background process starts.

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0.
2. `shellcheck scripts/session_history.sh` reports **no new diagnostics** vs. a pre-edit baseline.
3. `grep -n 'do_start_poller' scripts/session_history.sh` → **zero matches** (the call site is gone).
4. `grep -n 'piped-pane\|pipe-pane' scripts/session_history.sh` → **zero matches** anywhere (the legacy block is fully removed; no other code references it).
5. `grep -n 'poller-pid' scripts/session_history.sh` → matches ONLY inside the new migration guard (3 lines: the read, the kill-guarded reference, the clear). This is expected and correct — it is the self-cleaning guard.
6. `do_init()` starts NO process: `sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -nE 'run-shell|setsid|nohup|disown|\s&\s*$'` → **zero matches**.
7. `wc -l scripts/session_history.sh` == **BASELINE − 5** (see Baseline Note: **559** if only S1 has landed / **557** if S2 has also landed; the edit itself is always −5 lines).
8. Under a throwaway tmux server, `session_history.sh init` runs **without** a `do_start_poller: command not found` error (it currently fails this — S2 leaves `init` broken; THIS task fixes it).

## Why

S1 deleted the **bodies** of `do_activity`/`do_poller`/`do_start_poller` but intentionally left
their **call sites** for later tasks. Two of those call sites live inside `do_init`:

- `do_start_poller` (line 520) now calls a function that no longer exists → **`session_history.sh init`
  is currently broken** (throws `do_start_poller: command not found`). This task removes that call.
- The pipe-pane legacy cleanup (lines 509–515) references `@session-history-piped-pane`, an option
  that is **not in PRD §3** and whose machinery PRD §12 explicitly rejects ("not wired"). Dead code
  that must go.

**Critical migration issue (GAP open-question #1):** a user upgrading from a pre-S1 install may have
a **stale poller process** still running — tracked in `@session-history-poller-pid`, spawned by the
old `do_start_poller` via `tmux run-shell -b "${SELF} poller"`. Because the reload no longer calls
`do_start_poller` (which used to kill its own predecessor), that orphan would run **indefinitely**.
The one-shot migration guard kills it on the first `init` after upgrade, then clears the option so
every subsequent `init` is a no-op. After this, `do_init` matches PRD §17 exactly.

This is a **small, surgical edit**: one contiguous block deletion + one replacement, both inside
`do_init`. No logic refactor.

## What

Two edits inside `do_init()` in `scripts/session_history.sh`, anchored on stable text (NOT line
numbers — they shifted when S1 landed and may shift again if S2's parallel edits differ slightly).

### Success Criteria

- [ ] The pipe-pane legacy-cleanup block (comment + 3 code lines + trailing blank line) is deleted.
- [ ] The poller-start block (3-line comment + `do_start_poller` call) is deleted.
- [ ] A one-shot migration guard is added where the poller-start block was, reading
      `@session-history-poller-pid`, killing a non-empty PID with `kill "$old_pid" 2>/dev/null`,
      and clearing the option with `S "$(H poller-pid)" "" 2>/dev/null`.
- [ ] The seed-if-empty logic (the `if [ -z "$CURRENT" ]; then … fi` block, incl. the
      `# Same guard as do_hook` comment) is **byte-for-byte unchanged**.
- [ ] `do_init()` starts no new process and contains no `do_start_poller`/`pipe-pane`/`piped-pane` reference.
- [ ] `bash -n` passes; `shellcheck` adds zero diagnostics.
- [ ] File is **BASELINE − 5** lines (559 post-S1-only, or 557 post-S2).

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact current `do_init()` source (post-S1), the exact line ranges of
the two blocks to delete, the exact text of the replacement guard (mirroring the deleted
`do_start_poller`'s proven kill line, verified via git), the exact helper semantics (`H`/`G`/`S`),
the exact grep proofs of success, the expected final `do_init()` verbatim, and precise sibling-task
boundaries. An implementer with zero prior knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authoritative spec for what `init` must do
- docfile: PRD.md
  section: "§17. Subcommand reference"
  why: "`init` = 'Seed initial state if empty (current/attached session).' Nothing else.
        No background process may be started. This is the target shape of do_init."
  critical: "There is no poller start and no pipe-pane cleanup in §17. Both current blocks are the gap."

# MUST READ — why pipe-pane is rejected (justifies the legacy-cleanup deletion)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "Explicitly rejects 'heavy per-pane pipe-pane plumbing.' @session-history-piped-pane is
        the option that tracked that plumbing; deleting its cleanup block is spec-mandated."
  critical: "Do NOT re-add pipe-pane handling. The deletion is required, not cosmetic."

# MUST READ — the option set that sanctions (or not) the options this task touches
- docfile: PRD.md
  section: "§3. State model"
  why: "Persistent + config options are listed exhaustively. Neither @session-history-poller-pid
        nor @session-history-piped-pane appears. Both must end up gone from the codebase;
        poller-pid survives ONLY inside the one-shot migration guard (a deliberate, self-cleaning
        exception to drain stale state from prior installs)."
  critical: "The empty string is the canonical unset/empty value for all list options. The guard
             uses S ... '' to clear poller-pid, consistent with that convention."

# MUST READ — concurrency context for running tmux calls inside do_init
- docfile: PRD.md
  section: "§13. Concurrency & race safety"
  why: "Every mutating command (including init) takes the exclusive flock for its whole critical
        section; the dispatch does `init) lock; load_alive; do_init; unlock ;;`. So the guard's
        tmux show-options/set-option and the kill all run UNDER the lock — safe and consistent."
  critical: "No new locking is needed. The guard runs inside the existing locked section."

# The decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 7 — INIT: remove poller start + pipe-pane legacy cleanup (PRD §17)"
  why: "7a (seed logic, lines 578–594 pre-S1) = COMPLIANT, keep. 7b (pipe-pane cleanup, 595–601) =
        DELETE. 7c (poller start, 602–606) = DELETE. This PRP == GAP 7b + 7c plus the migration guard
        from open-question #1. Also see GAP 4b (@session-history-piped-pane must be removed)."
  critical: "GAP 7 == THIS task. GAP 1 (function bodies) == S1 (done). GAP 3 (case branches) == S2 (parallel)."

# The file under edit
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash, `set -u` at
        line 110. do_init() is the ONLY function touched. Helpers: H() line 113, G() line 144,
        S() line 145. The dispatch calls do_init under the lock: `init) lock; load_alive; do_init; unlock ;;`."
  pattern: "do_init() is a plain bash function; 4-space indent; comments are `# `-prefixed at 4-space
            indent; options are read via `G \"$(H <short>)\"` and written via `S \"$(H <short>)\" <val>`.
            The existing pipe-pane block already demonstrates the exact G/S idiom — the migration
            guard reuses it for poller-pid."
  gotcha: "Under `set -u`, always assign before reading. The guard declares `local old_pid` then
           assigns via command substitution — safe. Never reference `$old_pid` before assignment."

# The sibling PRP whose output this task consumes (CONTRACT — S2 runs in parallel)
- docfile: plan/001_ca41c05f3ead/P1M1T1S2/PRP.md
  why: "S2 edits ONLY the case dispatch + Usage string at the BOTTOM of the file (~546–562). It
        explicitly PRESERVES the do_init poller call for T2. Therefore do_init's line numbers
        (491–521) are STABLE for this task regardless of S2. S2 also confirms do_start_poller's
        CALL SITE survives S1 — which is exactly what this task removes."
  critical: "Do not assume S2 has changed do_init. It has not. Match do_init edits on TEXT anchors
             (the unique comment/code lines), not line numbers."

# The completed S1 PRP — defines the post-S1 starting state
- docfile: plan/001_ca41c05f3ead/P1M1T1S1/PRP.md
  why: "S1 deleted the do_activity/do_poller/do_start_poller FUNCTION bodies (originally lines
        320–405). After S1 the file is 564 lines and do_init sits at 491–521. The do_start_poller
        CALL at line 520 now references an undefined function — this is the defect T2 fixes."
  critical: "S1 is already committed (f070deb). The live file is post-S1. Do NOT derive line numbers
             from a pre-S1 checkout."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY)
├── README.md                   # docs (NOT this task — M3)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (564 post-S1 / 562 post-S2; see Baseline Note)
├── session_history.tmux        # entry point (NOT this task — M2)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md   # ← read GAP 7 + GAP 4b + open-question #1
        ├── P1M1T1S1/PRP.md                # ← S1 contract (done)
        └── P1M1T1S2/PRP.md                # ← S2 contract (parallel; does NOT touch do_init)
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified, and ONLY do_init().
# After this task the file is BASELINE − 5 lines (559 post-S1-only / 557 post-S2; see Baseline Note).
# do_init() is now: unchanged seed-if-empty logic + one-shot stale-poller migration guard.
#
# === BASELINE NOTE (line-count timing) ============================================
# S1 (delete activity/poller function bodies) landed at commit f070deb → file = 564 lines.
# S2 (delete activity/poller case branches + Usage tokens) runs IN PARALLEL with this task and
# is BELOW do_init (it edits the dispatch at the file's bottom), so it does NOT shift do_init's
# line numbers (do_init stays at 491–521). It DOES change the file's TOTAL line count:
#   - post-S1 only : BASELINE = 564 → after this task FINAL = 559
#   - post-S2 also : BASELINE = 562 → after this task FINAL = 557   (observed during research)
# The edit is TEXT-anchored (verified to match the live file), so it is unaffected by S2. Before
# editing, run `wc -l scripts/session_history.sh` to read BASELINE; your expected FINAL = BASELINE − 5.
# All validation gates below use BASELINE − 5 (or name both values). Do NOT treat a 557 result as
# a failure if BASELINE was 562, nor a 559 result as a failure if BASELINE was 564.
# =================================================================================
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — current state is post-S1 (commit f070deb). do_init is at lines 491–521, NOT 577–607
# (those were pre-S1 line numbers cited in the gap analysis / item contract). Every line after the
# deleted function bodies (~old 405) shifted up by ~86 when S1 landed. The IMPLEMENTATION TASKS
# below key on STABLE TEXT ANCHORS, so they are robust to any further drift.

# GOTCHA (init is currently BROKEN): line 520 `do_start_poller` calls a function whose BODY S1
# deleted. So `session_history.sh init` currently prints "do_start_poller: command not found" and
# exits non-zero. Removing that call (this task) makes `init` functional again. A test that runs
# `init` and sees that error BEFORE this task is seeing the known S2→T2 boundary, NOT a regression.

# GOTCHA (the kill must be best-effort + guarded): the deleted do_start_poller killed its
# predecessor with EXACTLY  `[ -n "$old" ] && kill "$old" 2>/dev/null`. The stale poller PID is the
# PID of a `session_history.sh poller` process (plain bash, spawned by `tmux run-shell -b`); SIGTERM
# (the default `kill` signal) is correct and proven. Mirror that line verbatim. NEVER call
# `kill ""` without the `[ -n ]` guard (bare `kill ""` errors in bash; the guard + 2>/dev/null make
# it a clean no-op when poller-pid is unset).

# GOTCHA (self-cleaning property): the guard clears poller-pid UNCONDITIONALLY on every init
# (S "$(H poller-pid)" "" runs every time). After the first post-upgrade init, the option is empty,
# so subsequent inits read "" and skip the kill. This is the intended design — do not add a "only
# clear if non-empty" condition; unconditional clear is simpler and matches the old pipe-pane block's
# unconditional `S "$(H piped-pane)" ""` style.

# GOTCHA (do NOT start anything): PRD §17 forbids `init` from starting processes. The guard must
# NOT use `tmux run-shell`, `setsid`, `nohup`, `&`, or `disown`. It only KILLS (best-effort) and
# CLEARS an option. If the diff adds any process-spawning construct, you have over-reached.

# GOTCHA (set -u, line 110): the guard declares `local old_pid` before reading it, and reads
# `$old_pid` only after assignment. No new unset-variable reads are introduced. set -u is safe.

# GOTCHA (lock context): do_init runs UNDER the exclusive flock (the dispatch does
# `init) lock; load_alive; do_init; unlock ;;`, see PRD §13). The guard's tmux show-options /
# set-option / kill are all safe inside the lock. Do NOT add lock()/unlock() calls inside do_init.

# GOTCHA (option naming): `H poller-pid` expands to `@session-history-poller-pid`. `H piped-pane`
# expands to `@session-history-piped-pane`. The helper `H` (line 113) just prefixes the namespace.
```

## Implementation Blueprint

### The exact target `do_init()` (post-T2.S1) — full function, verbatim

```bash
do_init() {
    load
    if [ -z "$CURRENT" ]; then
        local s; s="$(attached_session)"
        [ -z "$s" ] && s="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null | sort -rn | head -n1 | cut -d ' ' -f2-)"
        # Same guard as do_hook: only SEED history on a genuinely empty
        # timeline. If history exists (e.g. CURRENT was blanked by a prior
        # prune), adopt `s` as current without destroying it.
        if [ -n "$s" ]; then
            if [ "${#HIST[@]}" -eq 0 ]; then HIST=("$s"); IDX=0
            else
                local j
                if j="$(index_of "$s")"; then IDX="$j"
                else HIST+=("$s"); IDX=$(( ${#HIST[@]} - 1 )); fi
            fi
            CURRENT="$s"; save
        fi
    fi
    # One-shot migration guard: an older version may have left a poller process
    # running, tracked in @session-history-poller-pid. That machinery is gone
    # now, so kill the stale PID once (if any) and clear the option. Self-
    # cleaning: once the option is empty, subsequent inits skip this entirely.
    local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"
    [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
    S "$(H poller-pid)" "" 2>/dev/null
}
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE a pre-edit shellcheck baseline (no source edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_before_t2s1.txt 2>&1; echo "baseline exit: $?"
  - RUN: wc -l /tmp/sc_before_t2s1.txt    # note the count
  - WHY: this task's shellcheck gate is "no NEW diagnostics", so you need a before-snapshot.
         The file already carries pre-existing SC warnings (gap analysis did not clean them);
         your edit must not ADD any.

Task 2: REPLACE the pipe-pane block + poller-start block with the migration guard
         (single edit, anchored on unique text — see "Recommended edit technique" below)
  - MATCH the contiguous block that starts at the line:
        '    # Legacy cleanup: older versions kept a pipe-pane on the focused pane,'
    and ends at the line:
        '    do_start_poller'
    (This spans POST-S1 ~509–520: the 4-line pipe-pane comment + 3 pipe-pane code lines + the
     blank line + the 3-line poller comment + the do_start_poller call.)
  - REPLACE that entire block with the migration guard (7 lines):
        '    # One-shot migration guard: an older version may have left a poller process\n    # running, tracked in @session-history-poller-pid. That machinery is gone\n    # now, so kill the stale PID once (if any) and clear the option. Self-\n    # cleaning: once the option is empty, subsequent inits skip this entirely.\n    local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"\n    [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null\n    S "$(H poller-pid)" "" 2>/dev/null'
  - PRESERVE: everything above the matched block (seed logic, lines 491–508) — byte-for-byte.
  - PRESERVE: the closing `}` of do_init (the line after the old `do_start_poller` call).
  - ANCHOR on the comment text + code, NOT line numbers (they shifted under S1 and S2 is parallel).

Task 3: VERIFY parse (no edits)
  - RUN: bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
  - EXPECTED: PARSE OK (exit 0).

Task 4: VERIFY lint delta + line count (no edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after_t2s1.txt 2>&1; echo "after exit: $?"
  - RUN: diff <(sort /tmp/sc_before_t2s1.txt) <(sort /tmp/sc_after_t2s1.txt)
    EXPECTED: only REMOVED lines (leading '<') or no diff; NEVER a line starting with '>'.
  - RUN: wc -l scripts/session_history.sh
    EXPECTED: BASELINE − 5  (= 559 if BASELINE was 564 / post-S1-only; = 557 if BASELINE was 562 / post-S2).

Task 5: VERIFY removal + structural invariants with grep (no edits)
  - RUN: grep -n 'do_start_poller' scripts/session_history.sh
    EXPECTED: ZERO output (the call site is gone).
  - RUN: grep -nE 'piped-pane|pipe-pane' scripts/session_history.sh
    EXPECTED: ZERO output (legacy block fully removed; no other code references it).
  - RUN: grep -n 'poller-pid' scripts/session_history.sh
    EXPECTED: exactly 3 lines, all inside the new migration guard:
        (the `G "$(H poller-pid)"` read)
        (the `[ -n "$old_pid" ] && kill "$old_pid"` line — note: this line does NOT contain
         the literal 'poller-pid'; only the read and the clear do)
      => actually 2 literal 'poller-pid' matches: the `local old_pid; old_pid="$(G "$(H poller-pid)" ...`
         line and the `S "$(H poller-pid)" ""` line. The kill line contains old_pid, not poller-pid.
      => So EXPECTED: exactly 2 lines containing the literal 'poller-pid', both in the guard.
  - RUN: sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -nE 'run-shell|setsid|nohup|disown|[[:space:]]&[[:space:]]*$'
    EXPECTED: ZERO output (do_init starts nothing).
  - RUN: sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -c 'CURRENT="\$s"; save'
    EXPECTED: 1 (seed logic's save call intact).
  - RUN: sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -c 'Same guard as do_hook'
    EXPECTED: 1 (seed-logic comment intact).

Task 6: INTEGRATION smoke test under a throwaway tmux server (no source edits)
  - RUN the block in Validation Loop L3. `init` must now run WITHOUT
    "do_start_poller: command not found".
```

### Recommended edit technique (use the exact-text `edit` tool, NOT line-number sed)

Because the two blocks to remove are contiguous (pipe-pane block + blank + poller block) and their
combined text is unique in the file, do it as ONE `edit` call: match the whole contiguous region
as `oldText` and provide the guard as `newText`. This collapses cleanly with no stray blank line.

**oldText** (the contiguous POST-S1 ~509–520 region — match EXACTLY, including the blank line and
the comment hyphens/spaces):

```
    # Legacy cleanup: older versions kept a pipe-pane on the focused pane,
    # tracked in @session-history-piped-pane. Close just THAT pane's pipe (if
    # any) so its reader exits; the current design uses no pipes. Targeted so we
    # never close another plugin's pipe-pane.
    local legacy; legacy="$(G "$(H piped-pane)" 2>/dev/null)"
    [ -n "$legacy" ] && tmux pipe-pane -t "$legacy" "" 2>/dev/null
    S "$(H piped-pane)" "" 2>/dev/null

    # Start the focused-activity poller: it watches the attached client's
    # client_activity timestamp and promotes the current session on input.
    # Reload-safe — do_start_poller kills any previous instance first. No-op
    do_start_poller
```

**newText** (the migration guard — matches the exact target `do_init()` block above):

```
    # One-shot migration guard: an older version may have left a poller process
    # running, tracked in @session-history-poller-pid. That machinery is gone
    # now, so kill the stale PID once (if any) and clear the option. Self-
    # cleaning: once the option is empty, subsequent inits skip this entirely.
    local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"
    [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
    S "$(H poller-pid)" "" 2>/dev/null
```

> ⚠️ Before editing, confirm the live block matches `oldText` exactly by running:
> `sed -n '/# Legacy cleanup: older versions/,/do_start_poller/p' scripts/session_history.sh`
> If the live text differs (e.g. S2 somehow touched it — it should not), adjust the anchor to the
> live text but keep the SAME semantic transformation: delete pipe-pane block + poller block, insert guard.

### Implementation Patterns & Key Details

```bash
# The migration guard mirrors the DELETED do_start_poller's proven predecessor-kill pattern.
# Verified via: git show 734be9f:scripts/session_history.sh
#   do_start_poller() {
#       toggle_enabled || return 0
#       local old; old="$(G "$(H poller-pid)")"
#       [ -n "$old" ] && kill "$old" 2>/dev/null        # ← THIS is the pattern we reuse
#       tmux run-shell -b "${SELF} poller"              # ← we do NOT reuse this (no new process)
#   }
# The poller stored ITS OWN PID:  S "$(H poller-pid)" "$$"
# So kill(SIGTERM) on that PID is correct and proven; SIGTERM is the default `kill` signal.

# Helper semantics (lines 113/144/145):
#   H poller-pid  -> @session-history-poller-pid   (namespace prefix)
#   G <opt>       -> tmux show-options -gv <opt>   (reads value; own 2>/dev/null)
#   S <opt> <val> -> tmux set-option -g <opt> <val>(writes global option)

# The guard is intentionally unconditional on the CLEAR and conditional on the KILL:
#   local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"   # read (empty if unset)
#   [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null              # kill ONLY if non-empty
#   S "$(H poller-pid)" "" 2>/dev/null                            # always clear (self-cleaning)
# This matches the style of the deleted pipe-pane block, which also did an unconditional
# `S "$(H piped-pane)" ""`. Unconditional clear keeps the option drained without extra branches.
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin; no DB, no schema migrations.

CONFIG (tmux global user options):
  - @session-history-poller-pid: READ (best-effort) then CLEARED to "" by the guard. This option
        is NOT in PRD §3; the guard is the ONLY remaining reference and exists solely to drain
        stale state from prior installs. After the first post-upgrade init, it stays empty forever.
  - @session-history-piped-pane: NO LONGER READ OR WRITTEN by do_init (the legacy block is deleted).
        The option is not in PRD §3 and nothing else references it. (An old install may leave a
        stale value; it is harmless — nothing reads it. A one-shot clear of piped-pane is OUT of
        scope: the contract specifies the guard for poller-pid only. Do not add a piped-pane clear.)

ROUTES / DISPATCH:
  - none changed. The `init) lock; load_alive; do_init; unlock ;;` dispatch branch is untouched.
        The guard simply runs inside do_init's existing locked critical section (PRD §13).
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit shellcheck baseline (run BEFORE editing):
shellcheck scripts/session_history.sh > /tmp/sc_before_t2s1.txt 2>&1; echo "baseline exit: $?"
wc -l /tmp/sc_before_t2s1.txt

# 1. Parse check (run AFTER the single edit):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0).

# 2. Lint delta (run AFTER editing):
shellcheck scripts/session_history.sh > /tmp/sc_after_t2s1.txt 2>&1; echo "after exit: $?"
diff <(sort /tmp/sc_before_t2s1.txt) <(sort /tmp/sc_after_t2s1.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: no diff, OR only lines REMOVED (leading '<'). A line starting with '>' = a NEW
#           diagnostic you introduced — read it and fix. (Do NOT fix pre-existing warnings; that
#           is out of scope and bloats the diff.)

# 3. Line-count sanity:
wc -l scripts/session_history.sh
# Expected: BASELINE − 5  (= 559 if BASELINE was 564 / post-S1-only; = 557 if BASELINE was 562 / post-S2).
#           Capture BASELINE with the `wc -l` you run for the shellcheck baseline in step 0.
```

### Level 2: Unit / Structural Tests (Component Validation)

```bash
# This repo has NO test framework (no bats, no test/ dir). "Unit testing" = grep-based structural
# verification that the edit is exactly what was specified.

# A. do_start_poller call site is GONE (the whole reason init was broken):
grep -n 'do_start_poller' scripts/session_history.sh
# Expected: NO output (zero matches).

# B. pipe-pane / piped-pane fully removed:
grep -nE 'piped-pane|pipe-pane' scripts/session_history.sh
# Expected: NO output (zero matches anywhere — no other code references it).

# C. poller-pid survives ONLY inside the guard (self-cleaning drain). Exactly 2 literal matches:
grep -n 'poller-pid' scripts/session_history.sh
# Expected: exactly 2 lines, both inside do_init's migration guard:
#   ...local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"
#   ...S "$(H poller-pid)" "" 2>/dev/null

# D. do_init starts NO process:
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh \
  | grep -nE 'run-shell|setsid|nohup|disown|[[:space:]]&[[:space:]]*$'
# Expected: NO output.

# E. Seed logic intact (unchanged):
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -c 'CURRENT="$s"; save'
# Expected: 1
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -c 'Same guard as do_hook'
# Expected: 1
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -c 'attached_session'
# Expected: 1

# F. do_init still defined exactly once:
grep -c 'do_init()' scripts/session_history.sh
# Expected: 1

# G. Full do_init body matches the target verbatim (visual diff):
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh
# Compare against the "exact target do_init()" block in the Implementation Blueprint.
```

### Level 3: Integration Testing (System Validation)

```bash
# The script is a tmux plugin engine. Run it under a THROWAWAY tmux server.
# KEY: before this task, `init` throws "do_start_poller: command not found". After this task,
# `init` must run cleanly. This L3 step proves the fix.

if command -v tmux >/dev/null; then
  SOCK=prpt2s1
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$SOCK" new-session -d -s prptest 2>/dev/null

  # 1. init must now run WITHOUT the "command not found" error (the core fix):
  SESSION_HISTORY_TOGGLE_ENABLED=1 \
    tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh init" 2>&1
  # Expected: empty/clean output; NO "do_start_poller: command not found".

  # 2. After init, the seed logic should have set current session state (if a session existed):
  tmux -L "$SOCK" show-options -gv '@session-history-current' 2>/dev/null
  # Expected: "prptest" (the seed logic attached the current/newest session) — OR empty if the
  #           run-shell had no attached client and list-sessions was unavailable. Either way, no error.

  # 3. The migration guard cleared poller-pid (best-effort; should be empty after init):
  tmux -L "$SOCK" show-options -gv '@session-history-poller-pid' 2>/dev/null
  # Expected: empty string (the guard's unconditional S ... "" cleared it).

  # 4. (Optional, if you can plant a fake stale PID) — simulate a prior-install leftover:
  tmux -L "$SOCK" set-option -g '@session-history-poller-pid' '999999'  # a PID that does not exist
  SESSION_HISTORY_TOGGLE_ENABLED=1 \
    tmux -L "$SOCK" run-shell "$PWD/scripts/session_history.sh init" 2>&1
  tmux -L "$SOCK" show-options -gv '@session-history-poller-pid' 2>/dev/null
  # Expected: empty string again. The guard tried `kill 999999` (failed harmlessly — no such
  #           process — 2>/dev/null swallowed it) and then cleared the option. No error surfaced.
  #           This proves the self-cleaning behavior on a stale leftover.

  tmux -L "$SOCK" kill-server 2>/dev/null
else
  echo "tmux not installed — skipping L3 (run manually where tmux is available)."
fi
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Domain-specific: prove the change is minimal and scoped in git.
git diff --stat scripts/session_history.sh
# Expected: a single file line. The stat should reflect roughly -12/+7 inside do_init only
#           (git may express the contiguous block as a smaller hunk count; the key invariant is
#           that ONLY do_init changes and nothing else in the file moves).

git diff scripts/session_history.sh
# Manually confirm the diff touches ONLY the do_init region:
#   - the 7-line pipe-pane block (comment + 3 code) is gone
#   - the blank line between the blocks is gone
#   - the 4-line poller block (3 comment + do_start_poller) is gone
#   - the 7-line migration guard (4 comment + 3 code) is added
# Any changed line OUTSIDE do_init (e.g. in the seed logic, or in the case dispatch) = over-reach
# OR a conflict with S2's parallel edit. If you see dispatch/Usage changes, coordinate with S2.

# Idempotency / self-cleaning proof (structural): the guard's clear is unconditional, so running
# init twice must be a no-op on the second run (poller-pid is already empty):
grep -n 'S "$(H poller-pid)" ""' scripts/session_history.sh
# Expected: exactly 1 match — the unconditional clear line in the guard.

# No-background-process proof (re-stated, since it is a hard PRD §17 requirement):
sed -n '/^do_init()/,/^}/p' scripts/session_history.sh | grep -ciE 'tmux run-shell|run-shell -b|\$\{SELF\} poller'
# Expected: 0. do_init must never launch the poller (or anything) again.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_t2s1.txt`
      (diff of sorted output shows only removed lines or nothing).
- [ ] `wc -l scripts/session_history.sh` == **BASELINE − 5** (559 post-S1-only / 557 post-S2).
- [ ] `grep -n 'do_start_poller' scripts/session_history.sh` → zero matches.
- [ ] `grep -nE 'piped-pane|pipe-pane' scripts/session_history.sh` → zero matches.
- [ ] `grep -n 'poller-pid' scripts/session_history.sh` → exactly 2 lines, both in the guard.
- [ ] `sed -n '/^do_init()/,/^}/p' … | grep -nE 'run-shell|setsid|nohup|disown|[[:space:]]&[[:space:]]*$'`
      → zero matches (do_init starts nothing).

### Feature Validation

- [ ] `do_init()` body == seed-if-empty logic (unchanged) + one-shot stale-poller migration guard.
- [ ] Under a throwaway tmux server, `session_history.sh init` runs with NO
      `do_start_poller: command not found` error (L3 step 1).
- [ ] After `init`, `@session-history-poller-pid` is empty (L3 step 3) — including after planting a
      fake stale PID (L3 step 4), proving the self-cleaning drain.
- [ ] Seed logic verified intact: `CURRENT="$s"; save`, `# Same guard as do_hook`, `attached_session`
      each still present exactly once in `do_init`.
- [ ] No new background process is started by `init` (PRD §17 compliance).

### Code Quality Validation

- [ ] The diff touches ONLY the `do_init` region (pipe-pane block + poller block → guard).
- [ ] The kill line mirrors the deleted `do_start_poller`'s proven pattern
      (`[ -n "$old" ] && kill "$old" 2>/dev/null`), verified via git.
- [ ] No re-formatting or "drive-by" fixes to the seed logic or surrounding functions.
- [ ] No `lock()`/`unlock()` calls added inside `do_init` (it already runs under the lock).
- [ ] Change description scoped to "remove pipe-pane legacy + poller start; add stale-poller
      migration guard (T2.S1)" — does not claim T3/T4/M2/M3 work.

### Documentation & Deployment

- [ ] No documentation changes in this task (README is M3; header comments are T4; entry point is M2).
- [ ] No new environment variables. The `@session-history-poller-pid` option is drained, not added.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT start any new process.** PRD §17 forbids `init` from launching anything. The guard
  only KILLS (best-effort) and CLEARS an option. No `tmux run-shell`, no `&`, no `setsid`.
- ❌ **Do NOT call `kill ""` unguarded.** Always guard with `[ -n "$old_pid" ]` first; a bare
  `kill ""` errors in bash. The guard + `2>/dev/null` mirror the proven deleted `do_start_poller`.
- ❌ **Do NOT add a `piped-pane` clear.** The contract specifies the migration guard for
  `poller-pid` only. A stale `piped-pane` value is harmless (nothing reads it) and clearing it is
  out of scope — adding it bloats the diff.
- ❌ **Do NOT touch the seed logic.** Lines 491–508 (the `if [ -z "$CURRENT" ] … fi` block) are
  COMPLIANT (GAP 7a) and must stay byte-for-byte. If your diff shows any change there, you over-reached.
- ❌ **Do NOT edit the case dispatch or Usage string.** That is S2 (parallel). Match your edit only
  inside `do_init`. If you see dispatch changes in your diff, you have collided with S2 — re-anchor.
- ❌ **Do NOT rewrite the header comments** (lines ~42–66, ~89–104) that still mention activity/poller.
  That is T4.S1/T4.S2 scope.
- ❌ **Do NOT key the edit on hard line numbers.** S1 shifted them and S2 is editing in parallel.
  Match on the unique text anchors (the `# Legacy cleanup: older versions…` comment and the
  `do_start_poller` call line).
- ❌ **Do NOT add a "only clear if non-empty" condition.** The clear is intentionally unconditional
  (self-cleaning, matching the deleted pipe-pane block's style). Extra conditions bloat the guard.
- ❌ **Do NOT treat `session_history.sh init` failing with "command not found" as a bug** — that is
  the KNOWN pre-T2 state (S2 leaves `init` broken on purpose). This task's job is to MAKE IT WORK;
  L3 step 1 proves the fix.

---

## Scope Boundaries (one-screen reference)

| Item | This task (T2.S1)? | Owner |
|------|:---:|-------|
| Delete pipe-pane legacy-cleanup block in `do_init` (POST-S1 ~509–515) | ✅ | T2.S1 |
| Delete poller-start comment + `do_start_poller` call (POST-S1 ~517–520) | ✅ | T2.S1 |
| Add one-shot stale-poller migration guard (kill + clear `poller-pid`) | ✅ | T2.S1 |
| Keep seed-if-empty logic (POST-S1 ~491–508) byte-for-byte | ✅ (preserve) | T2.S1 |
| Delete `do_activity`/`do_poller`/`do_start_poller` FUNCTION bodies | ❌ | **S1** (done) |
| Delete case `activity)`/`poller)` branches + Usage tokens | ❌ | **S2** (parallel) |
| Rewrite header comments (WHAT MAKES RELEVANT / CONCURRENCY) | ❌ | **T4.S1 / T4.S2** |
| Change dwell default 10000→30000 | ❌ | **T3** |
| `session_history.tmux` / `README.md` changes | ❌ | **M2 / M3** |
| Add a `piped-pane` one-shot clear | ❌ | out of scope (harmless leftover) |

---

## Confidence Score

**9/10** for one-pass success. This is a single contiguous-region edit inside one function with a
verbatim target block supplied, an exact-text `oldText`/`newText` pair, proven kill semantics
(verified via git against the deleted `do_start_poller`), parse + lint gates with a before/after
baseline, and grep-based structural proofs including the exact expected line count (BASELINE − 5,
given explicitly for both the post-S1 and post-S2 starting baselines) and match counts. The residual 1 point reflects (a) the line numbers cited in the item contract being
pre-S1 (the implementer must read the live file — mitigated by text-anchor edits and the Baseline Note
that handles the post-S1/post-S2 line-count variance), and (b) the
contract's "BEFORE the existing save/return" phrasing being slightly imprecise (the OUTPUT spec
governs; the guard replaces the poller block in place, which is placement-independent for
correctness since kill and seed are independent operations).