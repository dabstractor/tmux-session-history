name: "P1.M3.T1.S1 — Rewrite README promotion model: remove activity bullet, keep selection + dwell"
description: "One-region exact-text rewrite of README.md 'How it works' lines 106–128 (the 'A session becomes relevant…' intro + bullet list + the 'Walking through a session' paragraph). DELETE the entire 'type, switch panes/windows, or run any tmux command… primary signal' bullet (old lines 109–116) including the monitor-activity parenthetical and the client_activity/keystroke explanation; REORDER so 'select it directly' is bullet #1; REWRITE the 'dwell on it' bullet to drop the '*without* typing/interacting' clause; REWRITE the 'Walking through a session does not make it relevant' paragraph (old lines 122–128) to delete 'the instant you produce output… activity promotes immediately' and instead explain dwell promotion. Result: exactly two promotion causes (selection + dwell) matching PRD §6, with zero activity/typing/output/poller references in the edit region. Executed as ONE atomic exact-text replacement (oldText = old lines 106–128, 23 lines; newText = 16 lines). Net −7 lines (README 199 → 192). This IS the doc update (Mode A — README section directly touched by the relevance-model change). Sibling T1.S2 owns the disjoint region below (old lines 130–148, the 'How activity detection works' subsection + async-paths paragraph); T2.S1 owns the Options table row (old line 86); T2.S2 owns Troubleshooting (old lines 187–189). Anchor on TEXT, never line numbers — both sibling regions have unique text anchors so merge order is irrelevant."

---

## Goal

