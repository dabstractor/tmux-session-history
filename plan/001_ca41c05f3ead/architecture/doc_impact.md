# Documentation Impact Analysis — README.md vs PRD.md

**Scope:** What `README.md` must change so the user-facing docs describe the
PRD's desired final state: relevance comes from **selection + dwell only**.
No `client_activity` polling, no background poller, no per-pane `pipe-pane`
processes, and `@session-history-dwell-ms` default of **30000**.

**Ground truth verified:**
- The *current* code still implements `client_activity` polling
  (`scripts/session_history.sh` `do_poller`/`do_activity` at lines 321–403;
  `session_history.tmux:55` defaults dwell to `10000`). So today's README is
  **accurate to the implementation but stale relative to the PRD target**.
- The current code default for dwell is `10000` in both `session_history.tmux:55`
  and `scripts/session_history.sh:154`. (These code edits are out of scope for
  the README task but are flagged as required companion changes.)
- The README is **internally inconsistent today**: the Options table (line 86)
  says `10000`, while the "How it works" body (line 119) already says
  "default 30 s". The refactor reconciles both to 30000.

Files referenced: `README.md` (current), `PRD.md` (target spec),
`scripts/session_history.sh`, `session_history.tmux`.

---

## 1. Every README section referencing ACTIVITY DETECTION

### 1a. `## Options` table — `@session-history-dwell-ms` row (README.md:86)
**Severity: High (factual, user-facing default).**
Current text frames dwell as a *fallback* because "working there (typing,
switching panes, any tmux command) promotes it immediately regardless" — this
presupposes the activity poller. In the target state there is **no** immediate
promote-on-input path, so dwell is no longer merely a "fallback"; for a
walked-to session it is the **only** way to become relevant (besides leaving and
re-selecting). Must be rewritten — see §4 below.

### 1b. `## How it works` — promotion bullet list (README.md:106–128)
**Severity: High (core behavioral description).**
- **Line 109–115** — the "type, switch panes/windows, or run any tmux command"
  bullet is the **primary** signal described. This entire bullet must be
  **removed**: in the target state input does not promote. The PRD §6 lists
  exactly two promotion causes: direct selection and dwell.
- **Lines 122–128** — the "But the instant you produce output in a walked-to
  session, activity promotes it immediately, so the dwell timer never gets in
  the way of active use" paragraph is false in the target state. In target
  state, a walked-to session is promoted **only** by dwell timing out (or by
  the user navigating/toggling away and back). Rewrite — see §3.

### 1c. `## How it works` — "How activity detection works" subsection (README.md:130–140)
**Severity: High (entire subsection describes a removed feature).**
This whole bolded subsection ("How activity detection works.") describes the
`client_activity` timestamp, the background poller (~0.5–1 s), and the "no
per-pane pipes / one resident process" framing. **Remove the subsection
entirely.** What replaces it — see §6.

### 1d. `## How it works` — async-paths paragraph (README.md:142–148)
**Severity: High.**
"The dwell timer is one asynchronous path; **focused-activity detection is the
other.**" In the target state there is **only one** asynchronous path: dwell.
The "focused-activity detection is the other" clause and "The moment you
produce output there, activity promotes it instead" (lines 146–147) must be
removed. The paragraph should describe dwell as the sole async path touching
only `tlist` (PRD §8). Rewrite — see §3.

### 1e. `## Troubleshooting` (README.md:185–189)
**Severity: Medium (misleads debugging).**
"a session enters the relevance list when you select it, **produce output in it
while viewing it**, or dwell on it" and "Walked-past sessions are intentionally
skipped **(unless you then produce output in them)**" — both reference the
removed output-activity signal. Must be reduced to **selection + dwell**. See §7.

