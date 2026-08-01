#!/bin/sh
# vibestretch — stretch nudges while your coding agent works.
# Subcommands (wired via hooks.json):
#   start  (UserPromptSubmit) — mark turn start, reset stale sitting debt
#   check  (PostToolUse)      — accumulate agent-active time, nudge when due
#   stop   (Stop)             — close out the turn's accounting
#
# Nudge fires only when ALL of:
#   - the current turn has been running >= VIBESTRETCH_MIN_TURN seconds
#     (you are actually waiting on the agent right now)
#   - accumulated agent-active time since your last nudge >= VIBESTRETCH_MIN_ACTIVE
#     (you have genuinely been sitting through agent work — one big turn
#      or several medium ones both count)
#   - at least VIBESTRETCH_COOLDOWN seconds passed since the last nudge
# A break away from the keyboard longer than 45 min resets the debt.
# Time when nobody touches the machine is never counted at all (macOS: the
# system's keyboard/mouse idle clock; elsewhere this guard degrades to the
# 45-minute reset above) — an overnight agent run is the agent's time, not
# your sitting.
#
# Config (env, all in seconds):
#   VIBESTRETCH_MIN_TURN    current turn must be at least this long (default 120)
#   VIBESTRETCH_MIN_ACTIVE  agent-active time since last nudge (default 300)
#   VIBESTRETCH_COOLDOWN    min gap between nudges (default 900)
#   VIBESTRETCH_AWAY        no keyboard/mouse input for this long = you are
#                           away: no debt, no nudges (default 300, 0 = off;
#                           detection is macOS-only)
#   VIBESTRETCH_DISABLE     set to anything to turn nudges off
#   VIBESTRETCH_NOTIFY      0 = no desktop notification, terminal text only
#   VIBESTRETCH_SOUND       0 = no sound with the nudge

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vibestretch"
mkdir -p "$STATE_DIR" 2>/dev/null

MIN_TURN="${VIBESTRETCH_MIN_TURN:-120}"
MIN_ACTIVE="${VIBESTRETCH_MIN_ACTIVE:-300}"
COOLDOWN="${VIBESTRETCH_COOLDOWN:-900}"
IDLE_RESET=2700 # away >45 min => sitting debt is stale

# session_id sits near the top of the hook payload; don't slurp huge tool outputs.
# No session_id — no accounting: a shared fallback id would pool unrelated
# runs into one eternal "turn" (and collide with the seen-global file).
SID=$(head -c 4096 | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$SID" ] && exit 0
TURN_FILE="$STATE_DIR/turn-$SID"
SEEN_FILE="$STATE_DIR/seen-$SID"
ACTIVE_FILE="$STATE_DIR/active"

readnum() { # readnum <file> <default>
  VAL=$(cat "$1" 2>/dev/null)
  case "$VAL" in ''|*[!0-9]*) VAL="$2" ;; esac
  echo "$VAL"
}

# Seconds since the last keyboard/mouse input, from the OS. Empty when the
# machine can't tell us (non-macOS) — then we assume the human is present.
HID_IDLE=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
AWAY_AFTER="${VIBESTRETCH_AWAY:-300}"

away() { # true when the human has not touched the machine for AWAY_AFTER+
  [ "$AWAY_AFTER" = "0" ] && return 1
  case "$HID_IDLE" in ''|*[!0-9]*) return 1 ;; esac
  [ "$HID_IDLE" -ge "$AWAY_AFTER" ]
}

# Add in-turn time elapsed since we last counted into the global active total.
# The debt is per-HUMAN wall-clock ("at least one agent was working"), not the
# sum over sessions: with several windows running in parallel, each check only
# counts time nobody has counted yet (seen-global), or three busy agents would
# turn 5 real minutes into 15.
accumulate() {
  [ -f "$TURN_FILE" ] || return 0
  TURN_START=$(readnum "$TURN_FILE" "$NOW")
  if away; then
    # The human is not at the machine: an unattended agent run is not sitting.
    # Advance the seen marks so this stretch is never counted later, but leave
    # last-activity alone — the 45-minute burn must see the real absence.
    echo "$NOW" > "$SEEN_FILE"
    echo "$NOW" > "$STATE_DIR/seen-global"
    return 1
  fi
  SEEN=$(readnum "$SEEN_FILE" "$TURN_START")
  GSEEN=$(readnum "$STATE_DIR/seen-global" 0)
  [ "$GSEEN" -gt "$SEEN" ] && SEEN=$GSEEN
  DELTA=$((NOW - SEEN))
  [ "$DELTA" -lt 0 ] && DELTA=0
  ACTIVE=$(( $(readnum "$ACTIVE_FILE" 0) + DELTA ))
  echo "$ACTIVE" > "$ACTIVE_FILE"
  echo "$NOW" > "$SEEN_FILE"
  echo "$NOW" > "$STATE_DIR/seen-global"
  echo "$NOW" > "$STATE_DIR/last-activity"
}

