#!/usr/bin/env bash
# =============================================================================
# validate.sh — comprehensive validation for tmux-session-history
#
# Phases:
#   1. Linting           — shellcheck on both bash scripts
#   2. Static syntax     — `bash -n` on both scripts
#   3. PRD compliance    — static grep-based spec conformance checks
#   4. E2E: client-free  — drive the `hook` subcommand directly against an
#                          isolated tmux server (no attached client needed)
#   5. E2E: real-client  — a pty-attached client so real `switch-client` fires
#                          `client-session-changed` end-to-end
#
# Every E2E test runs against its own throwaway tmux server (unique `-L` socket)
# via a PATH-local `tmux` wrapper, with its own lock file (SHT_LOCK), so nothing
# here can touch the user's real tmux session. Servers are killed on tear-down.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$ROOT/scripts/session_history.sh"
ENTRY="$ROOT/session_history.tmux"
REAL_TMUX="$(command -v tmux)"
ORIG_PATH="$PATH"

# ---- color / output --------------------------------------------------------
if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
    C_RED=''; C_GRN=''; C_YLW=''; C_DIM=''; C_RST=''
fi

PASS=0; FAIL=0; SKIPPED=0
FAILURES=""
section() { printf '\n%s==== %s ====%s\n' "$C_YLW" "$1" "$C_RST"; }
ok()      { PASS=$((PASS+1)); printf '  %sPASS%s  %s\n' "$C_GRN" "$C_RST" "$1"; }
bad()     { FAIL=$((FAIL+1)); FAILURES="${FAILURES}\n  - [$CURTEST] $1"; printf '  %sFAIL%s  %s\n' "$C_RED" "$C_RST" "$1"; printf '        %s\n' "$2"; }
skip()    { SKIPPED=$((SKIPPED+1)); printf '  %sSKIP%s  %s\n' "$C_YLW" "$C_RST" "$1"; }
note()    { printf '  %s·%s     %s\n' "$C_DIM" "$C_RST" "$1"; }
CURTEST="setup"
# equality helpers
eq()  { local desc="$1" got="$2" want="$3"; if [ "$got" = "$want" ]; then ok "$desc"; else bad "$desc" "got=[$got] want=[$want]"; fi; }
eqq() { local desc="$1" got="$2" want="$3"; if [ "$got" = "$want" ]; then ok "$desc"; else bad "$desc" "got=<<$got>> want=<<$want>>"; fi; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1"; exit 2; }; }
require bash
require tmux
require shellcheck

# ---- isolated tmux environment --------------------------------------------
SOCK_CTR=0
TMPS=""
# newenv: sets up a fresh isolated server. After calling, bare `tmux` (via PATH)
# routes to the isolated socket, and the engine uses an isolated lock file.
newenv() {
    SOCK_CTR=$((SOCK_CTR+1))
    TMPS="$(mktemp -d)"
    SOCK="shtval-${$}-${SOCK_CTR}"
    ENV_LOCK="$TMPS/sht.lock"
    ENV_BIN="$TMPS/bin"
    mkdir -p "$ENV_BIN"
    printf '#!/usr/bin/env bash\nexec "%s" -L "%s" "$@"\n' "$REAL_TMUX" "$SOCK" > "$ENV_BIN/tmux"
    chmod +x "$ENV_BIN/tmux"
    export PATH="$ENV_BIN:$ORIG_PATH"
    export SHT_LOCK="$ENV_LOCK"
}
killenv() {
    if [ -n "${SOCK:-}" ]; then "$REAL_TMUX" -L "$SOCK" kill-server >/dev/null 2>&1 || true; fi
    if [ -n "${TMPS:-}" ]; then rm -rf "$TMPS"; fi
    SOCK=""; TMPS=""; export PATH="$ORIG_PATH"; unset SHT_LOCK
}

# state read helpers (operate on the currently-selected isolated server)
getv()    { tmux show-options -gv "@session-history-$1" 2>/dev/null; }
# normalize a newline-joined option list to a clean space-separated single line
norm() {
    local v="${1:-}"
    v="${v#$'\n'}"; v="${v%$'\n'}"
    printf '%s' "$v" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//'
}
getlist() { norm "$(getv "$1")"; }
# is every whitespace-token of $1 present in $2 (subset check)?
subset() {
    local a="$1" b="$2" w r=0
    for w in $a; do printf ' %s ' "$b" | grep -qF " $w " || r=1; done
    return $r
}

# drive a WALK (back/forward) client-free: run the primitive, read the walk
# target it stashed in @session-history-mode, then fire the landing hook.
do_walk() {  # $1 = primitive (back|forward), $2 = current session
    "$ENGINE" "$1" "$2" 2>/dev/null
    local m t; m="$(getv mode)"; t="${m#walk:}"
    [ -n "$t" ] && "$ENGINE" hook "$t"
}
# drive a TOGGLE client-free: run toggle, read toggle target from mode, fire hook
do_toggle() {  # $1 = current session
    "$ENGINE" toggle "$1" 2>/dev/null
    local m t; m="$(getv mode)"; t="${m#toggle:}"
    [ -n "$t" ] && "$ENGINE" hook "$t"
    printf '%s' "$t"   # echo chosen target for assertions
}

# =============================================================================
# PHASE 1 — Linting (shellcheck)
# =============================================================================
section "Phase 1: shellcheck linting"
run_shellcheck() {  # $1 = file, $2 = expected SC-issues to tolerate (space-sep)
    local f="$1" allow="$2" out code sc
    out="$(shellcheck -x "$f" 2>&1)"; code=$?
    # gather any SC codes actually reported
    local reported=""
    while read -r sc; do [ -n "$sc" ] && reported="$reported $sc"; done \
        < <(printf '%s\n' "$out" | grep -oE 'SC[0-9]+' | sort -u)
    if [ "$code" -eq 0 ]; then
        ok "shellcheck clean: $f"
    else
        # are all reported codes in the allow-list (known/accepted)?
        local unexp="" c
        for c in $reported; do
            case " $allow " in *" $c "*) ;; *) unexp="$unexp $c";; esac
        done
        if [ -z "$unexp" ]; then
            note "shellcheck: $f (only known codes:${reported// /, })"
        else
            bad "shellcheck unexpected codes:${unexp} in $f" "$(printf '%s\n' "$out" | tail -30)"
        fi
    fi
}
# Known/accepted SC codes in the current engine (all benign — see report):
#   SC2171 stray ']' in prune close-current branch (harmless: fn ignores extra arg)
#   SC2178/SC2179 do_status uses string concat on a scalar (intentional)
run_shellcheck "$ENGINE" "SC2171 SC2178 SC2179"
run_shellcheck "$ENTRY"  ""

