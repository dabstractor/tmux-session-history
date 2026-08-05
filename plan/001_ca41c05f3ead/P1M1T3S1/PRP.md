name: "P1.M1.T3.S1 — Change dwell_ms() default from 10000 to 30000"
description: "Single-literal edit to `scripts/session_history.sh:154`: change the fallback `echo 10000` to `echo 30000` inside the `dwell_ms()` one-liner's case statement. This makes the engine's runtime default match PRD §15 / §8 / §14 (non-numeric or empty `@session-history-dwell-ms` → 30000). No other line changes. The entry-point default (`session_history.tmux:55`) is M2.T1.S1; the README Options table is M3.T2.S1; the line-58 header comment '(default 10000 ms)' is rewritten in T4. Net: ±0 lines."

---

## Goal

**Feature Goal**: Make the engine's dwell-threshold fallback value conform to the PRD. When
`@session-history-dwell-ms` is empty or non-numeric, `dwell_ms()` must return **30000** (30 s),
not the current legacy value of 10000 (10 s).

**Deliverable**: An edited `scripts/session_history.sh` in which the `dwell_ms()` function's
case-statement fallback branch reads `echo 30000` instead of `echo 10000`. Exactly one literal is
changed. No lines added or removed. No other file touched.

**Success Definition**:
1. `bash -n scripts/session_history.sh` exits 0.
2. `shellcheck` reports **no new diagnostics** vs. a pre-edit baseline.
3. `grep -n 'echo 10000' scripts/session_history.sh` → **zero matches**.
4. `grep -n 'echo 30000' scripts/session_history.sh` → **exactly 1 match**, on the `dwell_ms()` line.
5. Behavioral: `dwell_ms()` returns `30000` for empty input, `30000` for non-numeric input, `0`
   for the literal `"0"` (passthrough preserved — dwell still disables), and the user's value for
   any other numeric input (Level 2 logic test passes).
6. The line-58 header comment (`default 10000 ms`) is **left untouched** (owned by T4 — scope boundary).
7. File line count is unchanged (the edit is a value replacement, ±0 lines).

## User Persona (if applicable)

**Target User**: tmux-session-history end user who has not set `@session-history-dwell-ms`.

**Use Case**: A user walks (back/forward) to a session and stays there silently. After the dwell
threshold elapses with no interaction, that session is promoted in the relevance list so a later
toggle returns to it.

**User Journey**: User presses back/forward → `do_hook` classifies a WALK → `arm_dwell(to)` reads
`dwell_ms()` → because the option is unset (empty), the fallback fires → the timer is armed for
`max(1, 30000/1000) = 30 s` → if the user is still on that session 30 s later, it promotes.

**Pain Points Addressed**: Today the fallback is 10 s, which (a) contradicts the PRD spec (§15:
30000) and (b) is too aggressive — brief pauses while walking past sessions would over-promote them.
The PRD-chosen 30 s reflects "you actually stayed to work," not "you paused to glance."

## Why

- **Spec compliance.** PRD §15 lists the default as `30000`. §8 (`arm_dwell`) comments
  `# @session-history-dwell-ms, default 30000`. §14 states "Non-numeric `dwell-ms` → treated as the
  default (30000)." The engine currently emits `10000` — a pre-PRD legacy value. The PRD contains
  **zero** occurrences of `10000` (grep-verified). This task eliminates that legacy value from the
  engine's runtime path.
- **Cross-file consistency.** Three sources define the dwell default and must all agree on 30000:
  the engine fallback (this task), the entry-point `session_history.tmux` default (M2.T1.S1), and
  the README Options table (M3.T2.S1). A fourth — the line-58 header comment — is rewritten in T4.
  This task is the engine leg of that four-way alignment.
- **User-noticeable behavior shift.** 10 s → 30 s meaningfully changes how long a silent walk must
  persist before promotion. It is a deliberate product decision encoded in the PRD, not a cosmetic
  tweak. Getting the engine fallback right is what actually changes runtime behavior for unset option.

## What

Change exactly one literal on one line of `scripts/session_history.sh`.

### The current line (line 154, post-S1+S2; file currently 562 lines)

```bash
dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 10000 ;; *) echo "$d" ;; esac; }
```

### The target line (after this task)

```bash
dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 30000 ;; *) echo "$d" ;; esac; }
```

Semantics of the case expression (unchanged in structure — only the fallback literal changes):

