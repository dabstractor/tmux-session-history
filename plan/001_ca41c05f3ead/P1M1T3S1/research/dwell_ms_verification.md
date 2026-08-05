# Research Notes — P1.M1.T3.S1 (dwell_ms default 10000 → 30000)

## Verified current state (post-S1 + post-S2; file = 562 lines)

S1 (delete activity/poller function bodies) and S2 (remove activity/poller case
dispatch + Usage tokens) are BOTH **Complete** per `<plan_status>`. T2.S1
(do_init cleanup) is **Implementing** in parallel. T3.S1 (this task) is
**Researching**.

### The exact line to change — `scripts/session_history.sh:154`

```bash
153: # user-facing dwell threshold in ms; 0 disables dwell entirely
154: dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 10000 ;; *) echo "$d" ;; esac; }
```

- The fallback literal `echo 10000` → `echo 30000`. That is the ENTIRE change.
- Line 153 comment does NOT mention a default value — leave it untouched.
- Line 58 comment `# ... @session-history-dwell-ms (default 10000 ms)` is in the
  header comment block (lines 42–105) that **T4.S1/T4.S2** will rewrite. This
  task must NOT touch it (explicit scope boundary in the work-item contract,
  point 5: "the comment ... is inside the header comment block rewritten in
  P1.M1.T4").

### All `10000` occurrences in the engine (grep-verified)

```
58:#     and stay on it longer than @session-history-dwell-ms (default 10000 ms)
154:dwell_ms() { ... echo 10000 ;; ... }
```

Only line 154 is code. Line 58 is a comment owned by T4.

### Consumers of dwell_ms() (verified via grep)

- `arm_dwell()` (line 226–232) — the ONLY caller: `ms="$(dwell_ms)"; [ "$ms" -gt 0 ] 2>/dev/null || return 0`
- `arm_dwell` is called only from `do_hook` step 8 (line 297) for WALK arrivals.

So changing the fallback default 10000→30000 changes the **walk-dwell threshold**
when `@session-history-dwell-ms` is empty or non-numeric. The `0`-disables path
is UNAFFECTED: `"0"` is numeric, falls through to `*) echo "$d"` (echoes `0`),
and `arm_dwell`'s `[ "$ms" -gt 0 ]` returns early. This passthrough is a critical
regression invariant to test.

## Cross-file consistency map (the three places that must agree on 30000)

| Location | Current | Owner task | Status |
|----------|---------|------------|--------|
| `scripts/session_history.sh:154` (`dwell_ms` fallback) | `10000` | **P1.M1.T3.S1 (THIS)** | Researching |
| `session_history.tmux:55` (entry-point default) | `10000` | P1.M2.T1.S1 | Planned |
| `README.md:86` (Options table) | `10000` | P1.M3.T2.S1 | Planned |
| `scripts/session_history.sh:58` (header comment) | `10000` | P1.M1.T4 (rewrite) | Planned |
| `README.md:119` (prose "default 30 s") | already 30 s | (already correct) | n/a |

All three "default" sources must end at `30000`. This task covers ONLY the engine
runtime default (line 154).

## PRD authority (verbatim)

- **§15** (Config reference): `| @session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables dwell. |`
- **§8** (Dwell): `ms = dwell_ms()  # @session-history-dwell-ms, default 30000`
- **§14** (Invariants): `Non-numeric dwell-ms → treated as the default (30000).` and `dwell-ms = 0 → arm_dwell returns immediately`
- PRD contains **zero** occurrences of `10000` (grep-verified) — the `10000` is a
  pre-PRD legacy value that must be eliminated everywhere.

## Parallel-execution boundary with T2.S1

- T2.S1 edits `do_init()` (post-S1+S2 ~line 491–521 region: deletes pipe-pane
  block + poller-start, adds migration guard). Its edit is line-count-negative
  (−5 net per its PRP) but my line-154 edit is **line-count-neutral**.
- My `oldText` (the `dwell_ms()` one-liner) and T2.S1's `oldText` (the do_init
  pipe-pane/poller block) are textually disjoint and ~340 lines apart. **Clean
  merge, no collision.** Neither task re-reads the other's region.

## gap_analysis.md anchor

GAP 2a (verbatim): `scripts/session_history.sh:154 | dwell_ms() { ... echo 10000
;; ... } | 🔴 change 10000 → 30000`. GAP 2b = tmux (M2.T1.S1), 2c = line-58
comment (T4), 2d = README (M3.T2.S1). This PRP == GAP 2a only.