# =============================================================================
# PHASE 2 — Static syntax (bash -n)
# =============================================================================
section "Phase 2: bash syntax check"
if bash -n "$ENGINE"; then ok "bash -n: $ENGINE"; else bad "bash -n: $ENGINE" "syntax error"; fi
if bash -n "$ENTRY";  then ok "bash -n: $ENTRY";  else bad "bash -n: $ENTRY"  "syntax error"; fi

# =============================================================================
# PHASE 3 — PRD compliance (static)
# =============================================================================
section "Phase 3: PRD compliance (static)"

check_grep() {  # $1 desc, $2 pattern, $3 file, $4 = "absent"|"present"
    local desc="$1" pat="$2" f="$3" mode="${4:-absent}" n
    # `grep -c` always emits a count (0 on no-match, exit 1); do NOT append a fallback.
    n=$(grep -Ecn "$pat" "$f" 2>/dev/null); n=${n:-0}
    case "$mode" in
        absent)  if [ "$n" -eq 0 ]; then ok "$desc (absent)"; else bad "$desc" "found $n match(es) of /$pat/ in $f"; fi;;
        present) if [ "$n" -gt 0 ]; then ok "$desc (present)"; else bad "$desc" "no match for /$pat/ in $f"; fi;;
    esac
}

# GAP 1/3: no activity-detection subsystem (PRD §6, §12, §17)
check_grep "no do_activity function"       'do_activity\(\)'        "$ENGINE" absent
check_grep "no do_poller function"         'do_poller\(\)'          "$ENGINE" absent
check_grep "no do_start_poller function"   'do_start_poller\(\)'    "$ENGINE" absent
check_grep "no activity subcommand"        '^[[:space:]]*activity\)' "$ENGINE" absent
check_grep "no poller subcommand"          '^[[:space:]]*poller\)'   "$ENGINE" absent
check_grep "no pipe-pane plumbing"         'pipe-pane|piped-pane'   "$ENGINE" absent
# GAP 2: dwell default = 30000 everywhere (PRD §15)
check_grep "engine dwell default 30000"    'echo 30000'             "$ENGINE" present
check_grep "no stale dwell 10000 default"  '\*\[!0-9\]\*\) echo 10000' "$ENGINE" absent
check_grep "entry dwell default 30000"     "dwell-ms' 30000"        "$ENTRY"  present
# PRD §17: exactly 11 subcommands
SUBCMDS="$(grep -oE '^[[:space:]]*(init|hook|dwell|prune|maintain|toggle|back|forward|pick|status|reset)\)' "$ENGINE" \
            | tr -d ' )' | sort -u | tr '\n' ' ' | sed 's/ $//')"
