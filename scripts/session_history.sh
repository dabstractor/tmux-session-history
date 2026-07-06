#!/usr/bin/env bash
# scripts/session_history.sh — tmux-session-history engine
#
# Four session-navigation primitives over a single duplicate-free timeline:
#
#   toggle   — flip to the session you were just in (Alt-Tab style). Self-heals:
#              if that session was deleted, falls back to the nearest live
#              neighbor instead of breaking like `switch-client -l`.
#   back     — browser-style walk toward older entries.
#   forward  — browser-style walk toward newer entries (dead at the tip).
#   pick     — fzf picker over live history (most-recent-first).
#
# Strict browser semantics: back/forward WALK the timeline; any other switch
# (toggle, picker, sessionx, manual) is a NAVIGATION that collapses forward
# history and becomes the end of the road — pressing forward from there does
# nothing, exactly like a browser.
#
# MODEL (tmux global user options; namespaced @session-history-*):
#   @session-history-hist     ordered timeline of visited sessions, NO DUPLICATES
#   @session-history-idx      cursor position (index of the current session)
#   @session-history-current  last-known current session (so the hook can diff from→to)
#   @session-history-prev     the session the toggle flips to
#   @session-history-walk     transient flag: a walk (back/forward) names its
#                             target here so the hook knows NOT to collapse history
#
# How the hook tells a walk from a navigation:
#   • back/forward set @session-history-walk = <target> an instant before they
#     switch. The synchronous client-session-changed hook fires, sees the flag
#     matches the landing session, and does a pure cursor move (no truncate).
#   • any switch WITHOUT a matching flag is a navigation: drop everything after
#     the cursor, append the new session (deduped) -> end of road, forward dead.
#
# Global state, single-client assumption. Maintained reactively by hooks; no
# probing session switches. session-closed prunes dead entries; session-created
# also caps the timeline to the number of open sessions. Subcommands take the
# invoking session as $1.

set -u

# Internal state option prefix (namespaced to avoid collisions).
P="@session-history"
H() { printf '%s-%s\n' "$P" "$1"; }   # H hist  -> @session-history-hist

G() { tmux show-options -gv "$1" 2>/dev/null; }
S() { tmux set-option -g "$1" "$2"; }
session_exists() { tmux has-session -t "$1" 2>/dev/null; }
attached_session() { tmux display-message -p '#{session_name}' 2>/dev/null; }

CURRENT="" IDX="0" PREV=""
HIST=()

load() {
    CURRENT="$(G "$(H current)")"
    IDX="$(G "$(H idx)")"; [ -z "$IDX" ] && IDX=0
    PREV="$(G "$(H prev)")"
    local raw; raw="$(G "$(H hist)")"
    HIST=()
    [ -n "$raw" ] || return
    local seen=""
    while IFS= read -r line; do           # dedup keeping first occurrence
        [ -n "$line" ] || continue
        case "$seen" in *"|""$line""|"*) continue ;; esac
        seen+="_|$line|_"; HIST+=("$line")
    done <<< "$raw"
    local j; j="$(index_of "$CURRENT" 2>/dev/null)" && IDX="$j"
}

save() {
    S "$(H current)" "$CURRENT"
    S "$(H idx)" "$IDX"
    S "$(H prev)" "$PREV"
    if [ "${#HIST[@]}" -eq 0 ]; then S "$(H hist)" ""
    else local IFS=$'\n'; S "$(H hist)" "${HIST[*]}"; fi
}

index_of() {
    local t="$1" i
    for i in "${!HIST[@]}"; do [ "${HIST[$i]}" = "$t" ] && { printf '%s\n' "$i"; return 0; }; done
    return 1
}

reconcile() {
    local cur="$1"; [ -z "$cur" ] && cur="$(attached_session)"; [ -z "$cur" ] && return
    if [ "$cur" != "$CURRENT" ]; then
        CURRENT="$cur"; local i; i="$(index_of "$cur")" && IDX="$i"
    fi
}

