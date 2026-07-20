#!/usr/bin/env bash
# session_history.tmux — tmux-session-history plugin entry point.
#
# Wires the reactive engine (hooks + bootstrap) and binds the navigation keys.
# Every key is overridable via a tmux option so users can rebind without
# forking. Designed to be reload-safe: hooks/keys/init are all idempotent.
#
# TOGGLE IS OPT-IN. The toggle feature (Alt-Tab flip between the two most
# *relevant* sessions) does NOTHING unless the user sets @session-history-toggle-
# key. When that key is empty (the default), we set @session-history-toggle-
# enabled off and the engine skips all relevance tracking and dwell timers — no
# extra hooks, no background sleepers, no monitor-activity. The moment a toggle
# key is bound we flip the flag on and the engine starts maintaining the
# relevance list. See scripts/session_history.sh for the full model.

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
# hook and clobber current/idx/mode via a lost update, corrupting navigation.
# Synchronous hooks serialize through tmux's command loop -> no lost updates.
# client-session-changed is the spine: every switch flows through it, which is
# how we tell WALKS (back/forward) and TOGGLES from NAVIGATIONS (pick/sessionx/
# manual). session-closed prunes dead entries from both the timeline and the
# relevance list; session-created re-prunes and caps both to the open-session
# count, so neither list ever references sessions that no longer exist or grows
# past the number open.
tmux set-hook -g client-session-changed "run-shell '${SCRIPT} hook \"#{session_name}\"'"
tmux set-hook -g session-closed         "run-shell '${SCRIPT} prune \"#{session_name}\"'"
tmux set-hook -g session-created        "run-shell '${SCRIPT} maintain'"

# --- key bindings (all overridable) -------------------------------------------
# All four actions ship UNBOUND by default. There is no universally free,
# mnemonic key worth hardcoding for any of them, so each is opt-in. Set any key
# to an empty string (or leave it unset) to leave it unbound.
toggle_key="$(get_tmux_option  '@session-history-toggle-key'  '')"
back_key="$(get_tmux_option    '@session-history-back-key'    '')"
forward_key="$(get_tmux_option '@session-history-forward-key' '')"
pick_key="$(get_tmux_option    '@session-history-pick-key'    '')"

# Default the dwell threshold once (user can override before or after load).
[ -z "$(get_tmux_option '@session-history-dwell-ms' '')" ] && \
    tmux set-option -g '@session-history-dwell-ms' 8000

# Toggle is a load-bearing opt-in: the enabled flag tells the engine whether to
# maintain the relevance list and arm dwell timers. Bind the key ONLY when set,
# and mirror the flag either way so the engine always reads a definitive value.
if [ -n "$toggle_key" ]; then
    tmux set-option -g '@session-history-toggle-enabled' on
    tmux bind-key "$toggle_key" run-shell "${SCRIPT} toggle \"#{session_name}\""
else
    tmux set-option -g '@session-history-toggle-enabled' off
fi
[ -n "$back_key" ]    && tmux bind-key "$back_key"    run-shell "${SCRIPT} back    \"#{session_name}\""
[ -n "$forward_key" ] && tmux bind-key "$forward_key" run-shell "${SCRIPT} forward \"#{session_name}\""
[ -n "$pick_key" ]    && tmux bind-key "$pick_key"    run-shell "${SCRIPT} pick    \"#{session_name}\""

# --- focused-activity detection (only with toggle bound) --------------------
# The relevance list's PRIMARY signal is output/typing in the session you are
# viewing. tmux's alert-activity cannot see the focused window, so the engine
# keeps a pipe-pane on the focused pane and promotes its session on output (see
# scripts/session_history.sh). Focus is followed by a background poller started
# from do_init (pane-focus-in proved unreliable for intra-session switches), so
# NOTHING extra is wired here — no hooks, no focus-events forcing. With toggle
# unbound the poller is never started: no resident processes, no pipes.

# Bootstrap the engine LAST, after every option/hook/key above is in place —
# do_init reads @session-history-toggle-enabled (set by the toggle block) to
# decide whether to start the focused-activity poller, so it must run after that
# flag is set (calling it earlier raced the async run-shell ahead of the toggle
# block and left the poller unset on reload).
tmux run-shell "${SCRIPT} init"

# The bind lines above short-circuit to false (exit 1) when their key is empty;
# end on a no-op so plugin load always reports success.
: