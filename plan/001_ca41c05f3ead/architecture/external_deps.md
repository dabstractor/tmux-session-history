# External Dependencies: tmux Internal Behavior Reference

**Purpose.** This document validates the architectural assumptions of the
`tmux-session-history` plugin against the actual behavior of tmux (target
release: **3.6a**). It is written as an authoritative reference for downstream
implementation agents: each of the eight load-bearing tmux features the design
relies on is described as *what it is*, *how it behaves on 3.6a*, *gotchas*, and
*what it means for the plugin*.

**Citation conventions.** Because no live network source was available during
this research pass, claims are attributed to one of:
- `[tmux(1)]` — behavior documented in the tmux man page.
- `[PRD §X]` — a finding already verified empirically on 3.6a and recorded in the
  plugin's `PRD.md` (which explicitly states "verified on tmux 3.6a" for the
  concurrency claims).
- `[code: path]` — the current implementation in this repo.
- `[needs verification]` — my inference that could not be confirmed against a
  primary source and should be checked against the tmux source or a live 3.6a
  binary before being relied upon as a hard guarantee.

---

## 0. Cross-cutting finding: PRD diverges from the current implementation

Before the per-topic analysis, the single most important thing a downstream
implementer must know:

**`PRD.md` describes a design that *removes* the `client_activity`-based
activity-detection poller that the current code still ships.**

| Aspect | `PRD.md` (reference spec / new direction) | `scripts/session_history.sh` + `README.md` (current code) |
|---|---|---|
| Activity / output signal | **None.** §12: "There is no robust tmux primitive for 'the focused session produced output'… It is therefore not wired. Relevance comes from **selection** and **dwell** only." | **Present.** A resident `do_poller` (started via `tmux run-shell -b`) samples `#{client_activity}` ~2×/s and calls `do_activity` to promote the viewed session on input. |
| Relevance sources | selection + dwell (2) | selection + focused-activity + dwell (3) |
| `@session-history-dwell-ms` default | **30000** (§3, §15) | **10000** (`dwell_ms()` in code; `session_history.tmux` default; README table) |
| Resident background processes (toggle on) | none (only transient `run-shell -b` dwell timers) | one poller process + dwell timers |
| `do_activity` / `do_poller` / `poller-pid` | absent | present |

This is almost certainly **intentional**: the PRD is the *target* architecture
being implemented under this plan, and removing the poller is a deliberate
simplification (fewer resident processes, fewer concurrent writers on the
relevance list, no per-client heuristic). The dwell default rising from 10 s →
30 s is the coupled compensating change — once focused-activity is gone, dwell
becomes the *only* silent-presence signal, so its threshold must be long enough
to avoid spurious promotion of sessions you merely browsed past. See topic 3 for
the full rationale.

**Implication for implementers:** an agent implementing *to* the PRD must
**delete** `do_activity`, `do_poller`, `do_start_poller`, the `poller`/`activity`
subcommands, the `@session-history-poller-pid` option, and the poller-bootstrap
call in `do_init`/`session_history.tmux`, and raise the dwell default to `30000`.
The README's "How activity detection works" section must also be rewritten to
match. Leaving the poller in would silently re-introduce the complexity and the
third concurrency path the PRD set out to eliminate.

---

## 1. Asynchronous hook behavior

### What it is
The plugin wires its engine to tmux hooks via `set-hook -g <hook> "run-shell
'…'"` (`session_history.tmux`). The core architectural claim is:

> "A `run-shell` inside a tmux hook is **asynchronous** regardless of `-b`." —
> `scripts/session_history.sh` header; `session_history.tmux` comment; `[PRD §13]`.

### How it behaves on 3.6a
- tmux fires a hook when its event occurs (e.g. `client-session-changed` on a
  client session change, `session-closed` on session destruction). `[tmux(1),
  HOOKS section]`
