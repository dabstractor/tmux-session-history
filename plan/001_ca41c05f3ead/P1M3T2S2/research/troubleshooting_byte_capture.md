# Byte-Accurate Capture — README.md Troubleshooting "wrong session" paragraph (P1.M3.T2.S2)

**Purpose:** Pin the exact bytes of the region this task edits, the scope
boundary vs. sibling regions, the input-state confirmation, the
item-description-vs-doc_impact wording resolution, and the deterministic grep
proofs — so the PRP's one-pass edit is unambiguous.

Ground truth captured live from `/home/dustin/.config/tmux/plugins/tmux-session-history/README.md`.

---

## 0. Input-state confirmation (T2.S1 has LANDED — README is 184 lines)

```
$ wc -l < README.md
184
$ grep -c '10000' README.md
0
$ grep -c '30000' README.md
1
$ grep -c 'Fallback for \*silent\* presence' README.md
0
```

**Conclusion:** P1.M3.T2.S1 (Options table `10000`→`30000` + description
rewrite) has ALREADY landed. The Options table now advertises `30000` and the
selection+dwell-only model. The input to T2.S2 is the **184-line** README.
T2.S1 was Δ0 (one table row in / one out), so it did not shift any line numbers
below it. Troubleshooting is therefore at the SAME absolute line numbers it
would be at after only S1/S2 (How-it-works) landed.

---

## 1. Where the section actually is (NOT lines 185-189)

`doc_impact.md` §1e/§7 were written when README was **192 lines** (pre-S1/S2),
hence its "lines 185-189" reference. After S1/S2 removed ~8 lines (the
"How activity detection works" subsection + tightened async paragraph) the file
shrank to **184** and the section moved up by ~14-19 lines.

**Live line numbers (verified):**

```
156: ## Troubleshooting
157: (blank)
158: The engine script has helpers for debugging:
159: (blank)
160: - `status` prints the current timeline (cursor in brackets) and the relevance
161:   list in the tmux message line.
162: - `reset` clears all state and starts over.
163: (blank)
164: Run them through the script under your plugin directory, for example:
165: (blank)
166: ```sh
167: ~/.tmux/plugins/tmux-session-history/scripts/session_history.sh status
168: ```
169: (blank)
170: If toggle seems to target the "wrong" session, remember it tracks *relevance*,
171: not recency: a session enters the relevance list when you select it, produce
172: output in it while viewing it, or dwell on it. Walked-past sessions are
173: intentionally skipped (unless you then produce output in them). Lower
174: `@session-history-dwell-ms` if you want silent walks to "stick" sooner.
175: (blank)
176: ## Limitations
```

**The editable region = lines 170-174** (the "wrong session" paragraph — a
single logical paragraph wrapped across 5 physical lines at ~76-79 cols).

The status/reset helpers (156-168) and the code block are **OUT OF SCOPE** and
have zero activity references — verified: the only file-wide activity refs are
line 132 (`monitor-activity`, the §12 sentence — correct, KEEP) and lines
171-173 (the ones we remove). So status/reset need no change, exactly as the
task contract and doc_impact §7 state.

> **Anchor on TEXT, never line numbers.** The paragraph opens with
> `If toggle seems to target the "wrong" session, remember it tracks *relevance*,`
> which is globally unique (`grep -c` = 1). Use the full 5-line oldText for the
> replacement; line numbers are illustrative only.

---

## 2. The exact oldText (byte-accurate, cat -A verified)

