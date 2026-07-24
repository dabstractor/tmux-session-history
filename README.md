# tmux-session-history

Browser-style back and forward, an Alt-Tab style toggle that flips between the
two sessions you're *actually using*, and an fzf picker for moving between tmux
sessions. The plugin keeps one duplicate-free timeline of the sessions you have
visited and moves a cursor through it.

## Why

tmux's `switch-client -l` flips to the last session, but it fails silently when
that session no longer exists, and it has no concept of forward. Session
pickers such as tmux-sessionx jump to any session, but every jump is a fresh
start with no back button. This plugin gives session switching a real history
cursor — and a toggle that targets the sessions you're working in, not just the
ones you most recently clicked past.

## Features

- **Toggle** flips to the other session you're *actively using*, Alt-Tab style.
  It tracks relevance, not recency: walking past a session with back/forward
  never makes it a toggle target — you have to select it or stay on it. If the
  target was closed, it self-heals to the nearest live relevant session instead
  of breaking.
- **Back** moves toward older entries in the timeline.
- **Forward** moves toward newer entries. It does nothing at the tip, like a
  browser.
- **Pick** lists your live history in fzf, most recent first, and switches to
  your choice.

## Install

With [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'dabstractor/tmux-session-history'
```

Reload your config and press `prefix + I` to install.

Manual:

```sh
git clone https://github.com/dabstractor/tmux-session-history ~/.tmux/plugins/tmux-session-history
```

```tmux
run-shell ~/.tmux/plugins/tmux-session-history/session_history.tmux
```

**Nothing is bound by default.** Pick the keys you want (see [Keys](#keys)).

## Keys

All four actions ship **unbound**. There is no universally free, mnemonic key
worth hardcoding for any of them, so each is opt-in:

```tmux
set -g @session-history-toggle-key  'M-Space'   # Alt-Tab style flip
set -g @session-history-back-key    'C-F9'      # walk toward older sessions
set -g @session-history-forward-key 'C-F10'     # walk toward newer sessions
# set -g @session-history-pick-key  'C-S-l'     # optional: fzf picker (needs fzf)
```

| Action | Default | Option | What it does |
|---|---|---|---|
| Toggle | unbound | `@session-history-toggle-key` | flip to the other most-*relevant* session (self-healing) |
| Back | unbound | `@session-history-back-key` | walk toward older entries |
| Forward | unbound | `@session-history-forward-key` | walk toward newer entries |
| Pick | unbound | `@session-history-pick-key` | fzf picker over live history (opt-in, needs fzf) |

Set any key to an empty string (or leave it unset) to leave it unbound.

> **Toggle is load-bearing opt-in.** None of the relevance machinery — the
> relevance list, the dwell timers — is wired unless `@session-history-toggle-key`
> is set. The moment you bind it, the engine starts tracking relevance; with it
> unbound, the plugin only runs the lightweight history engine for back/forward/pick.

## Options

| Option | Default | Purpose |
|---|---|---|
| `@session-history-toggle-key` | (empty) | Key bound to toggle. Empty leaves it unbound and disables the whole relevance feature. |
| `@session-history-back-key` | (empty) | Key bound to back. Empty leaves it unbound. |
| `@session-history-forward-key` | (empty) | Key bound to forward. Empty leaves it unbound. |
| `@session-history-pick-key` | (empty) | Key bound to pick. Empty leaves it unbound. |
| `@session-history-dwell-ms` | `8000` | Fallback for *silent* presence: how long you must stay on a session you *walked* to (back/forward) without typing/interacting before it counts as relevant. Working there (typing, switching panes, any tmux command) promotes it immediately regardless. `0` disables dwell (relevance then comes only from selecting a session or interacting with it). |
| `@session-history-popup` | `on` | Use an fzf-tmux popup for pick. Set `off` for inline fzf. |

## How it works

There are two independent pieces of state:

**The timeline** (always on, for back/forward). Every session switch fires
`client-session-changed`. Back and forward set a flag naming their target
before they switch, so the hook moves the cursor without touching the timeline.
Any other switch (pick, tmux-sessionx, a manual `switch-client`) carries no
flag, so the hook drops forward history and appends the new session at the tip.
That is why forward is dead after a jump, until you walk back again — strict
browser semantics.

**The relevance list** (only when toggle is bound). This is a second, separate
list of sessions ordered by recency of *use*. Toggle flips the cursor to the
first live entry of this list that isn't your current session — i.e. the two
most-recently-used sessions oscillate.

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
  `@session-history-dwell-ms` (default 8 s) *without* producing output. This is
  the fallback for silent presence (reading, thinking).

Walking through a session does **not** make it relevant by itself. So if you're working
in session A, walk the history back through several sessions to land on B, and
press toggle, you flip back to A — not to the session adjacent to B — because A
is what you were using and the walk never promoted the ones in between. But the
instant you produce output in a walked-to session, activity promotes it
immediately, so the dwell timer never gets in the way of active use. Press
toggle again and you're back on B (once B itself is relevant).

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

When a session closes it is pruned from both lists and everything shifts down.
Nothing is ever auto-added in its place, so closing the session you're currently
on does **not** promote whatever tmux moves you to — that landing session will
not become a toggle target until you actually select it or dwell on it.

The plugin composes with tmux-sessionx and other pickers. Switches made through
them count as direct selections and promote relevance, the same as a manual
switch.

Both lists are capped at the number of sessions currently open and pruned of
dead sessions on close/create, so neither ever references sessions that no
longer exist or grows past the number open.

## Requirements

- tmux 2.4 or newer for toggle, back, and forward.
- tmux 3.2 or newer for the fzf-tmux popup used by pick. Set
  `@session-history-popup off` for inline fzf on older tmux.
- [fzf](https://github.com/junegunn/fzf) for pick only. The other three actions
  need nothing beyond tmux.

## Troubleshooting

The engine script has helpers for debugging:

- `status` prints the current timeline (cursor in brackets) and the relevance
  list in the tmux message line.
- `reset` clears all state and starts over.

Run them through the script under your plugin directory, for example:

```sh
~/.tmux/plugins/tmux-session-history/scripts/session_history.sh status
```

If toggle seems to target the "wrong" session, remember it tracks *relevance*,
not recency: a session enters the relevance list when you select it, produce
output in it while viewing it, or dwell on it. Walked-past sessions are
intentionally skipped (unless you then produce output in them). Lower
`@session-history-dwell-ms` if you want silent walks to "stick" sooner.

## Limitations

Single attached client. State is global, so two clients switching sessions
independently share one timeline and one relevance list. Multi-client support
is not implemented.

## License

[MIT](LICENSE).