- Each hook's `run-shell` **forks an independent shell process** owned by the
  server. The plugin's empirical finding `[PRD §13, verified on 3.6a]` is that
  this run-shell does **not** block on completion in a way that serializes it
  against *other* concurrently-triggered hooks — the `-b` flag does not change
  the outcome. `[PRD §13]`
- **The concurrency that actually matters:** a single user action — killing the
  *focused* session, or any "switch-then-kill" (e.g. a session picker that
  deletes a session) — causes tmux to fire **two** hooks: `session-closed`
  (→ `prune`) *and* `client-session-changed` for the relocated client (→ `hook`).
  `[PRD §11, §13]` These produce **two independent shell processes that the OS
  scheduler runs concurrently.** `[code: session_history.sh, CONCURRENCY note]`
- **The corruption that results without serialization:** both `prune` and `hook`
  perform load → modify → save on the same `@session-history-*` options. If they
  interleave, a hook that loaded stale state can save **last** and clobber
  prune's removal of the just-closed session. Dead sessions then **accumulate**
  in the timeline until a later prune lands unclobbered and mass-removes them —
  which presents to the user as the timeline being "truncated" or "wiped."
  `[PRD §13]`
- **Command-queuing caveat:** a `tmux` command issued *from inside* a hook's
  `run-shell` is deferred until after the triggering tmux command returns. So an
  external observer that reads state immediately after `kill-session` may see
  pre-prune state for a few milliseconds. `[PRD §13]`

### Gotchas
- The claim "regardless of `-b`" is the PRD's empirical 3.6a observation. The
  precise source-level mechanism (whether the hook dispatch is itself
  non-blocking, or whether run-shell blocks only its own command-queue context
  while the server event loop keeps dispatching other hooks) is **[needs
  verification]** against `cmd-run-shell.c` / the hooks dispatch path in the tmux
  source. The *engineering conclusion* (the two hook processes run concurrently;
  external serialization is required) does **not** depend on this sub-detail and
  is solid. `[PRD §13]`
