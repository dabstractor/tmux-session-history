name: "P1.M3.T2.S1 — Update dwell-ms row in README Options table (10000 → 30000, rewrite description to selection+dwell-only)"
description: "Single-table-row exact-text replacement in README.md line 86 (Options table): change the `@session-history-dwell-ms` default cell from `10000` to `30000` and rewrite the Purpose cell from the activity-poller-presupposing text ('Fallback for *silent* presence … without typing/interacting … Working there (typing, switching panes, any tmux command) promotes it immediately regardless … or interacting with it') to the selection+dwell-only model from plan/001_ca41c05f3ead/architecture/doc_impact.md §4: 'How long you must stay on a session you *walked* to (back/forward) before it counts as relevant. This is the only way a walked-to session becomes a toggle target besides re-selecting it. `0` disables dwell — relevance then comes only from selecting a session (toggle, pick, tmux-sessionx, or a manual switch).' Executed as ONE atomic exact-text replacement (oldText = the single line-86 row; newText = the rewritten single row). Net Δ0 lines (README 184 → 184; one row in, one row out). Quote style is ALL STRAIGHT (0 curly quotes in the file). One U+2014 em-dash in the newText. Typography preserved: `*walked*` emphasis and `` `0` `` backticks match the file's existing row style. This IS the doc update (Mode A — README Options table row directly touched by the dwell-default/description change). Siblings T1.S1 + T1.S2 have ALREADY LANDED (README is 184 lines, 'How it works' already dwell-only); T2.S2 owns Troubleshooting (~line 172-176) and is disjoint. Anchor on TEXT (the row's 'Fallback for *silent* presence' opening is globally unique), never line numbers."

---

## Goal

**Feature Goal**: Bring the README **Options table**'s `@session-history-dwell-ms`
row into alignment with (a) the PRD default of `30000` (PRD §15 / §3.4 / §8) and
(b) the selection+dwell-only relevance model (PRD §6) — by changing the default
cell from `` `10000` `` to `` `30000` `` and rewriting the Purpose cell so it
contains **zero** activity-poller presuppositions ("Fallback for *silent*
presence", "without typing/interacting", "Working there promotes it immediately",
"or interacting with it") and instead states dwell is the only way a walked-to
session becomes a toggle target besides re-selecting it.

**Deliverable**: An edited `README.md` in which the single Options-table row for
`@session-history-dwell-ms` reads exactly as the newText in the "What" section:
default `` `30000` ``, and a Purpose cell matching the selection+dwell-only
model. Everything else in README.md (all other Options rows, the already-landed
S1/S2 "How it works" text, Troubleshooting, etc.) is byte-identical.

**Success Definition**:
1. README.md contains **zero** occurrences of `` `10000` `` (the only `10000` in
   the file was this row's default cell).
2. README.md contains **exactly one** occurrence of `` `30000` `` (the new
   default cell) — wait: also confirm it is the Options-table default, not a stray.
3. The dwell-ms row contains **none** of: `Fallback for *silent* presence`,
   `without typing/interacting`, `promotes it immediately regardless`,
   `or interacting with it`.
4. The dwell-ms row **does** contain: `the only way a walked-to session becomes a
   toggle target besides re-selecting it` and `` `0` disables dwell `` and the
   selection enumeration `(toggle, pick, tmux-sessionx, or a manual switch)`.
5. `README.md` is **184** lines (unchanged — one row replaced by one row).
6. The row still parses as a 3-column markdown table row (5 `|`-split fields).

## User Persona (if applicable)

**Target User**: A plugin user (tmux power-user) reading the README **Options**
table to learn the `@session-history-dwell-ms` default and *what dwell actually
does*.

**Use Case**: The user has bound the toggle key, sees sessions they walked to not
becoming toggle targets, and looks up `@session-history-dwell-ms` in the Options
table to understand the threshold and the `0` escape hatch.

**User Journey**: User opens README → scrolls to `## Options` → reads the
`@session-history-dwell-ms` row. Today that row says `10000` and frames dwell as
a "Fallback for silent presence" because "Working there (typing, switching panes,
any tmux command) promotes it immediately regardless" — a claim that presupposes
the activity poller the engine **no longer has** (removed in P1.M1). The user
who trusts it expects typing to promote a walked-to session immediately and is
confused when it does not. After this edit the row tells the truth: dwell is the
*only* way a walked-to session becomes a toggle target besides re-selecting it.

**Pain Points Addressed**: Today the Options table row (a) advertises a stale
`10000` default that contradicts both the PRD (`30000`) and the README's own "How
it works" body (which already says "default 30 s"), and (b) describes an
activity-promotion path that no longer exists. The rewrite fixes both: `30000`
default + the selection+dwell-only model, making the Options table consistent
with the rest of the README and with the engine.

## Why

- **Spec compliance — default (PRD §15 / §3.4 / §8).** The PRD's configuration
  reference lists `@session-history-dwell-ms` default `30000`; §8's `dwell_ms()`
  pseudocode defaults to 30000. The README's `10000` is a stale leftover.
- **Spec compliance — relevance model (PRD §6 / §2).** PRD §6 lists exactly two
  promotion causes: direct selection and dwell. PRD §2's key invariant: "Walking
  moves the history cursor but never touches the relevance list. Selecting or
  dwelling promotes." The current row's "Working there … promotes it
  immediately" describes a **third** cause the PRD does not have; the rewrite
  states dwell is the only walked-to promotion path besides re-selecting.
- **Internal consistency (doc_impact §1a / GAP 2d).** The README is internally
  inconsistent today: the Options table (line 86) says `10000` while the "How it
  works" body (now post-S1/S2) says "default 30 s". Fixing line 86 reconciles
  them. doc_impact §1a flags this as **High severity (factual, user-facing
  default)**.
- **Code-state alignment (CONTRACT).** The engine default is already `30000`
  (`scripts/session_history.sh` `dwell_ms()` — P1.M1.T3.S1 Complete) and the entry
  point is already `30000` (`session_history.tmux:55` — P1.M2.T1.S1 Complete).
  The README is the last place still saying `10000`; without this edit the docs
  **lie** about the default (doc_impact §9.1, HIGH README↔code drift risk).
