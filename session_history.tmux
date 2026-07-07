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

# All three hooks run SYNCHRONOUSLY (no -b). Each does a read-modify-write on the
# @session-history-* options, so an async (-b) hook would race the navigation
# hook and clobber current/prev/idx via a lost update, corrupting toggle.
# Synchronous hooks serialize through tmux's command loop -> no lost updates.
# client-session-changed is the spine: every switch flows through it, which is
# how we tell WALKS (back/forward) from NAVIGATIONS (toggle/pick/sessionx/manual).
# session-closed prunes dead entries; session-created re-prunes and caps the
# timeline to the number of open sessions, so history never outlives sessions.
tmux set-hook -g client-session-changed "run-shell '${SCRIPT} hook \"#{session_name}\"'"
tmux set-hook -g session-closed         "run-shell '${SCRIPT} prune \"#{session_name}\"'"
tmux set-hook -g session-created        "run-shell '${SCRIPT} maintain'"
tmux run-shell "${SCRIPT} init"

# --- key bindings (all overridable) -------------------------------------------
# Only toggle is bound by default (L). back/forward/pick ship unbound so users
# wire the keys they want in their tmux.conf via the options below. An empty
# option value leaves that key unbound.
toggle_key="$(get_tmux_option  '@session-history-toggle-key'  'L')"
back_key="$(get_tmux_option    '@session-history-back-key'    '')"
forward_key="$(get_tmux_option '@session-history-forward-key' '')"
pick_key="$(get_tmux_option    '@session-history-pick-key'    '')"
[ -n "$toggle_key" ]  && tmux bind-key "$toggle_key"  run-shell "${SCRIPT} toggle  \"#{session_name}\""
[ -n "$back_key" ]    && tmux bind-key "$back_key"    run-shell "${SCRIPT} back    \"#{session_name}\""
[ -n "$forward_key" ] && tmux bind-key "$forward_key" run-shell "${SCRIPT} forward \"#{session_name}\""
[ -n "$pick_key" ]    && tmux bind-key "$pick_key"    run-shell "${SCRIPT} pick    \"#{session_name}\""

# The bind lines above short-circuit to false (exit 1) when their key is empty;
# end on a no-op so plugin load always reports success.
:
