# P1.M3.T3.S1 Research — Token Triage & Final-State Contract

## Purpose

This verification sweep (Mode B — changeset-level doc sweep, runs LAST) must
confirm all three files (`scripts/session_history.sh`, `session_history.tmux`,
`README.md`) are mutually consistent and consistent with the PRD, with NO stale
references to the removed activity-detection subsystem. The single most
important finding of this research is the **check (b) triage**: the contract's
broad `grep -rni "activity|poller|..."` is **intentionally a triage exercise,
not a literal "must be zero" gate** — three sanctioned references survive BY
DESIGN and must NOT be deleted.

## Observed current file state (all predecessor tasks effectively landed)

Verified by direct grep + read on 2025-08-05:

| File | Lines | Key state |
|------|-------|-----------|
| `README.md` | 184 | Options table `30000` (T2.S1 ✓); no `10000`; How-it-works selection+dwell only + §12 sentence (T1.S1/S2 ✓); Troubleshooting rewritten (T2.S2 ✓); no "How activity detection works" |
| `session_history.tmux` | 79 | dwell default `30000` (M2.T1.S1 ✓); bootstrap comment rewritten (M2.T1.S2 ✓); no focused-activity block |
| `scripts/session_history.sh` | 537 | `dwell_ms()` → `30000` (M1.T3.S1 ✓); header comments rewritten (M1.T4 ✓); `do_init` has migration guard, no `do_start_poller`, no `pipe-pane` (M1.T2.S1 ✓); Usage string has 11 commands (M1.T1.S2 ✓) |