- **Decomposition ownership (GAP 9a).** This is exactly GAP 9a of
  `architecture/gap_analysis.md`: "README options table `| @session-history-dwell-ms | 10000 |`
  + long description citing 'typing/interacting promotes it immediately' → default
  → 30000; rewrite description to selection+dwell only." Sibling T1.S1 (GAP 9b/9c)
  and T1.S2 (GAP 9d/9e) are **DONE**; T2.S2 (GAP 9f, Troubleshooting) is disjoint
  and still planned.
- **Mode A documentation.** This **is** the doc update for the Options-table row
  — a user-facing README cell directly touched by the dwell-default/description
  change. No separate docs subtask.

## What

A single exact-text replacement of **one** markdown table row in `README.md`.
The row is in the Options table (the `## Options` block), and **anchor on the
row's text, not a line number** — see Gotchas.

> ⚠️ **CURRENT-STATE / IDEMPOTENCY NOTE (read first).** This PRP is written to
> be correct **whether or not the change has already been applied** (parallel
> agents may have landed it). The on-disk state at PRP-authoring time shifted
> mid-session: at first read the row showed `10000` + "Fallback for *silent*
> presence"; by the time the PRP was finalized, a parallel agent had committed
> the exact target change (`git log` shows commit
> `9d01bb9 Update README Options table dwell-ms default to 30000`). **Either
> state is a valid input.** Task 1 below DETECTS which state the file is in:
>
> - **State A — NOT yet applied** (the row still has `10000` + "Fallback for
>   *silent* presence"): perform the Task 2 edit, then run the Task 3-5 proofs.
> - **State B — ALREADY applied** (the row already has `30000` + "the only way
>   a walked-to session becomes a toggle target"): the Task 2 edit is a
>   **no-op** (oldText not present); SKIP the edit and go straight to Task 3-5,
>   which verify the already-applied row matches this PRP's newText exactly. If
>   it matches, the work is DONE — report success. Do NOT re-edit.
>
> In both states the file is **184** lines (S1+S2 landed: the "How it works"
> section reads dwell-only with the §12 sentence; no `**How activity detection
> works.**` heading). Task 1's probes branch on the row text, never on a line
> number.

### The row being replaced (oldText — one line)

```markdown
| `@session-history-dwell-ms` | `10000` | Fallback for *silent* presence: how long you must stay on a session you *walked* to (back/forward) without typing/interacting before it counts as relevant. Working there (typing, switching panes, any tmux command) promotes it immediately regardless. `0` disables dwell (relevance then comes only from selecting a session or interacting with it). |
```

- Opening anchor (globally unique, `grep -c` = 1): `Fallback for *silent* presence`.
- Closing anchor: the row's final ` |` after `interacting with it).`.
- It is a single markdown table row (3 cells: option / default / purpose),
  bounded by leading and trailing `|`. Replacing it keeps the table intact.

### The replacement (newText — one line, from doc_impact.md §4)

```markdown
| `@session-history-dwell-ms` | `30000` | How long you must stay on a session you *walked* to (back/forward) before it counts as relevant. This is the only way a walked-to session becomes a toggle target besides re-selecting it. `0` disables dwell — relevance then comes only from selecting a session (toggle, pick, tmux-sessionx, or a manual switch). |
```

- Sourced verbatim from `architecture/doc_impact.md` §4, which is the curated,
  PRD-aligned target text (the same doc S2 treated as authoritative for its
  region). Preserves the file's existing `*walked*` emphasis and `` `0` ``
  backticks; introduces **one** U+2014 em-dash (`—`) before "relevance then
  comes only", matching the file's 14 existing em-dashes.

### What the newText says (clause-by-clause → PRD authority)

- **`` `30000` `` default** → PRD §15 (`@session-history-dwell-ms` `30000`),
  PRD §3.4 config table, PRD §8 (`dwell_ms()` default 30000). Replaces `` `10000` ``.
- **"How long you must stay on a session you *walked* to (back/forward) before it
  counts as relevant"** → PRD §8 (dwell = the walk-dwell threshold) + PRD §2 key
  invariant (dwelling on a walked-to session promotes in the relevance list).
- **"This is the only way a walked-to session becomes a toggle target besides
  re-selecting it"** → PRD §6 (exactly two promotion causes: selection + dwell;
  walking never promotes). Replaces the deleted "Working there promotes it
  immediately regardless".
- **"`` `0` `` disables dwell — relevance then comes only from selecting a
  session (toggle, pick, tmux-sessionx, or a manual switch)"** → PRD §8 arming
  (`if ms <= 0: return`; "0 disables dwell entirely") + PRD §6 selection causes.
  Replaces the old "relevance then comes only from selecting a session or
  interacting with it" (the "interacting with it" was an activity reference).

### Task-description wording vs doc_impact §4 (resolution — no ambiguity)

The orchestrator task description paraphrases the description in plain text
("you walked to" / "0 disables dwell" without the asterisks/backticks).
`doc_impact.md` §4 gives the markdown-formatted version (`*walked*` /
`` `0` ``). They are **substance-identical**. **Use the doc_impact §4 version**
(newText above): it preserves the README's existing typography (`*walked*`
emphasis, `` `0` `` backticks — both already present in the current row and
mirrored in S1's already-landed "How it works" dwell bullet), keeping the
Options row visually consistent with the rest of the file.

### What is NOT changed (byte-identical, preserved)

- All other Options-table rows: `@session-history-toggle-key`, `back-key`,
  `forward-key`, `pick-key`, `popup` — KEEP (their `(empty)` / `on` defaults and
  text are unaffected).
- The Options-table header rows (lines 80-83: `## Options`, the
  `| Option | Default | Purpose |` + `|---|---|---|` lines) — KEEP.
- The already-landed S1/S2 "How it works" text (timeline paragraph, relevance-list
  paragraph, the two promotion bullets, the Walking paragraph, the dwell-only
  async paragraph, the §12 sentence, close-current, sessionx-composition, capping)
  — KEEP. None of it is in the Options table.
- Troubleshooting (~line 172-176) — KEEP; that is **T2.S2's** scope.
- Everything else (title, intro, Why, Features, Install, Keys, Requirements,
  Limitations, License).

### Success Criteria

- [ ] `grep -c '`10000`' README.md` → **0** (the only 10000 was this row).
- [ ] `grep -c '`30000`' README.md` → **1** (the new default cell).
- [ ] The dwell-ms row contains none of `Fallback for *silent* presence`,
      `without typing/interacting`, `promotes it immediately regardless`,
      `or interacting with it`.
- [ ] The dwell-ms row contains `the only way a walked-to session becomes a
      toggle target besides re-selecting it` and `` `0` disables dwell `` and
      `(toggle, pick, tmux-sessionx, or a manual switch)`.
- [ ] `wc -l README.md` → **184** (unchanged; one row in, one row out).
- [ ] Row still parses as a 3-column table row (`sed -n '<rowline>p' README.md |
      awk -F'|' '{print NF}'` → 5).

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact one-line oldText (the current line-86 row,
captured byte-accurately via `cat -A`, including the `*walked*` emphasis and
`` `0` `` / `` `10000` `` backticks) and the exact one-line newText (verbatim
from `doc_impact.md` §4); the precise scope (the Options table dwell-ms row only
— disjoint from every sibling region); input-state confirmation that S1+S2 have
landed (README is 184 lines, "How it works" already dwell-only); the
text-anchor strategy (the row's `Fallback for *silent* presence` opening is
globally unique, so the replacement is unambiguous regardless of line shifts
from parallel siblings); the deterministic grep proofs; and the companion
code-status confirmation that the engine/entry-point defaults are already 30000
(so this edit does not introduce README↔code drift). An implementer with zero
prior knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the exact target newText for the row
- docfile: plan/001_ca41c05f3ead/architecture/doc_impact.md
  section: "§4. Options table — @session-history-dwell-ms row AFTER the refactor"
  why: "§4 gives the EXACT target row text this PRP adopts verbatim (the
        'How long you must stay on a session you *walked* to …' version with
        `30000` default). §1a flags the current row as High severity
        ('presupposes the activity poller … must be rewritten'). §9.1 flags the
        README↔code drift risk if 10000 lingers."
  critical: "Use §4's text verbatim. §1a enumerates the exact phrases to DROP:
             'fallback', 'typing/interacting', 'Working there (typing, switching
             panes, any tmux command) promotes it immediately regardless', and
             'interacting with it'. Do not retain any of them."

