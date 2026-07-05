#!/usr/bin/env bash
# session_history.tmux — tmux-session-history plugin entry point.
#
# Wires the reactive engine (hooks + bootstrap) and binds the four navigation
# keys. Every key is overridable via a tmux option so users can rebind without
# forking. Designed to be reload-safe: hooks/keys/init are all idempotent.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${CURRENT_DIR}/scripts/session_history.sh"

# $1: option name, $2: default value
get_tmux_option() {
    local value
    value="$(tmux show-option -gqv "$1")"
    [ -n "$value" ] && echo "$value" || echo "$2"
}

# --- reactive engine wiring ---------------------------------------------------
# client-session-changed is the spine: every switch flows through it, which is
# how we tell WALKS (back/forward) from NAVIGATIONS (toggle/pick/sessionx/manual).
# session-closed prunes dead entries so the timeline never dangles.
tmux set-hook -g client-session-changed "run-shell '${SCRIPT} hook \"#{session_name}\"'"
tmux set-hook -g session-closed         "run-shell -b '${SCRIPT} prune \"#{session_name}\"'"
tmux run-shell "${SCRIPT} init"

# --- key bindings (all overridable) -------------------------------------------
toggle_key="$(get_tmux_option  '@session-history-toggle-key'  'L')"
back_key="$(get_tmux_option    '@session-history-back-key'    'C-F9')"
forward_key="$(get_tmux_option '@session-history-forward-key' 'C-F10')"
pick_key="$(get_tmux_option    '@session-history-pick-key'    '')"

# pick is opt-in (needs fzf); the other three are bound by default. An empty
# option value leaves the key unbound so users can disable any of them.
[ -n "$toggle_key" ]  && tmux bind-key "$toggle_key"  run-shell "${SCRIPT} toggle  \"#{session_name}\""
[ -n "$back_key" ]    && tmux bind-key "$back_key"    run-shell "${SCRIPT} back    \"#{session_name}\""
[ -n "$forward_key" ] && tmux bind-key "$forward_key" run-shell "${SCRIPT} forward \"#{session_name}\""
[ -n "$pick_key" ]    && tmux bind-key "$pick_key"    run-shell "${SCRIPT} pick    \"#{session_name}\""