# --- the reactive engine: wired to client-session-changed --------------------
do_hook() {
    local to="$1" from i
    [ -z "$to" ] && to="$(attached_session)"; [ -z "$to" ] && return

    if [ -z "$CURRENT" ]; then                       # first fire / after reset
        HIST=("$to"); IDX=0; CURRENT="$to"; PREV="$to"; S "$(H walk)" ""; save; return
    fi
    [ "$to" = "$CURRENT" ] && { S "$(H walk)" ""; return; }

    from="$CURRENT"
    local walk idx
    walk="$(G "$(H walk)")"

    if [ -n "$walk" ] && [ "$walk" = "$to" ] && idx="$(index_of "$to")"; then
        IDX="$idx"                                     # WALK: pure cursor move
    else
        # NAVIGATION: keep backward history (..cursor) minus 'to', append 'to'.
        local nh=()
        for i in "${!HIST[@]}"; do
            [ "$i" -gt "$IDX" ] && break               # drop forward history
            [ "${HIST[$i]}" != "$to" ] && nh+=("${HIST[$i]}")
        done
        nh+=("$to")
        HIST=("${nh[@]}")
        IDX=$(( ${#HIST[@]} - 1 ))                     # end of road
    fi

    session_exists "$from" && PREV="$from"             # else leave PREV; toggle self-heals
    CURRENT="$to"
    S "$(H walk)" ""                                   # always clear the flag
    save
}

# --- trailing toggle (a NAVIGATION: flips to prev, lands at the tip of the
# stack so forward is dead afterward) ----------------------------------------
do_toggle() {
    load; reconcile "${1:-}"
    local cur="$CURRENT" target
    if [ -n "$PREV" ] && [ "$PREV" != "$cur" ] && session_exists "$PREV"; then
        target="$PREV"
    else
        target="$(fallback_target "$cur")"
    fi
    if [ -z "$target" ] || [ "$target" = "$cur" ]; then
        tmux display-message "session-history: no other session to toggle to"; return 0
    fi
    # No @session-history-walk flag: the hook treats this as a navigation -> the
    # target is deduped and appended at the tip, so afterward the user is at the
    # end of the road and can only go backward.
    tmux switch-client -t "$target"
}

fallback_target() {
    local cur="$1" i n="${#HIST[@]}" lo hi
    for (( i=1; i<=n; i++ )); do
        lo=$(( IDX - i )); hi=$(( IDX + i ))
        if [ "$hi" -lt "$n" ] && session_exists "${HIST[$hi]}" && [ "${HIST[$hi]}" != "$cur" ]; then
            printf '%s\n' "${HIST[$hi]}"; return
        fi
        if [ "$lo" -ge 0 ] && session_exists "${HIST[$lo]}" && [ "${HIST[$lo]}" != "$cur" ]; then
            printf '%s\n' "${HIST[$lo]}"; return
        fi
    done
    while IFS= read -r s; do [ "$s" != "$cur" ] && { printf '%s\n' "$s"; return; }; done \
        < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
}

# --- browser-style walk (flag the switch so the hook preserves the timeline) -
do_back() {
    load; reconcile "${1:-}"
    local i
    for (( i=IDX-1; i>=0; i-- )); do
        if session_exists "${HIST[$i]}" && [ "${HIST[$i]}" != "$CURRENT" ]; then
            S "$(H walk)" "${HIST[$i]}"; tmux switch-client -t "${HIST[$i]}"; return
        fi
    done
    tmux display-message "session-history: start of history"
}

do_forward() {
    load; reconcile "${1:-}"
    local i n="${#HIST[@]}"
    for (( i=IDX+1; i<n; i++ )); do
        if session_exists "${HIST[$i]}" && [ "${HIST[$i]}" != "$CURRENT" ]; then
            S "$(H walk)" "${HIST[$i]}"; tmux switch-client -t "${HIST[$i]}"; return
        fi
    done
    tmux display-message "session-history: end of history"
}

# --- fzf picker over live history (most-recent-first) ------------------------
do_pick() {
    load; reconcile "${1:-}"
    local cur="$CURRENT" items="" i s sel popup use_popup
    for (( i=${#HIST[@]}-1; i>=0; i-- )); do
        s="${HIST[$i]}"; [ "$s" = "$cur" ] && continue
        session_exists "$s" || continue
        items+="$s"$'\n'
    done
    [ -n "$items" ] || { tmux display-message "session-history: no history yet"; return 0; }

    popup="$(G "@session-history-popup")"; [ -z "$popup" ] && popup=on
    use_popup=off
    [ "$popup" = on ] && command -v fzf-tmux >/dev/null 2>&1 && use_popup=on

    if [ "$use_popup" = on ]; then
        sel="$(printf '%s' "$items" | fzf-tmux -p 60%,40% --prompt=' history❯ ' --border-label=' Session History ' --no-sort)"
    elif command -v fzf >/dev/null 2>&1; then
        sel="$(printf '%s' "$items" | fzf --prompt=' history❯ ' --no-sort)"
    else
        tmux display-message "session-history: fzf not installed (needed for pick)"; return 0
    fi
    # NOTE: no @session-history-walk flag -> the hook treats this as a NAVIGATION,
    # collapsing forward history (picker = end of road, like a browser).
    [ -n "$sel" ] && tmux switch-client -t "$sel"
    return 0
}

# --- prune dead sessions (wired to session-closed) ---------------------------
prune_dead() {
    local alive=() removed=0 i s
    for i in "${!HIST[@]}"; do
        s="${HIST[$i]}"
        if session_exists "$s"; then alive+=("$s")
        elif [ "$i" -lt "$IDX" ]; then removed=$((removed+1)); fi
    done
    HIST=("${alive[@]}")
    IDX=$(( IDX - removed )); [ "$IDX" -lt 0 ] && IDX=0
    if ! session_exists "$CURRENT"; then
        CURRENT="$(attached_session)"; local j; j="$(index_of "$CURRENT")" && IDX="$j"
    fi
    [ -n "$PREV" ] && { session_exists "$PREV" || PREV=""; }
}

# --- cap + maintenance (wired to session-created) ----------------------------
# Ceiling = number of sessions currently open. Because the timeline is
# duplicate-free and dead sessions are pruned, |HIST| is already <= the open
# count in practice; this trims any oldest stragglers that slip through, never
# dropping the live current session.
live_session_count() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null | wc -l
}

cap_to_live() {
    local cap; cap="$(live_session_count)"; [ -z "$cap" ] && cap=0
    while [ "${#HIST[@]}" -gt "$cap" ]; do
        [ "${HIST[0]}" = "$CURRENT" ] && break        # never drop the current session
        HIST=("${HIST[@]:1}")                          # drop oldest (index 0)
        [ "$IDX" -gt 0 ] && IDX=$(( IDX - 1 ))
    done
}

# session-created: prune any dead entries, then cap to the open-session count.
# (Deletion is already covered by session-closed -> prune; this catches anything
# missed and enforces the ceiling whenever a session is added.)
do_maintain() {
    load
    prune_dead
    cap_to_live
    save
}

# --- init / status / reset ---------------------------------------------------
do_init() {
    load
    if [ -z "$CURRENT" ]; then
        local s; s="$(attached_session)"
        [ -z "$s" ] && s="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)"
        [ -n "$s" ] && { HIST=("$s"); IDX=0; CURRENT="$s"; PREV="$s"; save; }
    fi
}

do_status() {
    load
    local tl="" i
    for i in "${!HIST[@]}"; do
        if [ "$i" = "$IDX" ]; then tl+="[${HIST[$i]}] "; else tl+="${HIST[$i]} "; fi
    done
    tmux display-message "hist: ${tl% } | prev: ${PREV:-<none>}"
}

do_reset() {
    S "$(H hist)" ""; S "$(H idx)" 0
    S "$(H current)" ""; S "$(H prev)" ""; S "$(H walk)" ""
}

cmd="${1:-}"; to="${2:-}"
case "$cmd" in
    init)    do_init ;;
    hook)    load; do_hook "$to" ;;
    prune)   load; prune_dead; save ;;
    maintain) do_maintain ;;
    toggle)  do_toggle "$to" ;;
    back)    do_back "$to" ;;
    forward) do_forward "$to" ;;
    pick)    do_pick "$to" ;;
    status)  do_status ;;
    reset)   do_reset ;;
    *) echo "Usage: $0 {init|hook|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;
esac