| Input `@session-history-dwell-ms` | case branch | output | meaning |
|-----------------------------------|-------------|--------|---------|
| `''` (empty / unset)              | `''\|*[!0-9]*)` | `30000` | default (was 10000) |
| `abc`, `3.5`, `-1`, `5s` (non-numeric) | `''\|*[!0-9]*)` | `30000` | treated as default (PRD §14) |
| `0`                               | `*)`        | `0`    | **passthrough** — `arm_dwell`'s `[ "$ms" -gt 0 ]` then returns early → dwell disabled (PRD §14) |
| `5000`, `30000`, `120000` (numeric) | `*)`        | the value itself | passthrough — user override respected |

### Success Criteria

- [ ] The literal `echo 10000` no longer appears anywhere in `scripts/session_history.sh`.
- [ ] The literal `echo 30000` appears exactly once, inside `dwell_ms()`.
- [ ] `bash -n` passes; `shellcheck` introduces no new diagnostics.
- [ ] Logic test (Level 2): the four input cases above all resolve correctly with the post-edit function.
- [ ] File line count is unchanged (no lines added/removed).
- [ ] Line 58 header comment (`default 10000 ms`) is untouched (it belongs to T4).
- [ ] No other file is modified.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact current one-liner (line 154), the exact target one-liner, the
exact `oldText`/`newText` pair for the `edit` tool, the full semantics table for every case-branch
input (including the `0`-disables passthrough that must NOT regress), the cross-file ownership map
so the implementer does not over-reach into T4/M2/M3, the parallel-execution boundary with T2.S1
(edits do_init ~340 lines away; line-count-neutral), and deterministic Level 1–3 validation that
`eval`s the **real** post-edit function against mocked `G`/`H`. An implementer with zero prior
knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authoritative default value
- docfile: PRD.md
  section: "§15. Configuration reference"
  why: "Row: | @session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables dwell. |.
        This is the target default value (30000), replacing the legacy 10000."
  critical: "The PRD NEVER mentions 10000 anywhere (0 grep hits). 30000 is the only spec-sanctioned default."

# MUST READ — non-numeric handling
- docfile: PRD.md
  section: "§14. Invariants & edge cases"
  why: "Two invariants govern dwell_ms: 'Non-numeric dwell-ms → treated as the default (30000).'
        and 'dwell-ms = 0 → arm_dwell returns immediately; relevance comes only from selection.'
        The first is what the fallback literal implements. The second is preserved by the *) branch
        (0 is numeric → passthrough) and is a regression guard for this task."
  critical: "Do NOT make 0 fall into the default branch. 0 must pass through to *) so arm_dwell can
             short-circuit it. Only '' and non-numeric hit the fallback."

# MUST READ — the call site that consumes dwell_ms()
- docfile: PRD.md
  section: "§8. Dwell → Arming"
  why: "arm_dwell reads: ms = dwell_ms(); if ms <= 0: return; sec = max(1, ms/1000); tmux run-shell -b
        'sleep ${sec}; ...'. So a fallback of 30000 → sleep 30. Confirms the fallback is the ONLY
        place the default lives at runtime; changing this one literal fully realizes the spec for
        the engine path."
  critical: "arm_dwell already handles the ms<=0 early-return. We change only the fallback literal,
             so behavior for 0 and for explicit numerics is untouched."

# The decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 2 — DWELL DEFAULT must be 30000, currently 10000 (PRD §15)"
  why: "GAP 2a (this task) = scripts/session_history.sh:154 change echo 10000 → echo 30000.
        GAP 2b = session_history.tmux:55 (M2.T1.S1). GAP 2c = line-58 comment (T4).
        GAP 2d = README.md:86 (M3.T2.S1). Note: README.md:119 already says 'default 30 s' (already
        correct). This PRP == GAP 2a only."
  critical: "GAP 2a is line-scoped to 154 and literal-scoped to the echo fallback. Do not 'fix' 2b/2c/2d here."