# MUST READ — the decomposition that scoped this exact row
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 2d (README.md:86 default) and GAP 9a (Options table row rewrite)"
  why: "GAP 2d: 'README.md:86 options table default | 10000 | → change to 30000.'
        GAP 9a: 'options table | @session-history-dwell-ms | 10000 | + long
        description citing \"typing/interacting promotes it immediately\" →
        default → 30000; rewrite description to selection+dwell only (drop the
        \"working there promotes immediately\" activity claim).' This PRP ==
        GAP 2d + 9a. Note: GAP 2d's companion code rows 2a/2b/2c are OUT of
        README scope and already Complete (engine + entry point at 30000)."
  critical: "GAP 9b/9c (promotion bullets + Walking paragraph) = T1.S1 (DONE).
             GAP 9d/9e (activity-detection subsection + async paragraph) = T1.S2
             (DONE). GAP 9f (Troubleshooting ~187-189) = T2.S2. This task touches
             ONLY the Options-table dwell-ms row (line 86)."

# MUST READ — the default value authority
- docfile: PRD.md
  section: "§15. Configuration reference (and §3.4 Configuration user-facing table)"
  why: "PRD §15 lists `@session-history-dwell-ms` | `30000` | 'Walk-dwell
        threshold; `0` disables dwell.' §3.4 user-facing table: `30000` |
        'Dwell threshold in ms. `0` disables dwell.' Both pin the 30000 default
        and the `0`-disables-dwell semantics the row must advertise."
  critical: "The PRD NEVER mentions 10000 (verified: 0 hits in PRD.md). 30000 is
             the source-of-truth default. The README row must say 30000, not 10000."

# MUST READ — the relevance model authority (selection + dwell only)
- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't (and §2 Key invariant)"
  why: "PRD §6: a session is promoted by exactly two causes — (1) direct
        selection, (2) dwell. PRD §2 key invariant: 'Walking moves the history
        cursor but never touches the relevance list. Selecting or dwelling
        promotes in the relevance list.' The row's 'only way a walked-to session
        becomes a toggle target besides re-selecting it' encodes this."
  critical: "There is NO third 'typing/interacting promotes immediately' cause.
             That clause (from the old row) presupposes the removed activity
             poller. The rewrite drops it entirely."

# MUST READ — dwell arming & the 0-disables semantics
- docfile: PRD.md
  section: "§8. Dwell — Arming (and h3.8)"
  why: "PRD §8 arm_dwell: 'ms = dwell_ms() # @session-history-dwell-ms, default
        30000; if ms <= 0: return  # 0 disables dwell entirely.' The row's
        '`0` disables dwell — relevance then comes only from selecting a session'
        is the user-facing version of the `if ms <= 0: return` guard."
  critical: "Only a WALK arrival arms a dwell timer (§8 / §5 step 8). The row's
             'you walked to (back/forward)' framing is correct — do NOT generalize
             it to navigations/toggles (those already promote immediately by
             selection)."

# The file under edit
- file: README.md
  why: "The ONLY file this task modifies. GitHub-flavored Markdown, UTF-8.
        QUOTES ARE ALL STRAIGHT: 0 curly single (U+2018/U+2019) and 0 curly double
        (U+201C/U+201D) in the whole file (verified); apostrophes are U+0027.
        Em-dashes are U+2014 (14 in the file). The current dwell-ms row (line 86)
        is the ONLY `10000` in the file and opens with the globally-unique
        'Fallback for *silent* presence'. It uses the file's existing typography:
        `*walked*` emphasis and `0`/`10000` in backticks."
  pattern: "The Options table is a 3-column markdown table (| Option | Default |
            Purpose |). Each option gets one row, one line. Inline code for option
            names and values (backticks); *emphasis* for contrast words. The
            newText FOLLOWS this style exactly — same 3 cells, backticked default,
            `*walked*` emphasis, backticked `0`, one em-dash aside."
  gotcha: "Em-dashes are UTF-8 U+2014 (bytes E2 80 94). The newText has ONE em-dash
           ('`0` disables dwell — relevance then comes only'). Use U+2014, NOT
           '--' or ASCII '-'. Quotes: straight only. The newText's `*walked*`
           and `` `0` `` are NOT optional — they match the file's existing row
           typography and keep the Options table internally consistent."

