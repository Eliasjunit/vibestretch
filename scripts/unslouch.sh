#!/bin/sh
# unslouch — stretch nudges while your coding agent works.
# Subcommands (wired via hooks.json):
#   start  (UserPromptSubmit) — mark turn start
#   check  (PostToolUse)      — nudge if the agent has been working long enough
#   stop   (Stop)             — clear turn state
#
# Config (env):
#   UNSLOUCH_FIRST_MIN   minutes of agent work before the first nudge (default 3)
#   UNSLOUCH_REPEAT_MIN  minutes between nudges within one long turn (default 5)
#   UNSLOUCH_LINK        link shown in the nudge footer
#   UNSLOUCH_DISABLE     set to anything to turn nudges off

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/unslouch"
mkdir -p "$STATE_DIR" 2>/dev/null

LINK="${UNSLOUCH_LINK:-https://github.com/Eliasjunit/unslouch}"
FIRST_MIN="${UNSLOUCH_FIRST_MIN:-3}"
REPEAT_MIN="${UNSLOUCH_REPEAT_MIN:-5}"
COOLDOWN_SEC=120 # min gap between nudges across turns/sessions

# session_id sits near the top of the hook payload; don't slurp huge tool outputs
SID=$(head -c 4096 | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$SID" ] && SID="global"
TURN_FILE="$STATE_DIR/turn-$SID"
COUNT_FILE="$STATE_DIR/count-$SID"

exercise() {
  case $1 in
    0)  echo "20-20-20: look at something 20 feet away for 20 seconds." ;;
    1)  echo "Stand up, reach for the ceiling, hold 15s. Then fold to your toes, 15s." ;;
    2)  echo "10 squats. Your agent won't judge." ;;
    3)  echo "Slow neck rolls — 5 each direction." ;;
    4)  echo "Wrist circles, 10 each way. Your tendons will thank you." ;;
    5)  echo "Blink 20 times, slowly. Screens murder your blink rate." ;;
    6)  echo "Shoulder blade squeezes x10 — pinch, hold 3s, release." ;;
    7)  echo "Unslouch: ears over shoulders, shoulders over hips. Hold it." ;;
    8)  echo "Stand up and walk to a window. Bonus points: open it." ;;
    9)  echo "Rub your palms warm, cup them over closed eyes for 20s." ;;
    10) echo "Hip circles, 8 each way. Nobody is watching." ;;
    11) echo "One 4-7-8 breath: in for 4, hold 7, out for 8." ;;
  esac
}
EX_COUNT=12

case "$1" in
  start)
    date +%s > "$TURN_FILE"
    rm -f "$COUNT_FILE"
    ;;

  check)
    [ -n "$UNSLOUCH_DISABLE" ] && exit 0
    [ -f "$TURN_FILE" ] || exit 0
    START=$(cat "$TURN_FILE" 2>/dev/null)
    [ -z "$START" ] && exit 0
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))

    NUDGES=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    DUE=$((FIRST_MIN * 60 + NUDGES * REPEAT_MIN * 60))
    [ "$ELAPSED" -lt "$DUE" ] && exit 0

    LAST=$(cat "$STATE_DIR/last-nudge" 2>/dev/null || echo 0)
    [ $((NOW - LAST)) -lt "$COOLDOWN_SEC" ] && exit 0

    IDX=$(cat "$STATE_DIR/idx" 2>/dev/null || echo 0)
    EX=$(exercise "$IDX")
    echo $(( (IDX + 1) % EX_COUNT )) > "$STATE_DIR/idx"
    echo $((NUDGES + 1)) > "$COUNT_FILE"
    echo "$NOW" > "$STATE_DIR/last-nudge"

    MIN=$((ELAPSED / 60))
    printf '{"suppressOutput":true,"systemMessage":"🧘 unslouch » Agent has been at it for %s min. Meanwhile, you: %s  ·  %s"}\n' \
      "$MIN" "$EX" "$LINK"
    ;;

  stop)
    rm -f "$TURN_FILE" "$COUNT_FILE"
    ;;
esac
exit 0
