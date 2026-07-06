# tmux-session-history

Browser-style back and forward, an Alt-Tab style toggle, and an fzf picker for
moving between tmux sessions. The plugin keeps one duplicate-free timeline of
the sessions you have visited and moves a cursor through it.

## Why

tmux's `switch-client -l` flips to the last session, but it fails silently when
that session no longer exists, and it has no concept of forward. Session
pickers such as tmux-sessionx jump to any session, but every jump is a fresh
start with no back button. This plugin gives session switching a real history
cursor.

## Features

- **Toggle** flips to the session you were just in, Alt-Tab style. If that
  session was closed, it falls back to the nearest live session instead of
  breaking.
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

## Keys

Only toggle is bound by default. Bind the others to whatever you want, all
under the prefix:

| Action | Default | Change with |
|---|---|---|
| Toggle to previous session | `L` | `@session-history-toggle-key` |
| Back | unbound | `@session-history-back-key` |
| Forward | unbound | `@session-history-forward-key` |
| Pick from history | unbound | `@session-history-pick-key` |

For example:

```tmux
set -g @session-history-back-key    'C-F9'
set -g @session-history-forward-key 'C-F10'
set -g @session-history-pick-key    'C-S-l'   # pick is opt-in (needs fzf)
```

Set any key option to an empty string to leave that action unbound.

## Options

| Option | Default | Purpose |
|---|---|---|
| `@session-history-toggle-key` | `L` | Key bound to toggle. |
| `@session-history-back-key` | (empty) | Key bound to back. Empty leaves it unbound. |
| `@session-history-forward-key` | (empty) | Key bound to forward. Empty leaves it unbound. |
| `@session-history-pick-key` | (empty) | Key bound to pick. Empty leaves it unbound. |
| `@session-history-popup` | `on` | Use an fzf-tmux popup for pick. Set `off` for inline fzf. |

## How it works

Every session switch fires `client-session-changed`. Back and forward set a
flag naming their target before they switch, so the hook moves the cursor
without touching the timeline. Any other switch (toggle, pick, tmux-sessionx,
or a manual `switch-client`) carries no flag, so the hook drops forward history
and appends the new session at the tip. That is why forward is dead after a
jump, until you walk back again.

The plugin composes with tmux-sessionx and other pickers. Switches made through
them count as new navigation points, the same as a manual switch.

The timeline is capped at the number of sessions currently open. When a session
is closed, `session-closed` prunes it from history; when one is created,
`session-created` prunes any dead entries and trims the timeline down to the
open-session count, so history never references sessions that no longer exist
and never grows past the number open.

## Requirements

- tmux 2.4 or newer for toggle, back, and forward.
- tmux 3.2 or newer for the fzf-tmux popup used by pick. Set
  `@session-history-popup off` for inline fzf on older tmux.
- [fzf](https://github.com/junegunn/fzf) for pick only. The other three actions
  need nothing beyond tmux.

## Troubleshooting

The engine script has two helpers for debugging:

- `status` prints the current timeline in the tmux message line, with the
  cursor marked in brackets.
- `reset` clears all state and starts the timeline over.

Run them through the script under your plugin directory, for example:

```sh
~/.tmux/plugins/tmux-session-history/scripts/session_history.sh status
```

## Limitations

Single attached client. State is global, so two clients switching sessions
independently share one timeline. Multi-client support is not implemented.

## License

[MIT](LICENSE).
