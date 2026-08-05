name: "P1.M3.T2.S2 — Update README Troubleshooting section to remove activity/output references (selection + dwell only)"
description: "Exact-text replacement of the single 'wrong session' paragraph in README.md's ## Troubleshooting section (currently physical lines 170-174 of the 184-line file — doc_impact's '185-189' is from the pre-S1/S2 192-line file; ANCHOR ON TEXT not line numbers). The paragraph currently says a session enters the relevance list 'when you select it, produce output in it while viewing it, or dwell on it' and that walked-past sessions are skipped '(unless you then produce output in them)' — both reference the removed output-activity signal. Rewrite to the selection+dwell-only model from plan/001_ca41c05f3ead/architecture/doc_impact.md §7: 'a session enters the relevance list only when you select it or dwell on it long enough. Walked-past sessions are intentionally skipped — if you want a silent walk to "stick" sooner, lower @session-history-dwell-ms (or set it to 0 and only direct selections will ever count).' Executed as ONE atomic paragraph replacement (oldText = the 5 wrapped lines; newText = the 5 wrapped lines). Net Δ0 lines (README 184 → 184). The status/reset debug helpers (lines 156-168) have NO activity references and are byte-identical preserved. Typography preserved per doc_impact §7: *relevance* italics, backticked `@session-history-dwell-ms` and `0`, ONE U+2014 em-dash, straight quotes — resolving the item-description-paraphrase-vs-doc_impact-markdown discrepancy identically to T2.S1. INPUT: README.md after the How-it-works rewrite (T1.S1/S2 DONE) AND after the Options-table update (T2.S1 DONE — 30000 already landed). This IS the doc update (Mode A — README section directly touched by the relevance-model change). Sibling regions (How-it-works, Options table) are DONE and disjoint; only the Troubleshooting 'wrong session' paragraph is in scope."

---

## Goal