# The byte-accurate capture (source of truth for oldText/newText fidelity)
- docfile: plan/001_ca41c05f3ead/P1M3T2S1/research/row_byte_capture.md
  why: "This research note captures the exact byte-accurate old row (cat -A
        verified), the quote/em-dash style proof, the typography preservation
        rationale (`*walked*` / `` `0` ``), the line-count math (Δ0; 184 → 184),
        the disjoint-from-siblings boundary table, the task-description-vs-
        doc_impact wording resolution, and the deterministic grep proofs."
  critical: "The edit is ONE atomic replacement of one table row. Do NOT split
             it into 'change default' + 'rewrite description' edits — a single
             oldText→newText row replacement is atomic, unambiguous (unique text
             anchor), and yields a clean single-hunk git diff with Δ0 lines."

# The sibling README tasks (CONTRACTS — all disjoint regions)
- docfile: plan/001_ca41c05f3ead/P1M3T1S1/PRP.md
  why: "T1.S1 owns the 'How it works' promotion bullets + Walking paragraph
        (DONE — already landed; the README 'How it works' already reads
        selection+dwell). Its region is BELOW the Options table and does not
        touch line 86."
  critical: "Do NOT re-edit T1.S1's region. T1.S1 is done."
- docfile: plan/001_ca41c05f3ead/P1M3T1S2/PRP.md
  why: "T1.S2 owns the 'How it works' async-paths paragraph + §12 sentence
        (DONE — README is 184 lines, the §12 sentence is present, no 'How
        activity detection works' heading remains). Its region is BELOW the
        Options table and does not touch line 86. Because S2 already landed, the
        current on-disk README (184 lines) is this task's actual input."
  critical: "Do NOT re-edit T1.S2's region. T1.S2 is done. If `wc -l README.md`
             is NOT 184 or `grep -c 'How activity detection works' README.md` is
             NOT 0, S2 may not have landed — STOP and surface the discrepancy
             instead of editing."

# The code state this doc aligns to (CONTRACTS — already Complete)
- file: scripts/session_history.sh
  why: "P1.M1.T3.S1 changed `dwell_ms()` default 10000 → 30000 (Complete). The
        README row must say 30000 to match the engine default or the docs lie
        (doc_impact §9.1 HIGH risk)."
  critical: "This PRP does NOT edit the engine. The engine default is already
             30000. No code change is needed for this doc edit to be accurate —
             only the README row is stale."
- file: session_history.tmux
  why: "P1.M2.T1.S1 changed the entry-point `set-option -g
        '@session-history-dwell-ms'` default 10000 → 30000 (Complete). Same
        drift rationale as the engine."
  critical: "This PRP does NOT edit the entry point. The entry-point default is
             already 30000."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §15/§3.4/§8/§6 authorize this edit
├── README.md                   # ← THE FILE TO EDIT (184 lines, post-S1/S2)
│                                #     line 80 = "## Options"
│                                #     line 81 = blank
│                                #     line 82 = "| Option | Default | Purpose |"
│                                #     line 83 = "|---|---|---|"
│                                #     lines 84-86 = toggle/back/forward/pick/dwell rows
│                                #     line 86 = `@session-history-dwell-ms` row (THE EDIT)
│                                #     line 87 = `@session-history-popup` row (KEEP)
│                                #     line 88 = blank, line 89 = "## How it works"
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — dwell_ms() default ALREADY 30000 (P1.M1.T3.S1 done)
├── session_history.tmux        # entry point — dwell default ALREADY 30000 (P1.M2.T1.S1 done)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/doc_impact.md      # ← §4 = the exact newText; §1a = phrases to drop
        ├── architecture/gap_analysis.md    # ← GAP 2d (default) + 9a (row rewrite)
        ├── prd_snapshot.md                 # full PRD (READ-ONLY)
        ├── P1M3T1S1/PRP.md                 # ← sibling, DONE (promotion bullets)
        ├── P1M3T1S2/PRP.md                 # ← sibling, DONE (async-paths + §12 sentence)
        └── P1M3T2S1/
            ├── PRP.md                      # ← THIS task
            └── research/row_byte_capture.md   # byte-accurate old row + scope boundary + proofs
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only README.md is modified.
# After this task the file is STILL 184 lines (one table row replaced by one table
# row; Δ0). The single change:
#   - line 86 default cell:  `10000`  →  `30000`
#   - line 86 Purpose cell:  rewritten to the selection+dwell-only model (see "What")
# All other lines byte-identical. The Options table still has exactly 6 option rows
# + header; "How it works", Troubleshooting, etc. are untouched.
```

### Known Gotchas of our codebase & Library Quirks

```markdown
<!-- CRITICAL — S1 AND S2 have ALREADY LANDED. The input is the 184-line README,
     with "How it works" already reading dwell-only. Verify before editing:
     `wc -l README.md` → 184; `grep -c 'How activity detection works' README.md`
     → 0. If you see 192 lines or the heading is still present, S1/S2 have NOT
     both landed — STOP and surface the discrepancy (do not edit). -->

<!-- CRITICAL — the row is the ONLY 10000 in the file. Verify before editing:
     `grep -c '10000' README.md` → 1. After editing it must be 0. This is the
     single deterministic proof the default changed. -->

<!-- CRITICAL — anchor on TEXT, never line numbers. The row opens with
     'Fallback for *silent* presence' which is globally unique
     (`grep -c 'Fallback for \*silent\* presence' README.md` → 1). Use the full
     oldText line for the replacement; do NOT key on "line 86". (T2.S2 edits
     Troubleshooting ~line 172-176 in parallel; even if it changes line counts
     below 86, line 86 itself is unaffected because T2.S1 is one row in / one
     row out. But the text anchor is robust regardless.) -->

<!-- CRITICAL — execute as ONE combined edit (not two). The row is a single line.
     A single oldText→newText row replacement is atomic, unambiguous (unique
     anchor), and yields Δ0 lines and a clean single-hunk git diff. Splitting
     into "change default cell" + "rewrite description" would risk a malformed
     half-row. -->

<!-- CRITICAL — quotes are ALL STRAIGHT. The whole file has 0 curly quotes
     (verified). The newText has no apostrophes (the description uses no
     contractions) and no double-quotes; it has one em-dash. Do NOT introduce
     curly quotes (a common editor "smart quote" auto-correct). -->

<!-- CRITICAL — the em-dash is UTF-8 U+2014 (bytes E2 80 94; cat -A shows
     M-bM-^@M-^T). The newText has ONE em-dash: "`0` disables dwell — relevance
     then comes only". Use U+2014, NOT '--' or ASCII '-'. -->

<!-- GOTCHA — preserve the file's typography: `*walked*` (asterisk emphasis) and
     `` `0` `` / `` `30000` `` (backticks). The current row already uses both;
     S1's already-landed "How it works" dwell bullet also uses `*walked*`. The
     newText keeps them so the Options row is visually consistent. Do NOT drop
     the asterisks or backticks. (The orchestrator task description paraphrases
     the wording without the markdown markers; doc_impact §4 — the canonical
     design text — keeps them. Use doc_impact §4 verbatim.) -->

<!-- GOTCHA — the selection enumeration "(toggle, pick, tmux-sessionx, or a
     manual switch)" mirrors S1's already-landed promotion bullet ("via toggle,
     pick, tmux-sessionx, or a manual `switch-client`"). 'tmux-sessionx' (4×)
     and 'switch-client' (3×) already appear in the README — consistent
     vocabulary. Keep 'switch' lowercase and un-backticked here as in the
     doc_impact §4 canonical text (it reads as prose, not a literal command
     token, matching the row's informal tone). -->

<!-- GOTCHA — do NOT touch any other Options row, the table header, or any line
     outside line 86. The oldText is EXACTLY the dwell-ms row (from its leading
     `|` to its trailing ` |`). The row above (`@session-history-pick-key`) and
     the row below (`@session-history-popup`) are KEEP. -->

<!-- GOTCHA — no test framework / markdown linter is wired into this repo's CI.
     Validation uses grep proofs (the deterministic 10000→0 / 30000→1 default
     change, the banned-phrase removals scoped to the row, the required-phrase
     presences), a table-row structure sanity check (`awk -F'|' '{print NF}'`
     → 5), a line-count assertion (184 → 184), and a git-diff review confirming
     a single one-line hunk. If `markdownlint` or `mdl` is installed, run it as
     a bonus; absence is not a failure. -->
```

## Implementation Blueprint

### Data models and structure

None. This is a pure prose edit (change one default cell + rewrite one Purpose
cell) in a single user-facing Markdown table row. No data models, no schemas, no
code, no options, no hooks, no dispatch. The `@session-history-dwell-ms` option
name is referenced verbatim (unchanged); `30000` and `0` are the only literal
values in the newText.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: DETECT input state (no source edits) — IDEMPOTENT, branches A vs B
  - RUN: wc -l README.md                                   # EXPECT 184 either way (S1+S2 landed)
  - RUN: grep -c 'How activity detection works' README.md  # EXPECT 0 either way (S2 landed)
  - RUN: old_present=$(grep -c 'Fallback for \*silent\* presence' README.md)   # 1=State A, 0=State B
  - RUN: new_present=$(grep -c 'the only way a walked-to session becomes a toggle target besides re-selecting it' README.md)  # 0=State A, 1=State B
  - RUN: grep -n 'Fallback for \*silent\* presence\|the only way a walked-to session' README.md  # locate the dwell-ms row by TEXT
  - WHY: branch on the row's TEXT, not a line number. Exactly one of {old_present,
         new_present} should be 1 (the row is either the pre- or post-edit version).
         - State A (old_present=1, new_present=0): proceed to Task 2 (the edit).
         - State B (old_present=0, new_present=1): SKIP Task 2 — change is already applied;
           go straight to Task 3 (it will verify the applied row == this PRP's newText).
  - RUN: sed -n '/@session-history-dwell-ms/p' README.md | head -1 | cat -A   # eyeball the actual row bytes
  - STOP-AND-SURFACE only if: wc -l != 184; the heading is still present (S2 not landed);
    BOTH old_present and new_present are 0 (the row is in some third/unexpected state);
    or BOTH are 1 (the row appears twice — a merge accident). Those are real discrepancies.
    A clean State A or State B is NOT a discrepancy — proceed.
  - RUN (snapshot for regression, State A only): sed -n '/^\| `@session-history-pick-key`/,/^\| `@session-history-popup`/p' README.md > /tmp/region_before_m3t2s1.txt
         # Captures the Options-table rows from pick-key through popup, inclusive. Regression
         # guard: proves the pick-key row above and popup row below are byte-identical pre/post.
         # (Anchored on row text, not line 84-88, so it survives line shifts.)

Task 2: PERFORM the single exact-text row replacement (the edit) — SKIP if Task 1 found State B
  - GUARD: if Task 1 reported State B (new_present=1), SKIP this task entirely — the
    change is already applied. Go to Task 3 to verify it matches this PRP's newText.
    Do NOT attempt the edit (oldText is absent; the `edit` tool would fail to match).
  - USE the `edit` tool with the oldText/newText in the "What" section above. The
    oldText is the EXACT bytes of the dwell-ms row (one line, from leading `|` to
    trailing ` |`). The newText is the rewritten row (30000 default + selection+dwell
    description). Match the U+2014 em-dash exactly; use STRAIGHT quotes; keep
    `*walked*` emphasis and `0`/`30000` backticks.
  - ANCHOR on the full text (opening anchor 'Fallback for *silent* presence' is
    globally unique; the whole oldText row is unique); do NOT key on a line number.
  - PRESERVE byte-for-byte: the pick-key row above, the popup row below, the table
    header rows, and every row outside the dwell-ms row.
  - DO NOT TOUCH: any other Options row, the table header, the "How it works"
    section (S1/S2, done), Troubleshooting (~line 172-176, T2.S2's scope),
    Requirements, Limitations, License.

Task 3: VERIFY default change + line count + table structure (no edits)
  - RUN: after=$(wc -l < README.md); echo "lines = $after"
    EXPECTED: 184 in BOTH State A (post-edit) and State B (no edit). Any other count =
              wrong edit scope (you accidentally added/removed a line) — revert.
  - RUN: grep -c '`10000`' README.md   # EXPECTED: 0  (the only 10000 was this row)
  - RUN: grep -c '`30000`' README.md   # EXPECTED: 1  (the new default cell)
  - RUN: grep -n '`30000`' README.md   # confirm it is on the dwell-ms row, not a stray
  - RUN: grep '@session-history-dwell-ms' README.md | head -1 | awk -F'|' '{print NF}'
    EXPECTED: 5 (leading empty + trailing empty + 3 cells = a well-formed 3-column row).
    # (Text-anchored: greps the dwell-ms row itself, not 'line 86', so it survives shifts.)
  - RUN: grep '@session-history-dwell-ms' README.md | head -1 | cat -A   # eyeball: `30000`, `*walked*`, `0`, one em-dash (—)

Task 4: VERIFY phrase removal + required phrases on the row (no edits)
  - RUN: grep -c 'Fallback for \*silent\* presence' README.md                # EXPECTED: 0
  - RUN: grep -c 'without typing/interacting' README.md                      # EXPECTED: 0
  - RUN: grep -c 'promotes it immediately regardless' README.md              # EXPECTED: 0
  - RUN: grep -c 'or interacting with it' README.md                          # EXPECTED: 0
  - RUN: grep -c 'the only way a walked-to session becomes a toggle target besides re-selecting it' README.md
    # EXPECTED: 1
  - RUN: grep -c '`0` disables dwell' README.md                              # EXPECTED: 1
  - RUN: grep -c '(toggle, pick, tmux-sessionx, or a manual switch)' README.md  # EXPECTED: 1

Task 5: VERIFY sibling-region preservation + markdown sanity (no edits)
  - RUN (State A only — needs the Task-1 snapshot): if [ -f /tmp/region_before_m3t2s1.txt ]; then
      diff <(grep -A1 '@session-history-pick-key' /tmp/region_before_m3t2s1.txt | head -1) \
           <(grep '@session-history-pick-key' README.md | head -1) && echo "ROW ABOVE OK"
      diff <(grep '@session-history-popup' /tmp/region_before_m3t2s1.txt | head -1) \
           <(grep '@session-history-popup' README.md | head -1) && echo "ROW BELOW OK"
    else echo "State B (no snapshot taken) — skip boundary diff; verify neighbors directly:";
      grep -c '@session-history-pick-key' README.md; grep -c '@session-history-popup' README.md;
    fi
    EXPECTED (State A): empty diffs + "ROW ABOVE OK" + "ROW BELOW OK" (pick-key row above
              and popup row below unchanged). EXPECTED (State B): each neighbor grep = 1.
              (Text-anchored on the neighbor row content, not line 84/87.)
  - RUN: grep -c 'How activity detection works' README.md    # EXPECTED: 0 (S2's region intact/untouched)
  - RUN: grep -c 'select it directly' README.md             # EXPECTED: 1 (S1's promotion bullet intact)
  - RUN (bonus, if installed): markdownlint README.md 2>/dev/null || mdl README.md 2>/dev/null || echo "no markdown linter — skip (not a failure)"
  - RUN: git diff --stat README.md
    EXPECTED: State A — a single file, net ≈0 lines (one modified line, no add/delete).
              State B — either no diff (already committed) or a single one-line hunk if the
              prior commit is your working-tree baseline; either is fine.
```

### Implementation Patterns & Key Details

```markdown
<!-- Why ONE combined edit (not split): the dwell-ms row is a single markdown
     table line. Replacing it as one oldText→newText is atomic and unambiguous
     (the row's 'Fallback for *silent* presence' opening is globally unique,
     grep -c = 1). One edit → one clean one-line git hunk → a deterministic Δ0
     line count. (Splitting into "change default cell" + "rewrite description"
     would require matching a partial row, risk a malformed half-row, and produce
     a noisier diff.) -->

<!-- Why the newText says what it says (each clause maps to a PRD section / doc_impact):

  Default cell: `30000`
      → PRD §15 / §3.4 / §8: the dwell-ms default is 30000. Replaces the stale
        `10000`. This also reconciles the README internally (the "How it works"
        body already says "default 30 s") and with the engine/entry-point code
        (both already 30000 per P1.M1.T3.S1 / P1.M2.T1.S1).

  Purpose cell, sentence 1: "How long you must stay on a session you *walked* to
  (back/forward) before it counts as relevant."
      → PRD §8 (dwell = the walk-dwell threshold) + PRD §2 key invariant
        (dwelling on a walked-to session promotes). Replaces the deleted
        "Fallback for *silent* presence: how long you must stay on a session you
        *walked* to (back/forward) without typing/interacting before it counts
        as relevant." — drops "Fallback for *silent* presence:" (dwell is no
        longer a "fallback" now that there's no primary activity signal) and
        "without typing/interacting" (the typing/interacting signal is gone).

  Purpose cell, sentence 2: "This is the only way a walked-to session becomes a
  toggle target besides re-selecting it."
      → PRD §6 (exactly two promotion causes: selection + dwell; walking never
        promotes). Replaces the deleted "Working there (typing, switching panes,
        any tmux command) promotes it immediately regardless." — that clause
        described the removed activity signal; the new clause states dwell is the
        ONLY walked-to promotion path besides selection.

  Purpose cell, sentence 3: "`0` disables dwell — relevance then comes only from
  selecting a session (toggle, pick, tmux-sessionx, or a manual switch)."
      → PRD §8 arming (if ms <= 0: return; "0 disables dwell entirely") + PRD §6
        selection causes (the four selection verbs). Replaces the deleted
        "`0` disables dwell (relevance then comes only from selecting a session
        or interacting with it)." — drops the "or interacting with it" activity
        reference and adds the explicit selection enumeration for clarity.