- `client-session-changed` does **not** reliably fire for the auto-landing on
  *every* tmux version (`[PRD §11]`: "on many setups the relocation also fires
  `client-session-changed`"). The design must be correct whether or not it fires
  — see topic 6 / close-current behavior.

### What it means for the plugin
The async-hooks fact is the **entire justification for the flock** (topic 2).
Without it, the read-modify-write on the critical state would be implicitly
serialized by tmux. Because it is not, every mutating subcommand holds an
exclusive flock for its whole critical section. `[code: session_history.sh,
lock/unlock + the case dispatch]`

---

## 2. `flock` serialization

### What it is
The plugin serializes all mutations with an advisory file lock:

```bash
LOCK_FILE="${SHT_LOCK:-${TMPDIR:-/tmp}/tmux-session-history.lock}"
lock()   { exec 9>"$LOCK_FILE"; flock 9; }   # blocks until exclusive lock
unlock() { exec 9>&-; }                        # closing fd 9 releases the lock
```
`[code: session_history.sh]` Every mutating subcommand (`init`, `hook`, `dwell`,
`prune`, `maintain`, `toggle`, `back`, `forward`, `reset`, and — in the current
code — `activity`) wraps its critical section in `lock` … `unlock`.

### How it behaves / safety
- `flock(1)` (util-linux) implements POSIX advisory locking via `flock(2)`. The
  `exec 9>file; flock 9` idiom binds the lock to file descriptor 9's lifetime:
  the lock is held while fd 9 is open and is released when fd 9 closes. `[tmux
  design note in code; standard flock(1) semantics]`
- **Auto-release on death:** if a command is killed (SIGTERM, SIGKILL, crash),
  the kernel closes its fds, so the lock is released automatically — it can never
  be held stale by a dead process. `[PRD §13]`
- Critical sections are a few tens of ms; keypresses are ~150 ms apart, so
  contention is imperceptible. `[PRD §13]`
- All participants are the engine script itself, so the "advisory locks only work
  if everyone uses them" precondition is satisfied — there is no non-flocked
  writer of the critical state. (The async relevance paths — dwell and, in the
  current code, activity — also take the lock.) `[code]`

### Gotchas (by severity)

| Severity | Gotcha | Detail |
|---|---|---|
| **High** | **macOS has no `flock(1)`.** util-linux `flock` is absent on stock macOS/BSD. The `flock 9` call would fail, and because `lock()` does not check `flock`'s exit status, the script would **proceed without a lock** — silently reverting to the racy behavior on macOS. **[needs verification]** whether the project targets macOS; if so, a fallback (e.g. `mkdir`-based lock, or `shlock`, or a compile-time check) is required. | `[code: lock()]` ignores `flock`'s return. |
| Medium | **`/tmp` symlink / pre-creation.** The lock file lives in world-writable `/tmp` (or `$TMPDIR`). A local attacker who can pre-create `/tmp/tmux-session-history.lock` as a symlink could redirect lock acquisition, or a stale file owned by another UID could make `exec 9>` fail. Single-user setups are low-risk, but a per-user `$XDG_RUNTIME_DIR`/`$TMPDIR` location is safer. | `LOCK_FILE` default. |
| Medium | **No error handling on open.** `exec 9>"$LOCK_FILE"` — if the path is unwritable, the `exec` fails non-fatally and the script continues unlocked. Pair with the macOS point: a silent no-op lock defeats the whole safety model. | `[code: lock()]` |
| Low | **Multiple tmux servers share one lock file.** Two `tmux -L` servers have independent `@`-option stores (separate processes) but share `/tmp/tmux-session-history.lock`. A hook in server A would block on a lock held by server B, despite their state being unrelated. Inefficiency only, not correctness. | `LOCK_FILE` is host-global. |
| Low | **NFS.** `flock` semantics differ on NFS mounts. `/tmp`/`$TMPDIR` are normally tmpfs/local, so usually fine, but if `TMPDIR` points at NFS the guarantee weakens. | `[needs verification]` for exotic setups. |
| Low | **No per-lock-name namespacing.** There is one global lock; there is no way to allow read concurrency (not needed here — every section mutates). | By design. |

### What it means for the plugin
flock is the correct and sufficient serialization primitive **on Linux**. The
two actionable risks are (a) the macOS absence of `flock(1)` with no fallback,
and (b) the un-checked `flock`/`exec` return codes, which convert a locking
failure into a silent data-corruption bug rather than a loud one. A hardened
version should `flock 9 || exit 1` and detect `flock`'s absence at startup.

---

## 3. `#{client_activity}` and why the PRD removes activity detection

### What it is
`#{client_activity}` is a tmux **client** format variable: an epoch-seconds
timestamp of the last *activity* by that client. tmux advances it on every
keystroke/command the client sends — a character passed through to the shell, a
pane/window switch, or any tmux command. `[tmux(1), FORMATS; code comments in
session_history.sh "ACTIVITY DETECTION"]`

### How it behaves on 3.6a
- It advances on **any** client input, including the very keystroke that switches
  sessions. The current poller handles this by re-anchoring its baseline on every
  sample and treating "session changed" as distinct from "active in same session"
  — so a switch key is not mistaken for work. `[code: do_poller]`
- Resolution is **whole seconds** `[code comment]`; with a ~0.5 s poll, promotion
  lands within ~0.5–1.5 s of input. It is **per-client**, so the single-attached-
  client assumption is load-bearing. `[code]`
- `monitor-activity`/`alert-activity` (tmux's built-in) fires only for **non-
  focused/background** windows — it detects activity in sessions you are *not*
  viewing, the opposite of "the session I'm using." Verified on 3.6a. `[PRD §12]`

### Why the PRD removes activity detection based on it
The current code uses `client_activity` polling precisely *because* `alert-
activity` can't see the focused window. The PRD reverses this and removes the
poller entirely, leaving **selection + dwell** as the only relevance signals.
`[PRD §12]` The rationale, reconstructed from the PRD's stated tradeoffs (the PRD
does not spell out the "why remove" explicitly, so the reasons below are inferred
and partly **[needs explicit PRD confirmation]**):

1. **Eliminate the resident process.** The poller is the plugin's only long-lived
   background process. Removing it means that, even with toggle bound, the only
   async artifacts are short-lived `run-shell -b` dwell timers that self-cancel.
   Fewer moving parts, no SIGTERM/PID tracking, no reload races. `[PRD §19, known
   limitations implicitly simplified]`
2. **Collapse the concurrency model.** The poller is a third async writer on the
   relevance list (`tlist`). The PRD keeps dwell (also async, also tlist-only,
   also locked) but drops the continuously-running one, so the only remaining
   background writer is a bounded set of one-shot timers. `[PRD §13]`
3. **Dwell alone is "good enough."** With the dwell default raised to **30 s**
   (`[PRD §3, §15]`, vs the current code's 10 s), silent presence (reading,
   thinking) is still captured, and any *deliberate* use routes through
   selection. The sub-second promotion the poller gave is traded away for
   simplicity. (Note the coupled change: removing activity detection and raising
   dwell to 30 s go together — the shorter 10 s dwell only made sense as a
   backstop behind the faster activity signal.)
4. **Heuristic fragility.** `client_activity` is a client-level proxy, not a
   session/focus primitive; it relies on the single-client assumption and on the
   "switch key changes the session in the same event" timing subtlety. Multi-
   client use breaks it entirely. `[code: do_poller, "single attached client"]`

### Gotchas
- **The dwell default is inconsistent across the repo:** PRD = 30000, code =
  10000, `session_history.tmux` = 10000, README table = 10000 (but README prose
  says "30 s" in one place). An implementer following the PRD must set **30000**
  everywhere. `[PRD §3/§15 vs code dwell_ms() vs session_history.tmux vs README]`
- **Losing the sub-second signal changes UX:** after removing activity, the
  *fastest* path to promote a walked-to session is the full dwell interval (30 s)
  unless the user *selects* it. The PRD accepts this. `[PRD §8, §12]`
- If the removal is **not** intended and the PRD is stale relative to the code,
  the reverse applies — but the task framing ("why is the PRD removing activity
  detection") confirms the removal is the intended direction.

### What it means for the plugin
See topic 0's migration list. The PRD's relevance model becomes: **promotion on
direct selection (pick/sessionx/manual switch/toggle) and on dwell ≥ 30 s after a
walk — nothing else.** This is simpler and removes a resident process and a
concurrency writer, at the cost of slower silent-presence promotion.

---

## 4. Global user options (`@session-history-*`)

### What they are
tmux "user options" are any option whose name begins with `@` and that is not a
built-in. They store arbitrary string values and are the plugin's sole state
store. `[tmux(1), OPTIONS]` The plugin reads/writes them exclusively with the
**global** scope:

```bash
G() { tmux show-options -gv "$1" 2>/dev/null; }   # read global value
S() { tmux set-option -g "$1" "$2"; }             # write global
```
`[code: session_history.sh]` State options: `@session-history-{hist,idx,current,
mode,tlist,toggle-enabled}` (plus config `@session-history-{toggle,back,forward,
pick}-key`, `dwell-ms`, `popup`; and in the current code `poller-pid`,
`piped-pane`). `[PRD §3, §15; code]`

### How they behave on 3.6a
- **Scope.** `-g` = **global (server-wide)**: the value is shared by all
  sessions/clients in that server. `[tmux(1), set-option]` The plugin uses `-g`
  uniformly, which is why state is global and the design assumes a single
  timeline/relevance list across the server. `[PRD §19, known limitation:
  "Single attached client… state is global"]`
- **No persistence across server restart.** User options live **in the server's
  memory only**. tmux does **not** write `@` options to disk, and
  `tmux kill-server` / a server crash / reboot **loses all of them.** On reload
  the entry script re-runs and `init` re-seeds from the currently-attached
  session, but the *accumulated* timeline/relevance is gone. `[tmux(1); code:
  do_init]` This is a known limitation, not a bug. `[needs verification]` whether
  any `tmux resurrect`-style persistence is planned.
- **`show-options -gv`** returns the raw value with the option name stripped
  (`-v`). `-g` selects the global value. `[tmux(1)]`
- **Newline-valued options.** The plugin stores `\n`-joined lists in a single
  `@`-option value (e.g. `@session-history-hist = "sessA\nsessB\nsessC"`). tmux
  **does** preserve embedded newlines in option values, and `show-options -gv`
  returns them verbatim, which is how the engine reads them back line-by-line.
  `[code: save()/load(); needs verification on tmux quoting edge cases]`

### Gotchas
| Severity | Gotcha |
|---|---|
| Medium | **Format expansion.** Some read paths expand `#{…}`. `show-options -v` returns the **raw** value (no expansion), which is what the plugin uses — safe. But if any session name ever contained `#`/`#{`, and the value were read through a format-expanding path, it could be mangled. Session names with `#` are exotic; tmux itself restricts names. `[needs verification]` |
| Medium | **Quoting in `run-shell` args.** Hooks pass `"#{session_name}"` into the shell. Session names must not contain double-quotes or newlines. `[PRD §19]` A name with a `'` or `"` could break the dwell `run-shell -b` quoting. |
| Low | **`0` is a valid `idx`.** Code must not treat `0`/empty as "unset" interchangeably; `idx` uses explicit emptiness checks. `[PRD §3]` |
| Low | **Empty string = "unset".** The canonical empty value is `""`, never `[]`/`0` for lists. `[PRD §3]` |
| Low | **`set-option -g` with an empty value** vs unsetting: the plugin sets `""` rather than `set-option -gu`. Consistent as long as readers treat empty as empty. `[code]` |

### What it means for the plugin
Global `@` options are a good fit: atomic-ish per-command, single store, no
extra files, naturally re-seedable. The two real constraints are (a) no
cross-restart persistence (acceptable, documented) and (b) the single-global-
store assumption that underpins the single-client limitation.

---

## 5. Does `switch-client -t` fire `client-session-changed`?

### What it is
`tmux switch-client -t target` moves the attached client to session `target`. It
is the primitive the plugin's `do_back`/`do_forward`/`do_toggle` use to effect a
switch. `client-session-changed` is the hook the plugin relies on as the "spine"
of its reactive engine. `[PRD §5; code]`

### How it behaves on 3.6a
- **Yes — `switch-client -t target` fires `client-session-changed`.** It is the
  canonical way to change a client's displayed session, and the hook is defined
  to fire "when the current session being displayed by a client changes." `[tmux(1),
  HOOKS; PRD §16]`
- The hook fires **after** the switch completes, with the **new** session as the
  format context. The plugin passes `"#{session_name}"` as the argument, so the
  engine's `do_hook` receives the **destination** session as `to`. `[code:
  session_history.tmux hook wiring; do_hook]`
- `switch-client -l` (last), `-n`/`-p` (next/prev) also fire it. `[tmux(1)]`
- A switch to the **same** session (`switch-client -t <current>`) is treated by
  the engine as a no-op (`to == current` → clear mode, return). `[code: do_hook]`

### Gotchas
- **Timing of the mode flag.** The primitives set `mode` via a synchronous
  `tmux set-option -g` *before* issuing `tmux switch-client`. Because the hook
  fires asynchronously *after* the switch, the `set-option` has already completed
  by the time the hook reads `mode`. This is what makes the one-shot flag a safe
  handoff. `[PRD §13; code do_back/do_forward/do_toggle]`
- **Picker composition.** `tmux-sessionx` and other pickers ultimately issue a
  `switch-client`, so their switches also fire the hook as a plain NAVIGATION
  (no mode flag → treated as navigation → collapse + promote). `[PRD §6; README
  "composes with tmux-sessionx"]`
- **[needs verification]** whether `switch-client -t <same>` actually fires the
  hook on 3.6a or is suppressed as a no-change at the tmux level. The engine is
  correct either way.

### What it means for the plugin
The `switch-client → client-session-changed` pairing is the foundation of the
reactive design: every switch funnels through one hook, classified by the
transient `mode` flag. `[PRD §5]`

---

## 6. `set-hook -g client-session-changed`

### What it is
The plugin installs global hooks in `session_history.tmux`:

```tmux
set-hook -g client-session-changed "run-shell '${SCRIPT} hook \"#{session_name}\"'"
set-hook -g session-closed         "run-shell '${SCRIPT} prune \"#{session_name}\"'"
set-hook -g session-created        "run-shell '${SCRIPT} maintain'"
```

### How it behaves on 3.6a
- **`-g` = global scope.** The hook applies server-wide (fires for any
  session/client), not just the current session. `[tmux(1), set-hook]` With a
  single client this is equivalent and is the intended global-spine behavior.
- **`set-hook` replaces by default** (use `-a` to append). The entry script calls
  bare `set-hook` on every load, so reloading the plugin **re-sets** (overwrites)
  the hooks rather than stacking duplicates → **reload-safe / idempotent.**
  `[code: session_history.tmux; README "reload-safe"]`
- **Sync vs async of the *hook body*:** the `-g` flag controls scope only; the
  sync/async behavior of the `run-shell` body is governed by the async-hook
  behavior in topic 1 (i.e. the hook's run-shell runs concurrently with other
  triggered hooks; tmux does not serialize them). `[PRD §13]`
- `set-hook -R` would run the hook immediately (not used here). `[tmux(1)]`

### Gotchas
| Severity | Gotcha |
|---|---|
| Medium | **Hook clobbering between plugins.** Bare `set-hook -g client-session-changed …` **overwrites** any other plugin's global `client-session-changed` hook. If another plugin also owns this hook, only the last `set-hook` wins. The plugin assumes it owns the hook. Using `-a` (append) would stack hooks but introduces ordering/unwinding complexity. `[needs verification]` of real-world collisions with popular plugins. |
| Medium | **`session-closed` format context.** By the time `session-closed` fires, the closing session may be partially torn down. The plugin passes `#{session_name}` (the name of the session that closed) and the engine re-derives liveness from a fresh `list-sessions` snapshot rather than trusting the arg. `[code: do_hook/prune_dead, load_alive]` |
| Low | **`client-session-changed` may or may not fire for the auto-landing** when the focused session is killed. The close-current design is correct either way because prune and hook both use the "leaving session is dead" detection and the flock serializes them. `[PRD §11]` |

### What it means for the plugin
Global hooks with replace-semantics give a clean, reload-safe wiring. The main
external risk is hook-name collision with other plugins that touch
`client-session-changed`.

---

## 7. `run-shell -b` (background, lifecycle, server restart)

### What it is
`run-shell` executes a shell command; `-b` runs it in the **background** (tmux
does not wait for it). The plugin uses `run-shell -b` for two things: (a) the
**dwell timers** (`arm_dwell`: `tmux run-shell -b "sleep ${sec}; \"${SELF}\" dwell
\"${to}\""`), and (b) in the *current* code only, the **poller**
(`tmux run-shell -b "${SELF} poller"`). `[code: arm_dwell, do_start_poller]`

### How it behaves on 3.6a
- **Without `-b`:** `run-shell` blocks until the command finishes, then displays
  stdout in copy mode. `[tmux(1), run-shell]`
- **With `-b`:** the shell command is forked and run in the background; `run-
  shell` returns immediately. `[tmux(1)]`
- **Lifecycle / ownership:** a `-b` job is a **child of the tmux server.** It
  persists until the command exits **or the server exits.** This is the property
  the code comments rely on: it is "preferred over a shell `&` subshell, which
  can orphan and outlive the server." `[code comment; PRD §8]`
- **Server restart kills it:** on `tmux kill-server`, server crash, or reboot,
  all `-b` jobs die with the server (they are its children). On the next plugin
  load, dwell timers are re-armed only by a new walk, and (current code) the
  poller is re-started by `do_init`. So **no orphaned processes survive a server
  restart.** `[PRD §8; code]`
- **Stale-timer self-cancellation:** a dwell `run-shell -b` fires `dwell <s>`;
  `do_dwell` guards "is `s` still `@session-history-current`?" and no-ops if not.
  `[code: do_dwell; PRD §8]`

### Gotchas
| Severity | Gotcha |
|---|---|
| Medium | **Output of `-b` jobs is not captured like foreground.** The plugin never relies on dwell stdout, so this is fine, but any future use of `run-shell -b` that expects stdout display will be surprised. `[tmux(1)]` |
| Medium | **Whole-second dwell granularity.** `sec = ms/1000`, min 1 s. Sub-second dwell is impossible; `dwell-ms` is effectively rounded. `[PRD §19; code arm_dwell]` |
| Low | **Rapid walking arms multiple timers.** One dwell timer per walk; each self-no-ops if you moved on. Bounded churn. `[PRD §14]` |
| Low | **`-C` / `-d delay` flags** exist on `run-shell` (tmux 3.x) but are unused. `[tmux(1)]` |

### What it means for the plugin
`run-shell -b` is the right primitive for fire-and-forget background work whose
lifetime should be bounded by the server. After the PRD's removal of the poller
(topic 0/3), the **only** remaining `run-shell -b` use is the transient dwell
timers — which is exactly the simplification goal.

---

## 8. `list-sessions` atomicity and the single-snapshot pattern

### What it is
Each locked critical section builds **one** consistent snapshot of live sessions
and keys every liveness check off it, instead of forking one `has-session` per
entry:

```bash
declare -A ALIVE=()
load_alive() {
    ALIVE=()
    local s
    while IFS= read -r s; do [ -n "$s" ] && ALIVE["$s"]=1; done \
        < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
}
session_exists() {
    if [ "${#ALIVE[@]}" -gt 0 ]; then [ "${ALIVE[$1]:-}" = 1 ]
    else tmux has-session -t "$1" 2>/dev/null; fi
}
```
`[code: session_history.sh]`

### How it behaves on 3.6a
- `tmux list-sessions -F '#{session_name}'` returns all live session names in a
  single server reply — a **point-in-time** view taken at one instant. `[tmux(1),
  list-sessions]`
- Because it is a single read, **no session can appear or disappear mid-scan.**
  If the engine instead issued N separate `has-session` calls, a session could
  close *between* two checks: a live session could be dropped (false dead) or a
  dead one missed (false alive), making pruning inexact. `[PRD §13]`
- **Performance:** 1 `tmux` invocation (one fork/exec round-trip) vs N
  `has-session` forks — far faster, and the snapshot is reused for every check in
  the section. `[PRD §13; code comment]`
- The snapshot is loaded **under the flock**, so even concurrent hooks each build
  their own consistent snapshot within their own mutually-exclusive section.
  `[code: case dispatch loads load_alive right after lock]`

### Gotchas
| Severity | Gotcha |
|---|---|
| Medium | **Stale within a section.** The snapshot is point-in-time. If a session closes *after* the snapshot but before `save()`, the section's saved state may still reference it — but the *next* prune cleans it. Within-section consistency (the property that matters for exact pruning) holds. `[code]` |
| Low | **`ALIVE` empty ⇒ falls back to `has-session`.** If `load_alive` failed (tmux down), `session_exists` per-call forks instead. The code keys off `${#ALIVE[@]}` to detect this. `[code: session_exists]` |
| Low | **Names with spaces.** `#{session_name}` is newline-delimited; names with spaces are preserved on one line. Names with newlines are impossible (tmux-disallowed). `[PRD §19]` |

### What it means for the plugin
The single-snapshot pattern is what makes **pruning exact**: every list entry is
judged against the same instant, so all-and-only dead sessions are removed and
the cursor adjustment is precise. `[PRD §10, §13]` It is also a major performance
win (O(1) tmux calls per section vs O(N)).

---

## 9. Severity-ranked gotcha summary (all topics)

| Sev | Topic | Issue | Fix direction |
|---|---|---|---|
| **High** | 2 | `flock(1)` absent on macOS; `lock()` ignores failure → silent unlock | Detect `flock` at startup; add `mkdir`/`shlock` fallback; check `flock` exit status |
| **High** | 0 | PRD removes activity poller; code/README still have it; dwell default 30000 vs 10000 | Implement-to-PRD: delete `do_activity`/`do_poller`/`poller-pid`, raise dwell to 30000, rewrite README |
| Medium | 2 | `/tmp` lock file: symlink/world-writable, un-checked `exec`/`flock` returns | Per-user lock dir; `flock 9 \|\| exit 1` |
| Medium | 4 | No cross-restart persistence of `@` options | Documented limitation; optional `resurrect` hook if desired |
| Medium | 4 | Session names with `#`/`"`/`'` break format/quoting | tmux already restricts names; guard dwell quoting |
| Medium | 6 | Bare `set-hook -g` clobbers other plugins' same-name hooks | Consider `-a` append or document the assumption |
| Medium | 7 | `-b` output not captured; whole-second dwell granularity | Avoid relying on `-b` stdout; accept 1 s floor |
| Low | 2 | Multiple `tmux -L` servers share one lock file (cross-server block) | Namespacing by socket (low value) |
| Low | 1 | Exact source mechanism of "async regardless of -b" unverified | Confirm vs tmux `cmd-run-shell.c`; conclusion is solid regardless |
| Low | 8 | Point-in-time snapshot can lag within a long section | Next prune self-heals |

---

## 10. Gaps / items marked `[needs verification]`

1. **Exact mechanism behind "run-shell in a hook is async regardless of `-b`"**
   (topic 1). Confirm against the tmux source (`cmd-run-shell.c` and the hooks
   dispatch path). *Engineering conclusion (concurrency is real; flock required)
   does not depend on this.*
2. **`switch-client -t <same-session>`** — does tmux fire `client-session-changed`
   on 3.6a, or suppress as a no-change? Engine is correct either way.
3. **macOS support intent.** Is `flock` a hard dependency? If macOS is in scope,
   the locking strategy needs a fallback.
4. **Newline/`#` preservation in `@`-option values** under all tmux quoting paths
   (topic 4). Believed safe via `show-options -v`, but worth a unit test.
5. **Explicit PRD rationale for removing the activity poller** (topic 3). The
   reasons given are inferred from the PRD's stated tradeoffs; the PRD should
   state the "why remove" directly.
6. **Cross-plugin `client-session-changed` collisions** (topic 6). Real-world
   collision frequency with popular plugins is unknown.

### Suggested next steps
- Run a small 3.6a harness that (a) kills the focused session while logging
  prune/hook process start/stop order to confirm concurrency; (b) toggles dwell
  quoting against `#`/`"`-bearing session names; (c) confirms `list-sessions`
  atomicity under a concurrent closer.
- Add a startup guard: `command -v flock >/dev/null || { echo "flock required"; … }`
  and make `lock()` fail-closed.
- Reconcile the dwell default to `30000` across PRD, code, `session_history.tmux`,
  and README as part of the poller-removal migration.