exercise() {
  case $1 in
    0)  echo "20-20-20: look at something 20 feet away for 20 seconds." ;;
    1)  echo "Stand up, reach for the ceiling, hold 15s. Then fold to your toes, 15s." ;;
    2)  echo "10 squats. Your agent won't judge." ;;
    3)  echo "Slow neck rolls — 5 each direction." ;;
    4)  echo "Wrist circles, 10 each way. Your tendons will thank you." ;;
    5)  echo "Blink 20 times, slowly. Screens murder your blink rate." ;;
    6)  echo "Shoulder blade squeezes x10 — pinch, hold 3s, release." ;;
    7)  echo "Posture check: ears over shoulders, shoulders over hips. Hold it." ;;
    8)  echo "Stand up and walk to a window. Bonus points: open it." ;;
    9)  echo "Rub your palms warm, cup them over closed eyes for 20s." ;;
    10) echo "Hip circles, 8 each way. Nobody is watching." ;;
    11) echo "One 4-7-8 breath: in for 4, hold 7, out for 8." ;;
  esac
}
EX_COUNT=12

# A line of text loses to a desktop notification when you have looked away.
# Only terminals known to support the sequence get one; the rest stay silent
# rather than risk stray bytes. Opt out entirely with VIBESTRETCH_NOTIFY=0.
notify() { # notify <exercise> <minutes>  -> JSON fragment, possibly empty
  [ "${VIBESTRETCH_NOTIFY:-1}" = "0" ] && return 0
  BODY=$(printf '%s' "$1" | tr ';' ',') # ; separates OSC fields
  case "${TERM_PROGRAM:-}:${TERM:-}" in
    *Warp*|*ghostty*|*Ghostty*)
      printf ',"terminalSequence":"\\u001b]777;notify;🧘 %s min sitting — time to move;%s\\u0007"' "$2" "$BODY" ;;
    *iTerm*|*WezTerm*)
      printf ',"terminalSequence":"\\u001b]9;🧘 %s\\u0007"' "$BODY" ;;
    *kitty*)
      printf ',"terminalSequence":"\\u001b]99;;🧘 %s\\u0007"' "$BODY" ;;
  esac
}

# Sound is the channel that works when you are not looking at any screen —
# the pattern every Claude Code notification recipe converges on. The chime is
# our own (bundled wav, nothing system-sounding), played by the OS player —
# still zero deps. Backgrounded so the hook never waits.
sound() {
  [ "${VIBESTRETCH_SOUND:-1}" = "0" ] && return 0
  SND="${CLAUDE_PLUGIN_ROOT:-$(dirname -- "$0")/..}/sounds/nudge.wav"
  [ -f "$SND" ] || return 0
  if [ -x /usr/bin/afplay ]; then
    /usr/bin/afplay "$SND" >/dev/null 2>&1 &
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$SND" >/dev/null 2>&1 &
  fi
}

NOW=$(date +%s)

# A disabled session must not touch the accounting at all. Guarding only the
# nudge (check) is not enough: start/stop from disabled headless runs would
# still pump the sitting debt and keep refreshing last-activity, so the
# 45-minute idle reset could never fire.
[ -n "$VIBESTRETCH_DISABLE" ] && exit 0

case "$1" in
  start)
    LAST_ACT=$(readnum "$STATE_DIR/last-activity" 0)
    if [ $((NOW - LAST_ACT)) -gt "$IDLE_RESET" ]; then
      echo 0 > "$ACTIVE_FILE"
    fi
    echo "$NOW" > "$TURN_FILE"
    echo "$NOW" > "$SEEN_FILE"
    echo "$NOW" > "$STATE_DIR/last-activity"
    ;;

  check)
    [ -f "$TURN_FILE" ] || exit 0
    # away: no debt grows and no nudge fires into an empty chair (a 3 a.m.
    # chime for an overnight agent run is the opposite of the product)
    accumulate || exit 0

    TURN_ELAPSED=$((NOW - TURN_START))
    [ "$TURN_ELAPSED" -lt "$MIN_TURN" ] && exit 0

    LAST_NUDGE=$(readnum "$STATE_DIR/last-nudge" 0)
    [ $((NOW - LAST_NUDGE)) -lt "$COOLDOWN" ] && exit 0

    [ "$ACTIVE" -lt "$MIN_ACTIVE" ] && exit 0

    IDX=$(readnum "$STATE_DIR/idx" 0)
    EX=$(exercise "$IDX")
    echo $(( (IDX + 1) % EX_COUNT )) > "$STATE_DIR/idx"
    echo "$NOW" > "$STATE_DIR/last-nudge"
    echo 0 > "$ACTIVE_FILE"

    # systemMessage renders as one transcript line pinned to the tool the hook
    # fired after (older builds showed a fading toast), so it must be one clean
    # line, exercise first. Durable copies: the desktop notification (stays in the
    # notification center) and the state files below, which any status line can
    # render (the plugin can't draw there itself — the bottom bar is the user's).
    MIN=$((ACTIVE / 60))
    printf '%s\n' "$EX" > "$STATE_DIR/current"
    sound
    printf '{"suppressOutput":true,"systemMessage":"🧘 %s · vibestretch · %s min sitting"%s}\n' \
      "$EX" "$MIN" "$(notify "$EX" "$MIN")"
    ;;

  stop)
    accumulate || :
    rm -f "$TURN_FILE" "$SEEN_FILE"
    ;;
esac
exit 0
