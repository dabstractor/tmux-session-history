name: "P1.M3.T1.S2 — Remove 'How activity detection works' subsection and rewrite the async-paths paragraph to dwell-only"
description: "One-region exact-text rewrite of README.md lines 123–141 (post-S1, 192-line state): DELETE the entire 11-line '**How activity detection works.**' subsection (lines 123–133) — it describes the removed client_activity timestamp, the background poller (~0.5–1 s), and the false 'one resident process / no per-pane pipes' framing — and REWRITE the 7-line async-paths paragraph (lines 135–141), deleting 'focused-activity detection is the other [async path]', 'activity promotes it instead', 'produce output there', and replacing them with the dwell-only model from doc_impact.md §3 'Paragraph 4': 'The dwell timer is the only asynchronous path …' plus the optional PRD-§12 sentence ('Relevance intentionally comes from selection and dwell only: there is no robust tmux primitive for \"the focused session produced output\" without a resident process per pane, and tmux's `monitor-activity` only sees *background* windows — the opposite of what toggle needs.'). Executed as ONE atomic exact-text replacement (oldText = old lines 123–141, 19 lines incl. the blank at 134 between the two blocks; newText = 11 lines: 6-line dwell paragraph + blank + 4-line §12 sentence). Net −8 lines (README 192 → 184). Quote style is ALL STRAIGHT (0 curly quotes in the file; verified). Em-dashes are U+2014. This IS the doc update (Mode A — README section directly touched by the activity-removal change). Sibling T1.S1 has ALREADY LANDED (README is 192 lines, promotion bullets already reordered to select+dwell); T2.S1 owns the Options table row (line 86 / 10000); T2.S2 owns Troubleshooting (lines ~179–181). Anchor on TEXT, never line numbers — the opening anchor '**How activity detection works.**' and the closing anchor 'so stale timers are harmless.' are each globally unique."

---

## Goal

**Feature Goal**: Remove the README's entire "**How activity detection works.**"
subsection and rewrite the async-paths paragraph that follows it, so that the
README "How it works" section describes **dwell as the ONLY asynchronous path**
(matching PRD §8 / §13), with **zero** `client_activity` / background-poller /
focused-activity / "activity promotes" / "one resident process" / per-pane-pipe
references — i.e. no narrative describing the output-activity feature the
engine no longer has (PRD §12: "It is therefore not wired").

**Deliverable**: An edited `README.md` in which the region from
`**How activity detection works.**` (old line 123) through the end of the
async-paths paragraph (`…so stale timers are harmless.`, old line 141) reads
exactly as the newText specified in the "What" section: a 6-line "dwell is the
only asynchronous path" paragraph + blank + a 4-line sentence explaining *why*
there is no input/output signal (PRD §12). The "**How activity detection works.**"
heading is **gone**. Everything outside this region (S1's promotion bullets and
Walking paragraph above; the close-current, sessionx-composition, and capping
paragraphs below) is byte-identical.

**Success Definition**:
1. README.md contains **zero** occurrences of the heading `**How activity detection works.**`.
2. README.md contains **zero** occurrences of `client_activity`,
   `focused-activity detection`, `activity promotes it`, `background poller`,
   `poller` (as a resident-process noun), `one resident process`, `produce output
   there`, `per-pane pipes`, or `~0.5` — i.e. every activity-detection phrase is
   gone from the README's "How it works" section.
3. The async-paths region states dwell is the **only** asynchronous path
   ("only asynchronous path") touching only the relevance list, matching PRD §8.
4. The new region includes the §12 sentence citing `monitor-activity`'s
   background-only limitation as the reason there is no output signal.
5. `README.md` is **184** lines (was 192 after S1; net **−8**).
6. The blank separators at old line 122 (the S1↔S2 boundary) and old line 142
   (before the close-current paragraph) are preserved byte-for-byte.

## User Persona (if applicable)

**Target User**: A plugin user (tmux power-user) reading the README "How it
works" section to understand *what makes a session relevant* and *what runs in
the background*.

**Use Case**: The user has bound the toggle key and wants to know (a) which
sessions become toggle targets and (b) what asynchronous work the plugin does.
They read past S1's two-bullet promotion model, then read the next paragraph.
Today that paragraph is the "**How activity detection works.**" subsection — a
detailed description of a `client_activity` poller the engine **no longer has**
(removed in P1.M1). The user who trusts it expects typing to promote a session
within ~0.5–1 s and is confused when it does not.

**User Journey**: User opens README → "How it works" → reads timeline paragraph
(unchanged) → reads relevance-list paragraph (unchanged) → reads S1's
two-bullet promotion model (select + dwell) → reads S1's Walking paragraph →
**reads the new async-paths paragraph** (dwell is the only async path; it
touches only the relevance list; stale timers are harmless) → **reads the §12
sentence** (why there is no input/output signal) → reads close-current
paragraph (unchanged).

**Pain Points Addressed**: Today the README "How it works" section contains a
whole bolded subsection documenting a removed feature (the `client_activity`
poller) and a paragraph claiming "focused-activity detection is the other
[async path]" and "activity promotes it instead" — both **false** in the
target state (PRD §8: dwell is the sole async path; PRD §12: no output signal
is wired). A user who reads this expects typing to promote instantly and is
surprised it does not. The rewrite tells the truth: dwell only, and explains
*why* (no robust focused-output primitive).

## Why

- **Spec compliance (PRD §8).** PRD §8 "Dwell" is explicit: "Dwell is the one
  asynchronous path." The README's "The dwell timer is one asynchronous path;
  focused-activity detection is the other" directly contradicts this. The
  rewrite states dwell is the **only** async path.
- **Spec compliance (PRD §12).** PRD §12 dedicates a whole section to *why*
  there is no output-activity signal: `alert-activity` "only fires for
  non-focused/background windows"; "There is no robust tmux primitive for 'the
  focused session produced output' without heavy per-pane pipe-pane plumbing";
  "It is therefore not wired. Relevance comes from selection and dwell only."
  The README's "**How activity detection works.**" subsection documents exactly
  the feature §12 rejects. Deleting it and adding the §12-citation sentence
  reconciles README ↔ PRD.
- **Spec compliance (PRD §13).** PRD §13 lists dwell among the async relevance
  paths "touch ONLY `tlist`". The rewrite's "it touches only the relevance list
  (never the timeline)" reproduces this.
- **Code-state alignment (CONTRACT).** P1.M1 already removed
  `do_activity`/`do_poller`/`do_start_poller` and the dispatch + usage
  references; P1.M1.T4 rewrote the engine header comments. The engine is in the
  selection+dwell-only, no-poller state. The README is now *stale* relative to
  the code and must be brought into alignment. (Confirmed: S1 already landed —
  README is 192 lines, promotion bullets already reordered.)
