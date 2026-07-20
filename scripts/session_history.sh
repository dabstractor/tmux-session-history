#!/usr/bin/env bash
# scripts/session_history.sh — tmux-session-history engine
#
# Session-navigation primitives over a single duplicate-free timeline, plus an
# optional "toggle" (Alt-Tab style) feature that flips between the two most
# *relevant* sessions.
#
# PRIMITIVES
#   toggle   — flip to the other most-*relevant* session (Alt-Tab style).
#              Self-heals: if the target was deleted, falls back to the nearest
#              live relevant session, then the nearest live history neighbor.
#   back     — browser-style walk toward older entries.
#   forward  — browser-style walk toward newer entries (dead at the tip).
#   pick     — fzf picker over live history (most-recent-first).
#
# ---------------------------------------------------------------------------
# THE TIMELINE (history) — always on:
#   @session-history-hist     ordered visited sessions, NO DUPLICATES
#   @session-history-idx      cursor position (index of the current session)
#   @session-history-current  last-known current session (so the hook can from→to diff)
#   @session-history-mode     transient switch flag, set an instant before a
#                             back/forward/toggle switch so the hook can tell
#                             HOW the switch happened. Values:
#                               ""            a NAVIGATION (pick/sessionx/manual)
#                               "walk:<tgt>"  a WALK (back/forward)
#                               "toggle:<tgt>" the TOGGLE key
#                             (<tgt> is the intended landing session; the hook
#                             only honors the flag when it matches the actual
#                             landing session, which also clears stale flags.)
#
# THE TOGGLE FEATURE — opt-in via @session-history-toggle-key (bound in
# session_history.tmux). When the key is set, @session-history-toggle-enabled is
# "on" and this engine maintains a second, independent list:
#   @session-history-tlist    the RELEVANCE list: sessions ordered by recency of
#                             USE (most-recently-used first), deduped. Toggle
#                             flips the cursor to the first LIVE entry of this
#                             list that isn't the current session.
#
# WHAT MAKES A SESSION "RELEVANT" (promoted to #1 of the relevance list)?
#   • direct navigation — pick / sessionx / manual switch / toggle: the session
#     you select becomes #1 immediately.
#   • focused activity (the PRIMARY signal) — producing output OR typing in the
#     session you are CURRENTLY VIEWING promotes it to #1 within ~1 s. tmux's
#     alert-activity can't see the focused window (it fires only for background
#     windows), so this is implemented instead with pipe-pane: the SINGLE
#     focused pane is piped (pipe-pane -O captures both program output and the
#     terminal's echo of typed keys) to a throttled reader that fires
#     `activity <session>` at most once per second. Only the focused pane is
#     ever piped — exactly one resident reader — so background output never
#     promotes anything.
#   • dwell (the SILENT-PRESENCE fallback) — if you reach a session by a WALK
#     and stay on it longer than @session-history-dwell-ms (default 8000 ms)
#     WITHOUT producing output, it becomes #1. Covers reading/thinking; it is
#     superseded the instant you produce output.
#   Walking (back/forward) through a session does NOT promote it by itself —
#   merely browsing past a session never makes it relevant. But the moment you
#   produce output in a walked-to session, activity promotes it immediately,
#   which is exactly the user's intent ("I'm working here, that's my toggle").
#
# When a session closes it is removed from BOTH lists (everything above shifts
# down). We NEVER auto-add a replacement, so closing the *current* session does
# not promote its history fallback into the relevance list — toggle will not
# return you to that fallback until you actually use it (navigate to it, or
# dwell on it). Until then, toggling twice will NOT return you to where you
# landed, by design.
#
# CONCURRENCY / SAFETY
#   The three core hooks run SYNCHRONOUSLY (no -b), serialized through tmux's
#   command loop, so the read-modify-write on hist/idx/current/mode/tlist in the
#   hook is race-free. There are TWO async best-effort paths, both of which touch
#   ONLY @session-history-tlist (never hist/idx/current/mode), so a lost update
#   there merely nudges the relevance list and self-heals on the next navigation:
#     • dwell — the hook arms a tmux-managed background `run-shell -b` sleep that
#       fires `dwell <session>`; it self-guards ("am I still current?").
#     • activity — fired by the focused-pane pipe reader (`pipereader`), at most
#       once per second of output; it self-guards against the LIVE attached
#       session (not @current — see do_activity), so a reader on a pane that is
#       no longer the focused one is a clean no-op.
#   The pipe itself is driven by a single background poller (do_poller): it
#   re-evaluates the attached client's active pane ~twice a second and re-pipes to
#   follow it (pane-focus-in proved unreliable — it misses intra-session pane/window
#   switches). Exactly one pane — the focused one — is piped at any time; the
#   best-effort @session-history-piped-pane tracks it, and the activity guard
#   (against the live client session) makes any stray pipe harmless. The poller
#   self-terminates when toggle is off. See the ACTIVITY DETECTION section below.
#
# Global state, single-client assumption. Subcommands take the invoking session
# as $1.