-->

<!-- What the newText deliberately OMITS (banned activity-presupposing phrases):
     "Fallback for *silent* presence", "without typing/interacting", "Working
     there (typing, switching panes, any tmux command) promotes it immediately
     regardless", "or interacting with it". Task 4's grep gate enforces all of
     these are gone. NOTE: the newText LEGITIMATELY contains "toggle", "pick",
     "tmux-sessionx", and "switch" — these are the SELECTION verbs (PRD §6), not
     activity references; do not gate on bare "switch"/"pick". -->

<!-- How the row reads AFTER the edit (line 86, one line):
     | `@session-history-dwell-ms` | `30000` | How long you must stay on a session you *walked* to (back/forward) before it counts as relevant. This is the only way a walked-to session becomes a toggle target besides re-selecting it. `0` disables dwell — relevance then comes only from selecting a session (toggle, pick, tmux-sessionx, or a manual switch). |
-->
```

### Integration Points

```yaml
DATABASE:
  - none. Pure documentation; no DB.

CONFIG (tmux global user options):
  - none changed. The newText references `@session-history-dwell-ms` (the option
    whose row this is) and states its default is `30000` and `0` disables dwell.
    It does NOT change any option's actual default — the engine
    (scripts/session_history.sh dwell_ms()) and entry point
    (session_history.tmux:55) are ALREADY at 30000 (P1.M1.T3.S1 / P1.M2.T1.S1,
    Complete). This edit makes the DOCUMENTED default match the CODE default.

