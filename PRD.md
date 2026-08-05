# tmux-session-history — Specification

**Status:** reference spec for the engine. Detailed enough to re-implement the
feature from scratch. Read alongside `scripts/session_history.sh` (the engine)
and `session_history.tmux` (the entry point that wires hooks + bindings).

---

## Table of contents

1. [Purpose & scope](#1-purpose--scope)
2. [Concepts](#2-concepts)
3. [State model](#3-state-model)
4. [Switch classification & the mode flag](#4-switch-classification--the-mode-flag)
5. [The reactive engine (`do_hook`)](#5-the-reactive-engine-do_hook)
6. [Relevance — what promotes and what doesn't](#6-relevance--what-promotes-and-what-doesnt)
7. [Toggle](#7-toggle)
8. [Dwell](#8-dwell)
9. [Gating](#9-gating)
10. [Pruning & capping](#10-pruning--capping)
11. [Close-current behavior (the "4a" rule)](#11-close-current-behavior-the-4a-rule)
12. [Why there is no output-activity signal](#12-why-there-is-no-output-activity-signal)
13. [Concurrency & race safety](#13-concurrency--race-safety)
14. [Invariants & edge cases](#14-invariants--edge-cases)
15. [Configuration reference](#15-configuration-reference)
16. [Hook & binding reference](#16-hook--binding-reference)
17. [Subcommand reference](#17-subcommand-reference)
18. [Testing](#18-testing)
19. [Known limitations](#19-known-limitations)
20. [File map](#20-file-map)

---

## 1. Purpose & scope

Four session-navigation primitives over tmux sessions:

| Primitive | Style | Default key |
|---|---|---|
| `toggle` | Alt-Tab flip between the two most-*relevant* sessions | unbound |
| `back` | browser back (toward older history) | unbound |
| `forward` | browser forward (toward newer history; dead at tip) | unbound |
| `pick` | fzf picker over live history | unbound |

The distinguishing idea: **toggle targets sessions by relevance, not recency.**
Browsing past a session with back/forward never makes it a toggle target; you
have to select it or stay on it. This keeps toggle between the sessions you are
*actively using* rather than the ones you most recently skimmed.

All keys are opt-in. Nothing is bound by default. The toggle feature (and all
of its relevance machinery) is entirely dormant unless `@session-history-toggle-
key` is set.

**Environment:** tmux 2.4+ (3.2+ for the fzf-tmux popup). Single attached client
assumed. State is global.

---

## 2. Concepts

There are two independent pieces of state. Keeping them separate is the central
design decision; do not conflate them.

### The timeline (history) — always on
A duplicate-free, ordered list of every session the client has visited, with a
**cursor** (`idx`) pointing at the current session. Back/forward move the
cursor. The timeline records *where you've been*.

- Index `0` is the **oldest** visited session; the highest index is the
  **newest** (the "tip"). The cursor normally sits at the tip.
- Forward is "dead at the tip" exactly like a browser: after a navigation the
  cursor is at the tip and forward does nothing until you walk back.

### The relevance list — only when toggle is bound
A second, separate, duplicate-free list of sessions ordered by recency of
*use* (most-recently-used first). This is what toggle reads. It records *what
you've been working in*, which is a strict subset of where you've been.

Toggle flips the cursor to the first **live** entry of this list that isn't the
current session — so consecutive toggles oscillate between the two
most-recently-used sessions.

### Key invariant
The two lists are maintained independently. Walking moves the history cursor
but never touches the relevance list. Selecting or dwelling promotes in the
relevance list but, for walks, leaves the timeline intact.

---

## 3. State model

All state lives in tmux **global user options**, namespaced `@session-history-*`.

### Persistent state

| Option | Type | Meaning |
|---|---|---|
| `@session-history-hist` | `\n`-joined names | The timeline, oldest-first, deduped. |
| `@session-history-idx` | int | Cursor: index of the current session in `hist`. |
| `@session-history-current` | name | Last-known current session (so the hook can diff from→to). |
| `@session-history-mode` | `""` \| `walk:<t>` \| `toggle:<t>` | **Transient** switch flag (see §4). |
| `@session-history-tlist` | `\n`-joined names | The relevance list, most-recent-first, deduped. Only meaningful when toggle is enabled. |

### Configuration (user-facing)

| Option | Default | Meaning |
|---|---|---|
| `@session-history-toggle-key` | `""` | Key for toggle. Empty ⇒ toggle feature fully disabled. |
| `@session-history-back-key` | `""` | Key for back. |
| `@session-history-forward-key` | `""` | Key for forward. |
| `@session-history-pick-key` | `""` | Key for pick. |
| `@session-history-dwell-ms` | `30000` | Dwell threshold in ms. `0` disables dwell. |
| `@session-history-popup` | `on` | Use fzf-tmux popup for pick (`off` = inline). |

### Internal flag

| Option | Set by | Meaning |
|---|---|---|
| `@session-history-toggle-enabled` | entry script | `"on"` iff a toggle key is bound. The engine reads this to decide whether to maintain `tlist` and arm dwell timers. |

The empty string is the canonical "unset/empty" value for all list options
(never `[]` or similar). `0` is a valid `idx`.

---

## 4. Switch classification & the mode flag

Every session switch funnels through one hook: `client-session-changed`. The
engine must distinguish three kinds of switch to handle each correctly. It does
so with the transient `@session-history-mode` flag, set an instant *before* the
switch by the primitive that initiates it.

| Kind | Initiator | Mode value before switch | History effect | Relevance effect |
|---|---|---|---|---|
| **WALK** | `back`, `forward` | `walk:<target>` | cursor move only (timeline untouched) | none |
| **TOGGLE** | `toggle` | `toggle:<target>` | cursor move only (timeline untouched) | promote target to #1 |
| **NAVIGATION** | `pick`, sessionx, manual `switch-client` | `""` | collapse forward + append target at tip | promote target to #1 |

The flag carries the *intended* target. The hook only honors it when the
intended target equals the actual landing session (`#{session_name}`). This
match-or-fall-through is what makes stale flags safe: an unmatched flag is
treated as a plain navigation.

Because the hook **clears the flag at the end of every run**, the flag is a
strict one-shot handoff. `save()` deliberately does **not** write `mode`; the
flag is managed explicitly (set by the initiator, cleared by the hook) so a
save can never clobber an in-flight flag.

---

## 5. The reactive engine (`do_hook`)

`do_hook` is wired to `client-session-changed` and is the spine of the plugin.
Algorithm (`to` = the session just switched to):

```
1. If CURRENT is empty (first fire / after reset):
     hist = [to]; idx = 0; current = to; clear mode; save; return.
2. If to == current: clear mode; return.        (no-op switch)
3. from = current.
4. Parse mode -> kind (walk|toggle|nav) and mtarget.
5. Branch:
   WALK   (mode walk:<t>, mtarget == to, to in hist):
       idx = index_of(to)                       # cursor move ONLY
   TOGGLE (mode toggle:<t>, mtarget == to):
       idx = index_of(to)        # cursor move, NO collapse
         (if to not in hist: collapse+append — rare fallback)
       if toggle_enabled: promote_tlist(to)
   else (NAVIGATION, or any unmatched/stale flag):
       collapse_and_append(to); idx = last      # browser end-of-road
       if toggle_enabled: promote_tlist(to)
6. current = to.
7. Clear mode (consume the flag).
8. If kind == WALK and toggle_enabled: arm_dwell(to).
9. save().
```

Helpers:

- `collapse_and_append(to)`: keep `hist[0..idx]` with `to` removed, then append
  `to`. Result: forward history is dropped and `to` is the new tip.
- `promote_tlist(s)`: remove `s` from `tlist` (dedup) and prepend it. In-memory.
- `index_of(s)`: returns the index of `s` in `hist` via stdout, exit 1 if absent.

---

## 6. Relevance — what promotes and what doesn't

A session is promoted to the **front** of the relevance list (`promote_tlist`)
by exactly two causes:

1. **Direct selection.** Any NAVIGATION or TOGGLE promotes the session you land
   on (`to`). This covers `pick`, tmux-sessionx, a manual `switch-client`, and
   toggle itself.
2. **Dwell.** Reaching a session by a WALK and staying longer than
   `@session-history-dwell-ms` (see §8).

**Walking never promotes.** This is the rule that makes toggle track usage
rather than browsing. If you are working in A, walk the timeline back through
several sessions to B, and toggle, you flip to A (the thing you were using) —
not to the session adjacent to B — because the walk never promoted the
in-between sessions.

`promote_tlist` is idempotent and dedups, so promoting a session already at #1
is a no-op and promoting one lower down moves it to #1.

---

## 7. Toggle

`do_toggle(cur)`:

1. `target =` the first **live** entry of `tlist` that is not `cur`.
   - If `cur` is #1, this yields #2; otherwise it yields #1. So this single rule
     produces correct oscillation in every case (see §14).
2. If `tlist` yields nothing, `target = fallback_target(cur)`: the nearest live
   neighbor of the cursor in `hist` (search outward symmetrically), finally any
   other live session. This is the self-healing path.
3. If `target` is empty or equals `cur`: message "no other session to toggle to";
   return.
4. Set `mode = toggle:<target>`; `switch-client -t target`. The hook then moves
   the cursor to `target` (no collapse) and promotes `target` to #1.

### Oscillation, precisely
Because toggle promotes its target to #1 and the target is always "the top live
entry that isn't current," repeated toggles swap #1 and #2 of the relevance
list. The current session is always #1 immediately after a toggle/navigation/
dwell. The only time current is *not* #1 is right after walking somewhere
(without promoting) or right after the close-current landing (see §11) — and in
exactly those cases toggle correctly refuses to "return" to that non-relevant
session, by design.

### Self-healing
If the would-be target was closed, `tlist_target` skips dead entries; if the
whole list is dead/empty, `fallback_target` finds the nearest live history
neighbor. Toggle never breaks — it degrades to the most useful live session.

---

## 8. Dwell

Dwell covers the case "I walked somewhere and then actually stayed to work,"
which selection doesn't capture (you didn't choose it, you browsed to it) and
which we don't want to count instantly (you might be passing through).

### Arming
Only a **WALK** arrival arms a dwell timer (in `do_hook`, step 8). Navigations
and toggles already promoted the session to #1, so a dwell there would be a
redundant no-op; arming only on walks minimizes background jobs.

`arm_dwell(to)`:
```
ms = dwell_ms()                      # @session-history-dwell-ms, default 30000
if ms <= 0: return                   # 0 disables dwell entirely
sec = max(1, ms / 1000)
tmux run-shell -b "sleep ${sec}; \"${SELF}\" dwell \"${to}\""
```

`run-shell -b` is a **tmux-managed background job**: it returns immediately (it
does **not** block the synchronous hook) and its lifecycle is owned by the
server. This is preferred over a shell `&` subshell, which can orphan and
outlive the server.

### Firing
`do_dwell(s)` is the timer's callback:
```
if not toggle_enabled: return
if s != @session-history-current: return     # stale timer -> no-op
# read-modify-write ONLY @session-history-tlist (never hist/idx/current/mode)
promote s to front of tlist; save tlist
```

The "still current?" guard uses the engine's own tracked current
(`@session-history-current`), which is kept in sync on every switch, so the
guard needs no attached client and a stale timer is a clean no-op.

### Why dwell touches only the relevance list
The synchronous hook does the read-modify-write on the *critical* state
(`hist`/`idx`/`current`/`mode`) and is race-free. Dwell is the one asynchronous
path. To make it incapable of corrupting critical state, it is restricted to a
read-modify-write of `tlist` alone. The worst conceivable failure is a rare
lost-update on `tlist`, which is best-effort and self-heals on the next
navigation or dwell. See §13.

---

## 9. Gating

The entire toggle feature is gated on `@session-history-toggle-key` being set.

The entry script (`session_history.tmux`):
- If the key is non-empty: binds it and sets `@session-history-toggle-enabled on`.
- If empty: sets `@session-history-toggle-enabled off` and binds nothing.

The engine reads `toggle_enabled` (`= on`?) to decide:
- whether to promote in `tlist` (NAVIGATION/TOGGLE branches),
- whether to arm dwell timers (WALK branch).

With toggle disabled, the engine still runs the full history engine (back /
forward / pick) and maintains `hist`/`idx`/`current`/`mode`; it simply never
touches `tlist` and never arms dwell. `tlist` stays empty and harmless.

This means a user who only wants back/forward pays nothing for the toggle
machinery — no background timers, no relevance bookkeeping, no extra hooks.

---

## 10. Pruning & capping

Two maintenance hooks keep both lists consistent with reality.

### `session-closed` → `prune_dead`
For each list, drop entries whose session no longer exists; everything above
shifts down. For `hist`, adjust `idx` by the number of removed entries that were
*below* the cursor. **Never add anything.** If the current session itself is
gone, set `current` to the (now) attached session and re-derive `idx`.

### `session-created` → `do_maintain`
Run `prune_dead`, then cap each list to the number of currently-open sessions:
- `hist`: drop from the front (oldest visited, index 0) — never the current.
- `tlist`: drop from the end (oldest relevant) — never the current.

Neither list can ever reference a dead session or exceed the open-session count.

---

## 11. Close-current behavior (the "4a" rule)

**Requirement.** When the session you are currently on closes, tmux moves you
to another session. That landing session must **not** be promoted into the
relevance list merely because tmux dropped you there — otherwise toggle would
"return" you to a session you never chose, until you dwell on or select it.

**How it is satisfied.** When the current session closes, tmux relocates the
client to another session and fires `session-closed` (→ `prune_dead`); on many
setups the relocation *also* fires `client-session-changed` for the landing.
Two independent mechanisms keep the landing from being treated as a navigation
(so it is neither reordered to the tip nor promoted in the relevance list):

- **`do_hook` close-relocation detection.** If the session being LEFT
  (`from` = the previous `current`) no longer exists, the switch was forced by a
  close, so the hook performs a pure cursor move to the landing's existing
  position (no `move_to_tip`, no `promote_tlist`, no dwell). This makes the
  outcome identical whether the landing hook or `prune_dead` acquires the lock
  first.
- **`prune_dead` cursor-based landing.** If the attached client can't be
  resolved when `session-closed` fires (mid-relocation, or no client), prune
  lands `current` on the session at the **cursor** and its nearest live
  neighbors — never the timeline tip — so a subsequent landing hook can't
  reorder the tip ahead of the forward history.

Net: closing a session removes exactly that session and leaves the rest of the
stack (and its order) untouched; the old top stays reachable via forward.

**Why no explicit "suppress" flag.** A natural idea is a `mode = "auto"` flag
set in `prune_dead` and consumed by a landing hook. This is fragile: if the
landing hook does not fire the flag lingers, and the close-vs-navigation
detection above (the leaving session being dead) is both simpler and
self-correcting.

**Portability note.** If a future/different tmux version (or a session picker
that does switch-then-kill) *does* fire `client-session-changed` for the
landing, prune and hook now run concurrently. This is no longer a correctness
hazard: every mutating command is serialized by an exclusive flock (§13), so
the landing is promoted only if it genuinely wins the lock after prune, and the
timeline is never corrupted either way. The close-current case therefore cannot
truncate or wipe the stack on any tmux version.

---

## 12. Why there is no output-activity signal

An earlier design proposed promoting a session when it produced output (typing
echoes back), via `alert-activity`. **This is unusable:** `alert-activity` only
fires for **non-focused/background** windows — it detects activity in sessions
you are *not* viewing, the opposite of "the session I'm using." Verified on
3.6a: output in a focused window fires nothing; output in a background window
fires `alert-activity`.

There is no robust tmux primitive for "the focused session produced output"
without heavy per-pane `pipe-pane` plumbing (a resident process per pane, and
no hooks to re-pipe on pane/window focus changes). It is therefore not wired.
Relevance comes from **selection** and **dwell** only, which — given the 30 s
dwell floor — fully cover "sessions I'm actively using."

---

## 13. Concurrency & race safety

- **Hooks are ASYNCHRONOUS, not synchronous.** A `run-shell` inside a tmux hook
  runs *after* the triggering command returns, regardless of `-b` (verified on
  tmux 3.6a). So `session-closed` (prune) and `client-session-changed` (hook)
  can execute **concurrently** whenever a close also relocates the client —
  closing the focused session, or any switch-then-kill such as a session picker
  deleting a session. Their load → modify → save on the critical state
  (`hist`/`idx`/`current`/`mode`/`tlist`) would otherwise interleave: a hook that
  loaded stale state can save **last** and clobber prune's removal of the
  just-closed session, so dead sessions **accumulate** in the timeline; when a
  prune finally lands unclobbered it mass-removes them, which presents as the
  timeline being truncated or "wiped."
- **Serialization.** Every mutating command (`hook`, `prune`, `maintain`,
  `init`, `back`, `forward`, `toggle`, `pick`, `dwell`, `activity`, `reset`)
  takes an exclusive `flock` on a stable file for its whole critical section
  (`lock`/`unlock` in the engine). The critical sections are thus mutually
  exclusive no matter how tmux schedules the async run-shells, so a close now
  removes exactly the closed session and leaves the rest of the stack
  untouched. Each section is a few tens of ms; keypresses are ~150 ms apart and
  the poller fires only every ~0.5 s, so lock contention is imperceptible. The
  lock auto-releases if a command dies (the fd closes), so it can never be held
  stale.
- **Single consistent liveness snapshot.** Each locked section loads one
  `list-sessions` snapshot into an associative array and keys all
  `session_exists` checks off it (1 tmux call instead of N, and atomic — no
  session can appear/disappear mid-scan). This is what makes pruning exact: a
  live session is never dropped and a dead one is never missed.
- The primitives (`do_back`/`do_forward`/`do_toggle`) set the `mode` flag, then
  call `switch-client` (under the lock); the landing hook fires asynchronously
  afterward and acquires the lock in its own process. `mode` is set before the
  switch and read under the lock, so it is never lost.
- **Dwell and activity** (the async relevance paths) touch ONLY `tlist` AND now
  take the lock too, so they are fully serialized and can never corrupt
  `hist`/`idx`/`current`/`mode`.
- **Caveat (tmux command queuing).** A `tmux` command issued *from within* a
  hook's `run-shell` is deferred until after the triggering tmux command
  returns. An external observer that reads state immediately after
  `kill-session` may see pre-prune state for a few milliseconds. This is
  harmless to users and to the engine; tests settle with a tiny sleep after
  such operations.

---

## 14. Invariants & edge cases

- **`tlist ⊆ live sessions`**, maintained by prune + cap.
- **A relevance entry is almost always also in `hist`** (you can only become
  relevant by being somewhere, which records history). If a cap ever drops a
  `tlist` entry from `hist`, `do_toggle` falls through to `collapse_and_append`
  for history correctness.
- **Toggle when `tlist` is empty** → `fallback_target` (nearest live history
  neighbor). The first toggle thus bootstraps a relevance pair from history.
- **Toggle target == current** → message, no switch.
- **`dwell-ms = 0`** → `arm_dwell` returns immediately; relevance comes only
  from selection.
- **Non-numeric `dwell-ms`** → treated as the default (30000).
- **Rapid walking** arms one dwell timer per walk; each self-no-ops if you have
  moved on. Bounded, short-lived churn.
- **Mode flag with a target that doesn't match the landing** → treated as a
  navigation (stale flag self-heals).

---

## 15. Configuration reference

| Option | Default | Notes |
|---|---|---|
| `@session-history-toggle-key` | `""` | Empty disables the entire relevance feature. |
| `@session-history-back-key` | `""` | |
| `@session-history-forward-key` | `""` | |
| `@session-history-pick-key` | `""` | Requires fzf. |
| `@session-history-dwell-ms` | `30000` | Walk-dwell threshold; `0` disables dwell. |
| `@session-history-popup` | `on` | `off` for inline fzf (older tmux). |

Keys use tmux key-name syntax (`C-F9`, `M-Space`, `L`, …). An empty string
leaves that key unbound.

---

## 16. Hook & binding reference

Wired by the entry script (all global, all synchronous — no `-b`):

```
set-hook -g client-session-changed  run-shell '${SCRIPT} hook "#{session_name}"'
set-hook -g session-closed          run-shell '${SCRIPT} prune "#{session_name}"'
set-hook -g session-created         run-shell '${SCRIPT} maintain'
```

Bindings (each only if its key is non-empty):

```
bind-key <toggle-key>  run-shell '${SCRIPT} toggle "#{session_name}"'
bind-key <back-key>    run-shell '${SCRIPT} back   "#{session_name}"'
bind-key <forward-key> run-shell '${SCRIPT} forward "#{session_name}"'
bind-key <pick-key>    run-shell '${SCRIPT} pick   "#{session_name}"'
```

The entry script also defaults `@session-history-dwell-ms` to `30000` if unset,
and sets `@session-history-toggle-enabled` on/off from the toggle key.

---

## 17. Subcommand reference

`session_history.sh <cmd> [session]`:

| Cmd | Purpose |
|---|---|
| `init` | Seed initial state if empty (current/attached session). |
| `hook <s>` | The `client-session-changed` handler (§5). |
| `dwell <s>` | Dwell timer fire (§8); promotes `s` if still current. |
| `prune <s>` | The `session-closed` handler (§10). |
| `maintain` | The `session-created` handler: prune + cap. |
| `toggle <s>` | Compute relevance target and switch (§7). |
| `back <s>` | Walk toward older entries. |
| `forward <s>` | Walk toward newer entries. |
| `pick <s>` | fzf picker over live history. |
| `status` | Print timeline (cursor in `[ ]`) and relevance list. |
| `reset` | Clear all state. |

---

## 18. Testing

Two harnesses (not shipped; kept as the regression suite):

1. **Client-free logic suite.** Drives the `hook` subcommand directly (what
   tmux calls on a switch) and reads `@session-history-mode` to learn
   `toggle`/`back` targets, so no attached client is needed. Covers gating,
   navigation promotion, walk non-promotion, dwell (direct + the real
   `run-shell -b` timer), toggle oscillation, the headline walk-deep scenario,
   and both close-pruning cases. Uses an isolated socket via a `tmux` wrapper.
2. **Real-client suite.** One pty-attached client (python `pty.fork`) so real
   `switch-client` fires `client-session-changed` end-to-end. Smoke-tests nav,
   back, toggle through the real path and asserts the close-current invariant
   (§11: no session is newly added to `tlist`).

Both use `tmux kill-server` between groups. Note the settle-after-close detail
(§13): allow a few hundred ms after `kill-session` before asserting, because the
prune `save` is deferred until after the triggering command returns.

---

## 19. Known limitations

- **Single attached client.** All state is global; two clients switching
  independently share one timeline and one relevance list.
- **Dwell granularity is whole seconds** (`ms / 1000`, min 1 s).
- **Close-current on non-3.6a tmux** may behave slightly differently if a
  future version fires `client-session-changed` for the auto-landing (§11).
- **No output-activity signal** by design (§12); relevance is selection + dwell.
- **Session names** must not contain newlines (tmux-enforced) and ideally not
  double-quotes (used in `run-shell` argument quoting for dwell).

---

## 20. File map

```
session_history.tmux        Entry point: wires hooks, reads options, binds keys,
                            sets toggle-enabled + dwell defaults. Idempotent/reload-safe.
scripts/session_history.sh  The engine: all state, the reactive hook, the four
                            primitives, prune/cap, dwell, status/reset.
README.md                   User documentation.
SPEC.md                     This document.
```