**Feature Goal**: Rewrite the README.md "How it works" **promotion model** so it
describes exactly **two** causes of relevance — **direct selection** and **dwell**
— matching PRD §6, with **no** activity / typing / output / poller references in
the edited region. The current three-bullet list (whose first bullet is "type,
switch panes/windows, or run any tmux command… primary signal") and the false
"the instant you produce output… activity promotes immediately" paragraph must be
replaced with the two-cause model and a dwell-based explanation.

**Deliverable**: An edited `README.md` in which the region from "A session becomes
relevant…" through the end of the "Walking through a session does **not** make it
relevant…" paragraph reads exactly as the newText specified in Task 2: two bullets
(selection + dwell), the activity bullet deleted, the "produce output / activity
promotes" paragraph rewritten to describe dwell promotion. Everything outside this
region is byte-identical — including the blank separator line and the
"**How activity detection works.**" subsection immediately below (owned by T1.S2).

**Success Definition**:
1. The "when you either:" list under "A session becomes relevant" contains
   **exactly two** bullets: `select it directly` and `dwell on it`.
2. **Zero** occurrences of `client_activity`, `monitor-activity`, `keystroke`,
   `produce output`, `activity promotes`, `primary`, `poller`, `~0.5`, or
   `typing/interacting` anywhere in the edited region (the rewritten lines 106–121).
3. The "Walking through a session" paragraph explains that **dwell** promotes a
   walked-to session (not activity/output), matching PRD §6's "Walking never
   promotes … stay longer than @session-history-dwell-ms" model.
4. `README.md` is **192** lines (was 199; net **−7**).
5. The blank line separating this region from the "**How activity detection
   works.**" subsection (T1.S2's region) is preserved — the two regions stay
   disjoint so both edits merge cleanly regardless of order.

## User Persona (if applicable)

**Target User**: A plugin user (tmux power-user) reading the README to understand
*why* toggle targets the sessions it does.

**Use Case**: The user binds the toggle key and wants to know which sessions become
"relevant" toggle targets. They read "How it works" → "A session becomes relevant"
and must see a single, true, two-cause model (select it, or dwell on it) with no
reference to a typing/output signal the engine no longer has (per PRD §12).

**User Journey**: User opens README → scrolls to "How it works" → reads the
timeline paragraph (unchanged) → reads the relevance-list paragraph (unchanged) →
reads "A session becomes relevant…" and sees exactly two bullets → reads "Walking
through a session does **not** make it relevant…" and understands that only dwell
can promote a browsed-to session.

**Pain Points Addressed**: Today the README's promotion list leads with a
"type/switch panes/windows… primary signal" bullet describing `client_activity`
polling — a signal the engine no longer has (P1.M1 removed it; PRD §12 says it is
"not wired"). A user who trusts this list expects typing to promote a session
instantly and is confused when it does not. The rewrite tells the truth: selection
and dwell only.

## Why

- **Spec compliance (PRD §6).** PRD §6 is explicit and unambiguous: "A session is
  promoted to the front of the relevance list (`promote_tlist`) by **exactly two**
  causes: (1) Direct selection … (2) Dwell … **Walking never promotes.**" The
  current README's three-bullet list (input / selection / dwell) directly
  contradicts "exactly two causes." The rewrite reconciles README ↔ PRD.
- **Spec compliance (PRD §12).** PRD §12 dedicates a whole section to *why* there
  is no output-activity signal: `alert-activity` is "unusable" (fires only for
  non-focused/background windows); "It is therefore not wired. Relevance comes
  from **selection and dwell only**." The README's "type, switch panes/windows…
  primary signal" bullet describes exactly the signal §12 rejects.
- **Code-state alignment (CONTRACT).** P1.M1 already removed `do_activity` /
  `do_poller` / `do_start_poller` and the dispatch + usage references; P1.M1.T3
  changed the dwell default to 30000; P1.M1.T4 rewrote the engine header comments.
  The engine is in the selection+dwell-only state. The README is now *stale*
  relative to the code and must be brought into alignment.
- **Decomposition ownership (GAP 9b + 9c).** This is exactly GAP 9b ("DELETE the
  'type, switch panes/windows' bullet; reorder so select-it-directly + dwell-on-it
  are the two causes") and GAP 9c ("DELETE/REWRITE 'the instant you produce
  output… activity promotes immediately'") of `architecture/gap_analysis.md`. The
  sibling README subtasks (T1.S2 = GAP 9d/9e, T2.S1 = GAP 9a, T2.S2 = GAP 9f) own
  the *other* activity references and are disjoint from this region.
- **Mode A documentation.** This **is** the doc update for the promotion model —
  a user-facing README section directly touched by the relevance-model change. No
  separate docs subtask.

## What

A single exact-text replacement in `README.md`. The replacement rewrites a 23-line
region (the "A session becomes relevant…" intro + the three-bullet list + the
"Walking through a session" paragraph) into a 16-line region (intro + two-bullet
list + a dwell-based "Walking through a session" paragraph). The blank separator
and the "**How activity detection works.**" subsection immediately following are
untouched (T1.S2 owns that subsection).

### The region being replaced (old lines 106–128 — 23 lines)

```markdown
A session becomes relevant — is promoted to the front of the relevance list —
when you either:

- **type, switch panes/windows, or run any tmux command in it while viewing it** —
  this is the *primary* signal. The moment you're working in the session in
  front of you, it becomes the toggle target, within about half a second to a
  second. (tmux's built-in `monitor-activity` can't see this — it only notices
  *background* windows — so the plugin instead watches the attached client's
  activity timestamp, which advances on every keystroke you send: characters
  typed into the shell, pane/window switches, and tmux commands alike.)
- **select it directly** — via toggle, pick, tmux-sessionx, or a manual
  `switch-client`. The session you go to becomes relevant immediately.
- **dwell on it** — reach it by walking (back/forward) and stay longer than
  `@session-history-dwell-ms` (default 30 s) *without* typing/interacting. This is
  the fallback for silent presence (reading, thinking).

Walking through a session does **not** make it relevant by itself. So if you're working
in session A, walk the history back through several sessions to land on B, and
press toggle, you flip back to A — not to the session adjacent to B — because A
is what you were using and the walk never promoted the ones in between. But the
instant you produce output in a walked-to session, activity promotes it
immediately, so the dwell timer never gets in the way of active use. Press
toggle again and you're back on B (once B itself is relevant).
```

### The replacement (newText — 16 lines)

```markdown
A session becomes relevant — is promoted to the front of the relevance list —
when you either:

- **select it directly** — via toggle, pick, tmux-sessionx, or a manual
  `switch-client`. The session you go to becomes relevant immediately.
- **dwell on it** — reach it by walking (back/forward) and stay longer than
  `@session-history-dwell-ms` (default 30 s). This is the fallback for silent
  presence (reading, thinking): a session you only browsed to is not relevant
  until you've actually stayed on it.

Walking through a session does **not** make it relevant by itself. So if you're
working in session A, walk the history back through several sessions to land on
B, and press toggle, you flip back to A — not to the session adjacent to B —
because A is what you were using and the walk never promoted the ones in
between. If you instead stay on that walked-to session B long enough, dwell
promotes it; press toggle and you're now oscillating between A and B.
```

### What is NOT changed (byte-identical, preserved)

- **The blank line at old line 105** (separator after the relevance-list paragraph
  "...most-recently-used sessions oscillate.") — sits just ABOVE the oldText and
  stays.
- **The blank line at old line 129** (separator BEFORE the "**How activity
  detection works.**" subsection) — sits just BELOW the oldText and stays. This is
  the boundary that keeps this task (S1) disjoint from T1.S2.
- **The "**How activity detection works.**" subsection (old lines 130–140)** and
  **the async-paths paragraph (old lines 142–148)** — T1.S2's region. Untouched.
- Everything else in README.md (title, intro, Why, Features, Install, Keys,
  Options table, Requirements, Troubleshooting, Limitations, License).

### Success Criteria

- [ ] The "when you either:" list has **exactly two** bullets: `select it directly`
      then `dwell on it`.
- [ ] The "type, switch panes/windows…" bullet is **entirely absent**.
- [ ] The "dwell on it" bullet contains **no** "*without* typing/interacting"
      clause.
- [ ] The "Walking through a session…" paragraph contains **no** "produce output",
      "activity promotes", or "back on B (once B itself is relevant)" text.
- [ ] The rewritten "Walking through a session…" paragraph states that **dwell**
      promotes a walked-to session B.
- [ ] `README.md` is **192** lines (was 199; −7).
- [ ] The blank separator + "**How activity detection works.**" subsection below
      the edit are byte-identical (T1.S2's region is undisturbed).

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact 23-line oldText (lines 106–128, captured
byte-accurately including UTF-8 em-dashes, verified via `cat -A`) and the exact
16-line newText; the precise scope boundary (old lines 129 blank separator +
130 "How activity detection works" = T1.S2, NOT this task); the full banned-token
enumeration for the edit region; the edit is executed as ONE atomic replacement
because the region is contiguous and the opening line "A session becomes relevant"
is globally unique; the newText is sourced verbatim from the architecture
analysis (`doc_impact.md` §3 paragraph 3) which itself maps 1:1 to PRD §6;
parallel-safety vs T1.S2 (disjoint region, unique text anchors); deterministic
grep proofs scoped to the edit region (not the whole file, since S2's region
still legitimately contains "activity"); a markdown-structure sanity check (blank
lines around the bullet list and paragraph). An implementer with zero prior
knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authority for the two-cause model this rewrite must match
- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't"
  why: "PRD §6 is the exact spec the rewritten bullet list must reproduce. Verbatim:
        'A session is promoted to the front of the relevance list (promote_tlist) by
        exactly two causes: (1) Direct selection. Any NAVIGATION or TOGGLE promotes
        the session you land on (to). This covers pick, tmux-sessionx, a manual
        switch-client, and toggle itself. (2) Dwell. Reaching a session by a WALK
        and staying longer than @session-history-dwell-ms (see §8). Walking never
        promotes.' The newText's two bullets are a user-facing paraphrase of these
        two clauses."
  critical: "EXACTLY two causes — selection + dwell. The current README's first bullet
             ('type, switch panes/windows… primary signal') is a THIRD cause PRD §6
             does not have. It must be deleted wholesale, not partially rewritten."

# MUST READ — why the activity/typing bullet is deleted (not retained)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "PRD §12 is the authority for deleting the 'type/switch panes/windows' bullet.
        It states alert-activity is 'unusable' (fires only for non-focused/background
        windows — the opposite of 'the session I'm using'), there is 'no robust tmux
        primitive for the focused session produced output' without heavy per-pane
        pipe-pane plumbing, and 'It is therefore not wired. Relevance comes from
        selection and dwell only.' The deleted bullet's claim that input is the
        'PRIMARY signal' directly contradicts this section."
  critical: "Relevance = SELECTION + DWELL only (§12). Do not retain or soften the
             activity bullet — delete it. Do not add an apologetic 'we used to detect
             typing' note; the README must contain no activity-detection narrative in
             this region."

# MUST READ — the design doc that pre-authored the exact newText
- docfile: plan/001_ca41c05f3ead/architecture/doc_impact.md
  section: "§3. Outline: what ## How it works should say AFTER the refactor — Paragraph 3"
  why: "doc_impact.md §3 'Paragraph 3' contains the EXACT target newText for this
        region (the two bullets + the rewritten 'Walking through a session' paragraph).
        This PRP adopts that text verbatim. It is the curated, PRD-aligned phrasing."
  critical: "§3 Paragraph 4 (the 'dwell timer is the only asynchronous path' replacement
             for the How-activity-detection subsection + async-paths paragraph) is T1.S2's
             scope, NOT this task. Use ONLY §3 Paragraph 3 (the bullet list + the Walking
             paragraph). Do not pull Paragraph 4 into this edit."

# MUST READ — the decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 9 — README drift — rows 9b and 9c"
  why: "GAP 9b (README lines 110–116): 'first bullet is type, switch panes/windows… as
        the primary signal → 🔴 DELETE this bullet; reorder so select it directly +
        dwell on it are the two causes (PRD §6).' GAP 9c (README lines 126–127):
        'the instant you produce output… activity promotes immediately → 🔴 DELETE/REWRITE.'
        This PRP == GAP 9b + 9c."
  critical: "GAP 9d (the 'How activity detection works' subsection, lines 130–140) and
             9e (async-paths 'focused-activity detection is the other', lines 142–148)
             are T1.S2 — NOT this task. GAP 9a (Options table line 86) is T2.S1.
             GAP 9f (Troubleshooting lines 187–189) is T2.S2. This task touches ONLY
             lines 106–128."

# MUST READ — the key invariant confirming the two-cause model
- docfile: PRD.md
  section: "§2. Concepts — Key invariant"
  why: "'The two lists are maintained independently. Walking moves the history cursor
        but never touches the relevance list. Selecting or dwelling promotes in the
        relevance list but, for walks, leaves the timeline intact.' This confirms
        exactly two promotion verbs (select, dwell) — the model the rewrite encodes."
  critical: "Walking NEVER promotes. The rewritten 'Walking through a session' paragraph
             must preserve this: only dwelling (staying) promotes a walked-to session."

# The file under edit
- file: README.md
  why: "The ONLY file this task modifies. GitHub-flavored Markdown, UTF-8 (em-dashes —
        are U+2014, bytes E2 80 94). The edit region is lines 106–128: line 106 opens
        with 'A session becomes relevant' (unique anchor); line 128 closes with
        '...back on B (once B itself is relevant).' Line 129 (blank) follows and is the
        separator before T1.S2's region at line 130 ('**How activity detection works.**').
        Everything above line 106 (timeline paragraph, relevance-list paragraph) and
        below line 129 is untouched."
  pattern: "The 'How it works' section uses bolded lead-phrases for list items
            ('- **select it directly** — …') and prose paragraphs with inline code
            (`@session-history-dwell-ms`) and em-dash asides. The newText follows this
            exact style — bolded bullet leads, one inline-code option reference, em-dash
            asides. No new structural element is introduced."
  gotcha: "Em-dashes (—) in the file are UTF-8 (bytes E2 80 94, shown by cat -A as
           M-bM-^@M-^Y). The oldText contains em-dashes on old lines 106, 109, 112, 113,
           116, 118, 124; the newText keeps em-dashes on new lines 1, 4, 6, 13. Match
           UTF-8 exactly in oldText; preserve it in newText. Do NOT substitute '--' or
           ASCII '-'."

# The sibling README task (CONTRACT — same file, disjoint region BELOW this one)
- docfile: plan/001_ca41c05f3ead/P1M3T1S1/research/promotion_model_region.md
  why: "This research note captures the exact byte-accurate old region (cat -A verified),
        the line-by-line mapping, the banned-token enumeration scoped to the edit region,
        and the S1-vs-S2 boundary (the blank line 129 separator). It is the source of
        truth for the oldText/newText byte fidelity."
  critical: "The grep gate is scoped to S1's EDIT REGION, not the whole README. The word
             'activity' still legitimately appears below (T1.S2's 'How activity detection
             works' subsection) until S2 lands. Do NOT assert whole-file 'activity' = 0."

# The code state this doc is being aligned to (CONTRACT — already Complete/Ready)
- file: scripts/session_history.sh
  why: "P1.M1 already removed the activity machinery this README bullet described.
        grep-verified (per P1M2T1S2 PRP): do_activity/do_poller/do_start_poller = 0
        matches; dwell_ms() default = 30000; the only 'poller' text left is the
        self-cleaning migration guard. The README rewrite brings the docs INTO ALIGNMENT
        with this already-refactored engine."
  critical: "This PRP does NOT edit the engine. The engine is already selection+dwell-only.
             No code change is needed for this doc edit to be accurate — only the README
             is stale."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §6/§12/§2 authorize this edit
├── README.md                   # ← THE FILE TO EDIT (199 lines)
│                                #     line 104   = "...most-recently-used sessions oscillate." (KEEP)
│                                #     line 105   = blank (KEEP — separator above region)
│                                #     lines 106–128 = promotion bullets + Walking paragraph (THIS TASK: REWRITE)
│                                #     line 129   = blank (KEEP — separator, boundary to S2)
│                                #     line 130+  = "**How activity detection works.**" (T1.S2 — DO NOT TOUCH)
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — already selection+dwell-only (P1.M1 done; READ for cross-check only)
├── session_history.tmux        # entry point (T1.S2/M2 own; DO NOT TOUCH)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/doc_impact.md      # ← §3 Paragraph 3 = the exact newText
        ├── architecture/gap_analysis.md    # ← GAP 9b (delete bullet) + 9c (rewrite paragraph)
        ├── prd_snapshot.md                 # full PRD (READ-ONLY)
        └── P1M3T1S1/
            ├── PRP.md                      # ← THIS task
            └── research/promotion_model_region.md   # byte-accurate old region + scope boundary
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only README.md is modified.
# After this task the file is 192 lines (was 199; −7):
#   - the 8-line "type, switch panes/windows" bullet (old 109–116) is gone  (−8)
#   - the "dwell on it" bullet's "*without* typing/interacting" clause is gone
#     and the bullet is rephrased (net +1 line for the rephrase)
#   - the "Walking through a session" paragraph (old 122–128, 7 lines) becomes
#     a 6-line dwell-based paragraph (net −1... see exact line map: 23 → 16 = −7)
#   - the blank separators (old 105, 121, 129) are preserved
# The "**How activity detection works.**" subsection (was line 130, now ~123) is
# byte-identical and is T1.S2's to handle separately.
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```markdown
<!-- CRITICAL — em-dashes are UTF-8. The file uses U+2014 (—, bytes E2 80 94) on old
     lines 106, 109, 112, 113, 116, 118, 124. The newText keeps em-dashes on its lines
     1, 4, 6, 13. Match UTF-8 exactly in oldText; preserve it in newText. Do NOT replace
     with '--' or an ASCII '-'. (Verified via cat -A: M-bM-^@M-^Y.) -->

<!-- CRITICAL — execute as ONE combined edit, not several. The region old lines 106–128
     is contiguous (intro + 3 bullets + blank + Walking paragraph). A single
     oldText→newText replacement is atomic and unambiguous, gives a clean single-hunk
     git diff, and makes the −7 line-count assertion deterministic. The opening line
     "A session becomes relevant — is promoted to the front of the relevance list —"
     is globally unique in README.md, guaranteeing exactly one match. -->

<!-- CRITICAL — scope the grep gate to the EDIT REGION, not the whole README. The word
     "activity" still legitimately appears below the edit in T1.S2's "How activity
     detection works" subsection (old line 130+) until S2 lands, and in the
     Troubleshooting section (old line 187) until T2.S2 lands. A whole-file
     'grep activity README.md' is NOT expected to be zero after this task alone.
     Gate on the edit region only (see Level 2). -->

<!-- GOTCHA — do NOT touch old line 129 (the blank separator) or old line 130 ("**How
     activity detection works.**"). The oldText must END at old line 128
     ("...back on B (once B itself is relevant)."). The blank at 129 is the boundary
     that keeps this task disjoint from T1.S2; preserving it means both edits merge
     cleanly in either order. -->

<!-- GOTCHA — do NOT pull doc_impact.md §3 "Paragraph 4" into this edit. Paragraph 4
     is the replacement for the "How activity detection works" subsection + the
     async-paths paragraph — that is T1.S2's scope. This task uses §3 "Paragraph 3"
     ONLY (the two bullets + the Walking paragraph). -->

<!-- GOTCHA — keep the "dwell on it" bullet's inline-code reference `@session-history-dwell-ms`
     and "(default 30 s)". The 30 s already matches the PRD target default (30000 ms);
     do not change it to "10 s" or "10000". (The Options TABLE row at old line 86 still
     says 10000 until T2.S1 fixes it — that is NOT this task; the body text is already
     correct at 30 s and stays.) -->

<!-- GOTCHA — no test framework / markdown linter is wired into this repo's CI. Validation
     uses grep proofs (token removal scoped to the edit region, bullet count), a
     markdown-structure sanity check (blank line before/after the bullet list and around
     the paragraph), a manual line-count assertion (199 → 192), and a git-diff review
     confirming a single hunk. If `markdownlint` or `mdl` happens to be installed, run it
     as a bonus; absence is not a failure. -->

<!-- GOTCHA — line numbers shift under parallel execution but anchors don't. T1.S2 edits
     the region BELOW this one (old 130–148); if S2 lands first it does not move lines
     106–128. This task is net −7, shifting only lines BELOW old line 128. ALWAYS match
     the full TEXT of the opening line "A session becomes relevant" and the closing line
     "...back on B (once B itself is relevant).", not the line number 106/128. -->
```

## Implementation Blueprint

### Data models and structure

None. This is a pure prose edit (delete one bullet + rephrase one bullet + rewrite
one paragraph) in the user-facing Markdown README. No data models, no schemas, no
code, no options, no hooks, no dispatch. The `@session-history-dwell-ms` option
name is referenced verbatim in the newText (unchanged from the old text).

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CAPTURE pre-edit baseline (no source edits)
  - RUN: before=$(wc -l < README.md); echo "pre-edit lines = $before"   # expect 199
  - RUN: sed -n '104,132p' README.md > /tmp/region_before_m3t1s1.txt
         # Captures the relevance-list tail (104) + blank (105) + edit region (106-128) +
         # blank separator (129) + "How activity detection works" header line (130) + a
         # few lines of S2's region (131-132). Regression guard: proves lines 104-105 and
         # 129-132 are byte-identical before/after (only 106-128 change).
  - RUN: grep -c 'A session becomes relevant' README.md   # expect 1 (unique anchor)
  - RUN: grep -c 'produce output in a walked-to' README.md   # expect 1 (the clause to delete)
  - WHY: the snapshot proves you edited ONLY lines 106-128. Lines 104-105 (above) and
         129-132 (below, incl. the blank separator and S2's header) must match pre/post.

Task 2: PERFORM the single combined exact-text replacement (the edit)
  - USE the `edit` tool with the oldText/newText in the "What" section above. The oldText
    is the EXACT bytes of old lines 106–128 (intro + 3 bullets + blank + Walking paragraph).
    The newText is the 16-line two-bullet + rewritten-Walking-paragraph block. Match UTF-8
    em-dashes (—) exactly.
  - ANCHOR on the full text (opening line "A session becomes relevant — is promoted to the
    front of the relevance list —" is unique in README.md); do NOT key on 'line 106'.
  - PRESERVE byte-for-byte: old line 105 (blank above), old line 129 (blank separator
    below), old line 130 ("**How activity detection works.**" — T1.S2's region).
  - DO NOT TOUCH: the Options table (old line 86, T2.S1), the "How activity detection
    works" subsection (old 130–140, T1.S2), the async-paths paragraph (old 142–148,
    T1.S2), the Troubleshooting section (old 187–189, T2.S2).

Task 3: VERIFY line count + structure (no edits)
  - RUN: after=$(wc -l < README.md); echo "post-edit lines = $after"
    EXPECTED: 192 (was 199; −7). Any other count = wrong edit scope — revert.
  - RUN: sed -n '106,121p' README.md | cat -n
    # Eyeball: intro (2 lines) + blank + 2 bullets (select: 2 lines; dwell: 3 lines) +
    # blank + ... then the Walking paragraph follows. Exactly TWO "- **" bullet leads.
  - RUN: awk '/^A session becomes relevant/{f=1} f{print} /^toggle again.*oscillating between A and B/{if(f){f=0}}' README.md | grep -c '^- \*\*'
    EXPECTED: 2 (exactly two bullets in the promotion list).

Task 4: VERIFY token removal in the edit region + preservation of the boundary (no edits)
  - RUN: sed -n '/^A session becomes relevant/,/^If you instead stay on.*dwell/p' README.md > /tmp/s1_region.txt
         # Extracts the rewritten region (intro → end of Walking paragraph).
  - RUN: grep -niE 'client_activity|monitor-activity|keystroke|produce output|activity promotes|\*primary\*|poller|typing/interacting|half a second|background windows' /tmp/s1_region.txt
    EXPECTED: ZERO output (all banned tokens gone from S1's region).
  - RUN: grep -ni 'activity' /tmp/s1_region.txt
    EXPECTED: ZERO output (no "activity" word anywhere in S1's rewritten region).
  - RUN: grep -c 'select it directly' /tmp/s1_region.txt   # EXPECTED: 1
  - RUN: grep -c 'dwell on it' /tmp/s1_region.txt          # EXPECTED: 1
  - RUN: grep -c 'dwell promotes it' /tmp/s1_region.txt    # EXPECTED: 1 (the new clause)
  - RUN: grep -nF '**How activity detection works.**' README.md
    EXPECTED: exactly 1 line (T1.S2's region header survived byte-identical; it shifted
              up by 7 lines from old 130 → ~123 but is unchanged).
  - RUN: diff <(sed -n '104,105p' /tmp/region_before_m3t1s1.txt) <(sed -n '104,105p' README.md)
    EXPECTED: empty (the relevance-list tail + blank above the region are byte-identical).

Task 5: VERIFY markdown structure / whole-file sanity (no edits)
  - RUN: awk 'NR>=106 && NR<=125' README.md | grep -n '^$'
    # Confirm there is a blank line between the intro+bullets block and the Walking
    # paragraph (markdown paragraph separation), and that the bullet list block is
    # surrounded by blanks. A missing blank would render the paragraph as a
    # continuation of the list — visually broken.
  - RUN (bonus, if installed): markdownlint README.md 2>/dev/null || mdl README.md 2>/dev/null || echo "no markdown linter — skip (not a failure)"
  - RUN: git diff --stat README.md
    EXPECTED: a single file; net change ≈ −7 lines.
```

### Implementation Patterns & Key Details

```markdown
<!-- Why ONE combined edit (not three): the region old lines 106–128 is contiguous
     (intro + 3 bullets + blank + Walking paragraph). Replacing it as a single
     oldText→newText is atomic and unambiguous. The opening line
     "A session becomes relevant — is promoted to the front of the relevance list —"
     is the unique anchor guaranteeing exactly one match. One edit → one clean git
     hunk → a deterministic −7 line count. (Three separate edits — delete bullet,
     rephrase dwell bullet, rewrite paragraph — risk leaving the blank at old line
     121 orphaned or double-counted, and produce a noisier diff.) -->

<!-- Why the newText says what it says (each clause maps to a PRD section / doc_impact):

  Intro (unchanged, 2 lines): "A session becomes relevant — is promoted to the front
  of the relevance list — when you either:"
      → Kept verbatim; it is activity-neutral and frames the two-bullet list.

  Bullet 1 — "select it directly": "via toggle, pick, tmux-sessionx, or a manual
  switch-client. The session you go to becomes relevant immediately."
      → Maps to PRD §6 cause (1) "Direct selection. Any NAVIGATION or TOGGLE promotes
        the session you land on (to). This covers pick, tmux-sessionx, a manual
        switch-client, and toggle itself." This bullet is KEPT from the old text
        (old lines 116–118) and merely promoted to bullet #1.

  Bullet 2 — "dwell on it": "reach it by walking (back/forward) and stay longer than
  @session-history-dwell-ms (default 30 s). This is the fallback for silent presence
  (reading, thinking): a session you only browsed to is not relevant until you've
  actually stayed on it."
      → Maps to PRD §6 cause (2) "Dwell. Reaching a session by a WALK and staying
        longer than @session-history-dwell-ms." The old bullet's "*without*
        typing/interacting" clause is DROPPED (it presupposes the removed poller) and
        replaced with the doc_impact §3 phrasing. The inline-code option name +
        "(default 30 s)" are preserved.

  Walking paragraph (rewritten): "...If you instead stay on that walked-to session B
  long enough, dwell promotes it; press toggle and you're now oscillating between A
  and B."
      → Maps to PRD §6 "Walking never promotes ... If you are working in A, walk ...
        to B, and toggle, you flip to A ... not to the session adjacent to B." The
        old false clause "But the instant you produce output ... activity promotes it
        immediately" is replaced with the TRUE dwell-promotes clause.
-->

<!-- What the newText deliberately OMITS (banned in S1's region): client_activity,
     monitor-activity, keystroke, "produce output", "activity promotes", "*primary*",
     poller, "typing/interacting", "~0.5–1 s" / "half a second", "background windows",
     "pane/window switches" (in the activity-detection sense). The Level 2 grep gate
     enforces all of these scoped to the edit region. -->

<!-- How the region reads AFTER the edit (old 106–128 → new 106–121, then blank + S2):
     A session becomes relevant — is promoted to the front of the relevance list —    # new 1
     when you either:                                                                  # new 2
                                                                                        # new 3 (blank)
     - **select it directly** — via toggle, pick, tmux-sessionx, or a manual           # new 4
       `switch-client`. The session you go to becomes relevant immediately.            # new 5
     - **dwell on it** — reach it by walking (back/forward) and stay longer than       # new 6
       `@session-history-dwell-ms` (default 30 s). This is the fallback for silent     # new 7
       presence (reading, thinking): a session you only browsed to is not relevant     # new 8
       until you've actually stayed on it.                                            # new 9
                                                                                        # new 10 (blank)
     Walking through a session does **not** make it relevant by itself. So if you're   # new 11
     working in session A, walk the history back through several sessions to land on   # new 12
     B, and press toggle, you flip back to A — not to the session adjacent to B —      # new 13
     because A is what you were using and the walk never promoted the ones in          # new 14
     between. If you instead stay on that walked-to session B long enough, dwell       # new 15
     promotes it; press toggle and you're now oscillating between A and B.             # new 16
                                                                                        # old 129 (blank — preserved)
     **How activity detection works.** ...   ← T1.S2's region (was line 130, now ~123)
-->
```

### Integration Points

```yaml
DATABASE:
  - none. Pure documentation; no DB.

CONFIG (tmux global user options):
  - none changed. The inline-code reference `@session-history-dwell-ms` and "(default 30 s)"
    in the newText are identical to the old text — no option renamed, no default changed
    in the body. (The Options TABLE row at old line 86 still says 10000 until T2.S1 fixes
    it; that is NOT this task. The body text was already correct at 30 s and stays.)

ROUTES / DISPATCH:
  - none. Documentation only.

HOOKS / BINDINGS:
  - none changed.

DOCUMENTATION:
  - THIS edit IS the documentation (Mode A — README section directly touched by the
    relevance-model change). After this edit, the README "How it works" promotion model
    matches PRD §6 (two causes: selection + dwell) within S1's region. The remaining
    activity references live in T1.S2's region (the "How activity detection works"
    subsection + async-paths paragraph, old lines 130–148), T2.S1's region (Options table
    dwell row, old line 86), and T2.S2's region (Troubleshooting, old lines 187–189) —
    each owned by its own subtask. Cross-file consistency (README ↔ code ↔ PRD) is
    verified by the P1.M3.T3.S1 task.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Pre-edit baseline (run BEFORE editing):
before=$(wc -l < README.md); echo "pre-edit lines = $before"          # expect 199
sed -n '104,132p' README.md > /tmp/region_before_m3t1s1.txt           # snapshot incl. boundary
grep -c 'A session becomes relevant' README.md                        # expect 1 (unique anchor)
grep -c 'produce output in a walked-to' README.md                     # expect 1 (clause to delete)

# 1. Line-count delta (capture before & after within THIS task):
#    (edit happens here via the `edit` tool — single oldText→newText replacement)
after=$(wc -l < README.md)
echo "lines: $before -> $after (expect 199 -> 192, delta -7)"
[ "$after" = "192" ] && echo "LINE COUNT OK" || echo "LINE COUNT WRONG"
# Expected: LINE COUNT OK (192). The edit is 23 oldText lines -> 16 newText lines = -7.

# 2. Markdown structure sanity — bullet list bounded by blanks, paragraph bounded by blanks:
sed -n '106,125p' README.md | grep -n '^$'
# Expected: blank lines at the intro/list boundary, the list/paragraph boundary, and the
# paragraph/next-section boundary. A MISSING blank would render a list item as a paragraph
# continuation (visually broken) — investigate if a required separator is absent.

# 3. Bonus markdown lint (only if a linter is installed; absence is NOT a failure):
command -v markdownlint >/dev/null && markdownlint README.md || \
command -v mdl >/dev/null && mdl README.md || \
echo "no markdown linter installed — skipping (not a failure for a doc task)"
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo (no bats/spec/Makefile/markdown-CI). These grep proofs
pin the exact token removal **scoped to S1's edit region**, the two-bullet count, and the
byte-identical preservation of the boundary into T1.S2's region.

```bash
# A. Extract S1's rewritten region (intro through end of the Walking paragraph):
sed -n '/^A session becomes relevant/,/oscillating between A and B/p' README.md > /tmp/s1_region.txt
wc -l /tmp/s1_region.txt   # expect 16 lines (no trailing blanks)

# B. Banned tokens are absent from S1's region:
grep -niE 'client_activity|monitor-activity|keystroke|produce output|activity promotes|\*primary\*|poller|typing/interacting|half a second|background windows|pane/window switches' /tmp/s1_region.txt
# Expected: NO output (zero matches). [Pre-edit this region matched 'primary', 'monitor-activity',
# 'keystroke', 'produce output', 'activity promotes', 'typing/interacting', 'background windows',
# 'pane/window switches'.]

# C. The word "activity" is absent from S1's region:
grep -ni 'activity' /tmp/s1_region.txt
# Expected: NO output. (S1's region must be activity-free. NOTE: 'activity' still legitimately
# appears BELOW in T1.S2's "How activity detection works" subsection — do NOT gate on the
# whole file for this token; only on /tmp/s1_region.txt.)

# D. Exactly two bullets in the promotion list:
grep -c '^- \*\*' /tmp/s1_region.txt
# Expected: 2 (select it directly; dwell on it).

# E. The two required clauses are present:
grep -c 'select it directly' /tmp/s1_region.txt      # Expected: 1
grep -c 'dwell on it' /tmp/s1_region.txt             # Expected: 1
grep -c 'dwell promotes it' /tmp/s1_region.txt       # Expected: 1 (the new clause replacing
                                                       # "activity promotes it immediately")

# F. The dwell bullet still references the option + 30 s default (preserved, not changed):
grep -c '`@session-history-dwell-ms`' /tmp/s1_region.txt   # Expected: 1
grep -c 'default 30 s' /tmp/s1_region.txt                   # Expected: 1

# G. T1.S2's region header survived byte-identical (shifted up by 7, content unchanged):
grep -nF '**How activity detection works.**' README.md
# Expected: exactly 1 line (was old line 130, now ~123). Byte-identical text.

# H. Boundary preservation — the lines immediately ABOVE and BELOW the edit are byte-identical:
diff <(sed -n '104,105p' /tmp/region_before_m3t1s1.txt) <(sed -n '104,105p' README.md) && echo "ABOVE BOUNDARY OK"
# Expected: empty diff + "ABOVE BOUNDARY OK" (relevance-list tail "...oscillate." + blank).
grep -qF '**How activity detection works.**' README.md && echo "BELOW BOUNDARY OK (S2 header intact)"
# Expected: "BELOW BOUNDARY OK" — S2's region is undisturbed.

# I. Scope guard — the Options table (T2.S1) and Troubleshooting (T2.S2) are untouched:
grep -c '@session-history-dwell-ms` | `10000`' README.md    # Expected: 1 (T2.S1 hasn't landed
                                                             # yet — the 10000 row is NOT this task)
grep -c 'produce output in it while viewing it' README.md   # Expected: 1 (T2.S2 hasn't landed
                                                             # yet — Troubleshooting is NOT this task)
# These assert you did NOT accidentally edit sibling-owned regions.
```

### Level 3: Integration Testing (System Validation)

There is no runtime component to a README prose edit (Markdown is not executed), so the
"integration test" is a **rendered-preview + cross-reference** check: confirm the edited
section renders as a proper two-bullet list with a well-separated paragraph, and that the
README's promotion model now matches PRD §6 word-for-word in its two causes.

```bash
# A. Render the edited "How it works" promotion block as it would appear on GitHub.
#    (If a markdown renderer is available, use it; otherwise eyeball the raw markdown
#    structure from the sed output below.)
sed -n '106,125p' README.md
# Expected (manual review): a 2-line intro ("A session becomes relevant ... when you either:"),
# a blank, a 2-line "select it directly" bullet, a 3-line "dwell on it" bullet, a blank, and a
# 6-line "Walking through a session" paragraph ending "...oscillating between A and B."

# B. Cross-reference: README's two bullets == PRD §6's two causes, word for word.
echo "--- README promotion causes ---"
grep -E '^- \*\*(select it directly|dwell on it)' README.md
echo "--- PRD §6 causes ---"
grep -A1 'exactly two causes' PRD.md
# Expected: README lists (1) select it directly, (2) dwell on it; PRD §6 lists (1) Direct
# selection, (2) Dwell. They correspond 1:1. No third cause in either.

# C. Cross-reference: README no longer claims typing/output promotes (PRD §12 says not wired).
echo "--- README S1 region: any 'produces output promotes' claim? (expect none) ---"
sed -n '/^A session becomes relevant/,/oscillating between A and B/p' README.md | grep -iE 'produces? output|typing.*promotes|output.*promotes'
# Expected: NO output. PRD §12: "It is therefore not wired. Relevance comes from selection and dwell only."

# D. Git diff review — the change is a single, scoped hunk.
git diff README.md
# Manually confirm:
#   - the '-' side is EXACTLY old lines 106-128 (intro + 3 bullets + blank + Walking paragraph).
#   - the '+' side is the 16-line two-bullet + rewritten-Walking-paragraph block.
#   - NOTHING above old line 106 or below old line 128 changed (the blank at 129 and S2's
#     "**How activity detection works.**" header at 130 appear UNCHANGED — no +/- prefix).
#   - If you see a change to old line 86 (Options table) or old lines 130+ (S2's region) or
#     old lines 187+ (Troubleshooting), you have crossed into a sibling's scope — revert.
# Expected: one hunk, roughly -23/+16 (markdown diff may group context lines; net -7).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# A. Whole-file consistency snapshot — how many activity references remain and WHERE
#    (this is informational; S1 does NOT zero the whole file — S2/T2.S1/T2.S2 do their parts):
echo "=== remaining 'activity' occurrences in README (S1 should have removed the 106-128 ones) ==="
grep -ni 'activity' README.md | head -30
# Expected: 'activity' NO LONGER appears in the 106-121 span (S1's new region). It still
# appears at the "**How activity detection works.**" subsection (T1.S2's region) and in
# Troubleshooting (T2.S2's region) until those land. This is correct — record the count,
# do not try to zero the whole file here.

# B. The dwell default is consistent within S1's region (body says 30 s; PRD §15 says 30000):
grep -n 'default 30 s' README.md
# Expected: 1 match in S1's region (preserved from old text; was already correct).
# (The Options TABLE at old line 86 still says 10000 until T2.S1 — NOT a contradiction S1 fixes.)

# C. PRD authority for every clause of the newText is present in the spec:
grep -n 'exactly two causes' PRD.md          # §6 — the two-cause model
grep -n 'Direct selection' PRD.md            # §6 — cause (1)
grep -n 'Dwell' PRD.md | head -3             # §6 — cause (2)
grep -n 'Walking never promotes' PRD.md      # §6 — the rule the Walking paragraph encodes
grep -n 'not wired' PRD.md                   # §12 — why the activity bullet is deleted
# Expected: all present. The newText's claims are each grounded in a PRD section.

# D. The edit is minimal and scoped in git:
git diff --stat README.md
# Expected: a single file. Net ≈ -7 lines. One hunk.

# E. Final whole-region token sweep (the authoritative S1 gate):
sed -n '/^A session becomes relevant/,/oscillating between A and B/p' README.md \
  | grep -niE 'client_activity|monitor-activity|keystroke|produce output|activity promotes|\*primary\*|poller|typing/interacting|half a second'
# Expected: NO output. S1's region is activity-free.
echo "LEVEL 4 DONE"
```

## Final Validation Checklist

### Technical Validation

- [ ] `wc -l README.md` == **192** (was 199; −7).
- [ ] The S1 region (`sed -n '/^A session becomes relevant/,/oscillating between A and B/p'`)
      contains **zero** matches for `client_activity`, `monitor-activity`, `keystroke`,
      `produce output`, `activity promotes`, `*primary*`, `poller`, `typing/interacting`,
      `half a second`, `background windows`.
- [ ] The S1 region contains **zero** matches for the bare word `activity`.
- [ ] The S1 region contains **exactly two** `^- \*\*` bullets (`select it directly`,
      `dwell on it`).
- [ ] The S1 region contains the new clause `dwell promotes it` (replacing the deleted
      `activity promotes it immediately`).

### Feature Validation

- [ ] The "type, switch panes/windows…" bullet is **entirely absent** from the README
      promotion list.
- [ ] The "dwell on it" bullet contains **no** "*without* typing/interacting" clause.
- [ ] The "Walking through a session…" paragraph explains that **dwell** promotes a
      walked-to session (not output/activity), and contains **no** "produce output",
      "activity promotes", or "back on B (once B itself is relevant)" text.
- [ ] The intro + bullets + paragraph render as valid Markdown (blanks separate the
      bullet list from the surrounding prose).
- [ ] Cross-reference: README's two bullets correspond 1:1 to PRD §6's two causes
      (Direct selection; Dwell). No third cause.

### Code Quality Validation

- [ ] The git diff is a single hunk on the old lines 106–128 region; nothing else.
- [ ] old line 105 (blank above) and old line 129 (blank separator below) are
      byte-identical.
- [ ] The "**How activity detection works.**" header (T1.S2's region, was line 130) is
      byte-identical (shifts up by 7 to ~123 but content unchanged).
- [ ] UTF-8 em-dashes (—) in the newText are preserved (not downgraded to `--`).
- [ ] No "drive-by" fixes; no edit to the Options table (T2.S1), the "How activity
      detection works" subsection (T1.S2), the async-paths paragraph (T1.S2), or
      Troubleshooting (T2.S2).
- [ ] Edit is anchored on the full oldText text (opening line is unique), not the line
      number 106.

### Documentation & Deployment

- [ ] This edit IS the documentation (Mode A — README "How it works" promotion model).
- [ ] The README promotion model now matches PRD §6 (selection + dwell) within S1's region.
- [ ] No new options, hooks, bindings, or environment variables introduced.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT touch old line 129 (blank separator) or old line 130** ("**How activity
  detection works.**"). The oldText must END at old line 128 ("...back on B (once B
  itself is relevant)."). The blank at 129 is the boundary keeping this task disjoint
  from T1.S2; preserving it means both edits merge in either order.
- ❌ **Do NOT pull `doc_impact.md` §3 "Paragraph 4" into this edit.** Paragraph 4 (the
  "dwell timer is the only asynchronous path" replacement) is T1.S2's scope. This task
  uses §3 "Paragraph 3" ONLY (the two bullets + the Walking paragraph).
- ❌ **Do NOT gate on a whole-file `grep activity README.md` == 0.** The word "activity"
  still legitimately appears in T1.S2's "How activity detection works" subsection and
  T2.S2's Troubleshooting until those land. Gate on S1's **edit region only**.
- ❌ **Do NOT mention `client_activity`, `monitor-activity`, `keystroke`, `produce
  output`, `activity promotes`, `*primary*`, `poller`, `typing/interacting`, or `~0.5–1 s`
  in the newText.** Even an explanatory "we used to detect typing" note violates the
  spec-cleanup intent. The region must contain *zero* activity-detection narrative.
- ❌ **Do NOT change the dwell default in the body.** The old text already says "(default
  30 s)" which matches PRD §15's 30000. Keep it. (The Options TABLE row at old line 86
  still says `10000` — that is T2.S1, not this task.)
- ❌ **Do NOT split this into three edits** (delete bullet / rephrase dwell bullet /
  rewrite paragraph) when one combined edit is feasible. The region (106–128) is
  contiguous and the opening line is unique; one atomic replacement gives a clean
  single-hunk diff and a deterministic −7 line count.
- ❌ **Do NOT edit `scripts/session_history.sh`, `session_history.tmux`, the Options
  table, the Troubleshooting section, or the "How activity detection works" subsection.**
  The engine is already selection+dwell-only (P1.M1 done); the other README regions are
  owned by T1.S2 / T2.S1 / T2.S2. This task is the README promotion-bullets + Walking
  paragraph ONLY.
- ❌ **Do NOT key the edit on the hard line number `106`.** T1.S2 edits the same file
  BELOW this region and does not move lines 106–128; but always match the full TEXT of
  the opening line "A session becomes relevant" and the closing line "...back on B (once
  B itself is relevant)." Line numbers are for orientation, not anchoring.
- ❌ **Do NOT reformat surrounding lines or "fix" the em-dash style elsewhere.** Preserve
  UTF-8 em-dashes (—) exactly. The edit is the 106–128 region only.

---

## Scope Boundaries (one-screen reference)

| Item | This task (M3.T1.S1)? | Owner |
|------|:---:|-------|
| Promotion bullet list — DELETE "type/switch panes" bullet (old 109–116) | ✅ | M3.T1.S1 (GAP 9b) |
| Reorder: "select it directly" → bullet #1 (old 116–118) | ✅ | M3.T1.S1 (GAP 9b) |
| REWRITE "dwell on it" bullet — drop "*without* typing/interacting" (old 118–120) | ✅ | M3.T1.S1 (GAP 9b) |
| REWRITE "Walking through a session" paragraph — dwell, not activity (old 122–128) | ✅ | M3.T1.S1 (GAP 9c) |
| Keep blank separator (old 129) + S2 region header (old 130) byte-identical | ✅ (preserve) | M3.T1.S1 |
| "How activity detection works" subsection (old 130–140) | ❌ | **M3.T1.S2** (GAP 9d) |
| Async-paths paragraph "focused-activity is the other" (old 142–148) | ❌ | **M3.T1.S2** (GAP 9e) |
| Options table `@session-history-dwell-ms` row (old 86) | ❌ | **M3.T2.S1** (GAP 9a) |
| Troubleshooting "produce output in it while viewing it" (old 187–189) | ❌ | **M3.T2.S2** (GAP 9f) |
| Cross-file consistency (README ↔ code ↔ PRD) | ❌ | **M3.T3.S1** |
| Engine / entry-point code | ❌ | P1.M1 / P1.M2 (done) |

---

## Confidence Score

**10/10** for one-pass success. This is a single-region Markdown prose edit with: the exact
23-line oldText supplied byte-accurately (including UTF-8 em-dashes, verified via `cat -A`)
and the exact 16-line newText supplied (sourced verbatim from the curated
`architecture/doc_impact.md` §3 paragraph 3, which maps 1:1 to PRD §6); the rewrite's every
clause grounded in a PRD section (§6 two causes, §6 "walking never promotes", §12 not-wired);
the full banned-token enumeration for the edit region; executed as ONE atomic replacement
because the region is contiguous and the opening line "A session becomes relevant" is
globally unique; deterministic grep proofs **scoped to the edit region** (not the whole
file, since T1.S2's region still legitimately contains "activity"); a −7 line-count
assertion (199 → 192); explicit parallel-safety vs T1.S2 (disjoint region separated by the
preserved blank line 129, both regions anchored on unique text); an explicit scope map
separating M3.T1.S1 from M3.T1.S2 (GAP 9d/9e), M3.T2.S1 (GAP 9a), and M3.T2.S2 (GAP 9f); and
a markdown-structure sanity check. No ambiguity: the oldText is unique, the newText is fully
specified, and the validation gates are deterministic.