ROUTES / DISPATCH:
  - none. Documentation only.

HOOKS / BINDINGS:
  - none changed.

DOCUMENTATION:
  - THIS edit IS the documentation (Mode A — README Options-table row directly
    touched by the dwell-default/description change). After this edit, the Options
    table advertises `30000` and the selection+dwell-only model, consistent with
    (a) the rest of the README "How it works" section (S1/S2, already landed),
    (b) the engine + entry-point code defaults (already 30000), and (c) the PRD
    (§15 / §3.4 / §8 / §6). The remaining activity reference lives in T2.S2's
    region (Troubleshooting ~line 172-176) — owned by its own subtask. Cross-file
    consistency (README ↔ code ↔ PRD) is verified by the P1.M3.T3.S1 task.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Detect input state (run BEFORE editing) — IDEMPOTENT: see CURRENT-STATE note above.
wc -l README.md                                          # expect 184 either way
head_present=$(grep -c 'Fallback for \*silent\* presence' README.md)  # 1=State A, 0=State B
new_present=$(grep -c 'the only way a walked-to session becomes a toggle target' README.md)  # 0=State A, 1=State B
echo "State A (edit needed) if old=1,new=0; State B (already applied) if old=0,new=1"
# State B -> SKIP the edit; the file already matches the newText. State A -> snapshot, then edit:
if [ "$head_present" = "1" ]; then
  grep -n 'Fallback for \*silent\* presence' README.md    # locate the row by TEXT
  sed -n '/^\| `@session-history-pick-key`/,/^\| `@session-history-popup`/p' README.md > /tmp/region_before_m3t2s1.txt
