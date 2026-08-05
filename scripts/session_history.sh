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
#   A session is promoted to the FRONT of the relevance list by exactly TWO
#   causes:
#   • direct selection — any NAVIGATION (pick / sessionx / manual switch-client)
#     or TOGGLE promotes the session you land on (`to`) to #1 immediately.
#   • dwell — if you reach a session by a WALK (back/forward) and stay on it
#     longer than @session-history-dwell-ms (default 30000 ms), it becomes #1.
#
#   Walking (back/forward) through a session does NOT promote it by itself —
#   merely browsing past a session never makes it relevant. This is the rule
#   that makes toggle track USAGE rather than browsing: if you are working in A,
#   walk the timeline back through several sessions to B, and toggle, you flip
#   to A (the thing you were using) — not to the session adjacent to B — because
#   the walk never promoted the in-between sessions.
#
#   promote_tlist is idempotent and dedups, so promoting a session already at
#   #1 is a no-op, and promoting one lower down moves it to #1.
#
# When a session closes it is removed from BOTH lists (everything above shifts
# down). We NEVER auto-add a replacement, so closing the *current* session does
# not promote its history fallback into the relevance list — toggle will not
# return you to that fallback until you actually use it (navigate to it, or
# dwell on it). Until then, toggling twice will NOT return you to where you
# landed, by design.
#
# CONCURRENCY / SAFETY
#   IMPORTANT: the `run-shell` in a tmux hook is ASYNCHRONOUS — the triggering
#   command (e.g. switch-client) returns immediately and the hook's shell runs
#   afterward (verified on tmux 3.6a; `-b` makes no difference inside a hook).
#   So the read-modify-write on hist/idx/current/mode/tlist is NOT serialized by
#   tmux. A close that also relocates the client fires prune AND hook at once
#   (closing the focused session, or any switch-then-kill such as a session
#   picker deleting a session), and a hook that loaded stale state can save LAST
#   and clobber prune's removal of the just-closed session — dead sessions then
#   ACCUMULATE in the timeline, and a later prune that finally lands unclobbered
#   mass-removes them, which looks like the timeline was truncated or wiped. We
#   therefore wrap EVERY mutating command in an exclusive flock (see lock/
#   unlock below) so the critical sections are mutually exclusive regardless of
#   how tmux schedules the async run-shells. (Machine-speed bursts of
#   switch-client can still collapse into a single step — a known, accepted
#   limitation — but they can no longer corrupt the timeline.)
#   The TWO further async paths (dwell, activity) touch ONLY @session-history-
#   tlist, AND now also take the lock, so they are fully serialized as well:
#     • dwell — the hook arms a tmux-managed background `run-shell -b` sleep that
#       fires `dwell <session>`; it self-guards ("am I still current?").
#     • activity — fired by the background poller (do_poller) when the attached
#       client's `#{client_activity}` advances while the session stays the same
#       (the user typed / switched panes / ran a tmux command in the session
#       they're viewing). It self-guards against the LIVE attached session (not
#       @current — see do_activity), so a late fire is a clean no-op.
#   Focused-activity detection runs entirely in that one poller: it reads the
#   attached client's session + client_activity ~2x/sec, promotes the current
#   session when activity advances on an unchanged session, and re-anchors its
#   baseline whenever the session changes (so a switch can't be mistaken for
#   work). There are NO per-pane pipes and NO reader processes; the poller is the
#   only resident process for activity, and it self-terminates when toggle is
#   off. See the ACTIVITY DETECTION section below.
#
# Global state, single-client assumption. Subcommands take the invoking session
# as $1.

set -u

# Internal state option prefix (namespaced to avoid collisions).
P="@session-history"
H() { printf '%s-%s\n' "$P" "$1"; }   # H hist -> @session-history-hist

SELF="${BASH_SOURCE[0]:-$0}"

# --- concurrency: serialize the critical sections ----------------------------
# A `run-shell` inside a tmux hook is ASYNCHRONOUS (see the header note): the
# triggering command returns immediately and the hook's shell runs afterward, so
# `session-closed` (prune) and `client-session-changed` (hook) can run
# concurrently whenever a close also relocates the client. Every mutating
# command below therefore takes an exclusive flock on a stable file for its
# whole critical section, so the read-modify-writes cannot interleave. Each
# section is a few tens of ms; keypresses are ~150 ms apart and the poller fires
# only every ~0.5 s, so contention is imperceptible. The lock auto-releases if a
# command dies (fd closes / process exits), so it can never be held stale.
LOCK_FILE="${SHT_LOCK:-${TMPDIR:-/tmp}/tmux-session-history.lock}"
lock()   { exec 9>"$LOCK_FILE"; flock 9; }   # blocks until exclusive lock acquired
unlock() { exec 9>&-; }                        # closing fd 9 releases the lock