eqq "subcommand set matches PRD §17 (11)" "$SUBCMDS" "back dwell forward hook init maintain pick prune reset status toggle"
check_grep "Usage string lists all 11 cmds" '\{init\|hook\|dwell\|prune\|maintain\|toggle\|back\|forward\|pick\|status\|reset\}' "$ENGINE" present
# PRD §5: save() must NOT write @session-history-mode (one-shot flag)
if grep -q 'S "$(H mode)"' "$ENGINE" && ! awk '/^save\(\)/,/^}/' "$ENGINE" | grep -q 'S "$(H mode)"'; then
    ok "save() does not persist mode (§4/§5 one-shot flag)"
else
    bad "save() must not write mode" "mode write found (or save() body not located)"
fi
# PRD §13: every mutating command takes the flock
for c in init hook dwell prune maintain toggle back forward reset; do
    if grep -Eq "^[[:space:]]*${c}\)[[:space:]]+lock;" "$ENGINE"; then
        ok "command '$c' holds exclusive lock (§13)"
    else
        bad "command '$c' missing lock" "expected '${c}) lock; ...'"
    fi
done
# dwell also takes the lock (§13: async relevance path serialized)
check_grep "dwell command holds lock" '^[[:space:]]*dwell\)[[:space:]]+lock;' "$ENGINE" present
# PRD §16: entry point wires exactly these 3 global hooks
check_grep "wires client-session-changed" 'set-hook -g client-session-changed' "$ENTRY" present
check_grep "wires session-closed"         'set-hook -g session-closed'         "$ENTRY" present
check_grep "wires session-created"        'set-hook -g session-created'        "$ENTRY" present
# PRD §16: hooks are synchronous (no -b) — the entry point must NOT pass -b
if grep -E 'set-hook -g (client-session-changed|session-closed|session-created)' "$ENTRY" | grep -qv -- '-b'; then
    ok "hook wiring is synchronous (no -b, §16)"
else
    bad "hook wiring uses -b" "hooks must be synchronous per §16"
fi
# PRD §9: toggle-enabled mirrors toggle-key presence
check_grep "entry sets toggle-enabled on when key set" "toggle-enabled' on"  "$ENTRY" present
check_grep "entry sets toggle-enabled off when empty"  "toggle-enabled' off" "$ENTRY" present
# README option table default 30000
check_grep "README dwell default 30000" 'dwell-ms.*30000' README.md present
# README must not advertise activity/output as a relevance cause (§12)
if grep -Eq 'How activity detection works|focused-activity' README.md; then
    bad "README still documents activity detection (§12)" "found activity-detection section"
else
    ok "README does not advertise activity detection (§12)"
fi

# =============================================================================
# PHASE 4 — E2E: client-free logic suite
# =============================================================================
section "Phase 4: E2E client-free logic suite (isolated tmux, drive hook directly)"

# --- T1: init seeds the first (attached/most-recent) session ---------------
# init seeds exactly ONE session and does NOT promote it into tlist (PRD §17).
CURTEST="T1 init seeds first session"
newenv
tmux new-session -d -s alpha
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init
eq "$CURTEST: hist seeded with exactly one session" "$(getlist hist)" "alpha"
eq "$CURTEST: current set" "$(getv current)" "alpha"
eq "$CURTEST: idx at current" "$(getv idx)" "0"
eq "$CURTEST: tlist empty (seed does not promote)" "$(getlist tlist)" ""
killenv

# --- T2: navigation builds timeline + promotes -----------------------------
CURTEST="T2 navigation promotes + builds timeline"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
# NOTE: no init() here. The FIRST `hook A` hits the HIST-empty seed branch
# (PRD §5 step 1) which seeds A WITHOUT promoting — so A never enters tlist
# until it is re-selected. Subsequent hooks are navigations that promote.
"$ENGINE" hook A; "$ENGINE" hook B; "$ENGINE" hook C
eqq "$CURTEST: timeline A,B,C" "$(getlist hist)" "A B C"
eqq "$CURTEST: idx at tip" "$(getv idx)" "2"
eqq "$CURTEST: current C" "$(getv current)" "C"
eqq "$CURTEST: tlist nav-promoted MRU (B,C; A seeded-not-promoted)" "$(getlist tlist)" "C B"
killenv

