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
#
# Config (env, all in seconds):
#   VIBESTRETCH_MIN_TURN    current turn must be at least this long (default 120)
#   VIBESTRETCH_MIN_ACTIVE  agent-active time since last nudge (default 300)
#   VIBESTRETCH_COOLDOWN    min gap between nudges (default 900)
#   VIBESTRETCH_DISABLE     set to anything to turn nudges off

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vibestretch"
mkdir -p "$STATE_DIR" 2>/dev/null

MIN_TURN="${VIBESTRETCH_MIN_TURN:-120}"
MIN_ACTIVE="${VIBESTRETCH_MIN_ACTIVE:-300}"
COOLDOWN="${VIBESTRETCH_COOLDOWN:-900}"
IDLE_RESET=2700 # away >45 min => sitting debt is stale

# session_id sits near the top of the hook payload; don't slurp huge tool outputs
SID=$(head -c 4096 | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$SID" ] && SID="global"
TURN_FILE="$STATE_DIR/turn-$SID"
SEEN_FILE="$STATE_DIR/seen-$SID"
ACTIVE_FILE="$STATE_DIR/active"

readnum() { # readnum <file> <default>
  VAL=$(cat "$1" 2>/dev/null)
  case "$VAL" in ''|*[!0-9]*) VAL="$2" ;; esac
  echo "$VAL"
}

# add in-turn time elapsed since we last counted into the global active total
accumulate() {
  [ -f "$TURN_FILE" ] || return 0
  TURN_START=$(readnum "$TURN_FILE" "$NOW")
  SEEN=$(readnum "$SEEN_FILE" "$TURN_START")
  DELTA=$((NOW - SEEN))
  [ "$DELTA" -lt 0 ] && DELTA=0
  ACTIVE=$(( $(readnum "$ACTIVE_FILE" 0) + DELTA ))
  echo "$ACTIVE" > "$ACTIVE_FILE"
  echo "$NOW" > "$SEEN_FILE"
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

NOW=$(date +%s)

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
    [ -n "$VIBESTRETCH_DISABLE" ] && exit 0
    [ -f "$TURN_FILE" ] || exit 0
    accumulate

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

    MIN=$((ACTIVE / 60))
    printf '{"suppressOutput":true,"systemMessage":"🧘 vibestretch » ~%s min of agent time since your last break. You: %s"}\n' \
      "$MIN" "$EX"
    ;;

  stop)
    accumulate
    rm -f "$TURN_FILE" "$SEEN_FILE"
    ;;
esac
exit 0
