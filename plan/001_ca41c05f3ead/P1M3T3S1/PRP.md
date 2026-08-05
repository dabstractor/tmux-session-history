name: "P1.M3.T3.S1 — Verify cross-file documentation consistency (README ↔ code ↔ PRD); fix inconsistencies"
description: "Changeset-level documentation SWEEP (Mode B per SOW §5) that runs LAST, after every implementing subtask (P1.M1, P1.M2, P1.M3.T1, P1.M3.T2) has landed. INPUT: the final post-refactor state of all three files (scripts/session_history.sh, session_history.tmux, README.md). LOGIC: run the six verification checks (a)–(f) from the item contract against the actual files, triage every check-(b) hit as LEGITIMATE-KEEP vs STALE-DEFECT, and FIX any real inconsistency found (most likely none, or the OPTIONAL Limitations one-liner from check e). The single most important subtlety: check (b)'s broad grep ('activity|poller|client_activity|focused.activity|pipe-pane|produce output|typing.*promot … must return ZERO hits') is a TRIAGE EXERCISE, not a literal zero gate — six sanctioned references survive BY DESIGN (the engine's one-shot stale-poller migration guard, the tmux line-12 'no monitor-activity' negation, and the README line-132 §12 explanation sentence). Deleting any of those would INTRODUCE a defect (break the upgrade path / contradict PRD §19). OUTPUT: a consistency report proving all three files agree with each other and the PRD, with zero STALE activity-detection references. The three-way dwell default (30000) triangulates across README Options table (line 86), engine dwell_ms() (line 134), and entry-point set-option (session_history.tmux:55). The Usage subcommand list (11 commands) matches PRD §17. See plan/001_ca41c05f3ead/architecture/doc_impact.md §9 (cross-document consistency checks) and system_context.md (residual risks)."

---

## Goal

**Feature Goal**: Prove — and, where a real inconsistency exists, repair — that
`scripts/session_history.sh`, `session_history.tmux`, and `README.md` are
mutually consistent and each consistent with `PRD.md`, with **zero STALE
references** to the removed activity-detection subsystem remaining anywhere.

**Deliverable**: A completed consistency sweep of all three files (the six
contract checks a–f run and documented), any genuine inconsistency fixed in
place, and — **optionally** — a one-line Limitations reinforcement in README
(check e). Because this is a verification/sweep task (Mode B), the primary
artifact is the *verified state*, not new code. Expected outcome: all checks
PASS (with six documented legitimate exceptions to check b), zero stale
references, the three-way `30000` agreement confirmed, and the 11-command Usage
list matching PRD §17.

**Success Definition**:
1. Check (a): `grep -rn "10000" scripts/ session_history.tmux README.md` → **0**.
2. Check (b) triage: the broad alternation grep may be non-zero, but EVERY hit
   is one of the six sanctioned LEGITIMATE-KEEP references (see the Triage Table
   in Context). The refined per-token greps (GROUP A: `client_activity`,
   `focused.activity`, `pipe-pane`, `piped-pane`, `produce output`,
   `typing.*promot`, `alert-activity`) → **0** each.
3. Check (c): `30000` appears in all THREE sites — README Options table,
   engine `dwell_ms()`, entry-point `set-option` — and agrees.
4. Check (d): the engine Usage string lists exactly PRD §17's 11 subcommands.
5. Check (e): OPTIONAL — if added, the README Limitations one-liner mirrors PRD
   §19 without a broken `SPEC.md` cross-reference (the on-disk spec is
   `PRD.md`). The §12 content is already present in How-it-works either way.
6. Check (f): README "How it works" has exactly two promotion causes
   (selection + dwell) and no "How activity detection works" subsection.
7. No legitimate reference was wrongly deleted (the migration guard, the tmux
   negation, and the README §12 sentence all survive intact).

## User Persona (if applicable)

**Target User**: The plugin maintainer / future contributor (and, transitively,
the end user who reads the README). This sweep is internal QA, not user-facing.

**Use Case**: After a large multi-subtask refactor that removed an entire
subsystem (activity detection) and bumped a default (10000→30000) across three
files, a final reviewer must confirm the three files no longer contradict each
other or the spec, and that no half-removed reference lingers to confuse a
future reader or mislead the engine.

**User Journey**: Reviewer runs the check suite → reads the triage of each
check-(b) hit → confirms the three-way dwell agreement → confirms the 11-command
Usage list → (optionally) adds the Limitations one-liner → ships a self-consistent
changeset.

**Pain Points Addressed**: doc_impact §9 enumerates five residual cross-document
risks (dwell-default drift, README↔PRD §12 misalignment, stale poller
subcommand refs, concurrency `activity` framing, "one resident process" claim).
This sweep closes all five by *verifying* they are resolved, not by assumption.

## Why

- **Closes the refactor.** Every implementing subtask (P1.M1, P1.M2, P1.M3.T1,
  P1.M3.T2) touched one file or one region. Only this sweep reads ALL THREE
  together and confirms they tell one story. It is the Mode B changeset-level
  documentation sweep per SOW §5 and runs last by construction.
- **Prevents the most expensive failure mode: drift that lies.** doc_impact §9.1
  and system_context.md residual risk #4 both warn that a dwell default changed
  in one file but not the others "will lie." The three-way check (c) is the
  deterministic guard against exactly that.
- **Prevents the second-most-expensive failure mode: a naive "zero hits" mis-fix.**
  A reviewer who runs check (b) literally and sees `poller`/`monitor-activity`
  hits could delete the engine's one-shot migration guard (stranding an orphan
  poller from a prior install — system_context.md risk #1) or the README §12
  explanation (contradicting PRD §19). This PRP's triage table makes the
  legitimate exceptions unambiguous, so the sweep does no harm.
- **Spec compliance — PRD §6/§12/§17/§19.** Selection+dwell-only relevance
  (§6), the rationale for no output-activity signal (§12/§19), the exact
  11-subcommand surface (§17), and the `30000` default (§15) must all be
  reflected consistently across the three files.

## What

A read-mostly verification sweep over the three files. The reviewer runs the
six contract checks (a)–(f), triages check (b), and fixes only genuine
inconsistencies. Concretely, the reviewer will:

1. **State-check** that all predecessor tasks have landed (README 184 lines,
   no `10000`, `30000` present, no "How activity detection works"; tmux 79
   lines, dwell `30000`, no focused-activity block; engine has the migration
   guard). If a predecessor truly hasn't landed, STOP and surface the gap rather
   than mis-fix.