set -u

# Internal state option prefix (namespaced to avoid collisions).
P="@session-history"
H() { printf '%s-%s\n' "$P" "$1"; }   # H hist -> @session-history-hist

SELF="${BASH_SOURCE[0]:-$0}"

G() { tmux show-options -gv "$1" 2>/dev/null; }
S() { tmux set-option -g "$1" "$2"; }
session_exists() { tmux has-session -t "$1" 2>/dev/null; }
attached_session() { tmux display-message -p '#{session_name}' 2>/dev/null; }
toggle_enabled() { [ "$(G "$(H toggle-enabled)")" = "on" ]; }
# user-facing dwell threshold in ms; 0 disables dwell entirely
dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 8000 ;; *) echo "$d" ;; esac; }

CURRENT="" IDX="0"
HIST=() TLIST=()
MODE=""   # in-memory mirror of @session-history-mode for the duration of a hook

load() {
    CURRENT="$(G "$(H current)")"
    IDX="$(G "$(H idx)")"; [ -z "$IDX" ] && IDX=0
    MODE="$(G "$(H mode)")"
    local raw
    HIST=(); raw="$(G "$(H hist)")"
    [ -n "$raw" ] && while IFS= read -r line; do [ -n "$line" ] && HIST+=("$line"); done <<< "$raw"
    TLIST=(); raw="$(G "$(H tlist)")"
    [ -n "$raw" ] && while IFS= read -r line; do [ -n "$line" ] && TLIST+=("$line"); done <<< "$raw"
    local j; j="$(index_of "$CURRENT" 2>/dev/null)" && IDX="$j"
}