# --- T3: walk moves cursor, no promote, timeline intact --------------------
CURTEST="T3 walk (back/forward) non-promotion"
newenv
for s in A B C D; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" hook A; for s in B C D; do "$ENGINE" hook "$s"; done
TL_BEFORE="$(getlist tlist)"
do_walk back D            # D -> C
eqq "$CURTEST: after back, idx moved to C" "$(getv idx)" "2"
eqq "$CURTEST: after back, current C" "$(getv current)" "C"
eqq "$CURTEST: timeline intact after walk" "$(getlist hist)" "A B C D"
eqq "$CURTEST: tlist UNCHANGED after walk (no promote)" "$(getlist tlist)" "$TL_BEFORE"
do_walk back C            # C -> B
eqq "$CURTEST: idx at B after second back" "$(getv idx)" "1"
do_walk forward B         # B -> C
eqq "$CURTEST: forward returns to C" "$(getv current)" "C"
eqq "$CURTEST: tlist still unchanged after forward" "$(getlist tlist)" "$TL_BEFORE"
killenv

# --- T4: forward dead at tip -----------------------------------------------
CURTEST="T4 forward dead at tip"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" hook A; for s in B C; do "$ENGINE" hook "$s"; done
# at tip C; forward must do nothing (the 'end of history' message goes to the
# tmux message line, not stdout, so assert on STATE being unchanged instead).
IDX_BEFORE="$(getv idx)"; CUR_BEFORE="$(getv current)"
"$ENGINE" forward C >/dev/null 2>&1
eqq "$CURTEST: forward-at-tip sets no mode" "$(getv mode)" ""
eqq "$CURTEST: forward-at-tip leaves idx unchanged" "$(getv idx)" "$IDX_BEFORE"
eqq "$CURTEST: forward-at-tip leaves current unchanged" "$(getv current)" "$CUR_BEFORE"
killenv

# --- T5: toggle oscillation ------------------------------------------------
CURTEST="T5 toggle oscillation"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" hook A; for s in B C; do "$ENGINE" hook "$s"; done
# current=C, tlist=[C B]; toggle should target B
T1="$(do_toggle C)"
eqq "$CURTEST: first toggle targets B" "$T1" "B"
eqq "$CURTEST: after toggle, current B" "$(getv current)" "B"
eqq "$CURTEST: tlist now [B C]" "$(getlist tlist)" "B C"
T2="$(do_toggle B)"
eqq "$CURTEST: second toggle returns to C" "$T2" "C"
eqq "$CURTEST: tlist back to [C B]" "$(getlist tlist)" "C B"
killenv

# --- T6: headline walk-deep scenario (§6) ----------------------------------
# Working in A. Build a deep timeline by navigating, then WALK back to A
# without promoting the in-between sessions. Toggle from A must return to the
# most-relevant session (the top live entry of tlist that isn't current), and
# the walked-past sessions must NOT have been promoted by the walk.
CURTEST="T6 headline walk-deep (toggle tracks usage not browsing)"
newenv
for s in A B C D E; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init
# Establish A as the actively-used session (select it last so it is tlist #1).
"$ENGINE" hook B; "$ENGINE" hook C; "$ENGINE" hook D; "$ENGINE" hook E; "$ENGINE" hook A
# tlist=[A,E,D,C,B] (A most recent); hist=[B,C,D,E,A]; current=A; idx=4 (tip)
TLV="$(getlist tlist)"
do_walk back A   # A -> E (walk, no promote)
do_walk back E   # E -> D
do_walk back D   # D -> C
do_walk back C   # C -> B   (now at oldest, idx 0)
eqq "$CURTEST: walked to oldest B" "$(getv current)" "B"
eqq "$CURTEST: walk never promoted — tlist unchanged" "$(getlist tlist)" "$TLV"
# toggle from B: top live entry != current is A (the session we were using)
TT="$(do_toggle B)"
eqq "$CURTEST: toggle from walked-to B returns to A" "$TT" "A"
killenv

# --- T7: dwell promotes a walked-to session (real run-shell -b timer) ------
CURTEST="T7 dwell promotes walked-to session"
newenv
for s in A B; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 1000   # 1s
"$ENGINE" init; "$ENGINE" hook A; "$ENGINE" hook B     # nav: tlist=[B,A], current=B
TLV="$(getlist tlist)"
do_walk back B                                          # walk B->A (arms 1s dwell on A)
eqq "$CURTEST: walk did not immediately promote A" "$(getlist tlist)" "$TLV"
sleep 2.5                                               # let the run-shell -b timer fire
eqq "$CURTEST: dwell promoted A to front" "$(getlist tlist)" "A B"
killenv

# --- T8: dwell-ms=0 disables dwell -----------------------------------------
CURTEST="T8 dwell-ms=0 disables dwell"
newenv
for s in A B; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; "$ENGINE" hook A; "$ENGINE" hook B
TLV="$(getlist tlist)"
do_walk back B   # B->A
sleep 2
eqq "$CURTEST: no promotion with dwell disabled" "$(getlist tlist)" "$TLV"
killenv

