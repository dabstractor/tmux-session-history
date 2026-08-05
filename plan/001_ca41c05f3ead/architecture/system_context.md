# System Context — tmux-session-history PRD Alignment

## Executive Summary

The PRD (`PRD.md`) is a **reference spec** that describes the desired final state
of the engine. The current implementation has **diverged** from it: the code
ships a `client_activity`-polling activity-detection subsystem that the PRD
explicitly removes (§12: "It is therefore not wired. Relevance comes from
**selection** and **dwell** only.").

This plan is a **simplification refactor**: strip the activity-detection
machinery, raise the dwell default from 10000→30000 ms (the coupled
compensating change), and update all documentation to match.

## The Core Change

| Aspect | Current Code | PRD Target |
|--------|-------------|------------|
| Relevance signals | selection + focused-activity (client_activity poller) + dwell (3) | selection + dwell only (2) |
| Resident processes (toggle on) | one poller process + transient dwell timers | zero resident processes; only transient dwell timers |
| `dwell-ms` default | 10000 | 30000 |
| Subcommands | init, hook, dwell, activity, poller, prune, maintain, toggle, back, forward, pick, status, reset | init, hook, dwell, prune, maintain, toggle, back, forward, pick, status, reset |
| State options | + `@session-history-poller-pid`, `@session-history-piped-pane` | exactly the 5 in PRD §3 |

## What is COMPLIANT (no changes needed)

The gap analysis (§5) confirms these are already correct and must NOT be touched:
- `do_hook()` — the reactive engine, including close-relocation detection (§11)
- `do_dwell()` — dwell timer fire (touches only tlist)
- `do_toggle()` / `tlist_target()` / `fallback_target()` — toggle logic
- `do_back()` / `do_forward()` — walk primitives
- `do_pick()` — fzf picker
- `prune_dead()` / `cap_to_live()` / `do_maintain()` — pruning & capping
- `do_status()` / `do_reset()` — status/reset
- `promote_tlist()` / `move_to_tip()` / `arm_dwell()` — helpers
- `lock()` / `unlock()` / `load_alive()` / `load()` / `save()` — state primitives
- The three `set-hook -g` lines in `session_history.tmux` (hook wiring)

## Files to Change

1. **`scripts/session_history.sh`** — delete `do_activity()`, `do_poller()`,
   `do_start_poller()`; remove `activity`/`poller` case branches + Usage tokens;
   clean `do_init()` (remove poller start + pipe-pane legacy); change
   `dwell_ms()` default 10000→30000; rewrite header comments (relevance model
   + concurrency section).

2. **`session_history.tmux`** — change dwell default 10000→30000; delete the
   "focused-activity detection" comment block; rewrite the bootstrap comment
   (drop poller rationale).

3. **`README.md`** — rewrite "How it works" promotion model (selection + dwell
   only); delete "How activity detection works" subsection; rewrite async-paths
   paragraph (dwell only); update Options table (dwell-ms: 30000, new
   description); update Troubleshooting (remove "produce output" references).

## Residual Risks

1. **Stale poller process on upgrade.** After removing `do_start_poller`, a
   previously-started poller will keep running until tmux server restarts. The
   reload will no longer kill it. Mitigation: a one-shot guard in `do_init` that
   kills the stale PID (reading `@session-history-poller-pid` before the option
   is removed from the codebase), or document "restart tmux server after
   upgrade."

2. **macOS `flock(1)` absence (HIGH — pre-existing, not introduced by this
   refactor).** `flock(1)` is absent on stock macOS and `lock()` ignores the
   return code, so the plugin silently runs unlocked on macOS. The PRD does not
   mention macOS; this is flagged for awareness but is out of scope for this
   PRD-alignment plan.

3. **UX change: slower silent-presence promotion.** Without the sub-second
   activity signal, a walked-to session is promoted only by the full dwell
   interval (30 s) unless the user re-selects it. The PRD accepts this tradeoff
   (§8, §12).

4. **Dwell default inconsistency risk.** The dwell default must change in THREE
   places simultaneously (engine, entry point, README) or the docs will lie.