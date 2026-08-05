# GAP ANALYSIS — tmux-session-history vs PRD

Reference spec: `PRD.md` (desired final state).
Files analyzed: `scripts/session_history.sh` (650 lines), `session_history.tmux` (88 lines), `README.md` (199 lines).

Severity legend: 🔴 BLOCKER (spec violation / dead code that must be removed), 🟡 MINOR (doc/comment drift, default value), 🟢 COMPLIANT (no change needed).

---

## GAP 1 — ACTIVITY DETECTION must be removed (PRD §12)

PRD §12: *"It is therefore not wired. Relevance comes from **selection** and **dwell** only."*
PRD §6: a session is promoted by exactly two causes — (1) direct selection, (2) dwell. There is NO focused-activity / `client_activity` signal.

The current engine implements a `client_activity`-polling activity promoter as a **third** relevance path. Every piece of it must be removed from `scripts/session_history.sh`:

| # | Lines | Function / item | Required change |
|---|-------|-----------------|-----------------|
| 1a | `320-341` | `do_activity()` block (divider comment `320-325`, function body `326-340`, blank `341`) | 🔴 DELETE entirely |
| 1b | `342-395` | `do_poller()` block (divider comment `342-367`, function `368-394`, blank `395`) | 🔴 DELETE entirely |
| 1c | `396-405` | `do_start_poller()` block (comment `396-398`, function `399-404`, blank `405`) | 🔴 DELETE entirely |
| 1d | `639` | case dispatch `activity)  lock; load_alive; do_activity "$to"; unlock ;;` | 🔴 DELETE line |
| 1e | `640` | case dispatch `poller)    do_poller ;;` | 🔴 DELETE line |
| 1f | `649` | Usage string lists `activity|poller|` | 🔴 Remove those two tokens |
| 1g | `602-606` | inside `do_init()`: the "Start the focused-activity poller" comment (`602-605`) + `do_start_poller` call (`606`) | 🔴 DELETE (see also GAP 7) |

Functions `do_activity`, `do_poller`, `do_start_poller` become unreferenced after 1d/1e/1g; deleting 1a-1c removes them. No other call sites exist (verified by grep).

**Ripple — header comment references to activity** are tracked under GAP 6; `@session-history-poller-pid` option usage (lines `369`, `393`, `401`) under GAP 4.

---

## GAP 2 — DWELL DEFAULT must be 30000, currently 10000 (PRD §15)

PRD §15 / §8 / §14: default `@session-history-dwell-ms` = `30000` (30 s). Non-numeric → default `30000`.

| # | File:Line | Current | Required |
|---|-----------|---------|----------|
| 2a | `scripts/session_history.sh:154` | `dwell_ms() { ... echo 10000 ;; ... }` | 🔴 change `10000` → `30000` |
| 2b | `session_history.tmux:55` | `tmux set-option -g '@session-history-dwell-ms' 10000` | 🔴 change `10000` → `30000` |
| 2c | `scripts/session_history.sh:58` | header comment "(default 10000 ms)" | 🟡 update to 30000 (or removed via GAP 6 rework) |
| 2d | `README.md:86` | options table default `\| 10000 \|` | 🟡 change to `30000` |

Note: `README.md:119` already says "default 30 s" — so the README is internally inconsistent today (86 vs 119); fixing 2d reconciles it. The PRD never mentions `10000` anywhere (verified: 0 hits).

---

## GAP 3 — SUBCOMMAND REFERENCE: remove `activity` and `poller` (PRD §17)

PRD §17 lists exactly: `init, hook, dwell, prune, maintain, toggle, back, forward, pick, status, reset`. The engine adds two extra subcommands.

| # | Lines | Item | Required change |
|---|-------|------|-----------------|
| 3a | `639` | case `activity)` | 🔴 DELETE (same as 1d) |
| 3b | `640` | case `poller)` | 🔴 DELETE (same as 1e) |
| 3c | `649` | Usage string `{init\|hook\|dwell\|activity\|poller\|prune\|...}` | 🔴 Remove `activity|poller|` (same as 1f) |

After removal, the case dispatch + Usage string match PRD §17 exactly (11 commands).

---

## GAP 4 — OPTIONS not in PRD (PRD §3)

PRD §3 persistent state options (5): `@session-history-hist`, `@session-history-idx`, `@session-history-current`, `@session-history-mode`, `@session-history-tlist`.
PRD §3 also config options + internal `@session-history-toggle-enabled`.
The engine uses two options NOT in the PRD:

| # | Option | Used at lines | Required change |
|---|--------|---------------|-----------------|
| 4a | `@session-history-poller-pid` | `369`, `393`, `401` | 🔴 DELETE (all inside `do_poller`/`do_start_poller`, removed via GAP 1) |
| 4b | `@session-history-piped-pane` | `596` (comment), `599`, `601` (inside `do_init`) | 🔴 DELETE the whole legacy pipe-pane cleanup block (GAP 7) |

Neither option appears in `session_history.tmux` or `README.md`. After GAP 1 + GAP 7 removals, the option set equals the PRD.

---