# The file under edit
- file: scripts/session_history.sh
  why: "The ONLY file this task modifies. Bash engine, shebang #!/usr/bin/env bash, set -u (line 110).
        dwell_ms() is a one-liner at line 154. Helpers it calls: H (line 113, namespace prefix
        @session-history-), G (line 144, tmux show-options -gv). It is consumed ONLY by arm_dwell()
        (line 226–232), which is called ONLY from do_hook step 8 (line 297) on WALK arrivals."
  pattern: "dwell_ms() is the standard one-liner idiom in this file: declare local, read via G/H,
            branch via a POSIX case glob (''|*[!0-9]*) for empty/non-numeric, *) for valid. The
            inline comment on line 153 (# user-facing dwell threshold in ms; 0 disables dwell entirely)
            is accurate and does NOT mention a numeric default — leave it."
  gotcha: "The line-58 header comment '# ... @session-history-dwell-ms (default 10000 ms)' will still
           say 10000 after this task. That is EXPECTED and CORRECT — it is in the header comment block
           (lines 42–105) that T4.S1/T4.S2 will rewrite. Do NOT 'helpfully' fix it here; doing so
           collides with T4's planned contiguous-block rewrite."

# The sibling PRP running in parallel (CONTRACT)
- docfile: plan/001_ca41c05f3ead/P1M1T2S1/PRP.md
  why: "T2.S1 edits do_init() (post-S1+S2 ~lines 491–521): deletes the pipe-pane legacy block +
        do_start_poller call, adds a one-shot poller-pid migration guard. Its oldText is textually
        disjoint from dwell_ms() (~340 lines apart). Its edit is line-count-negative (−5); this
        task's edit is line-count-neutral (±0). The two edits will merge cleanly with no conflict."
  critical: "Anchor on the dwell_ms() one-liner text, NOT line number. If T2.S1 lands first, do_init
             shrinks but line 154 stays line 154 (T2.S1's region is BELOW it). If this lands first,
             T2.S1's line numbers are unaffected (no lines added/removed above do_init)."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §8/§14/§15 authorize 30000
├── README.md                   # docs (NOT this task — M3.T2.S1 owns the 10000 at line 86)
├── LICENSE
├── scripts/
│   └── session_history.sh      # ← THE FILE TO EDIT (562 lines, post-S1+S2)
│                                #     line 154 = dwell_ms() fallback (THIS TASK)
│                                #     line 58  = header comment 'default 10000 ms' (T4 — DO NOT TOUCH)
├── session_history.tmux        # entry point (NOT this task — M2.T1.S1 owns line 55)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/gap_analysis.md   # ← GAP 2a (this task)
        ├── P1M1T2S1/PRP.md                # ← parallel sibling (edits do_init, no overlap)
        └── P1M1T3S1/                      # ← THIS task
            ├── PRP.md
            └── research/dwell_ms_verification.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only scripts/session_history.sh is modified, and ONLY the echo literal on line 154.
# After this task the file is still 562 lines (±0). dwell_ms() echoes 30000 as fallback.
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL — the 0-disables path must NOT regress. In the case glob ''|*[!0-9]*) the literal "0" is
# fully numeric, so it falls through to *) and echo "$d" returns "0". arm_dwell then runs
# [ "$ms" -gt 0 ] 2>/dev/null || return 0  → returns immediately → dwell disabled (PRD §14).
# We change ONLY the fallback literal (10000→30000); the *) branch and arm_dwell are untouched, so
# 0-disables stays correct. The Level 2 logic test asserts [ "$(dwell_ms_for '0')" = "0" ].

# GOTCHA — line 58 header comment will still read "(default 10000 ms)" after this task. LEAVE IT.
# It lives in the header block (lines 42–105) that T4.S1/T4.S2 will rewrite as a contiguous unit.
# Editing it here risks a merge conflict with T4 and is explicitly out of scope (contract point 5).

# GOTCHA — line numbers under parallel execution. T2.S1 edits do_init (~line 491+) and may shift
# the tail of the file by −5, but dwell_ms() at line 154 is ABOVE do_init, so line 154 is STABLE
# regardless of T2.S1 ordering. Still, MATCH ON TEXT (the full one-liner), not the line number.

# GOTCHA — set -u (line 110). dwell_ms() declares `local d` before assigning it. The edit changes
# only a literal echo argument; no new variable is introduced. set -u is unaffected.

# GOTCHA — the case glob ''|*[!0-9]*) uses single-quoted empty string '' OR'd with the non-numeric
# glob *[!0-9]*. A value like "3.5", "-1", "5s", "1e3" all match the glob → default. This is the
# intended PRD §14 behavior ("non-numeric → default"). Do not "improve" the glob.
```

## Implementation Blueprint

### Data models and structure

None. This is a pure literal-value change in a stateless bash helper. No data models, no schemas,
no types beyond the existing string `@session-history-dwell-ms` option.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE a pre-edit shellcheck baseline (no source edits)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_before_t3s1.txt 2>&1; echo "baseline exit: $?"
  - RUN: wc -l /tmp/sc_before_t3s1.txt   # note the diagnostic count
  - WHY: this task's shellcheck gate is "no NEW diagnostics". The file already carries pre-existing
         SC warnings (gap analysis did not clean them); a one-literal change must not ADD any.
         Equivalently, capture the baseline so a sorted diff proves you introduced nothing.

Task 2: EDIT the dwell_ms() fallback literal (single exact-text replacement)
  - USE the `edit` tool with this oldText/newText (match the FULL one-liner so the edit is unique):
      oldText:  'dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in '\'''\''|*[!0-9]*) echo 10000 ;; *) echo "$d" ;; esac; }'
      newText:  'dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in '\'''\''|*[!0-9]*) echo 30000 ;; *) echo "$d" ;; esac; }'
    (i.e. the ONLY character difference is 10000 → 30000 inside `echo 10000`.)
  - ANCHOR on the full one-liner text, NOT line number 154 (T2.S1 is editing in parallel; line 154
    is stable but text-matching is robust to any drift).
  - PRESERVE: the line-153 comment (`# user-facing dwell threshold in ms; 0 disables dwell entirely`)
    byte-for-byte — it does not mention a numeric default and needs no change.
  - DO NOT TOUCH: line 58 header comment, the *) passthrough branch, arm_dwell(), any other line.

