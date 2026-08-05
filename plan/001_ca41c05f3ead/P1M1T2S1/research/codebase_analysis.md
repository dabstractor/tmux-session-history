# Codebase Analysis — P1.M1.T2.S1

**Item**: Remove pipe-pane legacy cleanup and poller start; add stale-poller migration guard.
**File under edit**: `scripts/session_history.sh` (one file, function `do_init` only).
**Baseline state**: post-S1 (commit f070deb removed `do_activity`/`do_poller`/`do_start_poller`
function BODIES). File is **564 lines**. S2 (case branches + Usage) is being implemented in
parallel; S2 does NOT touch `do_init`, so its line numbers are stable for this task.

---

## 1. Current `do_init()` — exact content (POST-S1, lines 491–521)

Read live from `scripts/session_history.sh` (offset 488):

```
490: # --- init / status / reset ---------------------------------------------------
491: do_init() {
492:     load
493:     if [ -z "$CURRENT" ]; then
494:         local s; s="$(attached_session)"
495:         [ -z "$s" ] && s="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null | sort -rn | head -n1 | cut -d ' ' -f2-)"
496:         # Same guard as do_hook: only SEED history on a genuinely empty
497:         # timeline. If history exists (e.g. CURRENT was blanked by a prior
498:         # prune), adopt `s` as current without destroying it.
499:         if [ -n "$s" ]; then
500:             if [ "${#HIST[@]}" -eq 0 ]; then HIST=("$s"); IDX=0
501:             else
502:                 local j
503:                 if j="$(index_of "$s")"; then IDX="$j"
504:                 else HIST+=("$s"); IDX=$(( ${#HIST[@]} - 1 )); fi
505:             fi
506:             CURRENT="$s"; save
507:         fi
508:     fi
509:     # Legacy cleanup: older versions kept a pipe-pane on the focused pane,
510:     # tracked in @session-history-piped-pane. Close just THAT pane's pipe (if
511:     # any) so its reader exits; the current design uses no pipes. Targeted so we
512:     # never close another plugin's pipe-pane.
513:     local legacy; legacy="$(G "$(H piped-pane)" 2>/dev/null)"
514:     [ -n "$legacy" ] && tmux pipe-pane -t "$legacy" "" 2>/dev/null
515:     S "$(H piped-pane)" "" 2>/dev/null
516: (blank)
517:     # Start the focused-activity poller: it watches the attached client's
518:     # client_activity timestamp and promotes the current session on input.
519:     # Reload-safe — do_start_poller kills any previous instance first. No-op
520:     do_start_poller
521: }
```

**Three logical blocks (matches contract):**
1. **Seed logic (491–508)** — COMPLIANT (PRD §17 / GAP 7a). KEEP BYTE-FOR-BYTE.
2. **Pipe-pane legacy cleanup (509–515, +blank 516)** — DELETE (option not in PRD §3;
   PRD §12 rejects pipe-pane plumbing; GAP 4b/7b).
3. **Poller start (517–520)** — DELETE & REPLACE with the one-shot stale-poller migration
   guard. Note: line 520 `do_start_poller` calls a function whose BODY S1 already deleted →
   invoking `init` today throws `do_start_poller: command not found`. This task FIXES that.

---

## 2. Helper-function semantics (lines 113, 144, 145)

```bash
113: H() { printf '%s-%s\n' "$P" "$1"; }                 # H poller-pid -> @session-history-poller-pid
144: G() { tmux show-options -gv "$1" 2>/dev/null; }      # GET option value (already suppresses stderr)
145: S() { tmux set-option -g "$1" "$2"; }                # SET global option
```

- `H piped-pane` → `@session-history-piped-pane` ; `H poller-pid` → `@session-history-poller-pid`.
- `G "$(H poller-pid)"` reads the option value; if unset, tmux exits non-zero but `G`'s own
  `2>/dev/null` + the call-site `2>/dev/null` swallow it → empty string.
