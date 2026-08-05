# Codebase Analysis — P1.M1.T1.S2

## Task
Remove the `activity)` and `poller)` case-dispatch branches and strip `activity|poller|`
from the Usage string in `scripts/session_history.sh`, so the dispatch + Usage match
PRD §17's exactly-11-command list.

## Contract dependency: S1 (P1.M1.T1.S1)
S1 deletes the contiguous block **lines 320–405** (86 lines) of the current 650-line file
— the bodies/dividers of `do_activity()`, `do_poller()`, `do_start_poller()`.
After S1 lands: **file = 564 lines**, and every line AFTER 405 shifts up by exactly 86.

This PRP (S2) runs AFTER S1. All line numbers below are given as
`CURRENT (pre-S1) → POST-S1`.

## Verified exact content (pre-S1, captured from live file)
4-space indentation throughout the case block. Each branch ends with ` ;;`.

```
632 → 546 : case "$cmd" in
633 → 547 :     init)      lock; load_alive; do_init; unlock ;;
634 → 548 :     hook)      lock; load_alive; load; do_hook "$to"; unlock ;;
635 → 549 :     dwell)     lock; load_alive; do_dwell "$to"; unlock ;;
636 → 550 :     (3-line comment block about locking — keep)
639 → 553 :     activity)  lock; load_alive; do_activity "$to"; unlock ;;            ← DELETE
640 → 554 :     poller)    do_poller ;;           # long-running; locks per fire of do_activity  ← DELETE
641 → 555 :     prune)     lock; load_alive; load; prune_dead; save; unlock ;;
642 → 556 :     maintain)  lock; load_alive; do_maintain; unlock ;;
643 → 557 :     toggle)    lock; load_alive; do_toggle "$to"; unlock ;;
644 → 558 :     back)      lock; load_alive; do_back "$to"; unlock ;;
645 → 559 :     forward)   lock; load_alive; do_forward "$to"; unlock ;;
646 → 560 :     pick)      do_pick "$to" ;;        # self-manages the lock (releases before fzf)
647 → 561 :     status)    do_status ;;            # read-only; no lock
648 → 562 :     reset)     lock; do_reset; unlock ;;
649 → 563 :     *) echo "Usage: $0 {init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;   ← EDIT (remove activity|poller|)
650 → 564 : esac
```

## Exact bytes of the lines S2 touches (cat -A; `$` = line end, no trailing ws)
```
    activity)  lock; load_alive; do_activity "$to"; unlock ;;$
    poller)    do_poller ;;           # long-running; locks per fire of do_activity$
    *) echo "Usage: $0 {init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;$
```

## The two deletions (whole-line deletes)
- POST-S1 ~553: `    activity)  lock; load_alive; do_activity "$to"; unlock ;;`
- POST-S1 ~554: `    poller)    do_poller ;;           # long-running; locks per fire of do_activity`

## The one edit (Usage string)
Replace substring `activity|poller|` with nothing inside the `{...}` token list.

BEFORE: `{init|hook|dwell|activity|poller|prune|maintain|toggle|back|forward|pick|status|reset}`
AFTER : `{init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset}`

Result matches PRD §17 order EXACTLY (11 cmds):
init, hook, dwell, prune, maintain, toggle, back, forward, pick, status, reset.

## Post-S2 expected state
- File line count: 564 (post-S1) − 2 (deleted branches) = **562 lines**.
- `grep -c 'activity'` over the dispatch+usage region → 0.
- `grep -c 'poller'` over the dispatch+usage region → 0.
- The 3-line comment at old 636–638 (about locking) is UNCHANGED.
- `do_start_poller` call site inside `do_init` (POST-S1 ~520) is UNCHANGED — T2 scope.

## Out-of-scope (must NOT touch)
| Item | Owner |
|------|-------|
| `do_start_poller` call inside `do_init` (~520 post-S1) | T2.S1 |
| Header comment region mentioning activity (lines 89–97) | T4.S2 |
| dwell default 10000→30000 | T3 |
| README.md | M3 |
| session_history.tmux | M2 |

## Tooling confirmed available
- `/usr/bin/bash` — `bash -n` parse gate works.
- `/usr/bin/shellcheck` — lint gate works.
- `/usr/bin/tmux` — live smoke test (status/reset paths) possible.

## PRD cross-reference (provided in task)
- **§17** Subcommand reference: exact 11-command table. Authoritative list to match.
- **§12** Why there is no output-activity signal: justifies WHY activity/poller are gone
  (alert-activity only fires for background windows; no robust focused-activity primitive).

## No external research needed
This is a pure bash `case`/string edit. No library, no API, no network. The only
references are PRD §17 (given) and the live file (analyzed above). External subagent
research would add no value.