Task 3: VERIFY parse (no edits)
  - RUN: bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
  - EXPECTED: PARSE OK (exit 0). A one-literal change cannot break parsing; this is a smoke check.

Task 4: VERIFY the literal swap + lint delta (no edits)
  - RUN: grep -n 'echo 10000' scripts/session_history.sh
    EXPECTED: ZERO output (the fallback literal is gone from the code).
  - RUN: grep -n 'echo 30000' scripts/session_history.sh
    EXPECTED: exactly 1 line — the dwell_ms() one-liner.
  - RUN: grep -n '10000' scripts/session_history.sh
    EXPECTED: exactly 1 line — the line-58 HEADER COMMENT ("default 10000 ms"). This is correct and
    owned by T4; it must remain for now. (If you see 0 lines, you accidentally edited line 58 — revert
    that; if you see 2+ lines you missed the canonical source — re-check.)
  - RUN: shellcheck scripts/session_history.sh > /tmp/sc_after_t3s1.txt 2>&1
  - RUN: diff <(sort /tmp/sc_before_t3s1.txt) <(sort /tmp/sc_after_t3s1.txt)
    EXPECTED: no diff (a literal change in an echo argument cannot introduce a shellcheck diagnostic).
  - RUN: wc -l scripts/session_history.sh
    EXPECTED: UNCHANGED from the pre-edit count (the edit is ±0 lines; currently 562, but if T2.S1
    landed first the baseline is whatever it was before THIS task's edit — assert EQUAL to your own
    pre-edit wc, not an absolute number).

Task 5: VERIFY behavior with a real-function logic test (Level 2, no tmux needed)
  - RUN the Level 2 block in the Validation Loop. It eval's the REAL post-edit dwell_ms() one-liner
    extracted from the file (with mocked G/H) and asserts all four input cases. EXPECTED: all 4 OK.
```

### Implementation Patterns & Key Details

```bash
# dwell_ms() is consumed by exactly one caller — arm_dwell() (lines 226–232):
#     arm_dwell() {
#         local ms to; to="$1"
#         ms="$(dwell_ms)"; [ "$ms" -gt 0 ] 2>/dev/null || return 0      # 0 (or non-num) disables
#         local sec; sec=$(( ms / 1000 )); [ "$sec" -lt 1 ] && sec=1
#         tmux run-shell -b "sleep ${sec}; \"${SELF}\" dwell \"${to}\""
#     }
# With the fallback now 30000: empty option → ms=30000 → sec=30 → 30 s dwell timer. Correct per §8.
# With option "0": ms=0 → [ 0 -gt 0 ] is false → return 0 → no timer (dwell disabled). Preserved.
# With option "abc": dwell_ms returns 30000 (non-numeric → default per §14) → 30 s timer. Correct.