Captured with `sed -n '170,174p' README.md | cat -A` (the trailing `$` is
cat -A's newline marker, NOT part of the bytes):

```
If toggle seems to target the "wrong" session, remember it tracks *relevance*,$
not recency: a session enters the relevance list when you select it, produce$
output in it while viewing it, or dwell on it. Walked-past sessions are$
intentionally skipped (unless you then produce output in them). Lower$
`@session-history-dwell-ms` if you want silent walks to "stick" sooner.$
```

**Style facts (verified):**
- Quotes are ALL STRAIGHT: `"wrong"` and `"stick"` are U+0022 (cat -A renders
  them literally, not as `M-bM-^@M-...`). 0 curly quotes in the whole file.
- `*relevance*` is markdown italics (asterisk emphasis) — present in the
  CURRENT paragraph (line 170). NOT optional; it is the file's existing style.
- `` `@session-history-dwell-ms` `` is backticked inline code (line 174) —
  matches the rest of the README (Options table, Keys, etc.).
- The paragraph wraps at ~76-79 cols (line 170 is the longest at 79 chars).
- There are NO em-dashes in the current paragraph. (Em-dashes appear elsewhere
  in the file — the §12 sentence line ~133 has one; see byte table below.)

**The two activity references to remove (both inside lines 170-174):**
1. `…when you select it, produce output in it while viewing it, or dwell on it.`
   — note "produce" ends line 171 and "output" starts line 172 (the phrase is
   **wrapped across two physical lines**). The bare-string
   `grep 'produce output'` does NOT match it line-wise; scope validation to the
   Troubleshooting section instead (§5).
2. `…(unless you then produce output in them).` — all within line 173.

---

## 3. The newText (verbatim from doc_impact.md §7, typography preserved)

doc_impact §7 gives the canonical rewrite. Wrapped to match the file's ~76-79
col style (5 physical lines, same as the original → **Δ0**, README stays 184):

```
If toggle seems to target the "wrong" session, remember it tracks *relevance*,
not recency: a session enters the relevance list only when you select it or
dwell on it long enough. Walked-past sessions are intentionally skipped — if
you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`
(or set it to `0` and only direct selections will ever count).
```

**What changed clause-by-clause (old → new → PRD authority):**

| Old (REMOVE) | New (ADD) | Authority |
|---|---|---|
| `when you select it, produce output in it while viewing it, or dwell on it` | `only when you select it or dwell on it long enough` | PRD §6 (exactly two promotion causes: selection + dwell) |
| `Walked-past sessions are intentionally skipped (unless you then produce output in them). Lower \`@session-history-dwell-ms\` if you want silent walks to "stick" sooner.` | `Walked-past sessions are intentionally skipped — if you want a silent walk to "stick" sooner, lower \`@session-history-dwell-ms\` (or set it to \`0\` and only direct selections will ever count).` | PRD §6 (walking never promotes) + PRD §8 (`0` disables dwell) |

**Style notes on the newText:**
- Keeps `*relevance*` italics (matches current line 170 — file consistency).
- Keeps `` `@session-history-dwell-ms` `` backticks (matches current line 174).
- Adds `` `0` `` backticks for the disable-dwell value (matches the Options
  table row T2.S1 just landed: `` `0` disables dwell `` — internal consistency).
- Introduces exactly **ONE** U+2014 em-dash: `skipped — if you want`.
- Keeps straight `"wrong"` / `"stick"` quotes (file-wide straight-quote policy).
- Note wording tweaks that are intentional: old `silent walks` (plural) → new
  `a silent walk` (singular); old `Lower` (capital) → new `lower` (lowercase,
  now mid-sentence after the em-dash). Do not "restore" the old forms.

### Wording-discrepancy resolution: item description vs doc_impact §7

The orchestrator item description paraphrases the rewrite in **plain text**
(`remember it tracks relevance, not recency`, `lower @session-history-dwell-ms`,
`set it to 0`) — i.e. it drops the markdown markers. `doc_impact.md` §7 keeps
them (`*relevance*`, `` `@session-history-dwell-ms` ``, `` `0` ``). They are
**substance-identical**; only typography differs.

**Resolution: USE doc_impact §7's typography** (the newText above), exactly as
P1.M3.T2.S1 resolved the identical discrepancy for the Options-table row.
Reasons:
1. The CURRENT Troubleshooting paragraph already uses `*relevance*` and
   backticked `` `@session-history-dwell-ms` ``. Dropping them would be an
   unrequested, inconsistent style regression.
2. The just-landed Options row (T2.S1) and S1's "How it works" bullets both use
   `` `0` `` backticks — keeping `` `0` `` here is internally consistent.
3. The README's house style is straight quotes + U+2014 em-dashes + backticked
   option names + asterisk emphasis; the newText honors all four.

---

## 4. Em-dash byte proof (the newText's single U+2014)

Em-dashes elsewhere in the file are UTF-8 U+2014 (bytes E2 80 94; cat -A shows
`M-bM-^@M-^T`). Verified on the §12 sentence:

```
$ sed -n '131,133p' README.md | grep -o 'background' # context
… `monitor-activity` only sees *background* windows — the opposite …
$ sed -n '133p' README.md | cat -A | grep -o 'M-bM-^@M-^T'   # the em-dash bytes
M-bM-^@M-^T
```

The newText's em-dash (`skipped — if`) MUST be the same U+2014 (NOT `--` or
ASCII `-`). One occurrence only.