**Feature Goal**: Bring the README **Troubleshooting** section's "wrong session"
guidance paragraph into alignment with the PRD's selection+dwell-only relevance
model (PRD §6 / §2) — by removing both references to the removed output-activity
promotion signal ("produce output in it while viewing it" and "unless you then
produce output in them") and replacing them with a selection+dwell-only
explanation that also folds in the `@session-history-dwell-ms` tuning advice and
the `0`-disables-dwell escape hatch.

**Deliverable**: An edited `README.md` in which the single Troubleshooting
"wrong session" paragraph reads exactly as the newText in the "What" section
(selection + dwell only, with the dwell-ms / `0` advice). Everything else in
README.md — the status/reset debug helpers, the code block, the just-landed
Options-table `30000` row, the already-landed "How it works" dwell-only text,
Requirements, Limitations, License — is byte-identical.

**Success Definition**:
1. README.md's Troubleshooting section contains **zero** occurrences of `produce`
   (the two removed phrases "produce output in it while viewing it" and "unless
   you then produce output in them" are both gone).
2. README.md's Troubleshooting section **does** contain the selection+dwell-only
   phrase `a session enters the relevance list only when you select it or dwell
   on it long enough`.
3. README.md's Troubleshooting section **does** contain the `0`-escape-hatch
   phrase `only direct selections will ever count`.
4. `README.md` is **184** lines (unchanged — 5 wrapped lines in, 5 out; Δ0).
5. The status/reset debug helpers and the `…/session_history.sh status` code
   block are byte-identical (zero activity references there, so they must be
   untouched).
6. The only file-wide "activity" token left is `monitor-activity` on line ~132
   (the PRD §12 sentence explaining the *absence* of an output signal — correct,
   KEEP). No new stray activity references are introduced.

## User Persona (if applicable)

**Target User**: A plugin user (tmux power-user) who has bound the toggle key,
pressed it, and felt it targeted the "wrong" session — and who scrolls to the
README **Troubleshooting** section to understand why.

**Use Case**: The user walked the timeline back through several sessions, pressed
toggle, and did NOT flip to the session adjacent to where they landed — they
flipped to a session much earlier in their history (the one they were "actually
using"). Confused, they open README → Troubleshooting. Today the paragraph tells
them relevance comes from selecting a session, **producing output in it while
viewing it**, or dwelling — but the engine (post-P1.M1) **no longer has** an
output-activity signal, so that explanation describes behavior the plugin does
not exhibit. After this edit the paragraph tells the truth: relevance comes only
from selection or dwell, walked-past sessions are skipped by design, and the user
can lower `@session-history-dwell-ms` (or set `0`) to change the behavior.

**User Journey**: User opens README → scrolls to `## Troubleshooting` → reads the
`status`/`reset` helper notes (unchanged) → reads the "wrong session" paragraph.
After the edit, that paragraph matches what they observe: walking never promotes,
only selecting or dwelling does, and dwell is tunable.

**Pain Points Addressed**: Today the Troubleshooting paragraph (a) advertises an
output-activity promotion path that no longer exists (removed in P1.M1.T1), so a
user who expects "producing output in a walked-to session" to promote it is
confused when it does not; and (b) is inconsistent with the rest of the README
(the Options table — now T2.S1 — and "How it works" — T1.S1/S2 — both already
describe selection+dwell only). The rewrite reconciles Troubleshooting with both
the engine and the other README sections.

## Why

- **Spec compliance — relevance model (PRD §6 / §2).** PRD §6 lists exactly two
  promotion causes: direct selection and dwell. PRD §2's key invariant: "Walking
  moves the history cursor but never touches the relevance list. Selecting or
  dwelling promotes." The Troubleshooting paragraph's "produce output in it while
  viewing it" describes a **third** cause the PRD does not have and the engine no
  longer implements; the rewrite reduces it to selection + dwell.
- **Spec compliance — why no output signal (PRD §12).** PRD §12 is dedicated to
  "Why there is no output-activity signal." The README's How-it-works section
  (T1.S2, DONE) already carries the §12 sentence. The Troubleshooting paragraph
  must not contradict it by re-asserting that producing output promotes.
- **Internal consistency (doc_impact §1e, §7).** doc_impact §1e flags the
  Troubleshooting paragraph as **Medium severity (misleads debugging)** because
  both "produce output in it while viewing it" and "unless you then produce
  output in them" reference the removed signal. §7 gives the exact target
  rewrite this PRP adopts verbatim.
- **Decomposition ownership (gap_analysis GAP 9f).** This is GAP 9f of
  `architecture/gap_analysis.md`: the Troubleshooting activity-reference cleanup.
  Siblings T1.S1 (GAP 9b/9c — promotion bullets + Walking paragraph, DONE),
  T1.S2 (GAP 9d/9e — activity-detection subsection + async paragraph, DONE), and
  T2.S1 (GAP 2d/9a — Options-table default + row description, DONE) have all
  landed. **T2.S2 is the last README activity-reference cleanup.**
- **Mode A documentation.** This **is** the doc update for the Troubleshooting
  paragraph — a user-facing README region directly touched by the relevance-model
  change. No separate docs subtask.

## What

A single exact-text replacement of **one logical paragraph** (currently wrapped
across 5 physical lines, 170-174) in `README.md`'s `## Troubleshooting` section.
The line numbers below are illustrative (doc_impact's "185-189" predates the
S1/S2 shrink from 192→184 lines); **anchor on the paragraph's text, not line
numbers** — see Gotchas.

> **Input state.** README.md is currently **184** lines. P1.M3.T2.S1 (Options
> table `10000`→`30000` + description rewrite) has ALREADY landed — verified:
> `grep -c '10000' README.md` → 0; `grep -c '30000' README.md` → 1. So the
> Options table already advertises `30000` and the selection+dwell-only model.
> The input to this task is the 184-line README with a fully dwell-only "How it
> works" section (T1.S1/S2 DONE) and a corrected Options table (T2.S1 DONE).

### The paragraph being replaced (oldText — 5 wrapped lines)

```
If toggle seems to target the "wrong" session, remember it tracks *relevance*,
not recency: a session enters the relevance list when you select it, produce
output in it while viewing it, or dwell on it. Walked-past sessions are
intentionally skipped (unless you then produce output in them). Lower
`@session-history-dwell-ms` if you want silent walks to "stick" sooner.
```

- Opening anchor (globally unique, `grep -c` = 1):
  `If toggle seems to target the "wrong" session`.
- It is a single markdown paragraph wrapped at ~76-79 cols (line 1 is the
  longest at 79 chars). Replacing the whole wrapped block keeps the section
  intact. Note "produce output in it while viewing it" **wraps across two
  physical lines** (171→172); this is why validation greps are scoped to the
  section, not matched on a single line.

### The replacement (newText — 5 wrapped lines, from doc_impact.md §7)

```
If toggle seems to target the "wrong" session, remember it tracks *relevance*,
not recency: a session enters the relevance list only when you select it or
dwell on it long enough. Walked-past sessions are intentionally skipped — if
you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`
(or set it to `0` and only direct selections will ever count).
```

- Sourced verbatim from `architecture/doc_impact.md` §7, the curated PRD-aligned
  target text, wrapped to match the file's existing ~76-79 col style (5 physical
  lines in → 5 physical lines out = **Δ0**, README stays 184).
- Preserves the file's typography: `*relevance*` italics (already on current
  line 170), backticked `` `@session-history-dwell-ms` `` (already on current
  line 174), adds `` `0` `` backticks (consistent with T2.S1's Options row and
  S1's How-it-works bullet), straight `"wrong"`/`"stick"` quotes.
- Introduces exactly **one** U+2014 em-dash: `skipped — if you want`.

### What the newText says (clause-by-clause → PRD authority)

- **"a session enters the relevance list only when you select it or dwell on it
  long enough"** → PRD §6 (exactly two promotion causes: selection + dwell) +
  PRD §2 key invariant (selecting/dwelling promotes; walking never does).
  Replaces the deleted "when you select it, **produce output in it while viewing
  it**, or dwell on it" — drops the output-activity cause entirely.
- **"Walked-past sessions are intentionally skipped"** → PRD §6 ("Walking never
  promotes"). Unchanged in substance.
- **"if you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`"**
  → PRD §8 (dwell is the walk-dwell threshold; lowering it makes walked-to
  sessions promote sooner). Re-ordered from the old trailing sentence; note
  `silent walks` (plural) → `a silent walk` (singular) and `Lower` → `lower`
  (now mid-sentence after the em-dash) — intentional, do not "restore" old forms.
- **"(or set it to `0` and only direct selections will ever count)"** → PRD §8
  arming (`if ms <= 0: return`; "0 disables dwell entirely"). New clause that
  gives users the explicit `0` escape hatch (relevance from selection only),
  mirroring the Options-table row T2.S1 just landed.

### Wording-discrepancy resolution: item description vs doc_impact §7

The orchestrator item description paraphrases the rewrite in **plain text**
(`remember it tracks relevance`, `lower @session-history-dwell-ms`, `set it to
0`) — i.e. it drops the markdown markers. `doc_impact.md` §7 keeps them
(`*relevance*`, `` `@session-history-dwell-ms` ``, `` `0` ``). They are
**substance-identical**; only typography differs.

**Use the doc_impact §7 version (newText above).** This is the identical
discrepancy P1.M3.T2.S1 resolved for the Options-table row, resolved the same
way (doc_impact typography wins), because: (1) the CURRENT Troubleshooting
paragraph already uses `*relevance*` and backticked `@session-history-dwell-ms`;
(2) T2.S1's Options row and S1's How-it-works bullet both use `` `0` `` backticks
— keeping them is internally consistent; (3) the README's house style is
straight quotes + U+2014 em-dashes + backticked option names + asterisk emphasis.

### What is NOT changed (byte-identical, preserved)

- The `status`/`reset` debug helper bullets and the `…/session_history.sh status`
  code block (lines ~156-168) — KEEP (zero activity references; the task contract
  explicitly says they need no change).
- The `## Troubleshooting` heading, the "The engine script has helpers for
  debugging:" intro, and the "Run them through the script…" sentence — KEEP.
- The already-landed Options-table dwell-ms row (`` `30000` `` — T2.S1, DONE).
- The already-landed "How it works" text incl. the §12 `monitor-activity`
  sentence (T1.S1/S2, DONE).
- Everything else (title, intro, Why, Features, Install, Keys, Options header +
  other rows, Requirements, Limitations, License).

### Success Criteria

- [ ] Troubleshooting-scoped `grep -c 'produce'` → **0** (both removed phrases
      gone). NOTE: scope to the section, because "produce output in it while
      viewing it" wraps across two physical lines and a line-anchored grep is a
      false-negative trap.
- [ ] Troubleshooting-scoped `grep -c 'while viewing it'` → **0**.
- [ ] Troubleshooting-scoped `grep -c 'unless you then'` → **0**.
- [ ] Troubleshooting-scoped `grep -c 'the relevance list only when you select
      it or dwell on it long enough'` → **1**.
- [ ] Troubleshooting-scoped `grep -c 'only direct selections will ever count'`
      → **1**.
- [ ] `wc -l README.md` → **184** (unchanged; Δ0).
- [ ] status/reset helpers preserved: Troubleshooting-scoped `grep -c 'status\`
      prints'` → **1** and `grep -c 'reset\` clears'` → **1**.
- [ ] `grep -n 'monitor-activity' README.md` → still exactly **1** hit on line
      ~132 (the §12 sentence — KEEP, do NOT remove).

## All Needed Context

### Context Completeness Check

**Yes.** This PRP supplies: the exact 5-line oldText (captured byte-accurately
via `cat -A`, including the `*relevance*` italics and backticked
`@session-history-dwell-ms`, and flagging that "produce output in it while
viewing it" wraps across two physical lines); the exact 5-line newText (verbatim
from `doc_impact.md` §7, wrapped to match file style, Δ0); the precise scope
(the Troubleshooting "wrong session" paragraph only — disjoint from the
status/reset helpers, the Options table, How-it-works, Limitations); input-state
confirmation that T1.S1/S2 AND T2.S1 have all landed (README is 184 lines,
`30000` already present, `10000` gone); the text-anchor strategy (the paragraph's
opening is globally unique); the section-scoped validation design that sidesteps
the line-wrapping false-negative trap; and the companion code-status confirmation
that the engine has no activity signal (P1.M1.T1 removed `do_activity`/`do_poller`,
Complete). An implementer with zero prior knowledge of this codebase can do it in
one pass.

### Documentation & References

```yaml
# MUST READ — the exact target newText for the paragraph
- docfile: plan/001_ca41c05f3ead/architecture/doc_impact.md
  section: "§7. Troubleshooting section — activity/typing/output references"
  why: "§7 gives the EXACT target paragraph this PRP adopts verbatim (the
        'a session enters the relevance list only when you select it or dwell on
        it long enough … lower @session-history-dwell-ms (or set it to 0 …)'
        version). §1e flags the current paragraph as Medium severity
        ('misleads debugging') and enumerates the two phrases to DROP: 'produce
        output in it while viewing it' and '(unless you then produce output in
        them)'. §7 also confirms the status/reset helpers (its 'lines 173-183')
        have NO activity references and need no change."
  critical: "Use §7's text verbatim (with its markdown typography). §1e enumerates
             the exact phrases to DROP. NOTE: doc_impact's line numbers (185-189,
             173-183) are from the PRE-S1/S2 192-line file; the section is now at
             ~156-174 of the 184-line file. Anchor on TEXT (the paragraph's
             'If toggle seems to target the "wrong" session' opening is globally
             unique), never line numbers."

# MUST READ — the relevance model authority (selection + dwell only)
- docfile: PRD.md
  section: "§6. Relevance — what promotes and what doesn't (and §2 Key invariant)"
  why: "PRD §6: a session is promoted by exactly two causes — (1) direct
        selection, (2) dwell. 'Walking never promotes.' PRD §2 key invariant:
        'Walking moves the history cursor but never touches the relevance list.
        Selecting or dwelling promotes in the relevance list.' The paragraph's
        'a session enters the relevance list only when you select it or dwell on
        it long enough' encodes this."
  critical: "There is NO third 'produce output promotes' cause. That clause (from
             the old paragraph) presupposes the removed output-activity signal.
             The rewrite drops it entirely."

# MUST READ — why no output-activity signal (the §12 sentence stays)
- docfile: PRD.md
  section: "§12. Why there is no output-activity signal"
  why: "PRD §12 explains the design decision: there is no robust tmux primitive
        for 'the focused session produced output' without a resident process per
        pane, and tmux's monitor-activity only sees background windows. The README
        How-it-works §12 sentence (T1.S2, DONE) already documents this. The
        Troubleshooting paragraph must not contradict it by re-asserting output
        promotion."
  critical: "The file-wide 'monitor-activity' token (README ~line 132, inside the
             §12 sentence) is the EXPLANATION of the absence and is CORRECT. Do
             NOT treat it as an activity reference to remove — it stays. Only the
             Troubleshooting 'produce output' phrases are in scope."

# MUST READ — dwell arming & the 0-disables semantics
- docfile: PRD.md
  section: "§8. Dwell — Arming (and h3.8) + §15 Configuration reference"
  why: "PRD §8 arm_dwell: 'if ms <= 0: return  # 0 disables dwell entirely.' PRD
        §15: '@session-history-dwell-ms | 30000 | Walk-dwell threshold; 0 disables
        dwell.' The paragraph's '(or set it to 0 and only direct selections will
        ever count)' is the user-facing version of the if ms <= 0: return guard."
  critical: "Only a WALK arrival arms a dwell timer (§8). The paragraph's
             'silent walk to stick' framing is correct — walking never promotes by
             itself; only dwelling on a walked-to session does."

# MUST READ — the byte-accurate capture (source of truth for oldText/newText fidelity)
- docfile: plan/001_ca41c05f3ead/P1M3T2S2/research/troubleshooting_byte_capture.md
  why: "This research note captures: the exact byte-accurate old paragraph
        (cat -A verified, including the line-wrapping of 'produce output in it
        while viewing it' across two physical lines); the input-state proof that
        T2.S1 has landed (30000 present, 10000 gone, README 184 lines); the
        section-scoped validation design that avoids the wrapping false-negative
        trap; the em-dash byte proof (U+2014 = E2 80 94); the
        item-description-vs-doc_impact typography resolution; the scope boundary
        table vs. sibling regions; and the deterministic grep proofs."
  critical: "The edit is ONE atomic replacement of the whole wrapped paragraph
             (5 physical lines). Do NOT try to edit only the changing sub-clause
             ('when you select it, produce output in it while viewing it, or dwell
             on it' spans lines 171-172 and wraps awkwardly) — replace the full
             5-line oldText with the full 5-line newText for a clean, unambiguous,
             Δ0 single-hunk diff. The paragraph opening is the unique anchor."

# The file under edit
- file: README.md
  why: "The ONLY file this task modifies. GitHub-flavored Markdown, UTF-8.
        QUOTES ARE ALL STRAIGHT: 0 curly single (U+2018/U+2019) and 0 curly double
        (U+201C/U+201D) in the whole file (verified); the existing paragraph uses
        straight \"wrong\" and \"stick\". Em-dashes are U+2014 (E2 80 94). The
        current 'wrong session' paragraph (lines 170-174) uses the file's existing
        typography: *relevance* italics and backticked `@session-history-dwell-ms`."
  pattern: "README prose paragraphs are wrapped at ~76-79 cols; inline code for
            option names (backticks); *emphasis* for contrast words; straight
            double quotes for quoted UI phrases; U+2014 em-dashes for asides. The
            newText FOLLOWS this style exactly — same wrapping width, backticked
            option, *relevance* emphasis, straight quotes, one em-dash aside."
  gotcha: "The em-dash is UTF-8 U+2014 (bytes E2 80 94; cat -A shows M-bM-^@M-^T).
           The newText has ONE em-dash ('skipped — if you want'). Use U+2014, NOT
           '--' or ASCII '-'. Quotes: straight only. The newText's *relevance*,
           `@session-history-dwell-ms`, and `0` are NOT optional — they match the
           file's existing paragraph typography (and T2.S1's Options row) and keep
           the README internally consistent."

# The sibling README tasks (CONTRACTS — all disjoint regions)
- docfile: plan/001_ca41c05f3ead/P1M3T1S1/PRP.md
  why: "T1.S1 owns the How-it-works promotion bullets + Walking paragraph (DONE).
        Its region is ABOVE Troubleshooting and does not touch lines 170-174."
  critical: "Do NOT re-edit T1.S1's region. It is done."
- docfile: plan/001_ca41c05f3ead/P1M3T1S2/PRP.md
  why: "T1.S2 owns the How-it-works async-paths paragraph + §12 sentence (DONE).
        Its region contains the file's only 'monitor-activity' token (~line 132),
        which is the EXPLANATION of the absence of an output signal — correct and
        KEEP. Because S2 has landed, the current on-disk README (184 lines, with
        the §12 sentence present) is this task's actual input."
  critical: "Do NOT re-edit T1.S2's region or remove its 'monitor-activity' token.
             T1.S2 is done. If `wc -l README.md` is NOT 184 or
             `grep -c 'How activity detection works' README.md` is NOT 0, S2 may
             not have landed — STOP and surface the discrepancy instead of editing."
- docfile: plan/001_ca41c05f3ead/P1M3T2S1/PRP.md
  why: "T2.S1 owns the Options-table dwell-ms row (DONE — `30000` already landed).
        Its region (line 86) is far ABOVE Troubleshooting and disjoint. Because
        T2.S1 is Δ0 (one row in / one out), it did not shift Troubleshooting's
        line numbers."
  critical: "Do NOT re-edit the Options table. If `grep -c '10000' README.md` is
             NOT 0 or `grep -c '30000' README.md` is NOT 1, T2.S1 may not have
             landed — STOP and surface the discrepancy instead of editing. (Note:
             at PRP-write time T2.S1 has already landed on disk.)"

# The code state this doc aligns to (CONTRACTS — already Complete)
- file: scripts/session_history.sh
  why: "P1.M1.T1 removed do_activity()/do_poller()/do_start_poller() and the
        activity/poller case-dispatch branches (Complete). There is NO
        output-activity signal in the engine, so the README's Troubleshooting must
        not claim one."
  critical: "This PRP does NOT edit the engine. The engine has no activity signal
             already. No code change is needed for this doc edit to be accurate —
             only the README paragraph is stale."
```

### Current Codebase tree

```bash
.
├── PRD.md                      # spec (READ-ONLY) — §6/§2/§8/§12/§15 authorize this edit
├── README.md                   # ← THE FILE TO EDIT (184 lines, post-T1.S1/S2 + T2.S1)
│                                #     line  86 = @session-history-dwell-ms row (T2.S1 DONE: `30000`)
│                                #   ~line 132 = §12 sentence w/ `monitor-activity` (T1.S2 DONE; KEEP)
│                                #     line 156 = "## Troubleshooting"
│                                #   lines 158-168 = status/reset helpers + code block (KEEP)
│                                #   lines 170-174 = "wrong session" paragraph (THE EDIT)
│                                #     line 176 = "## Limitations"
├── LICENSE
├── scripts/
│   └── session_history.sh      # engine — NO activity signal (P1.M1.T1 removed it; Complete)
├── session_history.tmux        # entry point — dwell default 30000 (P1.M2.T1.S1 done)
└── plan/
    └── 001_ca41c05f3ead/
        ├── architecture/doc_impact.md              # ← §7 = exact newText; §1e = phrases to drop
        ├── architecture/gap_analysis.md            # ← GAP 9f (Troubleshooting activity refs)
        ├── prd_snapshot.md                         # full PRD (READ-ONLY)
        ├── P1M3T1S1/PRP.md                         # ← sibling, DONE (promotion bullets)
        ├── P1M3T1S2/PRP.md                         # ← sibling, DONE (async-paths + §12 sentence)
        ├── P1M3T2S1/PRP.md                         # ← sibling, DONE (Options `30000` row)
        └── P1M3T2S2/
            ├── PRP.md                              # ← THIS task
            └── research/troubleshooting_byte_capture.md  # byte-accurate old para + scope + proofs
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
# No files added. Only README.md is modified.
# After this task the file is STILL 184 lines (5 wrapped lines replaced by 5
# wrapped lines; Δ0). The single change: the Troubleshooting "wrong session"
# paragraph (lines 170-174) is rewritten from the activity-presupposing text to
# the selection+dwell-only model. All other lines byte-identical, including the
# status/reset helpers, the Options table, How-it-works, Requirements,
# Limitations, License.
```

### Known Gotchas of our codebase & Library Quirks

```markdown
<!-- CRITICAL — T1.S1, T1.S2, AND T2.S1 have ALL LANDED. The input is the
     184-line README with a dwell-only "How it works", a `30000` Options row, and
     NO "How activity detection works" heading. Verify before editing:
     `wc -l README.md` → 184;
     `grep -c 'How activity detection works' README.md` → 0;
     `grep -c '10000' README.md` → 0 (T2.S1 landed);
     `grep -c '30000' README.md` → 1 (T2.S1 landed).
     If any of these fail, a sibling may not have landed — STOP and surface the
     discrepancy instead of editing. -->

<!-- CRITICAL — anchor on TEXT, never line numbers. doc_impact's "lines 185-189"
     are from the PRE-S1/S2 192-line file; the paragraph is now at ~170-174 of the
     184-line file. The paragraph opens with 'If toggle seems to target the "wrong"
     session' which is globally unique. Use the full 5-line oldText for the
     replacement; do NOT key on a line number. -->

<!-- CRITICAL — execute as ONE combined edit (the whole wrapped paragraph), NOT a
     sub-clause edit. The removed phrase "when you select it, produce output in it
     while viewing it, or dwell on it" wraps across physical lines 171-172, so
     matching only that sub-string is fragile and would leave a malformed partial
     paragraph. A single full-paragraph oldText→newText replacement is atomic,
     unambiguous (unique opening anchor), Δ0, and yields a clean single-hunk diff. -->

<!-- CRITICAL — VALIDATION TRAP: "produce output in it while viewing it" wraps
     across two physical lines, so a line-anchored `grep 'produce output'` returns
     0 EVEN BEFORE the edit (false negative). Scope every Troubleshooting check to
     the section:
         sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'
     (pre-edit → 2: line 171 "select it, produce" + line 173 "produce output in
     them"; post-edit → 0). Do NOT rely on a file-wide single-line grep. -->

<!-- CRITICAL — quotes are ALL STRAIGHT. The whole file has 0 curly quotes
     (verified). The newText keeps straight "wrong" and "stick" (already in the
     current paragraph). Do NOT introduce curly quotes (a common editor "smart
     quote" auto-correct). -->

<!-- CRITICAL — the em-dash is UTF-8 U+2014 (bytes E2 80 94; cat -A shows
     M-bM-^@M-^T). The newText has ONE em-dash: "skipped — if you want". Use
     U+2014, NOT '--' or ASCII '-'. -->

<!-- GOTCHA — preserve the file's typography: *relevance* (asterisk emphasis),
     `@session-history-dwell-ms` (backticks), and `0` (backticks). The current
     paragraph already uses the first two; T2.S1's Options row and S1's
     How-it-works bullet use `0` backticks. The newText keeps all three so the
     paragraph is visually consistent with the rest of the README. Do NOT drop
     them. (The orchestrator item description paraphrases the wording without the
     markdown markers; doc_impact §7 — the canonical design text — keeps them. Use
     doc_impact §7 verbatim, exactly as T2.S1 resolved the identical discrepancy.) -->

<!-- GOTCHA — do NOT touch the status/reset debug helpers or the code block
     (lines ~156-168). They have ZERO activity references (verified) and the task
     contract explicitly says they need no change. The oldText starts at the
     "If toggle seems to target" line and ends at the "...stick sooner." line. -->

<!-- GOTCHA — do NOT remove the file-wide `monitor-activity` token (~line 132).
     It is the PRD §12 sentence explaining WHY there is no output-activity signal
     (T1.S2, DONE). It is correct and KEEP. Only the Troubleshooting "produce
     output" phrases are in scope. After this edit, `grep -c 'monitor-activity'
     README.md` should still be exactly 1. -->

<!-- GOTCHA — wording tweaks in the newText are INTENTIONAL, not errors to "fix":
     old "silent walks" (plural) → new "a silent walk" (singular); old "Lower"
     (sentence-start capital) → new "lower" (lowercase, now mid-sentence after
     the em-dash). Use the newText verbatim. -->

<!-- GOTCHA — no test framework / markdown linter is wired into this repo's CI
     (no bats/spec/Makefile/markdown-CI). Validation uses section-scoped grep
     proofs, a line-count assertion (184 → 184), and a git-diff review confirming
     a single Δ0 hunk. If `markdownlint` or `mdl` is installed, run it as a bonus;
     absence is not a failure. -->
```

## Implementation Blueprint

### Data models and structure

None. This is a pure prose edit (rewrite one wrapped paragraph) in a single
user-facing Markdown section. No data models, no schemas, no code, no options,
no hooks, no dispatch. The `@session-history-dwell-ms` option name and `0` value
are referenced verbatim (unchanged); no literal numeric defaults change here
(the `30000` default already landed via T2.S1).

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CONFIRM input state (no source edits)
  - RUN: wc -l README.md                                    # EXPECT 184 (T1.S1/S2 + T2.S1 landed)
  - RUN: grep -c 'How activity detection works' README.md   # EXPECT 0 (T1.S2 landed)
  - RUN: grep -c '10000' README.md                          # EXPECT 0 (T2.S1 landed)
  - RUN: grep -c '30000' README.md                          # EXPECT 1 (T2.S1 landed)
  - RUN: grep -c 'If toggle seems to target' README.md      # EXPECT 1 (unique paragraph anchor)
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'
            # EXPECT 2 (baseline: line 171 "select it, produce" + line 173 "produce output in them")
  - RUN: grep -n 'monitor-activity' README.md               # EXPECT 1 hit ~line 132 (§12 sentence; KEEP)
  - WHY: confirms all three prior siblings landed and the paragraph is the unique,
         section-scoped activity-reference site. If wc -l is NOT 184, the Options
         table still has 10000, or the 'How activity detection works' heading is
         still present, STOP — a sibling may not have landed; surface the
         discrepancy instead of editing.
  - RUN (snapshot for regression):
         sed -n '/## Troubleshooting/,/## Limitations/p' README.md > /tmp/region_before_m3t2s2.txt
         # Captures the whole Troubleshooting section (helpers + code block + the
         # "wrong session" paragraph). Regression guard: proves everything EXCEPT
         # the "wrong session" paragraph is byte-identical pre/post.

Task 2: PERFORM the single exact-text paragraph replacement (the edit)
  - USE the `edit` tool with the oldText/newText in the "What" section above. The
    oldText is the EXACT 5 wrapped lines of the "wrong session" paragraph (from
    "If toggle seems to target …" through "… \"stick\" sooner."). The newText is
    the rewritten 5 wrapped lines (selection+dwell only, with the dwell-ms / `0`
    advice). Match the U+2014 em-dash exactly; use STRAIGHT quotes; keep
    *relevance* emphasis and `@session-history-dwell-ms` / `0` backticks.
  - ANCHOR on the full paragraph text (opening anchor 'If toggle seems to target
    the "wrong" session' is globally unique); do NOT key on a line number.
  - PRESERVE byte-for-byte: the ## Troubleshooting heading, the helpers intro,
    the status/reset bullets, the code block, the "Run them through the script…"
    sentence, and everything below the paragraph (## Limitations onward).
  - DO NOT TOUCH: the status/reset helpers (no activity refs), the Options table
    (T2.S1), How-it-works incl. the §12 `monitor-activity` sentence (T1.S1/S2),
    Requirements, Limitations, License.

Task 3: VERIFY removal + line count (no edits)
  - RUN: after=$(wc -l < README.md); echo "post-edit lines = $after"
    EXPECTED: 184 (unchanged; 5 wrapped lines in, 5 out). Any other count = wrong
              edit scope (you accidentally added/removed a line) — revert.
  - RUN (Troubleshooting-scoped — avoids the wrapping false-negative trap):
         sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'
    EXPECTED: 0 (both removed phrases gone; pre-edit was 2).
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'while viewing it'
    EXPECTED: 0.
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'unless you then'
    EXPECTED: 0.

Task 4: VERIFY required new phrases + em-dash + typography (no edits)
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | \
          grep -c 'the relevance list only when you select it or dwell on it long enough'
    EXPECTED: 1.
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | \
          grep -c 'only direct selections will ever count'
    EXPECTED: 1.
  - RUN (em-dash byte check — U+2014 = E2 80 94; cat -A shows M-bM-^@M-^T):
         sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep 'intentionally skipped' | cat -A
    EXPECTED: a line containing "intentionally skipped M-bM-^@M-^T if you want"
              (the em-dash bytes between "skipped" and "if"). No "--" or bare "-".
  - RUN (straight quotes — no curly):
         sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c '“\|”'
    EXPECTED: 0 (no curly double quotes). The straight "wrong"/"stick" remain.

Task 5: VERIFY preserved regions + markdown sanity (no edits)
  - RUN (status/reset helpers byte-identical):
         diff <(grep -A4 'The engine script has helpers' /tmp/region_before_m3t2s2.txt) \
              <(sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -A4 'The engine script has helpers') \
              && echo "HELPERS OK"
    EXPECTED: empty diff + "HELPERS OK".
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'status` prints'   # EXPECT 1
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'reset` clears'     # EXPECT 1
  - RUN: sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'session_history.sh status'  # EXPECT 1 (code block)
  - RUN (§12 sentence + Options row intact):
         grep -n 'monitor-activity' README.md        # EXPECT 1 hit ~line 132 (T1.S2 region untouched)
         grep -c '30000' README.md                    # EXPECT 1 (T2.S1 Options row untouched)
         grep -c '10000' README.md                    # EXPECT 0
  - RUN (bonus, if installed): markdownlint README.md 2>/dev/null || mdl README.md 2>/dev/null || echo "no markdown linter — skip (not a failure)"
  - RUN: git diff --stat README.md
    EXPECTED: a single file; net change ≈ 0 lines (5 modified lines, no add/delete).
```

### Implementation Patterns & Key Details

```markdown
<!-- Why ONE combined edit (not a sub-clause edit): the "wrong session" paragraph
     is a single markdown paragraph wrapped across 5 physical lines. Replacing the
     whole block as one oldText→newText is atomic and unambiguous (the opening
     'If toggle seems to target the "wrong" session' is globally unique). One edit
     → one clean single-hunk git diff → a deterministic Δ0 line count.
     (Trying to edit only the changing sub-clause 'when you select it, produce
     output in it while viewing it, or dwell on it' is fragile: it wraps lines
     171-172, and matching a partial wrapped line risks a malformed paragraph.) -->

<!-- Why section-scoped validation: the removed phrase 'produce output in it while
     viewing it' wraps across two physical lines (171-172), so a line-anchored
     grep 'produce output' returns 0 EVEN BEFORE the edit (false negative). Scope
     to the section with sed -n '/## Troubleshooting/,/## Limitations/p' and grep
     for the bare token 'produce' (pre-edit 2 hits, post-edit 0). This is the
     single most important validation-correctness detail in this PRP. -->

<!-- Why the newText says what it says (each clause maps to a PRD section / doc_impact):

  Clause 1 (unchanged lead-in): "If toggle seems to target the "wrong" session,
  remember it tracks *relevance*, not recency:"
      → unchanged from current text (it is already target-aligned: relevance, not
        recency, is the PRD §6 framing). Kept verbatim incl. *relevance* italics.

  Clause 2 (REWRITE): "a session enters the relevance list only when you select it
  or dwell on it long enough."
      → PRD §6 (exactly two promotion causes: selection + dwell) + PRD §2 key
        invariant (selecting/dwelling promotes; walking never). Replaces the
        deleted "when you select it, produce output in it while viewing it, or
        dwell on it" — drops the output-activity cause entirely.

  Clause 3 (REWRITE, reordered): "Walked-past sessions are intentionally skipped —
  if you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`
  (or set it to `0` and only direct selections will ever count)."
      → PRD §6 ("Walking never promotes") + PRD §8 (dwell threshold; `0` disables
        dwell entirely). Replaces the deleted "(unless you then produce output in
        them). Lower `@session-history-dwell-ms` if you want silent walks to
        "stick" sooner." — drops the "unless you then produce output" escape and
        adds the `0` escape hatch (relevance from selection only).
-->

<!-- What the newText deliberately OMITS (banned output-activity phrases):
     "produce output in it while viewing it" and "(unless you then produce output
     in them)". Task 3's section-scoped grep gate enforces both are gone (bare
     token 'produce' → 0 in Troubleshooting). NOTE: the newText LEGITIMATELY
     contains "select", "dwell", "walked", "walk", and "selections" — these are
     the selection/dwell verbs (PRD §6/§8), NOT activity references; do not gate
     on bare "select"/"walk". -->

<!-- How the paragraph reads AFTER the edit (lines ~170-174, 5 wrapped lines):
     If toggle seems to target the "wrong" session, remember it tracks *relevance*,
     not recency: a session enters the relevance list only when you select it or
     dwell on it long enough. Walked-past sessions are intentionally skipped — if
     you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`
     (or set it to `0` and only direct selections will ever count).
-->
```

### Integration Points

```yaml
DATABASE:
  - none. Pure documentation; no DB.

CONFIG (tmux global user options):
  - none changed. The newText references `@session-history-dwell-ms` (the option
    whose tuning advice it gives) and the `0`-disables-dwell escape hatch. It does
    NOT change any option's actual default — the `30000` default already landed
    (T2.S1 in docs; P1.M1.T3.S1 / P1.M2.T1.S1 in code). This edit makes the
    Troubleshooting guidance consistent with the rest of the README and the engine.

ROUTES / DISPATCH:
  - none. Documentation only.

HOOKS / BINDINGS:
  - none changed.

DOCUMENTATION:
  - THIS edit IS the documentation (Mode A — README Troubleshooting region
    directly touched by the relevance-model change). After this edit, the README's
    Troubleshooting section describes selection + dwell only, with no
    output-activity references, consistent with (a) the Options table (T2.S1),
    (b) "How it works" (T1.S1/S2), (c) the engine (no activity signal,
    P1.M1.T1), and (d) the PRD (§6/§2/§8/§12/§15). This is the LAST README
    activity-reference cleanup (GAP 9f). Cross-file consistency (README ↔ code ↔
    PRD) is then verified by the downstream P1.M3.T3.S1 task.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# 0. Confirm input state (run BEFORE editing):
wc -l README.md                                     # expect 184 (T1.S1/S2 + T2.S1 landed)
grep -c 'How activity detection works' README.md    # expect 0  (T1.S2 landed)
grep -c '10000' README.md                           # expect 0  (T2.S1 landed)
grep -c '30000' README.md                           # expect 1  (T2.S1 landed)
grep -c 'If toggle seems to target' README.md       # expect 1  (unique paragraph anchor)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'   # expect 2 (baseline)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md > /tmp/region_before_m3t2s2.txt  # snapshot

# 1. Line-count delta (capture before & after within THIS task):
#    (edit happens here via the `edit` tool — single 5-line oldText→newText replacement)
after=$(wc -l < README.md)
echo "lines: 184 -> $after (expect 184, delta 0)"
[ "$after" = "184" ] && echo "LINE COUNT OK" || echo "LINE COUNT WRONG"
# Expected: LINE COUNT OK (184). The edit is 5 lines in -> 5 lines out = Δ0.

# 2. Byte-level eyeball of the new paragraph (em-dash, backticks, emphasis, quotes):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | sed -n '/If toggle/,/ever count\./p' | cat -A
# Expected: 5 lines; *relevance* (asterisks); one U+2014 em-dash after "skipped"
# (cat -A shows M-bM-^@M-^T); `@session-history-dwell-ms` and `0` in backticks;
# straight "wrong"/"stick" quotes; NO curly quotes.

# 3. Bonus markdown lint (only if a linter is installed; absence is NOT a failure):
command -v markdownlint >/dev/null && markdownlint README.md || \
command -v mdl >/dev/null && mdl README.md || \
echo "no markdown linter installed — skipping (not a failure for a doc task)"
```

### Level 2: Structural Proofs (Component Validation)

No test framework in this repo (no bats/spec/Makefile/markdown-CI). These grep
proofs — SCOPED TO THE TROUBLESHOOTING SECTION (to avoid the line-wrapping
false-negative trap) — pin the exact phrase removal, the required new phrases,
and the byte-identical preservation of the helpers and code block.

```bash
# A. REMOVED — output-activity phrases gone from Troubleshooting (scoped):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'             # Expected: 0 (was 2)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'while viewing it'    # Expected: 0
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'unless you then'     # Expected: 0

# B. PRESENT — selection+dwell-only phrases (scoped):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | \
  grep -c 'the relevance list only when you select it or dwell on it long enough'          # Expected: 1
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | \
  grep -c 'only direct selections will ever count'                                         # Expected: 1

# C. Em-dash is exactly one U+2014 (E2 80 94) and quotes are straight (scoped):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep 'intentionally skipped' | cat -A | grep -c 'M-bM-^@M-^T'  # Expected: 1
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c '“\|”'                # Expected: 0 (no curly double quotes)

# D. status/reset helpers + code block are byte-identical (boundary preservation):
diff <(sed -n '156,168p' /tmp/region_before_m3t2s2.txt 2>/dev/null; sed -n '/## Troubleshooting/,/## Limitations/p' /tmp/region_before_m3t2s2.txt | sed -n '1,15p') \
     <(sed -n '/## Troubleshooting/,/## Limitations/p' README.md | sed -n '1,15p') \
     && echo "HELPERS+CODEBLOCK OK"
# (Simpler robust form — just assert the helper tokens still present exactly once:)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'status` prints'      # Expected: 1
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'reset` clears'       # Expected: 1
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'session_history.sh status'  # Expected: 1

# E. Sibling regions are untouched:
grep -n 'monitor-activity' README.md          # Expected: 1 hit ~line 132 (§12 sentence intact; T1.S2 region)
grep -c '30000' README.md                      # Expected: 1 (T2.S1 Options row intact)
grep -c '10000' README.md                      # Expected: 0
sed -n '106,133p' README.md | grep -c 'select it directly'   # Expected: 1 (T1.S1 bullets intact)
```

### Level 3: Integration Testing (System Validation)

```bash
# Render the Troubleshooting section to eyeball it renders as a clean paragraph
# (not a broken code block or merged line):
command -v pandoc >/dev/null && \
  pandoc README.md -t plain | sed -n '/## Troubleshooting/,/## Limitations/p' || \
  echo "pandoc not installed — eyeball the section on GitHub or in an editor"
# Expected: the status/reset helper bullets, the code block, then ONE paragraph
# reading "If toggle seems to target the "wrong" session, remember it tracks
# relevance, not recency: a session enters the relevance list only when you select
# it or dwell on it long enough. Walked-past sessions are intentionally skipped —
# if you want a silent walk to "stick" sooner, lower @session-history-dwell-ms
# (or set it to 0 and only direct selections will ever count)."

# git diff sanity — one file, single Δ0 hunk:
git diff --stat README.md
# Expected: "1 file changed, 5 insertions(+), 5 deletions(-)" (5 modified lines; Δ0).
git diff README.md
# Expected: a single hunk: the old "wrong session" paragraph (red, 5 lines)
# replaced by the new paragraph (green, 5 lines); no other hunks.
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Cross-document consistency spot-check (the whole point of this edit):
# 1. README has NO user-facing output-activity promotion cause anywhere
#    (Options table, How-it-works, AND Troubleshooting all selection+dwell only):
grep -c 'produce output in it while viewing it' README.md     # 0 (this task removed it)
grep -c 'unless you then produce output' README.md            # 0 (this task removed it)
# (Note: the bare-token 'produce' still appears once in the §12 sentence as
#  "produced output" — that is the meta-explanation of the ABSENCE of the signal,
#  PRD §12, and is correct/KEEP. Do not gate on bare 'produce' file-wide; gate
#  section-scoped as in Level 2.)
sed -n '128,135p' README.md | grep -c 'produced output'       # 1 (the §12 sentence — KEEP)

# 2. README relevance model == PRD §6 (selection + dwell only), echoed in 3 places:
grep -c 'select it directly\|select it or dwell on it long enough\|selecting a session' README.md
# Expected: >= 2 (How-it-works bullets + Troubleshooting; Options row uses "selecting a session")

# 3. README default == PRD default == engine default (already true from T2.S1; this
#    task must not regress it):
grep -c '30000' README.md                 # 1 (Options row)
grep -o '30000' scripts/session_history.sh | head -1   # 30000 (engine dwell_ms fallback)
grep -o '30000' session_history.tmux      | head -1   # 30000 (set-option -g)
# Expected: README / engine / PRD all agree on 30000 and on the selection+dwell-only
# model. No drift; Troubleshooting no longer contradicts the rest.
```

## Final Validation Checklist

### Technical Validation

- [ ] All validation levels completed successfully.
- [ ] Line count unchanged: `wc -l README.md` → **184**.
- [ ] git diff is a single Δ0 hunk (5 insertions, 5 deletions; one paragraph).

### Feature Validation

- [ ] All success criteria from "What" section met (Troubleshooting is
      selection+dwell only; banned phrases gone; required phrases present).
- [ ] Troubleshooting-scoped `grep -c 'produce'` → **0** (both "produce output in
      it while viewing it" and "unless you then produce output in them" gone).
- [ ] Troubleshooting contains `the relevance list only when you select it or
      dwell on it long enough` and `only direct selections will ever count`.
- [ ] status/reset helpers + code block byte-identical (zero activity refs there).
- [ ] Sibling regions intact (T1.S1 bullets, T1.S2 §12 `monitor-activity`
      sentence, T2.S1 Options `30000` row).

### Code Quality Validation

- [ ] Follows existing README prose conventions (~76-79 col wrapping, inline code
      for option names, *emphasis* for contrast words, straight quotes, U+2014).
- [ ] Typography consistent with the file: `*relevance*` italics,
      `` `@session-history-dwell-ms` `` and `` `0` `` backticks, one U+2014
      em-dash, straight `"wrong"`/`"stick"` quotes.
- [ ] No new structural element introduced (still one prose paragraph in the
      section; helpers + code block unchanged).

### Documentation & Deployment

- [ ] README Troubleshooting now describes selection + dwell only — consistent
      with the Options table (T2.S1), "How it works" (T1.S1/S2), the engine (no
      activity signal, P1.M1.T1), and the PRD (§6/§2/§8/§12/§15).
- [ ] The only file-wide "activity" token is `monitor-activity` (~line 132, the
      PRD §12 explanation of the absence) — correct, not a stale reference.
- [ ] No environment variables or new options introduced.

---

## Anti-Patterns to Avoid

- ❌ Don't key on line numbers ("170-174" or doc_impact's stale "185-189") —
  anchor on the paragraph's text (the `If toggle seems to target the "wrong"
  session` opening is globally unique).
- ❌ Don't edit only the changing sub-clause — replace the WHOLE 5-line wrapped
  paragraph as one atomic oldText→newText (the sub-clause "produce output in it
  while viewing it" wraps across two physical lines and is fragile to match).
- ❌ Don't use file-wide `grep 'produce output'` for validation — it's a
  false-negative trap (the phrase wraps across lines). Scope to the
  Troubleshooting section and grep the bare token `produce`.
- ❌ Don't drop the `*relevance*` italics or `` `@session-history-dwell-ms` `` /
  `` `0` `` backticks — they match the file's existing paragraph typography and
  keep the README internally consistent.
- ❌ Don't substitute the em-dash (—) with `--` or ASCII `-` — use UTF-8 U+2014.
- ❌ Don't introduce curly quotes — the whole file uses straight quotes.
- ❌ Don't touch the status/reset helpers or the code block — they have zero
  activity references and the contract says no change.
- ❌ Don't remove the file-wide `monitor-activity` token (~line 132) — it is the
  PRD §12 sentence explaining the ABSENCE of an output signal; it is correct and
  KEEP.
- ❌ Don't gate validation on bare "select"/"walk"/"dwell"/"selections" — those
  are the selection/dwell verbs (PRD §6/§8), not activity references. Gate on the
  EXACT banned phrases (section-scoped `produce`, `while viewing it`,
  `unless you then`).
- ❌ Don't "restore" the old singular/plural or capitalization — `silent walks` →
  `a silent walk` and `Lower` → `lower` are intentional newText forms.