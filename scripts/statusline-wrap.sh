#!/bin/sh
# Wraps an existing statusLine command and appends the vibestretch segment.
#
#   statusline-wrap.sh '<original command>'   # keep your status line, add us
#   statusline-wrap.sh                        # no prior status line: model + us
#
# Claude Code pipes session JSON to the statusLine command's stdin; we pass it
# through to the original untouched.
IN=$(cat)

if [ -n "$1" ]; then
  OUT=$(printf '%s' "$IN" | sh -c "$1")
else
  # minimal default: the model's display name from the session JSON
  OUT=$(printf '%s' "$IN" | sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

SEG=$("$(dirname -- "$0")/statusline-segment.sh")
if [ -n "$SEG" ] && [ -n "$OUT" ]; then
  printf '%s | %s\n' "$OUT" "$SEG"
elif [ -n "$SEG" ]; then
  printf '%s\n' "$SEG"
else
  printf '%s\n' "$OUT"
fi