---

## 5. Deterministic grep proofs (validation design)

**Important: the removed phrase "produce output in it while viewing it" wraps
across physical lines 171→172**, so a line-anchored `grep 'produce output'`
returns 0 *even before the edit* (false negative). Scope every Troubleshooting
check to the section between `## Troubleshooting` and `## Limitations`.

### Pre-edit baseline (current state)
```
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'   # → 2
#   (line 171 "select it, produce" + line 173 "produce output in them")
grep -n 'monitor-activity' README.md                                             # → 132 (KEEP; out of scope)
```

### Post-edit expectations
```
# REMOVED — Troubleshooting-scoped (all → 0):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'produce'                            # 0
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'while viewing it'                   # 0
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'unless you then'                    # 0

# PRESENT — Troubleshooting-scoped (all → 1):
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'the relevance list only when you select it or dwell on it long enough'  # 1
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'only direct selections will ever count'                                 # 1

# UNCHANGED / preserved:
wc -l < README.md                                                          # 184 (Δ0: 5 lines in, 5 out)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'status` prints'   # 1 (helper intact)
sed -n '/## Troubleshooting/,/## Limitations/p' README.md | grep -c 'reset` clears'     # 1 (helper intact)
grep -n 'monitor-activity' README.md                                        # 132 (§12 sentence intact)
grep -c '30000' README.md                                                   # 1 (T2.S1's Options row intact)
```

---

## 6. Scope boundary vs. sibling regions (disjointness table)

| Region | Lines | Owner | Touched here? |
|---|---|---|---|
| How-it-works promotion bullets + Walking paragraph | ~106-128 | P1.M3.T1.S1 (DONE) | NO |
| How-it-works async paragraph + §12 sentence (`monitor-activity`) | ~130-133 | P1.M3.T1.S2 (DONE) | NO (line 132 `monitor-activity` is the explanation of the ABSENCE — keep) |
| Options table dwell-ms row (`30000`) | 86 | P1.M3.T2.S1 (DONE) | NO |
| **Troubleshooting status/reset helpers + code block** | **156-168** | — | **NO (no activity refs)** |
| **Troubleshooting "wrong session" paragraph** | **170-174** | **P1.M3.T2.S2 (THIS TASK)** | **YES** |
| Limitations, License | 176+ | — | NO |

**Single edit = lines 170-174 (5 physical lines) → 5 physical lines. Δ0.**
No other region is touched. The edit is one atomic oldText→newText paragraph
replacement, anchored on the unique opening text.

---

## 7. Cross-doc consistency after this edit

After T2.S2 lands, the README contains **zero** user-facing references to a
"produce output / output-activity" promotion cause:
- Options table (T2.S1, DONE): no "interacting", no "promotes immediately".
- How-it-works (T1.S1/S2, DONE): selection + dwell only; §12 sentence explains
  the *absence* of an output signal (citing `monitor-activity`).
- Troubleshooting (T2.S2, this task): selection + dwell only.

The ONLY remaining "activity" token file-wide is `monitor-activity` (line 132),
which is the intentional PRD-§12 explanation of why there is *no* output-activity
signal — correct and KEEP. Cross-file consistency (README ↔ code ↔ PRD) is then
fully verified by the downstream P1.M3.T3.S1 task.