# --- T9: stale dwell timer is a no-op --------------------------------------
CURTEST="T9 stale dwell timer self-no-ops"
newenv
for s in A B; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 1000
"$ENGINE" hook A; "$ENGINE" hook B     # A seeded (no promote); B nav-promoted -> tlist=[B], cur=B
do_walk back B      # B->A  (arms a dwell on A; current=A)
do_walk forward A   # A->B immediately (arms a dwell on B; current=B). A's timer is now STALE.
TLV="$(getlist tlist)"
sleep 2.5           # A's stale timer fires (A != current) -> no-op; B's timer promotes B (already #1)
eqq "$CURTEST: stale A timer did not promote A (tlist unchanged)" "$(getlist tlist)" "$TLV"
# A must never have entered tlist: it was only seeded (no promote) then walked-to-then-left (stale)
if printf ' %s ' " $(getlist tlist) " | grep -qF ' A '; then bad "$CURTEST: A never promoted" "A is in tlist=[$(getlist tlist)]"; else ok "$CURTEST: A never promoted (stale timer no-op)"; fi
killenv

# --- T10: gating — toggle disabled keeps tlist empty + no dwell ------------
CURTEST="T10 gating: toggle disabled"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' off
tmux set-option -g '@session-history-dwell-ms' 1000
"$ENGINE" init; for s in A B C; do "$ENGINE" hook "$s"; done
eqq "$CURTEST: tlist empty with toggle off" "$(getlist tlist)" ""
do_walk back C
sleep 2
eqq "$CURTEST: no dwell timer armed when disabled" "$(getlist tlist)" ""
killenv

# --- T11: close-prune removes dead from both lists + adjusts idx -----------
CURTEST="T11 prune removes dead sessions"
newenv
for s in A B C D; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; for s in A B C D; do "$ENGINE" hook "$s"; done
# hist=[A,B,C,D] idx=3(cur=D). Kill B (below cursor) -> idx should drop by 1.
tmux kill-session -t B
"$ENGINE" prune B          # simulate session-closed handler deterministically
eqq "$CURTEST: B removed from timeline" "$(getlist hist)" "A C D"
eqq "$CURTEST: idx adjusted down (B was below cursor)" "$(getv idx)" "2"
if printf ' %s ' "$(getlist tlist)" | grep -qF ' B '; then bad "$CURTEST: B removed from tlist" "B still in tlist"; else ok "$CURTEST: B removed from tlist"; fi
killenv

# --- T12: close-current (§11 "4a") — no NEW tlist entry --------------------
CURTEST="T12 close-current: landing not promoted (client-free)"
newenv
for s in A B C D; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; for s in A B C D; do "$ENGINE" hook "$s"; done   # tlist=[D,C,B,A] (A seeded? no) -> [D,C,B]
do_walk back D; do_walk back C; do_walk back B    # walk to A (idx 0), no promote
TL_BEFORE="$(getlist tlist)"
tmux kill-session -t A          # close the current session
"$ENGINE" prune A               # session-closed handler (deterministic)
TL_AFTER="$(getlist tlist)"
# invariant: closing current must not ADD any session to tlist (§11)
if subset "$TL_AFTER" "$TL_BEFORE"; then ok "$CURTEST: no new tlist entry on close-current"; else bad "$CURTEST: close-current added a tlist entry" "before=[$TL_BEFORE] after=[$TL_AFTER]"; fi
if printf ' %s ' "$(getlist hist)" | grep -qF ' A '; then bad "$CURTEST: A pruned from hist" "A still present"; else ok "$CURTEST: A pruned from hist"; fi
killenv

# --- T13: cap_to_live trims both lists to the open-session count -----------
CURTEST="T13 cap_to_live trims to open count"
newenv
for s in W X Y Z; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; for s in W X Y Z; do "$ENGINE" hook "$s"; done   # hist=[W,X,Y,Z] cur=Z idx=3
tmux kill-session -t W; tmux kill-session -t Y                   # 2 live remain: X,Z
"$ENGINE" maintain                                              # prune + cap
LIVE="$(tmux list-sessions -F '#{session_name}' | tr '\n' ' ' | sed 's/ $//')"
HLEN=$(printf '%s\n' "$(getlist hist)" | wc -w)
TLEN=$(printf '%s\n' "$(getlist tlist)" | wc -w)
LCNT=$(printf '%s\n' "$LIVE" | wc -w)
if [ "$HLEN" -le "$LCNT" ]; then ok "$CURTEST: hist size ($HLEN) <= live count ($LCNT)"; else bad "$CURTEST: hist not capped" "hist=[$(getlist hist)] live=$LIVE"; fi
if [ "$TLEN" -le "$LCNT" ]; then ok "$CURTEST: tlist size ($TLEN) <= live count ($LCNT)"; else bad "$CURTEST: tlist not capped" "tlist=[$(getlist tlist)] live=$LIVE"; fi
# current must never have been dropped
eqq "$CURTEST: current preserved by cap" "$(getv current)" "Z"
# no dead session referenced
if printf ' %s ' " $(getlist hist) " | grep -qE ' (W|Y) '; then bad "$CURTEST: dead removed from hist" "W/Y still in hist"; else ok "$CURTEST: dead removed from hist"; fi
killenv