- **Decomposition ownership (GAP 9d + 9e).** This is exactly GAP 9d ("DELETE
  the 'How activity detection works' paragraph") and 9e ("REWRITE the async-path
  paragraph — focused-activity detection is the other / activity promotes it
  instead → dwell only") of `architecture/gap_analysis.md`. Sibling T1.S1
  (GAP 9b/9c, already done), T2.S1 (GAP 9a, Options table), and T2.S2 (GAP 9f,
  Troubleshooting) own the *other* activity references and are disjoint.
- **Mode A documentation.** This **is** the doc update for the async-paths /
  activity-detection region — a user-facing README section directly touched by
  the activity-removal change. No separate docs subtask.

## What

A single exact-text replacement in `README.md`. The replacement deletes a
19-line region (the "**How activity detection works.**" subsection + the blank
that follows it + the async-paths paragraph) and substitutes an 11-line region
(a dwell-only paragraph + blank + a §12-citation sentence). The blank separator
above (old line 122, the S1↔S2 boundary) and the blank separator below
(old line 142, before the close-current paragraph) are untouched.

> **Line numbers are POST-S1.** S1 (P1.M3.T1.S1) has already landed — README is
> 192 lines, the promotion bullets are already reordered to select+dwell, and
> the Walking paragraph already says "dwell promotes it". This task's INPUT is
> the 192-line post-S1 README. **Always anchor on TEXT, not line numbers.**

### The region being replaced (old lines 123–141 — 19 lines)

```markdown
**How activity detection works.** When toggle is bound the plugin watches the
attached client's `client_activity` timestamp. tmux advances it on every
keystroke you send — a character passed through to the shell, a pane/window
switch, or any tmux command — so it is a direct signal for "the user is working
in the session they're viewing". A small background poller promotes the current
session whenever that timestamp advances while the session stays the same
(~0.5–1 s). A session-switch key (back/forward/toggle/sessionx) also advances
the timestamp, but it changes the session at the same time, so it is not
mistaken for work — walking past a session never promotes it. There are no
per-pane pipes and only one resident process; with toggle unbound there are no
resident processes at all.

The dwell timer is one asynchronous path; focused-activity detection is the
other. Both touch only the relevance list (never the timeline), so a rare lost
update only nudges relevance and self-heals on the next switch. When you walk
onto a session, a background timer is armed; if you're still on that session
when it fires, the session is promoted. The moment you produce output there,
activity promotes it instead, so dwell only matters for silent presence. The
timer self-cancels if you've moved on, so stale timers are harmless.
```

This region is: 11-line subsection (123–133) + blank (134) + 7-line paragraph
(135–141). It opens with the globally-unique line
`**How activity detection works.** When toggle is bound the plugin watches the`
and closes with the globally-unique line
`timer self-cancels if you've moved on, so stale timers are harmless.`

### The replacement (newText — 11 lines)

```markdown
The dwell timer is the only asynchronous path, and it touches only the
relevance list (never the timeline), so a rare lost update only nudges
relevance and self-heals on the next switch. When you walk onto a session, a
background timer is armed; if you're still on that session when it fires, the
session is promoted. The timer self-cancels if you've moved on, so stale
timers are harmless.

Relevance intentionally comes from selection and dwell only: there is no
robust tmux primitive for "the focused session produced output" without a
resident process per pane, and tmux's `monitor-activity` only sees
*background* windows — the opposite of what toggle needs.
```

The newText is the verbatim text from
`plan/001_ca41c05f3ead/architecture/doc_impact.md` §3 "Paragraph 4" (the
curated, PRD-aligned design text), with the file's straight-quote / U+2014
em-dash style preserved.

### What the newText says (clause-by-clause → PRD authority)

- **"The dwell timer is the only asynchronous path"** → PRD §8 "Dwell is the one
  asynchronous path." Replaces the deleted false clause "focused-activity
  detection is the other".
- **"it touches only the relevance list (never the timeline)"** → PRD §8
  "restricted to a read-modify-write of `tlist` alone" and PRD §13 "Dwell and
  activity (the async relevance paths) touch ONLY `tlist`".
- **"a rare lost update only nudges relevance and self-heals on the next
  switch"** → PRD §8 "The worst conceivable failure is a rare lost-update on
  `tlist`, which is best-effort and self-heals on the next navigation or dwell."
- **"When you walk onto a session, a background timer is armed; if you're still
  on that session when it fires, the session is promoted. The timer
  self-cancels if you've moved on, so stale timers are harmless."** → PRD §8
  Arming/Firing: `arm_dwell` arms on a WALK arrival; `do_dwell`'s "still
  current?" guard makes a stale timer a clean no-op.
- **"Relevance intentionally comes from selection and dwell only: there is no
  robust tmux primitive for 'the focused session produced output' without a
  resident process per pane, and tmux's `monitor-activity` only sees
  *background* windows — the opposite of what toggle needs."** → PRD §12, nearly
  verbatim: "There is no robust tmux primitive for 'the focused session produced
  output' without heavy per-pane `pipe-pane` plumbing"; "`alert-activity` only
  fires for non-focused/background windows — it detects activity in sessions you
  are *not* viewing, the opposite of 'the session I'm using.'"

### What is NOT changed (byte-identical, preserved)

- **Old line 121:** `promotes it; press toggle and you're now oscillating between A and B.` (S1's Walking paragraph tail — KEEP).
- **Old line 122:** BLANK — the S1↔S2 boundary separator (sits immediately
  ABOVE oldText). KEEP.
- **Old line 142:** BLANK — separator before the close-current paragraph (sits
  immediately BELOW oldText). KEEP.
- **Old lines 143–146:** the close-current paragraph (`When a session closes…
  select it or dwell on it.`) — KEEP (already target-aligned; doc_impact §1f).
- **Old lines 148+:** sessionx-composition and capping paragraphs — KEEP.
- **Old line 86:** the Options table `@session-history-dwell-ms` row (still says
  `10000`) — KEEP; that is **T2.S1's** scope, NOT this task.
- **Troubleshooting (old lines ~179–181):** `…produce output in it while viewing
  it…` — KEEP; that is **T2.S2's** scope, NOT this task.
- Everything else in README.md (title, intro, Why, Features, Install, Keys,
  Options table, Requirements, Limitations, License).

### Success Criteria

- [ ] The heading `**How activity detection works.**` is **entirely absent**
      from README.md.
- [ ] The edit region (`sed -n '/^The dwell timer is the only asynchronous
      path/,/the opposite of what toggle needs/p'`) contains **zero** matches
      for `client_activity`, `focused-activity detection`, `activity promotes`,
      `background poller`, `poller`, `one resident process`, `produce output
      there`, `per-pane pipes`, `~0.5`.
- [ ] The edit region contains `only asynchronous path`, `monitor-activity`,
      `resident process per pane`, and `the opposite of what toggle needs`.
- [ ] `README.md` is **184** lines (was 192; −8).
- [ ] The blank separator at old line 122 (above) and old line 142 (below) are
      byte-identical; S1's Walking paragraph tail and the close-current
      paragraph are byte-identical.

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact 19-line oldText (post-S1 lines 123–141,
captured byte-accurately including UTF-8 em-dashes U+2014 and the en-dash U+2013
inside "(~0.5–1 s)", verified via `cat -A`) and the exact 11-line newText; the
precise scope boundary (old line 122 blank above = S1↔S2 boundary; old line 142
blank below = before close-current; both preserved); the full banned-phrase
enumeration for the edit region (specific phrases, NOT bare "activity"/"output"
— because `monitor-activity` and "produced output" legitimately appear in the
newText); the edit is executed as ONE atomic replacement because the region is
contiguous and both anchors are globally unique; the newText is sourced verbatim
from the architecture analysis (`doc_impact.md` §3 "Paragraph 4") which itself
maps clause-by-clause to PRD §8/§12/§13; input-state confirmation that S1 has
landed (README is 192 lines); parallel-safety vs T2.S1/T2.S2 (disjoint regions,
unique text anchors); deterministic grep proofs scoped to the edit region (not
the whole file, since Troubleshooting still legitimately contains
"activity"-adjacent text until T2.S2 lands). An implementer with zero prior
knowledge of this codebase can do it in one pass.

### Documentation & References

```yaml
# MUST READ — the authority for "dwell is the ONLY async path" this rewrite encodes
- docfile: PRD.md
  section: "§8. Dwell (esp. 'Why dwell touches only the relevance list')"
  why: "PRD §8 is the exact spec the rewritten paragraph must reproduce. Verbatim:
        'Dwell is the one asynchronous path. To make it incapable of corrupting
        critical state, it is restricted to a read-modify-write of tlist alone.
        The worst conceivable failure is a rare lost-update on tlist, which is
        best-effort and self-heals on the next navigation or dwell.' The newText's
        'only asynchronous path', 'touches only the relevance list', and
        'self-heals on the next switch' are direct paraphrases."
  critical: "EXACTLY ONE async path — dwell. The current README's 'The dwell timer
             is one asynchronous path; focused-activity detection is the other' is
             a SECOND async path PRD §8 does not have. The 'focused-activity
             detection is the other' clause must be deleted, not retained."

# MUST READ — why there is no output-activity signal (the §12 sentence's authority)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "PRD §12 is the authority for the optional-but-recommended second sentence.
        It states alert-activity is 'unusable' (fires only for non-focused/background
        windows — the opposite of 'the session I'm using'), there is 'no robust tmux
        primitive for the focused session produced output without heavy per-pane
        pipe-pane plumbing', and 'It is therefore not wired. Relevance comes from
        selection and dwell only.' The newText's 'monitor-activity only sees
        *background* windows — the opposite of what toggle needs' reproduces §12."
  critical: "The §12 sentence is what tells a user WHY typing no longer promotes —
             doc_impact §9.2 calls removing the input signal 'the single most
             user-visible behavioral change.' Include it (it is in the canonical
             newText). Do NOT add an apologetic 'we used to detect typing' note; the
             README must contain no activity-detection FEATURE narrative."

# MUST READ — concurrency framing: dwell touches ONLY tlist (the safety claim)
- docfile: PRD.md
  section: "§13. Concurrency & race safety"
  why: "PRD §13: 'Dwell and activity (the async relevance paths) touch ONLY tlist
        AND now take the lock too, so they are fully serialized and can never
        corrupt hist/idx/current/mode.' The newText's 'it touches only the
        relevance list (never the timeline)' is the user-facing version of this."
  critical: "The newText says dwell touches the RELEVANCE LIST only (never the
             timeline). This is PRD §8/§13. Do NOT claim it touches hist/idx/current."

# MUST READ — the design doc that pre-authored the exact newText
- docfile: plan/001_ca41c05f3ead/architecture/doc_impact.md
  section: "§3. Outline: what ## How it works should say AFTER the refactor — Paragraph 4"
  why: "doc_impact.md §3 'Paragraph 4' contains the EXACT target newText for this
        region (the dwell-only paragraph + the §12 sentence). This PRP adopts that
        text verbatim. It is the curated, PRD-aligned phrasing. doc_impact §6
        ('The How activity detection works subsection — remove entirely? → YES')
        and §8 (table row for '## How it works': 'REWRITE 106-148 per §3') confirm
        §3 Paragraph 4 is authoritative and the subsection is deleted wholesale."
  critical: "§3 'Paragraph 3' (the two promotion bullets + Walking paragraph) is
             T1.S1's scope and has ALREADY landed — do NOT re-edit it. Use ONLY
             §3 'Paragraph 4'. §5's optional 'resident process' framing line is
             NOT required (§8 designates §3 as authoritative); the §12 sentence in
             Paragraph 4 already conveys 'no resident process per pane' / zero
             resident processes implicitly."

# MUST READ — the decomposition that scoped this exact work
- docfile: plan/001_ca41c05f3ead/architecture/gap_analysis.md
  section: "GAP 9 — README drift — rows 9d and 9e"
  why: "GAP 9d (README lines 130-148 in the ORIGINAL 199-line file = post-S1
        123-141): 'DELETE the \"How activity detection works\" paragraph; rewrite
        the async-path paragraph to mention dwell only.' GAP 9e: 'focused-activity
        detection is the other / activity promotes it instead → REWRITE (dwell is
        now the only async path).' This PRP == GAP 9d + 9e."
  critical: "GAP 9b/9c (the promotion bullets + Walking paragraph) = T1.S1 (DONE).
             GAP 9a (Options table line 86, the 10000 default) = T2.S1. GAP 9f
             (Troubleshooting ~179-181) = T2.S2. This task touches ONLY post-S1
             lines 123-141."

# MUST READ — the key invariant confirming selection+dwell (no third cause)
- docfile: PRD.md
  section: "§2. Concepts — Key invariant"
  why: "'The two lists are maintained independently. Walking moves the history
        cursor but never touches the relevance list. Selecting or dwelling
        promotes in the relevance list.' This confirms exactly two promotion
        verbs (select, dwell) and that the relevance list is the thing dwell
        touches — the model the rewritten paragraph encodes."
  critical: "Walking NEVER promotes; only dwelling on a walked-to session promotes.
             The rewritten async-paths paragraph must not reintroduce any 'produce
             output promotes' clause. The §12 sentence says there is NO primitive
             for output detection — the opposite of a promotion claim."

# The file under edit
- file: README.md
  why: "The ONLY file this task modifies. GitHub-flavored Markdown, UTF-8.
        QUOTES ARE ALL STRAIGHT: 18 straight apostrophes (U+0027), 0 curly (U+2018/
        U+2019); 4 straight double-quotes (U+0022), 0 curly (U+201C/U+201D) —
        verified across the whole file. Em-dashes are U+2014 (—, bytes E2 80 94,
        cat -A shows M-bM-^@M-^T). The edit region is post-S1 lines 123-141: line
        123 opens with '**How activity detection works.**' (unique anchor); line
        141 closes with 'timer self-cancels if you've moved on, so stale timers
        are harmless.' (unique anchor). Line 122 (blank, above) and line 142
        (blank, below) are the preserved boundaries. S1 has already landed (README
        is 192 lines, bullets reordered, Walking paragraph rewritten)."
  pattern: "The 'How it works' section uses bolded lead-phrases for subsections
            ('**How activity detection works.**') and prose paragraphs with inline
            code (`monitor-activity`, `@session-history-dwell-ms`), straight quotes,
            and em-dash asides (—). The newText FOLLOWS this style — no bolded
            subsection heading (it is deleted), inline-code option reference, em-dash
            aside, straight quotes. No new structural element is introduced; the
            region becomes two plain paragraphs where there was one bolded subsection
            + one paragraph."
  gotcha: "Em-dashes (—) in the file are UTF-8 U+2014 (bytes E2 80 94). The oldText
           contains em-dashes on old lines 125, 126, 131 (and an en-dash U+2013 on
           line 129 inside '(~0.5–1 s)'); the newText has ONE em-dash (before 'the
           opposite'). Match UTF-8 exactly in oldText; use U+2014 in newText. Do NOT
           substitute '--' or ASCII '-'. Quotes: the file uses STRAIGHT apostrophes
           (you're, you've, tmux's) and STRAIGHT double-quotes — the newText must
           match (0 curly quotes anywhere)."

# The byte-accurate region capture (source of truth for oldText/newText fidelity)
- docfile: plan/001_ca41c05f3ead/P1M3T1S2/research/region_byte_capture.md
  why: "This research note captures the exact byte-accurate old region (cat -A
        verified, post-S1 line numbers), the straight-quote style proof, the
        em-dash/en-dash byte map, the boundary lines to preserve, the line math
        (19 → 11 = −8; 192 → 184), and the scoped grep-gate rationale (why bare
        'activity'/'output' must NOT be gated — monitor-activity and 'produced
        output' legitimately appear in the newText)."
  critical: "The grep gate is scoped to THIS task's EDIT REGION, not the whole
             README. After this task, 'monitor-activity' (which contains the
             substring 'activity') legitimately appears in the new region, and
             'activity'-adjacent text still appears in Troubleshooting (T2.S2's
             region) until T2.S2 lands. Do NOT assert whole-file 'activity' = 0."

# The sibling README task whose output is this task's input (CONTRACT)
- docfile: plan/001_ca41c05f3ead/P1M3T1S1/PRP.md
  why: "T1.S1 owns the region ABOVE this one (the promotion bullets + Walking
        paragraph). S1 has ALREADY landed (verified: README is 192 lines, bullets
        reordered to select+dwell, Walking paragraph says 'dwell promotes it').
        S1's region is byte-identical to its PRP's newText. The blank at post-S1
        line 122 is the S1↔S2 boundary this task preserves."
  critical: "Do NOT re-edit S1's region. Do NOT touch the blank at line 122. The
             two tasks are disjoint and merge cleanly regardless of order; since
             S1 already landed, this task applies cleanly on top."

# The code state this doc is being aligned to (CONTRACT — already Complete)
- file: scripts/session_history.sh
  why: "P1.M1 already removed the activity machinery this README subsection
        described. grep-verified (per P1M2T1S2 PRP): do_activity/do_poller/
        do_start_poller = 0 matches; the only 'poller' text left is the
        self-cleaning migration guard; dwell_ms() default = 30000. The README
        rewrite brings the docs INTO ALIGNMENT with this already-refactored engine."
  critical: "This PRP does NOT edit the engine. The engine is already
             selection+dwell-only with no poller. No code change is needed for
             this doc edit to be accurate — only the README is stale."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §8/§12/§13 authorize this edit
├── README.md                   # ← THE FILE TO EDIT (192 lines, post-S1)
│                                #     line 121  = "...oscillating between A and B." (S1's tail — KEEP)
│                                #     line 122  = blank (KEEP — S1↔S2 boundary, ABOVE region)
│                                #     lines 123–133 = "**How activity detection works.**" subsection (DELETE)
│                                #     line 134  = blank (inside oldText, between subsection & paragraph)
│                                #     lines 135–141 = async-paths paragraph (REWRITE)
│                                #     line 142  = blank (KEEP — separator before close-current, BELOW region)
│                                #     line 143+ = "When a session closes..." (close-current — KEEP)
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — already selection+dwell-only (P1.M1 done; READ for cross-check only)
├── session_history.tmux        # entry point (M2 done; DO NOT TOUCH)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/doc_impact.md      # ← §3 Paragraph 4 = the exact newText; §6 = "remove subsection entirely"
        ├── architecture/gap_analysis.md    # ← GAP 9d (delete subsection) + 9e (rewrite paragraph)
        ├── prd_snapshot.md                 # full PRD (READ-ONLY)
        ├── P1M3T1S1/PRP.md                 # ← sibling ABOVE this region (DONE)
        └── P1M3T1S2/
            ├── PRP.md                      # ← THIS task
            └── research/region_byte_capture.md   # byte-accurate old region + scope boundary
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only README.md is modified.
# After this task the file is 184 lines (was 192 post-S1; −8):
#   - the 11-line "**How activity detection works.**" subsection (old 123-133) is GONE  (−11)
#   - the blank at old line 134 (between subsection & paragraph) is GONE  (−1)
#   - the 7-line async-paths paragraph (old 135-141) becomes an 11-line block  (+4)
#       = a 6-line "dwell is the only async path" paragraph
#         + a blank
#         + a 4-line §12 sentence ("Relevance intentionally comes from selection
#           and dwell only: there is no robust tmux primitive for 'the focused
#           session produced output' without a resident process per pane, and
#           tmux's `monitor-activity` only sees *background* windows — the opposite
#           of what toggle needs.")
#       Net for the paragraph block: 7 → 11 = +4.
#   - the blank separators at old lines 122 (S1↔S2 boundary) and 142 (before
#     close-current) are PRESERVED.
# The close-current paragraph (was line 143, now ~135) is byte-identical.
# All other files unchanged.
```

### Known Gotchas of our codebase & Library Quirks

```markdown
<!-- CRITICAL — S1 has ALREADY LANDED. The input is the 192-line post-S1 README,
     NOT the original 199-line file. Line numbers in this PRP are POST-S1 (the
     subsection is at 123-141, not 130-148). Verify with `wc -l README.md` → 192
     and `grep -n 'How activity detection works'` → 123 before editing. If you see
     199 lines, S1 has NOT landed — STOP and surface the discrepancy (do not edit). -->

<!-- CRITICAL — quotes are ALL STRAIGHT. Verified across the whole file: 18 straight
     apostrophes (0x27), 0 curly (U+2018/U+2019); 4 straight double-quotes (0x22),
     0 curly (U+201C/U+201D). The newText uses straight apostrophes (you're, you've,
     tmux's) and straight double-quotes ("the focused session produced output"). Do
     NOT introduce curly quotes (a common editor "smart quote" auto-correct). -->

<!-- CRITICAL — em-dashes are UTF-8 U+2014 (bytes E2 80 94; cat -A shows M-bM-^@M-^T).
     The oldText has em-dashes on old lines 125, 126, 131 and an en-dash U+2013
     (E2 80 93) inside "(~0.5–1 s)" on old line 129. The newText has ONE em-dash
     (before "the opposite"). Match UTF-8 exactly in oldText; use U+2014 in newText.
     Do NOT replace with '--' or ASCII '-'. -->

<!-- CRITICAL — execute as ONE combined edit. The region old lines 123-141 is
     contiguous (subsection + blank + paragraph). A single oldText→newText
     replacement is atomic and unambiguous, gives a clean single-hunk git diff, and
     makes the −8 line-count assertion deterministic. The opening line
     "**How activity detection works.** When toggle is bound the plugin watches the"
     is globally unique (grep -c = 1), and the closing line
     "timer self-cancels if you've moved on, so stale timers are harmless." is
     globally unique (grep -c = 1) — guaranteeing exactly one match. -->

<!-- CRITICAL — scope the grep gate to the EDIT REGION, not the whole README. The
     new region LEGITIMATELY contains "monitor-activity" (which has the substring
     "activity") and "produced output" (in the §12 sentence explaining why there is
     NO detection). Gate on the EXACT activity-detection phrases (How activity
     detection works / focused-activity detection / activity promotes it / client_activity
     / background poller / poller / one resident process / produce output there /
     per-pane pipes / ~0.5), NOT on bare "activity" or bare "output". Also,
     "activity"-adjacent text still appears in Troubleshooting (T2.S2's region) until
     T2.S2 lands. A whole-file 'grep activity README.md' is NOT expected to be 0. -->

<!-- GOTCHA — "one resident process" (old, false, to delete) vs "resident process
     per pane" (new, in the §12 sentence, intentional). These are DIFFERENT strings.
     grep "one resident process" must be 0 after the edit; grep "resident process
     per pane" must be 1. Do not confuse them. -->

<!-- GOTCHA — "produce output there" (old, false, to delete) vs "produced output"
     (new, in "no robust tmux primitive for 'the focused session produced output'",
     intentional). grep "produce output there" must be 0; the new "produced output"
     clause is correct and cites PRD §12. Do not gate on bare "output". -->

<!-- GOTCHA — do NOT touch old line 122 (the blank S1↔S2 boundary) or old line 142
     (the blank before close-current). The oldText must START at old line 123
     ("**How activity detection works.**") and END at old line 141 ("...so stale
     timers are harmless."). Preserving both blanks means this task stays disjoint
     from S1 (above) and from the close-current paragraph (below). -->

<!-- GOTCHA — keep the §12 sentence's `monitor-activity` in backticks and the
     *background* emphasis (asterisks). These are stylistic matches to the file's
     existing inline-code and emphasis usage. Do not drop the backticks or the
     asterisks. -->

<!-- GOTCHA — no test framework / markdown linter is wired into this repo's CI.
     Validation uses grep proofs (phrase removal scoped to the edit region, required
     phrases present), a markdown-structure sanity check (blank line between the two
     new paragraphs and around the region), a manual line-count assertion (192 → 184),
     and a git-diff review confirming a single hunk. If `markdownlint` or `mdl` is
     installed, run it as a bonus; absence is not a failure. -->

<!-- GOTCHA — line numbers shift under parallel execution but anchors don't. T2.S1
     edits the Options table (old line 86) and T2.S2 edits Troubleshooting (old
     ~179-181); neither overlaps old lines 123-141, so merge order is irrelevant.
     ALWAYS match the full TEXT of the opening line "**How activity detection
     works.**" and the closing line "...so stale timers are harmless.", not the line
     numbers 123/141. -->
```

## Implementation Blueprint

### Data models and structure

None. This is a pure prose edit (delete one bolded subsection + rewrite one
paragraph + add one §12-citation sentence) in the user-facing Markdown README.
No data models, no schemas, no code, no options, no hooks, no dispatch. The
`monitor-activity` and `@session-history-dwell-ms` option names are referenced
verbatim in the newText (unchanged from the rest of the file).

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CONFIRM post-S1 input state (no source edits)
  - RUN: wc -l README.md                                   # EXPECT 192 (S1 landed)
  - RUN: grep -n 'How activity detection works' README.md   # EXPECT line 123
  - RUN: grep -n 'so stale timers are harmless' README.md   # EXPECT line 141
  - RUN: grep -n 'oscillating between A and B' README.md    # EXPECT line 121 (S1's tail)
  - WHY: confirms S1 landed and the region is at post-S1 lines 123-141. If wc -l
         is NOT 192 or the anchors are missing, STOP — S1 may not have landed; surface
         the discrepancy instead of editing.
  - RUN (snapshot for boundary regression): sed -n '119,145p' README.md > /tmp/region_before_m3t1s2.txt
         # Captures S1's Walking tail (119-121) + blank boundary (122) + edit region
         # (123-141) + blank boundary (142) + close-current head (143-145). Regression
         # guard: proves lines 119-122 and 142-145 are byte-identical pre/post.

Task 2: PERFORM the single combined exact-text replacement (the edit)
  - USE the `edit` tool with the oldText/newText in the "What" section above. The
    oldText is the EXACT bytes of post-S1 lines 123-141 (subsection + blank 134 +
    paragraph). The newText is the 11-line dwell-only paragraph + blank + §12
    sentence. Match UTF-8 em-dashes (—, U+2014) exactly; use STRAIGHT quotes.
  - ANCHOR on the full text (opening line "**How activity detection works.** When
    toggle is bound the plugin watches the" is unique in README.md; closing line
    "timer self-cancels if you've moved on, so stale timers are harmless." is
    unique); do NOT key on 'line 123'.
  - PRESERVE byte-for-byte: old line 122 (blank, S1↔S2 boundary ABOVE), old line
    142 (blank, separator BEFORE close-current BELOW).
  - DO NOT TOUCH: S1's promotion bullets / Walking paragraph (old 106-121), the
    Options table (old line 86, T2.S1), the close-current paragraph (old 143-146),
    the sessionx/capping paragraphs (old 148+), the Troubleshooting section
    (old ~179-181, T2.S2).

Task 3: VERIFY line count + structure (no edits)
  - RUN: after=$(wc -l < README.md); echo "post-edit lines = $after"
    EXPECTED: 184 (was 192; −8). Any other count = wrong edit scope — revert.
  - RUN: sed -n '123,135p' README.md | cat -n
    # Eyeball: 6-line "dwell is the only async path" paragraph + blank + 4-line §12
    # sentence. Then the blank at new line ~134 and the close-current paragraph at
    # new line ~135 follow.
  - RUN: awk '/^The dwell timer is the only asynchronous/{f=1} f{print} /the opposite of what toggle needs/{if(f){f=0}}' README.md | wc -l
    EXPECTED: 11 (the new region: 6 + 1 blank + 4).

Task 4: VERIFY phrase removal in the edit region + preservation of boundaries (no edits)
  - RUN: sed -n '/^The dwell timer is the only asynchronous/,/the opposite of what toggle needs/p' README.md > /tmp/s2_region.txt
         # Extracts the rewritten region (dwell paragraph → §12 sentence).
  - RUN: grep -niE 'How activity detection works|focused-activity detection|activity promotes|client_activity|background poller|poller|one resident process|produce output there|per-pane pipes|~0.5' /tmp/s2_region.txt
    EXPECTED: ZERO output (all banned activity-detection phrases gone from S2's region).
  - RUN: grep -c 'only asynchronous path' /tmp/s2_region.txt          # EXPECTED: 1
  - RUN: grep -c 'monitor-activity' /tmp/s2_region.txt                # EXPECTED: 1 (the §12 citation)
  - RUN: grep -c 'resident process per pane' /tmp/s2_region.txt       # EXPECTED: 1 (≠ "one resident process")
  - RUN: grep -c 'the opposite of what toggle needs' /tmp/s2_region.txt  # EXPECTED: 1
  - RUN: grep -c 'How activity detection works' README.md             # EXPECTED: 0 (subsection gone file-wide)
  - RUN: grep -c 'client_activity' README.md                          # EXPECTED: 0 (timestamp ref gone file-wide)
  - RUN: diff <(sed -n '119,122p' /tmp/region_before_m3t1s2.txt) <(sed -n '119,122p' README.md) && echo "ABOVE BOUNDARY OK"
    EXPECTED: empty diff + "ABOVE BOUNDARY OK" (S1's Walking tail + the blank boundary are byte-identical).
  - RUN: diff <(sed -n '142,145p' /tmp/region_before_m3t1s2.txt) <(sed -n '134,137p' README.md) && echo "BELOW BOUNDARY OK"
    EXPECTED: empty diff + "BELOW BOUNDARY OK" (the blank separator + close-current head
              are byte-identical; they shifted up by 8 lines: 142→134, 143→135).

Task 5: VERIFY markdown structure / whole-section sanity (no edits)
  - RUN: sed -n '121,137p' README.md | grep -n '^$'
    # Confirm: a blank between S1's Walking paragraph (121) and the new dwell
    # paragraph (123), a blank between the dwell paragraph (123-128) and the §12
    # sentence (130-133), and a blank before the close-current paragraph (~135).
    # A MISSING blank would render the two new paragraphs as one block or merge the
    # §12 sentence into close-current — visually broken.
  - RUN (bonus, if installed): markdownlint README.md 2>/dev/null || mdl README.md 2>/dev/null || echo "no markdown linter — skip (not a failure)"
  - RUN: git diff --stat README.md
    EXPECTED: a single file; net change ≈ −8 lines.
```

### Implementation Patterns & Key Details

```markdown
<!-- Why ONE combined edit (not two): the region post-S1 lines 123-141 is contiguous
     (subsection + blank + paragraph). Replacing it as a single oldText→newText is
     atomic and unambiguous. The opening line
     "**How activity detection works.** When toggle is bound the plugin watches the"
     and the closing line
     "timer self-cancels if you've moved on, so stale timers are harmless."
     are EACH globally unique (grep -c = 1), so the match is unambiguous. One edit
     → one clean git hunk → a deterministic −8 line count. (Two separate edits —
     delete subsection, then rewrite paragraph — risk leaving the blank at old 134
     orphaned or double-counted, and produce a noisier diff.) -->

<!-- Why the newText says what it says (each clause maps to a PRD section / doc_impact):

  Paragraph 1 — "The dwell timer is the only asynchronous path, and it touches only
  the relevance list (never the timeline), so a rare lost update only nudges
  relevance and self-heals on the next switch. When you walk onto a session, a
  background timer is armed; if you're still on that session when it fires, the
  session is promoted. The timer self-cancels if you've moved on, so stale timers
  are harmless."
      → Maps to PRD §8 "Dwell is the one asynchronous path … restricted to a
        read-modify-write of tlist alone … a rare lost-update on tlist, which is
        best-effort and self-heals on the next navigation or dwell" + §8 Arming/Firing
        (arm_dwell on a WALK; do_dwell's "still current?" guard → stale timer = no-op).
        This replaces the deleted false clauses "The dwell timer is one asynchronous
        path; focused-activity detection is the other" and "The moment you produce
        output there, activity promotes it instead, so dwell only matters for silent
        presence."

  Blank line (paragraph separator).

  Paragraph 2 (the §12 sentence) — "Relevance intentionally comes from selection and
  dwell only: there is no robust tmux primitive for 'the focused session produced
  output' without a resident process per pane, and tmux's `monitor-activity` only
  sees *background* windows — the opposite of what toggle needs."
      → Maps to PRD §12 nearly verbatim: "There is no robust tmux primitive for 'the
        focused session produced output' without heavy per-pane pipe-pane plumbing";
        "`alert-activity` only fires for non-focused/background windows — it detects
        activity in sessions you are not viewing, the opposite of 'the session I'm
        using.'"; "Relevance comes from selection and dwell only." This sentence
        replaces the entire deleted "**How activity detection works.**" subsection
        (which documented the removed client_activity poller) with the TRUTH: there
        is no input/output signal, and here is why.
-->

<!-- What the newText deliberately OMITS (banned activity-detection phrases): the
     "**How activity detection works.**" heading; "client_activity"; "background
     poller" / "poller"; "focused-activity detection is the other"; "activity
     promotes it instead"; "produce output there"; "one resident process";
     "per-pane pipes"; "~0.5–1 s"; "keystroke you send"; "direct signal for". The
     Level 2 grep gate enforces all of these scoped to the edit region. NOTE: the
     new region LEGITIMATELY contains "monitor-activity" (contains substring
     "activity") and "produced output" (in the §12 clause) — these are intentional
     and correct; do not gate on bare "activity"/"output". -->

<!-- How the region reads AFTER the edit (old 123-141 → new 123-133, then blank + close-current):
     The dwell timer is the only asynchronous path, and it touches only the        # new 123
     relevance list (never the timeline), so a rare lost update only nudges        # new 124
     relevance and self-heals on the next switch. When you walk onto a session, a  # new 125
     background timer is armed; if you're still on that session when it fires, the # new 126
     session is promoted. The timer self-cancels if you've moved on, so stale      # new 127
     timers are harmless.                                                          # new 128
                                                                                    # new 129 (blank)
     Relevance intentionally comes from selection and dwell only: there is no      # new 130
     robust tmux primitive for "the focused session produced output" without a     # new 131
     resident process per pane, and tmux's `monitor-activity` only sees            # new 132
     *background* windows — the opposite of what toggle needs.                     # new 133
                                                                                    # was 142 (blank — preserved, now 134)
     When a session closes it is pruned from both lists and everything shifts down. # was 143 (close-current, now 135)
-->
```

### Integration Points

```yaml
DATABASE:
  - none. Pure documentation; no DB.

CONFIG (tmux global user options):
  - none changed. The newText references `monitor-activity` (a tmux builtin, cited
    as the REASON there is no output signal — PRD §12) but does NOT change any
    option. No option renamed, no default changed. (The Options TABLE row at old
    line 86 still says 10000 until T2.S1 fixes it; that is NOT this task. The §12
    sentence does not mention dwell-ms.)

ROUTES / DISPATCH:
  - none. Documentation only.

HOOKS / BINDINGS:
  - none changed.

DOCUMENTATION:
  - THIS edit IS the documentation (Mode A — README "How it works" async-paths
    region directly touched by the activity-removal change). After this edit, the
    README "How it works" section has no activity-detection subsection and
    describes dwell as the sole async path (PRD §8), with a §12-citation sentence
    explaining why there is no input/output signal. The remaining activity
    references live in T2.S1's region (Options table dwell row, old line 86) and
    T2.S2's region (Troubleshooting, old ~179-181) — each owned by its own
    subtask. Cross-file consistency (README ↔ code ↔ PRD) is verified by the
    P1.M3.T3.S1 task.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Confirm post-S1 input state (run BEFORE editing):
wc -l README.md                                  # expect 192 (S1 landed)
grep -n 'How activity detection works' README.md # expect line 123
grep -n 'so stale timers are harmless' README.md # expect line 141
grep -n 'oscillating between A and B' README.md  # expect line 121 (S1's tail)
sed -n '119,145p' README.md > /tmp/region_before_m3t1s2.txt   # snapshot incl. boundaries

# 1. Line-count delta (capture before & after within THIS task):
#    (edit happens here via the `edit` tool — single oldText→newText replacement)
after=$(wc -l < README.md)
echo "lines: 192 -> $after (expect 184, delta -8)"
[ "$after" = "184" ] && echo "LINE COUNT OK" || echo "LINE COUNT WRONG"
# Expected: LINE COUNT OK (184). The edit is 19 oldText lines -> 11 newText lines = -8.

# 2. Markdown structure sanity — the two new paragraphs are separated by a blank,
#    and blanks separate the region from S1's paragraph (above) and close-current (below):
sed -n '121,137p' README.md | grep -n '^$'
# Expected: blank at ~122 (S1 boundary), blank at ~129 (between the two new paragraphs),
# blank at ~134 (before close-current). A MISSING blank would merge paragraphs — investigate.

# 3. Bonus markdown lint (only if a linter is installed; absence is NOT a failure):
command -v markdownlint >/dev/null && markdownlint README.md || \
command -v mdl >/dev/null && mdl README.md || \
echo "no markdown linter installed — skipping (not a failure for a doc task)"
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo (no bats/spec/Makefile/markdown-CI). These grep
proofs pin the exact phrase removal **scoped to S2's edit region**, the required
new phrases, and the byte-identical preservation of the boundaries.

```bash
# A. Extract S2's rewritten region (dwell paragraph through the §12 sentence):
sed -n '/^The dwell timer is the only asynchronous/,/the opposite of what toggle needs/p' README.md > /tmp/s2_region.txt
wc -l /tmp/s2_region.txt   # expect 11 lines (6 + 1 blank + 4)

# B. Banned activity-detection phrases are absent from S2's region (EXACT phrases,
#    NOT bare "activity"/"output" — monitor-activity and "produced output" are legit):
grep -niE 'How activity detection works|focused-activity detection|activity promotes|client_activity|background poller|poller|one resident process|produce output there|per-pane pipes|~0.5|keystroke you send|direct signal for' /tmp/s2_region.txt
# Expected: NO output (zero matches). [Pre-edit this region matched all of these.]

# C. File-wide removal of the subsection header and the client_activity timestamp ref:
grep -c 'How activity detection works' README.md   # Expected: 0 (subsection gone)
grep -c 'client_activity' README.md                # Expected: 0 (timestamp ref gone)
grep -c 'focused-activity detection' README.md     # Expected: 0 (the false clause gone)

# D. Required new phrases are present in S2's region:
grep -c 'only asynchronous path' /tmp/s2_region.txt          # Expected: 1
grep -c 'monitor-activity' /tmp/s2_region.txt                # Expected: 1 (the §12 citation)
grep -c 'resident process per pane' /tmp/s2_region.txt       # Expected: 1 (≠ "one resident process")
grep -c 'the opposite of what toggle needs' /tmp/s2_region.txt  # Expected: 1
grep -c 'self-heals on the next switch' /tmp/s2_region.txt   # Expected: 1

# E. File-wide "one resident process" (old false claim) is gone; "resident process
#    per pane" (new §12 clause) is present — these are DIFFERENT strings:
grep -c 'one resident process' README.md          # Expected: 0
grep -c 'resident process per pane' README.md     # Expected: 1

# F. Boundary preservation — the lines immediately ABOVE and BELOW the edit are byte-identical:
diff <(sed -n '119,122p' /tmp/region_before_m3t1s2.txt) <(sed -n '119,122p' README.md) && echo "ABOVE BOUNDARY OK"
# Expected: empty diff + "ABOVE BOUNDARY OK" (S1's Walking tail + the blank S1↔S2 boundary).
diff <(sed -n '142,145p' /tmp/region_before_m3t1s2.txt) <(sed -n '134,137p' README.md) && echo "BELOW BOUNDARY OK"
# Expected: empty diff + "BELOW BOUNDARY OK" (the blank separator + close-current head,
# shifted up by 8 lines: 142->134, 143->135).

# G. Scope guard — sibling-owned regions are untouched:
grep -c '@session-history-dwell-ms` | `10000`' README.md   # Expected: 1 (T2.S1 hasn't landed
                                                           # yet — the 10000 row is NOT this task)
grep -c 'produce output in it while viewing it' README.md  # Expected: 1 (T2.S2 hasn't landed
                                                           # yet — Troubleshooting is NOT this task)
# These assert you did NOT accidentally edit sibling-owned regions.
```

### Level 3: Integration Testing (System Validation)

There is no runtime component to a README prose edit (Markdown is not executed),
so the "integration test" is a **rendered-preview + cross-reference** check:
confirm the edited section renders as two well-separated paragraphs (no leftover
bolded subsection heading), and that the README's async-path model now matches
PRD §8 word-for-word (dwell is the sole async path).

```bash
# A. Render the edited "How it works" async-paths block as it would appear on GitHub.
sed -n '121,137p' README.md
# Expected (manual review): S1's Walking paragraph tail (121) ending "...oscillating
# between A and B.", a blank (122), a 6-line "dwell is the only async path" paragraph
# (123-128), a blank (129), a 4-line §12 sentence (130-133) ending "...the opposite of
# what toggle needs.", a blank (134), then the close-current paragraph (135+) starting
# "When a session closes…". NO "**How activity detection works.**" heading anywhere.

# B. Cross-reference: README's async-path claim == PRD §8's "one asynchronous path".
echo "--- README async-path claim ---"
sed -n '/^The dwell timer is the only asynchronous/,/timers are harmless/p' README.md | head -1
echo "--- PRD §8 claim ---"
grep -m1 'one asynchronous path' PRD.md
# Expected: README says "The dwell timer is the only asynchronous path"; PRD §8 says
# "Dwell is the one asynchronous path." They correspond 1:1. No second async path.

# C. Cross-reference: README no longer claims output/activity promotes (PRD §12 says not wired).
echo "--- README whole 'How it works': any 'activity promotes' / 'produce output there' claim? (expect none) ---"
sed -n '/^## How it works/,/^## Requirements/p' README.md | grep -iE 'activity promotes|focused-activity|produce output there|one resident process'
# Expected: NO output. PRD §12: "It is therefore not wired. Relevance comes from selection and dwell only."

# D. Git diff review — the change is a single, scoped hunk.
git diff README.md
# Manually confirm:
#   - the '-' side is EXACTLY post-S1 lines 123-141 (subsection + blank + paragraph).
#   - the '+' side is the 11-line dwell-only paragraph + blank + §12 sentence.
#   - NOTHING above line 123 (S1's region) or below line 141 changed: the blank at 122
#     and the blank at 142 appear UNCHANGED — no +/- prefix; the close-current paragraph
#     at 143 appears UNCHANGED.
#   - If you see a change to old line 86 (Options table) or old ~179-181 (Troubleshooting)
#     or S1's region (106-121), you have crossed into a sibling's scope — revert.
# Expected: one hunk, roughly -19/+11 (markdown diff may group context lines; net -8).
```

### Level 4: Creative & Domain-Specific Validation

```bash
# A. Whole-file consistency snapshot — how many activity-detection phrases remain
#    and WHERE (informational; S2 does NOT zero the whole file — T2.S1/T2.S2 do their parts):
echo "=== 'How activity detection works' (the deleted heading) — expect ZERO file-wide ==="
grep -c 'How activity detection works' README.md    # Expected: 0
echo "=== 'client_activity' (the deleted timestamp) — expect ZERO file-wide ==="
grep -c 'client_activity' README.md                 # Expected: 0
echo "=== 'monitor-activity' (the §12 citation, INTENTIONAL) — expect 1 ==="
grep -c 'monitor-activity' README.md                # Expected: 1 (S2's new region)
echo "=== remaining bare 'activity' substring occurrences (informational) ==="
grep -ni 'activity' README.md | head -30
# Expected: 'activity' NO LONGER appears in the "How it works" 123-141 span as a
# FEATURE reference; it appears ONLY inside 'monitor-activity' (S2's §12 citation).
# It still appears in Troubleshooting (T2.S2's region) until that lands. This is correct.

# B. The §12 sentence is grounded in the spec:
grep -n 'no robust tmux primitive' PRD.md           # §12 — the exact authority
grep -n 'alert-activity' PRD.md | head -2           # §12 — background-only limitation
grep -n 'selection and dwell only' PRD.md           # §12 — the closing rule
# Expected: all present. The §12 sentence's claims are each grounded in PRD §12.

# C. The dwell-is-sole-async-path claim is grounded in the spec:
grep -n 'one asynchronous path' PRD.md              # §8 — "Dwell is the one asynchronous path"
grep -n 'touch ONLY' PRD.md | head -2               # §13 — "touch ONLY tlist"
# Expected: all present.

# D. The edit is minimal and scoped in git:
git diff --stat README.md
# Expected: a single file. Net ≈ -8 lines. One hunk.

# E. Final whole-region token sweep (the authoritative S2 gate — EXACT phrases only):
sed -n '/^The dwell timer is the only asynchronous/,/the opposite of what toggle needs/p' README.md \
  | grep -niE 'How activity detection works|focused-activity detection|activity promotes|client_activity|background poller|poller|one resident process|produce output there|per-pane pipes|~0.5'
# Expected: NO output. S2's region is free of activity-detection narrative.
echo "LEVEL 4 DONE"
```

## Final Validation Checklist

### Technical Validation

- [ ] `wc -l README.md` == **184** (was 192; −8).
- [ ] `grep -c 'How activity detection works' README.md` == **0** (subsection gone).
- [ ] `grep -c 'client_activity' README.md` == **0** (timestamp ref gone).
- [ ] `grep -c 'focused-activity detection' README.md` == **0** (false clause gone).
- [ ] The S2 region (`sed -n '/^The dwell timer is the only asynchronous/,/the opposite of what toggle needs/p'`)
      contains **zero** matches for the EXACT phrases: `How activity detection works`,
      `focused-activity detection`, `activity promotes`, `client_activity`,
      `background poller`, `poller`, `one resident process`, `produce output there`,
      `per-pane pipes`, `~0.5`, `keystroke you send`, `direct signal for`.
- [ ] The S2 region contains `only asynchronous path`, `monitor-activity`,
      `resident process per pane`, `self-heals on the next switch`, and
      `the opposite of what toggle needs`.
- [ ] `grep -c 'one resident process' README.md` == **0** AND
      `grep -c 'resident process per pane' README.md` == **1** (distinct strings).

### Feature Validation

- [ ] The "**How activity detection works.**" heading is **entirely absent** from README.md.
- [ ] The async-paths paragraph states dwell is the **only** asynchronous path
      touching only the relevance list (never the timeline), matching PRD §8.
- [ ] The §12 sentence is present, citing `monitor-activity`'s background-only
      limitation as the reason there is no output signal (PRD §12).
- [ ] The new region renders as two plain paragraphs (a dwell paragraph and a §12
      sentence) separated by a blank — no leftover bolded subsection heading.
- [ ] Cross-reference: README's async-path claim corresponds 1:1 to PRD §8's "one
      asynchronous path" (dwell). No second async path.

### Code Quality Validation

- [ ] The git diff is a single hunk on the post-S1 lines 123–141 region; nothing else.
- [ ] Old line 122 (blank, S1↔S2 boundary) and old line 142 (blank, before
      close-current) are byte-identical (shifted up by 8 only).
- [ ] S1's Walking paragraph tail (old line 121) and the close-current paragraph
      (old line 143+) are byte-identical.
- [ ] UTF-8 em-dash (—, U+2014) in the newText is preserved (not downgraded to `--`).
- [ ] Straight quotes in the newText (you're, you've, tmux's, "the focused session
      produced output") — ZERO curly quotes introduced.
- [ ] No "drive-by" fixes; no edit to S1's region (old 106–121), the Options table
      (old line 86, T2.S1), the close-current/sessionx/capping paragraphs (old 143+),
      or Troubleshooting (old ~179–181, T2.S2).
- [ ] Edit is anchored on the full oldText text (both anchors globally unique), not
      the line numbers 123/141.

### Documentation & Deployment

- [ ] This edit IS the documentation (Mode A — README "How it works" async-paths region).
- [ ] The README "How it works" section now matches PRD §8 (dwell is the sole async
      path) and nods to PRD §12 (why there is no output signal), with no
      activity-detection subsection.
- [ ] No new options, hooks, bindings, or environment variables introduced.

---

## Anti-Patterns to Avoid

- ❌ **Do NOT touch old line 122 (blank, S1↔S2 boundary) or old line 142** (blank,
  before close-current). The oldText must START at old line 123
  ("**How activity detection works.**") and END at old line 141 ("...so stale
  timers are harmless."). The blank at 122 is the boundary keeping this task
  disjoint from S1 (which has already landed); the blank at 142 keeps it disjoint
  from the close-current paragraph.
- ❌ **Do NOT gate on bare `grep activity README.md` == 0 or bare `output`.** The
  new region LEGITIMATELY contains `monitor-activity` (substring "activity") and
  "produced output" (in the §12 sentence explaining why there is NO detection).
  Gate on the EXACT activity-detection phrases listed in Level 2, scoped to the
  edit region. Also, "activity"-adjacent text still appears in Troubleshooting
  (T2.S2's region) until that lands.
- ❌ **Do NOT confuse "one resident process" (old, to delete) with "resident
  process per pane" (new, the §12 clause).** They are distinct strings. After the
  edit, `grep 'one resident process'` must be 0 and `grep 'resident process per
  pane'` must be 1.
- ❌ **Do NOT confuse "produce output there" (old, to delete) with "produced
  output" (new, the §12 clause).** The old false claim ("The moment you produce
  output there, activity promotes it instead") must be gone; the new clause ("no
  robust tmux primitive for 'the focused session produced output'") must be
  present. Gate on the full phrase "produce output there", never on bare "output".
- ❌ **Do NOT mention `client_activity`, `background poller`, `poller`,
  `focused-activity`, `activity promotes`, `one resident process`, `per-pane
  pipes`, `~0.5–1 s`, `keystroke`, or `direct signal` in the newText** — not even
  in an explanatory "we used to detect typing" note. The region must contain
  *zero* activity-detection FEATURE narrative. The §12 sentence explains *why*
  there is no signal (citing `monitor-activity`'s limitation), which is the
  opposite of documenting a feature.
- ❌ **Do NOT introduce curly quotes.** The file uses ALL STRAIGHT quotes (verified:
  0 curly apostrophes/quotes file-wide). The newText must use straight `'` (you're,
  you've, tmux's) and straight `"` ("the focused session produced output"). Beware
  editor "smart quote" auto-correct.
- ❌ **Do NOT split this into two edits** (delete subsection, then rewrite
  paragraph) when one combined edit is feasible. The region (123–141) is
  contiguous and both anchors are globally unique; one atomic replacement gives a
  clean single-hunk diff and a deterministic −8 line count.
- ❌ **Do NOT edit S1's region** (promotion bullets + Walking paragraph, old
  106–121). S1 has already landed; re-editing it is out of scope and risks
  clobbering S1's byte-accurate newText.
- ❌ **Do NOT edit the Options table** (old line 86, T2.S1), **the close-current /
  sessionx / capping paragraphs** (old 143+), or **Troubleshooting** (old ~179–181,
  T2.S2). Those are sibling-owned and disjoint.
- ❌ **Do NOT key the edit on the hard line number `123`.** Always match the full
  TEXT of the opening line "**How activity detection works.** When toggle is bound
  the plugin watches the" and the closing line "timer self-cancels if you've moved
  on, so stale timers are harmless." Line numbers are for orientation (post-S1),
  not anchoring.
- ❌ **Do NOT reformat surrounding lines or "fix" the em-dash style elsewhere.**
  Preserve UTF-8 em-dashes (—) exactly; preserve the straight-quote style. The edit
  is the 123–141 region only.
- ❌ **Do NOT proceed if `wc -l README.md` is NOT 192.** That means S1 has not
  landed (or something else changed). Surface the discrepancy rather than editing
  on top of an unexpected state.