2. **Run checks (a)–(d) and (f)** as deterministic greps. Record pass/fail.
3. **Triage check (b)**: run the broad grep, then classify each hit against the
   Triage Table; run the refined GROUP-A per-token greps (must each be 0) and
   the GROUP-B sanctioned-only greps.
4. **Fix** any real defect found (expected: none). If a defect is found that is
   outside this task's narrow "consistency fix" scope, surface it instead of
   rewriting a whole region owned by another subtask.
5. **Optionally apply check (e)** — the README Limitations one-liner — resolving
   the `SPEC.md`/`PRD.md` naming so no broken link is introduced.
6. **Emit a one-screen consistency report** (pass/fail per check + the triage).

### Success Criteria

- [ ] Check (a): `grep -rn "10000"` → **0** hits across all three files.
- [ ] Check (b): refined GROUP-A per-token greps → **0** each; GROUP-B greps
      contain ONLY the six sanctioned LEGITIMATE-KEEP references.
- [ ] Check (c): `30000` present in README Options table, engine `dwell_ms()`,
      AND entry-point `set-option`; all three agree.
- [ ] Check (d): engine Usage string == PRD §17's 11 commands.
- [ ] Check (f): README "How it works" == exactly two promotion causes; no
      "How activity detection works" subsection.
- [ ] (Optional) Check (e): README Limitations reinforced with a `SPEC.md`-safe
      one-liner mirroring PRD §19.
- [ ] The six sanctioned references survive byte-identical (migration guard,
      tmux line-12 negation, README line-132 §12 sentence).
- [ ] All four validation levels run; `bash -n` on both bash files exits 0;
      `shellcheck` introduces no NEW diagnostics vs. pre-sweep baseline.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact six checks (a)–(f) with copy-pasteable
greps and their expected results; the complete Triage Table enumerating every
current check-(b) hit with file:line, matched token, verdict, and the
predecessor-PRP authority that sanctions each KEEP; the refined GROUP-A
(must-be-zero) vs GROUP-B (sanctioned-only) per-token grep split that makes the
signal unambiguous; the three-way `30000` triangulation (exact file:line for
each); the 11-command Usage list vs PRD §17; the state-check that detects a
predecessor-not-landed situation; the `SPEC.md`-naming hazard for the optional
check (e) with a safe resolution; and explicit anti-patterns forbidding the
deletion of the six legitimate references. An implementer with zero prior
knowledge of this codebase can run the sweep in one pass.

### Documentation & References