fi

# 1. Line-count delta (capture before & after within THIS task):
#    (State A: edit happens here via the `edit` tool — single row oldText→newText replacement.
#     State B: no edit; line count is already 184.)
after=$(wc -l < README.md)
echo "lines: 184 -> $after (expect 184, delta 0)"
[ "$after" = "184" ] && echo "LINE COUNT OK" || echo "LINE COUNT WRONG"
# Expected: LINE COUNT OK (184). The edit (if any) is one row in -> one row out = Δ0.

# 2. Table-row structure sanity — the row is still a well-formed 3-column row:
grep '@session-history-dwell-ms' README.md | head -1 | awk -F'|' '{print NF}'
# Expected: 5 (leading empty + trailing empty + 3 cells). Text-anchored on the
# dwell-ms row, not 'line 86'. A malformed row (e.g. an unescaped `|` inside the
# description, or a missing leading/trailing `|`) would give a different count.

# 3. Byte-level eyeball of the new row (em-dash, backticks, emphasis):
grep '@session-history-dwell-ms' README.md | head -1 | cat -A
# Expected: one line; `30000` (backticked); `*walked*`; one U+2014 em-dash
# (shown by cat -A as M-bM-^@M-^T); `0` (backticked); NO curly quotes.

# 4. Bonus markdown lint (only if a linter is installed; absence is NOT a failure):
command -v markdownlint >/dev/null && markdownlint README.md || \
command -v mdl >/dev/null && mdl README.md || \
echo "no markdown linter installed — skipping (not a failure for a doc task)"
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo (no bats/spec/Makefile/markdown-CI). These grep
proofs pin the deterministic default change, the exact phrase removal scoped to
the row, the required new phrases, and the byte-identical preservation of the
neighboring rows.

```bash
# A. Deterministic default change (the single most important proof):
grep -c '`10000`' README.md   # Expected: 0  (the only 10000 was this row)
grep -c '`30000`' README.md   # Expected: 1  (the new default cell)
grep -n  '`30000`' README.md  # confirm it is on the @session-history-dwell-ms row

# B. Banned activity-presupposing phrases are gone (file-wide — they only lived
#    in this row; S2 already removed the others from "How it works"):
grep -c 'Fallback for \*silent\* presence' README.md          # Expected: 0
grep -c 'without typing/interacting' README.md                # Expected: 0
grep -c 'promotes it immediately regardless' README.md        # Expected: 0
grep -c 'or interacting with it' README.md                    # Expected: 0

# C. Required new phrases are present (on the dwell-ms row):
grep -c 'the only way a walked-to session becomes a toggle target besides re-selecting it' README.md
# Expected: 1
grep -c '`0` disables dwell' README.md                        # Expected: 1
grep -c '(toggle, pick, tmux-sessionx, or a manual switch)' README.md   # Expected: 1

# D. Neighboring rows are byte-identical (boundary preservation) — State A uses the
#    Task-1 snapshot; State B verifies neighbors directly (no snapshot taken):
if [ -f /tmp/region_before_m3t2s1.txt ]; then
  diff <(grep '@session-history-pick-key' /tmp/region_before_m3t2s1.txt | head -1) \
       <(grep '@session-history-pick-key' README.md | head -1) && echo "ROW ABOVE OK"
  diff <(grep '@session-history-popup' /tmp/region_before_m3t2s1.txt | head -1) \
       <(grep '@session-history-popup' README.md | head -1) && echo "ROW BELOW OK"
else
  echo "State B (no snapshot) — neighbor presence check:"
  grep -c '@session-history-pick-key' README.md   # Expected: 1
  grep -c '@session-history-popup'   README.md   # Expected: 1
fi
# Expected (State A): empty diffs + "ROW ABOVE OK" + "ROW BELOW OK" (pick-key row
#   above and popup row below unchanged). Expected (State B): each neighbor grep = 1.

# E. Sibling regions are untouched (text-anchored, not line 106-133):
grep -c 'How activity detection works' README.md   # Expected: 0 (S2's deletion intact)
grep -c 'select it directly' README.md             # Expected: 1 (S1's promotion bullet intact)
# Troubleshooting still has the activity reference until T2.S2 lands — that is NOT this task:
grep -c 'produce output in it while viewing it' README.md # Expected: 1 (T2.S2 hasn't landed; NOT in scope)
```