> Note: `plan_status` flags M1.T2.S1 / M2.T1.S2 / M3.T1.S2 / M3.T2.S1 / M3.T2.S2
> as not-yet-Complete, but the **on-disk files are already in the post-refactor
> state** (each predecessor PRP anticipated this — see e.g. P1.M1.T2.S1's
> "Pre-flight state check" and P1.M2.T1.S2's note on T2.S1). The verification
> should therefore PASS (with documented exceptions). A state-check step
> detects the rare case where a predecessor truly hasn't landed.

## THE CHECK (b) TRIAGE TABLE (the core of this task)

Contract check (b): `grep -rni "activity\|poller\|client_activity\|focused.activity\|pipe-pane\|produce output\|typing.*promot" scripts/ session_history.tmux README.md`

Running this against the CURRENT (final-state) files produces these hits. Each
must be triaged LEGITIMATE-KEEP vs STALE-DEFECT:

| # | File:line | Matched token | Context | Verdict | Authority |
|---|-----------|---------------|---------|---------|-----------|
| 1 | `session_history.sh:489` | `poller` | migration-guard comment "left a poller process running" | **KEEP** (legitimate) | P1.M1.T2.S1 criterion #5 |
| 2 | `session_history.sh:490` | `poller` | "tracked in @session-history-poller-pid" | **KEEP** (legitimate) | P1.M1.T2.S1 criterion #5 |
| 3 | `session_history.sh:493` | `poller-pid` | `old_pid="$(G "$(H poller-pid)" ...)"` (read) | **KEEP** (legitimate) | P1.M1.T2.S1 criterion #5 |
| 4 | `session_history.sh:495` | `poller-pid` | `S "$(H poller-pid)" ""` (clear) | **KEEP** (legitimate) | P1.M1.T2.S1 criterion #5 |
| 5 | `session_history.tmux:12` | `activity` | "# extra hooks, no background sleepers, no monitor-activity." (NEGATION) | **KEEP** (legitimate) | P1.M2.T1.S2 criterion #4 |
| 6 | `README.md:132` | `activity` | "tmux's `monitor-activity` only sees *background* windows" (§12 explanation) | **KEEP** (legitimate) | P1.M3.T1.S2 (explicit KEEP); PRD §19 |

**All six are LEGITIMATE.** They reference the tokens only to (a) clean up stale
state (the migration guard drains a leftover PID from a prior install), or
(b) EXPLAIN THE ABSENCE of the subsystem (the two `monitor-activity` mentions
assert/describe that the signal is not used). None describes a *functioning*
activity-detection subsystem.

### Why deleting any of the six would be a DEFECT
- **Engine migration guard (#1–4):** deleting it strands an orphan poller
  process from a pre-refactor install running indefinitely (the residual risk
  flagged in `system_context.md` #1). The guard is self-cleaning: after one
  `init` it clears `@session-history-poller-pid` and subsequent runs no-op.
- **tmux negation (#5):** "no monitor-activity" is a CORRECT statement of what
  the plugin does NOT wire, consistent with PRD §9. P1.M2.T1.S2 success
  criterion #4 explicitly mandates it survives as the file's single `activity`
  hit.
- **README §12 sentence (#6):** PRD §19 "Known limitations" literally states
  "**No output-activity signal** by design (§12); relevance is selection +
  dwell." The README sentence is the user-facing version. P1.M3.T1.S2 and
  P1.M3.T2.S2 both explicitly KEEP it. doc_impact §9.2 says the README "should
  at least nod to this."

## The per-token REFINED greps (these distinguish must-be-zero from sanctioned-only)

The combined alternation in check (b) is too coarse. Run these per-token greps
to get an unambiguous signal — the first group MUST be zero; the second must be
sanctioned-only:

```bash
# GROUP A — MUST be ZERO (no legitimate exception exists for these tokens):
grep -rni "client_activity" scripts/ session_history.tmux README.md        # → 0
grep -rni "focused.activity" scripts/ session_history.tmux README.md       # → 0
grep -rni "pipe-pane" scripts/ session_history.tmux README.md              # → 0
grep -rni "piped-pane" scripts/ session_history.tmux README.md             # → 0
grep -rni "produce output" scripts/ session_history.tmux README.md         # → 0
grep -rni "typing.*promot" scripts/ session_history.tmux README.md         # → 0
grep -rni "alert-activity" scripts/ session_history.tmux README.md         # → 0

# GROUP B — sanctioned-only (every hit must appear in the triage table above):
grep -rni "activity" scripts/ session_history.tmux README.md   # → tmux:12 + README:132
grep -rni "poller" scripts/ session_history.sh                 # → 4 hits, all in migration guard
```

> Why "produce output" is in GROUP A (zero) even though README:132 says
> "produced output": the grep token is the literal two-word phrase
> `produce output` (present tense). The README sentence uses the past tense
> "produced output" (inside the quoted phrase "the focused session produced
> output"), which does NOT match `produce output`. Verified:
> `grep -rni "produce output"` → 0 on the current files. (The two removed
> Troubleshooting phrases "produce output in it while viewing it" and
> "unless you then produce output in them" are already gone — T2.S2.)

## Check (c) — dwell-default triangulation (three-way agreement)

All three must show `30000`:
- README Options table: line 86 → `30000` ✓ (T2.S1)
- engine `dwell_ms()` fallback: line 134 → `echo 30000` ✓ (M1.T3.S1)
- entry-point set-option: `session_history.tmux:55` → `30000` ✓ (M2.T1.S1)
And `10000` must be ZERO everywhere. (Verified: 0 hits across all three files.)

## Check (d) — Usage subcommand list vs PRD §17

Engine Usage string (line 536):
`Usage: $0 {init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset} [session]`
= 11 commands. PRD §17 lists exactly these 11. ✓ (10 `|` separators ⇒ 11 tokens.)

## Check (f) — README 'How it works' structure

- `grep -c "How activity detection works" README.md` → 0 ✓ (subsection removed, T1.S2)
- Exactly two promotion-cause bullets: "**select it directly**" + "**dwell on
  it**" ✓ (T1.S1). No third "type/switch panes/produce output" bullet.

## Check (e) — OPTIONAL Limitations one-liner (SPEC.md naming hazard)

Contract proposes adding to README Limitations:
> "Relevance comes from selection and dwell only — there is no output-activity
> signal by design (see SPEC.md §12). Dwell granularity is whole seconds."

**HAZARD:** the on-disk spec file is `PRD.md`, NOT `SPEC.md` (verified: no
`SPEC.md` exists; PRD §20 file map says "SPEC.md | This document" — the PRD's
internal name for itself, but the file is named PRD.md). A README link to
`SPEC.md` would 404 on GitHub. The README currently references NEITHER file.

**Recommendation:** check (e) is OPTIONAL and partially redundant — the §12
content already lives in How-it-works (README:132, T1.S2). If added, mirror PRD
§19's two limitations WITHOUT a broken cross-reference, e.g.:
> "Relevance comes from selection and dwell only — there is no output-activity
> signal by design. Dwell granularity is whole seconds."
(Or use "PRD.md §12" if a cross-ref is genuinely wanted.) The verification
PASSES regardless as long as the §12 content is present SOMEWHERE in README.

## doc_impact §9 residual risks (the sweep's job to confirm resolved)

1. README↔code dwell drift → **resolved** (all three at 30000; this task confirms).
2. README↔PRD §12 alignment → **resolved** (§12 sentence in How-it-works; this
   task confirms + optionally reinforces in Limitations).
3. Poller subcommand ref → **resolved** (no `activity`/`poller` subcommands in
   Usage; engine has no such case branches — this task confirms).
4. Concurrency framing `activity` among locked subcommands → **resolved**
   (engine dispatch has no `activity`/`poller` case — this task confirms).
5. "One resident process" claim → **resolved** (README §12 sentence + tmux line
   12 both now say no resident processes / no monitor-activity — this task
   confirms).

## Conclusion

The verification should PASS cleanly. The only "fix" the implementer is likely
to (optionally) make is the Limitations one-liner (check e). The critical
anti-pattern to prevent: a naive reading of check (b)'s "must return ZERO hits"
that deletes the migration guard or the §12 explanation sentence — both of which
would introduce real defects.