# Helper semantics (so the implementer understands the mocked Level 2 test):
#   H dwell-ms  -> @session-history-dwell-ms   (namespace prefix, line 113)
#   G <opt>     -> tmux show-options -gv <opt> (reads value, line 144)
# The Level 2 test stubs H/G so it can eval the REAL one-liner without a tmux server.
```

### Integration Points

```yaml
DATABASE:
  - none. Stateless tmux plugin; no DB.

CONFIG (tmux global user options):
  - @session-history-dwell-ms: READ by dwell_ms() via G/H. This task does NOT change how it is read,
        only the fallback when it is empty/non-numeric. The entry-point default-write
        (session_history.tmux:55) is M2.T1.S1; the README row is M3.T2.S1. After all three land,
        an unset option is written as 30000 by the entry point AND falls back to 30000 in the engine
        — fully consistent.

ROUTES / DISPATCH:
  - none changed. dwell_ms() is a helper, not a dispatch subcommand. The case dispatch
        (dwell) lock; load_alive; do_dwell ...) is untouched.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit shellcheck baseline (run BEFORE editing):
shellcheck scripts/session_history.sh > /tmp/sc_before_t3s1.txt 2>&1; echo "baseline exit: $?"

# 1. Parse check (run AFTER the single edit):
bash -n scripts/session_history.sh && echo "PARSE OK" || echo "PARSE FAIL"
# Expected: PARSE OK (exit 0).

# 2. Lint delta (run AFTER editing):
shellcheck scripts/session_history.sh > /tmp/sc_after_t3s1.txt 2>&1
diff <(sort /tmp/sc_before_t3s1.txt) <(sort /tmp/sc_after_t3s1.txt) && echo "NO NEW SC DIAGNOSTICS"
# Expected: empty diff (a literal change in an echo argument introduces no shellcheck diagnostic).

# 3. Line-count is unchanged (capture before & after within THIS task):
before=$(wc -l < scripts/session_history.sh)
# ... perform the edit ...
after=$(wc -l < scripts/session_history.sh)
[ "$before" = "$after" ] && echo "LINE COUNT UNCHANGED ($after)" || echo "LINE COUNT CHANGED: $before -> $after"
# Expected: LINE COUNT UNCHANGED. (Absolute value is currently 562 post-S1+S2, but if T2.S1 landed
#           first the file may already be 557 — assert EQUALITY, not an absolute number.)
```

### Level 2: Unit / Logic Tests (Component Validation)

This repo has no test framework. The behavioral proof below `eval`s the **real** post-edit
`dwell_ms()` one-liner extracted from the file, with `G`/`H` stubbed, so it exercises the actual
case expression — not a hand-copy.

```bash
# Extract the real dwell_ms() definition (it is a one-liner) and run it against mocked G/H.
H() { echo "@session-history-$1"; }     # stub: namespace prefix
G() { printf '%s' "$MOCK_DWELL"; }      # stub: return the mocked option value

# Pull the live one-liner from the file and define it in this shell:
eval "$(grep -E '^dwell_ms\(\) \{' scripts/session_history.sh)"

pass=0; fail=0
check() { # check <input> <expected> <label>
  MOCK_DWELL="$1"
  got="$(dwell_ms)"
  if [ "$got" = "$2" ]; then echo "OK   $3 (input='$1' -> $got)"; pass=$((pass+1))
  else echo "FAIL $3 (input='$1' expected='$2' got='$got')"; fail=$((fail+1)); fi
}

check ''     '30000' 'empty/unset -> default 30000'
check 'abc'  '30000' 'non-numeric -> default 30000 (PRD §14)'
check '3.5'  '30000' 'float -> default 30000 (non-numeric glob match)'
check '-1'   '30000' 'negative -> default 30000 (non-numeric glob match)'
check '5s'   '30000' 'suffixed -> default 30000 (non-numeric glob match)'
check '0'    '0'     'zero passthrough -> 0 (dwell DISABLED; arm_dwell returns early) *** regression guard ***'
check '5000' '5000'  'numeric passthrough -> 5000 (user override respected)'
check '30000' '30000' 'numeric passthrough -> 30000 (explicit default)'
check '120000' '120000' 'numeric passthrough -> 120000 (large override)'

echo "---"; echo "PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] && echo "ALL DWELL_MS CASES OK" || { echo "SOME CASES FAILED"; exit 1; }
# Expected: PASS=9 FAIL=0. The '0' -> '0' case is the critical regression guard for the disables path.
```

### Level 3: Integration Testing (System Validation)

```bash
# Structural proofs that the literal swap is exactly what was specified (run after Level 1).