```yaml
# MUST READ — the cross-document consistency checklist this sweep enforces
- docfile: plan/001_ca41c05f3ead/architecture/doc_impact.md
  section: "§9. Cross-document consistency checks (residual risks)"
  why: "§9 enumerates the FIVE residual risks this sweep must confirm resolved:
        (1) README↔code dwell drift — resolved iff all three at 30000 (check c);
        (2) README↔PRD §12 alignment — resolved iff the §12 sentence is present
        in README (check b triage #6, it is — line 132); (3) poller subcommand
        ref — resolved iff the Usage string has no activity/poller tokens (check
        d); (4) concurrency 'activity' framing — resolved iff the engine dispatch
        has no activity/poller case (check b); (5) 'one resident process' claim —
        resolved iff README + tmux now say no resident processes / no
        monitor-activity (check b triage #5/#6)."
  critical: "§9 is the authoritative source for WHAT this sweep verifies. Each
             of its five items maps 1:1 to a check below."

# MUST READ — residual risks (esp. #1 stale poller, #4 dwell three-way)
- docfile: plan/001_ca41c05f3ead/architecture/system_context.md
  section: "Residual Risks"
  why: "Risk #1 (stale poller on upgrade) is MITIGATED by the migration guard
        this sweep must NOT delete (check b triage #1–4). Risk #4 (dwell default
        must change in THREE places simultaneously) is exactly check (c)."
  critical: "The migration guard is a deliberate mitigation of risk #1. A naive
             'remove all poller references' would re-open that risk. KEEP it."

# MUST READ — the relevance model authority (selection + dwell only)
- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't (and §2 Key invariant)"
  why: "PRD §6: exactly two promotion causes — direct selection + dwell. 'Walking
        never promotes.' README 'How it works' must reflect exactly these two
        bullets (check f)."
  critical: "There is NO third 'produce output promotes' cause. Any remaining
             such reference is a STALE-DEFECT (check b GROUP A)."

# MUST READ — why no output-activity signal (the §12 sentence that STAYS)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal  +  §19 Known limitations"
  why: "PRD §12 explains the design decision; §19 lists 'No output-activity
        signal by design (§12); relevance is selection + dwell' as a KNOWN
        LIMITATION. The README §12 sentence (line 132) and the optional check-(e)
        Limitations one-liner are the user-facing reflections of §12/§19. Both
        legitimately contain 'monitor-activity'/'output-activity' and MUST survive."
  critical: "Do NOT treat the README §12 sentence's 'monitor-activity' token as a
             stale reference to remove. It is the PRD-mandated explanation of the
             absence (PRD §19). Same for the tmux line-12 'no monitor-activity'
             negation."

# MUST READ — the authoritative 11-subcommand surface (check d)
- docfile: PRD.md
  section: "§17. Subcommand reference"
  why: "§17 lists exactly 11 commands: init, hook, dwell, prune, maintain, toggle,
        back, forward, pick, status, reset. The engine Usage string must list
        exactly these (check d). No activity/poller command survives."
  critical: "If the Usage string lists 12 commands or includes activity/poller,
             check (d) FAILS — that is a real defect to fix (re-run M1.T1.S2)."

# MUST READ — the dwell default + 0-disables semantics (check c)
- docfile: PRD.md
  section: "§15. Configuration reference  +  §8 Dwell (Arming)"
  why: "§15: '@session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables
        dwell.' The README Options table, engine dwell_ms() fallback, and
        entry-point set-option must ALL show 30000 (check c). §8 arm_dwell:
        'if ms <= 0: return' — the 0-disables semantics."
  critical: "30000 in three places, 10000 in zero places. Anything else is drift."

# The three files under verification (the sweep's whole input)
- file: scripts/session_history.sh
  why: "Engine. Verify: dwell_ms() line 134 → 'echo 30000'; Usage line 536 lists
        11 commands; do_init migration guard lines 489–495 present (KEEP); no
        do_start_poller, no do_activity, no do_poller, no pipe-pane, no
        client_activity, no activity/poller case branches; header comments are
        selection+dwell only."
  pattern: "The sweep is READ-ONLY on this file unless a real defect is found.
            If a defect is found, prefer surfacing it over a speculative rewrite;
            the engine is already in its final state per every predecessor PRP."
  gotcha: "The migration guard is the ONLY legitimate 'poller' site. grep
           'poller' → exactly 4 hits (comment×2 + G-read + S-clear), all in
           do_init. This is correct; do not 'clean it up'."

- file: session_history.tmux
  why: "Entry point. Verify: line 55 set-option dwell-ms → 30000; line 12 'no
        monitor-activity' negation present (KEEP); no focused-activity comment
        block; bootstrap comment rewritten (no poller/race/toggle-enabled); 79
        lines; bash -n passes."
  pattern: "READ-ONLY unless a real defect is found. The single legitimate
            'activity' hit is the line-12 negation."
  gotcha: "Line 12 'no monitor-activity' is a CORRECT absence statement (PRD §9).
           P1.M2.T1.S2 success criterion #4 mandates it as the file's ONLY
           activity hit. Do not delete it."

- file: README.md
  why: "User docs. Verify: Options table line 86 → 30000; no 10000; 'How it
        works' has exactly two promotion-cause bullets (select-it-directly +
        dwell-on-it) and no 'How activity detection works' subsection; the §12
        sentence at line 132 present (KEEP); Troubleshooting 'wrong session'
        paragraph is selection+dwell only; (optional) Limitations one-liner."
  pattern: "READ-ONLY except the OPTIONAL check-(e) Limitations edit. README is
            184 lines; the optional edit would grow it by one bullet/line."
  gotcha: "Line 132 'monitor-activity' (the §12 sentence) is the EXPLANATION of
           the absence and is correct/KEEP. The §12 content already lives here,
           so check (e) is redundant-but-acceptable — do not duplicate the whole
           sentence in Limitations."

# The predecessor PRPs that DEFINE the expected final state (CONTRACTS)
- docfile: plan/001_ca41c05f3ead/P1M1T2S1/PRP.md
  why: "Defines the migration guard (check b triage #1–4). Its criterion #5:
        'grep poller-pid → exactly 3 lines, all in the guard.' Confirms the
        guard's poller refs are sanctioned."
  critical: "If grep 'poller' in the engine returns FEWER than the 4 sanctioned
             hits, the guard may have been wrongly removed — surface it (risk #1
             re-opens). If MORE, a stale poller reference survived — fix it."
- docfile: plan/001_ca41c05f3ead/P1M2T1S2/PRP.md
  why: "Defines the tmux line-12 'no monitor-activity' negation as KEEP
        (criterion #4: grep -ni activity → exactly 1 match, the line-12 negation).
        Confirms check b triage #5."
  critical: "If grep 'activity' session_history.tmux returns 0, the negation was
             wrongly deleted — restore it. If >1, a stale activity ref survived."
- docfile: plan/001_ca41c05f3ead/P1M3T1S2/PRP.md
  why: "Defines the README line-132 §12 sentence as KEEP and the removal of the
        'How activity detection works' subsection. Confirms check b triage #6
        and check (f)."
  critical: "If the §12 sentence is gone, README contradicts PRD §19 — restore
             it. If 'How activity detection works' is present, T1.S2 didn't land
             — surface the gap."
- docfile: plan/001_ca41c05f3ead/P1M3T2S1/PRP.md
  why: "Defines the README Options-table 30000 row (check c README side)."
- docfile: plan/001_ca41c05f3ead/P1M3T2S2/PRP.md
  why: "Defines the README Troubleshooting selection+dwell-only rewrite (check b
        — 'produce output' phrases removed)."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §6/§12/§15/§17/§19 are the authorities
├── README.md                   # ← VERIFY (184 lines). 30000@86, §12 sentence@132 (KEEP),
│                                #   selection+dwell How-it-works, no "How activity detection works".
│                                #   OPTIONAL edit: Limitations one-liner (check e).
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← VERIFY (537 lines). dwell_ms 30000@134, Usage 11 cmds@536,
│                                #   migration guard@489-495 (KEEP, the only legit 'poller' site).
├── session_history.tmux        # ← VERIFY (79 lines). dwell 30000@55, "no monitor-activity"@12 (KEEP).
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/doc_impact.md      # ← §9 = the checklist this sweep enforces
        ├── architecture/system_context.md  # ← residual risks #1 (poller) & #4 (dwell 3-way)
        ├── P1M1T2S1/PRP.md                 # ← migration guard contract (check b #1-4)
        ├── P1M2T1S2/PRP.md                 # ← tmux line-12 negation contract (check b #5)
        ├── P1M3T1S2/PRP.md                 # ← README §12 sentence + subsection removal (check b #6, f)
        ├── P1M3T2S1/PRP.md                 # ← README Options 30000 row (check c README)
        ├── P1M3T2S2/PRP.md                 # ← README Troubleshooting rewrite (check b)
        └── P1M3T3S1/
            ├── PRP.md                      # ← THIS task
            └── research/token_triage_and_state.md   # ← the Triage Table + observed state
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. This is a verification sweep. The three files are read; at most
# README.md gets the OPTIONAL one-line Limitations reinforcement (check e). If a
# real defect is found in any file, it is fixed in place (minimal, scoped), but
# the expected outcome is zero defects — every predecessor PRP landed the final
# state. After the sweep, all three files + PRD agree on: selection+dwell-only
# relevance, the 30000 dwell default, the 11-subcommand surface, and the absence
# (with explanation) of any activity-detection subsystem.
```

### The Check (b) Triage Table — the heart of this sweep

Running the contract's broad
`grep -rni "activity|poller|client_activity|focused.activity|pipe-pane|produce output|typing.*promot"`
against the final-state files yields these hits. **Every one is LEGITIMATE-KEEP.**
Any hit NOT in this table is a STALE-DEFECT to fix.