# A single consistent snapshot of the live session names, refreshed once per
# locked critical section. prune/cap key off this instead of one `has-session`
# fork per entry: it is both far faster (1 tmux call vs N) and atomic — no
# session can appear or disappear mid-scan — which is what makes pruning exact:
# a live session is never dropped and a dead one is never missed.
declare -A ALIVE=()
load_alive() {
    ALIVE=()
    local s
    while IFS= read -r s; do [ -n "$s" ] && ALIVE["$s"]=1; done \
        < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
}

G() { tmux show-options -gv "$1" 2>/dev/null; }
S() { tmux set-option -g "$1" "$2"; }
# Uses the snapshot when one has been loaded this critical section, else forks.
session_exists() {
    if [ "${#ALIVE[@]}" -gt 0 ]; then [ "${ALIVE[$1]:-}" = 1 ]
    else tmux has-session -t "$1" 2>/dev/null; fi
}
attached_session() { tmux display-message -p '#{session_name}' 2>/dev/null; }
toggle_enabled() { [ "$(G "$(H toggle-enabled)")" = "on" ]; }
# user-facing dwell threshold in ms; 0 disables dwell entirely
dwell_ms() { local d; d="$(G "$(H dwell-ms)")"; case "$d" in ''|*[!0-9]*) echo 30000 ;; *) echo "$d" ;; esac; }

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

# NAVIGATION helper: move `to` to the tip, preserving every other entry (dedup).
# tmux sessions persist when you navigate away from them, so — unlike a browser —
# there is no "forward" history to invalidate: history is an accumulating,
# duplicate-free log of the sessions you have visited. Navigating to a session
# (pick / sessionx / manual switch) therefore must never DROP other entries; it
# only reorders `to` to the tip. (Earlier this collapsed forward history on
# navigation from a non-tip cursor, which silently truncated the list whenever
# you back'd/toggled and then switched — losing still-open sessions.)
move_to_tip() {
    local to="$1" nh=() i
    for i in "${!HIST[@]}"; do
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

    # Distinguish "genuinely uninitialized" (no history yet) from "CURRENT was
    # blanked but history still exists". The latter happens when prune_dead
    # couldn't resolve the landing session (the client was mid-relocation when
    # session-closed fired) and left CURRENT empty. Resetting HIST to [to] then
    # would DESTROY a valid timeline — so only seed on a truly empty history;
    # otherwise adopt `to` as current without touching the timeline.
    if [ "${#HIST[@]}" -eq 0 ]; then                   # genuine first fire: seed
        HIST=("$to"); IDX=0; CURRENT="$to"; S "$(H mode)" ""; save; return
    fi
    if [ -z "$CURRENT" ]; then                        # blanked mid-session:
        CURRENT="$to"                                #   adopt landing as current
        if i="$(index_of "$to")"; then IDX="$i"      #   usually already in history
        else HIST+=("$to"); IDX=$(( ${#HIST[@]} - 1 )); fi   # else append (no collapse)
        S "$(H mode)" ""; save; return
    fi
    [ "$to" = "$CURRENT" ] && { S "$(H mode)" ""; return; }

    from="$CURRENT"
    # If the session we're leaving no longer exists, this switch was FORCED by
    # tmux relocating us because our current session just CLOSED — its last
    # window/pane was killed, kill-session ran, or a session picker did a
    # switch-then-kill. Such a landing must NOT reorder the timeline (no
    # move_to_tip) and must NOT promote the relevance list: we simply move the
    # cursor to the landing session's EXISTING position so the forward history
    # survives (closing the middle must leave the top reachable via forward).
    # This also makes the outcome identical whether prune or this hook acquires
    # the lock first. (Relies on CURRENT being accurate, which the flock
    # serialization guarantees.)
    if ! session_exists "$from"; then
        if i="$(index_of "$to")"; then IDX="$i"
        else HIST+=("$to"); IDX=$(( ${#HIST[@]} - 1 )); fi   # rare: landing not yet in history
        CURRENT="$to"; S "$(H mode)" ""; save; return
    fi
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
        else move_to_tip "$to"; IDX=$(( ${#HIST[@]} - 1 )); fi   # rare: not in history
        toggle_enabled && promote_tlist "$to"
    else
        # NAVIGATION (or a stale/unmatched flag): move `to` to tip + relevance
        move_to_tip "$to"; IDX=$(( ${#HIST[@]} - 1 ))
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
    # Read state and build the candidate list under the lock, then RELEASE
    # before the interactive fzf so a picker left open can't block every other
    # command. The eventual switch fires the (locked) hook.
    lock; load_alive; load; reconcile "${1:-}"
    local cur="$CURRENT" items="" i s sel popup use_popup
    for (( i=${#HIST[@]}-1; i>=0; i-- )); do
        s="${HIST[$i]}"; [ "$s" = "$cur" ] && continue
        session_exists "$s" || continue
        items+="$s"$'\n'
    done
    unlock
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
        local landed
        landed="$(attached_session)"
        # The client can be mid-relocation when session-closed fires, so the
        # attached session is momentarily unresolvable (or still reports the
        # just-closed session). Never blank CURRENT in that case — a blank
        # CURRENT makes the next client-session-changed hook think the engine
        # is uninitialized and wipe the timeline. Fall back to the session at
        # the CURSOR (where the user just was) and its nearest live neighbors —
        # NOT the timeline tip: landing on the tip would make the subsequent
        # landing client-session-changed reorder it ahead of the forward
        # history, stranding the old top behind the cursor.
        if [ -z "$landed" ] || ! session_exists "$landed" ]; then
            landed=""
            local lo hi
            for (( j=0; j<${#HIST[@]}; j++ )); do
                lo=$(( IDX - j )); hi=$(( IDX + j ))
                if [ "$hi" -lt "${#HIST[@]}" ] && session_exists "${HIST[$hi]}"; then landed="${HIST[$hi]}"; break; fi
                if [ "$lo" -ge 0 ] && session_exists "${HIST[$lo]}"; then landed="${HIST[$lo]}"; break; fi
            done
        fi
        if [ -n "$landed" ]; then
            CURRENT="$landed"
            local j; j="$(index_of "$CURRENT")" && IDX="$j"
        fi
    fi
}

# --- cap + maintenance (wired to session-created) ----------------------------
# Ceiling = number of sessions currently open. Trim oldest stragglers from each
# list down to the open-session count, never dropping the live current session.
live_session_count() {
    if [ "${#ALIVE[@]}" -gt 0 ]; then echo "${#ALIVE[@]}"
    else tmux list-sessions -F '#{session_name}' 2>/dev/null | wc -l; fi
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
        # Same guard as do_hook: only SEED history on a genuinely empty
        # timeline. If history exists (e.g. CURRENT was blanked by a prior
        # prune), adopt `s` as current without destroying it.
        if [ -n "$s" ]; then
            if [ "${#HIST[@]}" -eq 0 ]; then HIST=("$s"); IDX=0
            else
                local j
                if j="$(index_of "$s")"; then IDX="$j"
                else HIST+=("$s"); IDX=$(( ${#HIST[@]} - 1 )); fi
            fi
            CURRENT="$s"; save
        fi
    fi
    # One-shot migration guard: an older version may have left a poller process
    # running, tracked in @session-history-poller-pid. That machinery is gone
    # now, so kill the stale PID once (if any) and clear the option. Self-
    # cleaning: once the option is empty, subsequent inits skip this entirely.
    local old_pid; old_pid="$(G "$(H poller-pid)" 2>/dev/null)"
    [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
    S "$(H poller-pid)" "" 2>/dev/null
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
    # Every mutating command holds the exclusive lock for its whole critical
    # section, so concurrent async hooks (a close that also relocates the client
    # fires prune + hook at once) cannot interleave their read-modify-writes.
    init)      lock; load_alive; do_init; unlock ;;
    hook)      lock; load_alive; load; do_hook "$to"; unlock ;;
    dwell)     lock; load_alive; do_dwell "$to"; unlock ;;
    prune)     lock; load_alive; load; prune_dead; save; unlock ;;
    maintain)  lock; load_alive; do_maintain; unlock ;;
    toggle)    lock; load_alive; do_toggle "$to"; unlock ;;
    back)      lock; load_alive; do_back "$to"; unlock ;;
    forward)   lock; load_alive; do_forward "$to"; unlock ;;
    pick)      do_pick "$to" ;;        # self-manages the lock (releases before fzf)
    status)    do_status ;;            # read-only; no lock
    reset)     lock; do_reset; unlock ;;
    *) echo "Usage: $0 {init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset} [session]" >&2; exit 1 ;;
esac