## GAP 5 — DO_HOOK vs PRD §5 / §11

The task asks to compare `do_hook()` (`scripts/session_history.sh:236-300`) against PRD §5, with attention to the §11 close-relocation detection.

**Result: do_hook is COMPLIANT.** No removals needed in `do_hook`. Details:

- 🟢 **Close-relocation detection (§11) is present and correct.** Lines `268-274`:
  ```
  if ! session_exists "$from"; then
      if i="$(index_of "$to")"; then IDX="$i"
      else HIST+=("$to"); IDX=$(( ${#HIST[@]} - 1 )); fi
      CURRENT="$to"; S "$(H mode)" ""; save; return
  fi
  ```
  This is exactly PRD §11's "leaving session (`from`) no longer exists → pure cursor move, no `move_to_tip`, no `promote_tlist`, no dwell." Note PRD §5's numbered algorithm does not show this block as a numbered step, but §11 documents it as part of the hook; the implementation matches §11.

- 🟡 **Two-tier seed guard (minor divergence from §5 step 1, but consistent with §11).**
  PRD §5 step 1: *"If CURRENT is empty (first fire / after reset): hist=[to]; idx=0; current=to."*
  Current code has two guards instead of one:
  - Line `247-249`: `if HIST empty` → genuine first fire, seed `[to]`.
  - Line `252-256`: `if CURRENT empty` (but HIST non-empty) → adopt `to` as current, do NOT wipe timeline.
  This is *more* defensive than §5 step 1's literal text, but is justified by PRD §11's statement that `prune_dead` may leave `CURRENT` blank mid-relocation. Compliant in spirit; no change required. (If strict literal §5 conformance is desired, the second guard's blank-CURRENT branch is the thing to reconcile — but removing it would re-introduce the wipe hazard §11 warns about. Recommend leaving as-is.)

- 🟢 No `activity` references inside `do_hook` — the hook already only arms dwell on WALK (line `299`), matching §5 step 8 and §8 arming rule.
- 🟢 Branch structure (walk / toggle / nav, lines `282-293`) matches §5 step 5.
- 🟢 `mode` cleared at end of every path (§4 one-shot, §5 step 7); `save()` does not write `mode` (comment lines `178-184`).

**Conclusion for GAP 5:** no edits to `do_hook` required for the activity removal. The only related cleanup is the header comments (GAP 6).

---

## GAP 6 — HEADER COMMENTS describe activity as the PRIMARY signal (PRD §6)

The engine header comment block runs `scripts/session_history.sh:1-108` (line `109` = `set -u`). It extensively describes focused-activity / `client_activity` polling as a relevance mechanism that PRD §6/§12 say does not exist. Must be rewritten so relevance = **selection + dwell only**.

Specific offending regions:

| # | Lines | Content | Required change |
|---|-------|---------|-----------------|
| 6a | `42-66` | "WHAT MAKES A SESSION RELEVANT" bullet: **"focused activity (the PRIMARY signal)"** — multi-paragraph description of `client_activity` polling; presents dwell only as the "SILENT-PRESENCE fallback" | 🔴 REWRITE to PRD §6's two causes: (1) direct selection, (2) dwell. Remove all `client_activity`/poller/`alert-activity` text. |
| 6b | `58` | "(default 10000 ms)" inside the dwell bullet | 🟡 30000 (covered by GAP 2) |
| 6c | `89-104` | CONCURRENCY block: names `activity` as the second async path, references `do_poller`, `do_activity`, the poller firing "~0.5 s", "the only resident process for activity" | 🔴 REWRITE: the only async path is now **dwell** (PRD §8). Remove all activity/poller sentences. |
| 6d | `124` | "keypresses are ~150 ms apart and the poller fires only every ~0.5 s" | 🟡 remove "and the poller fires only every ~0.5 s" |

PRD §6's authoritative wording: promote by (1) direct selection (NAVIGATION/TOGGLE) and (2) dwell; "Walking never promotes." The header should mirror this.

---

## GAP 7 — INIT: remove poller start + pipe-pane legacy cleanup (PRD §17)

PRD §17 `init`: *"Seed initial state if empty (current/attached session)."* Nothing else.

Current `do_init()` is `scripts/session_history.sh:577-607`:

| # | Lines | Content | Required change |
|---|-------|---------|-----------------|
| 7a | `578-594` | Seed logic (`if CURRENT empty` → attach/session-list fallback → seed or adopt; HIST-empty guard) | 🟢 COMPLIANT — matches PRD §17 (the HIST-empty guard is the same defensive nuance noted in GAP 5). Keep. |
| 7b | `595-601` | Legacy `pipe-pane` cleanup: reads `@session-history-piped-pane`, closes that pane's pipe, clears the option | 🔴 DELETE (option not in PRD §3; PRD §12 explicitly rejects pipe-pane plumbing). Lines `595` (comment)–`601`. |
| 7c | `602-606` | "Start the focused-activity poller" comment (`602-605`) + `do_start_poller` call (`606`) | 🔴 DELETE (same as 1g). |

After 7b+7c, `do_init()` = seed-if-empty only, exactly PRD §17.

---

## GAP 8 — ENTRY POINT focused-activity section (session_history.tmux)

`session_history.tmux` has a dedicated section documenting focused-activity detection that must go.

| # | Lines | Content | Required change |
|---|-------|---------|-----------------|
| 8a | `55` | `tmux set-option -g '@session-history-dwell-ms' 10000` | 🔴 → 30000 (GAP 2b) |
| 8b | `70-77` | "# --- focused-activity detection (only with toggle bound) ---" comment block — describes `client_activity`/poller/`alert-activity` | 🔴 DELETE the whole block (PRD §12: not wired; no extra hook). |
| 8c | `79-83` | Bootstrap comment: *"do_init reads ... whether to start the focused-activity poller"* | 🟡 REWRITE — keep `init` running LAST, but the rationale is no longer the poller; init seeds state and (post-cleanup) nothing async. Drop poller/poller-race wording. |

Note: the entry point itself never starts the poller directly (that was `do_init`→`do_start_poller`); so removing GAP 1g + 8b/8c fully de-activates activity at load time.

---

## GAP 9 — README drift (secondary, PRD §6/§15)

README documents the activity-based model and the 10000 default. Not in the task's enumerated list but required for spec consistency.

| # | Lines | Content | Required change |
|---|-------|---------|-----------------|
| 9a | `86` | options table `\| @session-history-dwell-ms \| 10000 \|` + long description citing "typing/interacting promotes it immediately" | 🔴 default → 30000; rewrite description to selection+dwell only (drop the "working there promotes immediately" activity claim) |
| 9b | `110-116` | "How it works" relevance bullets: first bullet is **"type, switch panes/windows, or run any tmux command"** as the *primary* signal | 🔴 DELETE this bullet; reorder so **select it directly** + **dwell on it** are the two causes (PRD §6) |
| 9c | `126-127` | "the instant you produce output in a walked-to session, activity promotes it immediately" | 🔴 DELETE/REWRITE |
| 9d | `130-148` | "**How activity detection works.**" paragraph + the following paragraph referencing "focused-activity detection is the other [async path]" | 🔴 DELETE the "How activity detection works" paragraph; rewrite the async-path paragraph to mention **dwell only** |
| 9e | `142-148` | "focused-activity detection is the other [async path]" / "activity promotes it instead" | 🔴 REWRITE (dwell is now the only async path) |
| 9f | `187-189` | "or produce output in it while viewing it, or dwell on it" | 🟡 change to "select it or dwell on it" |
| 9g | `74` | "the relevance list, the dwell timers — is wired" | 🟢 OK (no activity mention) |

---

## CROSS-CUT: full removal checklist (one place)

To make the engine match the PRD, a single edit pass must touch:

**`scripts/session_history.sh`**
- DELETE lines `320-341` (`do_activity`)
- DELETE lines `342-395` (`do_poller`)
- DELETE lines `396-405` (`do_start_poller`)
- DELETE case lines `639-640` (`activity)`, `poller)`)
- EDIT line `649` (Usage: drop `activity|poller|`)
- DELETE `do_init` lines `595-601` (pipe-pane cleanup) and `602-606` (poller start)
- EDIT line `154` (`dwell_ms` default 10000 → 30000)
- REWRITE header `1-108` (activity paragraphs at `42-66`, `89-104`; dwell default `58`)

**`session_history.tmux`**
- EDIT line `55` (dwell default → 30000)
- DELETE lines `70-77` (focused-activity comment block)
- REWRITE lines `79-83` (bootstrap comment, drop poller rationale)

**`README.md`**
- EDIT line `86` (default + description)
- REWRITE `110-148` (remove activity as a relevance cause; one async path = dwell)
- EDIT `187-189`

No changes needed to: `do_hook` (GAP 5 compliant), `do_dwell`, `do_toggle`, `do_back/forward`, `do_pick`, `prune_dead`, `cap_to_live`, `do_maintain`, `do_status`, `do_reset`, `promote_tlist`, `move_to_tip`, `arm_dwell`, lock/load helpers, or the three `set-hook` lines in `session_history.tmux` (46-48) — all already match the PRD.

---

## Open questions / residual risks

1. **Existing poller processes on upgrade.** After deploy, a previously-started poller (tracked in `@session-history-poller-pid`) will keep running until the tmux server restarts or it is killed. Since `do_start_poller` is removed, a reload will no longer kill it. Mitigation: `do_reset` or a one-time migration could kill the stale PID, but PRD §17 `reset` only clears history state. Consider documenting "restart tmux server after upgrade" or adding a one-shot PID kill in `do_init` guarded by the option's prior existence. (Not a spec blocker; PRD is silent on migration.)
2. **`do_hook` two-tier seed guard (GAP 5).** Strictly more defensive than §5 step 1's literal text; aligned with §11. Recommend keeping. Flagged only because a literal-reading reviewer might ask.
3. **`@session-history-piped-pane` option cleanup.** Removing the read in `do_init` (7b) means a stale option value left from an old install is never cleared. Harmless (nothing reads it) but lingers. Optional: a one-shot clear.