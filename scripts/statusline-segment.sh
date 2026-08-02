#!/bin/sh
# vibestretch status line segment. Prints the active nudge for 5 minutes after
# it fires (bold green), then the agent-time counter from 2 minutes of debt
# (dim), else nothing. Reads plugin state only — safe to call from any
# statusLine command.
#
# Honesty guards (from review): a muted plugin shows nothing (the hooks that
# would reset the state are muted too); debt goes quiet once the human has
# been away 45+ minutes (the hook-side reset can only run at the NEXT prompt,
# but the bar must not claim debt all night); a last-nudge timestamp from the
# future (clock jump) must not pin the exercise banner forever.
[ -n "$VIBESTRETCH_DISABLE" ] && exit 0

VS="${XDG_CACHE_HOME:-$HOME/.cache}/vibestretch"
NOW=$(date +%s)

num() { # num <file> -> value or 0
  V=$(cat "$1" 2>/dev/null)
  case "$V" in ''|*[!0-9]*) V=0 ;; esac
  echo "$V"
}

LN=$(num "$VS/last-nudge")
AGE=$((NOW - LN))
if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 300 ] && [ -s "$VS/current" ]; then
  EX=$(cat "$VS/current")
  # status line gets the first sentence only — the instruction; the flavor
  # tail lives in the toast and the notification, where there is room
  case "$EX" in *". "*) EX="${EX%%. *}." ;; esac
  printf '\033[1;32m🧘 %s\033[0m' "$EX"
  exit 0
fi

LA=$(num "$VS/last-activity")
IDLE=$((NOW - LA))
{ [ "$IDLE" -lt 0 ] || [ "$IDLE" -gt 2700 ]; } && exit 0  # away 45+ min: debt is stale

ACT=$(num "$VS/active")
[ "$ACT" -ge 120 ] && printf '\033[2m🧘 %sm agent time\033[0m' $((ACT / 60))
exit 0