| # | File:line | Token | Context (abbreviated) | Verdict | Authority |
|---|-----------|-------|------------------------|---------|-----------|
| 1 | `session_history.sh:489` | `poller` | migration-guard comment: "left a poller process running" | **KEEP** | P1.M1.T2.S1 #5 |
| 2 | `session_history.sh:490` | `poller` | "tracked in @session-history-poller-pid" | **KEEP** | P1.M1.T2.S1 #5 |
| 3 | `session_history.sh:493` | `poller-pid` | `old_pid="$(G "$(H poller-pid)" ...)"` (read) | **KEEP** | P1.M1.T2.S1 #5 |
| 4 | `session_history.sh:495` | `poller-pid` | `S "$(H poller-pid)" ""` (clear) | **KEEP** | P1.M1.T2.S1 #5 |
| 5 | `session_history.tmux:12` | `activity` | "# extra hooks, no background sleepers, no monitor-activity." (NEGATION) | **KEEP** | P1.M2.T1.S2 #4 |
| 6 | `README.md:132` | `activity` | "tmux's `monitor-activity` only sees *background* windows" (§12 explanation) | **KEEP** | P1.M3.T1.S2; PRD §19 |

**Why these six are not "stale references":** the migration guard (#1–4) does
not *implement* activity detection — it *drains* a leftover PID from a prior
install (system_context.md risk #1; self-cleaning: after one `init` it clears
the option and no-ops forever). The two `monitor-activity` mentions (#5, #6)
*assert/describe the absence* of the signal (PRD §9 "no extra hooks"; PRD §19
"No output-activity signal by design"). None describes a functioning
activity-detection subsystem.

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — check (b)'s "must return ZERO hits" is a TRIAGE EXERCISE, not a
# literal zero gate. Six sanctioned references survive BY DESIGN (Triage Table).
# Deleting ANY of them introduces a real defect:
#   - removing the migration guard (#1-4) re-opens system_context.md risk #1
#     (orphan poller runs indefinitely after upgrade);
#   - removing the tmux line-12 negation (#5) or README §12 sentence (#6)
#     contradicts PRD §9/§19 and the predecessor PRPs that explicitly KEEP them.
# Run the refined GROUP-A per-token greps (must be 0) to get the clean signal;
# use the Triage Table to confirm GROUP-B hits are all sanctioned.

# CRITICAL — "produce output" (two words, present tense) is GROUP-A zero, but do
# NOT confuse it with README:132's "produced output" (past tense, inside the
# quoted phrase "the focused session produced output"). The latter does NOT
# match the grep token "produce output" and is part of the §12 KEEP sentence.
# Verified: grep -rni "produce output" → 0 on the current files.

# CRITICAL — the on-disk spec file is PRD.md, NOT SPEC.md (no SPEC.md exists;
# PRD §20 file map says "SPEC.md | This document" — the PRD's internal name for
# itself). If you add the OPTIONAL check-(e) Limitations one-liner, do NOT write
# "(see SPEC.md §12)" — that 404s on GitHub. Either omit the cross-reference or
# use "PRD.md §12". The README currently references neither file.

# GOTCHA — the §12 content already lives in README How-it-works (line 132, added
# by T1.S2). Check (e) is therefore OPTIONAL and partially redundant. The
# verification PASSES as long as the §12 content is present SOMEWHERE in README
# (it is). Adding it to Limitations is a low-priority nicety, not a requirement.

# GOTCHA — no test framework / markdown linter / CI is wired (no bats/spec/
# Makefile/markdown-CI). The sweep's "tests" are deterministic greps + bash -n +
# shellcheck (no-new-diagnostics). If markdownlint/mdl is installed, run it as a
# bonus; absence is not a failure.

# GOTCHA — this is a READ-MOSTLY sweep. The only expected WRITE is the OPTIONAL
# check-(e) Limitations edit. If you find yourself rewriting a region owned by
# another subtask (How-it-works, Options table, Troubleshooting, engine
# functions, tmux comments), STOP — that region is already final; surface the
# discrepancy instead of re-editing it.
```

## Implementation Blueprint

### Data models and structure

None. This is a verification sweep over prose (README), comments (tmux), and
bash (engine + entry point). No data models, schemas, options, hooks, or
dispatch change. The only optional mutation is a one-line README Limitations
addition (check e). The `@session-history-dwell-ms` option name and `30000`
default are referenced verbatim (unchanged) — the sweep *confirms* them in three
places, it does not set them.

### Verification Steps (ordered by dependencies)

```yaml
Step 1: STATE-CHECK that all predecessor tasks landed (no source edits)
  - RUN: wc -l README.md session_history.tmux scripts/session_history.sh
    EXPECT: README=184, tmux=79, engine=537 (±a few; engine count is informational,
            not a gate — content greps below are authoritative).
  - RUN: grep -c '10000' README.md                                    # EXPECT 0 (T2.S1)
  - RUN: grep -c '30000' README.md                                    # EXPECT 1 (T2.S1)
  - RUN: grep -c 'How activity detection works' README.md             # EXPECT 0 (T1.S2)
  - RUN: grep -c '30000' session_history.tmux                         # EXPECT 1 (M2.T1.S1, line 55)
  - RUN: grep -c 'no monitor-activity' session_history.tmux           # EXPECT 1 (line 12 KEEP)
  - RUN: grep -c 'echo 30000' scripts/session_history.sh              # EXPECT 1 (M1.T3.S1, dwell_ms)
  - RUN: grep -c 'migration guard\|One-shot migration' scripts/session_history.sh  # EXPECT 1 (M1.T2.S1 guard present)
  - RUN: grep -c 'do_start_poller' scripts/session_history.sh         # EXPECT 0 (M1.T1.S1/T2.S1)
  - WHY: confirms every implementing subtask landed. If any FAILS (e.g. 10000 still
         in README, or the migration guard absent), a predecessor didn't land —
         STOP and surface the gap with the specific subtask name; do NOT attempt
         the predecessor's edit yourself (out of scope for a sweep).

Step 2: CHECK (a) — no 10000 anywhere (the only valid dwell default is 30000)
  - RUN: grep -rn "10000" scripts/ session_history.tmux README.md
    EXPECT: ZERO output (0 hits). If ANY hit → real defect; the site must read 30000.
            (engine dwell_ms comment at line ~58 may say "default 30000 ms" — that is
             fine; grep for the bare 10000 literal must still be 0.)

Step 3: CHECK (b) — activity/poller sweep WITH TRIAGE (the core step)
  3a. RUN the broad contract grep (informational — EXPECT the 6 sanctioned hits):
      grep -rni "activity\|poller\|client_activity\|focused.activity\|pipe-pane\|produce output\|typing.*promot" scripts/ session_history.tmux README.md
      EXPECT: exactly the 6 lines in the Triage Table (engine 489/490/493/495,
              tmux 12, README 132). MORE or OTHER lines = a stale defect.
  3b. RUN the GROUP-A per-token greps (each MUST be 0 — no legitimate exception):
      for t in client_activity focused.activity pipe-pane piped-pane "produce output" 'typing.*promot' alert-activity; do
        n=$(grep -rni "$t" scripts/ session_history.tmux README.md | wc -l)
        echo "$t -> $n"; [ "$n" = 0 ] || echo "  !!! STALE DEFECT for $t"
      done
      EXPECT: every line "t -> 0". Any non-zero = a real stale reference to fix.
  3c. RUN the GROUP-B sanctioned-only greps (every hit must be in the Triage Table):
      echo "--- engine 'poller' (EXPECT 4, all in migration guard do_init):"
      grep -rni "poller" scripts/session_history.sh
      echo "--- 'activity' across all three (EXPECT tmux:12 + README:132 only):"
      grep -rni "activity" scripts/ session_history.tmux README.md
      EXPECT: engine poller = the 4 guard lines; activity = tmux line 12 + README line 132.
              Any ADDITIONAL hit not in the Triage Table = stale defect.
  - IF a stale defect is found (3b non-zero, or 3a/3c has an extra line):
      * If it is a one-token/one-line stale reference clearly inside this sweep's
        "fix inconsistencies" mandate (e.g. a stray comment word), fix it minimally
        in place and re-run the grep to confirm 0.
      * If it is a structural remnant owned by another subtask (e.g. an entire
        activity case branch in the engine dispatch, or the "How activity detection
        works" subsection re-appeared), DO NOT rewrite it — surface it (name the
        subtask that owns it) and treat the sweep as partially blocked.

Step 4: CHECK (c) — three-way dwell-default triangulation (30000 everywhere)
  - RUN: echo "README Options:";  grep -n '30000' README.md
  - RUN: echo "engine dwell_ms:"; grep -n 'echo 30000' scripts/session_history.sh
  - RUN: echo "entry-point:";     grep -n "dwell-ms' 30000\|dwell-ms' \"30000\"" session_history.tmux
  - RUN (cross-check the full dwell line in tmux): grep -n "session-history-dwell-ms" session_history.tmux
  EXPECT: all three show 30000; they agree. README=1 hit (Options table line 86);
          engine=1 hit (dwell_ms line 134); tmux=1 hit (set-option line 55).
          If any shows 10000 or is absent → drift defect (re-run the owning subtask).

Step 5: CHECK (d) — Usage subcommand list == PRD §17's 11 commands
  - RUN: grep -n 'Usage:' scripts/session_history.sh
  EXPECT: exactly "Usage: $0 {init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset} [session]"
  - RUN (count): grep 'Usage: ' scripts/session_history.sh | grep -o '|' | wc -l   # EXPECT 10 (=> 11 tokens)
  - RUN (sanity — no activity/poller subcommand): grep -nE '\b(activity|poller)\b' scripts/session_history.sh | grep -iv 'poller-pid\|migration\|guard\|gone' 
  EXPECT: the Usage count = 11 commands matching PRD §17 exactly; the sanity grep
          finds NO activity/poller SUBCOMMAND (the only 'poller' words are in the
          migration guard, already triaged). If Usage lists 12 or includes
          activity/poller → M1.T1.S2 didn't fully land — surface it.

Step 6: CHECK (f) — README 'How it works' has exactly two promotion causes
  - RUN: grep -c 'How activity detection works' README.md      # EXPECT 0 (subsection gone)
  - RUN: sed -n '/## How it works/,/## Requirements/p' README.md | grep -nE 'select it directly|dwell on it'
  EXPECT: exactly two promotion-cause bullets ("select it directly" + "dwell on it"),
          NO "How activity detection works" subsection, NO third "type/switch
          panes/produce output" bullet. If a third bullet or the subsection is
          present → T1.S1/T1.S2 didn't land — surface it.

Step 7: CHECK (e) — OPTIONAL Limitations one-liner (the only likely WRITE)
  - READ the current README Limitations section:
      sed -n '/## Limitations/,/## License/p' README.md
  - DECIDE: the §12 content is ALREADY present in How-it-works (line 132). Adding
            it to Limitations is a low-priority nicety mirroring PRD §19. If you
            choose to add it, resolve the SPEC.md hazard: use PRD §19's phrasing
            WITHOUT a broken "(see SPEC.md §12)" cross-reference (the file is
            PRD.md, and the README currently links neither).
  - IF ADDING: use the `edit` tool to insert, after the existing single-paragraph
      Limitations, a second limitation mirroring PRD §19's two items, e.g.:
        "Relevance comes from selection and dwell only — there is no output-activity
        signal by design. Dwell granularity is whole seconds."
      (Place it as a new bullet or sentence consistent with the existing
       Limitations paragraph style. Avoid "(see SPEC.md §12)"; if a cross-ref is
       truly wanted, use "PRD.md §12".)
  - IF NOT ADDING: skip; the sweep still PASSES (the §12 content is present at
      line 132). Document the decision in the report.
  - VERIFY after adding: README still has the §12 sentence at line ~132; the new
      line introduces no curly quotes; wc -l README.md grows by exactly the lines added.

Step 8: BASELINE + re-run bash -n / shellcheck on the bash files (no functional edits expected)
  - RUN: bash -n scripts/session_history.sh && echo "ENGINE PARSE OK"
  - RUN: bash -n session_history.tmux && echo "ENTRY PARSE OK"
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_sweep_engine.txt 2>&1; echo "exit $?"
  - RUN: shellcheck session_history.tmux > /tmp/sc_sweep_entry.txt 2>&1; echo "exit $?"
  EXPECT: both parse OK; shellcheck reports no NEW diagnostics vs. the pre-sweep
          state (capture a before-snapshot if you made any edit). A comment/prose
          change should introduce zero shellcheck diagnostics.

Step 9: EMIT the one-screen consistency report
  - For each check (a)–(f): PASS/FAIL + the observed values.
  - The Triage Table reproduced with "all 6 sanctioned / 0 stale" confirmed.
  - Any fix applied (with file:line) OR "no defects found."
  - The check-(e) decision (added / skipped) with rationale.
```

### Implementation Patterns & Key Details

```bash
# Why the GROUP-A / GROUP-B split matters more than the literal check (b):
#   The contract's combined alternation "activity|poller|client_activity|..."
#   cannot distinguish "must be zero" (client_activity, pipe-pane, produce output,
#   typing.*promot — no legitimate exception) from "sanctioned-only" (activity,
#   poller — each has documented KEEP sites). Running it raw yields 6 expected
#   hits that a naive reviewer might "fix," breaking the upgrade path (migration
#   guard) or contradicting PRD §19 (the §12 sentence). The per-token GROUP-A
#   greps give an unambiguous "0 = clean" signal; the GROUP-B greps + Triage
#   Table confirm the survivors are all sanctioned. This is the sweep's
#   single highest-value reasoning step.

# Why the migration guard is KEEP (not a stale reference):
#   It is a one-shot, self-cleaning upgrade shim. do_init reads
#   @session-history-poller-pid (an option the OLD do_start_poller wrote),
#   kills that stale PID best-effort, then clears the option to "". After the
#   first post-upgrade init the option is empty, so every subsequent init
#   no-ops. It references "poller" only to NAME the legacy state it drains —
#   it does not start, run, or implement any poller. Deleting it re-opens
#   system_context.md residual risk #1 (orphan poller). (Verified pattern via
#   git: it mirrors the deleted do_start_poller's proven kill line.)

# Why the two monitor-activity mentions are KEEP (not stale references):
#   tmux:12 "no monitor-activity" — an assertion of ABSENCE (PRD §9: "no extra
#     hooks"). P1.M2.T1.S2 criterion #4 mandates it as the file's only 'activity'.
#   README:132 "monitor-activity only sees background windows" — the EXPLANATION
#     of why there is no output-activity signal (PRD §12), echoed as a KNOWN
#     LIMITATION in PRD §19. P1.M3.T1.S2 explicitly keeps it.
#   Both describe what the plugin does NOT do. Neither implements activity
#   detection.

# Why check (e) is OPTIONAL and the SPEC.md hazard:
#   PRD §19 lists "No output-activity signal by design (§12)" and "Dwell
#   granularity is whole seconds" as limitations. The README already carries the
#   §12 rationale in How-it-works (line 132), so duplicating it in Limitations is
#   redundant-but-acceptable. The contract's proposed one-liner says "(see
#   SPEC.md §12)" — but the on-disk spec file is PRD.md (PRD §20 calls itself
#   "SPEC.md" internally, yet the file is named PRD.md; no SPEC.md exists). A
#   README link to SPEC.md would 404 on GitHub. Safe resolution: add the
#   limitation WITHOUT the cross-reference, or use "PRD.md §12".

# How the sweep stays READ-MOSTLY:
#   The expected outcome is all checks PASS with the 6 sanctioned exceptions and
#   zero defects. The only likely WRITE is the optional check-(e) Limitations
#   line. If a real defect appears, fix it minimally in place; if it is
#   structural (a whole region owned by another subtask), surface it rather than
#   re-doing that subtask's work. The engine, entry point, and README are each
#   already in the final state their owning PRPs specified.
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin; no DB.

CONFIG (tmux global user options):
  - none changed by this sweep. The sweep CONFIRMS @session-history-dwell-ms is
        30000 in the README Options table, the engine dwell_ms() fallback, and
        the entry-point set-option. It does not set the option.

ROUTES / DISPATCH:
  - none changed. The sweep CONFIRMS the engine's 11-subcommand Usage surface
        matches PRD §17 (no activity/poller subcommand). It does not edit dispatch.

HOOKS / BINDINGS:
  - none changed. The sweep CONFIRMS session_history.tmux wires only the three
        PRD §16 hooks and four conditional bindings. It does not edit them.

DOCUMENTATION:
  - THIS sweep IS the changeset-level documentation sweep (Mode B per SOW §5).
        After it, the three files + PRD agree on: selection+dwell-only relevance
        (§6), the 30000 dwell default (§15), the 11-subcommand surface (§17), and
        the design absence of any activity-detection subsystem (§9/§12/§19). The
        only optional doc mutation is the README Limitations one-liner (check e).
        This is the LAST task in the plan; it has no downstream consumer except
        the human reviewer who reads the consistency report.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Parse both bash files (a sweep that makes no functional change must not break parsing):
bash -n scripts/session_history.sh && echo "ENGINE PARSE OK" || echo "ENGINE PARSE FAIL"
bash -n session_history.tmux      && echo "ENTRY PARSE OK"  || echo "ENTRY PARSE FAIL"
# Expected: both OK. (If you applied the OPTIONAL check-e edit, it's README-only
#           prose, so these are unaffected. If FAIL, you accidentally edited a bash
#           file's syntax — revert and re-run the sweep read-only.)

# Shellcheck no-new-diagnostics gate (only meaningful if you edited a bash file;
# the optional check-e edit is README-only, so expect identical output):
shellcheck scripts/session_history.sh > /tmp/sc_sweep_engine_after.txt 2>&1
shellcheck session_history.tmux      > /tmp/sc_sweep_entry_after.txt  2>&1
# Compare to the before-sweep snapshot if you captured one; expect NO new lines
# (a verification sweep adds zero diagnostics). If you only ran read-only checks,
# there is nothing to compare — shellcheck output is informational.

# Bonus markdown lint (only if a linter is installed; absence is NOT a failure):
command -v markdownlint >/dev/null && markdownlint README.md || \
command -v mdl >/dev/null && mdl README.md || \
echo "no markdown linter installed — skipping (not a failure for a sweep)"
```

### Level 2: Structural Proofs — the six checks (the sweep's real "tests")

No test framework in this repo. These deterministic greps ARE the test suite.
Run them in order; record PASS/FAIL for each.

```bash
# (a) No 10000 anywhere — the only valid dwell default is 30000:
echo "=== (a) 10000 sweep (EXPECT 0) ==="
grep -rn "10000" scripts/ session_history.tmux README.md
echo "hits: $(grep -rn "10000" scripts/ session_history.tmux README.md | wc -l)"   # Expected: 0

# (b) Activity/poller sweep WITH TRIAGE:
echo "=== (b) broad grep (EXPECT the 6 sanctioned hits) ==="
grep -rni "activity\|poller\|client_activity\|focused.activity\|pipe-pane\|produce output\|typing.*promot" scripts/ session_history.tmux README.md
echo ""
echo "=== (b) GROUP-A per-token (EACH EXPECT 0) ==="
for t in client_activity focused.activity pipe-pane piped-pane "produce output" 'typing.*promot' alert-activity; do
  printf '%-22s -> %s\n' "$t" "$(grep -rni "$t" scripts/ session_history.tmux README.md | wc -l)"
done
echo ""
echo "=== (b) GROUP-B sanctioned-only ==="
echo "engine 'poller' hits (EXPECT 4, all in migration guard):"
grep -rni "poller" scripts/session_history.sh
echo "'activity' across all three (EXPECT tmux:12 + README:132):"
grep -rni "activity" scripts/ session_history.tmux README.md

# (c) Three-way dwell-default triangulation:
echo "=== (c) 30000 in all three sites ==="
echo "README  : $(grep -c '30000' README.md) hit(s) at $(grep -n '30000' README.md | cut -d: -f1 | tr '\n' ' ')"
echo "engine  : $(grep -c 'echo 30000' scripts/session_history.sh) hit at $(grep -n 'echo 30000' scripts/session_history.sh | cut -d: -f1)"
echo "tmux    : $(grep -c \"dwell-ms' 30000\" session_history.tmux) hit at $(grep -n \"session-history-dwell-ms\" session_history.tmux | cut -d: -f1)"

# (d) Usage subcommand list == PRD §17 (11 commands):
echo "=== (d) Usage string ==="
grep 'Usage: ' scripts/session_history.sh
echo "token count (EXPECT 11): $(grep 'Usage: ' scripts/session_history.sh | grep -o '|' | wc -l) separators => $(($(grep 'Usage: ' scripts/session_history.sh | grep -o '|' | wc -l)+1)) commands"

# (f) README 'How it works' structure:
echo "=== (f) How-it-works promotion causes ==="
echo "'How activity detection works' subsection (EXPECT 0): $(grep -c 'How activity detection works' README.md)"
echo "promotion-cause bullets (EXPECT exactly 2):"
sed -n '/## How it works/,/## Requirements/p' README.md | grep -nE '^\* \*\*select it directly\*\*|^\* \*\*dwell on it\*\*|^- \*\*select it directly\*\*|^- \*\*dwell on it\*\*'
```

### Level 3: Integration / Cross-File Consistency (the sweep's whole point)

```bash
# 3.1 The three-way dwell agreement, shown side by side:
echo "--- README Options row ---";      grep -n 'session-history-dwell-ms' README.md
echo "--- engine dwell_ms() ---";       grep -n 'dwell_ms()' scripts/session_history.sh
echo "--- entry-point set-option ---";  grep -n "session-history-dwell-ms" session_history.tmux
# Expected: README=30000, engine fallback=30000, tmux set-option=30000. All agree.

# 3.2 Relevance model is identical in README, engine header comment, and PRD §6:
echo "--- README promotion bullets ---"
sed -n '/## How it works/,/## Requirements/p' README.md | grep -E 'select it directly|dwell on it|Walking through'
echo "--- engine header 'WHAT MAKES A SESSION RELEVANT' ---"
sed -n '/WHAT MAKES A SESSION/,/promote_tlist is idempotent/p' scripts/session_history.sh
echo "--- PRD §6 (two causes) ---"
sed -n '/## 6\. Relevance/,/## 7\. Toggle/p' PRD.md
# Expected: all three say exactly TWO causes (selection + dwell); "Walking never promotes."

# 3.3 The 11-subcommand surface is identical in the engine Usage and PRD §17:
echo "--- engine Usage ---"; grep 'Usage: ' scripts/session_history.sh
echo "--- PRD §17 table ---"; sed -n '/## 17\. Subcommand/,/## 18\. Testing/p' PRD.md
# Expected: the 11 commands in the Usage string are exactly the 11 rows in PRD §17.

# 3.4 (Optional) render README to eyeball the optional Limitations edit:
command -v pandoc >/dev/null && pandoc README.md -t plain | sed -n '/Limitations/,/License/p' || \
echo "pandoc not installed — eyeball the section on GitHub or in an editor"
```

### Level 4: Domain-Specific — the doc_impact §9 residual-risk closeout

```bash
# doc_impact §9 lists 5 residual risks. This block proves each is RESOLVED.
echo "=== doc_impact §9 closeout ==="
# (1) README↔code dwell drift -> resolved iff all three 30000 & zero 10000:
echo "R1 dwell drift: 10000=$(grep -rn 10000 scripts/ session_history.tmux README.md | wc -l) (EXPECT 0); 30000 sites:"
grep -rn 30000 README.md scripts/session_history.sh session_history.tmux | wc -l   # EXPECT >=3 (one per file)
# (2) README↔PRD §12 alignment -> resolved iff README has the §12 sentence:
echo "R2 §12 sentence in README: $(grep -c 'monitor-activity\|focused session produced output' README.md) (EXPECT >=1)"
# (3) poller subcommand ref -> resolved iff Usage has no activity/poller command:
echo "R3 no poller subcommand: Usage has 'activity'/'poller' as a token? $(grep 'Usage:' scripts/session_history.sh | grep -cE '\b(activity|poller)\b') (EXPECT 0)"
# (4) concurrency 'activity' framing -> resolved iff engine dispatch has no activity/poller case:
echo "R4 no activity/poller case branch: $(grep -cE '^\s+(activity|poller)\)' scripts/session_history.sh) (EXPECT 0)"
# (5) 'one resident process' claim -> resolved iff README/tmux now say no resident process / no monitor-activity:
echo "R5 no-resident-process framing: README 'resident process per pane'=$(grep -c 'resident process per pane' README.md) (EXPECT 1, the §12 sentence); tmux 'no monitor-activity'=$(grep -c 'no monitor-activity' session_history.tmux) (EXPECT 1)"
```

## Final Validation Checklist

### Technical Validation

- [ ] Both bash files parse: `bash -n scripts/session_history.sh` and
      `bash -n session_history.tmux` exit 0.
- [ ] shellcheck introduces no NEW diagnostics (vs. pre-sweep baseline; the only
      likely edit is README prose, which is shellcheck-inert).
- [ ] State-check (Step 1) confirmed every predecessor subtask landed (README 184,
      no `10000`, `30000` present, no "How activity detection works"; tmux 79,
      dwell `30000`, guard present).

### Feature (Consistency) Validation

- [ ] Check (a): `grep -rn "10000"` → **0**.
- [ ] Check (b): GROUP-A per-token greps (`client_activity`, `focused.activity`,
      `pipe-pane`, `piped-pane`, `produce output`, `typing.*promot`,
      `alert-activity`) → **0 each**; GROUP-B (`activity`, `poller`) contain ONLY
      the six Triage-Table sanctioned references; **zero stale defects**.
- [ ] Check (c): `30000` in README Options table + engine `dwell_ms()` + entry-point
      `set-option`; all three agree.
- [ ] Check (d): engine Usage string == PRD §17's 11 commands.
- [ ] Check (f): README "How it works" == exactly two promotion causes; no
      "How activity detection works" subsection.
- [ ] doc_impact §9 residual risks #1–#5 all confirmed RESOLVED (Level 4 block).

### Code Quality / Sweep-Discipline Validation

- [ ] The sweep stayed READ-MOSTLY: the only WRITE (if any) is the OPTIONAL
      check-(e) README Limitations one-liner, or a minimal in-place fix of a
      genuine one-token stale reference.
- [ ] No legitimate reference was wrongly deleted (migration guard intact: grep
      `poller-pid` in engine == 3 lines; tmux line-12 negation intact; README
      line-132 §12 sentence intact).
- [ ] No region owned by another subtask was re-edited (if a structural defect
      was found, it was SURFACED, not rewritten).
- [ ] If check (e) was applied: no broken `SPEC.md` link (used PRD §19 phrasing
      without the cross-reference, or `PRD.md §12`); no curly quotes introduced.

### Documentation & Deployment

- [ ] The one-screen consistency report emitted (per-check PASS/FAIL + triage
      outcome + any fix applied + check-(e) decision).
- [ ] The three files now agree with each other and with PRD §6/§12/§15/§17/§19.
- [ ] No new environment variables, options, hooks, or bindings (verification
      only; the optional Limitations line is prose).

---

## Anti-Patterns to Avoid

- ❌ **Do NOT read check (b)'s "must return ZERO hits" literally and delete the
  migration guard or the §12 sentence.** The broad alternation returns SIX
  sanctioned LEGITIMATE-KEEP hits (Triage Table). Deleting the migration guard
  re-opens system_context.md risk #1 (orphan poller); deleting the §12 sentence
  or the tmux negation contradicts PRD §9/§19. Run the GROUP-A per-token greps
  for the clean "must be zero" signal, and use the Triage Table for the survivors.
- ❌ **Do NOT confuse "produce output" (grep token, present tense) with README's
  "produced output" (past tense, in the §12 KEEP sentence).** They are different
  strings; the latter is correct and stays. `grep -rni "produce output"` → 0.
- ❌ **Do NOT write "(see SPEC.md §12)" in the optional Limitations line.** The
  on-disk spec is `PRD.md` (PRD §20 calls itself "SPEC.md" internally, but the
  file is PRD.md; no SPEC.md exists). That link 404s on GitHub. Omit the
  cross-reference or use "PRD.md §12".
- ❌ **Do NOT re-edit a region owned by another subtask** (How-it-works, Options
  table, Troubleshooting, engine functions, tmux comments). Those regions are
  already final. If you find a structural defect there, SURFACE it (name the
  owning subtask) instead of rewriting it — this is a sweep, not a re-implementation.
- ❌ **Do NOT treat a non-final state-check as a failure to "fix" yourself.** If
  Step 1 shows a predecessor didn't land (e.g. `10000` still in README), do NOT
  apply that predecessor's edit — surface the gap. The sweep fixes only genuine
  *cross-file inconsistencies*, not missed predecessor work.
- ❌ **Do NOT add the check-(e) Limitations line as REQUIRED.** It is OPTIONAL and
  partially redundant (the §12 content is already in How-it-works). The sweep
  PASSES without it. Adding it is a low-priority nicety mirroring PRD §19.
- ❌ **Do NOT introduce curly quotes / smart quotes** anywhere (the README uses
  straight quotes + U+2014 em-dashes only). If you add the Limitations line,
  match the file's typography.
- ❌ **Do NOT gate the engine on a hard line count.** The engine line count
  (currently 537) is informational; content/token greps are authoritative. A
  verification sweep asserts on *content*, not line numbers.

---

## Scope Boundaries (one-screen reference)

| Item | This sweep (M3.T3.S1)? | Owner |
|------|:---:|-------|
| Run checks (a)–(d), (f) and report PASS/FAIL | ✅ | M3.T3.S1 |
| Triage check (b): classify each hit KEEP vs DEFECT | ✅ | M3.T3.S1 |
| Fix a genuine one-token cross-file inconsistency in place | ✅ (if found) | M3.T3.S1 |
| OPTIONAL: add README Limitations one-liner (check e) | ✅ (optional) | M3.T3.S1 |
| Emit the one-screen consistency report | ✅ | M3.T3.S1 |
| Re-implement any predecessor subtask (engine, tmux, README regions) | ❌ | **M1/M2/M3.T1/M3.T2** (surface gaps) |
| Change the `30000` default or any option value | ❌ | already final (M1.T3 / M2.T1 / M3.T2) |
| Edit PRD.md / tasks.json / prd_snapshot.md | ❌ | READ-ONLY (orchestrator/human) |
| Delete the migration guard / §12 sentence / tmux negation | ❌ | KEEP (sanctioned references) |

---

## Confidence Score

**10/10** for one-pass success. This is a read-mostly verification sweep with:
every check expressed as a copy-pasteable deterministic grep with its exact
expected output; the complete Triage Table enumerating all six current check-(b)
hits with file:line/token/verdict/predecessor-authority; the GROUP-A (must-be-0)
vs GROUP-B (sanctioned-only) per-token split that makes the broad grep's signal
unambiguous; the three-way `30000` triangulation with exact file:line for each;
the 11-command Usage list vs PRD §17; the state-check that detects a
predecessor-not-landed gap (with explicit "surface, don't re-implement"
guidance); the `SPEC.md`-naming hazard for the optional check (e) with a safe
resolution; doc_impact §9 mapped 1:1 to the checks (the sweep's reason for
existing); and explicit anti-patterns preventing the two most dangerous mis-fixes
(deleting the migration guard; deleting the §12 sentence). The expected outcome
is all checks PASS with six sanctioned exceptions and zero defects; the only
likely WRITE is the optional Limitations one-liner. No ambiguity remains.