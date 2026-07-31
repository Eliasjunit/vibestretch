#!/bin/sh
# vibestretch status line segment. Prints the active nudge for 5 minutes after
# it fires (bold green), then the sitting-debt counter from 2 minutes of debt
# (dim), else nothing. Reads plugin state only — safe to call from any
# statusLine command.
VS="${XDG_CACHE_HOME:-$HOME/.cache}/vibestretch"
NOW=$(date +%s)

num() { # num <file> -> value or 0
  V=$(cat "$1" 2>/dev/null)
  case "$V" in ''|*[!0-9]*) V=0 ;; esac
  echo "$V"
}

LN=$(num "$VS/last-nudge")
if [ $((NOW - LN)) -lt 300 ] && [ -s "$VS/current" ]; then
  EX=$(cat "$VS/current")
  # status line gets the first sentence only — the instruction; the flavor
  # tail lives in the toast and the notification, where there is room
  case "$EX" in *". "*) EX="${EX%%. *}." ;; esac
  printf '\033[1;32m🧘 %s\033[0m' "$EX"
  exit 0
fi
ACT=$(num "$VS/active")
[ "$ACT" -ge 120 ] && printf '\033[2m🧘 %sm sitting\033[0m' $((ACT / 60))
exit 0