### Level 3: Integration Testing (System Validation)

```bash
# Render the Options table to eyeball it renders as a table (not a broken code block):
# Use any markdown renderer, e.g. GitHub's web preview, or locally:
#   - mdcat README.md  (if installed)
#   - pandoc README.md -t plain | sed -n '/## Options/,/## How it works/p'
# Expected: a 3-column table; the @session-history-dwell-ms row shows `30000`
# and the new description; all other rows unchanged.
command -v pandoc >/dev/null && pandoc README.md -t plain | sed -n '/## Options/,/## How it works/p' || \
echo "pandoc not installed — eyeball the table on GitHub or in an editor"

# git diff sanity — one file, one-line hunk, Δ0 lines:
git diff --stat README.md
# Expected: "1 file changed, 1 insertion(+), 1 deletion(-)" (one modified row).
git diff README.md
# Expected: a single hunk: the old dwell-ms row (red) replaced by the new row (green).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Cross-document consistency spot-check (the whole point of this edit):
# 1. README default == engine default:
grep -o '30000' scripts/session_history.sh | head -1   # expect 30000 (dwell_ms fallback)
grep -o '30000' session_history.tmux      | head -1   # expect 30000 (set-option -g)
grep -o '`30000`' README.md               | head -1   # expect `30000` (Options row)
# All three agree on 30000 → README ↔ code consistent.

# 2. README default == PRD default:
grep -A1 'session-history-dwell-ms' PRD.md | grep -o '30000' | head -1   # expect 30000
# 3. README relevance model == PRD §6 (selection + dwell only):
grep -c 'the only way a walked-to session becomes a toggle target' README.md  # expect 1
# Expected: all three documents (README / code / PRD) agree on 30000 and on the
# selection+dwell-only model. No drift.
```

## Final Validation Checklist

### Technical Validation

- [ ] All validation levels completed successfully.
- [ ] Line count unchanged: `wc -l README.md` → **184**.
- [ ] Default changed: `grep -c '`10000`' README.md` → **0**; `grep -c '`30000`' README.md` → **1**.
- [ ] Row still well-formed: `grep '@session-history-dwell-ms' README.md | head -1 | awk -F'|' '{print NF}'` → **5**.
- [ ] git diff is a single one-line hunk (1 insertion, 1 deletion).

### Feature Validation

- [ ] All success criteria from "What" section met (default 30000; banned phrases
      gone; required phrases present).
- [ ] The banned activity-presupposing phrases are all gone from the row:
      `Fallback for *silent* presence`, `without typing/interacting`,
      `promotes it immediately regardless`, `or interacting with it`.
- [ ] The new description matches the selection+dwell-only model (PRD §6): dwell
      is "the only way a walked-to session becomes a toggle target besides
      re-selecting it"; `0` disables dwell; relevance then comes only from
      selection (toggle, pick, tmux-sessionx, or a manual switch).
- [ ] Neighboring Options rows (pick-key above, popup below) byte-identical.
- [ ] Sibling regions intact (S1's promotion bullets, S2's async paragraph; the
      Troubleshooting activity reference is NOT this task — T2.S2 owns it).

### Code Quality Validation

- [ ] Follows existing README table conventions (3-column `| Option | Default | Purpose |`).
- [ ] Typography consistent with the file: `*walked*` emphasis, `` `0` `` /
      `` `30000` `` backticks, one U+2014 em-dash, straight quotes.
- [ ] Vocabulary consistent with the README (`tmux-sessionx`, `switch`).
- [ ] No new structural element introduced (still one Options row).

### Documentation & Deployment

- [ ] README Options table now advertises `30000`, matching the engine
      (`scripts/session_history.sh` `dwell_ms()`) and entry point
      (`session_history.tmux:55`) — no README↔code drift.
- [ ] README internally consistent (Options table `30000` == "How it works"
      "default 30 s").
- [ ] No environment variables or new options introduced.

---

## Anti-Patterns to Avoid

- ❌ Don't split the row edit into "change default" + "rewrite description" — one
  atomic row replacement is cleaner and Δ0.
- ❌ Don't key on "line 86" — anchor on the row's text (the `Fallback for *silent*
  presence` opening is globally unique).
- ❌ Don't drop the `*walked*` emphasis or `` `0` ``/`` `30000` `` backticks —
  they match the file's existing row typography and keep the table consistent.
- ❌ Don't substitute the em-dash (—) with `--` or ASCII `-` — use UTF-8 U+2014.
- ❌ Don't introduce curly quotes — the whole file uses straight quotes.
- ❌ Don't touch any other Options row, the table header, the "How it works"
  section, or Troubleshooting — those are out of scope (other rows / S1 / S2 / T2.S2).
- ❌ Don't gate validation on bare "switch"/"pick"/"activity" — those words
  legitimately appear (selection verbs; the §12 sentence cites `monitor-activity`).
  Gate on the EXACT banned phrases listed in Task 4.
- ❌ Don't claim the edit changes a code default — it only changes the DOCUMENTED
  default to match code that is already at 30000.