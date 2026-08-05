# P1.M3.T1.S2 — Byte-accurate capture of the target region

**Purpose:** Pin the exact bytes of the region this task edits, the boundaries it
must preserve, and the quote/dash style the newText must match. Source of truth
for the PRP's oldText/newText byte fidelity.

**File:** `/home/dustin/.config/tmux/plugins/tmux-session-history/README.md`

---

## 0. Input state — CONFIRMED post-S1 (192 lines)

S1 (P1.M3.T1.S1) has **landed**. Evidence (verified live):
- `wc -l README.md` → **192** (S1's target: 199 → 192).
- Promotion bullets reordered: line 109 = `- **select it directly**` (now #1),
  line 111 = `- **dwell on it**` (now #2). The "type, switch panes/windows"
  bullet is GONE.
- Walking paragraph (line 121) ends with `...dwell promotes it; press toggle
  and you're now oscillating between A and B.` (S1's rewrite).

So this task's INPUT is the **192-line post-S1 README**, NOT the original 199.
Line numbers below are POST-S1.

## 1. The target region — oldText (lines 123–141, 19 lines)

Two blocks separated by a blank (line 134):

### Block A — the subsection to DELETE (lines 123–133, 11 lines)

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
```

### Line 134 — blank (between blocks; inside oldText)

### Block B — the paragraph to REWRITE (lines 135–141, 7 lines)

```markdown
The dwell timer is one asynchronous path; focused-activity detection is the
other. Both touch only the relevance list (never the timeline), so a rare lost
update only nudges relevance and self-heals on the next switch. When you walk
onto a session, a background timer is armed; if you're still on that session
when it fires, the session is promoted. The moment you produce output there,
activity promotes it instead, so dwell only matters for silent presence. The
timer self-cancels if you've moved on, so stale timers are harmless.
```

### oldText = Block A + blank(134) + Block B = 19 contiguous lines (123–141)

- Opens with `**How activity detection works.** When toggle is bound the plugin watches the` — GLOBALLY UNIQUE (grep -c = 1).
- Closes with `timer self-cancels if you've moved on, so stale timers are harmless.` — GLOBALLY UNIQUE (grep -c = 1).

## 2. Boundaries to PRESERVE byte-for-byte (NOT in oldText)

- **Line 121:** `promotes it; press toggle and you're now oscillating between A and B.` (S1's Walking paragraph tail — KEEP).
- **Line 122:** BLANK (the S1↔S2 boundary separator — KEEP). Sits immediately ABOVE oldText.
- **Line 142:** BLANK (separator before close-current paragraph — KEEP). Sits immediately BELOW oldText.
- **Line 143:** `When a session closes it is pruned from both lists and everything shifts down.` (close-current paragraph — KEEP).

## 3. Quote / dash style — ALL STRAIGHT

Verified live on the whole file:
- Straight apostrophe `'` (0x27): **18** occurrences.
- Curly U+2018 / U+2019: **0 / 0**.
- Straight double-quote `"` (0x22): **4** occurrences.
- Curly U+201C / U+201D: **0 / 0**.

→ newText MUST use straight `'` (you're, you've, tmux's) and straight `"`
("the focused session produced output"). Zero curly quotes.

- Em-dash `—`: U+2014, bytes E2 80 94, `cat -A` shows `M-bM-^@M-^T`. Used throughout.
- En-dash `–`: U+2013, bytes E2 80 93. Appears ONLY inside oldText at "(~0.5–1 s)"
  (deleted region) — does NOT appear in newText.

## 4. The newText (canonical — doc_impact.md §3 "Paragraph 4", 11 lines)

Two paragraphs separated by one blank:

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

Style match: straight apostrophes (you're, you've, tmux's), straight
double-quotes around "the focused session produced output", backticked
`monitor-activity`, one em-dash (—) before "the opposite". Matches the file.

## 5. Line math

- oldText = 19 lines (123–141).
- newText = 11 lines.
- Net = **−8 lines**. README **192 → 184**.
- After edit, the close-current paragraph shifts from line 143 → line 135;
  the sessionx paragraph from line 148 → line 140.

## 6. Grep gates — scoped to THIS region (NOT whole file)

After the edit, extract the region:
`sed -n '/^The dwell timer is the only asynchronous path/,/the opposite of what toggle needs/p' README.md`

Must be ABSENT (specific phrases — do NOT gate on bare "activity" or bare "output"):
- `How activity detection works` (the deleted subsection header)
- `focused-activity detection` (the deleted clause)
- `activity promotes it` (the deleted false claim)
- `client_activity` (the deleted timestamp ref)
- `background poller` / `poller` (the deleted machinery)
- `one resident process` (the deleted false claim — NOTE: new text says
  "resident process per pane", which is DIFFERENT and intentional; grep
  "one resident process" must be 0, grep "resident process per pane" must be 1)
- `produce output there` (the deleted false clause — NOTE: new text says
  "produced output" in a different clause citing why there's NO detection;
  grep "produce output there" must be 0)
- `~0.5` / `per-pane pipes` (deleted)

Must be PRESENT:
- `only asynchronous path` (= 1; the new sole-path claim)
- `monitor-activity` (= 1; the §12 citation — contains substring "activity" by design)
- `resident process per pane` (= 1)
- `the opposite of what toggle needs` (= 1)

### Why NOT to gate on bare "activity" or "output" in this region
- `monitor-activity` legitimately contains the substring "activity" (it's the
  tmux option name cited as the REASON there is no signal — PRD §12).
- `"the focused session produced output"` legitimately contains "output" (it
  explains why there is no detection).
Gate on the EXACT activity-detection phrases above, never on bare words.

### Whole-file note
After S2, "activity" STILL legitimately appears in:
- `monitor-activity` (this region — correct).
- Troubleshooting section (T2.S2's region, ~line 179: "produce output in it
  while viewing it") until T2.S2 lands.
Do NOT assert whole-file `grep activity` = 0 after S2 alone.