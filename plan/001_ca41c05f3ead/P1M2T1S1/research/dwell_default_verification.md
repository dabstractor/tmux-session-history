# Research Notes — P1.M2.T1.S1 (session_history.tmux dwell default 10000 → 30000)

## Verified current state

This is the **entry-point leg** of the four-way dwell-default alignment. The
**engine leg (T3.S1) is already Complete** — `scripts/session_history.sh` line 134
(the `dwell_ms()` one-liner, relocated from 154 after T4 shrank the header) now
reads `echo 30000`. Confirmed:

```
134:dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 30000 ;; *) echo "$d" ;; esac; }
```

So after THIS task lands, the entry point writes `30000` and the engine
fallback returns `30000` — fully consistent for an unset option.

## The exact lines to change — `session_history.tmux:53–55`

```bash
53: # Default the dwell threshold once (user can override before or after load).
54: [ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
55:     tmux set-option -g '@session-history-dwell-ms' 10000
```

- The ENTIRE change is the literal `10000` → `30000` on **line 55**.
- Line 54 (the `[ -z ... ] && \` conditional) is UNTOUCHED.
- Line 53 comment ("Default the dwell threshold once …") is UNTOUCHED — it does
  not mention a numeric default, so it stays accurate after the change.
- This is a **single-literal, line-count-neutral** edit (±0 lines; file = 88).

### `10000` / `30000` occurrences in `session_history.tmux` (grep-verified)

```
55:    tmux set-option -g '@session-history-dwell-ms' 10000
```

Only one occurrence. No comment in the entry script references the numeric
default, so **no comment needs editing** (contract point 5: DOCS none).

## Semantics of the defaulting block (why only line 55 changes)

The two-line block is ONE statement (line 54 ends in `\` line-continuation):

```bash
[ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
    tmux set-option -g '@session-history-dwell-ms' 30000   # after this task
```

- `get_tmux_option` (defined line 20): `value="$(tmux show-option -gqv "$1")`;
  `[ -n "$value" ] && echo "$value" || echo "$2"`. Called here with default `''`,
  so it returns the option's value if set+non-empty, else `''`.
- `[ -z "..." ]` → true only when the option is **unset/empty**.
- Net behavior: **write `30000` to the global option ONLY if it is currently
  empty; otherwise leave the user's value untouched** (including `"0"`, `"abc"`,
  `"5000"`).

This matches PRD §16 verbatim: *"The entry script also defaults
`@session-history-dwell-ms` to `30000` if unset"*. The phrase **"if unset"** =
empty-string test, which is exactly what line 54 does. We change only the
literal on line 55.

### Complementarity with the engine fallback (T3.S1)

The two layers are **complementary, not identical**:

| Layer | When it runs | Trigger condition | Effect |
|-------|-------------|-------------------|--------|
| Entry point (line 55, THIS task) | once at plugin load (`tmux source`) | option is **empty** | writes `30000` to the global option |
| Engine `dwell_ms()` (line 134, T3.S1 done) | every WALK arrival | option is **empty OR non-numeric** | returns `30000` as the timer value |

After both land, a fresh load with no user setting → global option becomes
`"30000"` (written by entry point), and even if the option is later cleared
(`tmux set-option -gu`), `dwell_ms()` still returns `30000`. Fully redundant and
consistent. The entry point is the **authoritative load-time default**; the
engine fallback is the **runtime safety net**.

## Cross-file consistency map (the four places that must agree on 30000)

| Location | Was | Owner task | Status |
|----------|-----|------------|--------|
| `session_history.tmux:55` (entry-point default) | `10000` | **P1.M2.T1.S1 (THIS)** | Researching |
| `scripts/session_history.sh:134` (`dwell_ms` fallback) | `10000` | P1.M1.T3.S1 | **Complete** ✅ (now 30000) |
| `scripts/session_history.sh` header comment | `10000` | P1.M1.T4 (rewrite) | T4.S1 done; T4.S2 implementing |
| `README.md:86` (Options table) | `10000` | P1.M3.T2.S1 | Planned |
| `README.md:119` (prose "default 30 s") | — | (already correct) | n/a |

The PRD contains **zero** occurrences of `10000` (grep-verified across the whole
spec) — `10000` is a pre-PRD legacy value being eliminated everywhere.

## PRD authority (verbatim, line-anchored)

- **§15** (Config reference, `PRD.md:460`):
  `| @session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables dwell. |`
- **§16** (Hook & binding reference, `PRD.md:487`):
  *"The entry script also defaults `@session-history-dwell-ms` to `30000` if
  unset, and sets `@session-history-toggle-enabled` on/off from the toggle key."*
- **§3.4** (Configuration user-facing, `PRD.md:112`):
  `| @session-history-dwell-ms | 30000 | Dwell threshold in ms. 0 disables dwell. |`
- **§8** (Dwell / arming, `PRD.md:253`): `ms = dwell_ms()  # @session-history-dwell-ms, default 30000`
- **§14** (Invariants, `PRD.md:442/444`): `0` short-circuits; non-numeric → 30000.

## Parallel-execution boundaries

### With P1.M1.T4.S2 (currently implementing — per `<parallel_execution_context>`)

T4.S2 edits **`scripts/session_history.sh`** (the CONCURRENCY comment regions).
THIS task edits **`session_history.tmux`**. **Different files → zero collision
risk.** No coordination needed.

### With P1.M2.T1.S2 (same file, `session_history.tmux` — Planned, not yet running)

S2 edits two regions, BOTH **below** line 55 and textually disjoint:

- **Lines 70–77** — the `# --- focused-activity detection ---` comment block (DELETE).
- **Lines 79–83** — the bootstrap comment (REWRITE, drop poller rationale).

My edit is on **line 55**. The two regions are ~15–28 lines apart and share no
text. **Clean merge in either order:**
- If S1 lands first: ±0 lines → S2's line numbers 70–83 are unchanged.
- If S2 lands first: S2 deletes ~8 lines at 70–77 and rewrites 79–83 (net
  negative), shifting lines *below* 70; line 55 is *above* 70 → unchanged.

Per sibling-PRP discipline, **anchor on TEXT** (the full line-55 content), not
the line number. The line-55 content is unique in the file (only one
`set-option -g '@session-history-dwell-ms'` line).

## gap_analysis.md anchor

**GAP 2b** (verbatim): *"`session_history.tmux:55` |
`tmux set-option -g '@session-history-dwell-ms' 10000` | 🔴 change `10000` →
`30000`"*. This PRP == GAP 2b only. GAP 2a (engine) = T3.S1 (done); GAP 2c
(header comment) = T4; GAP 2d (README) = M3.T2.S1.

## Validation approach (no test framework in repo)

The repo has **no test framework** (no bats/spec/Makefile). shellcheck (present)
and tmux 3.6a (present) are available. Validation strategy:

1. **Level 1** — `bash -n` + shellcheck no-new-diagnostics diff + line-count
   neutrality (±0).
2. **Level 2** — structural grep proofs: `10000` gone from the file; `30000`
   present exactly once on the set-option line; line 54 conditional + line 53
   comment byte-identical.
3. **Level 3** — **real tmux integration test** against a throwaway `tmux -L`
   socket: replicate the entry-point's exact defaulting conditional and assert
   (a) option unset → becomes `30000`; (b) option set to a user value (`5000`)
   → preserved (not overwritten); (c) option set to `0` → preserved. This
   proves the "if unset" semantics + the new default without running the whole
   plugin (which sets hooks / binds keys / runs init).
4. **Level 4** — git diff is a single `+1/-1` literal; cross-file consistency
   grep (engine fallback already 30000).