- `S "$(H poller-pid)" ""` clears the option to the canonical empty value.

---

## 3. PROVEN kill semantics for the stale poller (from deleted `do_start_poller`)

Retrieved via `git show 734be9f:scripts/session_history.sh` (the pre-S1 source):

```bash
do_start_poller() {
    toggle_enabled || return 0
    local old; old="$(G "$(H poller-pid)")"
    [ -n "$old" ] && kill "$old" 2>/dev/null          # ← EXACT pattern to mirror
    tmux run-shell -b "${SELF} poller"
}
```

And inside the deleted `do_poller()`:
```bash
    S "$(H poller-pid)" "$$"        # poller stored ITS OWN PID ($$) on start
    ... loop ...
    S "$(H poller-pid)" ""          # cleared on clean exit
```

**Conclusion — the migration guard is not novel:** the old `do_start_poller` already killed a
predecessor poller with `[ -n "$old" ] && kill "$old" 2>/dev/null`. The stale PID is the PID of
a `session_history.sh poller` process spawned by `tmux run-shell -b` (a plain bash process;
SIGTERM is the correct and proven signal). The guard simply re-uses that exact, battle-tested
kill line and then unconditionally clears the option. Mirroring it verbatim is the lowest-risk
choice.

---

## 4. PRD confirmation (authoritative)

- **PRD §3** persistent/config options: `hist, idx, current, mode, tlist` + toggle keys + dwell-ms +
  popup + `toggle-enabled`. **`poller-pid` and `piped-pane` are NOT present** → both must be gone.
- **PRD §17** `init`: *"Seed initial state if empty (current/attached session)."* Nothing else →
  no background process may be started by `init`.
- **PRD §12**: pipe-pane plumbing is explicitly rejected ("heavy per-pane `pipe-pane` plumbing…
  not wired") → deleting the legacy cleanup is spec-mandated.
- **PRD §13** (concurrency): every mutating command takes `flock` for its whole critical section.
  `init` already acquires the lock in the dispatch (`init) lock; load_alive; do_init; unlock ;;`),
  so the guard runs UNDER the lock — `tmux show-options`/`set-option`/`kill` are all safe there.

---

## 5. Scope boundaries (sibling tasks)

| Item | Owner |
|------|-------|
| Delete `do_activity`/`do_poller`/`do_start_poller` FUNCTION bodies | **S1** (done) |
| Delete case `activity)`/`poller)` branches + Usage tokens | **S2** (in parallel) |
| **Delete pipe-pane cleanup + poller-start call inside `do_init`; add migration guard** | **THIS TASK (T2.S1)** |
| Rewrite header comments (WHAT MAKES RELEVANT / CONCURRENCY) | **T4.S1 / T4.S2** |
| dwell default 10000→30000 | **T3** |
| `session_history.tmux` / `README.md` | **M2 / M3** |

S2 (parallel) edits ONLY the dispatch + Usage string at the bottom (~546–562). It does NOT touch
`do_init`. So `do_init` line numbers (491–521) are stable for this task regardless of S2 outcome.

**Note on "BEFORE the existing save/return" phrasing in the contract:** the contract's OUTPUT
spec is unambiguous — *"do_init should be: seed-if-empty logic (unchanged) + one-shot
stale-poller guard."* Killing a stale poller and seeding history are independent operations
(order immaterial), so the guard replaces the poller-start block in place (end of `do_init`),
satisfying the OUTPUT spec. Do not re-order the seed logic.

---

## 6. Expected net change

- Removed: lines 509–520 (pipe-pane block 509–515 + blank 516 + poller block 517–520) = **12 lines**.
- Added: migration guard = **7 lines** (4-line comment + 3 code lines).
- Net: **−5 lines**. File 564 → **559 lines**. `do_init` ends at ~line 516.

---

## 7. The exact target `do_init()` (post-T2.S1)

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