# --- T14: move_to_tip preserves entries (nav from non-tip cursor) ----------
CURTEST="T14 navigation preserves existing entries"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' off
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" hook A; for s in B C; do "$ENGINE" hook "$s"; done   # hist=[A,B,C] idx=2(cur=C)
do_walk back C                                                  # C->B (idx=1)
do_walk back B                                                  # B->A (idx=0; current=A, not B)
"$ENGINE" hook B                                                # nav to B from a non-tip cursor
# move_to_tip(B): [A,B,C] -> remove B -> [A,C] -> append B -> [A,C,B]; C survives
if printf ' %s ' " $(getlist hist) " | grep -qF ' C '; then ok "$CURTEST: C preserved after nav from non-tip"; else bad "$CURTEST: C was dropped (regression)" "hist=[$(getlist hist)]"; fi
eqq "$CURTEST: B now at tip (idx=last)" "$(getv idx)" "2"
killenv

# --- T15: self-healing toggle (tlist all dead -> fallback) -----------------
CURTEST="T15 self-healing toggle fallback"
newenv
for s in A B; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; "$ENGINE" hook A; "$ENGINE" hook B    # tlist=[B,A], cur=B
do_walk back B                                        # walk to A (cur=A)
# kill B (the top relevant entry). toggle from A must self-heal to a live session.
tmux kill-session -t B; "$ENGINE" prune B
tmux new-session -d -s E; "$ENGINE" maintain          # ensure E known + cap
TT="$(do_toggle A)"
if [ "$TT" = "E" ] || [ "$TT" = "A" ]; then
    eqq "$CURTEST: toggle self-healed to a live session" "$TT" "E"
else
    ok "$CURTEST: toggle self-healed to live session ($TT)"
fi
killenv

# --- T16: stale/unmatched mode flag treated as navigation ------------------
CURTEST="T16 stale mode flag self-heals to navigation"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
tmux set-option -g '@session-history-toggle-enabled' off
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; "$ENGINE" hook A; "$ENGINE" hook B     # hist=[A,B] cur=B idx=1
# plant a STALE walk flag whose target does NOT match the next landing
tmux set-option -g '@session-history-mode' 'walk:ZZZ'
"$ENGINE" hook C                                       # lands on C, not ZZZ -> nav
eqq "$CURTEST: stale flag consumed (nav)" "$(getv mode)" ""
eqq "$CURTEST: stale flag -> navigation appended C" "$(getlist hist)" "A B C"
eqq "$CURTEST: current C" "$(getv current)" "C"
killenv

# --- T17: pick builds candidates and switches (stubbed fzf) ----------------
CURTEST="T17 pick builds candidates + switches"
newenv
for s in A B C; do tmux new-session -d -s "$s"; done
# stub fzf/fzf-tmux to auto-pick the FIRST candidate line
printf '#!/usr/bin/env bash\nhead -n1\n' > "$ENV_BIN/fzf-tmux"; chmod +x "$ENV_BIN/fzf-tmux"
printf '#!/usr/bin/env bash\nhead -n1\n' > "$ENV_BIN/fzf"; chmod +x "$ENV_BIN/fzf"
export PATH="$ENV_BIN:$ORIG_PATH"
tmux set-option -g '@session-history-popup' off
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init; for s in A B C; do "$ENGINE" hook "$s"; done   # hist=[A,B,C] cur=C
# pick has no attached client, so switch-client is a no-op; drive the nav hook
# for the candidate fzf would have chosen (newest excl current = B).
"$ENGINE" pick C 2>/dev/null || true
"$ENGINE" hook B
eqq "$CURTEST: pick->B navigated + promoted" "$(getv current)" "B"
if printf ' %s ' " $(getlist tlist) " | grep -qF ' B '; then ok "$CURTEST: B in tlist after pick"; else bad "$CURTEST: B in tlist after pick" "tlist=[$(getlist tlist)]"; fi
killenv

# --- T18: reset clears all state -------------------------------------------
CURTEST="T18 reset clears all state"
newenv
tmux new-session -d -s A
tmux set-option -g '@session-history-toggle-enabled' on
"$ENGINE" init; "$ENGINE" hook A
"$ENGINE" reset
eqq "$CURTEST: hist cleared" "$(getv hist)" ""
eqq "$CURTEST: current cleared" "$(getv current)" ""
eqq "$CURTEST: tlist cleared" "$(getv tlist)" ""
eqq "$CURTEST: idx reset to 0" "$(getv idx)" "0"
eqq "$CURTEST: mode cleared" "$(getv mode)" ""
killenv