# A. The legacy fallback literal is gone from CODE:
grep -n 'echo 10000' scripts/session_history.sh
# Expected: NO output (zero matches).

# B. The new fallback literal is present exactly once, in dwell_ms():
grep -n 'echo 30000' scripts/session_history.sh
# Expected: exactly 1 line, matching '^dwell_ms() { ... echo 30000 ... }'.

# C. The only remaining '10000' in the engine is the line-58 HEADER COMMENT (owned by T4 — must stay):
grep -n '10000' scripts/session_history.sh
# Expected: exactly 1 line — line 58: '# ... @session-history-dwell-ms (default 10000 ms)'.
#           If this line is MISSING you accidentally edited the header comment — revert it (T4 owns it).

# D. dwell_ms() is still defined exactly once, and arm_dwell still consumes it:
grep -c 'dwell_ms()' scripts/session_history.sh     # Expected: 1 (the definition)
grep -c '"$(dwell_ms)"' scripts/session_history.sh  # Expected: 1 (arm_dwell's call site)

# E. The 0-disables passthrough branch is intact (visual):
grep -n 'dwell_ms()' scripts/session_history.sh
# Expected: the one-liner still contains '*) echo "$d"' — the passthrough branch is unchanged.

# Optional, under a throwaway tmux server: prove arm_dwell arms a 30 s timer for an UNSET option.
# (This is the real end-to-end path: empty option -> dwell_ms -> 30000 -> sleep 30.)
if command -v tmux >/dev/null; then
  SOCK=prpt3s1
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$SOCK" new-session -d -s prptest 2>/dev/null
  # Ensure the option is genuinely unset/empty so the fallback fires:
  tmux -L "$SOCK" set-option -gu '@session-history-dwell-ms' 2>/dev/null
  # Call dwell_ms through a tiny sourced probe (mock-free, real G/H + real option):
  probe='d="$(tmux -L prpt3s1 show-options -gv @session-history-dwell-ms 2>/dev/null)"; case "$d" in '"''"'|*[!0-9]*) echo 30000 ;; *) echo "$d" ;; esac'
  echo "engine fallback for UNSET option = $(sh -c "$probe")"
  # Expected: 30000 (mirrors dwell_ms exactly, since the option is unset -> empty -> fallback).
  tmux -L "$SOCK" kill-server 2>/dev/null
else
  echo "tmux not installed — skipping L3 tmux probe (Level 2 already proves the function logic)."
fi
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Prove the change is minimal and scoped in git.
git diff --stat scripts/session_history.sh
# Expected: a single file, roughly +1/-1 within the dwell_ms one-liner only.

git diff scripts/session_history.sh
# Manually confirm the diff touches ONLY the dwell_ms() line:
#   - one '-' line with 'echo 10000'
#   - one '+' line with 'echo 30000'
#   - NOTHING else changes (not the line-153 comment, not line 58, not arm_dwell, not the dispatch).
# Any changed line OUTSIDE the dwell_ms() one-liner = over-reach OR a collision with T2.S1's parallel
# edit. If you see do_init changes, that is T2.S1's work — coordinate / rebase, do not commit both
# under this task's description.