### 1f. `## How it works` — close-current paragraph (README.md:150–153)
**Severity: Low (correct in substance, one wording tweak).**
The behavior described ("landing session will not become a toggle target until
you actually select it **or dwell on it**") is already target-aligned — good.
No activity reference here. Leave as-is (or lightly tightened).

### 1g. `## Keys` — opt-in callout (README.md:73–76)
**Severity: None (no activity reference).** Already says "the relevance list,
the dwell timers — is wired unless … toggle-key is set." Target-aligned. No
change needed, but worth noting the PRD's gating section (§9) confirms there are
**no resident processes at all** with toggle unbound — the existing phrasing
holds.

### 1h. `## Features` (README.md:19–23)
**Severity: None.** The Toggle blurb ("walking past a session… never makes it a
toggle target — you have to select it or stay on it") is target-aligned.
"Select it or stay on it" maps exactly to PRD §6 (selection + dwell). No change.

---

## 2. Every `10000` dwell-ms default that must become `30000`

There is **exactly one** `10000` occurrence in README.md:

| Location | Current | Target | Action |
|---|---|---|---|
| README.md:86 (`## Options` table, `@session-history-dwell-ms` row) | `10000` | `30000` | Change cell to `` `30000` `` |

Note: the **body** of "How it works" at README.md:119 already says
"default 30 s", so after fixing line 86 the doc becomes internally consistent
at 30000. No other `10000` appears in README.md (verified by grep).

**Companion code changes (NOT in README scope, but must happen together or the
docs will lie):**
- `session_history.tmux:55` — `tmux set-option -g '@session-history-dwell-ms' 10000` → `30000`
- `scripts/session_history.sh:154` — `dwell_ms()` fallback `echo 10000` → `echo 30000`
- `scripts/session_history.sh:58` comment "default 10000 ms" → "30000 ms"
- PRD §15/§16 already specify 30000; PRD is the source of truth.

---

## 3. Outline: what `## How it works` should say AFTER the refactor

The section keeps its two-state structure (timeline + relevance list) but the
**promotion model** changes from three causes (input / selection / dwell) to
**two causes (selection / dwell)**.

**Paragraph 1 — The timeline (unchanged, lines 93–99).** Keep verbatim. No
activity references.

**Paragraph 2 — The relevance list (lines 101–104).** Keep verbatim.

**Paragraph 3 — "A session becomes relevant…" (REWRITE, replacing 106–128).**
State the two — and only two — promotion causes:

> A session becomes relevant — is promoted to the front of the relevance list —
> when you either:
>
> - **select it directly** — via toggle, pick, tmux-sessionx, or a manual
>   `switch-client`. The session you go to becomes relevant immediately.
> - **dwell on it** — reach it by walking (back/forward) and stay longer than
>   `@session-history-dwell-ms` (default 30 s). This is the fallback for silent
>   presence (reading, thinking): a session you only browsed to is not relevant
>   until you've actually stayed on it.
>
> Walking through a session does **not** make it relevant by itself. So if
> you're working in session A, walk the history back through several sessions to
> land on B, and press toggle, you flip back to A — not to the session adjacent
> to B — because A is what you were using and the walk never promoted the ones
> in between. If you instead stay on a walked-to session B long enough, dwell
> promotes it; press toggle and you're now oscillating between A and B.

Key deletions from current text: the entire "type, switch panes/windows, or run
any tmux command… primary signal" bullet; the `monitor-activity` parenthetical;
the `client_activity` explanation; and "the instant you produce output…
activity promotes it immediately, so the dwell timer never gets in the way."

**Paragraph 4 — (REPLACE the "How activity detection works" subsection + the
async-paths paragraph, lines 130–148).** Replace with a concise dwell-only
paragraph:

> The dwell timer is the only asynchronous path, and it touches only the
> relevance list (never the timeline), so a rare lost update only nudges
> relevance and self-heals on the next switch. When you walk onto a session, a
> background timer is armed; if you're still on that session when it fires, the
> session is promoted. The timer self-cancels if you've moved on, so stale
> timers are harmless.

Optionally add one sentence aligning with PRD §12 — *why* there is no
input/output signal:

> Relevance intentionally comes from selection and dwell only: there is no
> robust tmux primitive for "the focused session produced output" without a
> resident process per pane, and tmux's `monitor-activity` only sees
> *background* windows — the opposite of what toggle needs.

**Remaining paragraphs (close-current 150–153, sessionx composition 155–157,
capping 159–161).** Keep; all are target-aligned.

---

## 4. Options table — `@session-history-dwell-ms` row AFTER the refactor

Current (README.md:86):
> \| `@session-history-dwell-ms` | `10000` | Fallback for *silent* presence: how
> long you must stay on a session you *walked* to (back/forward) without
> typing/interacting before it counts as relevant. Working there (typing,
> switching panes, any tmux command) promotes it immediately regardless. `0`
> disables dwell (relevance then comes only from selecting a session or
> interacting with it). \|

Proposed target:
> \| `@session-history-dwell-ms` | `30000` | How long you must stay on a session
> you *walked* to (back/forward) before it counts as relevant. This is the only
> way a walked-to session becomes a toggle target besides re-selecting it. `0`
> disables dwell — relevance then comes only from selecting a session (toggle,
> pick, tmux-sessionx, or a manual switch). \|

Rationale: drop "fallback", "typing/interacting", "Working there (typing,
switching panes, any tmux command) promotes it immediately", and the
"interacting with it" in the `0` clause — all describe the removed activity
signal. Bump default to `30000`.

---

## 5. `pipe-pane` / per-pane process content to remove

The README's **only** `pipe-pane`/per-pane reference is in the "How activity
detection works" subsection:

- **README.md:138–139** — "There are no per-pane pipes and only one resident
  process; with toggle unbound there are no resident processes at all."

This sentence is **correct as a fact** (the current code indeed has no
pipe-pane), but it exists only to distinguish the poller design from a
pipe-pane design. Once the whole subsection is removed (§1c), this reference is
removed with it and does **not** need to be re-homed. The target design has no
resident process *and* no poller, so the distinction is moot.

Suggested single replacement line (optional, fits the dwell paragraph in §3):
> With toggle unbound there are no resident processes at all; with it bound the
> only background work is short-lived one-shot dwell timers (no long-running
> poller, no per-pane pipes).

**Other README occurrences of pipe-pane/per-pane:** none (verified by grep
across README.md). The git history shows pipe-pane was the *previous*
implementation, already replaced by `client_activity` polling — the README
predates that and only carries the "no per-pane pipes" reassurance.

---

## 6. The "How activity detection works" subsection — remove entirely?

**Yes — remove it entirely (README.md:130–140).**

Reasons:
1. Its entire content (the `client_activity` timestamp, the background poller,
   the ~0.5–1 s promotion latency, the switch-key-doesn't-count explanation)
   describes a feature the PRD removes (PRD §6, §12).
2. There is no target behavior to document under that heading — the target has
   **no activity detection**. Keeping a renamed section would be misleading.

**What replaces it:** nothing under that heading. The information a user still
needs is folded into the rewritten "How it works" promotion model (§3) and the
options row (§4):
- "Walking never promotes" → stays in the promotion paragraph.
- "Why dwell exists / how the timer works" → the new async-paths paragraph (§3,
  paragraph 4).
- "Why no input signal" → optional one-liner citing `monitor-activity`
  background-only limitation (PRD §12).

The Troubleshooting "wrong session" guidance (§7) is the natural home for the
remaining "relevance, not recency" explanation, which already lives there.

---

## 7. Troubleshooting section — activity/typing/output references

**README.md:185–189** — two references to the removed signal:
- Line 186–187: "a session enters the relevance list when you select it,
  **produce output in it while viewing it**, or dwell on it."
- Line 187–188: "Walked-past sessions are intentionally skipped **(unless you
  then produce output in them)**."

Proposed target rewrite:
> If toggle seems to target the "wrong" session, remember it tracks *relevance*,
> not recency: a session enters the relevance list only when you select it or
> dwell on it long enough. Walked-past sessions are intentionally skipped — if
> you want a silent walk to "stick" sooner, lower `@session-history-dwell-ms`
> (or set it to `0` and only direct selections will ever count).

Drop both "produce output … while viewing it" and "unless you then produce
output in them". The `status`/`reset` debug helpers (lines 173–183) have **no**
activity references and need no change.

---

## 8. Desired final state of README.md, section by section

| Section | Lines | Change |
|---|---|---|
| Title + intro | 1–6 | **None.** No activity references. |
| `## Why` | 8–15 | **None.** No activity references. |
| `## Features` | 17–28 | **None.** "Select it or stay on it" is already selection+dwell aligned. |
| `## Install` | 30–50 | **None.** |
| `## Keys` | 52–76 | **None.** Opt-in callout (73–76) is target-aligned; no resident-process claim needs editing. (Optional: line 75 "the engine starts tracking relevance" is fine.) |
| `## Options` | 78–87 | **CHANGE line 86 only** — `10000` → `30000` and rewrite dwell row text per §4. All other rows unchanged. |
| `## How it works` | 89–161 | **REWRITE 106–148** per §3: remove input-promotion bullet (109–115), remove "produce output … activity promotes" (126–127), **delete entire "How activity detection works" subsection (130–140)** per §6, rewrite async-paths paragraph (142–148) to dwell-only. Keep timeline paragraph (93–99), relevance-list paragraph (101–104), close-current (150–153), sessionx composition (155–157), capping (159–161). |
| `## Requirements` | 163–169 | **None.** tmux version / fzf requirements unaffected by removing the poller. (If anything, removing the poller slightly *lowers* requirements — no change needed.) |
| `## Troubleshooting` | 171–189 | **CHANGE 185–189** per §7 — remove "produce output" clauses; reduce to selection + dwell. `status`/`reset` helpers (173–183) unchanged. |
| `## Limitations` | 191–195 | **Optional minor add.** Current text only mentions single-client. Consider adding the PRD §19 "No output-activity signal by design; relevance is selection + dwell" as a one-line limitation for completeness, and note dwell granularity is whole seconds. (Not strictly required; the "How it works" rewrite covers it.) |
| `## License` | 197–199 | **None.** |

**Net effect on README length:** removes one bolded subsection (~11 lines) and
two short passages; adds back a shorter dwell-only paragraph (~6 lines) and
optionally a one-liner "why no input signal". README shrinks slightly and
becomes internally consistent on the 30000 default.

---

## 9. Cross-document consistency checks (residual risks)

1. **README ↔ code default drift (HIGH risk).** If the README is updated to
   `30000` but `session_history.tmux:55` / `session_history.sh:154` stay at
   `10000`, the docs will lie. The dwell default change must land in code and
   docs in the same change. (Code files are out of README scope but flagged.)
2. **README ↔ PRD §12 alignment.** The PRD explicitly dedicates §12 to "Why
   there is no output-activity signal." The README should at least nod to this
   (optional one-liner in §3) so users aren't surprised that *typing* no longer
   promotes — this is the single most user-visible behavioral change.
3. **Poller subcommand reference.** `scripts/session_history.sh:649` usage
   string lists `activity|poller` subcommands. Removing the poller from the
   engine means those subcommands disappear; not a README concern, but any
   "internal commands" doc (none in README today) should be updated. README has
   no such list, so no README impact.
4. **Concurrency framing.** PRD §13 still lists `activity` among locked
   subcommands in the *current* spec snapshot; the target removes it. README
   has no concurrency section, so no impact — flagged only for the engine doc.
5. **The "one resident process" claim.** Current README line 139 says "only one
   resident process." Target has **zero** resident processes (only one-shot
   dwell `run-shell -b` sleeps). The rewrite in §3/§5 already corrects this;
   ensure no stray copy remains.