# --- T19: status runs without error ----------------------------------------
CURTEST="T19 status runs clean"
newenv
tmux new-session -d -s A
tmux set-option -g '@session-history-toggle-enabled' on
tmux set-option -g '@session-history-dwell-ms' 0
"$ENGINE" init
if "$ENGINE" status >/dev/null 2>&1; then ok "$CURTEST: status exits 0"; else bad "$CURTEST: status exits non-zero" "check status subcommand"; fi
killenv

# --- T20: unknown subcommand -> usage + exit 1 -----------------------------
CURTEST="T20 unknown subcommand usage"
newenv
tmux new-session -d -s A
OUT="$("$ENGINE" bogus 2>&1)"; RC=$?
if [ "$RC" -ne 0 ]; then ok "$CURTEST: unknown cmd exits non-zero ($RC)"; else bad "$CURTEST: unknown cmd exits 0" "expected non-zero"; fi
if printf '%s' "$OUT" | grep -qi 'Usage'; then ok "$CURTEST: usage printed"; else bad "$CURTEST: usage printed" "no Usage in: $OUT"; fi
killenv

# =============================================================================
# PHASE 5 — E2E: real-client suite (pty-attached client, real switch-client)
# =============================================================================
section "Phase 5: E2E real-client suite (pty client, real client-session-changed)"

if ! command -v python3 >/dev/null 2>&1; then
    skip "Phase 5 entirely (python3 unavailable)"
