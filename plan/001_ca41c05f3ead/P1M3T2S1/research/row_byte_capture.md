# Byte-accurate capture — Options table dwell-ms row (README.md:86)

**Purpose:** pin the exact oldText/newText for the single-row edit in P1.M3.T2.S1,
and the scope boundary that keeps it disjoint from siblings T1.S1, T1.S2, T2.S2.

## Input state (on-disk, the ground truth for THIS task)

- `wc -l README.md` → **184** lines. (S1 + S2 have already landed: the "How it
  works" section already reads dwell-only with the §12 sentence; no
  `**How activity detection works.**` heading remains.)
- The Options table dwell-ms row is at **line 86** and is the ONLY `10000` in
  the file (`grep -c '10000' README.md` → 1; `grep -c '`10000`' README.md` → 1).
- The row's opening anchor `Fallback for *silent* presence` is globally unique
  (`grep -c` → 1) — safe to key an exact-text replacement on.
- Quote style: **0 curly quotes** anywhere in the file (0 × U+2018/U+2019,
  0 × U+201C/U+201D). Apostrophes are straight (U+0027).
- Em-dashes: **14 × U+2014** (bytes E2 80 94) in the file. The current dwell-ms
  row contains NO em-dash; the newText will introduce **one** (`— relevance then
  comes only`), matching the file's established em-dash style.
- The row uses the file's existing typography: `*walked*` (asterisk emphasis) and
  `` `0` `` / `` `10000` `` (backticks). Confirmed via
  `sed -n '86p' | grep -oE '\*walked\*|`0`|`10000`'`.

## Exact oldText (line 86, byte-for-byte, cat -A verified, no trailing newline issues)

```
| `@session-history-dwell-ms` | `10000` | Fallback for *silent* presence: how long you must stay on a session you *walked* to (back/forward) without typing/interacting before it counts as relevant. Working there (typing, switching panes, any tmux command) promotes it immediately regardless. `0` disables dwell (relevance then comes only from selecting a session or interacting with it). |
```

- It is ONE markdown table row (one line). Replacing it = one line in, one line
  out → **README line count is UNCHANGED** (184 → 184).
- Phrases that presuppose the removed activity poller (must all be dropped):
  `Fallback for *silent* presence:`, `without typing/interacting`,
  `Working there (typing, switching panes, any tmux command) promotes it
  immediately regardless.`, and the `or interacting with it` tail.

## Exact newText (doc_impact.md §4, verbatim; preserves file typography)

```
| `@session-history-dwell-ms` | `30000` | How long you must stay on a session you *walked* to (back/forward) before it counts as relevant. This is the only way a walked-to session becomes a toggle target besides re-selecting it. `0` disables dwell — relevance then comes only from selecting a session (toggle, pick, tmux-sessionx, or a manual switch). |
```

- Two substantive changes vs oldText: (1) default cell `` `10000` `` → `` `30000` ``;
  (2) description rewritten to the selection+dwell-only model.
- Typography preserved from the file: `*walked*` emphasis + `` `0` `` backticks.
  (The orchestrator task description gives a plain-text paraphrase — "you walked
  to" / "0 disables dwell" without the asterisks/backticks; doc_impact §4 is the
  curated design text that keeps the README internally consistent and is adopted
  as canonical here. They are substance-identical.)
- ONE em-dash (`—`, U+2014) before "relevance then comes only".
- Vocabulary `tmux-sessionx` / `switch-client` already appears in README
  (4× / 3×) — the newText's "(toggle, pick, tmux-sessionx, or a manual switch)"
  mirrors S1's already-landed promotion bullet ("via toggle, pick, tmux-sessionx,
  or a manual `switch-client`"). Consistent.

## Line-count math

- Edit = replace 1 row line with 1 row line. Δ = 0.
- README stays **184** lines pre and post. (Distinct from S2, which was −8.)

## Scope boundary (disjoint from all sibling README tasks)

| Sibling | Region (current 184-line file) | Status | Overlaps line 86? |
|---|---|---|---|
| T1.S1 | "How it works" promotion bullets + Walking paragraph (~106-121) | DONE | No |
| T1.S2 | async-paths paragraph + §12 sentence (~123-133) | DONE | No |
| **T2.S1 (this)** | **Options table dwell-ms row (line 86)** | **THIS TASK** | — |
| T2.S2 | Troubleshooting "produce output … while viewing it" (~172-176) | Planned | No |

- Line 86 sits in the Options table (lines 80-87), ABOVE all "How it works" and
  Troubleshooting edits. None of the siblings touches the Options table.
- Because every sibling region is disjoint and the dwell-ms row is globally
  unique, merge order with T2.S2 is irrelevant. **Anchor on the row's TEXT
  (`Fallback for *silent* presence`), not on "line 86"** — if a sibling that
  edits lines above 86 ever changes line numbering, the text anchor still hits
  exactly one row.

## Authority for the target text (clause → PRD/doc_impact)

- `` `30000` `` default → PRD §15 (`@session-history-dwell-ms` `30000`), PRD §3.4
  table, PRD §8 (`dwell_ms()` default 30000). Also closes the README's internal
  inconsistency (Options table said 10000 while the "How it works" body already
  said "default 30 s" — doc_impact §1a / GAP 2d note).
- "How long you must stay on a session you walked to before it counts as
  relevant" → PRD §8 (dwell = the walk-dwell threshold) + PRD §2 key invariant
  (dwelling on a walked-to session promotes in the relevance list).
- "This is the only way a walked-to session becomes a toggle target besides
  re-selecting it" → PRD §6 (exactly two promotion causes: selection + dwell;
  walking never promotes). Replaces the removed "Working there promotes it
  immediately" activity claim.
- "`0` disables dwell — relevance then comes only from selecting a session
  (toggle, pick, tmux-sessionx, or a manual switch)" → PRD §8 arming
  (`if ms <= 0: return`; "0 disables dwell entirely") + PRD §6 selection causes.
  Drops the old false "or interacting with it" (an activity reference).

## Companion code changes (NOT in this task's scope, already Complete)

The README default must match the code default or the docs lie (doc_impact §9.1,
HIGH risk). Both are already done in the plan:
- `scripts/session_history.sh:154` `dwell_ms()` default → 30000 (P1.M1.T3.S1 — Complete)
- `session_history.tmux:55` `set-option -g '@session-history-dwell-ms'` → 30000
  (P1.M2.T1.S1 — Complete)

So this README edit lands with the code already at 30000 — no drift.

## Deterministic proofs (run after the edit)

- `grep -c '`10000`' README.md` → **0** (the only 10000 was this row)
- `grep -c '`30000`' README.md` → **1** (the new default; previously 0)
- `grep -c 'Fallback for \*silent\* presence' README.md` → **0**
- `grep -c 'promotes it immediately regardless' README.md` → **0**
- `grep -c 'without typing/interacting' README.md` → **0**
- `grep -c 'or interacting with it' README.md` → **0**
- `grep -c 'the only way a walked-to session becomes a toggle target besides re-selecting it' README.md` → **1**
- `wc -l README.md` → **184** (unchanged)
- Row still parses as a 3-column table row: `sed -n '86p' README.md | awk -F'|' '{print NF}'` → **5** (leading/trailing empty + 3 cells).