# save() persists the lists + cursor + current. It does NOT touch @session-
# history-mode: the mode flag is a transient handoff to the hook and is written
# explicitly (by back/forward/toggle before they switch, and cleared by the hook
# once consumed). Keeping it out of save() avoids clobbering an in-flight flag.
save() {
    S "$(H current)" "$CURRENT"
    S "$(H idx)" "$IDX"
    local IFS=$'\n'
    if [ "${#HIST[@]}" -eq 0 ]; then S "$(H hist)" ""
    else S "$(H hist)" "${HIST[*]}"; fi
    if [ "${#TLIST[@]}" -eq 0 ]; then S "$(H tlist)" ""
    else S "$(H tlist)" "${TLIST[*]}"; fi
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

# promote a session to #1 of the relevance list (dedup; in-memory)
promote_tlist() {
    local s="$1" nh=() i
    for i in "${!TLIST[@]}"; do [ "${TLIST[$i]}" != "$s" ] && nh+=("${TLIST[$i]}"); done
    TLIST=("$s" "${nh[@]}")
}

# NAVIGATION helper: keep backward history (..cursor) minus 'to', append 'to'.
# => 'to' lands at the tip; forward history is collapsed (browser "end of road").
collapse_and_append() {
    local to="$1" nh=() i
    for i in "${!HIST[@]}"; do
        [ "$i" -gt "$IDX" ] && break
        [ "${HIST[$i]}" != "$to" ] && nh+=("${HIST[$i]}")
    done
    nh+=("$to")
    HIST=("${nh[@]}")
}

# arm a one-shot dwell timer for a session reached by a WALK. The timer fires
# @session-history-dwell-ms later and, only if that session is STILL the attached
# session, promotes it in the relevance list. Stale timers self-no-op.
arm_dwell() {
    local to="$1" ms sec
    ms="$(dwell_ms)"; [ "$ms" -gt 0 ] 2>/dev/null || return 0
    sec=$(( ms / 1000 )); [ "$sec" -lt 1 ] && sec=1
    # tmux-managed background job: returns immediately (does not block the
    # synchronous hook) and is owned by the server, so no orphaned shell child.
    tmux run-shell -b "sleep ${sec}; \"${SELF}\" dwell \"${to}\""
}

# --- the reactive engine: wired to client-session-changed --------------------
do_hook() {
    local to="$1" from i mt mtarget
    [ -z "$to" ] && to="$(attached_session)"; [ -z "$to" ] && return

    if [ -z "$CURRENT" ]; then                       # first fire / after reset
        HIST=("$to"); IDX=0; CURRENT="$to"; S "$(H mode)" ""; save; return
    fi
    [ "$to" = "$CURRENT" ] && { S "$(H mode)" ""; return; }

    from="$CURRENT"
    case "$MODE" in
        walk:*)   mt="walk"   ;;
        toggle:*) mt="toggle" ;;
        *)        mt="nav"    ;;
    esac
    mtarget="${MODE#*:}"   # "" for nav; the named target otherwise

    if [ "$mt" = "walk" ] && [ "$mtarget" = "$to" ] && i="$(index_of "$to")"; then
        IDX="$i"                                     # WALK: pure cursor move
    elif [ "$mt" = "toggle" ] && [ "$mtarget" = "$to" ]; then
        # TOGGLE: cursor move (no history collapse) + mark target relevant
        if i="$(index_of "$to")"; then IDX="$i"
        else collapse_and_append "$to"; IDX=$(( ${#HIST[@]} - 1 )); fi   # rare: not in history
        toggle_enabled && promote_tlist "$to"
    else
        # NAVIGATION (or a stale/unmatched flag): collapse + append + relevance
        collapse_and_append "$to"; IDX=$(( ${#HIST[@]} - 1 ))
        toggle_enabled && promote_tlist "$to"
    fi

    CURRENT="$to"
    S "$(H mode)" ""                                 # always consume the flag
    # dwell is relevant only for WALK arrivals (the one arrival that doesn't
    # already earn relevance); nav/toggle already promoted the session to #1.
    if [ "$mt" = "walk" ] && toggle_enabled; then arm_dwell "$to"; fi
    save
}

# --- dwell timer fire (touches ONLY the relevance list) ----------------------
do_dwell() {
    local s="$1"
    toggle_enabled || return 0
    # still the current session? Use the engine's authoritative tracked current
    # (@session-history-current), kept in sync on every switch, so this needs no
    # attached client and a stale timer is a clean no-op.
    [ "$s" = "$(G "$(H current)")" ] || return 0
    # read-modify-write ONLY @session-history-tlist; never touch history state.
    local raw arr=() nh=() i
    raw="$(G "$(H tlist)")"
    [ -n "$raw" ] && while IFS= read -r line; do [ -n "$line" ] && arr+=("$line"); done <<< "$raw"
    for i in "${!arr[@]}"; do [ "${arr[$i]}" != "$s" ] && nh+=("${arr[$i]}"); done
    nh=("$s" "${nh[@]}")
    local IFS=$'\n'
    if [ "${#nh[@]}" -eq 0 ]; then S "$(H tlist)" ""
    else S "$(H tlist)" "${nh[*]}"; fi
}

# --- activity promoter (async; touches ONLY the relevance list) --------------
# Fired by the focused-pane pipe reader (do_pipereader), at most once per second
# of focused-pane output. Like do_dwell it read-modify-writes ONLY
# @session-history-tlist. Its guard checks the LIVE attached client's session via
# `tmux list-clients` — NOT `display-message` with no target (which, from a
# pipe-pane child process with no client context, can return an unrelated
# session), and NOT the engine's @current (which lags). A background poller keeps
# the pipe on the active pane of exactly that client's session, so a matching
# fire promotes it; any stray/leaked pipe on another pane has session != the
# client's => clean no-op.
do_activity() {
    local s="$1"
    toggle_enabled || return 0
    session_exists "$s" || return 0
    local attached; attached="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -n1)"
    [ -n "$attached" ] && [ "$s" = "$attached" ] || return 0
    local raw arr=() nh=() i
    raw="$(G "$(H tlist)")"
    [ -n "$raw" ] && while IFS= read -r line; do [ -n "$line" ] && arr+=("$line"); done <<< "$raw"
    for i in "${!arr[@]}"; do [ "${arr[$i]}" != "$s" ] && nh+=("${arr[$i]}"); done
    nh=("$s" "${nh[@]}")
    local IFS=$'\n'
    if [ "${#nh[@]}" -eq 0 ]; then S "$(H tlist)" ""
    else S "$(H tlist)" "${nh[*]}"; fi
}

# --- focused-session activity detection (pipe-pane on the focused pane) -------
# tmux's alert-activity sees only BACKGROUND windows, so it cannot detect that
# the user is actively working in the session they are viewing. We instead keep
# a pipe-pane -O on the SINGLE focused pane: -O feeds the pane's output stream
# (which includes both program output and the terminal's echo of typed keys) to a
# THROTTLED reader. The reader promotes the pane's session at most once per
# second and stays alive for the whole life of the pipe (focusin closes it on the
# next focus change), so a spurious early byte — e.g. a prompt redrawing when
# the pane gains focus — can never "use up" detection; real output afterwards
# still fires. Only the focused pane is ever piped (one resident reader), so
# background output can never promote a session.
#
# The pipe FOLLOWS FOCUS via a background poller (do_poller), not a hook: tmux's
# pane-focus-in fires on session switches but NOT on pane/window switches within
# a session (and not reliably from every client), so it cannot be trusted to keep
# the pipe on the pane the user is actually typing in. The poller instead reads
# the attached client's ACTIVE pane (via list-clients + display-message -t, which
# always reflects the genuine client view regardless of who invoked the command)
# roughly twice a second and re-pipes to follow it. One resident poller + one
# resident reader; both self-terminate when toggle is off.
#
# do_pipereader: stdin = the focused pane's output stream. Read it continuously;
# at most once per wall-clock second, look up the pane's session and promote it
# (do_activity re-checks that it is still the focused session). EOF (pipe close)
# ends the read loop and the process exits cleanly. Runs as the pipe-pane command,
# i.e. ONE resident process per piped pane.
do_pipereader() {
    local pane="$1" c="" last=0 now sess
    toggle_enabled || return 0
    while IFS= read -r -N 1 c; do          # one byte at a time until EOF
        now="${EPOCHSECONDS:-$(date +%s)}"  # bash5 builtin (no fork); date fallback
        [ "$now" -gt "$last" ] || continue  # at most one promote per second
        last="$now"
        sess="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null)" || continue
        [ -n "$sess" ] && do_activity "$sess"
    done
}

# do_focusin: close the previously-piped pane (if different), open the throttled
# reader on the newly-focused pane, remember it. Idempotent and self-correcting.
# We pass the pane id (not the session name) into the command string so pipe-pane
# never re-expands a '#' that might appear in a session name.
do_focusin() {
    local pane="$1"
    toggle_enabled || return 0
    [ -n "$pane" ] || return 0
    local old; old="$(G "$(H piped-pane)")"
    [ -n "$old" ] && [ "$old" != "$pane" ] && tmux pipe-pane -t "$old" "" 2>/dev/null
    tmux pipe-pane -O -t "$pane" "'${SELF}' pipereader '${pane}'" 2>/dev/null
    S "$(H piped-pane)" "$pane"
}

# do_unfocus: drop the pipe (no client / shutdown). The activity guard already
# makes a stray pipe harmless; this is hygiene (no resident reader once idle).
do_unfocus() {
    local old; old="$(G "$(H piped-pane)")"
    [ -n "$old" ] && tmux pipe-pane -t "$old" "" 2>/dev/null
    S "$(H piped-pane)" ""
}

# --- focused-pane pipe follower (background poller) --------------------------
# Drives do_focusin: re-evaluates the attached client's ACTIVE pane ~twice a
# second and re-pipes to follow it (session, window, AND pane switches). Exits on
# its own once toggle is disabled, and records its PID so a plugin reload can
# kill the previous instance (see do_start_poller).
do_poller() {
    S "$(H poller-pid)" "$$"
    # Die CLEANLY on SIGTERM. do_start_poller kills us with `kill` (SIGTERM) on
    # every plugin reload; if tmux sees the run-shell job die by signal it prints
    # "terminated by signal 15", which leaks into prompts like the TPM update
    # menu and blocks them. A trap that exits 0 is a normal exit -> no notice.
    # We skip do_unfocus here: the new poller instance reclaims the pipe via
    # do_focusin (closing the old pane's pipe -> old reader gets EOF -> exits).
    trap 'exit 0' TERM
    while toggle_enabled; do
        local sess pane cur
        sess="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -n1)"
        cur="$(G "$(H piped-pane)")"
        if [ -z "$sess" ]; then
            [ -n "$cur" ] && do_unfocus              # no client attached: drop pipe
        else
            pane="$(tmux display-message -t "$sess" -p '#{pane_id}' 2>/dev/null)"
            if [ -n "$pane" ] && [ "$pane" != "$cur" ]; then
                do_focusin "$pane"
            fi
        fi
        sleep 0.5
    done
    trap - TERM
    do_unfocus
    S "$(H poller-pid)" ""
}

# Start (or restart) the poller. Kills any previous instance first so reloading
# the plugin never stacks pollers. No-op unless toggle is enabled; also no-op
# without tmux (e.g. running the script by hand for status/reset).
do_start_poller() {
    toggle_enabled || return 0
    local old; old="$(G "$(H poller-pid)")"
    [ -n "$old" ] && kill "$old" 2>/dev/null
    tmux run-shell -b "${SELF} poller"
}

# --- toggle: flip to the other most-relevant session -------------------------
# Target = the first LIVE relevance-list entry that isn't the current session.
# (If current is #1, that yields #2; otherwise it yields #1 — so consecutive
# toggles oscillate between the two most-recently-used sessions.) If the
# relevance list has nothing, self-heal to the nearest live history neighbor.
# Toggle is a cursor move through the stack: it never collapses history.
do_toggle() {
    load; reconcile "${1:-}"
    local cur="$CURRENT" target
    target="$(tlist_target "$cur")"
    [ -n "$target" ] || target="$(fallback_target "$cur")"
    if [ -z "$target" ] || [ "$target" = "$cur" ]; then
        tmux display-message "session-history: no other session to toggle to"; return 0
    fi
    S "$(H mode)" "toggle:$target"                   # hook: cursor move + promote
    tmux switch-client -t "$target"
}

tlist_target() {
    local cur="$1" i s
    for i in "${!TLIST[@]}"; do
        s="${TLIST[$i]}"
        [ "$s" = "$cur" ] && continue
        session_exists "$s" || continue
        printf '%s\n' "$s"; return
    done
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
            S "$(H mode)" "walk:${HIST[$i]}"; tmux switch-client -t "${HIST[$i]}"; return
        fi
    done
    tmux display-message "session-history: start of history"
}

do_forward() {
    load; reconcile "${1:-}"
    local i n="${#HIST[@]}"
    for (( i=IDX+1; i<n; i++ )); do
        if session_exists "${HIST[$i]}" && [ "${HIST[$i]}" != "$CURRENT" ]; then
            S "$(H mode)" "walk:${HIST[$i]}"; tmux switch-client -t "${HIST[$i]}"; return
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
    # no mode flag -> the hook treats this as a NAVIGATION (collapse + relevance)
    [ -n "$sel" ] && tmux switch-client -t "$sel"
    return 0
}

# --- prune dead sessions (wired to session-closed) ---------------------------
# Removes the closed session from BOTH lists (shift up). We never add anything,
# so closing the current session does not promote its history fallback into the
# relevance list (toggle will not return you there until you use it).
prune_dead() {
    local alive=() removed=0 i s tl=()
    for i in "${!HIST[@]}"; do
        s="${HIST[$i]}"
        if session_exists "$s"; then alive+=("$s")
        elif [ "$i" -lt "$IDX" ]; then removed=$((removed+1)); fi
    done
    HIST=("${alive[@]}")
    IDX=$(( IDX - removed )); [ "$IDX" -lt 0 ] && IDX=0
    for i in "${!TLIST[@]}"; do session_exists "${TLIST[$i]}" && tl+=("${TLIST[$i]}"); done
    TLIST=("${tl[@]}")
    if ! session_exists "$CURRENT"; then
        CURRENT="$(attached_session)"; local j; j="$(index_of "$CURRENT")" && IDX="$j"
    fi
}

# --- cap + maintenance (wired to session-created) ----------------------------
# Ceiling = number of sessions currently open. Trim oldest stragglers from each
# list down to the open-session count, never dropping the live current session.
live_session_count() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null | wc -l
}

cap_to_live() {
    local cap; cap="$(live_session_count)"; [ -z "$cap" ] && cap=0
    while [ "${#HIST[@]}" -gt "$cap" ]; do
        [ "${HIST[0]}" = "$CURRENT" ] && break        # never drop the current session
        HIST=("${HIST[@]:1}")                          # drop oldest visited (index 0)
        [ "$IDX" -gt 0 ] && IDX=$(( IDX - 1 ))
    done
    # relevance list is most-recent-first, so "oldest relevant" is at the END
    while [ "${#TLIST[@]}" -gt "$cap" ]; do
        [ "${TLIST[0]}" = "$CURRENT" ] && break
        unset 'TLIST[${#TLIST[@]}-1]'
    done
    TLIST=("${TLIST[@]}")
}

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
        [ -z "$s" ] && s="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null | sort -rn | head -n1 | cut -d ' ' -f2-)"
        [ -n "$s" ] && { HIST=("$s"); IDX=0; CURRENT="$s"; save; }
    fi
    # Start the focused-activity poller: it opens the pipe on the client's active
    # pane and re-pipes to follow focus (session/window/pane switches). Reload-
    # safe — do_start_poller kills any previous instance first. No-op without a
    # client (the poller waits for one to attach).
    do_start_poller
}

do_status() {
    load
    local tl="" i tlist_str
    for i in "${!HIST[@]}"; do
        if [ "$i" = "$IDX" ]; then tl+="[${HIST[$i]}] "; else tl+="${HIST[$i]} "; fi
    done
    if toggle_enabled; then
        tlist_str=""
        for i in "${!TLIST[@]}"; do tlist_str+="${TLIST[$i]} "; done
        [ -n "$tlist_str" ] || tlist_str="<empty>"
    else
        tlist_str="<toggle disabled>"
    fi
    tmux display-message "hist: ${tl% } | toggle: ${tlist_str% }"
}

do_reset() {
    S "$(H hist)" ""; S "$(H idx)" 0
    S "$(H current)" ""; S "$(H mode)" ""
    S "$(H tlist)" ""
}

cmd="${1:-}"; to="${2:-}"
case "$cmd" in
    init)      do_init ;;
    hook)      load; do_hook "$to" ;;
    dwell)     do_dwell "$to" ;;
    activity)  do_activity "$to" ;;
    pipereader) do_pipereader "$to" ;;
    focusin)   do_focusin "$to" ;;
    unfocus)   do_unfocus ;;
    poller)    do_poller ;;
    prune)     load; prune_dead; save ;;
    maintain)  do_maintain ;;
    toggle)    do_toggle "$to" ;;
    back)      do_back "$to" ;;
    forward)   do_forward "$to" ;;
    pick)      do_pick "$to" ;;
    status)    do_status ;;
    reset)     do_reset ;;
    *) echo "Usage: $0 {init|hook|dwell|activity|pipereader|focusin|unfocus|prune|maintain|toggle|back|forward|pick|status|reset} [session|pane]" >&2; exit 1 ;;
esac