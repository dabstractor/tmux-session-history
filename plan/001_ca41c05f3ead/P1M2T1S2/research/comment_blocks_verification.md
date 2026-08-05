# P1.M2.T1.S2 — Verified facts: focused-activity block + bootstrap comment

## Source of truth
- Task contract: delete GAP 8b, rewrite GAP 8c (see
  `plan/001_ca41c05f3ead/architecture/gap_analysis.md` lines 141–151).
- PRD authority: §12 (no output-activity signal → not wired), §9 (gating → no
  extra hooks with toggle), §16 (hook/binding reference), §17 (subcommand ref:
  `init` = "Seed initial state if empty").

## File under edit: `session_history.tmux` (88 lines, UTF-8, shebang `#!/usr/bin/env bash`)

### Exact bytes of the edit region (lines 68–88, via `cat -A`)
```
68: [ -n "$pick_key" ]    && tmux bind-key "$pick_key"    run-shell "${SCRIPT} pick    \"#{session_name}\""$
69: (blank)$
70: # --- focused-activity detection (only with toggle bound) --------------------$   [len 78]
71: # The relevance list's PRIMARY signal is input in the session you are viewing M-bM-^@M-^YT$   [em-dash = E2 80 94]
72: # typing, pane/window switches, or any tmux command. tmux's alert-activity cannot$
73: # see the focused window, so the engine watches the attached client's$
74: # client_activity timestamp instead (see scripts/session_history.sh). The$
75: # poller promotes the current session whenever that timestamp advances while the$
76: # session stays the same; no extra hook is needed here. With toggle unbound the$
77: # poller is never started: no resident processes.$
78: (blank)$
79: # Bootstrap the engine LAST, after every option/hook/key above is in place M-bM-^@M-^YT$   [em-dash]
80: # do_init reads @session-history-toggle-enabled (set by the toggle block) to$
81: # decide whether to start the focused-activity poller, so it must run after that$
82: # flag is set (calling it earlier raced the async run-shell ahead of the toggle$
83: # block and left the poller unset on reload).$
84: tmux run-shell "${SCRIPT} init"$
85: (blank)$
86: # The bind lines above short-circuit to false (exit 1) when their key is empty;$
87: # end on a no-op so plugin load always reports success.$
88: :$
```

### `do_init()` current body (engine `scripts/session_history.sh:471`) — verified, NO poller start
```bash
do_init() {
    load
    if [ -z "$CURRENT" ]; then
        local s; s="$(attached_session)"
        [ -z "$s" ] && s="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null | sort -rn | head -n1 | cut -d ' ' -f2-)"
        # ... seed HIST/IDX/CURRENT only when genuinely empty, then save
        if [ -n "$s" ]; then ... CURRENT="$s"; save; fi
    fi
    # One-shot migration guard: kill stale @session-history-poller-pid + clear option
    local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"
    [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
    S "$(H poller-pid)" "" 2>/dev/null
}
```
Dispatch: `init)  lock; load_alive; do_init; unlock ;;` (synchronous, under flock).

**Confirmed:** `do_init` does NOT read `@session-history-toggle-enabled` and does NOT start any
poller/background process (grep for `run-shell|setsid|nohup|disown|&\s*$` in the function body = 0).
The old bootstrap comment's rationale is therefore doubly obsolete (it claimed do_init reads the
toggle flag to start a poller — neither is true anymore). P1.M1.T2 removed the `do_start_poller` call;
the engine file's only remaining "poller" text is the self-cleaning migration guard inside `do_init`.

## Activity/poller reference enumeration in session_history.tmux (grep -iE 'activity|poller|client_activity|alert|focused')
```
12: # extra hooks, no background sleepers, no monitor-activity. ...   ← KEEP (negation; asserts absence; consistent w/ PRD §9)
70,72,73,74,75,77: focused-activity block   ← DELETE (lines 70-77)
81,83: bootstrap comment poller references   ← REWRITE (lines 79-83)
```
After the edit the ONLY "activity" token left in the file is line 12's "no monitor-activity"
(a correct negation). "poller", "client_activity", "alert-activity", "focused-activity" all → 0.

## Parallel-execution safety vs P1.M2.T1.S1 (same file)
- S1 edits line 55 (`10000` → `30000`), ABOVE the edit region (70–83), ±0 lines.
- This task edits lines 70–83, BELOW line 55, net −9 lines.
- Neither shifts the other's anchors. **Anchor on TEXT, not line numbers.** The header comment
  `# --- focused-activity detection (only with toggle bound) ---` is UNIQUE in the file.

## em-dash encoding note
The file uses UTF-8 em-dashes (—, U+2014, bytes E2 80 94). The rewritten comment keeps one em-dash
to match file convention. Exact-match edits must preserve UTF-8 (do not substitute `--` or `—` ASCII).

## Net effect
- oldText = lines 70–83 (14 lines: 8 focused block + 1 blank + 5 bootstrap comment).
- newText = 5-line rewritten bootstrap comment.
- Net −9 lines; file 88 → 79 lines. Line 84 (`tmux run-shell "${SCRIPT} init"`) and the epilogue
  (lines 85–88) are preserved byte-for-byte.

## Decision: ONE combined edit (not two)
The region 70–83 is contiguous (focused block + blank + bootstrap comment). A single
`oldText`→`newText` replacement is atomic, unambiguous, and provably removes every activity/poller
token in the region. The header line at 70 makes the oldText globally unique.