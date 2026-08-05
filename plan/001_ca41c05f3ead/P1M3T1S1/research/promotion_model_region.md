# Research — README promotion-model rewrite (P1.M3.T1.S1)

## Scope boundary (S1 vs S2) — THE critical constraint

`architecture/gap_analysis.md` GAP 9 splits the README "How it works" activity
removal across two sibling subtasks. This task owns **GAP 9b + 9c ONLY**:

| GAP | README lines | Content | Owner |
|-----|--------------|---------|-------|
| 9a  | 86           | Options table `@session-history-dwell-ms` default + description | **T2.S1** |
| **9b**  | **109–116**  | "type, switch panes/windows..." bullet (PRIMARY signal) | **THIS TASK (S1)** |
| **9c**  | **126–127**  | "the instant you produce output... activity promotes immediately" | **THIS TASK (S1)** |
| 9d  | 130–140      | "**How activity detection works.**" subsection | **T1.S2** |
| 9e  | 142–148      | async-paths "focused-activity detection is the other" | **T1.S2** |
| 9f  | 187–189      | Troubleshooting "produce output in it while viewing it" | **T2.S2** |
| 9g  | 74           | Keys opt-in callout | no change |

**Therefore the S1 edit region is README lines 106–128** (the "A session becomes
relevant…" intro through the last line of the "Walking through a session"
paragraph, "...back on B (once B itself is relevant)."). The blank line at **129**
is the separator and is PRESERVED (not in oldText), cleanly separating S1's region
from S2's region which begins at line 130 ("**How activity detection works.**").

## Exact byte-accurate edit region (verified via `cat -A`)

README.md is UTF-8; em-dashes (—) are U+2014 (bytes E2 80 94, shown by cat -A as
`M-bM-^@M-^Y`). The oldText region (lines 106–128, 23 lines) contains em-dashes on
lines 106, 109, 113, 116, 117, 118, 124. Match them exactly — do not substitute
`--` or ASCII `-`.

```
106: A session becomes relevant — is promoted to the front of the relevance list —
107: when you either:
108: (blank)
109: - **type, switch panes/windows, or run any tmux command in it while viewing it** —
110:   this is the *primary* signal. The moment you're working in the session in
111:   front of you, it becomes the toggle target, within about half a second to a
112:   second. (tmux's built-in `monitor-activity` can't see this — it only notices
113:   *background* windows — so the plugin instead watches the attached client's
114:   activity timestamp, which advances on every keystroke you send: characters
115:   typed into the shell, pane/window switches, and tmux commands alike.)
116: - **select it directly** — via toggle, pick, tmux-sessionx, or a manual
117:   `switch-client`. The session you go to becomes relevant immediately.
118: - **dwell on it** — reach it by walking (back/forward) and stay longer than
119:   `@session-history-dwell-ms` (default 30 s) *without* typing/interacting. This is
120:   the fallback for silent presence (reading, thinking).
121: (blank)
122: Walking through a session does **not** make it relevant by itself. So if you're working
123: in session A, walk the history back through several sessions to land on B, and
124: press toggle, you flip back to A — not to the session adjacent to B — because A
125: is what you were using and the walk never promoted the ones in between. But the
126: instant you produce output in a walked-to session, activity promotes it
127: immediately, so the dwell timer never gets in the way of active use. Press
128: toggle again and you're back on B (once B itself is relevant).
129: (blank)  ← SEPARATOR — PRESERVED, not in oldText
130: **How activity detection works.** ...  ← S2's region begins here
```

## What S1 deletes / rewrites (per item description LOGIC step)

1. **DELETE** the entire "type, switch panes/windows..." bullet (lines 109–116),
   including: the "primary signal" framing, the `monitor-activity` parenthetical,
   the `client_activity`/keystroke explanation, and the "background windows" aside.
2. **KEEP** the "select it directly" bullet (lines 116–118) — it becomes bullet #1.
3. **REWRITE** the "dwell on it" bullet: drop the "*without* typing/interacting"
   clause (it presupposes the activity poller). New wording (from doc_impact §3)
   frames dwell as "the fallback for silent presence: a session you only browsed
   to is not relevant until you've actually stayed on it."
4. **REWRITE** the "Walking through a session does not make it relevant" paragraph
   (lines 122–128): DELETE "But the instant you produce output... activity promotes
   it immediately, so the dwell timer never gets in the way of active use. Press
   toggle again and you're back on B (once B itself is relevant)." Replace with the
   dwell-promotes explanation per PRD §6: "If you instead stay on that walked-to
   session B long enough, dwell promotes it; press toggle and you're now
   oscillating between A and B."

## Target newText (16 lines, from architecture/doc_impact.md §3 paragraph 3)

Aligns 1:1 with PRD §6's two-cause promotion model.

```
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

**Line delta: 23 → 16 = net −7.** README 199 → 192 lines.

## Banned tokens in S1's region after edit (grep gate)

These must NOT appear anywhere in lines 106–(106+16) after the edit:
- `client_activity` / `activity timestamp` / `keystroke`
- `monitor-activity`
- `primary signal` / `*primary*`
- `produce output` / `activity promotes`
- `typing/interacting` / `*without* typing`
- `poller` / `~0.5–1 s` / `half a second`
- `background windows` / `pane/window switches` (in the activity sense)

Note: the word "activity" may still appear OUTSIDE S1's region — most notably in
S2's "**How activity detection works.**" subsection (line 130+) which S1 must NOT
touch, and in S2's async-paths paragraph. S1's grep gate is scoped to its own
edit region, not the whole file. (Whole-file activity removal is the union of
S1+S2+T2.S1+T2.S2.)

## PRD authority

- **PRD §6** (Relevance): "promoted by exactly two causes: (1) Direct selection
  ... (2) Dwell ... Walking never promotes." This is the spec the rewrite matches.
- **PRD §12** (Why there is no output-activity signal): `alert-activity` is
  "unusable" (fires only for non-focused/background windows); "It is therefore
  not wired. Relevance comes from selection and dwell only." This is why the
  "type/switch panes" bullet is deleted, not retained.
- **PRD §2 Key invariant**: "Selecting or dwelling promotes in the relevance
  list but, for walks, leaves the timeline intact." Confirms two causes.

## Parallel-execution safety (S1 || S2)

- S1 region = README lines 106–128; S2 region = README lines 130–148.
  Separated by the blank line 129 (preserved by both).
- Disjoint regions → no collision regardless of merge order.
- S1 is net −7; if S1 lands first, S2's region shifts from 130–148 → 123–141.
  S2 must anchor on TEXT ("**How activity detection works.**"), not line numbers.
  Same in reverse for S1 (anchor on "A session becomes relevant").
- Both regions have unique text anchors, so the `edit` tool's exact-match works
  in either order.

## Code-state dependency (CONTRACT)

The item description says "The engine has already been refactored (P1.M1 done)
so the code reflects selection+dwell-only." Verified via plan_status:
P1.M1.T1 (activity funcs removed) = Complete; P1.M1.T3 (dwell default) = Complete;
P1.M1.T4 (header comments) = Complete; P1.M1.T2 = Ready but engine file already
reflects post-removal (per P1M2T1S2 PRP, grep-verified: `do_start_poller`=0). So
the README is being brought INTO ALIGNMENT with already-refactored code. No code
dependency blocking this doc task.