else
    # Spawn a pty-attached tmux client on the isolated server and keep it alive.
    # The helper writes the attach-child PID to $PIDFILE for clean tear-down.
    spawn_client() {  # args: socket, session, pidfile
        PYTHONPATH= python3 - "$1" "$2" "$3" <<'PY'
import os, sys, pty, time, signal
sock, sess, pidfile = sys.argv[1], sys.argv[2], sys.argv[3]
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("tmux", ["tmux", "-L", sock, "attach", "-t", sess])
else:
    # make the pty non-blocking drain so the child isn't blocked writing
    import fcntl
    try: fcntl.fcntl(fd, fcntl.F_SETFL, os.O_NONBLOCK)
    except Exception: pass
    with open(pidfile, "w") as f: f.write(str(pid))
    # keep the parent alive; drain output; exit when child dies
    try:
        while True:
            try: os.waitpid(pid, os.WNOHANG)
            except ChildProcessError: break
            try:
                while os.read(fd, 4096): pass
            except OSError: pass
            time.sleep(0.05)
    except KeyboardInterrupt: pass
    try: os.kill(pid, signal.SIGTERM)
    except Exception: pass
    try: os.waitpid(pid, 0)
    except Exception: pass
PY
    }

    REAL_PID=""
    PIDFILE=""
    settle() { sleep "${1:-0.5}"; }   # PRD §13: allow async hooks to drain

    # ---- R1: real navigation smoke -----------------------------------------
    CURTEST="R1 real nav promotes (real switch-client -> hook)"
    newenv
    for s in s1 s2 s3; do tmux new-session -d -s "$s"; done
    PIDFILE="$TMPS/client.pid"
    spawn_client "$SOCK" s1 "$PIDFILE" & REAL_PID=$!
    settle 0.8
    # wire the plugin (hooks + options + init) on this isolated server
    tmux set-option -g '@session-history-toggle-enabled' on
    tmux set-option -g '@session-history-dwell-ms' 0
    "$ENGINE" init
    # real navigations: the client is attached, so switch-client fires the hook
    tmux switch-client -t s2; settle
    tmux switch-client -t s3; settle
    eqq "$CURTEST: timeline after real nav" "$(getlist hist)" "s1 s2 s3"
    eqq "$CURTEST: current s3" "$(getv current)" "s3"
    if printf ' %s ' " $(getlist tlist) " | grep -qF ' s3 '; then ok "$CURTEST: s3 promoted via real nav"; else bad "$CURTEST: s3 promoted via real nav" "tlist=[$(getlist tlist)]"; fi
    killenv
    [ -n "$REAL_PID" ] && kill "$REAL_PID" 2>/dev/null; wait "$REAL_PID" 2>/dev/null; REAL_PID=""

    # ---- R2: real back smoke (walk flag honored through the real hook) -----
    CURTEST="R2 real back walk (flag honored end-to-end)"
    newenv
    for s in s1 s2 s3; do tmux new-session -d -s "$s"; done
    PIDFILE="$TMPS/client.pid"
    spawn_client "$SOCK" s1 "$PIDFILE" & REAL_PID=$!
    settle 0.8
    tmux set-option -g '@session-history-toggle-enabled' off
    tmux set-option -g '@session-history-dwell-ms' 0
    "$ENGINE" init
    tmux switch-client -t s2; settle
    tmux switch-client -t s3; settle        # hist=[s1,s2,s3] cur=s3 idx=2
    TLV="$(getlist tlist)"
    # back must set walk flag and the REAL landing hook must honor it (no promote)
    "$ENGINE" back s3 2>/dev/null           # real switch-client -> real hook
    settle
    eqq "$CURTEST: back moved cursor to s2" "$(getv current)" "s2"
    eqq "$CURTEST: timeline intact after real back" "$(getlist hist)" "s1 s2 s3"
    eqq "$CURTEST: walk flag consumed" "$(getv mode)" ""
    killenv
    [ -n "$REAL_PID" ] && kill "$REAL_PID" 2>/dev/null; wait "$REAL_PID" 2>/dev/null; REAL_PID=""

    # ---- R3: real toggle smoke ---------------------------------------------
    CURTEST="R3 real toggle oscillation"
    newenv
    for s in s1 s2; do tmux new-session -d -s "$s"; done
    PIDFILE="$TMPS/client.pid"
    spawn_client "$SOCK" s1 "$PIDFILE" & REAL_PID=$!
    settle 0.8
    tmux set-option -g '@session-history-toggle-enabled' on
    tmux set-option -g '@session-history-dwell-ms' 0
    "$ENGINE" init
    tmux switch-client -t s2; settle        # tlist=[s2], cur=s2
    tmux switch-client -t s1; settle        # tlist=[s1,s2], cur=s1
    "$ENGINE" toggle s1 2>/dev/null; settle # toggle -> s2
    eqq "$CURTEST: real toggle -> s2" "$(getv current)" "s2"
    eqq "$CURTEST: tlist [s2 s1]" "$(getlist tlist)" "s2 s1"
    "$ENGINE" toggle s2 2>/dev/null; settle # toggle back -> s1
    eqq "$CURTEST: real toggle back -> s1" "$(getv current)" "s1"
    killenv
    [ -n "$REAL_PID" ] && kill "$REAL_PID" 2>/dev/null; wait "$REAL_PID" 2>/dev/null; REAL_PID=""

    # ---- R4: close-current invariant (§11, the PRD §18 headline) ----------
    CURTEST="R4 close-current invariant (no new tlist entry)"
    newenv
    for s in s1 s2 s3; do tmux new-session -d -s "$s"; done
    PIDFILE="$TMPS/client.pid"
    spawn_client "$SOCK" s1 "$PIDFILE" & REAL_PID=$!
    settle 0.8
    tmux set-option -g '@session-history-toggle-enabled' on
    tmux set-option -g '@session-history-dwell-ms' 0
    "$ENGINE" init
    tmux switch-client -t s2; settle
    tmux switch-client -t s3; settle        # cur=s3, tlist=[s3,s2] (s1 seeded, not promoted)
    TL_BEFORE="$(getlist tlist)"
    # close the CURRENT session while it is focused -> tmux relocates the client
    tmux kill-session -t s3
    settle 0.8                               # let prune + (possible) landing hook drain
    TL_AFTER="$(getlist tlist)"
    CUR="$(getv current)"
    if printf ' %s ' " $(getlist hist) " | grep -qF ' s3 '; then bad "$CURTEST: s3 pruned from hist" "s3 still in hist"; else ok "$CURTEST: s3 pruned from hist"; fi
    if subset "$TL_AFTER" "$TL_BEFORE"; then ok "$CURTEST: no NEW tlist entry after close-current"; else bad "$CURTEST: close-current added a tlist entry (§11)" "before=[$TL_BEFORE] after=[$TL_AFTER] current=$CUR"; fi
    killenv
    [ -n "$REAL_PID" ] && kill "$REAL_PID" 2>/dev/null; wait "$REAL_PID" 2>/dev/null; REAL_PID=""
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "SUMMARY"
printf '  passed: %s%d%s   failed: %s%d%s   skipped: %s%d%s\n' \
    "$C_GRN" "$PASS" "$C_RST" "$C_RED" "$FAIL" "$C_RST" "$C_YLW" "$SKIPPED" "$C_RST"
if [ "$FAIL" -gt 0 ]; then
    printf '\n%sFailures:%s%b\n' "$C_RED" "$C_RST" "$FAILURES"
    exit 1
fi
printf '\n%sAll validations passed.%s\n' "$C_GRN" "$C_RST"
exit 0