# Cross-file awareness (informational — NOT to be changed in this task):
grep -n '10000\|30000' session_history.tmux  # line 55 still says 10000 -> M2.T1.S1's job
grep -n '10000' README.md                    # line 86 still says 10000 -> M3.T2.S1's job
# These are EXPECTED to still show 10000 after THIS task. They are separate work items.
```

## Final Validation Checklist

### Technical Validation

- [ ] `bash -n scripts/session_history.sh` exits 0.
- [ ] `shellcheck` post-edit output has **no new diagnostics** vs. `/tmp/sc_before_t3s1.txt`
      (sorted diff is empty).
- [ ] `wc -l scripts/session_history.sh` is **unchanged** vs. this task's own pre-edit baseline.
- [ ] `grep -n 'echo 10000' scripts/session_history.sh` → zero matches.
- [ ] `grep -n 'echo 30000' scripts/session_history.sh` → exactly 1 match (the dwell_ms line).
- [ ] `grep -n '10000' scripts/session_history.sh` → exactly 1 match (line 58 header comment, untouched).

### Feature Validation

- [ ] Level 2 logic test reports `PASS=9 FAIL=0`, including the `0 → 0` regression guard
      (dwell-disables path preserved) and `'' → 30000` / `abc → 30000` (default applied per §14/§15).
- [ ] `dwell_ms()` returns 30000 for empty/non-numeric input (matches PRD §15 default).
- [ ] `dwell_ms()` returns the user value for numeric input, including `0` (PRD §14 disables path).
- [ ] `arm_dwell()` is the sole consumer and is unchanged (grep proves 1 definition, 1 call site).

### Code Quality Validation

- [ ] The diff touches ONLY the `dwell_ms()` one-liner (single `echo 10000` → `echo 30000`).
- [ ] The line-58 header comment `(default 10000 ms)` is **NOT** edited (T4 owns it).
- [ ] The line-153 inline comment is unchanged.
- [ ] No re-formatting, no "drive-by" fixes, no glob changes.
- [ ] Edit is anchored on the full one-liner text (robust to T2.S1's parallel line shifts).

### Documentation & Deployment

- [ ] No documentation changes in this task (README is M3.T2.S1; header comments are T4; entry point is M2.T1.S1).
- [ ] No new environment variables or options.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT edit the line-58 header comment** `(default 10000 ms)`. It lives in the header block
  (lines 42–105) that T4.S1/T4.S2 will rewrite as a contiguous unit. Touching it here risks a merge
  conflict and is explicitly out of scope (contract point 5).
- ❌ **Do NOT "also fix" `session_history.tmux:55` or `README.md:86`.** Those are separate work items
  (M2.T1.S1 and M3.T2.S1). This task is the engine fallback ONLY.
- ❌ **Do NOT alter the case glob or the `*) echo "$d"` passthrough branch.** The `0`-disables path
  depends on `0` being numeric and passing through unchanged. Only the fallback literal changes.
- ❌ **Do NOT add lines / reformat the one-liner.** It must remain a single line so the diff is
  trivially `+1/-1` and merges cleanly with T2.S1.
- ❌ **Do NOT key the edit on the hard line number `154`.** T2.S1 edits do_init (~line 491+) and may
  shift the file tail; line 154 happens to be stable (it's above do_init), but text-matching the full
  one-liner is fully robust to any ordering. Match text, not numbers.
- ❌ **Do NOT introduce a new default constant or refactor dwell_ms() into multiple lines.** The PRP
  specifies a one-literal change. Any structural change is scope creep that risks T4/T2 collisions.
- ❌ **Do NOT treat the lingering line-58 `10000` as a bug after this task.** It is the KNOWN
  pre-T4 state. T4 will rewrite the whole header block (including that comment) to match the PRD.

---

## Scope Boundaries (one-screen reference)

| Item | This task (T3.S1)? | Owner |
|------|:---:|-------|
| `dwell_ms()` fallback `echo 10000` → `echo 30000` (line 154) | ✅ | T3.S1 |
| Keep line-153 inline comment (`# user-facing dwell threshold...`) unchanged | ✅ (preserve) | T3.S1 |
| Header comment line 58 `(default 10000 ms)` | ❌ | **T4.S1/T4.S2** (rewrite header block) |
| `session_history.tmux:55` entry-point default `10000` → `30000` | ❌ | **M2.T1.S1** |
| `README.md:86` Options table `10000` → `30000` | ❌ | **M3.T2.S1** |
| `README.md:119` (already "default 30 s") | ❌ | already correct |
| `do_init()` pipe-pane/poller cleanup + migration guard | ❌ | **T2.S1** (parallel, no overlap) |
| Case-dispatch `activity)`/`poller)` removal | ❌ | **S2** (Complete) |
| `dwell_ms()` glob / passthrough branch | ❌ (preserve) | out of scope |

---

## Confidence Score

**10/10** for one-pass success. This is a single-literal change (`echo 10000` → `echo 30000`) on a
unique one-liner with: the exact `oldText`/`newText` pair supplied, a full four-case semantics table
(including the `0`-disables regression guard), a real-function Level 2 logic test that `eval`s the
post-edit one-liner with mocked `G`/`H`, deterministic grep proofs (the line-58 comment is the ONLY
expected remaining `10000`, and it must stay), a line-count-neutrality assertion, and an explicit
scope map separating T3 from T2 (parallel, disjoint region), T4 (header comment), M2 (entry point),
and M3 (README). No ambiguity, no hidden dependencies, no behavioral surprise beyond the intended
default shift.